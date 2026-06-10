import Foundation

enum ProviderID: String, CaseIterable, Codable, Identifiable, Hashable {
  case bailian
  case openrouter
  case gemini
  case openai

  var id: String { rawValue }
}

enum ConfigurationMode: String, CaseIterable, Codable, Identifiable {
  case simple
  case advanced

  var id: String { rawValue }

  var title: String {
    switch self {
    case .simple: "普通模式"
    case .advanced: "专业模式"
    }
  }
}

enum TaskName: String, Codable, Identifiable {
  case diagram
  case plot

  var id: String { rawValue }
}

enum OutputFormat: String, CaseIterable, Codable, Identifiable {
  case png
  case svg

  var id: String { rawValue }

  var title: String {
    switch self {
    case .png: "PNG 图片"
    case .svg: "SVG 矢量图"
    }
  }
}

enum ImageSize: String, CaseIterable, Codable, Identifiable {
  case oneK = "1K"
  case twoK = "2K"
  case fourK = "4K"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .oneK: "1K 标准"
    case .twoK: "2K 高清"
    case .fourK: "4K 超清"
    }
  }
}

enum ReferenceImageMode: String, Codable, Identifiable {
  case mainModel = "main_model"
  case visionModel = "vision_model"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .mainModel: "主模型直读"
    case .visionModel: "独立识别模型"
    }
  }
}

enum PipelineMode: String, CaseIterable, Codable, Identifiable {
  case plannerCritic = "demo_planner_critic"
  case full = "demo_full"
  case vanilla

  var id: String { rawValue }

  var title: String {
    switch self {
    case .plannerCritic: "规划器 + 评审器"
    case .full: "完整流程"
    case .vanilla: "基础生成"
    }
  }

  var lafValue: String {
    switch self {
    case .plannerCritic: "planner_critic"
    case .full: "full"
    case .vanilla: "vanilla"
    }
  }
}

enum RetrievalSetting: String, CaseIterable, Codable, Identifiable {
  case none
  case auto
  case random
  case manual

  var id: String { rawValue }

  var title: String {
    switch self {
    case .none: "不使用检索"
    case .auto: "自动检索"
    case .random: "随机参考"
    case .manual: "手动参考"
    }
  }
}

enum FeedbackCategory: String, CaseIterable, Codable, Identifiable {
  case bug
  case feature
  case experience
  case other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bug: "问题反馈"
    case .feature: "功能建议"
    case .experience: "体验意见"
    case .other: "其他"
    }
  }
}

enum JobStatus: String, Codable {
  case queued
  case running
  case succeeded
  case failed
  case unknown

  var title: String {
    switch self {
    case .queued: "排队中"
    case .running: "生成中"
    case .succeeded: "已完成"
    case .failed: "失败"
    case .unknown: "未知"
    }
  }

  var isTerminal: Bool {
    self == .succeeded || self == .failed
  }
}

struct ModelOption: Identifiable, Equatable, Hashable {
  let value: String
  let label: String
  let group: String

  var id: String { value }

  var displayName: String {
    group.isEmpty ? label : "\(group) / \(label)"
  }
}

struct ProviderConfig: Identifiable, Equatable {
  let id: ProviderID
  let label: String
  let keyName: String
  let keyPlaceholder: String
  let mainModel: String
  let imageModel: String
  let visionModel: String
  let mainModels: [ModelOption]
  let imageModels: [ModelOption]
  let visionModels: [ModelOption]
  let guideURL: URL
  let guideSteps: [String]
}

struct InfographicCategory: Identifiable, Equatable, Hashable {
  let id: String
  let label: String
  let detail: String
}

struct QuickStartExample: Identifiable, Equatable {
  let id: String
  let label: String
  let title: String
  let categoryID: String
  let caption: String
  let methodContent: String
  let hint: String
}

struct GuideStep: Identifiable, Equatable {
  let id: String
  let title: String
  let detail: String
}

struct GuideTerm: Identifiable, Equatable {
  let id: String
  let name: String
  let detail: String
}

struct GuideResource: Identifiable, Equatable {
  let id: String
  let title: String
  let subtitle: String
  let systemImage: String
  let url: URL
}

struct ReferenceImageAsset: Codable, Identifiable, Equatable, Hashable {
  var filename: String
  var mimeType: String
  var size: Int
  var objectKey: String
  var uploadToken: String?
  var url: String?
  var storage: String?

