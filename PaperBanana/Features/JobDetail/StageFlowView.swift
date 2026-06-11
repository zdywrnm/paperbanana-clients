import SwiftUI

/// 阶段流：每个 stage 一张玻璃小卡，新 stage 到达时从底部模糊入场。
struct StageFlowView: View {
  @Bindable var model: AppModel
  let stages: [JobStage]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      Text("生成演化")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
        StageCard(model: model, stage: stage, index: index)
          .transition(
            reduceMotion
              ? AnyTransition.opacity
              : AnyTransition(.blurReplace.combined(with: .move(edge: .bottom)))
          )
      }
    }
    .animation(Theme.Motion.entrance, value: stages.map(\.id))
  }
}

/// 单个阶段卡：类型图标 + 标题 + 轮次、可展开的文本 / 建议摘要、阶段图缩略。
struct StageCard: View {
  @Bindable var model: AppModel
  let stage: JobStage
  let index: Int

  @State private var isExpanded = false

  private var nodeID: PipelineState.NodeID? {
    PipelineState.NodeID(stageType: stage.type, title: stage.title)
  }

  /// 阶段卡图标：流水线节点图标优先；stylist 不映射节点（跟随小程序的通用标记处理），
  /// 但阶段卡单独给配色风格图标；其余未知类型用虚线圆占位。
  private var stageIconName: String {
    if let nodeID { return nodeID.systemImage }
    if stage.type.lowercased() == "stylist" { return "paintpalette" }
    return "circle.dashed"
  }

  private var summaryText: String {
    [stage.text, stage.suggestion]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n建议：")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      header
      if !summaryText.isEmpty {
        expandableSummary
      }
      if let image = stage.image, let url = model.resolvedImageURL(image.url) {
        stageThumbnail(image: image, url: url)
      }
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .paperGlass(.panel)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
      Image(systemName: stageIconName)
        .font(.body.weight(.semibold))
        .foregroundStyle(Theme.Palette.banana)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(stage.title.isEmpty ? stage.type : stage.title)
          .font(.callout.weight(.semibold))
        Text("候选 \(stage.candidateID + 1)\(stage.round > 0 ? " · 第 \(stage.round) 轮" : "")")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if stage.image?.url.isEmpty == false {
        Button {
          Task { await model.exports.exportStageImage(stage, index: index) }
        } label: {
          Image(systemName: model.exports.exportingStageImageID == stage.id ? "hourglass" : "square.and.arrow.up")
        }
        .paperGlassButton()
        .controlSize(.small)
        .disabled(model.exports.exportingStageImageID == stage.id)
        .accessibilityLabel("保存或分享阶段图 \(index + 1)")
      }
    }
  }

  private var expandableSummary: some View {
    Button {
      withAnimation(Theme.Motion.stateChange) {
        isExpanded.toggle()
      }
    } label: {
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text(summaryText)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
          .lineLimit(isExpanded ? nil : 3)
          .frame(maxWidth: .infinity, alignment: .leading)
        if summaryText.count > 60 {
          Text(isExpanded ? "收起" : "展开全文")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.Palette.banana)
        }
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("阶段说明")
    .accessibilityValue(summaryText)
    .accessibilityHint(isExpanded ? "点按收起" : "点按展开全文")
  }

  @ViewBuilder
  private func stageThumbnail(image: StageImage, url: URL) -> some View {
    if image.mimeType.contains("svg") || image.filename.lowercased().hasSuffix(".svg") {
      SVGPreviewCard(url: url)
        .frame(maxHeight: 180)
    } else {
      AsyncImage(url: url) { phase in
        if case .success(let loaded) = phase {
          loaded.resizable().scaledToFit()
        }
      }
      .frame(maxHeight: 180)
      .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
      .accessibilityLabel("阶段图 \(index + 1)")
    }
  }
}

#if DEBUG
#Preview("阶段流") {
  ZStack {
    AppBackground()
    ScrollView {
      StageFlowView(model: AppModel(), stages: JobPreviewFixtures.running.stages)
        .padding()
    }
  }
}
#endif
