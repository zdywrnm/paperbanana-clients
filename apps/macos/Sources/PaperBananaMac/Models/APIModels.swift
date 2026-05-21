import Foundation

struct JobCreatePayload {
  let configurationMode: ConfigurationMode
  let provider: ProviderID
  let apiKey: String
  let methodContent: String
  let caption: String
  let infographicCategory: String
  let mainModelName: String
  let imageModelName: String
  let pipelineMode: String
  let retrievalSetting: String
  let aspectRatio: String
  let numCandidates: Int
  let maxCriticRounds: Int
  let mock: Bool

  func apiKeysBody() -> [String: String] {
    [
      "openrouter": provider == .openrouter ? apiKey : "",
      "gemini": provider == .gemini ? apiKey : "",
      "openai": provider == .openai ? apiKey : "",
      "bailian": provider == .bailian ? apiKey : ""
    ]
  }

  var lafPipelineMode: String {
    if pipelineMode == "demo_full" { return "full" }
    if pipelineMode == "vanilla" { return "vanilla" }
    return "planner_critic"
  }
}

struct AuthMode: Identifiable, Equatable {
  let id: String
  let title: String

  static let signIn = AuthMode(id: "sign-in", title: "登录账号")
  static let signUp = AuthMode(id: "sign-up", title: "注册账号")
}
