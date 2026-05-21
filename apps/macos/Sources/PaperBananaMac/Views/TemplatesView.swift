import SwiftUI

struct TemplatesView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    List {
      Section("Quick Start") {
        ForEach(PaperBananaSamples.quickStartExamples) { example in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(example.title)
                  .font(.headline)
                Text(example.hint)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
              }
              Spacer()
              Button("Apply") {
                model.applyExample(example)
              }
            }

            Text(example.caption)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .padding(.vertical, 6)
        }
      }
    }
    .navigationTitle("Templates")
  }
}
