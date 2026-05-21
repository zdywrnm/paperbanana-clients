import SwiftUI

struct TemplatesView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    List {
      Section("快速开始") {
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
              Button("套用") {
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
    .navigationTitle("示例模板")
    .scrollContentBackground(.hidden)
    .background(PaperWorkspaceBackground().ignoresSafeArea())
  }
}
