import Foundation

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
      throw PaperBananaAPIError.http(ServerErrorDetails(
        statusCode: httpResponse.statusCode,
        code: serverErrorCode(from: object),
        message: serverErrorMessage(from: object)
      ))
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

  /// 并发拉取记录详情（并发上限 4），输出顺序与输入保持一致；
  /// 单条失败时回退为原始摘要。
  private func hydrateRecordImages(apiBase: String, jobs: [Job]) async -> [Job] {
    let pending = jobs.enumerated().filter { $0.element.needsFreshRecordDetail }
    guard !pending.isEmpty else { return jobs }

    var hydrated = jobs
    await withTaskGroup(of: (Int, Job).self) { group in
      let maxConcurrent = 4
      var nextIndex = 0

      func addNextTask() {
        guard nextIndex < pending.count else { return }
        let (index, job) = pending[nextIndex]
        nextIndex += 1
        group.addTask {
          let detail = (try? await self.getJob(apiBase: apiBase, jobID: job.id)) ?? job
          return (index, detail)
        }
      }

      for _ in 0..<min(maxConcurrent, pending.count) {
        addNextTask()
      }
      for await (index, job) in group {
        hydrated[index] = job
        addNextTask()
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

  private func serverErrorMessage(from object: [String: Any]) -> String? {
    if let error = object["error"] as? String, !error.isEmpty { return error }
    if let detail = object["detail"] as? String, !detail.isEmpty { return detail }
    if let message = object["message"] as? String, !message.isEmpty { return message }
    if let error = object["error"] as? [String: Any], let message = error["message"] as? String, !message.isEmpty { return message }
    if let data = object["data"] as? [String: Any] {
      if let error = data["error"] as? String, !error.isEmpty { return error }
      if let message = data["message"] as? String, !message.isEmpty { return message }
    }
    return nil
  }

  private func serverErrorCode(from object: [String: Any]) -> String? {
    if let code = object["code"] as? String, !code.isEmpty { return code }
    if let error = object["error"] as? [String: Any], let code = error["code"] as? String, !code.isEmpty { return code }
    return nil
  }
}
