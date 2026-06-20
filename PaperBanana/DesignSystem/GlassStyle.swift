import SwiftUI

/// 玻璃层级纪律（Liquid Glass layering）：
///
/// 1. 最底层是 `AppBackground` 的 MeshGradient —— 全 app 唯一的"画布"，本身不带玻璃。
/// 2. 内容卡片用 `.paperGlass(.panel)`（regular glass）。
/// 3. 浮层 / 可点元素用 `.paperGlass(.interactive)`，需要语义色时用 `.paperGlass(.tinted(_))`。
/// 4. 玻璃不叠玻璃：已经在玻璃面板里的子视图不要再加 paperGlass；
///    需要强调时用 tint / 字重 / 间距，不要嵌套 glassEffect。
/// 5. 按钮统一走 `paperGlassButton(prominent:)`，不要手写 buttonStyle(.glass*)。
enum PaperGlass {
  /// 静态内容卡片。
  case panel
  /// 可交互浮层（按压有高光响应）。
  case interactive
  /// 带品牌 / 语义色的玻璃。
  case tinted(Color)

  fileprivate var glass: Glass {
    switch self {
    case .panel: .regular
    case .interactive: .regular.interactive()
    case .tinted(let color): .regular.tint(color)
    }
  }
}

extension View {
  /// 统一玻璃入口：全 app 只通过这里消费 glassEffect。
  /// 默认形状为卡片圆角矩形；胶囊请传 `in: .capsule`。
  func paperGlass(
    _ style: PaperGlass = .panel,
    in shape: some Shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
  ) -> some View {
    glassEffect(style.glass, in: shape)
  }

  /// 玻璃面板内的"井底"内容块：thinMaterial 圆角浅底（输入框、术语卡、状态行、链接行等）。
  /// 玻璃不叠玻璃：面板内需要再分层时用这个，不要嵌套 paperGlass。
  /// 需要撑满宽度时把 `.frame(maxWidth: .infinity, …)` 放在 fieldWell 之前。
  func fieldWell() -> some View {
    padding(Theme.Spacing.md)
      .background(Theme.Palette.paperWell, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
          .strokeBorder(Theme.Palette.paperBorder, lineWidth: 1)
      }
  }

  /// 小程序风格字段井底：更接近 paper surface，适合 TextField / SecureField。
  func paperFieldWell() -> some View {
    padding(Theme.Spacing.md)
      .background(Theme.Palette.paperPanel, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
          .strokeBorder(Theme.Palette.paperBorder, lineWidth: 1)
      }
  }

  @ViewBuilder
  func paperGlassButton(prominent: Bool = false) -> some View {
    if prominent {
      self.buttonStyle(PaperPrimaryButtonStyle())
    } else {
      self.buttonStyle(.glass)
    }
  }
}

private struct PaperPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .fontWeight(.semibold)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.md)
      .foregroundStyle(isEnabled ? .white : .white.opacity(0.72))
      .background(
        isEnabled
          ? Theme.Palette.paperGreen.opacity(configuration.isPressed ? 0.78 : 0.94)
          : Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
              ? UIColor(red: 0.30, green: 0.33, blue: 0.30, alpha: 0.72)
              : UIColor(red: 0.79, green: 0.75, blue: 0.70, alpha: 0.82)
          }),
        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
          .strokeBorder(isEnabled ? Theme.Palette.paperGreen.opacity(0.40) : Theme.Palette.paperBorder, lineWidth: 1)
      }
      .shadow(color: isEnabled ? Theme.Palette.paperGreen.opacity(0.22) : .clear, radius: 14, y: 7)
      .paperGlass(isEnabled ? .tinted(Theme.Palette.paperGreen.opacity(0.52)) : .panel, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
      .scaleEffect(configuration.isPressed && isEnabled ? 0.985 : 1)
      .animation(Theme.Motion.stateChange, value: configuration.isPressed)
  }
}
