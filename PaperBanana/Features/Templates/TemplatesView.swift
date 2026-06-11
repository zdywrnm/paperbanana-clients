import SwiftUI

struct TemplatesView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          ForEach(PaperBananaSamples.quickStartExamples) { example in
            GlassPanel {
              VStack(alignment: .leading, spacing: 8) {
                Text(example.title)
                  .font(.headline)
                Text(example.hint)
                  .font(.footnote)
                  .foregroundStyle(.secondary)
                Button("使用模板") {
                  model.applyExample(example)
                }
                .buttonStyle(.borderedProminent)
                .paperGlassButton(prominent: true)
              }
            }
          }
        }
        .padding()
      }
      .background(AppBackground(isGenerating: model.jobs.hasActiveJob))
      .navigationTitle("示例模板")
    }
  }
}
