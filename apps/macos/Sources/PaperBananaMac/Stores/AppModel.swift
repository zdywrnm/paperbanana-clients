import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published var section: WorkbenchSection = .generate
  @Published var draft = GenerationDraft()
  @Published var apiBase: String {
    didSet {
      apiBase = AppDefaults.normalizedAPIBase(apiBase)
      UserDefaults.standard.set(apiBase, forKey: AppDefaults.apiBaseKey)
    }
  }

  @Published var selectedAPIKey = ""
  @Published var health: BackendHealth?
  @Published var healthError = ""
  @Published var currentUser: CurrentUser?
  @Published var sessionPending = false

  @Published var authMode: AuthMode = .signIn
  @Published var authEmail = ""
  @Published var authPassword = ""
  @Published var authName = ""
  @Published var authError = ""
  @Published var authSubmitting = false
  @Published var isAuthSheetPresented = false

  @Published var isSubmitting = false
  @Published var submitError = ""
  @Published var currentJobID = ""
  @Published var currentJob: Job?
  @Published var userJobs: [Job] = []
  @Published var selectedRecordID: Job.ID?
  @Published var recordsError = ""
  @Published var recordsLoading = false
  @Published var alertMessage = ""
  @Published var isAlertPresented = false

  private let apiClient = PaperBananaAPIClient()
  private let keychain = KeychainService()
  private let notifications = NotificationService()
  let imageExport = ImageExportService()
  private var pollingTask: Task<Void, Never>?
  private var notifiedJobIDs = Set<String>()

  init() {
    let storedBase = UserDefaults.standard.string(forKey: AppDefaults.apiBaseKey) ?? AppDefaults.sealosAPIBase
    apiBase = AppDefaults.normalizedAPIBase(storedBase)
    loadSelectedProviderKey()
  }

  var selectedProviderConfig: ProviderConfig {
    ProviderCatalog.config(for: draft.provider)
  }

  var selectedCategory: InfographicCategory {
    PaperBananaSamples.categories.first { $0.id == draft.infographicCategoryID } ?? PaperBananaSamples.categories[0]
  }

  var selectedRecord: Job? {
    userJobs.first { $0.id == selectedRecordID }
  }

  var canSubmit: Bool {
    let canMock = draft.configurationMode == .advanced && draft.mock && (health?.mockEnabled == true)
    return !isSubmitting
      && draft.methodContent.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
      && draft.caption.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
      && (!selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || canMock)
  }

  func bootstrap() async {
    await notifications.requestAuthorization()
    await refreshHealth()
    await refreshSession()
    if currentUser != nil {
      await loadUserJobs(silent: true)
    }
  }

  func refreshActiveSection() async {
    await refreshHealth()
    switch section {
    case .generate:
      if !currentJobID.isEmpty {
        await loadCurrentJob()
      }
    case .records:
      await loadUserJobs(silent: false)
    case .templates:
      break
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
    loadSelectedProviderKey()
  }

  func updateSelectedAPIKey(_ value: String) {
    selectedAPIKey = value
    saveSelectedProviderKey()
  }

  func applyExample(_ example: QuickStartExample) {
    draft.infographicCategoryID = example.categoryID
    draft.methodContent = example.methodContent
    draft.caption = example.caption
    section = .generate
  }

  func submitJob() async {
    guard canSubmit else { return }
    saveSelectedProviderKey()
    submitError = ""
    isSubmitting = true
    currentJob = nil
    defer { isSubmitting = false }

    do {
      let payload = JobCreatePayload(
        configurationMode: draft.configurationMode,
        provider: draft.provider,
        apiKey: selectedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
        methodContent: draft.methodContent.trimmingCharacters(in: .whitespacesAndNewlines),
        caption: draft.caption.trimmingCharacters(in: .whitespacesAndNewlines),
        infographicCategory: selectedCategory.label,
        mainModelName: draft.configurationMode == .advanced ? draft.mainModelName : selectedProviderConfig.mainModel,
        imageModelName: draft.configurationMode == .advanced ? draft.imageModelName : selectedProviderConfig.imageModel,
        pipelineMode: draft.configurationMode == .advanced ? draft.pipelineMode : "demo_planner_critic",
        retrievalSetting: draft.configurationMode == .advanced ? draft.retrievalSetting : "none",
        aspectRatio: draft.configurationMode == .advanced ? draft.aspectRatio : "16:9",
        numCandidates: draft.configurationMode == .advanced ? draft.numCandidates : 1,
        maxCriticRounds: draft.configurationMode == .advanced ? draft.maxCriticRounds : 1,
        mock: draft.configurationMode == .advanced ? draft.mock : false
      )
      let created = try await apiClient.createJob(apiBase: apiBase, health: health, payload: payload)
      guard !created.id.isEmpty else {
        throw PaperBananaAPIError.server("后端没有返回任务 ID。")
      }
      currentJobID = created.id
      currentJob = Job(id: created.id, status: created.status)
      startPolling(jobID: created.id)
      if currentUser != nil {
        await loadUserJobs(silent: true)
      }
    } catch {
      submitError = formatUserFacingError(error)
    }
  }

  func loadCurrentJob() async {
    guard !currentJobID.isEmpty else { return }
    do {
      let previousStatus = currentJob?.statusKind
      let job = try await apiClient.getJob(apiBase: apiBase, health: health, jobID: currentJobID)
      currentJob = job
      if job.statusKind.isTerminal, previousStatus != job.statusKind, !notifiedJobIDs.contains(job.id) {
        notifiedJobIDs.insert(job.id)
        await notifications.notifyJobFinished(job: job)
      }
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
      userJobs = try await apiClient.userJobs(apiBase: apiBase, health: health)
      if selectedRecordID == nil {
        selectedRecordID = userJobs.first?.id
      }
    } catch {
      recordsError = formatUserFacingError(error)
    }
  }

  func signInOrSignUp() async {
    guard !authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          authPassword.count >= 8
    else {
      authError = "请输入邮箱和至少 8 位密码。"
      return
    }

    authSubmitting = true
    authError = ""
    defer { authSubmitting = false }

    do {
      let email = authEmail.trimmingCharacters(in: .whitespacesAndNewlines)
      if authMode == .signUp {
        let name = authName.trimmingCharacters(in: .whitespacesAndNewlines)
        try await apiClient.signUp(apiBase: apiBase, email: email, password: authPassword, name: name.isEmpty ? email : name)
      } else {
        try await apiClient.signIn(apiBase: apiBase, email: email, password: authPassword)
      }
      await refreshSession()
      authPassword = ""
      isAuthSheetPresented = false
      section = .records
      await loadUserJobs(silent: false)
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

  func saveImage(_ image: ResultImage) async {
    do {
      let data = try await imageExport.imageData(from: image, apiBase: apiBase)
      try imageExport.save(data: data, suggestedFilename: image.filename)
    } catch {
      presentAlert(formatUserFacingError(error))
    }
  }

  func copyImage(_ image: ResultImage) async {
    do {
      let data = try await imageExport.imageData(from: image, apiBase: apiBase)
      try imageExport.copyToPasteboard(data: data)
    } catch {
      presentAlert(formatUserFacingError(error))
    }
  }

  func resetBackendBase() {
    apiBase = AppDefaults.sealosAPIBase
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

  private func presentAlert(_ message: String) {
    alertMessage = message
    isAlertPresented = true
  }
}
