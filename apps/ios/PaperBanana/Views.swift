import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import WebKit

struct RootView: View {
  @Bindable var model: AppModel
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    rootContent
    .sheet(item: $model.refineSourceImage) { image in
      RefineSheet(model: model, image: image)
    }
    .sheet(item: $model.exportedResultFile) { file in
      ShareSheet(items: [file.url])
        .presentationDetents([.medium, .large])
    }
    .alert("PaperBanana", isPresented: $model.isAlertPresented) {
      Button("好", role: .cancel) {}
    } message: {
      Text(model.alertMessage)
    }
  }

  @ViewBuilder
  private var rootContent: some View {
    if horizontalSizeClass == .regular {
      NavigationSplitView {
        List(selection: Binding<AppTab?>(
          get: { model.selectedTab },
          set: { if let tab = $0 { model.selectedTab = tab } }
        )) {
          ForEach(AppTab.allCases) { tab in
            Label(tab.title, systemImage: tab.symbol)
              .tag(tab)
          }
        }
        .navigationTitle("PaperBanana")
      } detail: {
        selectedContent
      }
    } else {
      TabView(selection: $model.selectedTab) {
        GenerateView(model: model)
          .tabItem { Label(AppTab.generate.title, systemImage: AppTab.generate.symbol) }
          .tag(AppTab.generate)

        RecordsView(model: model)
          .tabItem { Label(AppTab.records.title, systemImage: AppTab.records.symbol) }
          .tag(AppTab.records)

        GuideView(model: model)
          .tabItem { Label(AppTab.guide.title, systemImage: AppTab.guide.symbol) }
          .tag(AppTab.guide)

        TemplatesView(model: model)
          .tabItem { Label(AppTab.templates.title, systemImage: AppTab.templates.symbol) }
          .tag(AppTab.templates)

        SettingsView(model: model)
          .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbol) }
          .tag(AppTab.settings)
      }
      .toolbarBackground(.regularMaterial, for: .tabBar)
      .toolbarBackground(.visible, for: .tabBar)
    }
  }

  @ViewBuilder
  private var selectedContent: some View {
    switch model.selectedTab {
    case .generate:
      GenerateView(model: model)
    case .records:
      RecordsView(model: model)
    case .guide:
      GuideView(model: model)
    case .templates:
      TemplatesView(model: model)
    case .settings:
      SettingsView(model: model)
    }
  }
}

struct GenerateView: View {
  @Bindable var model: AppModel
  @State private var isImporterPresented = false
  @State private var selectedPhotoItems: [PhotosPickerItem] = []

