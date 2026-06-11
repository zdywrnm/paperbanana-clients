import XCTest
@testable import PaperBanana

final class URLNormalizationTests: XCTestCase {
  func testAPIBaseNormalizationTrimsWhitespaceAndTrailingSlashes() {
    XCTAssertEqual(
      AppDefaults.normalizedAPIBase("  https://yifbnnzrwmxn.sealoshzh.site///  "),
      "https://yifbnnzrwmxn.sealoshzh.site"
    )
    XCTAssertEqual(AppDefaults.normalizedAPIBase(""), AppDefaults.sealosAPIBase)
  }

  func testRelativeImageURLsResolveAgainstConfiguredBase() {
    let client = PaperBananaAPIClient()

    XCTAssertEqual(
      client.resolvedImageURL(apiBase: "https://gateway.example/root/", url: "/signed/out.png")?.absoluteString,
      "https://gateway.example/root/signed/out.png"
    )
    XCTAssertEqual(
      client.resolvedImageURL(apiBase: "https://gateway.example/root", url: "signed/out.png")?.absoluteString,
      "https://gateway.example/root/signed/out.png"
    )
    XCTAssertEqual(
      client.resolvedImageURL(apiBase: "https://gateway.example", url: "data:image/png;base64,AAAA")?.absoluteString,
      "data:image/png;base64,AAAA"
    )
  }
}
