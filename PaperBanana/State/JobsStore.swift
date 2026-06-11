import Foundation
import Observation

/// 当前任务跟踪（含轮询）与历史任务记录。
@Observable
@MainActor
final class JobsStore {
  var currentJobID = ""
  var currentJob: Job?
  var userJobs: [Job] = []
  var selectedRecordID: Job.ID?
  var recordsError = ""
  var recordsLoading = false
  /// 轮询的结构化失败结果（连续失败 / 超时）转成的可展示文案；为空表示无异常。
  var pollingError = ""
  /// 当前 userJobs 来自本地缓存（尚未被网络刷新覆盖）。
  var isShowingCachedData = false

  /// 当前任务是否仍在进行中（排队 / 生成），驱动全局状态胶囊与背景动画。
  var hasActiveJob: Bool {
    guard let status = currentJob?.statusKind else { return false }
    return status == .queued || status == .running
  }

  private let apiClient: PaperBananaAPIClient
  private let settings: SettingsStore
  private let auth: AuthStore
  private let poller: JobPoller
  private let recordsCache = RecordsDiskCache()

  init(apiClient: PaperBananaAPIClient, settings: SettingsStore, auth: AuthStore, poller: JobPoller? = nil) {
    self.apiClient = apiClient
    self.settings = settings
    self.auth = auth
    self.poller = poller ?? JobPoller()
  }

  /// 开始跟踪一个新建任务并启动轮询。
  func track(jobID: String, status: String) {
    currentJobID = jobID
    currentJob = Job(id: jobID, status: status)
    pollingError = ""
    startPolling(jobID: jobID)
  }

  func pausePolling() {
    poller.pause()
  }

  func resumePolling() {
    poller.resume()
  }

  /// 轮询因超时 / 连续失败停止后，由 UI「重新检查」触发的恢复入口：
  /// 清除错误并对当前任务重新启动轮询。
  func retryPolling() {
    guard !currentJobID.isEmpty else { return }
    pollingError = ""
    startPolling(jobID: currentJobID)
  }

  func loadUserJobs(silent: Bool) async {
    guard auth.currentUser != nil else { return }
    if !silent {
      recordsError = ""
      recordsLoading = true
    }
    defer { recordsLoading = false }
    do {
      userJobs = try await apiClient.userJobs(apiBase: settings.apiBase)
      selectedRecordID = selectedRecordID ?? userJobs.first?.id
      isShowingCachedData = false
      recordsCache.save(userJobs)
    } catch {
      recordsError = formatUserFacingError(error)
    }
  }

  /// 启动时先加载本地缓存展示，等网络刷新成功后覆盖。
  func loadCachedRecords() {
    guard userJobs.isEmpty, let cached = recordsCache.load(), !cached.isEmpty else { return }
    userJobs = cached
    isShowingCachedData = true
  }

  func clearForSignOut() {
    userJobs = []
    selectedRecordID = nil
    isShowingCachedData = false
    recordsCache.clear()
  }

  private func startPolling(jobID: String) {
    let apiClient = apiClient
    let settings = settings
    poller.start(
      fetch: { try await apiClient.getJob(apiBase: settings.apiBase, jobID: jobID) },
      onUpdate: { [weak self] job in
        self?.currentJob = job
      },
      onFinish: { [weak self] termination in
        self?.handlePollingTermination(termination)
      }
    )
  }

  private func handlePollingTermination(_ termination: JobPoller.Termination) {
    switch termination {
    case .reachedTerminalStatus:
      break
    case .timedOut:
      pollingError = "任务轮询已超过 10 分钟，已自动停止刷新；请稍后在任务记录里查看结果。"
    case .repeatedFailures(let message):
      pollingError = message
    }
  }
}
