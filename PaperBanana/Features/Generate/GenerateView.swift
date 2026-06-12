import SwiftUI
import PhotosUI

struct GenerateView: View {
  @Bindable var model: AppModel
  @State private var isImporterPresented = false
  @State private var selectedPhotoItems: [PhotosPickerItem] = []
  @Namespace private var submitNamespace
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var importPipeline: ReferenceImportPipeline {
    ReferenceImportPipeline(generation: model.generation)
  }

  private var isAdvanced: Bool {
    model.generation.draft.configurationMode == .advanced
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            hero
            providerSection
            inputSection
            outputSection
            advancedSection
            submitHints
            if let job = model.jobs.currentJob {
              JobDetailView(model: model, job: job)
                .id("pipeline")
            }
          }
          .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) {
          // 任务进行中：本页底栏隐藏，进度交给页内流水线卡 + 全局 tab accessory，避免三处重复。
          if !model.jobs.hasActiveJob {
            submitBar
              .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .animation(Theme.Motion.stateChange, value: model.jobs.hasActiveJob)
        .onChange(of: model.jobs.currentJobID) { _, newID in
          guard !newID.isEmpty else { return }
          withAnimation(reduceMotion ? nil : Theme.Motion.entrance) {
            proxy.scrollTo("pipeline", anchor: .top)
          }
        }
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("PaperBanana")
      .task(id: model.generation.modelCapabilityQueryID) {
        await model.generation.refreshMainModelCapability()
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task { await model.settings.refreshHealth() }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .paperGlassButton()
          .accessibilityLabel("刷新后端状态")
        }
      }
      .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: ReferenceImportPipeline.referenceContentTypes, allowsMultipleSelection: true) { result in
        switch result {
        case .success(let urls):
          for url in urls.prefix(ReferenceImageLimits.maxCount - model.generation.draft.referenceImages.count) {
            importPipeline.addReference(url)
          }
        case .failure(let error):
          model.generation.referenceUploadError = formatUserFacingError(error)
        }
      }
      .onChange(of: selectedPhotoItems) { _, items in
        guard !items.isEmpty else { return }
        Task {
          await importPipeline.addPhotoReferences(items)
          selectedPhotoItems = []
        }
      }
    }
  }

  // MARK: - Hero

  private var hero: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        HStack(spacing: Theme.Spacing.md) {
          Image(systemName: "graduationcap.fill")
            .font(.title2)
            .foregroundStyle(Theme.Palette.banana)
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 2) {
            Text("论文图示工作台")
              .font(.title2.bold())
            Text(model.settings.health?.runtime == "gateway" ? "已连接 Sealos 网关" : (model.settings.healthError.isEmpty ? "默认连接 PaperBanana 网关" : model.settings.healthError))
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Spacer()
          StatusPill(text: model.auth.currentUser?.email ?? "未登录", systemImage: model.auth.currentUser == nil ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.fill")
        }
        Text("生成论文框架图、流程图、系统架构图和数据统计图；API Key 仅保存在本机 Keychain。")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - ① 平台与密钥

  private var providerSection: some View {
    sectionCard("平台与密钥") {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Theme.Spacing.sm) {
          ForEach(ProviderCatalog.order) { provider in
            providerChip(provider)
          }
        }
        .animation(Theme.Motion.stateChange, value: model.generation.draft.provider)
      }
      .accessibilityLabel("模型平台选择")

      SecureField(model.generation.selectedProviderConfig.keyPlaceholder, text: Binding(get: { model.generation.selectedAPIKey }, set: { model.generation.updateSelectedAPIKey($0) }))
        .textContentType(.password)
        .fieldWell()
        .accessibilityLabel("\(model.generation.selectedProviderConfig.label) API Key 输入")

      APIKeyGuideView(config: model.generation.selectedProviderConfig)
    }
  }

  private func providerChip(_ provider: ProviderID) -> some View {
    let isSelected = model.generation.draft.provider == provider
    let label = ProviderCatalog.config(for: provider).label
    return Button {
      model.generation.selectProvider(provider)
    } label: {
      Text(label)
        .font(.subheadline.weight(isSelected ? .semibold : .regular))
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background {
          if isSelected {
            Capsule().fill(Theme.Palette.banana.opacity(0.22))
          }
          Capsule().strokeBorder(isSelected ? AnyShapeStyle(Theme.Palette.banana) : AnyShapeStyle(.quaternary), lineWidth: 1.5)
        }
        .contentShape(.capsule)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("模型平台 \(label)")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  // MARK: - ② 内容输入

  private var inputSection: some View {
    sectionCard("内容输入") {
      LabeledTextEditor(title: "论文方法内容", text: $model.generation.draft.methodContent, minHeight: 180)
      LabeledTextEditor(title: "目标图注", text: $model.generation.draft.caption, minHeight: 90)

      HStack {
        Text("信息图类别")
          .font(.subheadline)
        Spacer()
        Picker("信息图类别", selection: $model.generation.draft.infographicCategoryID) {
          ForEach(PaperBananaSamples.categories) { category in
            Text(category.label).tag(category.id)
          }
        }
        .accessibilityLabel("信息图类别")
      }
      Text(model.generation.draft.selectedCategory.detail)
        .font(.footnote)
        .foregroundStyle(.secondary)
      if model.generation.draft.taskName == .plot {
        Label("统计图会走独立 plot worker 渲染。", systemImage: "chart.xyaxis.line")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      ReferenceUploadStrip(
        model: model,
        selectedPhotoItems: $selectedPhotoItems,
        showImporter: { isImporterPresented = true }
      )
    }
  }

  // MARK: - ③ 输出设置

  private var outputSection: some View {
    sectionCard("输出设置") {
      HStack {
        Text("导出格式")
          .font(.subheadline)
        Spacer()
        Picker("导出格式", selection: $model.generation.draft.outputFormat) {
          ForEach(OutputFormat.allCases) { format in
            Text(format.title).tag(format)
          }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityLabel("导出格式")
      }
      HStack {
        Text("清晰度")
          .font(.subheadline)
        Spacer()
        Picker("清晰度", selection: $model.generation.draft.imageSize) {
          ForEach(ProviderCatalog.supportedResolutions(provider: model.generation.draft.provider, imageModel: model.generation.activeImageModelName)) { size in
            Text(size.title).tag(size)
          }
        }
        .accessibilityLabel("清晰度")
      }
      HStack {
        Text("画面比例")
          .font(.subheadline)
        Spacer()
        Picker("画面比例", selection: $model.generation.draft.aspectRatio) {
          ForEach(["16:9", "21:9", "3:2", "1:1"], id: \.self) { ratio in
            Text(ratio).tag(ratio)
          }
        }
        .accessibilityLabel("画面比例")
      }
      if !isAdvanced {
        Text("普通模式固定 16:9 提交；切换专业参数后画面比例才会生效。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - ④ 专业参数

  private var advancedSection: some View {
    sectionCard("专业参数", trailing: {
      Picker("模式", selection: $model.generation.draft.configurationMode) {
        ForEach(ConfigurationMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .fixedSize()
      .accessibilityLabel("配置模式")
      .accessibilityHint("专业模式可调模型、流水线与评审参数")
    }) {
      if isAdvanced {
        advancedControls
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
      } else {
        Text("普通模式使用平台推荐的模型与流水线参数。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .animation(Theme.Motion.stateChange, value: isAdvanced)
  }

  @ViewBuilder
  private var advancedControls: some View {
    labeledPickerRow("主模型") {
      Picker("主模型", selection: Binding(get: { model.generation.draft.mainModelName }, set: { model.generation.selectMainModel($0) })) {
        ForEach(model.generation.selectedProviderConfig.mainModels) { option in
          Text(option.displayName).tag(option.value)
        }
      }
      .accessibilityLabel("主模型")
    }
    labeledPickerRow("图像生成模型") {
      Picker("图像生成模型", selection: Binding(get: { model.generation.draft.imageModelName }, set: { model.generation.selectImageModel($0) })) {
        ForEach(model.generation.selectedProviderConfig.imageModels) { option in
          Text(option.displayName).tag(option.value)
        }
      }
      .accessibilityLabel("图像生成模型")
    }
    if model.generation.activeReferenceImageMode != .mainModel {
      labeledPickerRow("参考图识别模型") {
        Picker("参考图识别模型", selection: $model.generation.draft.referenceVisionModelName) {
          ForEach(model.generation.selectedProviderConfig.visionModels) { option in
            Text(option.displayName).tag(option.value)
          }
        }
        .accessibilityLabel("参考图识别模型")
      }
    }
    labeledPickerRow("生成流程") {
      Picker("生成流程", selection: $model.generation.draft.pipelineMode) {
        ForEach(PipelineMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .accessibilityLabel("生成流程")
    }
    labeledPickerRow("检索设置") {
      Picker("检索设置", selection: $model.generation.draft.retrievalSetting) {
        ForEach(RetrievalSetting.allCases) { setting in
          Text(setting.title).tag(setting)
        }
      }
      .accessibilityLabel("检索设置")
      .disabled(!model.generation.draft.referenceImages.isEmpty)
    }
    if !model.generation.draft.referenceImages.isEmpty {
      Text("已上传参考图，检索自动关闭。")
        .font(.footnote)
        .foregroundStyle(.secondary)
      Picker("参考图处理方式", selection: $model.generation.draft.referenceImageMode) {
        Text(ReferenceImageMode.visionModel.title).tag(ReferenceImageMode.visionModel)
        Text(ReferenceImageMode.mainModel.title).tag(ReferenceImageMode.mainModel)
          .disabled(!model.generation.mainModelCanReadReferenceImages)
      }
      .pickerStyle(.segmented)
      Text(model.generation.referenceCapabilityNote)
        .font(.footnote)
        .foregroundStyle(model.generation.mainModelDirectUnsupported ? .red : .secondary)
    }
    Stepper("候选图数量 \(model.generation.draft.numCandidates)", value: $model.generation.draft.numCandidates, in: 1...3)
    Stepper("评审轮数 \(model.generation.draft.maxCriticRounds)", value: $model.generation.draft.maxCriticRounds, in: 0...3)
    if model.generation.draft.retrievalSetting == .manual && model.generation.draft.referenceImages.isEmpty {
      ManualReferencePanel(model: model)
    }
  }

  // MARK: - 提交提示

  @ViewBuilder
  private var submitHints: some View {
    if !model.generation.submitError.isEmpty {
      Label(model.generation.submitError, systemImage: "exclamationmark.triangle")
        .font(.footnote)
        .foregroundStyle(.red)
    }
    if model.generation.mainModelDirectUnsupported {
      Label("当前主模型不能直读参考图，请切换为独立识别模型。", systemImage: "eye.trianglebadge.exclamationmark")
        .font(.footnote)
        .foregroundStyle(.red)
    } else if !model.generation.hasRequiredManualReferences {
      Label("手动参考模式需要至少选择一个参考案例。", systemImage: "checklist")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - 底部提交栏

  /// 空闲态大按钮 ↔ 提交中紧凑进度胶囊，经同一 glassEffectID 在容器内 morph。
  private var submitBar: some View {
    GlassEffectContainer {
      if model.generation.isSubmitting {
        HStack(spacing: Theme.Spacing.sm) {
          ProgressView()
            .controlSize(.small)
          Text("正在提交…")
            .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .paperGlass(.interactive, in: .capsule)
        .glassEffectID("submit", in: submitNamespace)
        .accessibilityLabel("正在提交生成任务")
      } else {
        Button {
          Task { await model.generation.submitJob() }
        } label: {
          Label("开始生成", systemImage: "sparkles")
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .paperGlassButton(prominent: true)
        .glassEffectID("submit", in: submitNamespace)
        .disabled(!model.generation.canSubmit)
        .accessibilityLabel("开始生成")
        .accessibilityHint("提交论文方法内容，启动多智能体生成流水线")
      }
    }
    .animation(Theme.Motion.stateChange, value: model.generation.isSubmitting)
    .padding(.horizontal)
  }

  // MARK: - 分组卡

  private func labeledPickerRow(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
    HStack(spacing: Theme.Spacing.lg) {
      Text(title)
        .font(.subheadline)
        .fixedSize()
      Spacer(minLength: 0)
      picker()
        .labelsHidden()
        .lineLimit(1)
    }
  }

  private func sectionCard(
    _ title: String,
    @ViewBuilder trailing: () -> some View = { EmptyView() },
    @ViewBuilder content: () -> some View
  ) -> some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        HStack(alignment: .firstTextBaseline) {
          SectionHeader(title: title)
          Spacer()
          trailing()
        }
        content()
      }
    }
  }
}

#if DEBUG
#Preview("生成表单") {
  GenerateView(model: AppModel())
}
#endif
