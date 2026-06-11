import Foundation
import Observation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
  case generate
  case records
  case guide
  case templates
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .generate: "生成"
    case .records: "记录"
    case .guide: "指南"
    case .templates: "模板"
    case .settings: "设置"
    }
  }

  var symbol: String {
    switch self {
    case .generate: "wand.and.stars"
    case .records: "clock.arrow.circlepath"
    case .guide: "book"
    case .templates: "doc.text.magnifyingglass"
    case .settings: "gearshape"
    }
  }
}

struct GenerationDraft: Equatable {
  var configurationMode: ConfigurationMode = .simple
  var provider: ProviderID = .bailian
  var methodContent: String = PaperBananaSamples.sampleMethod
  var caption: String = "图 1：所提出的多智能体学术图示生成框架总览。"
  var infographicCategoryID: String = "method_framework"
  var outputFormat: OutputFormat = .png
  var imageSize: ImageSize = .oneK
  var mainModelName: String = ProviderCatalog.config(for: .bailian).mainModel
  var imageModelName: String = ProviderCatalog.config(for: .bailian).imageModel
  var referenceVisionModelName: String = ProviderCatalog.config(for: .bailian).visionModel
  var referenceImageMode: ReferenceImageMode = .visionModel
  var referenceImages: [PendingReferenceImage] = []
  var pipelineMode: PipelineMode = .plannerCritic
  var retrievalSetting: RetrievalSetting = .none
  var manualReferenceIds: [String] = []
  var aspectRatio: String = "16:9"
  var numCandidates: Int = 1
  var maxCriticRounds: Int = 1

  var selectedCategory: InfographicCategory {
    PaperBananaSamples.categories.first { $0.id == infographicCategoryID } ?? PaperBananaSamples.categories[0]
  }

  var taskName: TaskName {
    infographicCategoryID == "data_stat" ? .plot : .diagram
  }

  mutating func applyProviderDefaults(_ provider: ProviderID) {
    self.provider = provider
    let config = ProviderCatalog.config(for: provider)
    mainModelName = config.mainModel
    imageModelName = config.imageModel
    referenceVisionModelName = config.visionModel
    let supported = ProviderCatalog.supportedResolutions(provider: provider, imageModel: imageModelName)
    if !supported.contains(imageSize) {
      imageSize = supported.first ?? .oneK
    }
  }
}

@Observable
@MainActor
final class AppModel {
  var selectedTab: AppTab = .generate
  var draft = GenerationDraft()
  var apiBase: String {
    didSet {
      apiBase = AppDefaults.normalizedAPIBase(apiBase)
      UserDefaults.standard.set(apiBase, forKey: AppDefaults.apiBaseKey)
    }
  }

  var selectedAPIKey = ""
  var health: BackendHealth?
  var healthError = ""
  var currentUser: CurrentUser?
  var sessionPending = false

  var authMode: String = "sign-in"
  var authEmail = ""
  var authPassword = ""
  var authName = ""
  var authError = ""
  var authSubmitting = false

  var isSubmitting = false
  var submitError = ""
  var currentJobID = ""
  var currentJob: Job?
  var userJobs: [Job] = []
  var selectedRecordID: Job.ID?
  var recordsError = ""
  var recordsLoading = false

  var referenceLibrary: [ReferenceLibraryItem] = []
  var referenceLibraryError = ""
  var referenceLibraryLoading = false
  var referenceUploadError = ""
  var mainModelCapability: ModelCapability?

  var feedbackCategory: FeedbackCategory = .experience
  var feedbackMessage = ""
  var feedbackContact = ""
  var feedbackError = ""
  var feedbackSuccess = false
  var feedbackSubmitting = false

  var refineInstruction = ""
  var refineAspectRatio = "16:9"
  var refineImageSize: ImageSize = .twoK
  var refineSourceImage: ResultImage?
  var refineJobID = ""
  var exportedResultFile: ExportedResultFile?
  var exportingResultImageID: ResultImage.ID?
  var exportingReferenceImageID: ReferenceImageAsset.ID?
  var exportingStageImageID: JobStage.ID?
  var exportingJobArchiveID: Job.ID?
  var alertMessage = ""
  var isAlertPresented = false

  private let apiClient: PaperBananaAPIClient
  private let keychain = KeychainService()
  private var pollingTask: Task<Void, Never>?

