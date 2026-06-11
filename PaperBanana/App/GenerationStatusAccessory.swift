import SwiftUI

/// tab bar 上方的全局"生成中"状态胶囊（tabViewBottomAccessory 内容）。
/// 仅在 currentJob 处于 queued/running 时由 RootView 装入；
/// 系统自动提供玻璃胶囊容器，这里只放轻量内容（玻璃不叠玻璃）。
struct GenerationStatusAccessory: View {
  @Bindable var model: AppModel
  @Environment(\.tabViewBottomAccessoryPlacement) private var placement

  private var job: Job? { model.jobs.currentJob }

  private var hasPollingError: Bool { !model.jobs.pollingError.isEmpty }

  /// 当前阶段名：取 stages 最后一项标题；无 stages 时回退到状态文案。
  private var primaryText: String {
    if hasPollingError { return "轮询中断" }
    guard let job else { return "生成中" }
    if let stage = job.stages.last {
      let title = stage.title.trimmingCharacters(in: .whitespacesAndNewlines)
      if !title.isEmpty { return title }
    }
    return job.statusKind == .queued ? "排队中" : "生成中"
  }

  private var secondaryText: String {
    guard let job else { return "" }
    let title = job.title.trimmingCharacters(in: .whitespacesAndNewlines)
    return title == job.id ? "" : title
  }

  var body: some View {
    Button {
      model.selectedTab = .generate
    } label: {
      HStack(spacing: Theme.Spacing.sm) {
        if hasPollingError {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(Theme.Palette.warning)
        } else {
          ProgressView()
            .controlSize(.small)
            .tint(Theme.Palette.tint(for: job?.statusKind ?? .running))
        }
        Text(primaryText)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(hasPollingError ? AnyShapeStyle(Theme.Palette.warning) : AnyShapeStyle(.primary))
          .lineLimit(1)
        if placement == .expanded, !secondaryText.isEmpty {
          Text(secondaryText)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .frame(maxWidth: .infinity)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(hasPollingError ? "任务轮询中断，点按查看详情" : "任务\(primaryText)，点按查看详情")
  }
}
