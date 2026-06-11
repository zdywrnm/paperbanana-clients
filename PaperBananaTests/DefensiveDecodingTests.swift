import XCTest
@testable import PaperBanana

/// SYNC 2026-06-10：小程序端 getJob 曾报"非法 JSON"（最终判定为误报），
/// 小程序端加了 coerceJsonResponse 防御。iOS 对齐：requestJSON 首次解码失败后，
/// 移除响应里裸出现的非法控制字符（保留 \t \n \r，它们是合法 JSON whitespace；
/// 字符串内的合法转义如 \n 是两个 ASCII 字符，不受影响）再重试解码一次。
final class DefensiveDecodingTests: XCTestCase {
  override func tearDown() {
    DefensiveDecodingURLProtocolStub.requestHandler = nil
    super.tearDown()
  }

  func testJSONWithBareControlCharactersDecodesAfterSanitizing() async throws {
    let client = PaperBananaAPIClient(session: URLSession.defensiveDecodingStubbedSession())
    // 0x0C 裸出现在 token 之间（不是合法 JSON whitespace），首次解码必失败；
    // 字符串值内再混入 0x00-0x1F 区间的其他裸控制字节。
    var body = Data(#"{"code":0,"#.utf8)
    body.append(0x0C)
    body.append(Data(#""job":{"id":"job-1","status":"succeeded","caption":"abc"#.utf8))
    body.append(contentsOf: [0x00, 0x01, 0x08, 0x0B, 0x1F])
    body.append(Data(#"def","logs_tail":"line1\nline2"}}"#.utf8))
    DefensiveDecodingURLProtocolStub.requestHandler = { request in
      DefensiveDecodingURLProtocolStub.response(url: request.url, statusCode: 200, body: body)
    }

    let job = try await client.getJob(apiBase: "https://gateway.example", jobID: "job-1")

    XCTAssertEqual(job.id, "job-1")
    XCTAssertEqual(job.statusKind, .succeeded)
    // 裸控制字符被移除，字符串其余内容保持原样。
    XCTAssertEqual(job.title, "abcdef")
    // 合法 JSON 转义（\n）不被清洗破坏，仍解码为换行。
    XCTAssertEqual(job.failureLogsText, "line1\nline2")
  }

  func testWellFormedJSONWithLegalWhitespaceIsUnaffected() async throws {
    let client = PaperBananaAPIClient(session: URLSession.defensiveDecodingStubbedSession())
    let body = Data("{\n\t\"code\": 0,\r\n\t\"job\": {\n\t\t\"id\": \"job-2\",\n\t\t\"status\": \"queued\",\n\t\t\"caption\": \"正常任务\"\n\t}\n}".utf8)
    DefensiveDecodingURLProtocolStub.requestHandler = { request in
      DefensiveDecodingURLProtocolStub.response(url: request.url, statusCode: 200, body: body)
    }

    let job = try await client.getJob(apiBase: "https://gateway.example", jobID: "job-2")

    XCTAssertEqual(job.id, "job-2")
    XCTAssertEqual(job.statusKind, .queued)
    XCTAssertEqual(job.title, "正常任务")
  }

  func testTrulyInvalidJSONStillThrowsDecodingError() async {
    let client = PaperBananaAPIClient(session: URLSession.defensiveDecodingStubbedSession())
    DefensiveDecodingURLProtocolStub.requestHandler = { request in
      DefensiveDecodingURLProtocolStub.response(url: request.url, statusCode: 200, body: Data(#"{"job": {"id": "#.utf8))
    }

    do {
      _ = try await client.getJob(apiBase: "https://gateway.example", jobID: "job-3")
      XCTFail("Expected decoding error")
    } catch let error as PaperBananaAPIError {
      guard case .decoding = error else {
        return XCTFail("Expected .decoding, got \(error)")
      }
    } catch {
      XCTFail("Expected PaperBananaAPIError.decoding, got \(error)")
    }
  }

  func testInvalidJSONWithControlCharactersStillThrowsAfterRetry() async {
    let client = PaperBananaAPIClient(session: URLSession.defensiveDecodingStubbedSession())
    var body = Data(#"{"job": ["#.utf8)
    body.append(contentsOf: [0x01, 0x02])
    DefensiveDecodingURLProtocolStub.requestHandler = { request in
      DefensiveDecodingURLProtocolStub.response(url: request.url, statusCode: 200, body: body)
    }

    do {
      _ = try await client.getJob(apiBase: "https://gateway.example", jobID: "job-4")
      XCTFail("Expected decoding error")
    } catch let error as PaperBananaAPIError {
      guard case .decoding = error else {
        return XCTFail("Expected .decoding, got \(error)")
      }
    } catch {
      XCTFail("Expected PaperBananaAPIError.decoding, got \(error)")
    }
  }
}

private final class DefensiveDecodingURLProtocolStub: URLProtocol {
  static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  static func response(url: URL?, statusCode: Int, body: Data) -> (HTTPURLResponse, Data) {
    let resolvedURL = url ?? URL(string: "https://gateway.example/paperbanana-api")!
    let response = HTTPURLResponse(
      url: resolvedURL,
      statusCode: statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )!
    return (response, body)
  }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let requestHandler = Self.requestHandler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let (response, data) = try requestHandler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

private extension URLSession {
  static func defensiveDecodingStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DefensiveDecodingURLProtocolStub.self]
    return URLSession(configuration: configuration)
  }
}
