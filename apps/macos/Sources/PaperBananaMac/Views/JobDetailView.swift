import SwiftUI

struct JobDetailView: View {
  @ObservedObject var model: AppModel
  let job: Job?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let job {
          HStack {
            VStack(alignment: .leading, spacing: 5) {
              Text(job.title)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(2)
              Text(job.id)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            }
            Spacer()
            StatusBadge(status: job.statusKind)
          }

          Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            detailRow("Provider", job.provider)
            detailRow("Category", job.infographicCategory)
            detailRow("Main Model", job.mainModelName)
            detailRow("Image Model", job.imageGenModelName)
            detailRow("Pipeline", job.pipelineMode)
            detailRow("Aspect Ratio", job.aspectRatio)
            detailRow("Candidates", "\(job.numCandidates)")
          }

          if !job.error.isEmpty {
            Text(job.error)
              .foregroundStyle(.red)
              .textSelection(.enabled)
          }

          if !job.methodContent.isEmpty {
            Text("Methodology")
              .font(.headline)
            Text(job.methodContent)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          if !job.logsTail.isEmpty {
            Text("Logs")
              .font(.headline)
            Text(job.logsTail)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          JobResultPanel(model: model, job: job)
        } else {
          ContentUnavailableView("Select a Record", systemImage: "sidebar.left", description: Text("Choose a task record to inspect details and result images."))
            .frame(maxWidth: .infinity, minHeight: 360)
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func detailRow(_ label: String, _ value: String) -> some View {
    GridRow {
      Text(label)
        .foregroundStyle(.secondary)
      Text(value.isEmpty ? "-" : value)
        .textSelection(.enabled)
    }
  }
}