  var id: String {
    objectKey.isEmpty ? filename : objectKey
  }

  var displayFormat: String {
    if mimeType.contains("svg") || filename.lowercased().hasSuffix(".svg") { return "svg" }
    if mimeType.contains("jpeg") || mimeType.contains("jpg") || filename.lowercased().hasSuffix(".jpg") || filename.lowercased().hasSuffix(".jpeg") { return "jpg" }
    if mimeType.contains("webp") || filename.lowercased().hasSuffix(".webp") { return "webp" }
    return "png"
  }

  init(
    filename: String,
    mimeType: String,
    size: Int,
    objectKey: String,
    uploadToken: String? = nil,
    url: String? = nil,
    storage: String? = nil
  ) {
    self.filename = filename
    self.mimeType = mimeType
    self.size = size
    self.objectKey = objectKey
    self.uploadToken = uploadToken
    self.url = url
    self.storage = storage
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    filename = container.string("filename", default: "reference")
    mimeType = container.string("mime_type", "mimeType", default: "")
    size = container.int("size")
    objectKey = container.string("object_key", "objectKey")
    uploadToken = container.optionalString("upload_token", "uploadToken")
    url = container.optionalString("url")
    storage = container.optionalString("storage")
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    try container.encode(filename, forKey: .key("filename"))
    try container.encode(mimeType, forKey: .key("mimeType"))
    try container.encode(size, forKey: .key("size"))
    try container.encode(objectKey, forKey: .key("objectKey"))
    try container.encodeIfPresent(uploadToken, forKey: .key("uploadToken"))
  }

  var dictionary: [String: Any] {
    var result: [String: Any] = [
      "filename": filename,
      "mimeType": mimeType,
      "size": size,
      "objectKey": objectKey
    ]
    if let uploadToken { result["uploadToken"] = uploadToken }
    return result
  }
}

struct PendingReferenceImage: Identifiable, Equatable {
  let id: String
  let filename: String
  let mimeType: String
  let data: Data

  var size: Int { data.count }
}

typealias ReferenceUploadItem = PendingReferenceImage

enum ReferenceImageLimits {
  static let maxCount = 3
  static let maxBytes = 5 * 1024 * 1024
  static let acceptedMimeTypes: Set<String> = [
    "image/png",
    "image/jpeg",
    "image/webp",
    "image/svg+xml"
  ]

  static func normalizedMimeType(filename: String, mimeType: String?) -> String {
    let value = (mimeType ?? "").lowercased()
    if acceptedMimeTypes.contains(value) { return value }
    let ext = (filename as NSString).pathExtension.lowercased()
    switch ext {
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "webp": return "image/webp"
    case "svg": return "image/svg+xml"
    default: return value
    }
  }

  static func isAccepted(filename: String, mimeType: String?, size: Int) -> Bool {
    guard size > 0, size <= maxBytes else { return false }
    return acceptedMimeTypes.contains(normalizedMimeType(filename: filename, mimeType: mimeType))
  }
}

struct JobCreatePayload {
  let configurationMode: ConfigurationMode
  let provider: ProviderID
  let apiKeys: [ProviderID: String]
  let taskName: TaskName
  let methodContent: String
  let caption: String
  let infographicCategory: String
  let outputFormat: OutputFormat
  let imageSize: ImageSize
  let mainModelName: String
  let imageModelName: String
  let referenceVisionModelName: String
  let referenceImageMode: ReferenceImageMode?
  let referenceImages: [ReferenceImageAsset]
  let pipelineMode: PipelineMode
  let retrievalSetting: RetrievalSetting
  let manualReferenceIds: [String]
  let aspectRatio: String
  let numCandidates: Int
  let maxCriticRounds: Int

  func paperBananaBody() -> [String: Any] {
    let hasUploadedReferences = !referenceImages.isEmpty
    var body: [String: Any] = [
      "action": "createJob",
      "configurationMode": configurationMode.rawValue,
      "provider": provider.rawValue,
      "apiKeys": apiKeysBody(),
      "taskName": taskName.rawValue,
      "methodContent": methodContent,
      "caption": caption,
      "infographicCategory": infographicCategory,
      "outputFormat": outputFormat.rawValue,
      "imageSize": imageSize.rawValue,
      "mainModelName": mainModelName,
      "imageModelName": imageModelName,
      "referenceVisionModelName": referenceVisionModelName,
      "referenceImages": referenceImages.map(\.dictionary),
      "pipelineMode": pipelineMode.lafValue,
      "retrievalSetting": hasUploadedReferences ? RetrievalSetting.none.rawValue : retrievalSetting.rawValue,
      "manualReferenceIds": hasUploadedReferences ? [] : manualReferenceIds,
      "aspectRatio": aspectRatio,
      "numCandidates": numCandidates,
      "maxCriticRounds": maxCriticRounds
    ]
    if hasUploadedReferences, let referenceImageMode {
      body["referenceImageMode"] = referenceImageMode.rawValue
    }
    return body
  }

