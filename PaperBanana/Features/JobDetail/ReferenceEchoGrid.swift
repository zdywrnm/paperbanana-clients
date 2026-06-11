import SwiftUI

struct ReferenceEchoGrid: View {
  @Bindable var model: AppModel
  let references: [ReferenceImageAsset]

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: 150), spacing: 12)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text("参考回显")
          .font(.subheadline.bold())
        Text("仅作风格参考，不决定版式。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(Array(references.enumerated()), id: \.element.id) { index, reference in
          ReferenceEchoCard(model: model, reference: reference, index: index)
        }
      }
    }
  }
}

struct ReferenceEchoCard: View {
  @Bindable var model: AppModel
  let reference: ReferenceImageAsset
  let index: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ReferenceImagePreview(url: model.resolvedImageURL(reference.url ?? ""), mimeType: reference.mimeType)
      HStack {
        Text("参考图 \(index + 1) · \(reference.displayFormat.uppercased())")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer()
        Button {
          Task { await model.exports.exportReferenceImage(reference, index: index) }
        } label: {
          Image(systemName: model.exports.exportingReferenceImageID == reference.id ? "hourglass" : "square.and.arrow.down")
        }
        .disabled(model.exports.exportingReferenceImageID == reference.id || (reference.url ?? "").isEmpty)
        .accessibilityLabel("保存或分享参考图 \(index + 1)")
      }
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}

struct ReferenceImagePreview: View {
  let url: URL?
  let mimeType: String

  var body: some View {
    if mimeType.contains("svg") {
      SVGPreviewCard(url: url)
    } else if let url {
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
      .frame(maxWidth: .infinity, minHeight: 120)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
      .clipShape(RoundedRectangle(cornerRadius: 14))
    } else {
      Label("参考图", systemImage: "photo")
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
  }
}
