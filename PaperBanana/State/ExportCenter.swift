import Foundation
import Observation

/// 结果图 / 参考图 / 阶段图 / 任务打包的导出入口（统一去重的导出流程）。
@Observable
@MainActor
final class ExportCenter {
  var exportedResultFile: ExportedResultFile?
  var exportingResultImageID: ResultImage.ID?
  var exportingReferenceImageID: ReferenceImageAsset.ID?
  var exportingStageImageID: JobStage.ID?
  var exportingJobArchiveID: Job.ID?

  /// 错误弹窗（由 AppModel 注入的跨域门面）。
  /// 默认实现 debug 下断言提醒忘记接线（release 下仍是 no-op），避免错误静默丢失。
  @ObservationIgnored var presentAlert: (String) -> Void = { message in
    assertionFailure("presentAlert not wired: \(message)")
  }

  private let apiClient: PaperBananaAPIClient
  private let settings: SettingsStore
  private let exporter: ResultFileExporter

  init(apiClient: PaperBananaAPIClient, settings: SettingsStore, exporter: ResultFileExporter = ResultFileExporter()) {
    self.apiClient = apiClient
    self.settings = settings
    self.exporter = exporter
  }

  func exportResultImage(_ image: ResultImage, outputFormat: OutputFormat) async {
    exportingResultImageID = image.id
    defer { exportingResultImageID = nil }
    await exportSingleAsset(urlString: image.url, filename: ResultFileExporter.filename(for: image, outputFormat: outputFormat))
  }

  func exportReferenceImage(_ image: ReferenceImageAsset, index: Int) async {
    exportingReferenceImageID = image.id
    defer { exportingReferenceImageID = nil }
    await exportSingleAsset(urlString: image.url ?? "", filename: ResultFileExporter.filename(for: image, index: index))
  }

  func exportStageImage(_ stage: JobStage, index: Int) async {
    exportingStageImageID = stage.id
    defer { exportingStageImageID = nil }
    await exportSingleAsset(urlString: stage.image?.url ?? "", filename: ResultFileExporter.filename(for: stage, index: index))
  }

  func exportJobArchive(_ job: Job) async {
    exportingJobArchiveID = job.id
    defer { exportingJobArchiveID = nil }

    do {
      guard job.hasExportableAssets else {
        throw ZipArchiveError.empty
      }

      var entries = [ZipArchiveEntry(path: "metadata.json", data: try job.exportMetadataData())]
      for asset in job.exportAssets {
        guard let resolvedURL = resolvedImageURL(asset.url) else {
          throw PaperBananaAPIError.invalidURL(asset.url)
        }
        entries.append(ZipArchiveEntry(path: asset.path, data: try await exporter.download(from: resolvedURL)))
      }

      let archiveData = try StoredZipArchive.make(entries: entries)
      let fileURL = try exporter.writeExportFile(data: archiveData, filename: job.exportArchiveFilename)
      exportedResultFile = ExportedResultFile(url: fileURL, filename: fileURL.lastPathComponent)
    } catch {
      presentAlert(formatUserFacingError(error))
    }
  }

  private func exportSingleAsset(urlString: String, filename: String) async {
    do {
      guard let resolvedURL = resolvedImageURL(urlString) else {
        throw PaperBananaAPIError.invalidURL(urlString)
      }
      let data = try await exporter.download(from: resolvedURL)
      let fileURL = try exporter.writeExportFile(data: data, filename: filename)
      exportedResultFile = ExportedResultFile(url: fileURL, filename: filename)
    } catch {
      presentAlert(formatUserFacingError(error))
    }
  }

  private func resolvedImageURL(_ url: String) -> URL? {
    apiClient.resolvedImageURL(apiBase: settings.apiBase, url: url)
  }
}
