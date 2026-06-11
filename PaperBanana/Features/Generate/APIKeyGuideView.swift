import SwiftUI

struct APIKeyGuideView: View {
  let config: ProviderConfig
  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(config.guideSteps.enumerated()), id: \.offset) { item in
          APIKeyGuideStepRow(number: item.offset + 1, text: item.element)
        }

        Link(destination: config.guideURL) {
          Label("打开 \(config.label) 官方申请/说明页面", systemImage: "arrow.up.right.square")
            .font(.footnote.weight(.semibold))
        }

        Text("密钥只用于本次任务调用模型，不会保存到本站数据库。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.top, 8)
    } label: {
      Label("API Key 申请指南", systemImage: "book")
        .font(.footnote.weight(.semibold))
    }
  }
}

struct APIKeyGuideStepRow: View {
  let number: Int
  let text: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text("\(number)")
        .font(.caption.monospacedDigit().weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(Circle().fill(Color.accentColor))
      Text(text)
        .font(.footnote)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
