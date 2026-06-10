import Foundation
import Security

enum AppDefaults {
  static let sealosAPIBase = "https://yifbnnzrwmxn.sealoshzh.site"
  static let webOrigin = "https://www.paperbanana.asia"
  static let apiBaseKey = "paperbanana.ios.apiBase"
  static let clientVersion = "ios-0.1.0"

  static func normalizedAPIBase(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = trimmed.isEmpty ? sealosAPIBase : trimmed
    return base.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
  }
}

enum PaperBananaAPIError: LocalizedError {
  case invalidURL(String)
  case invalidResponse
  case server(String)
  case decoding(String)

  var errorDescription: String? {
    switch self {
    case .invalidURL(let value): "无效后端地址：\(value)"
    case .invalidResponse: "后端返回了无效响应。"
    case .server(let message): message
    case .decoding(let message): "响应解析失败：\(message)"
    }
  }
}

final class KeychainService {
  private let service = "asia.paperbanana.ios"

  func string(for account: String) throws -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw PaperBananaAPIError.server("Keychain 读取失败：\(status)") }
    guard let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  func set(_ value: String, for account: String) throws {
    try delete(account: account)
    var query = baseQuery(account: account)
    query[kSecValueData as String] = Data(value.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw PaperBananaAPIError.server("Keychain 保存失败：\(status)") }
  }

  func delete(account: String) throws {
    let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw PaperBananaAPIError.server("Keychain 删除失败：\(status)")
    }
  }

  private func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}

final class PaperBananaAPIClient {
  private let session: URLSession
  private let decoder = JSONDecoder()

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchBackendHealth(apiBase: String) async throws -> BackendHealth {
    let base = AppDefaults.normalizedAPIBase(apiBase)
    let candidates: [(BackendMode, URL, String, [String: Any]?)] = [
      (.gateway, try endpoint(apiBase: base, path: "health"), "GET", nil),
      (.gateway, try lafEndpoint(apiBase: base), "GET", nil),
      (.gateway, try lafEndpoint(apiBase: base), "POST", ["action": "health"]),
      (.fastapi, try endpoint(apiBase: base, path: "api/health"), "GET", nil)
    ]

    var lastError: Error?
    for (expectedMode, url, method, body) in candidates {
      do {
        let envelope: HealthEnvelope = try await requestJSON(url, method: method, body: body)
        if let health = envelope.toBackendHealth(expectedMode: expectedMode) {
          return health
        }
        throw PaperBananaAPIError.server("当前地址不是 PaperBanana 后端。")
      } catch {
        lastError = error
      }
    }
    throw lastError ?? PaperBananaAPIError.server("后端暂时不可用。")
  }

