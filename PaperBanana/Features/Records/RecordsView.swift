import SwiftUI

struct RecordsView: View {
  @Bindable var model: AppModel

  var body: some View {
    NavigationStack {
      Group {
        if model.auth.currentUser == nil {
          ContentUnavailableView {
            Label("登录后查看任务记录", systemImage: "person.crop.circle.badge.exclamationmark")
          } description: {
            Text("不登录也可以生成；登录后任务会保存到账号。")
          } actions: {
            Button("去登录") { model.selectedTab = .settings }
              .paperGlassButton(prominent: true)
          }
        } else {
          recordsList
        }
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("任务记录")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task { await model.jobs.loadUserJobs(silent: false) }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .paperGlassButton()
          .accessibilityLabel("刷新任务记录")
        }
      }
    }
  }

  // MARK: - 列表

  private var showsSkeleton: Bool {
    model.jobs.recordsLoading && model.jobs.userJobs.isEmpty
  }

  private var recordsList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
        if model.jobs.isShowingCachedData {
          StatusPill(
            text: "离线数据",
            systemImage: "wifi.slash",
            tint: Theme.Palette.warning,
            accessibilityLabel: "正在显示本地缓存的记录，下拉刷新获取最新数据"
          )
        }
        if !model.jobs.recordsError.isEmpty {
          recordsErrorCard
        }
        if showsSkeleton {
          skeletonList
        } else if model.jobs.userJobs.isEmpty {
          if model.jobs.recordsError.isEmpty {
            emptyRecordsState
          }
        } else {
          ForEach(model.jobs.userJobs) { job in
            NavigationLink(value: job.id) {
              JobRow(model: model, job: job)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding()
    }
    .refreshable { await model.jobs.loadUserJobs(silent: false) }
    .navigationDestination(for: String.self) { id in
      if let job = model.jobs.userJobs.first(where: { $0.id == id }) {
        ScrollView {
          JobDetailView(model: model, job: job)
            .padding()
        }
        .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
        .navigationTitle("任务详情")
      }
    }
  }

  private var emptyRecordsState: some View {
    ContentUnavailableView {
      Label("还没有任务记录", systemImage: "tray")
    } description: {
      Text("提交一次生成后，任务会保存到这里。")
    } actions: {
      Button("去生成") { model.selectedTab = .generate }
        .paperGlassButton(prominent: true)
    }
    .frame(maxWidth: .infinity)
  }

  private var recordsErrorCard: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Label(model.jobs.recordsError, systemImage: "exclamationmark.triangle")
        .font(.footnote)
        .foregroundStyle(.red)
      Button("重试") {
        Task { await model.jobs.loadUserJobs(silent: false) }
      }
      .font(.footnote.weight(.semibold))
      .paperGlassButton()
      .controlSize(.small)
      .accessibilityHint("重新加载任务记录")
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .paperGlass(.tinted(.red.opacity(0.18)))
  }

  private var skeletonList: some View {
    VStack(spacing: Theme.Spacing.md) {
      ForEach(0..<3, id: \.self) { _ in
        RecordSkeletonCard()
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("正在加载任务记录")
  }
}

// MARK: - 行卡

struct JobRow: View {
  let model: AppModel
  let job: Job

  var body: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.md) {
      thumbnail
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        // 标题 + 状态徽章：放得下时同行，AX 大字号或长标题时上下排。
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            titleText
            Spacer(minLength: Theme.Spacing.sm)
            statusPill
          }
          VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            titleText
            statusPill
          }
        }
        Text(metadataLine)
          .font(.caption)
          .foregroundStyle(.secondary)
        if job.statusKind == .failed, !job.failureErrorText.isEmpty {
          Text(formatUserFacingError(job.failureErrorText))
            .font(.caption)
            .foregroundStyle(.red.opacity(0.85))
            .lineLimit(1)
        }
      }
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .paperGlass(.interactive)
    .accessibilityElement(children: .combine)
    .accessibilityHint("点按查看任务详情")
  }

  private var titleText: some View {
    Text(job.title)
      .font(.callout.weight(.semibold))
      .lineLimit(2)
      .multilineTextAlignment(.leading)
  }

  private var statusPill: some View {
    StatusPill(
      text: job.statusKind.title,
      systemImage: statusIconName,
      tint: Theme.Palette.tint(for: job.statusKind),
      textTint: Theme.Palette.textTint(for: job.statusKind),
      accessibilityLabel: "任务状态：\(job.statusKind.title)"
    )
  }

  /// 按状态给正确图标（修复旧版 running 误用 checkmark.circle 的问题）。
  private var statusIconName: String {
    switch job.statusKind {
    case .queued: "clock"
    case .running: "progress.indicator"
    case .succeeded: "checkmark.circle"
    case .failed: "xmark.circle"
    case .unknown: "questionmark.circle"
    }
  }

  private var metadataLine: String {
    [relativeCreatedAt, displayCategory, "\(job.outputFormat.rawValue.uppercased()) · \(job.imageSize.rawValue)"]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }

  private var displayCategory: String {
    let trimmed = job.infographicCategory.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    return job.taskName == .plot ? "数据统计图" : "方法框架图"
  }

  private var relativeCreatedAt: String {
    // 相对时间策略（zh-Hans 固定 + 解析失败截断回退）集中在 DateDisplay。
    DateDisplay.relative(fromISO: job.createdAt)
  }

  // MARK: 缩略图

  /// 首张可栅格预览的结果图；SVG / 无结果图时用类别图标占位。
  private var thumbnailURL: URL? {
    guard
      let first = job.resultImages.first,
      !first.url.isEmpty,
      first.format != "svg"
    else { return nil }
    return model.resolvedImageURL(first.url)
  }

  private var thumbnail: some View {
    Group {
      if let url = thumbnailURL {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFill()
          case .failure:
            categoryIcon
          default:
            ProgressView().controlSize(.small)
          }
        }
      } else {
        categoryIcon
      }
    }
    .frame(width: 64, height: 64)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    .accessibilityHidden(true)
  }

  private var categoryIcon: some View {
    Image(systemName: PaperBananaSamples.categorySymbol(idOrLabel: displayCategory))
      .font(.title3)
      .foregroundStyle(.secondary)
  }
}

