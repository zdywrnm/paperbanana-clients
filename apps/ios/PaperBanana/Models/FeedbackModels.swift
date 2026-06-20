import Foundation

enum FeedbackCategory: String, CaseIterable, Codable, Identifiable {
  case bug
  case feature
  case experience
  case other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bug: "问题反馈"
    case .feature: "功能建议"
    case .experience: "体验意见"
    case .other: "其他"
    }
  }
}
