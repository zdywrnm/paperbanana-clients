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
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
  }

  @ViewBuilder
  func paperGlassButton(prominent: Bool = false) -> some View {
    if prominent {
      self.buttonStyle(.glassProminent)
        .modifier(ProminentGlassLabelColor())
    } else {
      self.buttonStyle(.glass)
    }
  }
}

/// prominent 玻璃按钮的标签色：AccentColor 深色模式是亮香蕉黄，系统默认白字只有 ~1.5:1，
/// 改黑字（黄底黑字，9.6:1）；浅色深金底保持白字（4.8:1）。disabled 不覆盖，保留系统变暗。
private struct ProminentGlassLabelColor: ViewModifier {
  @Environment(\.isEnabled) private var isEnabled

  private static let labelColor = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor.black.withAlphaComponent(0.85)
      : UIColor.white
  })

  func body(content: Content) -> some View {
    if isEnabled {
      content.foregroundStyle(Self.labelColor)
    } else {
      content
    }
  }
}