  func createJob(apiBase: String, payload: JobCreatePayload) async throws -> (id: String, status: String) {
    let response: CreateJobEnvelope = try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: payload.paperBananaBody()
    )
    return (response.jobID ?? response.id ?? "", response.status ?? "queued")
  }

  func refineImage(apiBase: String, payload: RefineImagePayload) async throws -> (id: String, status: String) {
    let response: CreateJobEnvelope = try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: payload.paperBananaBody()
    )
    return (response.jobID ?? response.id ?? "", response.status ?? "queued")
  }

  func prepareReferenceUpload(apiBase: String, files: [ReferenceUploadFile]) async throws -> [PreparedReferenceUpload] {
    let encodedFiles = try files.map { try dictionary(from: $0) }
    let response: UploadEnvelope = try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: ["action": "prepareReferenceUpload", "files": encodedFiles]
    )
    return response.uploads
  }

  func uploadReference(data: Data, mimeType: String, uploadURL: String) async throws {
    guard let url = URL(string: uploadURL) else { throw PaperBananaAPIError.invalidURL(uploadURL) }
    var request = URLRequest(url: url, timeoutInterval: 90)
    request.httpMethod = "PUT"
    request.httpBody = data
    request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
    let (_, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else { throw PaperBananaAPIError.invalidResponse }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw PaperBananaAPIError.server("参考图上传失败：HTTP \(httpResponse.statusCode)")
    }
  }

  func referenceLibrary(apiBase: String, taskName: TaskName, query: String = "", limit: Int = 24) async throws -> [ReferenceLibraryItem] {
    let response: ReferenceLibraryEnvelope = try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: [
        "action": "referenceLibrary",
        "taskName": taskName.rawValue,
        "query": query,
        "limit": limit
      ]
    )
    return response.references
  }

  func modelCapability(apiBase: String, provider: ProviderID, model: String) async throws -> ModelCapability {
    try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: ["action": "modelCapability", "provider": provider.rawValue, "model": model]
    )
  }

  func getJob(apiBase: String, jobID: String) async throws -> Job {
    let response: JobEnvelope = try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: ["action": "getJob", "jobId": jobID]
    )
    guard let job = response.job else { throw PaperBananaAPIError.server("后端没有返回任务详情。") }
    return job
  }

  func userJobs(apiBase: String) async throws -> [Job] {
    let response: JobsEnvelope = try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: ["action": "myJobs", "limit": 50]
    )
    return await hydrateRecordImages(apiBase: apiBase, jobs: response.jobs)
  }

  func submitFeedback(apiBase: String, message: String, category: FeedbackCategory, jobID: String?, contact: String?) async throws {
    var body: [String: Any] = [
      "action": "submitFeedback",
      "message": message,
      "category": category.rawValue,
      "platform": "ios",
      "clientVersion": AppDefaults.clientVersion
    ]
    if let jobID, !jobID.isEmpty { body["jobId"] = jobID }
    if let contact, !contact.isEmpty { body["contact"] = contact }

    let _: EmptyEnvelope = try await requestJSON(
      try lafEndpoint(apiBase: apiBase),
      method: "POST",
      body: body
    )
  }

  func getSession(apiBase: String) async throws -> CurrentUser? {
    let response: SessionEnvelope = try await requestJSON(
      try endpoint(apiBase: apiBase, path: "api/auth/get-session"),
      method: "GET",
      body: nil
    )
    return response.user
  }

  func signIn(apiBase: String, email: String, password: String) async throws {
    let _: EmptyEnvelope = try await requestJSON(
      try endpoint(apiBase: apiBase, path: "api/auth/sign-in/email"),
      method: "POST",
      body: ["email": email, "password": password]
    )
  }

  func signUp(apiBase: String, email: String, password: String, name: String) async throws {
    let _: EmptyEnvelope = try await requestJSON(
      try endpoint(apiBase: apiBase, path: "api/auth/sign-up/email"),
      method: "POST",
      body: ["email": email, "password": password, "name": name]
    )
  }

  func signOut(apiBase: String) async {
    let _: EmptyEnvelope? = try? await requestJSON(
      try endpoint(apiBase: apiBase, path: "api/auth/sign-out"),
      method: "POST",
      body: [:]
    )
  }

  func resolvedImageURL(apiBase: String, url: String) -> URL? {
    guard !url.isEmpty else { return nil }
    if url.hasPrefix("http://") || url.hasPrefix("https://") || url.hasPrefix("data:") {
      return URL(string: url)
    }
    let base = AppDefaults.normalizedAPIBase(apiBase)
    return URL(string: "\(base)\(url.hasPrefix("/") ? "" : "/")\(url)")
  }

  private func lafEndpoint(apiBase: String) throws -> URL {
    let base = AppDefaults.normalizedAPIBase(apiBase)
    if base.hasSuffix("/paperbanana-api") {
      guard let url = URL(string: base) else { throw PaperBananaAPIError.invalidURL(base) }
      return url
    }
    return try endpoint(apiBase: base, path: "paperbanana-api")
  }

  private func endpoint(apiBase: String, path: String) throws -> URL {
    let base = AppDefaults.normalizedAPIBase(apiBase)
    guard var components = URLComponents(string: base) else { throw PaperBananaAPIError.invalidURL(base) }
    let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = "/" + [existingPath, cleanPath].filter { !$0.isEmpty }.joined(separator: "/")
    guard let url = components.url else { throw PaperBananaAPIError.invalidURL(base) }
    return url
  }

  private func requestJSON<T: Decodable>(_ url: URL, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
    var request = URLRequest(url: url, timeoutInterval: 60)
    request.httpMethod = method
    request.httpShouldHandleCookies = true
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(AppDefaults.webOrigin, forHTTPHeaderField: "Origin")
    request.setValue("\(AppDefaults.webOrigin)/", forHTTPHeaderField: "Referer")
    if let body {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else { throw PaperBananaAPIError.invalidResponse }
    let object = data.isEmpty ? [:] : ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:])
    let isHTTPError = !(200..<300).contains(httpResponse.statusCode)
    let isEnvelopeFailure = objectIndicatesFailure(object)
    if isHTTPError || isEnvelopeFailure {
      throw PaperBananaAPIError.server(serverErrorMessage(from: object, statusCode: httpResponse.statusCode))
    }
    do {
      return try decoder.decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
    } catch {
      throw PaperBananaAPIError.decoding(error.localizedDescription)
    }
  }

  private func dictionary<T: Encodable>(from value: T) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
  }

  private func hydrateRecordImages(apiBase: String, jobs: [Job]) async -> [Job] {
    var hydrated: [Job] = []
    hydrated.reserveCapacity(jobs.count)

    for job in jobs {
      guard job.needsFreshRecordDetail else {
        hydrated.append(job)
        continue
      }

      do {
        hydrated.append(try await getJob(apiBase: apiBase, jobID: job.id))
      } catch {
        hydrated.append(job)
      }
    }
    return hydrated
  }

  private func objectIndicatesFailure(_ object: [String: Any]) -> Bool {
    if let code = object["code"] {
      return String(describing: code) != "0"
    }
    if let ok = object["ok"] as? Bool {
      return !ok
    }
    if let success = object["success"] as? Bool {
      return !success
    }
    return false
  }

  private func serverErrorMessage(from object: [String: Any], statusCode: Int) -> String {
    if let error = object["error"] as? String, !error.isEmpty { return error }
    if let detail = object["detail"] as? String, !detail.isEmpty { return detail }
    if let message = object["message"] as? String, !message.isEmpty { return message }
    if let error = object["error"] as? [String: Any], let message = error["message"] as? String, !message.isEmpty { return message }
    if let data = object["data"] as? [String: Any] {
      if let error = data["error"] as? String, !error.isEmpty { return error }
      if let message = data["message"] as? String, !message.isEmpty { return message }
    }
    if let code = object["code"] { return String(describing: code) }
    return "HTTP \(statusCode)"
  }
}

