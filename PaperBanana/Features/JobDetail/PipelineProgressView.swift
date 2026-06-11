import SwiftUI

/// 多智能体流水线可视化卡：节点行 + 流动连接线 + 轮询状态行。
/// 展示状态全部来自 `PipelineState`（纯派生），本视图零业务逻辑。
struct PipelineProgressView: View {
  let state: PipelineState
  /// 最近一次拿到任务数据的时刻（标题行右侧相对时间）。
  var lastPolledAt: Date?
  /// 任务进行中：显示刷新时间与手动刷新按钮。
  var isLive = false
  /// 轮询中断文案（为空表示正常）。
  var pollingError = ""
  var onRefresh: (() -> Void)?
  var onRetry: (() -> Void)?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .body) private var nodeSize: CGFloat = 42

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
      header
      nodeTrack
      if !pollingError.isEmpty {
        pollingErrorRow
      }
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .paperGlass(.panel)
  }

  // MARK: - 标题行

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
      Text("生成流水线")
        .font(.headline)
      Spacer()
      if isLive, let lastPolledAt {
        Text("刷新于 \(lastPolledAt, style: .relative)前")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      if isLive, let onRefresh {
        Button(action: onRefresh) {
          Image(systemName: "arrow.clockwise")
            .font(.footnote.weight(.semibold))
        }
        .paperGlassButton()
        .controlSize(.small)
        .accessibilityLabel("立即刷新任务状态")
        .accessibilityHint("不打断自动轮询，立即拉取一次最新进度")
      }
    }
  }

  // MARK: - 节点行

  private var nodeTrack: some View {
    ViewThatFits(in: .horizontal) {
      horizontalTrack
      compactGrid
    }
    .animation(Theme.Motion.stateChange, value: state)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("生成流水线")
    .accessibilityValue(state.accessibilitySummary)
  }

  /// 默认：单行水平排布，节点间连接线自适应拉伸。
  private var horizontalTrack: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
      ForEach(Array(state.nodes.enumerated()), id: \.element.id) { index, node in
        nodeView(node)
        if index < state.nodes.count - 1 {
          connector(after: index)
            .frame(minWidth: Theme.Spacing.lg, maxWidth: .infinity)
            .padding(.top, nodeSize / 2 - 1.5)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  /// Dynamic Type 放大溢出时：两列 Grid，行内保留短连接线，
  /// 行与行之间补一段竖向连接线（上一行尾节点 → 下一行首节点），保持与单行布局相同的连贯语义。
  private var compactGrid: some View {
    Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
      ForEach(Array(stride(from: 0, to: state.nodes.count, by: 2)), id: \.self) { start in
        GridRow {
          nodeView(state.nodes[start])
          if start + 1 < state.nodes.count {
            connector(after: start)
              .frame(width: Theme.Spacing.xl)
              .padding(.top, nodeSize / 2 - 1.5)
            nodeView(state.nodes[start + 1])
          }
        }
        if start + 2 < state.nodes.count {
          GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            connector(after: start + 1, axis: .vertical)
              .frame(height: Theme.Spacing.lg)
              .frame(maxWidth: .infinity)
          }
        }
      }
    }
  }

  private func nodeView(_ node: PipelineState.Node) -> some View {
    VStack(spacing: Theme.Spacing.xs) {
      nodeCircle(node)
        .frame(width: nodeSize, height: nodeSize)
        .overlay(alignment: .bottomTrailing) {
          if node.phase == .done {
            cornerBadge(systemImage: "checkmark.circle.fill", tint: .green)
          } else if node.phase == .failed {
            cornerBadge(systemImage: "xmark.circle.fill", tint: .red)
          }
        }
        .overlay(alignment: .topTrailing) {
          if let round = node.round {
            roundBadge(round)
          }
        }
      Text(node.label)
        .font(.caption.weight(node.phase == .active ? .semibold : .regular))
        .foregroundStyle(node.phase == .pending ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .lineLimit(1)
        .fixedSize()
    }
  }

  @ViewBuilder
  private func nodeCircle(_ node: PipelineState.Node) -> some View {
    let icon = Image(systemName: node.id.systemImage)
      .font(.system(size: nodeSize * 0.42, weight: .semibold))

    switch node.phase {
    case .done:
      Circle()
        .fill(Theme.Palette.banana)
        .overlay(icon.foregroundStyle(.black.opacity(0.72)))
    case .active:
      activeCircle(icon: icon)
    case .pending:
      Circle()
        .strokeBorder(.quaternary, lineWidth: 2)
        .overlay(icon.foregroundStyle(.tertiary))
    case .failed:
      Circle()
        .fill(.red.opacity(0.14))
        .overlay(Circle().strokeBorder(.red, lineWidth: 2))
        .overlay(icon.foregroundStyle(.red))
    }
  }

  /// active 节点：呼吸脉冲（scale 1.0↔1.08 + 外圈 glow）；减弱动态效果时为静态高亮。
  @ViewBuilder
  private func activeCircle(icon: some View) -> some View {
    let base = Circle()
      .fill(Theme.Palette.banana.opacity(0.16))
      .overlay(Circle().strokeBorder(Theme.Palette.banana, lineWidth: 2))
      .overlay(icon.foregroundStyle(Theme.Palette.banana))

    if reduceMotion {
      base
        .background(
          Circle()
            .fill(Theme.Palette.banana.opacity(0.22))
            .scaleEffect(1.3)
            .blur(radius: 5)
        )
    } else {
      base
        .phaseAnimator([false, true]) { content, pulsing in
          content
            .scaleEffect(pulsing ? 1.08 : 1.0)
            .background(
              Circle()
                .fill(Theme.Palette.banana.opacity(pulsing ? 0.34 : 0.08))
                .scaleEffect(1.3)
                .blur(radius: 5)
            )
        } animation: { _ in
          Theme.Motion.pulseSegment
        }
    }
  }

  private func cornerBadge(systemImage: String, tint: Color) -> some View {
    Image(systemName: systemImage)
      .symbolRenderingMode(.palette)
      .foregroundStyle(.white, tint)
      .font(.system(size: 14))
      .background(Circle().fill(.background).padding(1))
      .offset(x: 3, y: 3)
  }

  private func roundBadge(_ round: Int) -> some View {
    Text("第\(round)轮")
      .font(.caption2.weight(.bold))
      .foregroundStyle(.black.opacity(0.75))
      .padding(.horizontal, Theme.Spacing.xs + 2)
      .padding(.vertical, 2)
      .background(Theme.Palette.banana, in: .capsule)
      .offset(x: Theme.Spacing.md, y: -Theme.Spacing.sm)
  }

  // MARK: - 连接线

  private enum ConnectorAxis {
    case horizontal, vertical
  }

  /// index → index+1 之间的连接段：两端 done 实色；指向 active 的段流动渐变；其余灰。
  @ViewBuilder
  private func connector(after index: Int, axis: ConnectorAxis = .horizontal) -> some View {
    let leading = state.nodes[index].phase
    let trailing = state.nodes[index + 1].phase

    Group {
      if leading == .done, trailing == .done || trailing == .failed {
        Capsule().fill(Theme.Palette.banana)
      } else if trailing == .active {
        flowingLine(axis: axis)
      } else {
        Capsule().fill(.quaternary)
      }
    }
    .frame(
      width: axis == .vertical ? 3 : nil,
      height: axis == .horizontal ? 3 : nil
    )
  }

  /// active 段：LinearGradient 相位流动（周期 Theme.Motion.flowPeriod）；减弱动态效果时静止渐变。
  @ViewBuilder
  private func flowingLine(axis: ConnectorAxis) -> some View {
    if reduceMotion {
      Capsule().fill(
        LinearGradient(
          colors: [Theme.Palette.banana, Theme.Palette.banana.opacity(0.2)],
          startPoint: axis == .horizontal ? .leading : .top,
          endPoint: axis == .horizontal ? .trailing : .bottom
        )
      )
    } else {
      TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
        let progress = context.date.timeIntervalSinceReferenceDate
          .truncatingRemainder(dividingBy: Theme.Motion.flowPeriod) / Theme.Motion.flowPeriod
        Capsule().fill(
          LinearGradient(
            colors: [
              Theme.Palette.banana.opacity(0.25),
              Theme.Palette.banana,
              Theme.Palette.banana.opacity(0.25)
            ],
            startPoint: axis == .horizontal
              ? UnitPoint(x: CGFloat(progress) * 2 - 1, y: 0.5)
              : UnitPoint(x: 0.5, y: CGFloat(progress) * 2 - 1),
            endPoint: axis == .horizontal
              ? UnitPoint(x: CGFloat(progress) * 2 + 1, y: 0.5)
              : UnitPoint(x: 0.5, y: CGFloat(progress) * 2 + 1)
          )
        )
      }
    }
  }

  // MARK: - 轮询中断行

  private var pollingErrorRow: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Label(pollingError, systemImage: "exclamationmark.triangle")
        .font(.footnote)
        .foregroundStyle(Theme.Palette.warning)
      if let onRetry {
        Button("重新检查", action: onRetry)
          .font(.footnote.weight(.semibold))
          .paperGlassButton()
          .controlSize(.small)
          .accessibilityHint("清除轮询错误并重新开始跟踪任务")
      }
    }
  }
}

