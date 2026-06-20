import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// 缩略图专用的降采样异步图：CGImageSource 按 `kCGImageSourceThumbnailMaxPixelSize`
/// 解码，2K/4K 结果图不再为 64pt 行头像 / 网格卡全量解码占内存。
///
/// - `data:` 与 `http(s)` URL 都走同一条 URLSession 路径（共享 URLCache，与 AsyncImage 同源缓存）。
/// - 降采样失败（损坏数据 / 不支持的格式）回 `.failure`，由调用方 phase 闭包给占位图标。
/// - **只**用于缩略图场景（JobRow 行头像、ResultImageView 网格卡）；
///   全屏 ImageViewer 需要捏合放大细节，保持全量解码，不要迁移。
struct DownsampledAsyncImage<Content: View>: View {
  let url: URL?
  /// 目标显示边长（pt），内部乘 displayScale 得解码像素上限。
  let maxDimension: CGFloat
  @ViewBuilder let content: (AsyncImagePhase) -> Content

  @Environment(\.displayScale) private var displayScale
  @State private var phase: AsyncImagePhase = .empty

  var body: some View {
    content(phase)
      .task(id: url) { await load() }
  }

  private func load() async {
    guard let url else {
      phase = .failure(URLError(.badURL))
      return
    }
    do {
      // URLSession 原生支持 data: scheme；http(s) 命中共享 URLCache。
      let (data, _) = try await URLSession.shared.data(from: url)
      let maxPixelSize = maxDimension * displayScale
      guard let image = await Self.downsampledImage(data: data, maxPixelSize: maxPixelSize) else {
        throw URLError(.cannotDecodeContentData)
      }
      phase = .success(Image(uiImage: image))
    } catch {
      guard !Task.isCancelled else { return }
      phase = .failure(error)
    }
  }

  /// CGImageSource 缩略图解码（不全量解码原图）；@concurrent：CPU 工作不占主线程
  /// （项目开了 approachable concurrency，nonisolated async 会跟随调用方 actor，必须显式标注）。
  @concurrent static func downsampledImage(data: Data, maxPixelSize: CGFloat) async -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
    let thumbnailOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ] as CFDictionary
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
