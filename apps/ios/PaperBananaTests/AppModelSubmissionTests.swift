import XCTest
@testable import PaperBanana

@MainActor
final class AppModelSubmissionTests: XCTestCase {
  func testMainModelDirectReferenceIsBlockedWhenModelCannotReadImages() {
    let model = AppModel()
    model.generation.selectedAPIKey = "sk-test"
    model.generation.draft.configurationMode = .advanced
    model.generation.draft.provider = .bailian
    model.generation.draft.mainModelName = "qwen3.7-max"
    model.generation.draft.referenceImageMode = .mainModel
    model.generation.draft.referenceImages = [
      PendingReferenceImage(id: "ref-1", filename: "style.png", mimeType: "image/png", data: Data([1, 2, 3]))
    ]

    XCTAssertTrue(model.generation.mainModelDirectUnsupported)
    XCTAssertFalse(model.generation.canSubmit)
    XCTAssertEqual(model.generation.referenceCapabilityNote, "当前主模型不能直读参考图，请使用独立识别模型。")
  }

  func testManualReferenceModeRequiresSelectionWhenNoUploadExists() {
    let model = AppModel()
    model.generation.selectedAPIKey = "sk-test"
    model.generation.draft.configurationMode = .advanced
    model.generation.draft.retrievalSetting = .manual
    model.generation.draft.manualReferenceIds = []

    XCTAssertFalse(model.generation.hasRequiredManualReferences)
    XCTAssertFalse(model.generation.canSubmit)

    model.generation.draft.manualReferenceIds = ["diagram-001"]

    XCTAssertTrue(model.generation.hasRequiredManualReferences)
    XCTAssertTrue(model.generation.canSubmit)
  }

  func testProviderSelectionRealignsReferenceImageModeLikeWeb() {
    let model = AppModel()
    model.generation.draft.configurationMode = .advanced
    model.generation.draft.referenceImageMode = .mainModel

    model.generation.selectProvider(.bailian)

    XCTAssertEqual(model.generation.draft.mainModelName, ProviderCatalog.config(for: .bailian).mainModel)
    XCTAssertEqual(model.generation.draft.referenceImageMode, .visionModel)

    model.generation.selectProvider(.openrouter)

    XCTAssertEqual(model.generation.draft.mainModelName, ProviderCatalog.config(for: .openrouter).mainModel)
    XCTAssertEqual(model.generation.draft.referenceImageMode, .mainModel)
  }

  func testMainModelSelectionRealignsReferenceImageModeLikeWeb() {
    let model = AppModel()
    model.generation.draft.configurationMode = .advanced
    model.generation.selectProvider(.bailian)

    model.generation.selectMainModel("qwen3.7-plus")

    XCTAssertEqual(model.generation.draft.referenceImageMode, .mainModel)

    model.generation.selectMainModel("qwen3.7-max")

    XCTAssertEqual(model.generation.draft.referenceImageMode, .visionModel)
  }

  func testBeginRefineInitializesIndependentTargetSettings() throws {
    let model = AppModel()
    model.generation.draft.configurationMode = .advanced
    model.generation.draft.aspectRatio = "3:2"
    model.generation.draft.imageSize = .twoK
    model.generation.refineInstruction = "old instruction"
    let image = try JSONDecoder().decode(ResultImage.self, from: Data("""
    {
      "filename": "candidate.png",
      "url": "data:image/png;base64,iVBORw0KGgo=",
      "mime_type": "image/png",
      "candidate_id": 0
    }
    """.utf8))

    model.generation.beginRefine(image)

    XCTAssertEqual(model.generation.refineSourceImage, image)
    XCTAssertEqual(model.generation.refineInstruction, "")
    XCTAssertEqual(model.generation.refineAspectRatio, "3:2")
    XCTAssertEqual(model.generation.refineImageSize, .twoK)

    model.generation.refineAspectRatio = "1:1"
    model.generation.refineImageSize = .oneK

    XCTAssertEqual(model.generation.draft.aspectRatio, "3:2")
    XCTAssertEqual(model.generation.draft.imageSize, .twoK)
  }

  func testRefineImageSizeFollowsSelectedProviderSupport() {
    let model = AppModel()
    model.generation.refineImageSize = .fourK

    model.generation.selectProvider(.bailian)

    XCTAssertEqual(model.generation.refineImageSize, .oneK)

    model.generation.selectProvider(.openai)
    model.generation.refineImageSize = .fourK
    model.generation.selectProvider(.gemini)

    XCTAssertEqual(model.generation.refineImageSize, .oneK)
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
    model.settings.feedbackMessage = "体验很好"

    XCTAssertTrue(model.settings.canSubmitFeedback)

    model.settings.feedbackMessage = ""
    XCTAssertFalse(model.settings.canSubmitFeedback)

    model.settings.feedbackMessage = String(repeating: "图", count: 2001)
    XCTAssertFalse(model.settings.canSubmitFeedback)
  }
}
