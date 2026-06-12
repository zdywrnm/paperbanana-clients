import SwiftUI

struct SettingsView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: Theme.Spacing.lg) {
          accountPanel
          backendPanel
          feedbackPanel
          aboutPanel
        }
        .padding()
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("设置")
    }
  }

  // MARK: - ① 账号

  private var accountPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        SectionHeader(title: "账号", systemImage: "person.crop.circle")
        if let user = model.auth.currentUser {
          signedInContent(user: user)
        } else {
          authForm
        }
      }
    }
  }

  private func signedInContent(user: CurrentUser) -> some View {
    // 昵称与邮箱不同且非空时，昵称为主行、邮箱降级为辅行。
    let showsDistinctName = !user.name.isEmpty && user.name != user.email
    return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      HStack(spacing: Theme.Spacing.md) {
        Image(systemName: "person.crop.circle.fill")
          .font(.title2)
          .foregroundStyle(Theme.Palette.banana)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          if showsDistinctName {
            Text(user.name)
              .font(.callout.weight(.semibold))
          }
          Text(user.email)
            .font(showsDistinctName ? .footnote : .callout.weight(.semibold))
            .foregroundStyle(showsDistinctName ? .secondary : .primary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .fieldWell()
      .accessibilityElement(children: .combine)
      .accessibilityLabel("已登录：\(user.email)")

      Button("退出登录", role: .destructive) {
        Task { await model.auth.signOut() }
      }
      .paperGlassButton()
    }
  }

  private var authForm: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      Picker("登录模式", selection: $model.auth.authMode) {
        Text("登录").tag("sign-in")
        Text("注册").tag("sign-up")
      }
      .pickerStyle(.segmented)

      TextField("邮箱", text: $model.auth.authEmail)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .fieldWell()
      if model.auth.authMode == "sign-up" {
        TextField("昵称", text: $model.auth.authName)
          .fieldWell()
      }
      SecureField("密码", text: $model.auth.authPassword)
        .textContentType(.password)
        .fieldWell()

      Button {
        Task { await model.auth.signInOrSignUp() }
      } label: {
        Text(model.auth.authSubmitting ? "提交中" : "登录 / 注册")
          .frame(maxWidth: .infinity)
      }
      .paperGlassButton(prominent: true)
      .disabled(model.auth.authSubmitting)

      if !model.auth.authError.isEmpty {
        Text(model.auth.authError)
          .font(.footnote)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    // 登录 ↔ 注册切换时清掉上一模式的错误，避免陈旧文案误导新表单。
    .onChange(of: model.auth.authMode) { _, _ in
      model.auth.authError = ""
    }
    // 错误出现时主动播报，VoiceOver 用户不用扫到红字才知道失败。
    .onChange(of: model.auth.authError) { _, newValue in
      guard !newValue.isEmpty else { return }
      AccessibilityNotification.Announcement(newValue).post()
    }
  }

  // MARK: - ② 后端连接

  private var backendPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        SectionHeader(title: "后端", systemImage: "antenna.radiowaves.left.and.right")

        TextField("网关地址", text: $model.settings.apiBase)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .keyboardType(.URL)
          .fieldWell()
          .accessibilityLabel("网关地址输入")
        Text("请使用网关域名；直连 Laf 域名将被拒绝身份相关操作")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        healthStatusRow

        ViewThatFits(in: .horizontal) {
          HStack(spacing: Theme.Spacing.md) { backendButtons }
          VStack(alignment: .leading, spacing: Theme.Spacing.sm) { backendButtons }
        }
      }
    }
  }

  /// 连接健康状态：彩点 + 文案（已连接 / 检测失败 / 未检测）。
  private var healthStatusRow: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Circle()
        .fill(healthDotColor)
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
      Text(healthStatusText)
        .font(.footnote.weight(.medium))
        .foregroundStyle(model.settings.health == nil && model.settings.healthError.isEmpty ? .secondary : .primary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .fieldWell()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("后端连接状态：\(healthStatusText)")
  }

  private var healthDotColor: Color {
    if model.settings.health != nil { return .green }
    if !model.settings.healthError.isEmpty { return .red }
    return .gray
  }

  private var healthStatusText: String {
    if let health = model.settings.health {
      return "已连接 · \(health.runtime) · \(health.backendMode.rawValue)"
    }
    if !model.settings.healthError.isEmpty {
      return model.settings.healthError
    }
    return "尚未检测连接"
  }

  @ViewBuilder
  private var backendButtons: some View {
    Button("恢复默认") { model.settings.resetBackendBase() }
      .paperGlassButton()
    Button("检测连接") { Task { await model.settings.refreshHealth() } }
      .paperGlassButton(prominent: true)
      .accessibilityHint("立即检查网关连通性")
  }

  // MARK: - ③ 反馈

  private var feedbackPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        SectionHeader(title: "反馈", systemImage: "message")

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
          .fieldWell()

        Button {
          Task { await model.settings.submitFeedback() }
        } label: {
          Text(model.settings.feedbackSubmitting ? "提交中" : "提交反馈")
            .frame(maxWidth: .infinity)
        }
        .paperGlassButton(prominent: true)
        .disabled(!model.settings.canSubmitFeedback)

        if model.settings.feedbackSuccess {
          Label("已提交。", systemImage: "checkmark.circle")
            .font(.footnote)
            .foregroundStyle(.green)
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

  // MARK: - ④ 关于

  private var aboutPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        SectionHeader(title: "关于", systemImage: "info.circle")

        HStack {
          Text("版本")
            .font(.callout)
          Spacer()
          Text(appVersionText)
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .fieldWell()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("版本 \(appVersionText)")

        ForEach(aboutLinks) { resource in
          GuideResourceRow(resource: resource, embeddedInPanel: true)
        }
      }
    }
  }

  /// 版本号从 Bundle 读取，不在代码里硬编码。
  private var appVersionText: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    return "\(version) (\(build))"
  }

  /// 关于区只放最核心的两条外链；完整资源列表在"指南"页。
  private var aboutLinks: [GuideResource] {
    PaperBananaGuide.resources.filter { ["website", "github"].contains($0.id) }
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

#if DEBUG
#Preview("未登录") {
  SettingsView(model: AppModel())
}

#Preview("已登录") {
  let model = AppModel()
  let _ = {
    model.auth.currentUser = try? JSONDecoder().decode(
      CurrentUser.self,
      from: Data(#"{"id":"u-preview","email":"preview@paperbanana.app","name":"Preview"}"#.utf8)
    )
  }()
  SettingsView(model: model)
}
#endif
