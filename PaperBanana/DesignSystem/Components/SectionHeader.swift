import SwiftUI

/// 分组卡标题：headline 字重 + isHeader 朗读特征，可选图标。
/// Settings / Guide / Generate 的手卷分组标题统一从这里消费。
struct SectionHeader: View {
  let title: String
  var systemImage: String?

  var body: some View {
    Group {
      if let systemImage {
        Label(title, systemImage: systemImage)
      } else {
        Text(title)
      }
    }
    .font(.headline)
    .accessibilityAddTraits(.isHeader)
  }
}
