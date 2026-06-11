import Foundation

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
