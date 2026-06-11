import Foundation

struct ReferenceImageAsset: Codable, Identifiable, Equatable, Hashable {
  var filename: String
  var mimeType: String
  var size: Int
  var objectKey: String
  var uploadToken: String?
  var url: String?
  var storage: String?

  var id: String {
    objectKey.isEmpty ? filename : objectKey
  }

  var displayFormat: String {
    if mimeType.contains("svg") || filename.lowercased().hasSuffix(".svg") { return "svg" }
    if mimeType.contains("jpeg") || mimeType.contains("jpg") || filename.lowercased().hasSuffix(".jpg") || filename.lowercased().hasSuffix(".jpeg") { return "jpg" }
    if mimeType.contains("webp") || filename.lowercased().hasSuffix(".webp") { return "webp" }
    return "png"
  }

  init(
    filename: String,
    mimeType: String,
    size: Int,
    objectKey: String,
    uploadToken: String? = nil,
    url: String? = nil,
    storage: String? = nil
  ) {
    self.filename = filename
    self.mimeType = mimeType
    self.size = size
    self.objectKey = objectKey
    self.uploadToken = uploadToken
    self.url = url
    self.storage = storage
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    filename = container.string("filename", default: "reference")
    mimeType = container.string("mime_type", "mimeType", default: "")
    size = container.int("size")
    objectKey = container.string("object_key", "objectKey")
    uploadToken = container.optionalString("upload_token", "uploadToken")
    url = container.optionalString("url")
    storage = container.optionalString("storage")
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    try container.encode(filename, forKey: .key("filename"))
    try container.encode(mimeType, forKey: .key("mimeType"))
    try container.encode(size, forKey: .key("size"))
    try container.encode(objectKey, forKey: .key("objectKey"))
    try container.encodeIfPresent(uploadToken, forKey: .key("uploadToken"))
  }

  var dictionary: [String: Any] {
    var result: [String: Any] = [
      "filename": filename,
      "mimeType": mimeType,
      "size": size,
      "objectKey": objectKey
    ]
    if let uploadToken { result["uploadToken"] = uploadToken }
    return result
  }
}

struct PendingReferenceImage: Identifiable, Equatable {
  let id: String
  let filename: String
  let mimeType: String
  let data: Data

  var size: Int { data.count }
}

typealias ReferenceUploadItem = PendingReferenceImage

enum ReferenceImageLimits {
  static let maxCount = 3
  static let maxBytes = 5 * 1024 * 1024
  static let acceptedMimeTypes: Set<String> = [
    "image/png",
    "image/jpeg",
    "image/webp",
    "image/svg+xml"
  ]

  static func normalizedMimeType(filename: String, mimeType: String?) -> String {
    let value = (mimeType ?? "").lowercased()
    if acceptedMimeTypes.contains(value) { return value }
    let ext = (filename as NSString).pathExtension.lowercased()
    switch ext {
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "webp": return "image/webp"
    case "svg": return "image/svg+xml"
    default: return value
    }
  }

  static func isAccepted(filename: String, mimeType: String?, size: Int) -> Bool {
    guard size > 0, size <= maxBytes else { return false }
    return acceptedMimeTypes.contains(normalizedMimeType(filename: filename, mimeType: mimeType))
  }
}

struct ReferenceLibraryItem: Decodable, Identifiable, Equatable {
  let id: String
  let taskName: TaskName
  let title: String
  let summary: String
  let imageURL: String
  let imageObjectKey: String
  let source: String

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)
    id = container.string("id", "_id")
    taskName = TaskName(rawValue: container.string("task_name", "taskName", default: "diagram")) ?? .diagram
    title = container.string("title", "visualIntent", "caption")
    summary = container.string("summary", "content", "methodExcerpt")
    imageURL = container.string("image_url", "imageUrl", "url")
    imageObjectKey = container.string("image_object_key", "imageObjectKey", "objectKey")
    source = container.string("source", default: "paperbanana-bench")
  }
}