  func apiKeysBody() -> [String: String] {
    Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { ($0.rawValue, apiKeys[$0] ?? "") })
  }
}

struct RefineImagePayload {
  let provider: ProviderID
  let apiKeys: [ProviderID: String]
  let mainModelName: String
  let imageModelName: String
  let referenceVisionModelName: String
  let sourceImageURL: String
  let sourceImageObjectKey: String?
  let editInstruction: String
  let aspectRatio: String
  let imageSize: ImageSize

  func paperBananaBody() -> [String: Any] {
    var body: [String: Any] = [
      "action": "refineImage",
      "provider": provider.rawValue,
      "apiKeys": Dictionary(uniqueKeysWithValues: ProviderID.allCases.map { ($0.rawValue, apiKeys[$0] ?? "") }),
      "mainModelName": mainModelName,
      "imageModelName": imageModelName,
      "referenceVisionModelName": referenceVisionModelName,
      "sourceImageUrl": sourceImageURL,
      "editInstruction": editInstruction,
      "aspectRatio": aspectRatio,
      "imageSize": imageSize.rawValue
    ]
    if let sourceImageObjectKey, !sourceImageObjectKey.isEmpty {
      body["sourceImageObjectKey"] = sourceImageObjectKey
    }
    return body
  }
}

struct ReferenceUploadFile: Encodable {
  let clientId: String
  let role: String
  let filename: String
  let mimeType: String
  let size: Int
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

struct ResultImage: Decodable, Identifiable, Equatable {
  let filename: String
  let url: String
  let storage: String
  let candidateID: Int
  let mimeType: String
  let objectKey: String

  var id: String {
    "\(candidateID)-\(filename)-\(url)"
  }

  var format: String {
    if mimeType.contains("svg") || filename.lowercased().hasSuffix(".svg") { return "svg" }
    if mimeType.contains("jpeg") || mimeType.contains("jpg") { return "jpg" }
    if mimeType.contains("webp") { return "webp" }
    return "png"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    filename = container.string("filename", default: "")
    url = container.string("url", default: "")
    storage = container.string("storage", default: "")
    candidateID = container.int("candidate_id", "candidateId")
    mimeType = container.string("mime_type", "mimeType", default: "")
    objectKey = container.string("object_key", "objectKey", default: "")
  }
}

struct ExportedResultFile: Identifiable, Equatable {
  let id = UUID()
  let url: URL
  let filename: String
}

struct JobMetadataItem: Identifiable, Equatable {
  let label: String
  let value: String

  var id: String { label }
}

struct ReferenceLibraryItem: Decodable, Identifiable, Equatable {
  let id: String
  let taskName: TaskName
  let title: String
  let summary: String
  let imageURL: String
  let imageObjectKey: String
  let source: String

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    id = container.string("id", "_id")
    taskName = TaskName(rawValue: container.string("task_name", "taskName", default: "diagram")) ?? .diagram
    title = container.string("title", "visualIntent", "caption")
    summary = container.string("summary", "content", "methodExcerpt")
    imageURL = container.string("image_url", "imageUrl", "url")
    imageObjectKey = container.string("image_object_key", "imageObjectKey", "objectKey")
    source = container.string("source", default: "paperbanana-bench")
  }
}

struct StageImage: Decodable, Equatable {
  let filename: String
  let url: String
  let storage: String
  let mimeType: String

  var displayFormat: String {
    if mimeType.contains("svg") || filename.lowercased().hasSuffix(".svg") { return "svg" }
    if mimeType.contains("jpeg") || mimeType.contains("jpg") || filename.lowercased().hasSuffix(".jpg") || filename.lowercased().hasSuffix(".jpeg") { return "jpg" }
    if mimeType.contains("webp") || filename.lowercased().hasSuffix(".webp") { return "webp" }
    return "png"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    filename = container.string("filename", default: "")
    url = container.string("url", default: "")
    storage = container.string("storage", default: "")
    mimeType = container.string("mime_type", "mimeType", default: "")
  }
}

