import XCTest
@testable import PaperBanana

/// Phase 3 契约补强：用测试钉死已对齐的跨端行为（SYNC.md），防止 Phase 4-5 UI 重做回归。
/// 已有覆盖、此处不重复的契约：
/// - payload 双保险（带 referenceImages 强制 retrievalSetting=none、manualReferenceIds=[]）
///   → PayloadEncodingTests.testCreateJobBodySendsFullWebWhitelistAndDisablesRetrievalWhenUploadingReferences
/// - RefineImagePayload 含 mainModelName / referenceVisionModelName
///   → PayloadEncodingTests.testRefineImageBodySendsRequiredWebFields
/// - bailian 能力正则的 qwen3.7-max / qwen3.7-plus / kimi-k2.6
///   → ProviderCatalogTests.testMainModelImageCapabilityMatchesWebHelper
@MainActor
final class ContractAlignmentTests: XCTestCase {
  override func tearDown() {
    ContractAlignmentURLProtocolStub.requestHandler = nil
    super.tearDown()
  }

  // SYNC 2026-06-09：上传参考图后自动关闭检索并清空手动参考。
  func testAddingReferenceImageDisablesRetrievalAndClearsManualReferences() {
    let model = AppModel()
    model.generation.draft.configurationMode = .advanced
    model.generation.draft.retrievalSetting = .manual
    model.generation.draft.manualReferenceIds = ["ref-1", "ref-2"]

    model.generation.addReferenceFile(
      filename: "style.png",
      mimeType: "image/png",
      data: Data([0x89, 0x50, 0x4E, 0x47])
    )

    XCTAssertTrue(model.generation.referenceUploadError.isEmpty)
    XCTAssertEqual(model.generation.draft.referenceImages.count, 1)
    XCTAssertEqual(model.generation.draft.retrievalSetting, RetrievalSetting.none)
    XCTAssertEqual(model.generation.draft.manualReferenceIds, [])
  }

  // SYNC 2026-06-08：数据统计图派生 plot 任务，其余类别派生 diagram。
  func testInfographicCategoryDerivesTaskNameLikeWeb() {
    var draft = GenerationDraft()

    draft.infographicCategoryID = "data_stat"
    XCTAssertEqual(draft.taskName, .plot)

    let diagramCategories = [
      "method_framework", "workflow", "system_architecture", "mechanism",
      "comparison", "timeline", "concept_map"
    ]
    for categoryID in diagramCategories {
      draft.infographicCategoryID = categoryID
      XCTAssertEqual(draft.taskName, .diagram, "类别 \(categoryID) 应派生 diagram 任务")
    }
  }

  // SYNC 2026-06-08：bailian 主模型固定能力（补 ProviderCatalogTests 未覆盖的型号）。
  func testBailianMainModelCapabilityCoversOmniAndDeepseek() {
    XCTAssertTrue(ProviderCatalog.mainModelCanReadImages(provider: .bailian, model: "qwen3.5-omni-plus"))
    XCTAssertFalse(ProviderCatalog.mainModelCanReadImages(provider: .bailian, model: "deepseek-v4-pro"))
    XCTAssertFalse(ProviderCatalog.mainModelCanReadImages(provider: .bailian, model: "deepseek-v4-flash"))
  }

  // referenceLibrary 请求必须携带 taskName（plot/diagram 参考库内容不同）。
  func testReferenceLibraryRequestCarriesTaskName() async throws {
    let client = PaperBananaAPIClient(session: URLSession.contractAlignmentStubbedSession())
    var requestedTaskNames: [String] = []
    ContractAlignmentURLProtocolStub.requestHandler = { request in
      let body = try XCTUnwrap(
        JSONSerialization.jsonObject(with: try request.contractBodyData()) as? [String: Any]
      )
      XCTAssertEqual(body["action"] as? String, "referenceLibrary")
      if let taskName = body["taskName"] as? String {
        requestedTaskNames.append(taskName)
      }
      return ContractAlignmentURLProtocolStub.response(
        url: request.url,
        statusCode: 200,
        body: #"{"code":0,"references":[]}"#
      )
    }

    _ = try await client.referenceLibrary(apiBase: "https://gateway.example", taskName: .plot)
    _ = try await client.referenceLibrary(apiBase: "https://gateway.example", taskName: .diagram)

    XCTAssertEqual(requestedTaskNames, ["plot", "diagram"])
  }
}

private final class ContractAlignmentURLProtocolStub: URLProtocol {
  static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  static func response(url: URL?, statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
    let resolvedURL = url ?? URL(string: "https://gateway.example/paperbanana-api")!
    let response = HTTPURLResponse(
      url: resolvedURL,
      statusCode: statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )!
    return (response, Data(body.utf8))
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
  static func contractAlignmentStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ContractAlignmentURLProtocolStub.self]
    return URLSession(configuration: configuration)
  }
}

private extension URLRequest {
  func contractBodyData() throws -> Data {
    if let httpBody {
      return httpBody
    }
    guard let httpBodyStream else {
      return Data()
    }

    httpBodyStream.open()
    defer { httpBodyStream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while httpBodyStream.hasBytesAvailable {
      let count = httpBodyStream.read(&buffer, maxLength: buffer.count)
      if count > 0 {
        data.append(buffer, count: count)
      } else if count < 0 {
        throw httpBodyStream.streamError ?? URLError(.cannotDecodeContentData)
      } else {
        break
      }
    }
    return data
  }
}