  private var referenceContentTypes: [UTType] {
    [
      .png,
      .jpeg,
      UTType(filenameExtension: "webp") ?? .image,
      UTType(filenameExtension: "svg") ?? .image
    ]
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          hero
          configurationPanel
          inputPanel
          if model.draft.configurationMode == .advanced {
            advancedPanel
          }
          submitPanel
          if let job = model.currentJob {
            JobDetailView(model: model, job: job)
          }
        }
        .padding()
      }
      .paperCompactTabBarInset()
      .background(AppBackground())
      .navigationTitle("PaperBanana")
      .task(id: model.modelCapabilityQueryID) {
        await model.refreshMainModelCapability()
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task { await model.refreshHealth() }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .paperGlassButton()
          .accessibilityLabel("刷新后端状态")
        }
      }
      .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: referenceContentTypes, allowsMultipleSelection: true) { result in
        switch result {
        case .success(let urls):
          for url in urls.prefix(ReferenceImageLimits.maxCount - model.draft.referenceImages.count) {
            addReference(url)
          }
        case .failure(let error):
          model.referenceUploadError = formatUserFacingError(error)
        }
      }
      .onChange(of: selectedPhotoItems) { _, items in
        guard !items.isEmpty else { return }
        Task {
          await addPhotoReferences(items)
          selectedPhotoItems = []
        }
      }
    }
  }

  private var hero: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 12) {
          Image(systemName: "graduationcap.fill")
            .font(.title2)
            .foregroundStyle(.yellow)
          VStack(alignment: .leading, spacing: 2) {
            Text("论文图示工作台")
              .font(.title2.bold())
            Text(model.health?.runtime == "gateway" ? "已连接 Sealos 网关" : (model.healthError.isEmpty ? "默认连接 PaperBanana 网关" : model.healthError))
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Spacer()
          StatusPill(text: model.currentUser?.email ?? "未登录", systemImage: model.currentUser == nil ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle.fill")
        }
        Text("生成论文框架图、流程图、系统架构图和数据统计图；API Key 仅保存在本机 Keychain。")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var configurationPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 14) {
        Picker("模式", selection: $model.draft.configurationMode) {
          ForEach(ConfigurationMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        Picker("模型平台", selection: Binding(get: { model.draft.provider }, set: { model.selectProvider($0) })) {
          ForEach(ProviderCatalog.order) { provider in
            Text(ProviderCatalog.config(for: provider).label).tag(provider)
          }
        }
        .pickerStyle(.segmented)

        SecureField(model.selectedProviderConfig.keyPlaceholder, text: Binding(get: { model.selectedAPIKey }, set: { model.updateSelectedAPIKey($0) }))
          .textContentType(.password)
          .padding(12)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

        APIKeyGuideView(config: model.selectedProviderConfig)

        HStack {
          Picker("导出格式", selection: $model.draft.outputFormat) {
            ForEach(OutputFormat.allCases) { format in
              Text(format.title).tag(format)
            }
          }
          Picker("清晰度", selection: $model.draft.imageSize) {
            ForEach(ProviderCatalog.supportedResolutions(provider: model.draft.provider, imageModel: model.activeImageModelName)) { size in
              Text(size.title).tag(size)
            }
          }
        }
      }
    }
  }

  private var inputPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 14) {
        Picker("信息图类别", selection: $model.draft.infographicCategoryID) {
          ForEach(PaperBananaSamples.categories) { category in
            Text(category.label).tag(category.id)
          }
        }
        Text(model.draft.selectedCategory.detail)
          .font(.footnote)
          .foregroundStyle(.secondary)
        if model.draft.taskName == .plot {
          Label("统计图会走独立 plot worker 渲染。", systemImage: "chart.xyaxis.line")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        ReferenceUploadStrip(
          model: model,
          selectedPhotoItems: $selectedPhotoItems,
          showImporter: { isImporterPresented = true }
        )

        LabeledTextEditor(title: "论文方法内容", text: $model.draft.methodContent, minHeight: 180)
        LabeledTextEditor(title: "目标图注", text: $model.draft.caption, minHeight: 90)
      }
    }
  }

  private var advancedPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 14) {
        Picker("主模型", selection: Binding(get: { model.draft.mainModelName }, set: { model.selectMainModel($0) })) {
          ForEach(model.selectedProviderConfig.mainModels) { option in
            Text(option.displayName).tag(option.value)
          }
        }
        Picker("图像生成模型", selection: Binding(get: { model.draft.imageModelName }, set: { model.selectImageModel($0) })) {
          ForEach(model.selectedProviderConfig.imageModels) { option in
            Text(option.displayName).tag(option.value)
          }
        }
        if model.activeReferenceImageMode != .mainModel {
          Picker("参考图识别模型", selection: $model.draft.referenceVisionModelName) {
            ForEach(model.selectedProviderConfig.visionModels) { option in
              Text(option.displayName).tag(option.value)
            }
          }
        }
        Picker("生成流程", selection: $model.draft.pipelineMode) {
          ForEach(PipelineMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        Picker("检索设置", selection: $model.draft.retrievalSetting) {
          ForEach(RetrievalSetting.allCases) { setting in
            Text(setting.title).tag(setting)
          }
        }
        .disabled(!model.draft.referenceImages.isEmpty)
        if !model.draft.referenceImages.isEmpty {
          Text("已上传参考图，检索自动关闭。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        if !model.draft.referenceImages.isEmpty {
          Picker("参考图处理方式", selection: $model.draft.referenceImageMode) {
            Text(ReferenceImageMode.visionModel.title).tag(ReferenceImageMode.visionModel)
            Text(ReferenceImageMode.mainModel.title).tag(ReferenceImageMode.mainModel)
              .disabled(!model.mainModelCanReadReferenceImages)
          }
          .pickerStyle(.segmented)
          Text(model.referenceCapabilityNote)
            .font(.footnote)
            .foregroundStyle(model.mainModelDirectUnsupported ? .red : .secondary)
        }
        Stepper("候选图数量 \(model.draft.numCandidates)", value: $model.draft.numCandidates, in: 1...3)
        Stepper("评审轮数 \(model.draft.maxCriticRounds)", value: $model.draft.maxCriticRounds, in: 0...3)
        Picker("画面比例", selection: $model.draft.aspectRatio) {
          ForEach(["16:9", "21:9", "3:2", "1:1"], id: \.self) { ratio in
            Text(ratio).tag(ratio)
          }
        }
        if model.draft.retrievalSetting == .manual && model.draft.referenceImages.isEmpty {
          ManualReferencePanel(model: model)
        }
      }
    }
  }

  private var submitPanel: some View {
    VStack(spacing: 10) {
      Button {
        Task { await model.submitJob() }
      } label: {
        Label(model.isSubmitting ? "提交中" : "生成候选图", systemImage: model.isSubmitting ? "hourglass" : "paperplane.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!model.canSubmit)
      .paperGlassButton(prominent: true)

      if !model.submitError.isEmpty {
        Label(model.submitError, systemImage: "exclamationmark.triangle")
          .font(.footnote)
          .foregroundStyle(.red)
      }
      if model.mainModelDirectUnsupported {
        Label("当前主模型不能直读参考图，请切换为独立识别模型。", systemImage: "eye.trianglebadge.exclamationmark")
          .font(.footnote)
          .foregroundStyle(.red)
      } else if !model.hasRequiredManualReferences {
        Label("手动参考模式需要至少选择一个参考案例。", systemImage: "checklist")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func addReference(_ url: URL) {
    let didStart = url.startAccessingSecurityScopedResource()
    defer {
      if didStart { url.stopAccessingSecurityScopedResource() }
    }
    do {
      let data = try Data(contentsOf: url)
      let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
      model.addReferenceFile(filename: url.lastPathComponent, mimeType: type?.preferredMIMEType, data: data)
    } catch {
      model.referenceUploadError = formatUserFacingError(error)
    }
  }

  @MainActor
  private func addPhotoReferences(_ items: [PhotosPickerItem]) async {
    let remainingSlots = ReferenceImageLimits.maxCount - model.draft.referenceImages.count
    guard remainingSlots > 0 else {
      model.referenceUploadError = "最多只能上传 \(ReferenceImageLimits.maxCount) 张参考图。"
      return
    }

    for (index, item) in items.prefix(remainingSlots).enumerated() {
      await addPhotoReference(item, index: index)
    }
  }

  @MainActor
  private func addPhotoReference(_ item: PhotosPickerItem, index: Int) async {
    do {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        model.referenceUploadError = "无法读取所选照片。"
        return
      }

      if let type = acceptedReferenceContentType(from: item.supportedContentTypes) {
        model.addReferenceFile(
          filename: photoFilename(index: index, contentType: type),
          mimeType: type.preferredMIMEType,
          data: data
        )
        return
      }

      guard let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.92) else {
        model.referenceUploadError = "无法将所选照片转换为 JPG。"
        return
      }

      model.addReferenceFile(
        filename: photoFilename(index: index, contentType: .jpeg),
        mimeType: "image/jpeg",
        data: jpegData
      )
    } catch {
      model.referenceUploadError = formatUserFacingError(error)
    }
  }

  private func acceptedReferenceContentType(from contentTypes: [UTType]) -> UTType? {
    contentTypes.first { type in
      guard let mimeType = type.preferredMIMEType else { return false }
      return ReferenceImageLimits.acceptedMimeTypes.contains(mimeType)
    }
  }

  private func photoFilename(index: Int, contentType: UTType) -> String {
    let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
    return "photo-reference-\(index + 1).\(fileExtension)"
  }
}

struct ReferenceUploadStrip: View {
  @Bindable var model: AppModel
  @Binding var selectedPhotoItems: [PhotosPickerItem]
  let showImporter: () -> Void

  private var remainingSlots: Int {
    max(0, ReferenceImageLimits.maxCount - model.draft.referenceImages.count)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("参考图", systemImage: "photo.on.rectangle")
          .font(.headline)
        Spacer()
        PhotosPicker(
          selection: $selectedPhotoItems,
          maxSelectionCount: max(1, remainingSlots),
          matching: .images
        ) {
          Label("照片", systemImage: "photo.badge.plus")
        }
        .disabled(remainingSlots == 0)
        Button(action: showImporter) {
          Label("文件", systemImage: "folder.badge.plus")
        }
        .disabled(remainingSlots == 0)
      }
      if model.draft.referenceImages.isEmpty {
        Text("支持 PNG、JPG、WebP、SVG，最多 3 张。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(model.draft.referenceImages) { image in
          HStack {
            Image(systemName: image.mimeType.contains("svg") ? "doc.richtext" : "photo")
            VStack(alignment: .leading) {
              Text(image.filename)
                .lineLimit(1)
              Text(ByteCountFormatter.string(fromByteCount: Int64(image.size), countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
              model.removeReferenceImage(image)
            } label: {
              Image(systemName: "trash")
            }
          }
          .padding(10)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
      }
      if !model.referenceUploadError.isEmpty {
        Text(model.referenceUploadError)
          .font(.footnote)
          .foregroundStyle(.red)
      }
    }
  }
}

struct ManualReferencePanel: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("手动参考")
          .font(.headline)
        Spacer()
        Button("刷新") {
          Task { await model.loadReferenceLibrary() }
        }
      }
      if model.referenceLibrary.isEmpty && !model.referenceLibraryLoading {
        Button("加载参考库") {
          Task { await model.loadReferenceLibrary() }
        }
      }
      if model.referenceLibraryLoading {
        ProgressView()
      }
      if !model.referenceLibraryError.isEmpty {
        Text(model.referenceLibraryError)
          .font(.footnote)
          .foregroundStyle(.red)
      }
      ForEach(model.referenceLibrary.prefix(12)) { item in
        Toggle(isOn: Binding(
          get: { model.draft.manualReferenceIds.contains(item.id) },
          set: { _ in model.toggleManualReference(item) }
        )) {
          VStack(alignment: .leading) {
            Text(item.title.isEmpty ? item.id : item.title)
            if !item.summary.isEmpty {
              Text(item.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
          }
        }
      }
    }
  }
}

struct RecordsView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      Group {
        if model.currentUser == nil {
          ContentUnavailableView {
            Label("登录后查看任务记录", systemImage: "person.crop.circle.badge.exclamationmark")
          } description: {
            Text("不登录也可以生成；登录后任务会保存到账号。")
          } actions: {
            Button("去登录") { model.selectedTab = .settings }
          }
        } else {
          List(selection: $model.selectedRecordID) {
            ForEach(model.userJobs) { job in
              NavigationLink(value: job.id) {
                JobRow(job: job)
              }
            }
          }
          .navigationDestination(for: String.self) { id in
            if let job = model.userJobs.first(where: { $0.id == id }) {
              JobDetailView(model: model, job: job)
            }
          }
          .refreshable { await model.loadUserJobs(silent: false) }
        }
      }
      .navigationTitle("任务记录")
      .toolbar {
        Button {
          Task { await model.loadUserJobs(silent: false) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
      }
    }
  }
}

struct JobRow: View {
  let job: Job

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(job.title)
          .lineLimit(1)
        Spacer()
        StatusPill(text: job.statusKind.title, systemImage: job.statusKind == .failed ? "xmark.circle" : "checkmark.circle")
      }
      Text([job.taskName.rawValue, job.outputFormat.rawValue.uppercased(), job.imageSize.rawValue].joined(separator: " · "))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

struct JobDetailView: View {
  @Bindable var model: AppModel
  let job: Job

  var body: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text(job.title)
            .font(.headline)
          Spacer()
          StatusPill(text: job.statusKind.title, systemImage: job.statusKind == .failed ? "xmark.circle" : "sparkles")
        }
        if job.hasExportableAssets {
          Button {
            Task { await model.exportJobArchive(job) }
          } label: {
            Label(model.exportingJobArchiveID == job.id ? "打包中" : "分享全部", systemImage: model.exportingJobArchiveID == job.id ? "hourglass" : "archivebox")
          }
          .buttonStyle(.bordered)
          .paperGlassButton()
          .disabled(model.exportingJobArchiveID == job.id)
        }
        JobMetadataGrid(job: job)
        JobPromptEcho(job: job)
        if job.statusKind == .failed && !job.failureText.isEmpty {
          Text(formatUserFacingError(job.failureText))
            .foregroundStyle(.red)
        }
        if !job.retrievedReferences.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("检索参考")
              .font(.subheadline.bold())
            FlowText(items: job.retrievedReferences.map { $0.title.isEmpty ? $0.id : $0.title })
          }
        }
        if !job.resultImages.isEmpty {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            ForEach(job.resultImages) { image in
              ResultImageView(model: model, image: image, outputFormat: job.outputFormat)
            }
          }
        } else if job.statusKind == .running || job.statusKind == .queued {
          ProgressView("生成中")
        }
        if !job.visibleReferenceImages.isEmpty {
          ReferenceEchoGrid(model: model, references: job.visibleReferenceImages)
        } else if !job.referenceImages.isEmpty {
          Label("参考图 \(job.referenceImages.count) 张，后端未返回可预览 URL。", systemImage: "photo.on.rectangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        if !job.stages.isEmpty {
          StageTimelineView(model: model, stages: job.stages)
        }
      }
    }
    .padding()
    .background(AppBackground())
    .navigationTitle("任务详情")
  }
}

