import Foundation
import Observation

/// 生成任务的草稿编辑、能力检查、提交与精修。
@Observable
@MainActor
final class GenerationStore {
  var draft = GenerationDraft()
  var selectedAPIKey = ""
  var mainModelCapability: ModelCapability?

  var isSubmitting = false
  var submitError = ""

  var referenceLibrary: [ReferenceLibraryItem] = []
  var referenceLibraryError = ""
  var referenceLibraryLoading = false
  var referenceUploadError = ""

  var refineInstruction = ""
  var refineAspectRatio = "16:9"
  var refineImageSize: ImageSize = .twoK
  var refineSourceImage: ResultImage?
  var refineJobID = ""

  /// 错误弹窗（由 AppModel 注入的跨域门面）。
  /// 默认实现 debug 下断言提醒忘记接线（release 下仍是 no-op），避免错误静默丢失。
  @ObservationIgnored var presentAlert: (String) -> Void = { message in
    assertionFailure("presentAlert not wired: \(message)")
  }

  private let apiClient: PaperBananaAPIClient
  private let settings: SettingsStore
  private let jobs: JobsStore
  private let keychain = KeychainService()
  private let referenceUploader: ReferenceUploader
  private static let referenceLibraryLimit = 100

  init(apiClient: PaperBananaAPIClient, settings: SettingsStore, jobs: JobsStore) {
    self.apiClient = apiClient
    self.settings = settings
    self.jobs = jobs
    referenceUploader = ReferenceUploader(apiClient: apiClient)
    loadSelectedProviderKey()
  }

  // MARK: - 派生状态

  var selectedProviderConfig: ProviderConfig {
    ProviderCatalog.config(for: draft.provider)
  }

  var canSubmit: Bool {
    !isSubmitting
      && draft.methodContent.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
      && draft.caption.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
      && !selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && hasRequiredManualReferences
      && hasRequiredReferenceVisionModel
      && !mainModelDirectUnsupported
  }

  var activeMainModelName: String {
    draft.configurationMode == .advanced ? draft.mainModelName : selectedProviderConfig.mainModel
  }

  var activeImageModelName: String {
    draft.configurationMode == .advanced ? draft.imageModelName : selectedProviderConfig.imageModel
  }

  var activeVisionModelName: String {
    draft.configurationMode == .advanced ? draft.referenceVisionModelName : selectedProviderConfig.visionModel
  }

  var refineSupportedImageSizes: [ImageSize] {
    ProviderCatalog.supportedResolutions(provider: draft.provider, imageModel: activeImageModelName)
  }

  var activeReferenceImageMode: ReferenceImageMode? {
    guard !draft.referenceImages.isEmpty else { return nil }
    if draft.configurationMode == .advanced { return draft.referenceImageMode }
    return ProviderCatalog.mainModelCanReadImages(provider: draft.provider, model: activeMainModelName) ? .mainModel : .visionModel
  }

  var mainModelCanReadReferenceImages: Bool {
    ProviderCatalog.mainModelCanReadImages(provider: draft.provider, model: activeMainModelName)
  }

  var modelCapabilityQueryID: String {
    [
      settings.apiBase,
      draft.provider.rawValue,
      activeMainModelName,
      String(draft.referenceImages.count),
      settings.health?.runtime ?? ""
    ].joined(separator: "|")
  }

  var mainModelDirectUnsupported: Bool {
    !draft.referenceImages.isEmpty
      && activeReferenceImageMode == .mainModel
      && !mainModelCanReadReferenceImages
  }

  var needsReferenceVisionModel: Bool {
    !draft.referenceImages.isEmpty && activeReferenceImageMode != .mainModel
  }

