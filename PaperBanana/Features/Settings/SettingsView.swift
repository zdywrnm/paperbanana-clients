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
        if let user = model.currentUser {
          Label(user.email, systemImage: "person.crop.circle.fill")
          Button("退出登录", role: .destructive) {
            Task { await model.signOut() }
          }
        } else {
          Picker("登录模式", selection: $model.authMode) {
            Text("登录").tag("sign-in")
            Text("注册").tag("sign-up")
          }
          .pickerStyle(.segmented)
          TextField("邮箱", text: $model.authEmail)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textFieldStyle(.roundedBorder)
          if model.authMode == "sign-up" {
            TextField("昵称", text: $model.authName)
              .textFieldStyle(.roundedBorder)
          }
          SecureField("密码", text: $model.authPassword)
            .textFieldStyle(.roundedBorder)
          Button(model.authSubmitting ? "提交中" : "登录 / 注册") {
            Task { await model.signInOrSignUp() }
          }
          .buttonStyle(.borderedProminent)
          .paperGlassButton(prominent: true)
          if !model.authError.isEmpty {
            Text(model.authError)
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
        TextField("网关地址", text: $model.apiBase)
          .textInputAutocapitalization(.never)
          .textFieldStyle(.roundedBorder)
        HStack {
          Button("恢复默认") { model.resetBackendBase() }
          Button("检测连接") { Task { await model.refreshHealth() } }
        }
        if let health = model.health {
          Label("\(health.runtime) · \(health.backendMode.rawValue)", systemImage: "checkmark.seal")
            .foregroundStyle(.green)
        } else if !model.healthError.isEmpty {
          Text(model.healthError)
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
        Picker("类别", selection: $model.feedbackCategory) {
          ForEach(FeedbackCategory.allCases) { category in
            Text(category.title).tag(category)
          }
        }
        .pickerStyle(.segmented)
        LabeledTextEditor(title: "问题或建议", text: feedbackMessageBinding, minHeight: 120)
        Text("\(model.feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).count)/2000")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .trailing)
        TextField("联系方式（可选）", text: feedbackContactBinding)
          .textFieldStyle(.roundedBorder)
        Button(model.feedbackSubmitting ? "提交中" : "提交反馈") {
          Task { await model.submitFeedback() }
        }
        .buttonStyle(.borderedProminent)
        .paperGlassButton(prominent: true)
        .disabled(!model.canSubmitFeedback)
        if model.feedbackSuccess {
          Text("已提交。")
            .font(.footnote)
            .foregroundStyle(.green)
        }
        if !model.feedbackError.isEmpty {
          Text(model.feedbackError)
            .font(.footnote)
            .foregroundStyle(.red)
        }
      }
    }
  }

  private var feedbackMessageBinding: Binding<String> {
    Binding(
      get: { model.feedbackMessage },
      set: { model.feedbackMessage = String($0.prefix(2000)) }
    )
  }

  private var feedbackContactBinding: Binding<String> {
    Binding(
      get: { model.feedbackContact },
      set: { model.feedbackContact = String($0.prefix(300)) }
    )
  }
}
