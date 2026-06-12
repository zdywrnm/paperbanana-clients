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
        Label("账号", systemImage: "person.crop.circle")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        if let user = model.auth.currentUser {
          signedInContent(user: user)
        } else {
          authForm
        }
      }
    }
  }

  private func signedInContent(user: CurrentUser) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      HStack(spacing: Theme.Spacing.md) {
        Image(systemName: "person.crop.circle.fill")
          .font(.title2)
          .foregroundStyle(Theme.Palette.banana)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          if user.name != user.email, !user.name.isEmpty {
            Text(user.name)
              .font(.callout.weight(.semibold))
          }
          Text(user.email)
            .font(user.name != user.email && !user.name.isEmpty ? .footnote : .callout.weight(.semibold))
            .foregroundStyle(user.name != user.email && !user.name.isEmpty ? .secondary : .primary)
        }
      }
      .padding(Theme.Spacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
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
        .settingsFieldChrome()
      if model.auth.authMode == "sign-up" {
        TextField("昵称", text: $model.auth.authName)
          .settingsFieldChrome()
      }
      SecureField("密码", text: $model.auth.authPassword)
        .textContentType(.password)
        .settingsFieldChrome()

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
  }

  // MARK: - ② 后端连接

  private var backendPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        Label("后端", systemImage: "antenna.radiowaves.left.and.right")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        TextField("网关地址", text: $model.settings.apiBase)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .keyboardType(.URL)
          .settingsFieldChrome()
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
    .padding(Theme.Spacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
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
        Label("反馈", systemImage: "message")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

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
          .settingsFieldChrome()

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
        Label("关于", systemImage: "info.circle")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        HStack {
          Text("版本")
            .font(.callout)
          Spacer()
          Text(appVersionText)
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("版本 \(appVersionText)")

        ForEach(aboutLinks) { resource in
          Link(destination: resource.url) {
            HStack(spacing: Theme.Spacing.md) {
              Image(systemName: resource.systemImage)
                .foregroundStyle(Theme.Palette.banana)
                .frame(width: 24)
                .accessibilityHidden(true)
              Text(resource.title)
                .font(.callout)
              Spacer(minLength: Theme.Spacing.sm)
              Image(systemName: "safari")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityHint("在浏览器中打开")
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

// MARK: - 字段样式

private extension View {
  /// 设置页输入框统一外观：与生成页 API Key 输入一致的 thinMaterial 圆角底。
  func settingsFieldChrome() -> some View {
    padding(Theme.Spacing.md)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
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
