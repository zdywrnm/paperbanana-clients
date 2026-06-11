import Foundation

/// 导出文件的下载（含 data: URL 解码）、命名与临时文件写入。
struct ResultFileExporter {
  var session: URLSession = .shared

  func download(from url: URL) async throws -> Data {
    let absoluteString = url.absoluteString
    if absoluteString.hasPrefix("data:") {
      return try Self.decodeDataURL(absoluteString)
    }

    let (data, response) = try await session.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw PaperBananaAPIError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw PaperBananaAPIError.server("结果图下载失败：HTTP \(httpResponse.statusCode)")
    }
    return data
  }

  func writeExportFile(data: Data, filename: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PaperBananaExports", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent(filename)
    try data.write(to: fileURL, options: .atomic)
    return fileURL
  }

  // MARK: - 文件命名

  static func filename(for image: ResultImage, outputFormat: OutputFormat) -> String {
    let fallbackFormat = outputFormat == .svg ? "svg" : image.format
    let existingExtension = URL(fileURLWithPath: image.filename).pathExtension
    let fileExtension = existingExtension.isEmpty ? fallbackFormat : existingExtension
    return "paperbanana-candidate-\(image.candidateID + 1).\(fileExtension)"
  }

  static func filename(for image: ReferenceImageAsset, index: Int) -> String {
    let existingExtension = URL(fileURLWithPath: image.filename).pathExtension
    let fileExtension = existingExtension.isEmpty ? image.displayFormat : existingExtension
    return "paperbanana-reference-\(index + 1).\(fileExtension)"
  }

  static func filename(for stage: JobStage, index: Int) -> String {
    let existingExtension = URL(fileURLWithPath: stage.image?.filename ?? "").pathExtension
    let fileExtension = existingExtension.isEmpty ? (stage.image?.displayFormat ?? "png") : existingExtension
    let stageType = stage.type
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: " ", with: "-")
    return "paperbanana-stage-\(String(format: "%02d", index + 1))-\(stageType.isEmpty ? "stage" : stageType).\(fileExtension)"
  }

  // MARK: - data: URL

  static func decodeDataURL(_ value: String) throws -> Data {
    guard let comma = value.firstIndex(of: ",") else {
      throw PaperBananaAPIError.invalidURL(value)
    }
    let metadata = value[..<comma]
    let payload = String(value[value.index(after: comma)...])
    if metadata.contains(";base64") {
      guard let data = Data(base64Encoded: payload) else {
        throw PaperBananaAPIError.decoding("data URL base64 无法解码")
      }
      return data
    }
    let decoded = payload.removingPercentEncoding ?? payload
    return Data(decoded.utf8)
  }
}
