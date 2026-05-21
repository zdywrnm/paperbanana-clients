import AppKit
import SwiftUI

struct JobResultPanel: View {
  @ObservedObject var model: AppModel
  let job: Job?

  private let columns = [
    GridItem(.adaptive(minimum: 240), spacing: 14)
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Result")
          .font(.headline)
        Spacer()
        if let job {
          StatusBadge(status: job.statusKind)
        }
      }

      if let job {
        if !job.id.isEmpty {
          Text("Job \(job.id)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }

        if job.statusKind == .queued || job.statusKind == .running {
          HStack {
            ProgressView()
            Text(job.statusKind.label)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 120)
        } else if job.statusKind == .failed {
          Text(job.error.isEmpty ? "任务失败。" : job.error)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        } else if job.resultImages.isEmpty {
          Text("任务已完成，但后端没有返回图片地址。")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        } else {
          LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(job.resultImages) { image in
              ResultImageCard(model: model, image: image)
            }
          }
        }
      } else {
        Text("Submit a generation job to preview candidate images here.")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
      }
    }
    .padding(14)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
  }
}

struct ResultImageCard: View {
  @ObservedObject var model: AppModel
  let image: ResultImage

  @State private var imageData: Data?
  @State private var nsImage: NSImage?
  @State private var loadError = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(.quaternary)
          .aspectRatio(16.0 / 9.0, contentMode: .fit)

        if let nsImage {
          Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if !loadError.isEmpty {
          Text(loadError)
            .font(.caption)
            .foregroundStyle(.red)
            .padding()
        } else {
          ProgressView()
        }
      }
      .onDrag {
        dragProvider()
      }

      HStack {
        Text("Candidate \(image.candidateID + 1)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          Task { await model.copyImage(image) }
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
        .labelStyle(.iconOnly)

        Button {
          Task { await model.saveImage(image) }
        } label: {
          Label("Save", systemImage: "square.and.arrow.down")
        }
        .labelStyle(.iconOnly)
      }
    }
    .task(id: image.url) {
      await loadImage()
    }
  }

  private func loadImage() async {
    do {
      let data = try await model.imageExport.imageData(from: image, apiBase: model.apiBase)
      imageData = data
      nsImage = NSImage(data: data)
    } catch {
      loadError = formatUserFacingError(error)
    }
  }

  private func dragProvider() -> NSItemProvider {
    if let imageData,
       let url = model.imageExport.temporaryFileURL(data: imageData, suggestedFilename: image.filename) {
      return NSItemProvider(object: url as NSURL)
    }
    return NSItemProvider(object: image.url as NSString)
  }
}

struct StatusBadge: View {
  let status: JobStatus

  var body: some View {
    Text(status.label)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(background, in: Capsule())
      .foregroundStyle(foreground)
  }

  private var background: Color {
    switch status {
    case .succeeded: .green.opacity(0.16)
    case .failed: .red.opacity(0.14)
    case .running: .blue.opacity(0.14)
    case .queued: .orange.opacity(0.16)
    case .unknown: .gray.opacity(0.14)
    }
  }

  private var foreground: Color {
    switch status {
    case .succeeded: .green
    case .failed: .red
    case .running: .blue
    case .queued: .orange
    case .unknown: .secondary
    }
  }
}
