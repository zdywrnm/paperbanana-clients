import Foundation

struct EmptyEnvelope: Decodable {}

struct CreateJobEnvelope: Decodable {
  let id: String?
  let jobID: String?
  let status: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case jobID = "jobId"
    case status
  }
}

struct PreparedReferenceUpload: Decodable {
  let clientId: String
  let uploadURL: String
  let objectKey: String
  let uploadToken: String?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    clientId = container.string("clientId", "client_id")
    uploadURL = container.string("uploadUrl", "uploadURL", "upload_url")
    objectKey = container.string("objectKey", "object_key")
    uploadToken = container.optionalString("uploadToken", "upload_token")
  }
}

struct UploadEnvelope: Decodable {
  let uploads: [PreparedReferenceUpload]
}

struct ReferenceLibraryEnvelope: Decodable {
  let references: [ReferenceLibraryItem]
}

struct JobEnvelope: Decodable {
  let job: Job?
}

struct JobsEnvelope: Decodable {
  let jobs: [Job]
}

struct SessionEnvelope: Decodable {
  let user: CurrentUser?
}

struct HealthEnvelope: Decodable {
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

struct NestedHealth: Decodable {
  let runtime: String?
  let ok: Bool?
  let mockEnabledSnake: Bool?

  private enum CodingKeys: String, CodingKey {
    case runtime
    case ok
    case mockEnabledSnake = "mock_enabled"
  }
}
