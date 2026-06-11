import SwiftUI

struct StatusPill: View {
  let text: String
  let systemImage: String

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .paperGlass(cornerRadius: 999, interactive: false)
  }
}