  var hasRequiredReferenceVisionModel: Bool {
    !needsReferenceVisionModel || !activeVisionModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var hasRequiredManualReferences: Bool {
    draft.configurationMode != .advanced
      || draft.retrievalSetting != .manual
      || !draft.referenceImages.isEmpty
      || !draft.manualReferenceIds.isEmpty
  }

  var referenceCapabilityNote: String {
    guard !draft.referenceImages.isEmpty else { return "" }
    if let capability = mainModelCapability {
      switch capability.status {
      case "loading":
        return capability.reason.isEmpty ? "正在检查当前主模型是否支持直接理解参考图。" : capability.reason
      case "supported":
        return "网关确认当前主模型支持图像理解，可用主模型直读参考图。"
      case "unsupported":
        return "网关确认当前主模型不支持直接理解参考图，请使用独立识别模型。"
      default:
        if !capability.reason.isEmpty {
          return "\(localReferenceCapabilityNote)（能力查询：\(capability.reason)）"
        }
      }
    }
    return localReferenceCapabilityNote
  }

  private var localReferenceCapabilityNote: String {
    if mainModelCanReadReferenceImages {
      return "当前主模型支持图像理解，可用主模型直读参考图。"
    }
    return "当前主模型不能直读参考图，请使用独立识别模型。"
  }

  // MARK: - 草稿操作

  func selectProvider(_ provider: ProviderID) {
    saveSelectedProviderKey()
    draft.applyProviderDefaults(provider)
    mainModelCapability = nil
    alignReferenceImageModeWithActiveMainModel()
    ensureSupportedImageSize()
    ensureSupportedRefineImageSize()
    loadSelectedProviderKey()
  }

  func selectMainModel(_ modelName: String) {
    draft.mainModelName = modelName
    mainModelCapability = nil
    alignReferenceImageModeWithActiveMainModel()
  }

  func selectImageModel(_ modelName: String) {
    draft.imageModelName = modelName
    ensureSupportedImageSize()
    ensureSupportedRefineImageSize()
  }

  func updateSelectedAPIKey(_ value: String) {
    selectedAPIKey = value
    saveSelectedProviderKey()
  }

  func addReferenceFile(filename: String, mimeType: String?, data: Data) {
    referenceUploadError = ""
    guard draft.referenceImages.count < ReferenceImageLimits.maxCount else {
      referenceUploadError = "最多只能上传 \(ReferenceImageLimits.maxCount) 张参考图。"
      return
    }
    let normalized = ReferenceImageLimits.normalizedMimeType(filename: filename, mimeType: mimeType)
    guard ReferenceImageLimits.isAccepted(filename: filename, mimeType: normalized, size: data.count) else {
      referenceUploadError = "参考图仅支持 PNG、JPG、WebP 或 SVG，且单张不能超过 5MB。"
      return
    }
    draft.referenceImages.append(PendingReferenceImage(id: UUID().uuidString, filename: filename, mimeType: normalized, data: data))
    if !draft.referenceImages.isEmpty {
      draft.retrievalSetting = .none
      draft.manualReferenceIds = []
    }
    mainModelCapability = nil
  }

  func removeReferenceImage(_ image: PendingReferenceImage) {
    draft.referenceImages.removeAll { $0.id == image.id }
    if draft.referenceImages.isEmpty {
      mainModelCapability = nil
    }
  }

  func toggleManualReference(_ reference: ReferenceLibraryItem) {
    if draft.manualReferenceIds.contains(reference.id) {
      draft.manualReferenceIds.removeAll { $0 == reference.id }
    } else if draft.manualReferenceIds.count < 10 {
      draft.manualReferenceIds.append(reference.id)
    }
  }

  // MARK: - 网络操作

  func refreshMainModelCapability() async {
    guard !draft.referenceImages.isEmpty else {
      mainModelCapability = nil
      return
    }

    let provider = draft.provider
    let modelName = activeMainModelName
    mainModelCapability = ModelCapability(
      status: "loading",
      supportsReferenceImages: mainModelCanReadReferenceImages,
      reason: "正在检查主模型能力。",
      source: "ios",
      cached: false
    )

    do {
      let capability = try await apiClient.modelCapability(apiBase: settings.apiBase, provider: provider, model: modelName)
      guard provider == draft.provider, modelName == activeMainModelName, !draft.referenceImages.isEmpty else { return }
      mainModelCapability = capability
    } catch {
      guard provider == draft.provider, modelName == activeMainModelName, !draft.referenceImages.isEmpty else { return }
      mainModelCapability = ModelCapability(
        status: "unknown",
        supportsReferenceImages: mainModelCanReadReferenceImages,
        reason: formatUserFacingError(error),
        source: "client-error",
        cached: false
      )
    }
  }

  func loadReferenceLibrary() async {
    referenceLibraryError = ""
    referenceLibraryLoading = true
    defer { referenceLibraryLoading = false }
    do {
      referenceLibrary = try await apiClient.referenceLibrary(apiBase: settings.apiBase, taskName: draft.taskName, limit: Self.referenceLibraryLimit)
    } catch {
      referenceLibraryError = formatUserFacingError(error)
    }
  }

  func submitJob() async {
    guard canSubmit else { return }
    saveSelectedProviderKey()
    isSubmitting = true
    submitError = ""
    jobs.currentJob = nil
    defer { isSubmitting = false }

    do {
      let uploaded = try await referenceUploader.upload(draft.referenceImages, apiBase: settings.apiBase)
      let payload = JobCreatePayload(
        configurationMode: draft.configurationMode,
        provider: draft.provider,
        apiKeys: [draft.provider: selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)],
        taskName: draft.taskName,
        methodContent: draft.methodContent.trimmingCharacters(in: .whitespacesAndNewlines),
        caption: draft.caption.trimmingCharacters(in: .whitespacesAndNewlines),
        infographicCategory: draft.selectedCategory.label,
        outputFormat: draft.outputFormat,
        imageSize: draft.imageSize,
        mainModelName: activeMainModelName,
        imageModelName: activeImageModelName,
        referenceVisionModelName: activeVisionModelName,
        referenceImageMode: activeReferenceImageMode,
        referenceImages: uploaded,
        pipelineMode: draft.configurationMode == .advanced ? draft.pipelineMode : .plannerCritic,
        retrievalSetting: draft.configurationMode == .advanced ? draft.retrievalSetting : .none,
        manualReferenceIds: draft.configurationMode == .advanced ? draft.manualReferenceIds : [],
        aspectRatio: draft.configurationMode == .advanced ? draft.aspectRatio : "16:9",
        numCandidates: draft.configurationMode == .advanced ? draft.numCandidates : 1,
        maxCriticRounds: draft.configurationMode == .advanced ? draft.maxCriticRounds : 1
      )
      let created = try await apiClient.createJob(apiBase: settings.apiBase, payload: payload)
      guard !created.id.isEmpty else { throw PaperBananaAPIError.server("后端没有返回任务 ID。") }
      jobs.track(jobID: created.id, status: created.status)
      await jobs.loadUserJobs(silent: true)
    } catch {
      submitError = formatUserFacingError(error)
    }
  }