// MARK: - 骨架卡

/// 列表加载中的占位卡：redacted + subtle 不透明度脉冲；减弱动态效果时静态。
struct RecordSkeletonCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let card = HStack(alignment: .top, spacing: Theme.Spacing.md) {
      RoundedRectangle(cornerRadius: Theme.Radius.control)
        .fill(.quaternary)
        .frame(width: 64, height: 64)
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        Text("占位标题占位标题占位标题")
          .font(.callout.weight(.semibold))
        Text("时间 · 类别 · 格式尺寸")
          .font(.caption)
      }
      .redacted(reason: .placeholder)
      Spacer(minLength: 0)
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .paperGlass(.panel)
    .accessibilityHidden(true)

    if reduceMotion {
      card
    } else {
      card.phaseAnimator([1.0, 0.55]) { content, opacity in
        content.opacity(opacity)
      } animation: { _ in
        Theme.Motion.pulseSegment
      }
    }
  }
}

#if DEBUG
#Preview("记录列表") {
  let model = AppModel()
  let _ = {
    model.auth.currentUser = try? JSONDecoder().decode(
      CurrentUser.self,
      from: Data(#"{"id":"u-preview","email":"preview@paperbanana.app"}"#.utf8)
    )
    model.jobs.userJobs = [
      JobPreviewFixtures.succeeded,
      JobPreviewFixtures.running,
      JobPreviewFixtures.queued,
      JobPreviewFixtures.failed
    ]
  }()
  RecordsView(model: model)
}

#Preview("骨架屏") {
  let model = AppModel()
  let _ = {
    model.auth.currentUser = try? JSONDecoder().decode(
      CurrentUser.self,
      from: Data(#"{"id":"u-preview","email":"preview@paperbanana.app"}"#.utf8)
    )
    model.jobs.recordsLoading = true
  }()
  RecordsView(model: model)
}

#Preview("未登录") {
  RecordsView(model: AppModel())
}
#endif
