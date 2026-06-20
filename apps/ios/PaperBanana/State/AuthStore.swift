import Foundation
import Observation

/// 账号会话：登录、注册、退出与 session 刷新。
@Observable
@MainActor
final class AuthStore {
  var currentUser: CurrentUser?
  var sessionPending = false

  var authMode: String = "sign-in"
  var authEmail = ""
  var authPassword = ""
  var authName = ""
  var authError = ""
  var authSubmitting = false

  /// 登录/注册成功后的跨 store 协调（由 AppModel 注入，如刷新任务记录）。
  @ObservationIgnored var onAuthenticated: () async -> Void = {}
  /// 退出登录后的跨 store 协调（由 AppModel 注入，如清空任务记录）。
  /// 仅清登录相关缓存——不动 API key，用户重新登录还要用。
  @ObservationIgnored var onSignedOut: () -> Void = {}
  /// 删除账号后的跨 store 协调（由 AppModel 注入）。
  /// 比 onSignedOut 更彻底：除任务缓存外还清 API key、模板、草稿等所有本机数据。
  @ObservationIgnored var onAccountDeleted: () -> Void = {}

  private let apiClient: PaperBananaAPIClient
  private let settings: SettingsStore

  init(apiClient: PaperBananaAPIClient, settings: SettingsStore) {
    self.apiClient = apiClient
    self.settings = settings
  }

  func refreshSession() async {
    sessionPending = true
    defer { sessionPending = false }
    currentUser = try? await apiClient.getSession(apiBase: settings.apiBase)
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
        let name = authName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(email.split(separator: "@").first ?? "图研") : authName
        try await apiClient.signUp(apiBase: settings.apiBase, email: email, password: authPassword, name: name)
      } else {
        try await apiClient.signIn(apiBase: settings.apiBase, email: email, password: authPassword)
      }
      authPassword = ""
      await refreshSession()
      await onAuthenticated()
    } catch {
      authError = formatUserFacingError(error)
    }
  }

  func signOut() async {
    await apiClient.signOut(apiBase: settings.apiBase)
    currentUser = nil
    onSignedOut()
  }

  /// 永久删除账号：重新输入密码二次确认。成功后服务端已清 session 并真删账号；
  /// 客户端置空 currentUser 并触发完整本地清理（含 API key / 模板 / 草稿 / 任务缓存）。
  /// 失败（密码错 / 未登录 / 服务器错）抛出，由调用方用 formatUserFacingError 展示。
  func deleteAccount(password: String) async throws {
    guard let email = currentUser?.email, !email.isEmpty else {
      throw PaperBananaAPIError.server("当前未登录，无法删除账号。")
    }
    try await apiClient.deleteAccount(apiBase: settings.apiBase, email: email, password: password)
    currentUser = nil
    onAccountDeleted()
  }
}
