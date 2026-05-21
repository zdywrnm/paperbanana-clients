import AppKit
import Foundation

final class ImageExportService {
  func imageData(from image: ResultImage, apiBase: String) async throws -> Data {
    try await imageData(from: image.url, apiBase: apiBase)
  }

  func imageData(from urlString: String, apiBase: String) async throws -> Data {
    if let data = dataURLPayload(urlString) {
      return data
    }

    guard let url = resolvedURL(urlString, apiBase: apiBase) else {
      throw PaperBananaAPIError.invalidURL(urlString)
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode >= 200,
          httpResponse.statusCode < 300
    else {
      throw PaperBananaAPIError.server("图片下载失败。")
    }
    return data
  }

  @MainActor
  func save(data: Data, suggestedFilename: String) throws {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = suggestedFilename.isEmpty ? "paperbanana-result.png" : suggestedFilename
    panel.allowedContentTypes = [.png, .jpeg]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try data.write(to: url)
  }

  @MainActor
  func copyToPasteboard(data: Data) throws {
    guard let image = NSImage(data: data) else {
      throw PaperBananaAPIError.server("无法读取图片。")
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([image])
  }

  func temporaryFileURL(data: Data, suggestedFilename: String) -> URL? {
    let filename = suggestedFilename.isEmpty ? "paperbanana-result.png" : suggestedFilename
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("PaperBanana", isDirectory: true)
      .appendingPathComponent(filename)
    do {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url)
      return url
    } catch {
      return nil
    }
  }

  func resolvedURL(_ urlString: String, apiBase: String) -> URL? {
    if urlString.hasPrefix("data:") { return nil }
    if let url = URL(string: urlString), url.scheme != nil {
      return url
    }
    let base = AppDefaults.normalizedAPIBase(apiBase)
    guard var components = URLComponents(string: base) else { return nil }
    let path = urlString.hasPrefix("/") ? urlString : "/\(urlString)"
    components.path = path
    return components.url
  }

  private func dataURLPayload(_ value: String) -> Data? {
    guard value.hasPrefix("data:"), let comma = value.firstIndex(of: ",") else { return nil }
    let payload = String(value[value.index(after: comma)...])
    return Data(base64Encoded: payload)
  }
}