struct JobStage: Decodable, Identifiable, Equatable {
  let id: String
  let candidateID: Int
  let type: String
  let title: String
  let round: Int
  let text: String
  let suggestion: String
  let image: StageImage?
  let error: String

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    id = container.string("id", "_id", default: UUID().uuidString)
    candidateID = container.int("candidate_id", "candidateId")
    type = container.string("type")
    title = container.string("title")
    round = container.int("round")
    text = container.string("text", "description", "message")
    suggestion = container.string("suggestion", "criticSuggestion")
    image = try container.decodeIfPresent(StageImage.self, forKey: .key("image"))
    error = container.string("error")
  }
}

struct Job: Decodable, Identifiable, Equatable {
  let id: String
  let status: String
  let provider: String
  let jobType: String
  let userID: String
  let userEmail: String
  let configurationMode: String
  let methodContent: String
  let caption: String
  let infographicCategory: String
  let outputFormat: OutputFormat
  let imageSize: ImageSize
  let mainModelName: String
  let imageModelName: String
  let referenceVisionModelName: String
  let referenceImageMode: ReferenceImageMode?
  let referenceImageModeUsed: String
  let pipelineMode: String
  let taskName: TaskName
  let retrievalSetting: RetrievalSetting
  let retrievedReferenceIDs: [String]
  let retrievedReferences: [ReferenceLibraryItem]
  let stages: [JobStage]
  let criticMode: String
  let aspectRatio: String
  let numCandidates: Int
  let maxCriticRounds: Int
  let promptCharCount: Int
  let resultImageCount: Int
  let referenceImageCount: Int
  let resultImages: [ResultImage]
  let referenceImages: [ReferenceImageAsset]
  let logsTail: String
  let error: String
  let createdAt: String
  let updatedAt: String
  let startedAt: String
  let completedAt: String

  var statusKind: JobStatus {
    JobStatus(rawValue: status) ?? .unknown
  }

  var title: String {
    if !caption.isEmpty { return caption }
    if !methodContent.isEmpty { return String(methodContent.prefix(44)) }
    return id
  }

  var failureText: String {
    let trimmedError = failureErrorText
    if !trimmedError.isEmpty { return trimmedError }
    return failureLogsText
  }

