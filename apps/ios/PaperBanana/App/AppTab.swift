import Foundation

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
