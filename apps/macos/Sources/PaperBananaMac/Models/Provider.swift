import Foundation

enum ProviderID: String, CaseIterable, Codable, Identifiable {
  case bailian
  case openrouter
  case gemini
  case openai

  var id: String { rawValue }
}

struct ProviderConfig: Identifiable, Equatable {
  let id: ProviderID
  let label: String
  let keyName: String
  let keyPlaceholder: String
  let mainModel: String
  let imageModel: String
  let guideURL: URL
}

enum ProviderCatalog {
  static let providers: [ProviderID: ProviderConfig] = [
    .bailian: ProviderConfig(
      id: .bailian,
      label: "阿里百炼",
      keyName: "bailian",
      keyPlaceholder: "sk-...",
      mainModel: "qwen-plus",
      imageModel: "wan2.7-image",
      guideURL: URL(string: "https://help.aliyun.com/zh/model-studio/get-api-key")!
    ),
    .openrouter: ProviderConfig(
      id: .openrouter,
      label: "OpenRouter",
      keyName: "openrouter",
      keyPlaceholder: "sk-or-v1-...",
      mainModel: "openrouter/google/gemini-3.1-pro-preview",
      imageModel: "openrouter/google/gemini-3.1-flash-image-preview",
      guideURL: URL(string: "https://openrouter.ai/settings/keys")!
    ),
    .gemini: ProviderConfig(
      id: .gemini,
      label: "Gemini",
      keyName: "gemini",
      keyPlaceholder: "AIza...",
      mainModel: "gemini-3.1-pro-preview",
      imageModel: "gemini-3.1-flash-image-preview",
      guideURL: URL(string: "https://aistudio.google.com/app/apikey")!
    ),
    .openai: ProviderConfig(
      id: .openai,
      label: "OpenAI",
      keyName: "openai",
      keyPlaceholder: "sk-...",
      mainModel: "gpt-4o",
      imageModel: "gpt-image-1",
      guideURL: URL(string: "https://platform.openai.com/api-keys")!
    )
  ]

  static let order: [ProviderID] = [.bailian, .openrouter, .gemini, .openai]

  static func config(for id: ProviderID) -> ProviderConfig {
    providers[id] ?? providers[.bailian]!
  }
}