struct ReferenceEchoGrid: View {
  @Bindable var model: AppModel
  let references: [ReferenceImageAsset]

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: 150), spacing: 12)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text("参考回显")
          .font(.subheadline.bold())
        Text("仅作风格参考，不决定版式。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(Array(references.enumerated()), id: \.element.id) { index, reference in
          ReferenceEchoCard(model: model, reference: reference, index: index)
        }
      }
    }
  }
}

struct ReferenceEchoCard: View {
  @Bindable var model: AppModel
  let reference: ReferenceImageAsset
  let index: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ReferenceImagePreview(url: model.resolvedImageURL(reference.url ?? ""), mimeType: reference.mimeType)
      HStack {
        Text("参考图 \(index + 1) · \(reference.displayFormat.uppercased())")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer()
        Button {
          Task { await model.exportReferenceImage(reference, index: index) }
        } label: {
          Image(systemName: model.exportingReferenceImageID == reference.id ? "hourglass" : "square.and.arrow.down")
        }
        .disabled(model.exportingReferenceImageID == reference.id || (reference.url ?? "").isEmpty)
        .accessibilityLabel("保存或分享参考图 \(index + 1)")
      }
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}

struct ReferenceImagePreview: View {
  let url: URL?
  let mimeType: String

  var body: some View {
    if mimeType.contains("svg") {
      SVGPreviewCard(url: url)
    } else if let url {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFit()
        case .failure:
          Image(systemName: "photo.badge.exclamationmark")
            .font(.largeTitle)
        default:
          ProgressView()
        }
      }
      .frame(maxWidth: .infinity, minHeight: 120)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
      .clipShape(RoundedRectangle(cornerRadius: 14))
    } else {
      Label("参考图", systemImage: "photo")
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
  }
}

