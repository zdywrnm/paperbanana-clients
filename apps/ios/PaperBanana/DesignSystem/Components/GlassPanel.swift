import SwiftUI

struct GlassPanel<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(Theme.Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Theme.Palette.paperPanel, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
          .strokeBorder(Theme.Palette.paperBorder, lineWidth: 1)
      }
      .paperGlass(.panel)
  }
}
