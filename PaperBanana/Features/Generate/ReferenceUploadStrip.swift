import SwiftUI
import PhotosUI

struct ReferenceUploadStrip: View {
  @Bindable var model: AppModel
  @Binding var selectedPhotoItems: [PhotosPickerItem]
  let showImporter: () -> Void

  private var remainingSlots: Int {
    max(0, ReferenceImageLimits.maxCount - model.generation.draft.referenceImages.count)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("参考图", systemImage: "photo.on.rectangle")
          .font(.headline)
        Spacer()
        PhotosPicker(
          selection: $selectedPhotoItems,
          maxSelectionCount: max(1, remainingSlots),
          matching: .images
        ) {
          Label("照片", systemImage: "photo.badge.plus")
        }
        .disabled(remainingSlots == 0)
        Button(action: showImporter) {
          Label("文件", systemImage: "folder.badge.plus")
        }
        .disabled(remainingSlots == 0)
      }
      if model.generation.draft.referenceImages.isEmpty {
        Text("支持 PNG、JPG、WebP、SVG，最多 3 张。")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(model.generation.draft.referenceImages) { image in
          HStack {
            Image(systemName: image.mimeType.contains("svg") ? "doc.richtext" : "photo")
            VStack(alignment: .leading) {
              Text(image.filename)
                .lineLimit(1)
              Text(ByteCountFormatter.string(fromByteCount: Int64(image.size), countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
              model.generation.removeReferenceImage(image)
            } label: {
              Image(systemName: "trash")
            }
          }
          .padding(10)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
      }
      if !model.generation.referenceUploadError.isEmpty {
        Text(model.generation.referenceUploadError)
          .font(.footnote)
          .foregroundStyle(.red)
      }
    }
  }
}
