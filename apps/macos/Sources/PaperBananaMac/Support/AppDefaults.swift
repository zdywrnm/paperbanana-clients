import Foundation

enum AppDefaults {
  static let sealosAPIBase = "https://yifbnnzrwmxn.sealoshzh.site"
  static let apiBaseKey = "paperbanana.apiBase"

  static func normalizedAPIBase(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = trimmed.isEmpty ? sealosAPIBase : trimmed
    return base.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
  }
}

func formatUserFacingError(_ error: Error) -> String {
  formatUserFacingError(error.localizedDescription)
}

func formatUserFacingError(_ message: String) -> String {
  if message.contains("Invalid email or password") { return "邮箱或密码不正确。" }
  if message.contains("User already exists") { return "这个邮箱已经注册，请直接登录。" }
  if message.contains("Missing API key") { return "缺少所选模型接口的 API Key。" }
  if message.contains("Incorrect API key") || message.contains("apikey-error") { return "API Key 不正确，请确认模型服务和密钥匹配。" }
  if message.contains("Please log in") || message.contains("请先登录") || message.contains("Unauthorized") { return "请先登录后再使用任务记录。" }
  if message.contains("Forbidden") { return "当前账号没有权限查看这个任务。" }
  if message.contains("timed out") || message.contains("timeout") { return "请求超时，请稍后重试。" }
  if message.contains("Network request failed") || message.contains("No such host") || message.contains("无法连接") {
    return "无法连接后端，请确认网络可访问 Sealos 后端地址。"
  }
  if message.contains("ADMIN_TOKEN is not configured") { return "管理接口未启用：还没有配置 ADMIN_TOKEN。" }
  if message.contains("Admin API disabled") { return "管理接口未启用。" }
  if message.contains("Backend is unavailable") { return "后端暂时不可用。" }
  if message.contains("HTTP 503") { return "服务暂时不可用，请稍后重试。" }
  return message.isEmpty ? "操作失败" : message
}