struct JobMetadataGrid: View {
  let job: Job

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: 150), alignment: .topLeading)]
  }

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
      ForEach(job.metadataItems) { item in
        VStack(alignment: .leading, spacing: 2) {
          Text(item.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(item.value)
            .font(.caption)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
      }
    }
  }
}

struct JobPromptEcho: View {
  let job: Job

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !job.methodContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        DisclosureGroup("论文方法内容") {
          Text(job.methodContent)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      if !job.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        DisclosureGroup("目标图注") {
          Text(job.caption)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}

struct ResultImageView: View {
  @Bindable var model: AppModel
  let image: ResultImage
  let outputFormat: OutputFormat

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if image.format == "svg" {
        SVGPreviewCard(url: model.resolvedImageURL(image.url))
      } else if let url = model.resolvedImageURL(image.url) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFit()
          case .failure:
            Image(systemName: "photo.badge.exclamationmark")
              .font(.largeTitle)
          default:
            ProgressView()
          }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
      }
      HStack {
        Text("\(outputFormat.rawValue.uppercased()) · 候选 \(image.candidateID + 1)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          Task { await model.exportResultImage(image, outputFormat: outputFormat) }
        } label: {
          Image(systemName: model.exportingResultImageID == image.id ? "hourglass" : "square.and.arrow.down")
        }
        .disabled(model.exportingResultImageID == image.id || image.url.isEmpty)
        .accessibilityLabel("保存或分享候选图 \(image.candidateID + 1)")
        Button {
          model.beginRefine(image)
        } label: {
          Image(systemName: "wand.and.stars")
        }
      }
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}

