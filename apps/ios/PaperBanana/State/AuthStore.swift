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
  @ObservationIgnored var onSignedOut: () -> Void = {}

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
        let name = authName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(email.split(separator: "@").first ?? "PaperBanana") : authName
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
}
