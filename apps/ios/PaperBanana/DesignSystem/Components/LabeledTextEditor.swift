import SwiftUI

struct LabeledTextEditor: View {
  let title: String
  @Binding var text: String
  let minHeight: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
      TextEditor(text: $text)
        .frame(minHeight: minHeight)
        .padding(8)
        .scrollContentBackground(.hidden)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
  }
}
