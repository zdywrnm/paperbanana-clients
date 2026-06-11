import XCTest
@testable import PaperBanana

final class PipelineStateTests: XCTestCase {
  // MARK: - Fixtures

  private func makeJob(
    status: String,
    taskName: String = "diagram",
    stages: [[String: Any]] = []
  ) throws -> Job {
    let payload: [String: Any] = [
      "id": "job-pipeline",
      "status": status,
      "task_name": taskName,
      "stages": stages
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    return try JSONDecoder().decode(Job.self, from: data)
  }

  private func stage(_ type: String, round: Int = 0) -> [String: Any] {
    ["id": "stage-\(type)-\(round)-\(Int.random(in: 0...999_999))", "type": type, "round": round]
  }

  private func phases(_ state: PipelineState) -> [PipelineState.NodeID: PipelineState.NodePhase] {
    Dictionary(uniqueKeysWithValues: state.nodes.map { ($0.id, $0.phase) })
  }

  // MARK: - 空 stages

  func testQueuedJobWithoutStagesShowsAllPending() throws {
    let job = try makeJob(status: "queued")
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.map(\.id), [.plan, .render, .critique, .refine])
    XCTAssertEqual(state.nodes.map(\.phase), [.pending, .pending, .pending, .pending])
    XCTAssertEqual(state.nodes.map(\.label), ["规划", "渲染", "评审", "精修"])
    XCTAssertEqual(state.accessibilitySummary, "排队中，等待开始")
  }

  // MARK: - 单 plan

  func testRunningJobWithSinglePlanStageMarksPlanActive() throws {
    let job = try makeJob(status: "running", stages: [stage("plan")])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .active, .render: .pending, .critique: .pending, .refine: .pending])
    XCTAssertEqual(state.accessibilitySummary, "规划中")
  }

  // MARK: - 完整四阶段

  func testRunningJobWithAllFourStageTypesMarksRefineActive() throws {
    let job = try makeJob(status: "running", stages: [stage("plan"), stage("render"), stage("critic", round: 1), stage("refine")])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .done, .critique: .done, .refine: .active])
    XCTAssertEqual(state.accessibilitySummary, "精修中")
  }

  // MARK: - 多轮评审回跳

  func testSecondCriticRoundMarksCritiqueActiveWithRoundBadge() throws {
    let job = try makeJob(status: "running", stages: [
      stage("plan"), stage("render"), stage("critic", round: 1), stage("render"), stage("critic", round: 2)
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .done, .critique: .active, .refine: .pending])
    XCTAssertEqual(state.nodes.first(where: { $0.id == .critique })?.round, 2)
    XCTAssertEqual(state.accessibilitySummary, "评审中，第 2 轮")
  }

  func testRenderRerunAfterCritiqueKeepsCritiqueDone() throws {
    // critique → render 回跳：render 的最新位置在 critic 之后，render active、critique done。
    let job = try makeJob(status: "running", stages: [
      stage("plan"), stage("render"), stage("critic", round: 1), stage("render")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .active, .critique: .done, .refine: .pending])
    XCTAssertEqual(state.accessibilitySummary, "渲染中")
  }

  func testFirstRoundCritiqueHasNoRoundBadge() throws {
    let job = try makeJob(status: "running", stages: [stage("plan"), stage("render"), stage("critic", round: 1)])
    let state = PipelineState(job: job)

    XCTAssertNil(state.nodes.first(where: { $0.id == .critique })?.round)
    XCTAssertEqual(state.accessibilitySummary, "评审中")
  }

  // MARK: - plot 任务

  func testPlotJobHasThreeNodesWithCodeGenLabelAndNoRefine() throws {
    let job = try makeJob(status: "running", taskName: "plot", stages: [stage("plan")])
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.map(\.id), [.plan, .render, .critique])
    XCTAssertEqual(state.nodes.map(\.label), ["代码生成", "渲染", "评审"])
    XCTAssertEqual(state.nodes.first?.phase, .active)
    XCTAssertEqual(state.accessibilitySummary, "代码生成中")
  }

  // MARK: - succeeded

  func testSucceededJobMarksAllNodesDoneEvenWithPartialStages() throws {
    let job = try makeJob(status: "succeeded", stages: [stage("plan"), stage("render")])
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.map(\.phase), [.done, .done, .done, .done])
    XCTAssertEqual(state.accessibilitySummary, "已完成全部阶段")
  }

  // MARK: - failed

  func testFailedJobMarksCurrentNodeFailed() throws {
    let job = try makeJob(status: "failed", stages: [stage("plan"), stage("render")])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .failed, .critique: .pending, .refine: .pending])
    XCTAssertEqual(state.accessibilitySummary, "渲染阶段失败")
  }

  func testFailedJobWithoutStagesMarksFirstNodeFailed() throws {
    let job = try makeJob(status: "failed")
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.first?.phase, .failed)
    XCTAssertEqual(state.nodes.dropFirst().map(\.phase), [.pending, .pending, .pending])
    XCTAssertEqual(state.accessibilitySummary, "规划阶段失败")
  }

  // MARK: - unknown type 容错

  func testUnknownStageTypesAreIgnoredForPhases() throws {
    let job = try makeJob(status: "running", stages: [stage("plan"), stage("upload"), stage("render"), stage("telemetry")])
    let state = PipelineState(job: job)

    // 末尾 unknown stage 不抢 active：active 取最后一个可识别的 stage。
    XCTAssertEqual(phases(state), [.plan: .done, .render: .active, .critique: .pending, .refine: .pending])
  }

  func testOnlyUnknownStageTypesFallBackToAllPending() throws {
    let job = try makeJob(status: "running", stages: [stage("warmup")])
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.map(\.phase), [.pending, .pending, .pending, .pending])
    XCTAssertEqual(state.accessibilitySummary, "生成中")
  }

  // MARK: - "critique" 拼写兼容

  func testCritiqueSpellingAlsoMapsToCritiqueNode() throws {
    let job = try makeJob(status: "running", stages: [stage("plan"), stage("render"), stage("critique", round: 2)])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state)[.critique], .active)
    XCTAssertEqual(state.nodes.first(where: { $0.id == .critique })?.round, 2)
  }
}
