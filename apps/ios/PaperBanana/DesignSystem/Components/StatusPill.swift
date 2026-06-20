import SwiftUI

struct StatusPill: View {
  let text: String
  let systemImage: String
  /// 语义色（如 Theme.Palette.tint(for:)）：非 nil 时用 .tinted 玻璃并染色前景。
  var tint: Color?
  /// 小字前景的覆盖色（如 Theme.Palette.textTint(for:)）：浅色香蕉黄等
  /// 对比不足的 tint 用它换成可读的深化版本；nil 时沿用 `tint`。
  var textTint: Color?
  /// VoiceOver 朗读文案；nil 时回退到 `text`。
  var accessibilityLabel: String?

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle((textTint ?? tint).map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
      .padding(.horizontal, Theme.Spacing.md)
      .padding(.vertical, Theme.Spacing.xs)
      .paperGlass(tint.map { .tinted($0.opacity(0.35)) } ?? .panel, in: .capsule)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilityLabel ?? text)
  }
}
