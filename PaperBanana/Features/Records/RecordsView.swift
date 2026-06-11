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
          }
        } else {
          List {
            if model.jobs.isShowingCachedData {
              Text("正在显示本地缓存的记录，下拉刷新获取最新数据。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            ForEach(model.jobs.userJobs) { job in
              NavigationLink(value: job.id) {
                JobRow(job: job)
              }
            }
          }
          .scrollContentBackground(.hidden)
          .navigationDestination(for: String.self) { id in
            if let job = model.jobs.userJobs.first(where: { $0.id == id }) {
              ScrollView {
                JobDetailView(model: model, job: job)
              }
              .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
              .navigationTitle("任务详情")
            }
          }
          .refreshable { await model.jobs.loadUserJobs(silent: false) }
        }
      }
      .background(AppBackground(isGenerating: model.jobs.isActivelyGenerating))
      .navigationTitle("任务记录")
      .toolbar {
        Button {
          Task { await model.jobs.loadUserJobs(silent: false) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
      }
    }
  }
}

struct JobRow: View {
  let job: Job

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(job.title)
          .lineLimit(1)
        Spacer()
        StatusPill(text: job.statusKind.title, systemImage: job.statusKind == .failed ? "xmark.circle" : "checkmark.circle")
      }
      Text([job.taskName.rawValue, job.outputFormat.rawValue.uppercased(), job.imageSize.rawValue].joined(separator: " · "))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
