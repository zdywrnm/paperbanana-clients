import XCTest
@testable import PaperBanana

@MainActor
final class AppModelSubmissionTests: XCTestCase {
  func testMainModelDirectReferenceIsBlockedWhenModelCannotReadImages() {
    let model = AppModel()
    model.selectedAPIKey = "sk-test"
    model.draft.configurationMode = .advanced
    model.draft.provider = .bailian
    model.draft.mainModelName = "qwen3.7-max"
    model.draft.referenceImageMode = .mainModel
    model.draft.referenceImages = [
      PendingReferenceImage(id: "ref-1", filename: "style.png", mimeType: "image/png", data: Data([1, 2, 3]))
    ]

    XCTAssertTrue(model.mainModelDirectUnsupported)
    XCTAssertFalse(model.canSubmit)
    XCTAssertEqual(model.referenceCapabilityNote, "当前主模型不能直读参考图，请使用独立识别模型。")
  }

  func testManualReferenceModeRequiresSelectionWhenNoUploadExists() {
    let model = AppModel()
    model.selectedAPIKey = "sk-test"
    model.draft.configurationMode = .advanced
    model.draft.retrievalSetting = .manual
    model.draft.manualReferenceIds = []

    XCTAssertFalse(model.hasRequiredManualReferences)
    XCTAssertFalse(model.canSubmit)

    model.draft.manualReferenceIds = ["diagram-001"]

    XCTAssertTrue(model.hasRequiredManualReferences)
    XCTAssertTrue(model.canSubmit)
  }

  func testProviderSelectionRealignsReferenceImageModeLikeWeb() {
    let model = AppModel()
    model.draft.configurationMode = .advanced
    model.draft.referenceImageMode = .mainModel

    model.selectProvider(.bailian)

    XCTAssertEqual(model.draft.mainModelName, ProviderCatalog.config(for: .bailian).mainModel)
    XCTAssertEqual(model.draft.referenceImageMode, .visionModel)

    model.selectProvider(.openrouter)

    XCTAssertEqual(model.draft.mainModelName, ProviderCatalog.config(for: .openrouter).mainModel)
    XCTAssertEqual(model.draft.referenceImageMode, .mainModel)
  }

  func testMainModelSelectionRealignsReferenceImageModeLikeWeb() {
    let model = AppModel()
    model.draft.configurationMode = .advanced
    model.selectProvider(.bailian)

    model.selectMainModel("qwen3.7-plus")

    XCTAssertEqual(model.draft.referenceImageMode, .mainModel)

    model.selectMainModel("qwen3.7-max")

    XCTAssertEqual(model.draft.referenceImageMode, .visionModel)
  }

  func testBeginRefineInitializesIndependentTargetSettings() throws {
    let model = AppModel()
    model.draft.configurationMode = .advanced
    model.draft.aspectRatio = "3:2"
    model.draft.imageSize = .twoK
    model.refineInstruction = "old instruction"
    let image = try JSONDecoder().decode(ResultImage.self, from: Data("""
    {
      "filename": "candidate.png",
      "url": "data:image/png;base64,iVBORw0KGgo=",
      "mime_type": "image/png",
      "candidate_id": 0
    }
    """.utf8))

    model.beginRefine(image)

    XCTAssertEqual(model.refineSourceImage, image)
    XCTAssertEqual(model.refineInstruction, "")
    XCTAssertEqual(model.refineAspectRatio, "3:2")
    XCTAssertEqual(model.refineImageSize, .twoK)

    model.refineAspectRatio = "1:1"
    model.refineImageSize = .oneK

    XCTAssertEqual(model.draft.aspectRatio, "3:2")
    XCTAssertEqual(model.draft.imageSize, .twoK)
  }

  func testRefineImageSizeFollowsSelectedProviderSupport() {
    let model = AppModel()
    model.refineImageSize = .fourK

    model.selectProvider(.bailian)

    XCTAssertEqual(model.refineImageSize, .oneK)

    model.selectProvider(.openai)
    model.refineImageSize = .fourK
    model.selectProvider(.gemini)

    XCTAssertEqual(model.refineImageSize, .oneK)
  }

  func testFeedbackCategoriesMatchWebContract() {
    XCTAssertEqual(
      FeedbackCategory.allCases.map(\.rawValue),
      ["bug", "feature", "experience", "other"]
    )
    XCTAssertEqual(
      FeedbackCategory.allCases.map(\.title),
      ["问题反馈", "功能建议", "体验意见", "其他"]
    )
  }

  func testFeedbackMessageLengthMatchesWebLimit() {
    let model = AppModel()
    model.feedbackMessage = "体验很好"

    XCTAssertTrue(model.canSubmitFeedback)

    model.feedbackMessage = ""
    XCTAssertFalse(model.canSubmitFeedback)

    model.feedbackMessage = String(repeating: "图", count: 2001)
    XCTAssertFalse(model.canSubmitFeedback)
  }
}
