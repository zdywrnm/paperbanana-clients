import SwiftUI

struct RefineSheet: View {
  @Bindable var model: AppModel
  let image: ResultImage
  @Environment(\.dismiss) private var dismiss

  private var canSubmit: Bool {
    !model.generation.refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
          GlassPanel {
            LabeledTextEditor(title: "精修指令", text: $model.generation.refineInstruction, minHeight: 160)
          }

          GlassPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
              Text("比例与清晰度")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
              HStack {
                Text("目标比例")
                  .font(.subheadline)
                Spacer()
                Picker("目标比例", selection: $model.generation.refineAspectRatio) {
                  ForEach(["16:9", "21:9", "3:2", "1:1"], id: \.self) { ratio in
                    Text(ratio).tag(ratio)
                  }
                }
                .accessibilityLabel("目标比例")
              }
              HStack {
                Text("清晰度")
                  .font(.subheadline)
                Spacer()
                Picker("清晰度", selection: $model.generation.refineImageSize) {
                  ForEach(model.generation.refineSupportedImageSizes) { size in
                    Text(size.title).tag(size)
                  }
                }
                .accessibilityLabel("清晰度")
              }
            }
          }

          Button {
            Task {
              await model.generation.refine(image: image)
              dismiss()
            }
          } label: {
            Label("提交精修", systemImage: "wand.and.stars")
              .font(.headline)
              .frame(maxWidth: .infinity)
          }
          .controlSize(.large)
          .paperGlassButton(prominent: true)
          .disabled(!canSubmit)
          .accessibilityLabel("提交精修")
          .accessibilityHint("按精修指令对候选图重新生成")
        }
        .padding()
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("图片精修")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
            .accessibilityLabel("取消精修")
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationBackground(.thinMaterial)
  }
}

#if DEBUG
#Preview("精修面板") {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      RefineSheet(model: AppModel(), image: JobPreviewFixtures.succeeded.resultImages[0])
    }
}
#endif
