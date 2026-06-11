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

  @ViewBuilder
  func paperGlassButton(prominent: Bool = false) -> some View {
    if prominent {
      self.buttonStyle(.glassProminent)
    } else {
      self.buttonStyle(.glass)
    }
  }
}
