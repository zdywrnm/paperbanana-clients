import XCTest
@testable import PaperBanana

final class ReferenceImageValidationTests: XCTestCase {
  func testReferenceUploadLimitsMatchWebConstants() {
    XCTAssertEqual(ReferenceImageLimits.maxCount, 3)
    XCTAssertEqual(ReferenceImageLimits.maxBytes, 5 * 1024 * 1024)
    XCTAssertTrue(ReferenceImageLimits.acceptedMimeTypes.contains("image/svg+xml"))
    XCTAssertTrue(ReferenceImageLimits.isAccepted(filename: "chart.svg", mimeType: nil, size: 100))
    XCTAssertTrue(ReferenceImageLimits.isAccepted(filename: "photo.jpg", mimeType: "image/jpeg", size: 100))
    XCTAssertFalse(ReferenceImageLimits.isAccepted(filename: "paper.pdf", mimeType: "application/pdf", size: 100))
    XCTAssertFalse(ReferenceImageLimits.isAccepted(filename: "huge.png", mimeType: "image/png", size: ReferenceImageLimits.maxBytes + 1))
  }
}
