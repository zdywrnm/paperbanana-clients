import XCTest
@testable import PaperBanana

@MainActor
final class DeleteAccountTests: XCTestCase {
  override func tearDown() {
    DeleteAccountStub.requestHandler = nil
    super.tearDown()
  }

  private func makeModel() -> AppModel {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DeleteAccountStub.self]
    let client = PaperBananaAPIClient(session: URLSession(configuration: configuration))
    return AppModel(apiClient: client)
  }

  private func signIn(_ model: AppModel) throws {
    model.auth.currentUser = try JSONDecoder().decode(
      CurrentUser.self,
      from: Data(#"{"id":"u-del","email":"del@paperbanana.app"}"#.utf8)
    )
  }

  func testDeleteAccountSuccessClearsSessionAndAllLocalData() async throws {
    let model = makeModel()
    try signIn(model)

    // 准备本机数据：API key（Keychain）、保存的模板、本地任务缓存、记录。
    let keyName = model.generation.selectedProviderConfig.keyName
    model.generation.updateSelectedAPIKey("sk-secret-to-be-wiped")
    let template = model.saveCurrentTemplate(title: "待删模板")
    model.jobs.userJobs = [Job(id: "remote-job", status: "succeeded")]
    model.jobs.localJobs = [Job(id: "local-job", status: "running")]

    // 前置断言：数据确实在。
    let keychain = KeychainService()
    XCTAssertEqual(try keychain.string(for: keyName), "sk-secret-to-be-wiped")
    XCTAssertTrue(model.templates.templates.contains { $0.id == template.id })

    DeleteAccountStub.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/api/account/delete")
      return DeleteAccountStub.jsonResponse(url: request.url, body: #"{"code":0,"ok":true}"#)
    }

    try await model.auth.deleteAccount(password: "correct-pass")

    // 回到未登录态。
    XCTAssertNil(model.auth.currentUser)
    // 完整本地清理：模板、任务记录、本地任务、Keychain key 全清。
    XCTAssertTrue(model.templates.templates.isEmpty)
    XCTAssertTrue(model.jobs.userJobs.isEmpty)
    XCTAssertTrue(model.jobs.localJobs.isEmpty)
    XCTAssertNil(try keychain.string(for: keyName))
    XCTAssertEqual(model.generation.selectedAPIKey, "")
  }

  func testDeleteAccountInvalidPasswordKeepsSessionAndLocalData() async throws {
    let model = makeModel()
    try signIn(model)

    let keyName = model.generation.selectedProviderConfig.keyName
    model.generation.updateSelectedAPIKey("sk-must-survive")
    let template = model.saveCurrentTemplate(title: "保留模板")
    defer {
      // 失败路径不清理：用例自己负责善后，避免污染共享 Keychain / UserDefaults。
      try? KeychainService().delete(account: keyName)
      model.templates.delete(template)
    }

    DeleteAccountStub.requestHandler = { request in
      DeleteAccountStub.jsonResponse(
        url: request.url,
        body: #"{"code":401,"error":"INVALID_PASSWORD"}"#,
        statusCode: 401
      )
    }

    do {
      try await model.auth.deleteAccount(password: "wrong-pass")
      XCTFail("Expected delete to throw on invalid password")
    } catch {
      XCTAssertEqual(formatUserFacingError(error), "密码不正确，请重新输入。")
    }

    // 失败时一切保持原样：仍登录、数据未被清。
    XCTAssertNotNil(model.auth.currentUser)
    XCTAssertTrue(model.templates.templates.contains { $0.id == template.id })
    XCTAssertEqual(try KeychainService().string(for: keyName), "sk-must-survive")
  }

  func testDeleteAccountWithoutSessionThrowsAndDoesNotHitNetwork() async throws {
    let model = makeModel()
    // 未登录：currentUser == nil。
    DeleteAccountStub.requestHandler = { _ in
      XCTFail("Should not hit network without a session")
      return DeleteAccountStub.jsonResponse(url: nil, body: "{}")
    }

    do {
      try await model.auth.deleteAccount(password: "whatever")
      XCTFail("Expected delete to throw without a current user")
    } catch {
      // 任意错误即可，关键是没发网络请求且没崩。
    }
    XCTAssertNil(model.auth.currentUser)
  }
}

private final class DeleteAccountStub: URLProtocol {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

  static func jsonResponse(url: URL?, body: String, statusCode: Int = 200) -> (HTTPURLResponse, Data) {
    let resolvedURL = url ?? URL(string: "https://gateway.example/api/account/delete")!
    let response = HTTPURLResponse(
      url: resolvedURL,
      statusCode: statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )!
    return (response, Data(body.utf8))
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

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