struct SVGPreviewCard: View {
  let url: URL?

  var body: some View {
    Group {
      if let url {
        GeometryReader { proxy in
          SVGWebPreview(url: url)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
      } else {
        Label("SVG 矢量图", systemImage: "doc.richtext")
      }
    }
    .aspectRatio(4 / 3, contentMode: .fit)
    .frame(maxWidth: .infinity, minHeight: 140)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .accessibilityLabel("SVG 矢量图预览")
  }
}

struct SVGWebPreview: UIViewRepresentable {
  let url: URL

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    guard context.coordinator.lastURL != url else { return }
    context.coordinator.lastURL = url
    webView.load(URLRequest(url: url))
  }

  final class Coordinator {
    var lastURL: URL?
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct StageTimelineView: View {
  @Bindable var model: AppModel
  let stages: [JobStage]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("生成演化")
        .font(.subheadline.bold())
      ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: stage.type == "critic" ? "text.bubble" : "photo")
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading, spacing: 2) {
                Text(stage.title.isEmpty ? stage.type : stage.title)
                  .font(.callout.bold())
                Text("候选 \(stage.candidateID + 1)\(stage.round > 0 ? " · 第 \(stage.round) 轮" : "")")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              if stage.image?.url.isEmpty == false {
                Button {
                  Task { await model.exportStageImage(stage, index: index) }
                } label: {
                  Image(systemName: model.exportingStageImageID == stage.id ? "hourglass" : "square.and.arrow.down")
                }
                .disabled(model.exportingStageImageID == stage.id)
                .accessibilityLabel("保存或分享阶段图 \(index + 1)")
              }
            }
            if !stage.text.isEmpty {
              Text(stage.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            if let image = stage.image, let url = model.resolvedImageURL(image.url) {
              if image.mimeType.contains("svg") || image.filename.lowercased().hasSuffix(".svg") {
                SVGPreviewCard(url: url)
                  .frame(maxHeight: 180)
              } else {
                AsyncImage(url: url) { phase in
                  if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                  }
                }
                .frame(maxHeight: 180)
              }
            }
          }
        }
      }
    }
  }
}

