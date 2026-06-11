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
