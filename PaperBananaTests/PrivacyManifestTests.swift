import XCTest
@testable import PaperBanana

final class PrivacyManifestTests: XCTestCase {
  func testPrivacyManifestIsBundledWithAppStoreRequiredReasonAPI() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let data = try Data(contentsOf: url)
    let manifest = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    )

    XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
    XCTAssertNotNil(manifest["NSPrivacyTrackingDomains"] as? [Any])

    let accessedTypes = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    let userDefaults = try XCTUnwrap(accessedTypes.first {
      $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
    })
    XCTAssertEqual(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
  }

  func testPrivacyManifestDeclaresNoTrackingForCollectedData() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let data = try Data(contentsOf: url)
    let manifest = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    )

    let collectedTypes = try XCTUnwrap(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
    let declaredTypes = Set(collectedTypes.compactMap { $0["NSPrivacyCollectedDataType"] as? String })

    XCTAssertTrue(declaredTypes.contains("NSPrivacyCollectedDataTypeEmailAddress"))
    XCTAssertTrue(declaredTypes.contains("NSPrivacyCollectedDataTypeOtherUserContent"))
    XCTAssertTrue(declaredTypes.contains("NSPrivacyCollectedDataTypePhotosorVideos"))
    XCTAssertTrue(collectedTypes.allSatisfy { ($0["NSPrivacyCollectedDataTypeTracking"] as? Bool) == false })
  }
}
