import SwiftUI

struct RefineSheet: View {
  @Bindable var model: AppModel
  let image: ResultImage
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
          GlassPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
              Text("沿用生成设置")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
              Text("精修会按生成时选好的比例和清晰度继续处理，只提升清晰度、线条锐度和文字可读性，不再要求填写额外指令。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              HStack(spacing: Theme.Spacing.sm) {
                refineSettingChip(title: "目标比例", value: model.generation.refineAspectRatio)
                refineSettingChip(title: "清晰度", value: model.generation.refineImageSize.title)
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
          .accessibilityLabel("提交精修")
          .accessibilityHint("按生成时的比例与清晰度精修候选图")
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

  private func refineSettingChip(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.body.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.86)
    }
    .padding(.horizontal, Theme.Spacing.md)
    .padding(.vertical, Theme.Spacing.sm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.Palette.paperWell, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
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