#if DEBUG
#Preview("进行中 · 评审第 2 轮") {
  ZStack {
    AppBackground(isGenerating: true)
    PipelineProgressView(
      state: PipelineState(job: JobPreviewFixtures.running),
      lastPolledAt: .now.addingTimeInterval(-12),
      isLive: true,
      onRefresh: {}
    )
    .padding()
  }
}

#Preview("精修放大中") {
  ZStack {
    AppBackground(isGenerating: true)
    PipelineProgressView(
      state: PipelineState(job: JobPreviewFixtures.refining),
      lastPolledAt: .now.addingTimeInterval(-5),
      isLive: true,
      onRefresh: {}
    )
    .padding()
  }
}

#Preview("已完成") {
  ZStack {
    AppBackground()
    PipelineProgressView(state: PipelineState(job: JobPreviewFixtures.succeeded))
      .padding()
  }
}

#Preview("失败 / 轮询中断") {
  ZStack {
    AppBackground()
    VStack(spacing: Theme.Spacing.lg) {
      PipelineProgressView(state: PipelineState(job: JobPreviewFixtures.failed))
      PipelineProgressView(
        state: PipelineState(job: JobPreviewFixtures.running),
        lastPolledAt: .now.addingTimeInterval(-300),
        isLive: true,
        pollingError: "任务轮询已超过 10 分钟，已自动停止刷新；请稍后在任务记录里查看结果。",
        onRefresh: {},
        onRetry: {}
      )
    }
    .padding()
  }
}
#endif