  init(apiClient: PaperBananaAPIClient? = nil) {
    self.apiClient = apiClient ?? PaperBananaAPIClient()
    let storedBase = UserDefaults.standard.string(forKey: AppDefaults.apiBaseKey) ?? AppDefaults.sealosAPIBase
    apiBase = AppDefaults.normalizedAPIBase(storedBase)
    loadSelectedProviderKey()
  }

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

  var canSubmitFeedback: Bool {
    let messageLength = feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).count
    return !feedbackSubmitting && (1...2000).contains(messageLength)
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
      apiBase,
      draft.provider.rawValue,
      activeMainModelName,
      String(draft.referenceImages.count),
      health?.runtime ?? ""
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

  func bootstrap() async {
    await refreshHealth()
    await refreshSession()
    if currentUser != nil {
      await loadUserJobs(silent: true)
    }
  }

  func refreshHealth() async {
    healthError = ""
    do {
      health = try await apiClient.fetchBackendHealth(apiBase: apiBase)
    } catch {
      health = nil
      healthError = formatUserFacingError(error)
    }
  }

  func refreshSession() async {
    sessionPending = true
    defer { sessionPending = false }
    currentUser = try? await apiClient.getSession(apiBase: apiBase)
  }

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

  func beginRefine(_ image: ResultImage) {
    refineInstruction = ""
    refineAspectRatio = draft.configurationMode == .advanced ? draft.aspectRatio : "16:9"
    refineImageSize = refineSupportedImageSizes.contains(draft.imageSize) ? draft.imageSize : (refineSupportedImageSizes.first ?? .oneK)
    refineSourceImage = image
  }

