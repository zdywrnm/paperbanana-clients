import XCTest
@testable import PaperBanana

/// SYNC 2026-06-10：小程序端 getJob 曾报"非法 JSON"（最终判定为误报），
/// 小程序端加了 coerceJsonResponse 防御。iOS 对齐其语义：requestJSON 发现原始响应
/// 不是合法 JSON 时，裸 \t \n \r 替换为空格（空格在 JSON 字符串内外都合法，可修复
/// 字符串值内混入裸换行的损坏模式，如 logs_tail 事故场景），其余 0x00-0x1F 裸控制
/// 字节移除，envelope 失败检查与解码整体换用清洗后的数据——和小程序一样先清洗、
/// 再跑失败检查，避免把损坏的服务端错误响应误报为成功、把损坏字段静默置空
/// （JSONDecoder 对字符串值内裸控制字节是惰性校验，EmptyEnvelope/宽松字段不会触发解码失败）。
/// 字符串内的合法转义如 \n 是两个 ASCII 字符，不含裸控制字节，不受影响。
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

  func testBareNewlineInsideStringValueDecodesWithSpaceReplacement() async throws {
    let client = PaperBananaAPIClient(session: URLSession.defensiveDecodingStubbedSession())
    // 原始事故场景：logs_tail 字符串值内混入裸换行/制表符（JSONDecoder 必拒）。
    // 对齐小程序 coerceJsonResponse：\t \n \r 替换为空格后成功解码。
    var body = Data(#"{"code":0,"job":{"id":"job-5","status":"failed","logs_tail":"line1"#.utf8)
    body.append(0x0A)
    body.append(Data("line2".utf8))
    body.append(0x09)
    body.append(Data(#"line3"}}"#.utf8))
    DefensiveDecodingURLProtocolStub.requestHandler = { request in
      DefensiveDecodingURLProtocolStub.response(url: request.url, statusCode: 200, body: body)
    }

    let job = try await client.getJob(apiBase: "https://gateway.example", jobID: "job-5")

    XCTAssertEqual(job.id, "job-5")
    XCTAssertEqual(job.statusKind, .failed)
    // 字符串值内的裸换行/制表符变为空格，其余内容保持原样。
    XCTAssertEqual(job.failureLogsText, "line1 line2 line3")
  }

  func testCorruptedErrorEnvelopeThrowsServerErrorInsteadOfFalseSuccess() async {
    let client = PaperBananaAPIClient(session: URLSession.defensiveDecodingStubbedSession())
    // 200 + 错误 envelope（code!=0）+ 字符串值内裸控制字节：原始 JSONSerialization
    // 解析失败导致首轮 envelope 失败检查落空；清洗后必须补查并抛服务端错误，
    // 不能让 EmptyEnvelope 解码成功把它误报为成功（signIn/signUp/submitFeedback 路径）。
    var body = Data(#"{"code":1,"error":"server"#.utf8)
    body.append(0x00)
    body.append(Data(#" exploded"}"#.utf8))
    DefensiveDecodingURLProtocolStub.requestHandler = { request in
      DefensiveDecodingURLProtocolStub.response(url: request.url, statusCode: 200, body: body)
    }

    do {
      try await client.signIn(apiBase: "https://gateway.example", email: "a@b.c", password: "secret123")
      XCTFail("Expected server error, got false success")
    } catch let error as PaperBananaAPIError {
      guard case .http(let details) = error else {
        return XCTFail("Expected .http, got \(error)")
      }
      XCTAssertEqual(details.statusCode, 200)
      XCTAssertEqual(details.message, "server exploded")
    } catch {
      XCTFail("Expected PaperBananaAPIError.http, got \(error)")
    }
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
      guard case .decoding(let message) = error else {
        return XCTFail("Expected .decoding, got \(error)")
      }
      // 清洗后重试仍失败时带标注前缀，与首次解码即失败的路径可区分，便于排障。
      XCTAssertTrue(message.hasPrefix("清洗控制字符后仍解码失败"), "unexpected message: \(message)")
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
