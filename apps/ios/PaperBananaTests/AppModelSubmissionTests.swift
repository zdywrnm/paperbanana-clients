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