private struct EmptyEnvelope: Decodable {}

private struct CreateJobEnvelope: Decodable {
  let id: String?
  let jobID: String?
  let status: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case jobID = "jobId"
    case status
  }
}

private struct UploadEnvelope: Decodable {
  let uploads: [PreparedReferenceUpload]
}

private struct ReferenceLibraryEnvelope: Decodable {
  let references: [ReferenceLibraryItem]
}

private struct JobEnvelope: Decodable {
  let job: Job?
}

private struct JobsEnvelope: Decodable {
  let jobs: [Job]
}

private struct SessionEnvelope: Decodable {
  let user: CurrentUser?
}

private struct HealthEnvelope: Decodable {
  let runtime: String?
  let ok: Bool?
  let mockEnabledSnake: Bool?
  let mockEnabledCamel: Bool?
  let detail: String?
  let laf: NestedHealth?

  private enum CodingKeys: String, CodingKey {
    case runtime
    case ok
    case mockEnabledSnake = "mock_enabled"
    case mockEnabledCamel = "mockEnabled"
    case detail
    case laf
  }

  func toBackendHealth(expectedMode: BackendMode) -> BackendHealth? {
    if runtime == "gateway" {
      return BackendHealth(backendMode: .gateway, runtime: "gateway", mockEnabled: mockEnabledSnake ?? mockEnabledCamel ?? laf?.mockEnabledSnake ?? false, detail: detail ?? "")
    }
    if runtime == "laf" {
      return BackendHealth(backendMode: .laf, runtime: "laf", mockEnabled: mockEnabledSnake ?? mockEnabledCamel ?? false, detail: detail ?? "")
    }
    if expectedMode == .fastapi, ok == true {
      return BackendHealth(backendMode: .fastapi, runtime: "fastapi", mockEnabled: mockEnabledSnake ?? mockEnabledCamel ?? false, detail: detail ?? "")
    }
    if laf?.runtime == "laf" || laf?.ok == true {
      return BackendHealth(backendMode: .gateway, runtime: "gateway", mockEnabled: laf?.mockEnabledSnake ?? false, detail: detail ?? "")
    }
    return nil
  }
}

private struct NestedHealth: Decodable {
  let runtime: String?
  let ok: Bool?
  let mockEnabledSnake: Bool?

  private enum CodingKeys: String, CodingKey {
    case runtime
    case ok
    case mockEnabledSnake = "mock_enabled"
  }
}

func formatUserFacingError(_ error: Error) -> String {
  formatUserFacingError(error.localizedDescription)
}

func formatUserFacingError(_ message: String) -> String {
  if message.contains("Invalid email or password") { return "邮箱或密码不正确。" }
  if message.contains("User already exists") { return "这个邮箱已经注册，请直接登录。" }
  if message.contains("Missing API key") { return "缺少所选模型接口的 API Key。" }
  if message.contains("Incorrect API key") || message.contains("apikey-error") { return "API Key 不正确，请确认模型服务和密钥匹配。" }
  if message.contains("Please log in") || message.contains("请先登录") || message.contains("Unauthorized") { return "请先登录后再使用任务记录。" }
  if message.contains("Forbidden") { return "当前账号没有权限查看这个任务。" }
  if message.contains("timed out") || message.contains("timeout") { return "请求超时，请稍后重试。" }
  if message.contains("Network request failed") || message.contains("No such host") || message.contains("无法连接") { return "无法连接后端，请确认网络可访问 Sealos 后端地址。" }
  if message.contains("HTTP 503") { return "服务暂时不可用，请稍后重试。" }
  return message.isEmpty ? "操作失败" : message
}
