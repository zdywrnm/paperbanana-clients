import SwiftUI

struct SettingsView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          accountPanel
          backendPanel
          feedbackPanel
        }
        .padding()
      }
      .paperCompactTabBarInset()
      .background(AppBackground())
      .navigationTitle("设置")
    }
  }

  private var accountPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 12) {
        Text("账号")
          .font(.headline)
        if let user = model.auth.currentUser {
          Label(user.email, systemImage: "person.crop.circle.fill")
          Button("退出登录", role: .destructive) {
            Task { await model.auth.signOut() }
          }
        } else {
          Picker("登录模式", selection: $model.auth.authMode) {
            Text("登录").tag("sign-in")
            Text("注册").tag("sign-up")
          }
          .pickerStyle(.segmented)
          TextField("邮箱", text: $model.auth.authEmail)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textFieldStyle(.roundedBorder)
          if model.auth.authMode == "sign-up" {
            TextField("昵称", text: $model.auth.authName)
              .textFieldStyle(.roundedBorder)
          }
          SecureField("密码", text: $model.auth.authPassword)
            .textFieldStyle(.roundedBorder)
          Button(model.auth.authSubmitting ? "提交中" : "登录 / 注册") {
            Task { await model.auth.signInOrSignUp() }
          }
          .buttonStyle(.borderedProminent)
          .paperGlassButton(prominent: true)
          if !model.auth.authError.isEmpty {
            Text(model.auth.authError)
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }
      }
    }
  }

  private var backendPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 12) {
        Text("后端")
          .font(.headline)
        TextField("网关地址", text: $model.settings.apiBase)
          .textInputAutocapitalization(.never)
          .textFieldStyle(.roundedBorder)
        HStack {
          Button("恢复默认") { model.settings.resetBackendBase() }
          Button("检测连接") { Task { await model.settings.refreshHealth() } }
        }
        if let health = model.settings.health {
          Label("\(health.runtime) · \(health.backendMode.rawValue)", systemImage: "checkmark.seal")
            .foregroundStyle(.green)
        } else if !model.settings.healthError.isEmpty {
          Text(model.settings.healthError)
            .font(.footnote)
            .foregroundStyle(.red)
        }
      }
    }
  }

  private var feedbackPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 12) {
        Text("反馈")
          .font(.headline)
        Picker("类别", selection: $model.settings.feedbackCategory) {
          ForEach(FeedbackCategory.allCases) { category in
            Text(category.title).tag(category)
          }
        }
        .pickerStyle(.segmented)
        LabeledTextEditor(title: "问题或建议", text: feedbackMessageBinding, minHeight: 120)
        Text("\(model.settings.feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).count)/2000")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .trailing)
        TextField("联系方式（可选）", text: feedbackContactBinding)
          .textFieldStyle(.roundedBorder)
        Button(model.settings.feedbackSubmitting ? "提交中" : "提交反馈") {
          Task { await model.settings.submitFeedback() }
        }
        .buttonStyle(.borderedProminent)
        .paperGlassButton(prominent: true)
        .disabled(!model.settings.canSubmitFeedback)
        if model.settings.feedbackSuccess {
          Text("已提交。")
            .font(.footnote)
            .foregroundStyle(.green)
        }
        if !model.settings.feedbackError.isEmpty {
          Text(model.settings.feedbackError)
            .font(.footnote)
            .foregroundStyle(.red)
        }
      }
    }
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
