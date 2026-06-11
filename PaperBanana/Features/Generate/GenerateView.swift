import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

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
          if model.generation.draft.configurationMode == .advanced {
            advancedPanel
          }
          submitPanel
          if let job = model.jobs.currentJob {
            JobDetailView(model: model, job: job)
          }
        }
        .padding()
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
      .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: referenceContentTypes, allowsMultipleSelection: true) { result in
        switch result {
        case .success(let urls):
          for url in urls.prefix(ReferenceImageLimits.maxCount - model.generation.draft.referenceImages.count) {
            addReference(url)
          }
        case .failure(let error):
          model.generation.referenceUploadError = formatUserFacingError(error)
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

  private var configurationPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 14) {
        Picker("模式", selection: $model.generation.draft.configurationMode) {
          ForEach(ConfigurationMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)

        Picker("模型平台", selection: Binding(get: { model.generation.draft.provider }, set: { model.generation.selectProvider($0) })) {
          ForEach(ProviderCatalog.order) { provider in
            Text(ProviderCatalog.config(for: provider).label).tag(provider)
          }
        }
        .pickerStyle(.segmented)

        SecureField(model.generation.selectedProviderConfig.keyPlaceholder, text: Binding(get: { model.generation.selectedAPIKey }, set: { model.generation.updateSelectedAPIKey($0) }))
          .textContentType(.password)
          .padding(12)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

        APIKeyGuideView(config: model.generation.selectedProviderConfig)

        HStack {
          Picker("导出格式", selection: $model.generation.draft.outputFormat) {
            ForEach(OutputFormat.allCases) { format in
              Text(format.title).tag(format)
            }
          }
          Picker("清晰度", selection: $model.generation.draft.imageSize) {
            ForEach(ProviderCatalog.supportedResolutions(provider: model.generation.draft.provider, imageModel: model.generation.activeImageModelName)) { size in
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
        Picker("信息图类别", selection: $model.generation.draft.infographicCategoryID) {
          ForEach(PaperBananaSamples.categories) { category in
            Text(category.label).tag(category.id)
          }
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

        LabeledTextEditor(title: "论文方法内容", text: $model.generation.draft.methodContent, minHeight: 180)
        LabeledTextEditor(title: "目标图注", text: $model.generation.draft.caption, minHeight: 90)
      }
    }
  }

  private var advancedPanel: some View {
    GlassPanel {
      VStack(alignment: .leading, spacing: 14) {
        Picker("主模型", selection: Binding(get: { model.generation.draft.mainModelName }, set: { model.generation.selectMainModel($0) })) {
          ForEach(model.generation.selectedProviderConfig.mainModels) { option in
            Text(option.displayName).tag(option.value)
          }
        }
        Picker("图像生成模型", selection: Binding(get: { model.generation.draft.imageModelName }, set: { model.generation.selectImageModel($0) })) {
          ForEach(model.generation.selectedProviderConfig.imageModels) { option in
            Text(option.displayName).tag(option.value)
          }
        }
        if model.generation.activeReferenceImageMode != .mainModel {
          Picker("参考图识别模型", selection: $model.generation.draft.referenceVisionModelName) {
            ForEach(model.generation.selectedProviderConfig.visionModels) { option in
              Text(option.displayName).tag(option.value)
            }
          }
        }
        Picker("生成流程", selection: $model.generation.draft.pipelineMode) {
          ForEach(PipelineMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        Picker("检索设置", selection: $model.generation.draft.retrievalSetting) {
          ForEach(RetrievalSetting.allCases) { setting in
            Text(setting.title).tag(setting)
          }
        }
        .disabled(!model.generation.draft.referenceImages.isEmpty)
        if !model.generation.draft.referenceImages.isEmpty {
          Text("已上传参考图，检索自动关闭。")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        if !model.generation.draft.referenceImages.isEmpty {
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
        Picker("画面比例", selection: $model.generation.draft.aspectRatio) {
          ForEach(["16:9", "21:9", "3:2", "1:1"], id: \.self) { ratio in
            Text(ratio).tag(ratio)
          }
        }
        if model.generation.draft.retrievalSetting == .manual && model.generation.draft.referenceImages.isEmpty {
          ManualReferencePanel(model: model)
        }
      }
    }
  }

  private var submitPanel: some View {
    VStack(spacing: 10) {
      Button {
        Task { await model.generation.submitJob() }
      } label: {
        Label(model.generation.isSubmitting ? "提交中" : "生成候选图", systemImage: model.generation.isSubmitting ? "hourglass" : "paperplane.fill")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.large)
      .disabled(!model.generation.canSubmit)
      .paperGlassButton(prominent: true)

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
  }

  private func addReference(_ url: URL) {
    let didStart = url.startAccessingSecurityScopedResource()
    defer {
      if didStart { url.stopAccessingSecurityScopedResource() }
    }
    do {
      let data = try Data(contentsOf: url)
      let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
      model.generation.addReferenceFile(filename: url.lastPathComponent, mimeType: type?.preferredMIMEType, data: data)
    } catch {
      model.generation.referenceUploadError = formatUserFacingError(error)
    }
  }

  @MainActor
  private func addPhotoReferences(_ items: [PhotosPickerItem]) async {
    let remainingSlots = ReferenceImageLimits.maxCount - model.generation.draft.referenceImages.count
    guard remainingSlots > 0 else {
      model.generation.referenceUploadError = "最多只能上传 \(ReferenceImageLimits.maxCount) 张参考图。"
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
        model.generation.referenceUploadError = "无法读取所选照片。"
        return
      }

      if let type = acceptedReferenceContentType(from: item.supportedContentTypes) {
        model.generation.addReferenceFile(
          filename: photoFilename(index: index, contentType: type),
          mimeType: type.preferredMIMEType,
          data: data
        )
        return
      }

      guard let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.92) else {
        model.generation.referenceUploadError = "无法将所选照片转换为 JPG。"
        return
      }

      model.generation.addReferenceFile(
        filename: photoFilename(index: index, contentType: .jpeg),
        mimeType: "image/jpeg",
        data: jpegData
      )
    } catch {
      model.generation.referenceUploadError = formatUserFacingError(error)
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
