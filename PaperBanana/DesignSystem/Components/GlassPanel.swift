import SwiftUI

struct GlassPanel<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(Theme.Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .paperGlass(.panel)
  }
}