struct GuideView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          hero
          quickActions
          GuideStepSection(title: "三步上手", systemImage: "sparkles", steps: PaperBananaGuide.onboardingSteps)
          GuideStepSection(title: "多智能体流程", systemImage: "point.3.connected.trianglepath.dotted", steps: PaperBananaGuide.workflowSteps)
          GuideTermSection(title: "模型相关", systemImage: "cpu", terms: PaperBananaGuide.modelTerms)
          GuideTermSection(title: "生成参数", systemImage: "slider.horizontal.3", terms: PaperBananaGuide.parameterTerms)
          GuideTermSection(title: "检索与参考图", systemImage: "magnifyingglass", terms: PaperBananaGuide.referenceTerms)
          GuideTermSection(title: "结果区", systemImage: "photo.on.rectangle", terms: PaperBananaGuide.resultTerms)
          faqSection
          resourcesSection
        }
        .padding()
      }
      .paperCompactTabBarInset()
      .background(AppBackground())
      .navigationTitle("使用指南")
    }
  }

  private var hero: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        Label("使用教程", systemImage: "book")
          .font(.title3.bold())
        Text(PaperBananaGuide.intro)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var quickActions: some View {
    GlassPanel {
      HStack(spacing: 12) {
        Button {
          model.selectedTab = .generate
        } label: {
          Label("开始生成", systemImage: "wand.and.stars")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .paperGlassButton(prominent: true)

        Button {
          model.selectedTab = .settings
        } label: {
          Label("意见反馈", systemImage: "message")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .paperGlassButton()
      }
    }
  }

  private var faqSection: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        Label("提示与常见问题", systemImage: "questionmark.circle")
          .font(.headline)
        ForEach(PaperBananaGuide.faq, id: \.self) { item in
          Label(item, systemImage: "checkmark.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var resourcesSection: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        Label("相关资源", systemImage: "link")
          .font(.headline)
        ForEach(PaperBananaGuide.resources) { resource in
          Link(destination: resource.url) {
            HStack(spacing: 10) {
              Image(systemName: resource.systemImage)
                .frame(width: 24)
              VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                  .font(.callout.weight(.semibold))
                Text(resource.subtitle)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "arrow.up.right")
                .font(.caption)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

struct GuideStepSection: View {
  let title: String
  let systemImage: String
  let steps: [GuideStep]

  var body: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 12) {
        Label(title, systemImage: systemImage)
          .font(.headline)
        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
          HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
              .font(.caption.monospacedDigit().bold())
              .foregroundStyle(.white)
              .frame(width: 24, height: 24)
              .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 4) {
              Text(step.title)
                .font(.callout.bold())
              Text(step.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
    }
  }
}

struct GuideTermSection: View {
  let title: String
  let systemImage: String
  let terms: [GuideTerm]

  var body: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 10) {
        Label(title, systemImage: systemImage)
          .font(.headline)
        ForEach(terms) { term in
          VStack(alignment: .leading, spacing: 4) {
            Text(term.name)
              .font(.callout.weight(.semibold))
            Text(term.detail)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
  }
}

struct TemplatesView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          ForEach(PaperBananaSamples.quickStartExamples) { example in
            GlassPanel {
              VStack(alignment: .leading, spacing: 8) {
                Text(example.title)
                  .font(.headline)
                Text(example.hint)
                  .font(.footnote)
                  .foregroundStyle(.secondary)
                Button("使用模板") {
                  model.applyExample(example)
                }
                .buttonStyle(.borderedProminent)
                .paperGlassButton(prominent: true)
              }
            }
          }
        }
        .padding()
      }
      .paperCompactTabBarInset()
      .background(AppBackground())
      .navigationTitle("示例模板")
    }
  }
}

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

struct RefineSheet: View {
  @Bindable var model: AppModel
  let image: ResultImage
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section("精修指令") {
          TextEditor(text: $model.refineInstruction)
            .frame(minHeight: 160)
        }
        Section("目标设置") {
          Picker("目标比例", selection: $model.refineAspectRatio) {
            ForEach(["16:9", "21:9", "3:2", "1:1"], id: \.self) { ratio in
              Text(ratio).tag(ratio)
            }
          }
          Picker("清晰度", selection: $model.refineImageSize) {
            ForEach(model.refineSupportedImageSizes) { size in
              Text(size.title).tag(size)
            }
          }
        }
        Section {
          Button("提交精修") {
            Task {
              await model.refine(image: image)
              dismiss()
            }
          }
          .disabled(model.refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

struct LabeledTextEditor: View {
  let title: String
  @Binding var text: String
  let minHeight: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
      TextEditor(text: $text)
        .frame(minHeight: minHeight)
        .padding(8)
        .scrollContentBackground(.hidden)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
  }
}

struct APIKeyGuideView: View {
  let config: ProviderConfig
  @State private var isExpanded = false

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(config.guideSteps.enumerated()), id: \.offset) { item in
          APIKeyGuideStepRow(number: item.offset + 1, text: item.element)
        }

        Link(destination: config.guideURL) {
          Label("打开 \(config.label) 官方申请/说明页面", systemImage: "arrow.up.right.square")
            .font(.footnote.weight(.semibold))
        }

        Text("密钥只用于本次任务调用模型，不会保存到本站数据库。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.top, 8)
    } label: {
      Label("API Key 申请指南", systemImage: "book")
        .font(.footnote.weight(.semibold))
    }
  }
}

struct APIKeyGuideStepRow: View {
  let number: Int
  let text: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text("\(number)")
        .font(.caption.monospacedDigit().weight(.bold))
        .foregroundStyle(.white)
        .frame(width: 22, height: 22)
        .background(Circle().fill(Color.accentColor))
      Text(text)
        .font(.footnote)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct GlassPanel<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .paperGlass(cornerRadius: 22)
  }
}

