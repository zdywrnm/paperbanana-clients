import SwiftUI

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
            Task { await model.exports.exportJobArchive(job) }
          } label: {
            Label(model.exports.exportingJobArchiveID == job.id ? "打包中" : "分享全部", systemImage: model.exports.exportingJobArchiveID == job.id ? "hourglass" : "archivebox")
          }
          .paperGlassButton()
          .disabled(model.exports.exportingJobArchiveID == job.id)
        }
        JobMetadataGrid(job: job)
        JobPromptEcho(job: job)
        if job.statusKind == .failed {
          if !job.failureErrorText.isEmpty {
            Label(formatUserFacingError(job.failureErrorText), systemImage: "exclamationmark.triangle")
              .font(.footnote)
              .foregroundStyle(.red)
          } else if !job.failureLogsText.isEmpty {
            Label("任务失败，查看日志了解原因。", systemImage: "exclamationmark.triangle")
              .font(.footnote)
              .foregroundStyle(.red)
          }
          if !job.failureLogsText.isEmpty {
            FailureLogsView(logsTail: job.failureLogsText)
          }
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
          if job.id == model.jobs.currentJobID, !model.jobs.pollingError.isEmpty {
            pollingErrorRow
          } else {
            ProgressView("生成中")
          }
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
  }

  /// 轮询异常停止（超时 / 连续失败）时的最小提示 + 恢复入口；精致 UI 留给 Phase 5。
  private var pollingErrorRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(model.jobs.pollingError, systemImage: "exclamationmark.triangle")
        .font(.footnote)
        .foregroundStyle(.orange)
      Button("重新检查") {
        model.jobs.retryPolling()
      }
      .controlSize(.small)
      .paperGlassButton()
    }
  }
}

struct FailureLogsView: View {
  let logsTail: String

  var body: some View {
    DisclosureGroup("失败日志") {
      ScrollView(.horizontal) {
        Text(logsTail)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(10)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    .font(.footnote)
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
