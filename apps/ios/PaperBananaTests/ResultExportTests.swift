import XCTest
@testable import PaperBanana

@MainActor
final class ResultExportTests: XCTestCase {
  func testExportsDataURLResultAsLocalShareableFile() async throws {
    let image = try JSONDecoder().decode(ResultImage.self, from: Data("""
    {
      "filename": "candidate.svg",
      "url": "data:image/svg+xml;base64,PHN2Zy8+",
      "mime_type": "image/svg+xml",
      "candidate_id": 1
    }
    """.utf8))
    let model = AppModel()

    await model.exportResultImage(image, outputFormat: .svg)

    let exported = try XCTUnwrap(model.exportedResultFile)
    XCTAssertEqual(exported.filename, "paperbanana-candidate-2.svg")
    XCTAssertEqual(try String(contentsOf: exported.url, encoding: .utf8), "<svg/>")
    XCTAssertNil(model.exportingResultImageID)
  }

  func testJobExportArchiveMatchesWebZipContents() async throws {
    let svgDataURL = "data:image/svg+xml;base64,PHN2Zy8+"
    let pngDataURL = "data:image/png;base64,iVBORw0KGgo="
    let webpDataURL = "data:image/webp;base64,UklGRg=="
    let job = try JSONDecoder().decode(Job.self, from: Data("""
    {
      "id": "job/archive 1",
      "status": "succeeded",
      "provider": "bailian",
      "task_name": "diagram",
      "output_format": "svg",
      "image_size": "2K",
      "result_images": [
        {"filename": "candidate.svg", "url": "\(svgDataURL)", "mime_type": "image/svg+xml", "candidate_id": 0}
      ],
      "reference_images": [
        {"filename": "style.png", "url": "\(pngDataURL)", "objectKey": "refs/style.png", "mimeType": "image/png", "size": 16}
      ],
      "stages": [
        {"id": "stage-1", "candidate_id": 0, "type": "critic", "round": 1, "image": {"filename": "stage.webp", "url": "\(webpDataURL)", "mime_type": "image/webp"}}
      ]
    }
    """.utf8))
    let model = AppModel()

    await model.exportJobArchive(job)

    let exported = try XCTUnwrap(model.exportedResultFile)
    let data = try Data(contentsOf: exported.url)
    XCTAssertEqual(exported.filename, "paperbanana-job-archive-1.zip")
    XCTAssertTrue(data.starts(with: Data([0x50, 0x4b, 0x03, 0x04])))
    XCTAssertNotNil(data.range(of: Data("metadata.json".utf8)))
    XCTAssertNotNil(data.range(of: Data("results/result-1.svg".utf8)))
    XCTAssertNotNil(data.range(of: Data("references/reference-1.png".utf8)))
    XCTAssertNotNil(data.range(of: Data("stages/stage-01-critic.webp".utf8)))
    XCTAssertNil(model.exportingJobArchiveID)
  }

  func testJobExportAssetsSkipMissingURLs() throws {
    let job = try JSONDecoder().decode(Job.self, from: Data("""
    {
      "id": "no-assets",
      "status": "succeeded",
      "result_images": [{"filename": "missing.png", "url": "", "mime_type": "image/png", "candidate_id": 0}],
      "reference_images": [{"filename": "style.png", "objectKey": "refs/style.png", "mimeType": "image/png", "size": 16}],
      "stages": [{"id": "stage-1", "type": "renderer"}]
    }
    """.utf8))

    XCTAssertFalse(job.hasExportableAssets)
    XCTAssertEqual(job.exportAssets, [])
  }
}