  var failureErrorText: String {
    error.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var failureLogsText: String {
    logsTail.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var metadataItems: [JobMetadataItem] {
    [
      JobMetadataItem(label: "时间", value: formattedRecordDate(createdAt)),
      JobMetadataItem(label: "模式", value: displayConfigurationMode),
      JobMetadataItem(label: "类别", value: displayValue(infographicCategory, fallback: taskName == .plot ? "数据统计图" : "方法框架图")),
      JobMetadataItem(label: "平台", value: displayProvider),
      JobMetadataItem(label: "格式", value: "\(outputFormat.title) · \(imageSize.rawValue)"),
      JobMetadataItem(label: "画面比例", value: displayValue(aspectRatio)),
      JobMetadataItem(label: "检索", value: retrievalSetting.title),
      JobMetadataItem(label: "参考图处理", value: displayReferenceImageMode),
      JobMetadataItem(label: "主模型", value: displayValue(mainModelName)),
      JobMetadataItem(label: "图像生成模型", value: displayValue(imageModelName)),
      JobMetadataItem(label: "参考图识别模型", value: displayReferenceVisionModel),
      JobMetadataItem(label: "评审模式", value: displayCriticMode),
      JobMetadataItem(label: "候选图", value: "\(numCandidates > 0 ? numCandidates : max(resultImageCount, resultImages.count)) 张"),
      JobMetadataItem(label: "阶段", value: "\(stages.count) 个")
    ]
  }

  var needsFreshRecordDetail: Bool {
    let hasResult = resultImageCount > 0 || !resultImages.isEmpty
    let hasReference = referenceImageCount > 0 || !referenceImages.isEmpty
    let allURLs = resultImages.map(\.url) + referenceImages.compactMap(\.url)
    let hasBucketImage = resultImages.contains { $0.storage == "bucket" } || referenceImages.contains { $0.storage == "bucket" }
    let hasRemoteSignedURL = allURLs.contains { !$0.isEmpty && !$0.hasPrefix("data:") }

    if statusKind != .succeeded && !hasReference { return false }
    return hasResult || hasReference || hasBucketImage || hasRemoteSignedURL
  }

  var visibleReferenceImages: [ReferenceImageAsset] {
    referenceImages.filter { !($0.url ?? "").isEmpty }
  }

  init(id: String, status: String) {
    self.id = id
    self.status = status
    provider = ""
    jobType = "generate"
    userID = ""
    userEmail = ""
    configurationMode = ""
    methodContent = ""
    caption = ""
    infographicCategory = ""
    outputFormat = .png
    imageSize = .oneK
    mainModelName = ""
    imageModelName = ""
    referenceVisionModelName = ""
    referenceImageMode = nil
    referenceImageModeUsed = ""
    pipelineMode = ""
    taskName = .diagram
    retrievalSetting = .none
    retrievedReferenceIDs = []
    retrievedReferences = []
    stages = []
    criticMode = ""
    aspectRatio = ""
    numCandidates = 0
    maxCriticRounds = 0
    promptCharCount = 0
    resultImageCount = 0
    referenceImageCount = 0
    resultImages = []
    referenceImages = []
    logsTail = ""
    error = ""
    createdAt = ""
    updatedAt = ""
    startedAt = ""
    completedAt = ""
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    id = container.string("id", "_id")
    status = container.string("status", default: "unknown")
    provider = container.string("provider")
    jobType = container.string("job_type", "jobType", default: "generate")
    userID = container.string("user_id", "userId")
    userEmail = container.string("user_email", "userEmail")
    configurationMode = container.string("configuration_mode", "configurationMode", default: "advanced")
    methodContent = container.string("method_content", "methodContent")
    caption = container.string("caption")
    infographicCategory = container.string("infographic_category", "infographicCategory", default: "方法框架图")
    outputFormat = OutputFormat(rawValue: container.string("output_format", "outputFormat", default: "png")) ?? .png
    imageSize = ImageSize(rawValue: container.string("image_size", "imageSize", default: "1K")) ?? .oneK
    mainModelName = container.string("main_model_name", "mainModelName")
    imageModelName = container.string("image_gen_model_name", "imageModelName", "imageGenModelName")
    referenceVisionModelName = container.string("reference_vision_model_name", "referenceVisionModelName")
    referenceImageMode = ReferenceImageMode(rawValue: container.string("reference_image_mode", "referenceImageMode"))
    referenceImageModeUsed = container.string("reference_image_mode_used", "referenceImageModeUsed")
    pipelineMode = container.string("pipeline_mode", "pipelineMode")
    taskName = TaskName(rawValue: container.string("task_name", "taskName", default: "diagram")) ?? .diagram
    retrievalSetting = RetrievalSetting(rawValue: container.string("retrieval_setting", "retrievalSetting", default: "none")) ?? .none
    retrievedReferenceIDs = container.stringArray("retrieved_reference_ids", "retrievedReferenceIds")
    retrievedReferences = container.decodeArray("retrieved_references", "retrievedReferences")
    stages = container.decodeArray("stages")
    criticMode = container.string("critic_mode", "criticMode")
    aspectRatio = container.string("aspect_ratio", "aspectRatio")
    numCandidates = container.int("num_candidates", "numCandidates")
    maxCriticRounds = container.int("max_critic_rounds", "maxCriticRounds")
    promptCharCount = container.int("prompt_char_count", "promptCharCount")
    resultImages = container.decodeArray("result_images", "resultImages")
    resultImageCount = container.int("result_image_count", "resultImageCount", default: resultImages.count)
    referenceImages = container.decodeArray("reference_images", "referenceImages")
    referenceImageCount = container.int("reference_image_count", "referenceImageCount", default: referenceImages.count)
    let rawLogsTail = container.string("logs_tail", "logsTail")
    let logsArrayTail = container.logsString("logs")
    logsTail = [rawLogsTail, logsArrayTail]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    error = container.string("error")
    createdAt = container.string("created_at", "createdAt")
    updatedAt = container.string("updated_at", "updatedAt")
    startedAt = container.string("started_at", "startedAt")
    completedAt = container.string("completed_at", "completedAt")
  }

  private var displayProvider: String {
    if let providerID = ProviderID(rawValue: provider) {
      return ProviderCatalog.config(for: providerID).label
    }
    return displayValue(provider)
  }

  private var displayConfigurationMode: String {
    switch configurationMode {
    case "simple":
      return "普通模式"
    case "advanced":
      return "专业模式"
    default:
      return "未记录"
    }
  }

  private var displayReferenceImageMode: String {
    let rawMode = referenceImageModeUsed.isEmpty ? referenceImageMode?.rawValue ?? "" : referenceImageModeUsed
    switch rawMode {
    case ReferenceImageMode.mainModel.rawValue:
      return ReferenceImageMode.mainModel.title
    case ReferenceImageMode.visionModel.rawValue:
      return ReferenceImageMode.visionModel.title
    case "auto":
      return "自动选择"
    case "none":
      return "未使用参考图"
    default:
      return "未记录"
    }
  }

  private var displayReferenceVisionModel: String {
    let rawMode = referenceImageModeUsed.isEmpty ? referenceImageMode?.rawValue ?? "" : referenceImageModeUsed
    guard rawMode == ReferenceImageMode.visionModel.rawValue else { return "未使用" }
    return displayValue(referenceVisionModelName)
  }

  private var displayCriticMode: String {
    switch criticMode {
    case "image":
      return "图像评审"
    case "text":
      return "文本评审"
    default:
      return "未记录"
    }
  }

  private func displayValue(_ value: String, fallback: String = "未记录") -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
  }

  private func formattedRecordDate(_ value: String) -> String {
    guard !value.isEmpty else { return "未记录" }
    let normalized = value.replacingOccurrences(of: "T", with: " ")
    return String(normalized.prefix(16))
  }
}

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

struct ModelCapability: Decodable, Equatable {
  let status: String
  let supportsReferenceImages: Bool
  let reason: String
  let source: String
  let cached: Bool

