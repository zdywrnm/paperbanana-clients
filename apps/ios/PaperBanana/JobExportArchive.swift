import Foundation

struct JobExportAsset: Equatable {
  let path: String
  let url: String
}

struct ZipArchiveEntry: Equatable {
  let path: String
  let data: Data
}

enum ZipArchiveError: LocalizedError {
  case empty
  case invalidPath(String)
  case zip64Required

  var errorDescription: String? {
    switch self {
    case .empty:
      "没有可打包的任务素材。"
    case .invalidPath(let path):
      "ZIP 文件路径无效：\(path)"
    case .zip64Required:
      "任务素材过大，当前导出不支持 ZIP64。"
    }
  }
}

enum StoredZipArchive {
  static func make(entries: [ZipArchiveEntry]) throws -> Data {
    guard !entries.isEmpty else { throw ZipArchiveError.empty }

    var archive = Data()
    var centralRecords: [CentralDirectoryRecord] = []

    for entry in entries {
      try validate(path: entry.path)
      guard archive.count <= Int(UInt32.max), entry.data.count <= Int(UInt32.max) else {
        throw ZipArchiveError.zip64Required
      }

      let nameData = Data(entry.path.utf8)
      let localHeaderOffset = UInt32(archive.count)
      let crc = CRC32.checksum(entry.data)
      let size = UInt32(entry.data.count)

      archive.appendUInt32LE(0x04034b50)
      archive.appendUInt16LE(20)
      archive.appendUInt16LE(0x0800)
      archive.appendUInt16LE(0)
      archive.appendUInt16LE(0)
      archive.appendUInt16LE(0)
      archive.appendUInt32LE(crc)
      archive.appendUInt32LE(size)
      archive.appendUInt32LE(size)
      archive.appendUInt16LE(UInt16(nameData.count))
      archive.appendUInt16LE(0)
      archive.append(nameData)
      archive.append(entry.data)

      centralRecords.append(CentralDirectoryRecord(
        pathData: nameData,
        crc32: crc,
        size: size,
        localHeaderOffset: localHeaderOffset
      ))
    }

    guard archive.count <= Int(UInt32.max) else { throw ZipArchiveError.zip64Required }
    let centralDirectoryOffset = UInt32(archive.count)

    for record in centralRecords {
      archive.appendUInt32LE(0x02014b50)
      archive.appendUInt16LE(20)
      archive.appendUInt16LE(20)
      archive.appendUInt16LE(0x0800)
      archive.appendUInt16LE(0)
      archive.appendUInt16LE(0)
      archive.appendUInt16LE(0)
      archive.appendUInt32LE(record.crc32)
      archive.appendUInt32LE(record.size)
      archive.appendUInt32LE(record.size)
      archive.appendUInt16LE(UInt16(record.pathData.count))
      archive.appendUInt16LE(0)
      archive.appendUInt16LE(0)
      archive.appendUInt16LE(0)
      archive.appendUInt16LE(0)
      archive.appendUInt32LE(0)
      archive.appendUInt32LE(record.localHeaderOffset)
      archive.append(record.pathData)
    }

    let centralDirectorySize = archive.count - Int(centralDirectoryOffset)
    guard centralRecords.count <= Int(UInt16.max), centralDirectorySize <= Int(UInt32.max) else {
      throw ZipArchiveError.zip64Required
    }

    archive.appendUInt32LE(0x06054b50)
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(UInt16(centralRecords.count))
    archive.appendUInt16LE(UInt16(centralRecords.count))
    archive.appendUInt32LE(UInt32(centralDirectorySize))
    archive.appendUInt32LE(centralDirectoryOffset)
    archive.appendUInt16LE(0)

    return archive
  }

  private static func validate(path: String) throws {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed.hasPrefix("/") || trimmed.contains("..") || trimmed.contains("\\") {
      throw ZipArchiveError.invalidPath(path)
    }
    if Data(trimmed.utf8).count > Int(UInt16.max) {
      throw ZipArchiveError.invalidPath(path)
    }
  }
}

extension Job {
  var hasExportableAssets: Bool {
    !exportAssets.isEmpty
  }

  var exportAssets: [JobExportAsset] {
    let resultAssets = resultImages.enumerated().compactMap { index, image -> JobExportAsset? in
      guard !image.url.isEmpty else { return nil }
      let ext = JobExportArchiveSupport.fileExtension(
        filename: image.filename,
        mimeType: image.mimeType,
        fallback: outputFormat == .svg ? "svg" : "png"
      )
      return JobExportAsset(path: "results/result-\(index + 1).\(ext)", url: image.url)
    }

    let referenceAssets = referenceImages.enumerated().compactMap { index, image -> JobExportAsset? in
      guard let url = image.url, !url.isEmpty else { return nil }
      let ext = JobExportArchiveSupport.fileExtension(filename: image.filename, mimeType: image.mimeType, fallback: "png")
      return JobExportAsset(path: "references/reference-\(index + 1).\(ext)", url: url)
    }

    let stageAssets = stages.enumerated().compactMap { index, stage -> JobExportAsset? in
      guard let image = stage.image, !image.url.isEmpty else { return nil }
      let ext = JobExportArchiveSupport.fileExtension(filename: image.filename, mimeType: image.mimeType, fallback: "png")
      let type = JobExportArchiveSupport.safePathComponent(stage.type.isEmpty ? "stage" : stage.type)
      let number = String(format: "%02d", index + 1)
      return JobExportAsset(path: "stages/stage-\(number)-\(type).\(ext)", url: image.url)
    }

    return resultAssets + referenceAssets + stageAssets
  }

