import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

/// 照片 / 文件参考图导入管线（从 GenerateView 原样搬出，行为不变）：
/// 安全作用域读取、MIME 白名单匹配、HEIC→JPG 转码、容量上限提示。
@MainActor
struct ReferenceImportPipeline {
  let generation: GenerationStore

  static var referenceContentTypes: [UTType] {
    [
      .png,
      .jpeg,
      UTType(filenameExtension: "webp") ?? .image,
      UTType(filenameExtension: "svg") ?? .image
    ]
  }

  /// 文件导入入口：超过剩余槽位时与照片路径同样给用户提示，不再静默丢弃多余文件。
  func addFileReferences(_ urls: [URL]) {
    guard !generation.referenceUploadBlockedByRetrieval else {
      generation.referenceUploadError = generation.referenceUploadBlockedMessage
      return
    }
    let remainingSlots = ReferenceImageLimits.maxCount - generation.draft.referenceImages.count
    guard remainingSlots > 0 else {
      generation.referenceUploadError = "最多只能上传 \(ReferenceImageLimits.maxCount) 张参考图。"
      return
    }
    for url in urls.prefix(remainingSlots) {
      addReference(url)
    }
    // 注意放在循环后：addReferenceFile 每次会先清空 referenceUploadError。
    if urls.count > remainingSlots {
      generation.referenceUploadError = "最多 \(ReferenceImageLimits.maxCount) 张参考图，多余文件已忽略。"
    }
  }

  func addReference(_ url: URL) {
    let didStart = url.startAccessingSecurityScopedResource()
    defer {
      if didStart { url.stopAccessingSecurityScopedResource() }
    }
    do {
      let data = try Data(contentsOf: url)
      let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
      generation.addReferenceFile(filename: url.lastPathComponent, mimeType: type?.preferredMIMEType, data: data)
    } catch {
      generation.referenceUploadError = formatUserFacingError(error)
    }
  }

  func addPhotoReferences(_ items: [PhotosPickerItem]) async {
    guard !generation.referenceUploadBlockedByRetrieval else {
      generation.referenceUploadError = generation.referenceUploadBlockedMessage
      return
    }
    let remainingSlots = ReferenceImageLimits.maxCount - generation.draft.referenceImages.count
    guard remainingSlots > 0 else {
      generation.referenceUploadError = "最多只能上传 \(ReferenceImageLimits.maxCount) 张参考图。"
      return
    }

    for (index, item) in items.prefix(remainingSlots).enumerated() {
      await addPhotoReference(item, index: index)
    }
    // 与文件路径同语义：部分超限也提示，不静默丢弃（addReferenceFile 会清错误，放循环后）。
    if items.count > remainingSlots {
      generation.referenceUploadError = "最多 \(ReferenceImageLimits.maxCount) 张参考图，多余照片已忽略。"
    }
  }

  private func addPhotoReference(_ item: PhotosPickerItem, index: Int) async {
    do {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        generation.referenceUploadError = "无法读取所选照片。"
        return
      }

      if let type = acceptedReferenceContentType(from: item.supportedContentTypes) {
        generation.addReferenceFile(
          filename: photoFilename(index: index, contentType: type),
          mimeType: type.preferredMIMEType,
          data: data
        )
        return
      }

      guard let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.92) else {
        generation.referenceUploadError = "无法将所选照片转换为 JPG。"
        return
      }

      generation.addReferenceFile(
        filename: photoFilename(index: index, contentType: .jpeg),
        mimeType: "image/jpeg",
        data: jpegData
      )
    } catch {
      generation.referenceUploadError = formatUserFacingError(error)
    }
  }

  private func acceptedReferenceContentType(from contentTypes: [UTType]) -> UTType? {
    contentTypes.first { type in
      guard let mimeType = type.preferredMIMEType else { return false }
      return ReferenceImageLimits.acceptedMimeTypes.contains(mimeType)
    }
  }

  private func photoFilename(index: Int, contentType: UTType) -> String {
    let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
    return "photo-reference-\(index + 1).\(fileExtension)"
  }
}