  func beginRefine(_ image: ResultImage) {
    refineInstruction = ""
    refineAspectRatio = draft.configurationMode == .advanced ? draft.aspectRatio : "16:9"
    refineImageSize = refineSupportedImageSizes.contains(draft.imageSize) ? draft.imageSize : (refineSupportedImageSizes.first ?? .oneK)
    refineSourceImage = image
  }

  func refine(image: ResultImage) async {
    guard !refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    do {
      let payload = RefineImagePayload(
        provider: draft.provider,
        apiKeys: [draft.provider: selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)],
        mainModelName: activeMainModelName,
        imageModelName: activeImageModelName,
        referenceVisionModelName: activeVisionModelName,
        sourceImageURL: image.url,
        sourceImageObjectKey: image.objectKey,
        editInstruction: refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
        aspectRatio: refineAspectRatio,
        imageSize: refineImageSize
      )
      let created = try await apiClient.refineImage(apiBase: settings.apiBase, payload: payload)
      refineJobID = created.id
      jobs.track(jobID: created.id, status: created.status)
    } catch {
      presentAlert(formatUserFacingError(error))
    }
  }

  // MARK: - 私有

  private func alignReferenceImageModeWithActiveMainModel() {
    draft.referenceImageMode = mainModelCanReadReferenceImages ? .mainModel : .visionModel
  }

  private func ensureSupportedImageSize() {
    let supported = ProviderCatalog.supportedResolutions(provider: draft.provider, imageModel: activeImageModelName)
    if !supported.contains(draft.imageSize) {
      draft.imageSize = supported.first ?? .oneK
    }
  }

  private func ensureSupportedRefineImageSize() {
    let supported = refineSupportedImageSizes
    if !supported.contains(refineImageSize) {
      refineImageSize = supported.first ?? .oneK
    }
  }

  private func loadSelectedProviderKey() {
    selectedAPIKey = (try? keychain.string(for: selectedProviderConfig.keyName)) ?? ""
  }

  private func saveSelectedProviderKey() {
    do {
      try keychain.set(selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines), for: selectedProviderConfig.keyName)
    } catch {
      presentAlert(formatUserFacingError(error))
    }
  }
}
