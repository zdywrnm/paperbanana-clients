import XCTest
import SwiftUI
import UIKit
@testable import PaperBanana

final class DownsampledImageTests: XCTestCase {
  /// 生成一张纯色大图的 PNG 数据（模拟 2K 结果图）。
  private func makePNGData(width: CGFloat, height: CGFloat) throws -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
    let image = renderer.image { context in
      UIColor.systemYellow.setFill()
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    return try XCTUnwrap(image.pngData())
  }

  func testDownsampleCapsLongestSideAndKeepsAspectRatio() async throws {
    let data = try makePNGData(width: 2048, height: 1152) // 16:9 2K

    let image = await DownsampledAsyncImage<EmptyView>.downsampledImage(data: data, maxPixelSize: 128)

    let cgImage = try XCTUnwrap(image?.cgImage)
    XCTAssertLessThanOrEqual(max(cgImage.width, cgImage.height), 128)
    // 纵横比保持 16:9（±1px 取整误差）。
    let expectedHeight = Int((128.0 * 1152.0 / 2048.0).rounded())
    XCTAssertLessThanOrEqual(abs(cgImage.height - expectedHeight), 1)
  }

  func testDownsampleSmallImageDoesNotUpscale() async throws {
    let data = try makePNGData(width: 40, height: 40)

    let image = await DownsampledAsyncImage<EmptyView>.downsampledImage(data: data, maxPixelSize: 128)

    let cgImage = try XCTUnwrap(image?.cgImage)
    // kCGImageSourceThumbnailMaxPixelSize 是上限不是目标：小图不放大。
    XCTAssertLessThanOrEqual(max(cgImage.width, cgImage.height), 40)
  }

  func testDownsampleGarbageDataReturnsNilForPlaceholderFallback() async {
    let image = await DownsampledAsyncImage<EmptyView>.downsampledImage(
      data: Data("not an image".utf8),
      maxPixelSize: 128
    )

    XCTAssertNil(image)
  }
}
