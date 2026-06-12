import Foundation

/// 全 app 时间展示策略集中地（替代三处各自为政的格式化）：
/// - 文案为简体中文硬编码，相对时间固定 zh-Hans，避免系统非中文 locale 混出 "18 hours ago"。
/// - ISO8601 解析兼容带 / 不带毫秒两种形态；formatter 创建昂贵，全部提为 static 复用。
enum DateDisplay {
  static let locale = Locale(identifier: "zh-Hans")

  private static let isoFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let isoPlain: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// 绝对时间固定 "yyyy-MM-dd HH:mm"，UTC 时区：与 Web 记录页一致按后端
  /// 时间戳原样展示（冻结契约 "2026-06-10T13:45:12.000Z" → "2026-06-10 13:45"）。
  private static let absoluteFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
  }()

  static func parseISODate(_ value: String) -> Date? {
    guard !value.isEmpty else { return nil }
    return isoFractional.date(from: value) ?? isoPlain.date(from: value)
  }

  /// 相对时间（"3分钟前" / "昨天"），固定 zh-Hans。
  static func relative(_ date: Date) -> String {
    date.formatted(.relative(presentation: .named).locale(locale))
  }

  /// 原始时间串 → 相对时间；解析失败回退到截断的原始字符串。
  static func relative(fromISO raw: String) -> String {
    guard let date = parseISODate(raw) else { return truncatedRaw(raw) }
    return relative(date)
  }

  /// 原始时间串 → 绝对时间（本地时区 "yyyy-MM-dd HH:mm"）；解析失败回退到截断的原始字符串。
  static func absolute(fromISO raw: String) -> String {
    guard let date = parseISODate(raw) else { return truncatedRaw(raw) }
    return absoluteFormatter.string(from: date)
  }

  /// 解析失败的兜底：把 "2026-06-11T08:00:00" 截成 "2026-06-11 08:00"。
  private static func truncatedRaw(_ raw: String) -> String {
    String(raw.replacingOccurrences(of: "T", with: " ").prefix(16))
  }
}
