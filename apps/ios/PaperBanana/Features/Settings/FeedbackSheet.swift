import SwiftUI

struct FeedbackSheet: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
          GlassPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
              SectionHeader(title: "意见反馈", systemImage: "message")
              Text("遇到生成失败、模型异常或体验问题，可以直接提交给开发者。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              Picker("反馈类型", selection: $model.settings.feedbackCategory) {
                ForEach(FeedbackCategory.allCases) { category in
                  Text(category.title).tag(category)
                }
              }
              .pickerStyle(.segmented)

              LabeledTextEditor(title: "反馈内容", text: feedbackMessageBinding, minHeight: 160)
              Text("\(model.settings.feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).count)/2000")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

              TextField("联系方式（可选）", text: feedbackContactBinding)
                .paperFieldWell()
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

              if let jobID = model.settings.currentJobIDProvider(), !jobID.isEmpty {
                Label("会一并附上当前任务 ID。", systemImage: "number")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }

              Button {
                Task { await model.settings.submitFeedback() }
              } label: {
                Label(model.settings.feedbackSubmitting ? "提交中" : "提交反馈", systemImage: "paperplane")
                  .frame(maxWidth: .infinity)
              }
              .paperGlassButton(prominent: true)
              .disabled(!model.settings.canSubmitFeedback)

              if model.settings.feedbackSuccess {
                Label("已收到反馈。", systemImage: "checkmark.circle")
                  .font(.footnote)
                  .foregroundStyle(Theme.Palette.paperGreenText)
              }
              if !model.settings.feedbackError.isEmpty {
                Text(model.settings.feedbackError)
                  .font(.footnote)
                  .foregroundStyle(.red)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }
        .padding()
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("反馈")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var feedbackMessageBinding: Binding<String> {
    Binding(
      get: { model.settings.feedbackMessage },
      set: { model.settings.feedbackMessage = String($0.prefix(2000)) }
    )
  }

  private var feedbackContactBinding: Binding<String> {
    Binding(
      get: { model.settings.feedbackContact },
      set: { model.settings.feedbackContact = String($0.prefix(300)) }
    )
  }
}

struct FeedbackFloatingButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "message.fill")
        .font(.headline.weight(.semibold))
        .frame(width: 52, height: 52)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .frame(width: 52, height: 52)
    .paperGlass(.tinted(Theme.Palette.paperGreen.opacity(0.86)), in: .circle)
    .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
    .accessibilityLabel("意见反馈")
  }
}

#if DEBUG
#Preview("反馈") {
  FeedbackSheet(model: AppModel())
}
#endif
