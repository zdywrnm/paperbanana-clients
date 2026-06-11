import SwiftUI

/// 任务参数网格：默认两列，Dynamic Type 放大放不下时退到单列。
struct JobMetadataGrid: View {
  let job: Job

  var body: some View {
    ViewThatFits(in: .horizontal) {
      grid(columnCount: 2)
      grid(columnCount: 1)
    }
  }

  private func grid(columnCount: Int) -> some View {
    Grid(alignment: .topLeading, horizontalSpacing: Theme.Spacing.lg, verticalSpacing: Theme.Spacing.md) {
      ForEach(Array(stride(from: 0, to: job.metadataItems.count, by: columnCount)), id: \.self) { start in
        GridRow {
          ForEach(start..<min(start + columnCount, job.metadataItems.count), id: \.self) { index in
            cell(job.metadataItems[index])
          }
        }
      }
    }
  }

  private func cell(_ item: JobMetadataItem) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
      Text(item.label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .fixedSize()
      Text(item.value)
        .font(.caption)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

#if DEBUG
#Preview("任务参数") {
  ZStack {
    AppBackground()
    GlassPanel {
      JobMetadataGrid(job: JobPreviewFixtures.succeeded)
    }
    .padding()
  }
}
#endif
