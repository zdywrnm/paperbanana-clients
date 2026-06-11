import XCTest
@testable import PaperBanana

@MainActor
final class JobsStoreTests: XCTestCase {
  override func tearDown() {
    JobsStoreStub.requestHandler = nil
    super.tearDown()
  }

  private func makeStore() -> JobsStore {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [JobsStoreStub.self]
    let client = PaperBananaAPIClient(session: URLSession(configuration: configuration))
    let settings = SettingsStore(apiClient: client)
    let auth = AuthStore(apiClient: client, settings: settings)
    return JobsStore(apiClient: client, settings: settings, auth: auth)
  }

  // MARK: - refreshCurrentJob

  func testRefreshCurrentJobUpdatesJobAndLastPolledAt() async throws {
    let store = makeStore()
    store.currentJobID = "job-1"
    JobsStoreStub.requestHandler = { request in
      JobsStoreStub.jsonResponse(url: request.url, body: #"{"code":0,"job":{"id":"job-1","status":"running"}}"#)
    }

    await store.refreshCurrentJob()

    XCTAssertEqual(store.currentJob?.id, "job-1")
    XCTAssertEqual(store.currentJob?.status, "running")
    XCTAssertNotNil(store.lastPolledAt)
  }

  func testRefreshCurrentJobSlowResponseDoesNotOverwriteNewerJob() async throws {
    // 旧任务的 getJob 在 await 期间用户已切换跟踪新任务：慢响应不得覆盖新任务的 currentJob。
    let store = makeStore()
    store.currentJobID = "job-old"
    JobsStoreStub.requestHandler = { request in
      Thread.sleep(forTimeInterval: 0.2) // 模拟旧任务的慢响应
      return JobsStoreStub.jsonResponse(url: request.url, body: #"{"code":0,"job":{"id":"job-old","status":"succeeded"}}"#)
    }

    let refresh = Task { await store.refreshCurrentJob() }
    try await Task.sleep(for: .milliseconds(50)) // 让旧请求先发出
    store.currentJobID = "job-new"
    store.currentJob = Job(id: "job-new", status: "queued")
    await refresh.value

    XCTAssertEqual(store.currentJob?.id, "job-new")
    XCTAssertEqual(store.currentJob?.status, "queued")
    XCTAssertNil(store.lastPolledAt)
  }

  // MARK: - track

  func testTrackResetsLastPolledAtFromPreviousJob() {
    let store = makeStore()
    JobsStoreStub.requestHandler = { request in
      JobsStoreStub.jsonResponse(url: request.url, body: #"{"code":0,"job":{"id":"job-2","status":"running"}}"#)
    }
    store.lastPolledAt = Date()

    store.track(jobID: "job-2", status: "queued")

    XCTAssertEqual(store.currentJobID, "job-2")
    XCTAssertEqual(store.currentJob?.id, "job-2")
    // 新任务尚未拿到任何数据："刷新于 X 前"不能显示上一个任务的时刻。
    XCTAssertNil(store.lastPolledAt)
    store.pausePolling()
  }
}

private final class JobsStoreStub: URLProtocol {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

  static func jsonResponse(url: URL?, body: String) -> (HTTPURLResponse, Data) {
    let resolvedURL = url ?? URL(string: "https://gateway.example/paperbanana-api")!
    let response = HTTPURLResponse(
      url: resolvedURL,
      statusCode: 200,
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
    let (response, data) = requestHandler(request)
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