  init(
    status: String,
    supportsReferenceImages: Bool,
    reason: String,
    source: String,
    cached: Bool
  ) {
    self.status = status
    self.supportsReferenceImages = supportsReferenceImages
    self.reason = reason
    self.source = source
    self.cached = cached
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    status = container.string("status", default: "unknown")
    supportsReferenceImages = container.bool("supportsReferenceImages", "supports_reference_images")
    reason = container.string("reason")
    source = container.string("source")
    cached = container.bool("cached")
  }
}

struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }

  static func key(_ value: String) -> DynamicCodingKey {
    DynamicCodingKey(stringValue: value)!
  }
}

extension KeyedDecodingContainer where Key == DynamicCodingKey {
  func string(_ keys: String..., default defaultValue: String = "") -> String {
    for key in keys {
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)) {
        return value
      }
      if let intValue = try? decodeIfPresent(Int.self, forKey: .key(key)) {
        return String(intValue)
      }
    }
    return defaultValue
  }

  func optionalString(_ keys: String...) -> String? {
    for key in keys {
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)) {
        return value
      }
    }
    return nil
  }

  func int(_ keys: String..., default defaultValue: Int = 0) -> Int {
    for key in keys {
      if let value = try? decodeIfPresent(Int.self, forKey: .key(key)) {
        return value
      }
      if let value = try? decodeIfPresent(Double.self, forKey: .key(key)) {
        return Int(value)
      }
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)), let parsed = Int(value) {
        return parsed
      }
    }
    return defaultValue
  }

  func stringArray(_ keys: String...) -> [String] {
    for key in keys {
      if let value = try? decodeIfPresent([String].self, forKey: .key(key)) {
        return value
      }
    }
    return []
  }

  func bool(_ keys: String..., default defaultValue: Bool = false) -> Bool {
    for key in keys {
      if let value = try? decodeIfPresent(Bool.self, forKey: .key(key)) {
        return value
      }
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)) {
        let normalized = value.lowercased()
        if ["true", "1", "yes"].contains(normalized) { return true }
        if ["false", "0", "no"].contains(normalized) { return false }
      }
    }
    return defaultValue
  }

  func decodeArray<T: Decodable>(_ keys: String...) -> [T] {
    for key in keys {
      if let value = try? decodeIfPresent([T].self, forKey: .key(key)) {
        return value
      }
    }
    return []
  }

  func logsString(_ key: String) -> String {
    guard let logs = try? decodeIfPresent([String].self, forKey: .key(key)), !logs.isEmpty else {
      return ""
    }
    let suffix = logs.suffix(10).joined(separator: "\n")
    return suffix.isEmpty ? "" : "\n\(suffix)"
  }
}
