import SwiftUI

struct RefineSheet: View {
  @Bindable var model: AppModel
  let image: ResultImage
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section("精修指令") {
          TextEditor(text: $model.generation.refineInstruction)
            .frame(minHeight: 160)
        }
        Section("目标设置") {
          Picker("目标比例", selection: $model.generation.refineAspectRatio) {
            ForEach(["16:9", "21:9", "3:2", "1:1"], id: \.self) { ratio in
              Text(ratio).tag(ratio)
            }
          }
          Picker("清晰度", selection: $model.generation.refineImageSize) {
            ForEach(model.generation.refineSupportedImageSizes) { size in
              Text(size.title).tag(size)
            }
          }
        }
        Section {
          Button("提交精修") {
            Task {
              await model.generation.refine(image: image)
              dismiss()
            }
          }
          .disabled(model.generation.refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .navigationTitle("图片精修")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
      }
    }
  }
}
