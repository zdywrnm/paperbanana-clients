import SwiftUI

extension View {
  @ViewBuilder
  func paperGlass(cornerRadius: CGFloat = 18, interactive: Bool = false) -> some View {
    if interactive {
      self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    } else {
      self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
  }

  @ViewBuilder
  func paperGlassButton(prominent: Bool = false) -> some View {
    if prominent {
      self.buttonStyle(.glassProminent)
    } else {
      self.buttonStyle(.glass)
    }
  }

  func paperCompactTabBarInset() -> some View {
    modifier(CompactTabBarInsetModifier())
  }
}

private struct CompactTabBarInsetModifier: ViewModifier {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  func body(content: Content) -> some View {
    content.safeAreaInset(edge: .bottom, spacing: 0) {
      if horizontalSizeClass == .compact {
        Color.clear
          .frame(height: 88)
          .accessibilityHidden(true)
      }
    }
  }
}