struct StatusPill: View {
  let text: String
  let systemImage: String

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .paperGlass(cornerRadius: 999, interactive: false)
  }
}

struct FlowText: View {
  let items: [String]

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
      ForEach(items, id: \.self) { item in
        Text(item)
          .font(.caption)
          .lineLimit(1)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.thinMaterial, in: Capsule())
      }
    }
  }
}

struct AppBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    LinearGradient(
      colors: colorScheme == .dark ? darkColors : lightColors,
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }

  private var lightColors: [Color] {
    [
      Color(.systemBackground),
      Color(red: 0.95, green: 0.98, blue: 0.98),
      Color(red: 1.00, green: 0.97, blue: 0.88)
    ]
  }

  private var darkColors: [Color] {
    [
      Color(red: 0.04, green: 0.05, blue: 0.05),
      Color(red: 0.10, green: 0.15, blue: 0.14),
      Color(red: 0.15, green: 0.13, blue: 0.08)
    ]
  }
}

extension View {
  @ViewBuilder
  func paperGlass(cornerRadius: CGFloat = 18, interactive: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      if interactive {
        self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
      } else {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
      }
    } else {
      self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
  }

  @ViewBuilder
  func paperGlassButton(prominent: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      if prominent {
        self.buttonStyle(.glassProminent)
      } else {
        self.buttonStyle(.glass)
      }
    } else {
      self
    }
  }

  func paperCompactTabBarInset() -> some View {
    modifier(CompactTabBarInsetModifier())
  }
}

private struct CompactTabBarInsetModifier: ViewModifier {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  func body(content: Content) -> some View {
    content.safeAreaInset(edge: .bottom, spacing: 0) {
      if horizontalSizeClass == .compact {
        Color.clear
          .frame(height: 88)
          .accessibilityHidden(true)
      }
    }
  }
}