  func exportMetadataData() throws -> Data {
    let object: [String: Any] = [
      "id": id,
      "status": status,
      "provider": provider,
      "jobType": jobType,
      "userEmail": userEmail,
      "configurationMode": configurationMode,
      "taskName": taskName.rawValue,
      "caption": caption,
      "infographicCategory": infographicCategory,
      "outputFormat": outputFormat.rawValue,
      "imageSize": imageSize.rawValue,
      "mainModelName": mainModelName,
      "imageModelName": imageModelName,
      "referenceVisionModelName": referenceVisionModelName,
      "referenceImageMode": referenceImageMode?.rawValue ?? "",
      "referenceImageModeUsed": referenceImageModeUsed,
      "pipelineMode": pipelineMode,
      "retrievalSetting": retrievalSetting.rawValue,
      "retrievedReferenceIds": retrievedReferenceIDs,
      "criticMode": criticMode,
      "aspectRatio": aspectRatio,
      "numCandidates": numCandidates,
      "maxCriticRounds": maxCriticRounds,
      "promptCharCount": promptCharCount,
      "resultImageCount": resultImageCount,
      "referenceImageCount": referenceImageCount,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
      "startedAt": startedAt,
      "completedAt": completedAt,
      "error": error,
      "logsTail": logsTail,
      "resultImages": resultImages.map { image in
        [
          "filename": image.filename,
          "url": image.url,
          "storage": image.storage,
          "candidateId": image.candidateID,
          "mimeType": image.mimeType,
          "objectKey": image.objectKey
        ] as [String: Any]
      },
      "referenceImages": referenceImages.map { image in
        [
          "filename": image.filename,
          "url": image.url ?? "",
          "storage": image.storage ?? "",
          "mimeType": image.mimeType,
          "size": image.size,
          "objectKey": image.objectKey
        ] as [String: Any]
      },
      "stages": stages.map { stage in
        [
          "id": stage.id,
          "candidateId": stage.candidateID,
          "type": stage.type,
          "title": stage.title,
          "round": stage.round,
          "text": stage.text,
          "suggestion": stage.suggestion,
          "error": stage.error,
          "image": stage.image.map { image in
            [
              "filename": image.filename,
              "url": image.url,
              "storage": image.storage,
              "mimeType": image.mimeType
            ] as [String: Any]
          } ?? NSNull()
        ] as [String: Any]
      },
      "exportAssets": exportAssets.map { asset in
        [
          "path": asset.path,
          "url": asset.url
        ]
      }
    ]

    return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
  }

  var exportArchiveFilename: String {
    "paperbanana-\(JobExportArchiveSupport.safePathComponent(id.isEmpty ? "job" : id)).zip"
  }
}

enum JobExportArchiveSupport {
  static func fileExtension(filename: String, mimeType: String, fallback: String) -> String {
    let existing = URL(fileURLWithPath: filename).pathExtension.lowercased()
    if !existing.isEmpty { return safePathComponent(existing) }

    let lowered = mimeType.lowercased()
    if lowered.contains("svg") { return "svg" }
    if lowered.contains("jpeg") || lowered.contains("jpg") { return "jpg" }
    if lowered.contains("webp") { return "webp" }
    if lowered.contains("png") { return "png" }
    return safePathComponent(fallback.isEmpty ? "png" : fallback.lowercased())
  }

  static func safePathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
    let collapsed = String(scalars).replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
    let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    return trimmed.isEmpty ? "file" : trimmed
  }
}

private struct CentralDirectoryRecord {
  let pathData: Data
  let crc32: UInt32
  let size: UInt32
  let localHeaderOffset: UInt32
}

private enum CRC32 {
  private static let table: [UInt32] = (0..<256).map { value in
    var crc = UInt32(value)
    for _ in 0..<8 {
      crc = (crc & 1) == 1 ? (0xedb88320 ^ (crc >> 1)) : (crc >> 1)
    }
    return crc
  }

  static func checksum(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xffffffff
    for byte in data {
      let index = Int((crc ^ UInt32(byte)) & 0xff)
      crc = table[index] ^ (crc >> 8)
    }
    return crc ^ 0xffffffff
  }
}

private extension Data {
  mutating func appendUInt16LE(_ value: UInt16) {
    var littleEndian = value.littleEndian
    Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
  }

  mutating func appendUInt32LE(_ value: UInt32) {
    var littleEndian = value.littleEndian
    Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
  }
}