  func applyExample(_ example: QuickStartExample) {
    draft.infographicCategoryID = example.categoryID
    draft.methodContent = example.methodContent
    draft.caption = example.caption
    selectedTab = .generate
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
      let capability = try await apiClient.modelCapability(apiBase: apiBase, provider: provider, model: modelName)
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
      referenceLibrary = try await apiClient.referenceLibrary(apiBase: apiBase, taskName: draft.taskName)
    } catch {
      referenceLibraryError = formatUserFacingError(error)
    }
  }

  func toggleManualReference(_ reference: ReferenceLibraryItem) {
    if draft.manualReferenceIds.contains(reference.id) {
      draft.manualReferenceIds.removeAll { $0 == reference.id }
    } else if draft.manualReferenceIds.count < 10 {
      draft.manualReferenceIds.append(reference.id)
    }
  }

  func submitJob() async {
    guard canSubmit else { return }
    saveSelectedProviderKey()
    isSubmitting = true
    submitError = ""
    currentJob = nil
    defer { isSubmitting = false }

    do {
      let uploaded = try await uploadReferenceImages()
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
      let created = try await apiClient.createJob(apiBase: apiBase, payload: payload)
      guard !created.id.isEmpty else { throw PaperBananaAPIError.server("后端没有返回任务 ID。") }
      currentJobID = created.id
      currentJob = Job(id: created.id, status: created.status)
      startPolling(jobID: created.id)
      if currentUser != nil { await loadUserJobs(silent: true) }
    } catch {
      submitError = formatUserFacingError(error)
    }
  }

  func loadCurrentJob() async {
    guard !currentJobID.isEmpty else { return }
    do {
      currentJob = try await apiClient.getJob(apiBase: apiBase, jobID: currentJobID)
    } catch {
      submitError = formatUserFacingError(error)
    }
  }

  func loadUserJobs(silent: Bool) async {
    guard currentUser != nil else { return }
    if !silent {
      recordsError = ""
      recordsLoading = true
    }
    defer { recordsLoading = false }
    do {
      userJobs = try await apiClient.userJobs(apiBase: apiBase)
      selectedRecordID = selectedRecordID ?? userJobs.first?.id
    } catch {
      recordsError = formatUserFacingError(error)
    }
  }

  func signInOrSignUp() async {
    guard !authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, authPassword.count >= 8 else {
      authError = "请输入邮箱和至少 8 位密码。"
      return
    }
    authSubmitting = true
    authError = ""
    defer { authSubmitting = false }
    do {
      let email = authEmail.trimmingCharacters(in: .whitespacesAndNewlines)
      if authMode == "sign-up" {
        let name = authName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(email.split(separator: "@").first ?? "PaperBanana") : authName
        try await apiClient.signUp(apiBase: apiBase, email: email, password: authPassword, name: name)
      } else {
        try await apiClient.signIn(apiBase: apiBase, email: email, password: authPassword)
      }
      authPassword = ""
      await refreshSession()
      await loadUserJobs(silent: true)
    } catch {
      authError = formatUserFacingError(error)
    }
  }

  func signOut() async {
    await apiClient.signOut(apiBase: apiBase)
    currentUser = nil
    userJobs = []
    selectedRecordID = nil
  }

  func submitFeedback() async {
    guard canSubmitFeedback else {
      feedbackError = feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? "请先填写反馈内容。"
        : "反馈内容不能超过 2000 字。"
      return
    }
    feedbackSubmitting = true
    feedbackError = ""
    feedbackSuccess = false
    defer { feedbackSubmitting = false }
    do {
      try await apiClient.submitFeedback(
        apiBase: apiBase,
        message: feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines),
        category: feedbackCategory,
        jobID: currentJob?.id,
        contact: feedbackContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : feedbackContact
      )
      feedbackMessage = ""
      feedbackSuccess = true
    } catch {
      feedbackError = formatUserFacingError(error)
    }
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
      let created = try await apiClient.refineImage(apiBase: apiBase, payload: payload)
      refineJobID = created.id
      currentJobID = created.id
      currentJob = Job(id: created.id, status: created.status)
      startPolling(jobID: created.id)
    } catch {
      alertMessage = formatUserFacingError(error)
      isAlertPresented = true
    }
  }

  func resolvedImageURL(_ url: String) -> URL? {
    apiClient.resolvedImageURL(apiBase: apiBase, url: url)
  }

  func exportResultImage(_ image: ResultImage, outputFormat: OutputFormat) async {
    exportingResultImageID = image.id
    defer { exportingResultImageID = nil }

    do {
      guard let resolvedURL = resolvedImageURL(image.url) else {
        throw PaperBananaAPIError.invalidURL(image.url)
      }
      let data = try await resultImageData(from: resolvedURL)
      let filename = exportFilename(for: image, outputFormat: outputFormat)
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PaperBananaExports", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let fileURL = directory.appendingPathComponent(filename)
      try data.write(to: fileURL, options: .atomic)
      exportedResultFile = ExportedResultFile(url: fileURL, filename: filename)
    } catch {
      alertMessage = formatUserFacingError(error)
      isAlertPresented = true
    }
  }

  func exportReferenceImage(_ image: ReferenceImageAsset, index: Int) async {
    exportingReferenceImageID = image.id
    defer { exportingReferenceImageID = nil }

    do {
      guard let sourceURL = image.url, let resolvedURL = resolvedImageURL(sourceURL) else {
        throw PaperBananaAPIError.invalidURL(image.url ?? "")
      }
      let data = try await resultImageData(from: resolvedURL)
      let filename = exportFilename(for: image, index: index)
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PaperBananaExports", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let fileURL = directory.appendingPathComponent(filename)
      try data.write(to: fileURL, options: .atomic)
      exportedResultFile = ExportedResultFile(url: fileURL, filename: filename)
    } catch {
      alertMessage = formatUserFacingError(error)
      isAlertPresented = true
    }
  }

  func exportStageImage(_ stage: JobStage, index: Int) async {
    exportingStageImageID = stage.id
    defer { exportingStageImageID = nil }

    do {
      guard let image = stage.image, let resolvedURL = resolvedImageURL(image.url) else {
        throw PaperBananaAPIError.invalidURL(stage.image?.url ?? "")
      }
      let data = try await resultImageData(from: resolvedURL)
      let filename = exportFilename(for: stage, index: index)
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PaperBananaExports", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let fileURL = directory.appendingPathComponent(filename)
      try data.write(to: fileURL, options: .atomic)
      exportedResultFile = ExportedResultFile(url: fileURL, filename: filename)
    } catch {
      alertMessage = formatUserFacingError(error)
      isAlertPresented = true
    }
  }

  func exportJobArchive(_ job: Job) async {
    exportingJobArchiveID = job.id
    defer { exportingJobArchiveID = nil }

    do {
      guard job.hasExportableAssets else {
        throw ZipArchiveError.empty
      }

      var entries = [ZipArchiveEntry(path: "metadata.json", data: try job.exportMetadataData())]
      for asset in job.exportAssets {
        guard let resolvedURL = resolvedImageURL(asset.url) else {
          throw PaperBananaAPIError.invalidURL(asset.url)
        }
        entries.append(ZipArchiveEntry(path: asset.path, data: try await resultImageData(from: resolvedURL)))
      }

      let archiveData = try StoredZipArchive.make(entries: entries)
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PaperBananaExports", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let fileURL = directory.appendingPathComponent(job.exportArchiveFilename)
      try archiveData.write(to: fileURL, options: .atomic)
      exportedResultFile = ExportedResultFile(url: fileURL, filename: fileURL.lastPathComponent)
    } catch {
      alertMessage = formatUserFacingError(error)
      isAlertPresented = true
    }
  }

  func resetBackendBase() {
    apiBase = AppDefaults.sealosAPIBase
  }

  private func uploadReferenceImages() async throws -> [ReferenceImageAsset] {
    guard !draft.referenceImages.isEmpty else { return [] }
    let files = draft.referenceImages.map {
      ReferenceUploadFile(clientId: "\($0.id):original", role: "original", filename: $0.filename, mimeType: $0.mimeType, size: $0.size)
    }
    let prepared = try await apiClient.prepareReferenceUpload(apiBase: apiBase, files: files)
    var uploadsByID = Dictionary(uniqueKeysWithValues: prepared.map { ($0.clientId, $0) })
    var assets: [ReferenceImageAsset] = []
    for image in draft.referenceImages {
      let clientID = "\(image.id):original"
      guard let upload = uploadsByID.removeValue(forKey: clientID) else {
        throw PaperBananaAPIError.server("参考图上传地址创建失败。")
      }
      try await apiClient.uploadReference(data: image.data, mimeType: image.mimeType, uploadURL: upload.uploadURL)
      assets.append(ReferenceImageAsset(filename: image.filename, mimeType: image.mimeType, size: image.size, objectKey: upload.objectKey, uploadToken: upload.uploadToken))
    }
    return assets
  }

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

  private func startPolling(jobID: String) {
    pollingTask?.cancel()
    pollingTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        await self.loadCurrentJob()
        if self.currentJob?.statusKind.isTerminal == true { break }
        try? await Task.sleep(for: .seconds(3))
      }
    }
  }

  private func resultImageData(from url: URL) async throws -> Data {
    let absoluteString = url.absoluteString
    if absoluteString.hasPrefix("data:") {
      return try decodeDataURL(absoluteString)
    }

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PaperBananaAPIError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw PaperBananaAPIError.server("结果图下载失败：HTTP \(httpResponse.statusCode)")
    }
    return data
  }

  private func decodeDataURL(_ value: String) throws -> Data {
    guard let comma = value.firstIndex(of: ",") else {
      throw PaperBananaAPIError.invalidURL(value)
    }
    let metadata = value[..<comma]
    let payload = String(value[value.index(after: comma)...])
    if metadata.contains(";base64") {
      guard let data = Data(base64Encoded: payload) else {
        throw PaperBananaAPIError.decoding("data URL base64 无法解码")
      }
      return data
    }
    let decoded = payload.removingPercentEncoding ?? payload
    return Data(decoded.utf8)
  }

  private func exportFilename(for image: ResultImage, outputFormat: OutputFormat) -> String {
    let fallbackFormat = outputFormat == .svg ? "svg" : image.format
    let existingExtension = URL(fileURLWithPath: image.filename).pathExtension
    let fileExtension = existingExtension.isEmpty ? fallbackFormat : existingExtension
    return "paperbanana-candidate-\(image.candidateID + 1).\(fileExtension)"
  }

  private func exportFilename(for image: ReferenceImageAsset, index: Int) -> String {
    let existingExtension = URL(fileURLWithPath: image.filename).pathExtension
    let fileExtension = existingExtension.isEmpty ? image.displayFormat : existingExtension
    return "paperbanana-reference-\(index + 1).\(fileExtension)"
  }

  private func exportFilename(for stage: JobStage, index: Int) -> String {
    let existingExtension = URL(fileURLWithPath: stage.image?.filename ?? "").pathExtension
    let fileExtension = existingExtension.isEmpty ? (stage.image?.displayFormat ?? "png") : existingExtension
    let stageType = stage.type
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: " ", with: "-")
    return "paperbanana-stage-\(String(format: "%02d", index + 1))-\(stageType.isEmpty ? "stage" : stageType).\(fileExtension)"
  }

  private func loadSelectedProviderKey() {
    selectedAPIKey = (try? keychain.string(for: selectedProviderConfig.keyName)) ?? ""
  }

  private func saveSelectedProviderKey() {
    do {
      try keychain.set(selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines), for: selectedProviderConfig.keyName)
    } catch {
      alertMessage = formatUserFacingError(error)
      isAlertPresented = true
    }
  }
}
