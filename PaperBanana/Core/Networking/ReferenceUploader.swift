import Foundation

/// 参考图上传：prepare（获取签名地址）+ PUT 上传，返回可提交的资产描述。
struct ReferenceUploader {
  let apiClient: PaperBananaAPIClient

  func upload(_ images: [PendingReferenceImage], apiBase: String) async throws -> [ReferenceImageAsset] {
    guard !images.isEmpty else { return [] }
    let files = images.map {
      ReferenceUploadFile(clientId: "\($0.id):original", role: "original", filename: $0.filename, mimeType: $0.mimeType, size: $0.size)
    }
    let prepared = try await apiClient.prepareReferenceUpload(apiBase: apiBase, files: files)
    var uploadsByID = Dictionary(uniqueKeysWithValues: prepared.map { ($0.clientId, $0) })
    var assets: [ReferenceImageAsset] = []
    for image in images {
      let clientID = "\(image.id):original"
      guard let upload = uploadsByID.removeValue(forKey: clientID) else {
        throw PaperBananaAPIError.server("参考图上传地址创建失败。")
      }
      try await apiClient.uploadReference(data: image.data, mimeType: image.mimeType, uploadURL: upload.uploadURL)
      assets.append(ReferenceImageAsset(filename: image.filename, mimeType: image.mimeType, size: image.size, objectKey: upload.objectKey, uploadToken: upload.uploadToken))
    }
    return assets
  }
}
