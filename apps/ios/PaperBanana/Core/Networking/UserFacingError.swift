import Foundation

/// 把任意错误转换成适合直接展示给用户的中文文案。
///
/// 映射优先级：
/// 1. envelope 的错误 code 字段（Better Auth 等已知 code）
/// 2. 已知英文错误消息（Better Auth / 网关返回的固定文案）
/// 3. HTTP 状态码（401 → 提示登录、403 → 无权限、429 → 稍后再试、5xx → 服务暂时不可用；
///    5xx 仅在响应没有更具体的消息时映射，避免吃掉后端给出的真实原因）
/// 4. URLError.code 显式映射（localizedDescription 在非英文设备上是本地化文案，
///    字符串子串兜底永不命中，所以传输层错误按 code 映射）
/// 5. 原始消息字符串 contains() 兜底
func formatUserFacingError(_ error: Error) -> String {
  if let apiError = error as? PaperBananaAPIError, case .http(let details) = apiError {
    return userFacingMessage(for: details)
  }
  if let urlError = error as? URLError, let mapped = mappedURLErrorCode(urlError.code) {
    return mapped
  }
  return formatUserFacingError(error.localizedDescription)
}

func formatUserFacingError(_ message: String) -> String {
  if let mapped = mappedKnownMessage(message) { return mapped }
  return message.isEmpty ? "操作失败" : message
}

private func userFacingMessage(for details: ServerErrorDetails) -> String {
  if let code = details.code, let mapped = mappedErrorCode(code) { return mapped }
  let message = details.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  if !message.isEmpty, let mapped = mappedKnownMessage(message) { return mapped }
  if let mapped = mappedStatusCode(details.statusCode, hasSpecificMessage: !message.isEmpty) { return mapped }
  return message.isEmpty ? "操作失败" : message
}

/// Better Auth 等后端的已知错误 code。
private func mappedErrorCode(_ code: String) -> String? {
  switch code.uppercased() {
  case "INVALID_EMAIL_OR_PASSWORD", "INVALID_PASSWORD", "USER_NOT_FOUND":
    "邮箱或密码不正确。"
  case "USER_ALREADY_EXISTS", "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL":
    "这个邮箱已经注册，请直接登录。"
  case "INVALID_EMAIL":
    "邮箱格式不正确。"
  case "PASSWORD_TOO_SHORT":
    "密码太短，至少需要 8 位。"
  case "SESSION_EXPIRED":
    "登录已过期，请重新登录。"
  default:
    nil
  }
}

private func mappedStatusCode(_ statusCode: Int, hasSpecificMessage: Bool) -> String? {
  switch statusCode {
  case 401:
    return "请先登录后再使用任务记录。"
  case 403:
    return "当前账号没有权限查看这个任务。"
  case 429:
    return "请求过于频繁，请稍后再试。"
  case 500...599:
    return hasSpecificMessage ? nil : "服务暂时不可用，请稍后重试。"
  default:
    return nil
  }
}

/// URLError 传输层错误的显式映射；都不命中时返回 nil 落入字符串兜底。
private func mappedURLErrorCode(_ code: URLError.Code) -> String? {
  switch code {
  case .timedOut:
    "请求超时，请稍后重试。"
  case .notConnectedToInternet, .networkConnectionLost:
    "网络未连接，请检查网络后重试。"
  case .cannotFindHost, .cannotConnectToHost:
    "无法连接服务器，请确认网络可访问 Sealos 后端地址。"
  default:
    nil
  }
}

/// 已知英文错误消息映射；都不命中时返回 nil。
private func mappedKnownMessage(_ message: String) -> String? {
  if message.contains("Invalid email or password") { return "邮箱或密码不正确。" }
  if message.contains("User already exists") { return "这个邮箱已经注册，请直接登录。" }
  if message.contains("Missing API key") { return "缺少所选模型接口的 API Key。" }
  if message.contains("Incorrect API key") || message.contains("apikey-error") { return "API Key 不正确，请确认模型服务和密钥匹配。" }
  if message.contains("Please log in") || message.contains("请先登录") || message.contains("Unauthorized") { return "请先登录后再使用任务记录。" }
  if message.contains("Forbidden") { return "当前账号没有权限查看这个任务。" }
  if message.contains("timed out") || message.contains("timeout") { return "请求超时，请稍后重试。" }
  if message.contains("Network request failed") || message.contains("No such host") || message.contains("无法连接") { return "无法连接后端，请确认网络可访问 Sealos 后端地址。" }
  if message.contains("HTTP 503") { return "服务暂时不可用，请稍后重试。" }
  return nil
}
