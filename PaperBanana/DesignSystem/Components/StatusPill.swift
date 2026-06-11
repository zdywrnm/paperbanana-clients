import SwiftUI

struct StatusPill: View {
  let text: String
  let systemImage: String

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, Theme.Spacing.md)
      .padding(.vertical, Theme.Spacing.xs)
      .paperGlass(.panel, in: .capsule)
  }
}
