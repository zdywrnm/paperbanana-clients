import SwiftUI

/// 删除账号（App Store 5.1.1(v)）。二次确认方式：重新输入登录密码。
/// 成功后服务端已真删账号并清 session，客户端清空所有本机数据并自动回到未登录态。
struct DeleteAccountSheet: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var password = ""
  @State private var submitting = false
  @State private var errorText = ""

  private var canDelete: Bool {
    !submitting && !password.isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
          GlassPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
              SectionHeader(title: "删除账号", systemImage: "person.crop.circle.badge.xmark")

              warningBanner

              Text("请重新输入登录密码以确认删除。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

              VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("登录密码")
                  .font(.footnote.weight(.semibold))
                  .foregroundStyle(.secondary)
                SecureField("请输入当前账号密码", text: $password)
                  .textContentType(.password)
                  .submitLabel(.done)
                  .paperFieldWell()
                  .accessibilityLabel("登录密码")
                  .onChange(of: password) { _, _ in
                    // 用户重新输入即清掉上一次的错误，避免陈旧红字误导。
                    if !errorText.isEmpty { errorText = "" }
                  }
              }

              Button {
                Task { await submit() }
              } label: {
                Label(submitting ? "删除中" : "永久删除", systemImage: "trash")
                  .frame(maxWidth: .infinity)
              }
              .paperGlassButton(prominent: true)
              .disabled(!canDelete)
              .accessibilityLabel(submitting ? "正在删除账号" : "永久删除账号")

              Button("取消") { dismiss() }
                .buttonStyle(.plain)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.paperGreenText)
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(submitting)

              if !errorText.isEmpty {
                Text(errorText)
                  .font(.footnote)
                  .foregroundStyle(Theme.Palette.warningText)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }
        .padding()
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("删除账号")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") { dismiss() }
            .disabled(submitting)
        }
      }
    }
    .presentationDetents([.medium, .large])
    .interactiveDismissDisabled(submitting)
    .onChange(of: errorText) { _, newValue in
      // 错误出现时主动播报，VoiceOver 用户不必扫到红字才知道失败。
      guard !newValue.isEmpty else { return }
      AccessibilityNotification.Announcement(newValue).post()
    }
  }

  private var warningBanner: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.md) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.headline)
        .foregroundStyle(Theme.Palette.warning)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text("此操作不可恢复")
          .font(.callout.weight(.semibold))
          .foregroundStyle(Theme.Palette.warningText)
        Text("删除后将永久清除：")
          .font(.footnote)
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 2) {
          ForEach(deletionItems, id: \.self) { item in
            Label(item, systemImage: "minus")
              .labelStyle(.titleAndIcon)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.md)
    .background(Theme.Palette.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        .strokeBorder(Theme.Palette.warning.opacity(0.32), lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("警告：此操作不可恢复，删除后将永久清除账号、所有任务记录与生成结果、已保存模板，以及本机保存的 API Key。")
  }

  private let deletionItems = [
    "账号本身",
    "所有任务记录与生成结果",
    "已保存的模板",
    "本机保存的 API Key"
  ]

  private func submit() async {
    guard canDelete else { return }
    submitting = true
    errorText = ""
    defer { submitting = false }
    do {
      try await model.auth.deleteAccount(password: password)
      // 成功后服务端已真删账号、清 session；currentUser 已置 nil，SettingsView 会自动刷新回未登录态。
      dismiss()
    } catch {
      errorText = formatUserFacingError(error)
    }
  }
}

#if DEBUG
#Preview("删除账号") {
  let model = AppModel()
  let _ = {
    model.auth.currentUser = try? JSONDecoder().decode(
      CurrentUser.self,
      from: Data(#"{"id":"u-preview","email":"preview@paperbanana.app","name":"Preview"}"#.utf8)
    )
  }()
  return Color.clear.sheet(isPresented: .constant(true)) {
    DeleteAccountSheet(model: model)
  }
}
#endif
