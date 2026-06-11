import Foundation
import Observation

/// 组合根：持有各子 store、负责跨 store 协调与少量跨域门面。
@Observable
@MainActor
final class AppModel {
  var selectedTab: AppTab = .generate

  var alertMessage = ""
  var isAlertPresented = false

  // 子 store 引用从不重新赋值；声明为 var 是因为 SwiftUI @Bindable 的
  // dynamic member 链（$model.generation.draft.x）要求中间属性可写。
  var settings: SettingsStore
  var auth: AuthStore
  var jobs: JobsStore
  var generation: GenerationStore
  var exports: ExportCenter

  private let apiClient: PaperBananaAPIClient

  init(apiClient: PaperBananaAPIClient? = nil) {
    let client = apiClient ?? PaperBananaAPIClient()
    self.apiClient = client
    let settings = SettingsStore(apiClient: client)
    let auth = AuthStore(apiClient: client, settings: settings)
    let jobs = JobsStore(apiClient: client, settings: settings, auth: auth)
    self.settings = settings
    self.auth = auth
    self.jobs = jobs
    generation = GenerationStore(apiClient: client, settings: settings, jobs: jobs)
    exports = ExportCenter(apiClient: client, settings: settings)

    settings.currentJobIDProvider = { [weak jobs] in jobs?.currentJob?.id }
    auth.onAuthenticated = { [weak jobs] in await jobs?.loadUserJobs(silent: true) }
    auth.onSignedOut = { [weak jobs] in jobs?.clearForSignOut() }
    generation.presentAlert = { [weak self] message in self?.presentAlert(message) }
    exports.presentAlert = { [weak self] message in self?.presentAlert(message) }
  }

  func bootstrap() async {
    jobs.loadCachedRecords()
    await settings.refreshHealth()
    await auth.refreshSession()
    if auth.currentUser != nil {
      await jobs.loadUserJobs(silent: true)
    }
  }

  /// 模板套用：同时更新生成草稿与当前 tab。
  func applyExample(_ example: QuickStartExample) {
    generation.draft.infographicCategoryID = example.categoryID
    generation.draft.methodContent = example.methodContent
    generation.draft.caption = example.caption
    selectedTab = .generate
  }

  func resolvedImageURL(_ url: String) -> URL? {
    apiClient.resolvedImageURL(apiBase: settings.apiBase, url: url)
  }

  func presentAlert(_ message: String) {
    alertMessage = message
    isAlertPresented = true
  }
}
