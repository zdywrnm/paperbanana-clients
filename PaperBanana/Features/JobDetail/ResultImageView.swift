import SwiftUI

struct ResultImageView: View {
  @Bindable var model: AppModel
  let image: ResultImage
  let outputFormat: OutputFormat

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if image.format == "svg" {
        SVGPreviewCard(url: model.resolvedImageURL(image.url))
      } else if let url = model.resolvedImageURL(image.url) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFit()
          case .failure:
            Image(systemName: "photo.badge.exclamationmark")
              .font(.largeTitle)
          default:
            ProgressView()
          }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
      }
      HStack {
        Text("\(outputFormat.rawValue.uppercased()) · 候选 \(image.candidateID + 1)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          Task { await model.exportResultImage(image, outputFormat: outputFormat) }
        } label: {
          Image(systemName: model.exportingResultImageID == image.id ? "hourglass" : "square.and.arrow.down")
        }
        .disabled(model.exportingResultImageID == image.id || image.url.isEmpty)
        .accessibilityLabel("保存或分享候选图 \(image.candidateID + 1)")
        Button {
          model.beginRefine(image)
        } label: {
          Image(systemName: "wand.and.stars")
        }
      }
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}
