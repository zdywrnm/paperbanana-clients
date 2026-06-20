import XCTest
@testable import PaperBanana

final class ReferenceInsightTextTests: XCTestCase {
  func testCuratedDiagramBriefsAreSpecificPerReference() throws {
    let zeco = try reference(
      id: "6a26bcf2f0d6ef02acf1d988",
      taskName: "diagram",
      title: "Figure 2: Illustration of ZeCO.",
      summary: "ZeCO sequence parallel methods and communication requirements."
    )
    let cermic = try reference(
      id: "6a26bcf2f0d6ef02acf1d987",
      taskName: "diagram",
      title: "Figure 1: Workflow of CERMIC.",
      summary: "Novelty-driven exploration with mutual information objective."
    )

    let zecoBrief = ReferenceInsightText.briefIntro(for: zeco)
    let cermicBrief = ReferenceInsightText.briefIntro(for: cermic)

    XCTAssertTrue(zecoBrief.contains("并行注意力"))
    XCTAssertTrue(cermicBrief.contains("强化学习探索"))
    XCTAssertNotEqual(zecoBrief, cermicBrief)
  }

  func testUnknownDiagramFallsBackToSemanticSummary() throws {
    let item = try reference(
      id: "new-video-rag-reference",
      taskName: "diagram",
      title: "Figure 2: The framework of our Video-RAG.",
      summary: "Query Decouple, Auxiliary Text Generation and Retrieval, Integration and Generation."
    )

    let brief = ReferenceInsightText.briefIntro(for: item)

    XCTAssertTrue(brief.contains("视频检索增强"))
    XCTAssertTrue(brief.contains("查询拆解"))
  }

  func testPlotBriefUsesChartTypeAndFocus() throws {
    let item = try reference(
      id: "plot-scatter",
      taskName: "plot",
      title: "A scatter plot about Number of parameters (M) and NMAE (%), titled Number of params. vs. NMAE on QM9",
      summary: #"{"Model":["GPW-NO"],"Number of parameters (M)":[0.7],"NMAE (%)":[0.7]}"#
    )

    let brief = ReferenceInsightText.briefIntro(for: item)

    XCTAssertTrue(brief.contains("散点图"))
    XCTAssertTrue(brief.contains("模型规模"))
  }

  private func reference(id: String, taskName: String, title: String, summary: String) throws -> ReferenceLibraryItem {
    let payload: [String: Any] = [
      "id": id,
      "taskName": taskName,
      "title": title,
      "summary": summary,
      "imageUrl": "https://example.com/reference.png",
      "source": "paperbanana-bench"
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder().decode(ReferenceLibraryItem.self, from: data)
  }
}
