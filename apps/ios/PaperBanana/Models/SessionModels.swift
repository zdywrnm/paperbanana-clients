import Foundation

struct CurrentUser: Decodable, Equatable {
  let id: String
  let email: String
  let name: String

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    id = container.string("id", "_id")
    email = container.string("email")
    name = container.string("name", default: email)
  }
}

enum BackendMode: String, Equatable {
  case gateway
  case laf
  case fastapi
}

struct BackendHealth: Equatable {
  let backendMode: BackendMode
  let runtime: String
  let mockEnabled: Bool
  let detail: String
}
