import SwiftUI

struct RecordsListView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Task Records")
            .font(.title2)
            .fontWeight(.semibold)
          Text(model.currentUser == nil ? "Sign in to load account records from Sealos." : "Recent jobs associated with the current account.")
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          Task { await model.loadUserJobs(silent: false) }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(model.currentUser == nil || model.recordsLoading)
      }
      .padding(20)

      Divider()

      if model.currentUser == nil {
        ContentUnavailableView {
          Label("Sign in required", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
          Text("任务记录由 Sealos auth-gateway 保护，需要登录后读取。")
        } actions: {
          Button("Sign In / Register") {
            model.isAuthSheetPresented = true
          }
        }
      } else if model.recordsLoading {
        ProgressView("Loading Records")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if !model.recordsError.isEmpty {
        ContentUnavailableView("Unable to load records", systemImage: "exclamationmark.triangle", description: Text(model.recordsError))
      } else if model.userJobs.isEmpty {
        ContentUnavailableView("No Records", systemImage: "tray", description: Text("This account does not have generation records yet."))
      } else {
        List(selection: $model.selectedRecordID) {
          ForEach(model.userJobs) { job in
            JobRecordRow(job: job)
              .tag(job.id)
          }
        }
        .listStyle(.inset)
      }
    }
    .task {
      if model.currentUser != nil, model.userJobs.isEmpty {
        await model.loadUserJobs(silent: true)
      }
    }
  }
}

struct JobRecordRow: View {
  let job: Job

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .foregroundStyle(.secondary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 3) {
        Text(job.title)
          .lineLimit(1)
        HStack(spacing: 8) {
          Text(job.provider.ifEmpty("unknown"))
          Text(job.aspectRatio.ifEmpty("ratio"))
          Text(job.createdAt)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }

      Spacer()
      StatusBadge(status: job.statusKind)
    }
    .padding(.vertical, 4)
  }

  private var systemImage: String {
    switch job.statusKind {
    case .succeeded: "checkmark.circle"
    case .failed: "xmark.circle"
    case .running: "clock"
    case .queued: "hourglass"
    case .unknown: "questionmark.circle"
    }
  }
}

private extension String {
  func ifEmpty(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}
