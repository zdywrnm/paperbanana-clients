import XCTest
@testable import PaperBanana

/// 流水线派生状态测试。stage 的 type/title 全部取自真实后端契约
/// （laf-functions/paperbanana-api.ts 的 recordStage 调用点）：
/// - 后端只发 `planner` / `render` / `critic` / `stylist` 四种 type；
/// - 从不发 `refine`：精修放大阶段是 `type:'render'` + 标题「精修放大（…）」；
/// - `plan` / `critique` 拼写仅作历史数据兼容保留。
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

  private func stage(_ type: String, title: String = "", round: Int = 0) -> [String: Any] {
    [
      "id": "stage-\(type)-\(round)-\(Int.random(in: 0...999_999))",
      "type": type,
      "title": title,
      "round": round
    ]
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

  // MARK: - 单 planner

  func testRunningJobWithSinglePlannerStageMarksPlanActive() throws {
    let job = try makeJob(status: "running", stages: [stage("planner", title: "规划")])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .active, .render: .pending, .critique: .pending, .refine: .pending])
    XCTAssertEqual(state.accessibilitySummary, "规划中")
  }

  // MARK: - 完整真实序列（含精修放大）

  func testEnhanceRenderStageWithRefineTitleMarksRefineActive() throws {
    // 真实后端完整序列：planner → render → critic → render「精修放大（2K）」。
    // 精修放大是 type:'render'，靠标题映射到精修节点（镜像小程序 stageMarker）。
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染"),
      stage("critic", title: "图像评审（第1轮）", round: 1),
      stage("render", title: "精修放大（2K）")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .done, .critique: .done, .refine: .active])
    XCTAssertEqual(state.accessibilitySummary, "精修中")
  }

  func testEnhanceFallbackTitleStillMapsToRefine() throws {
    // 精修放大失败回退标题「精修放大（2K，已回退）」仍含「精修」→ 精修节点。
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染"),
      stage("render", title: "精修放大（2K，已回退）")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state)[.refine], .active)
    XCTAssertEqual(phases(state)[.render], .done)
  }

  // MARK: - 多轮评审回跳

  func testSecondCriticRoundMarksCritiqueActiveWithRoundBadge() throws {
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染"),
      stage("critic", title: "图像评审（第1轮）", round: 1),
      stage("render", title: "重渲染（第1轮）", round: 1),
      stage("critic", title: "图像评审（第2轮）", round: 2)
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .done, .critique: .active, .refine: .pending])
    XCTAssertEqual(state.nodes.first(where: { $0.id == .critique })?.round, 2)
    XCTAssertEqual(state.accessibilitySummary, "评审中，第 2 轮")
  }

  func testRenderRerunAfterCriticKeepsCritiqueDone() throws {
    // critic → render 回跳：render 的最新位置在 critic 之后，render active、critique done。
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染"),
      stage("critic", title: "图像评审（第1轮）", round: 1),
      stage("render", title: "重渲染（第1轮）", round: 1)
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .active, .critique: .done, .refine: .pending])
    XCTAssertEqual(state.accessibilitySummary, "渲染中")
  }

  func testFirstRoundCriticHasNoRoundBadge() throws {
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染"),
      stage("critic", title: "图像评审（第1轮）", round: 1)
    ])
    let state = PipelineState(job: job)

    XCTAssertNil(state.nodes.first(where: { $0.id == .critique })?.round)
    XCTAssertEqual(state.accessibilitySummary, "评审中")
  }

  // MARK: - stylist 归属（跟随小程序：不映射任何节点）

  func testStylistStageDoesNotClaimActiveAndKeepsPlanActive() throws {
    // 小程序 stageMarker 把 stylist 落入通用 '步' 标记，不并入任何节点；
    // 这里跟随：styling 期间规划节点保持 active。
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("stylist", title: "风格")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .active, .render: .pending, .critique: .pending, .refine: .pending])
    XCTAssertEqual(state.accessibilitySummary, "规划中")
  }

  func testStylistBetweenPlannerAndRenderDoesNotBreakOrdering() throws {
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("stylist", title: "风格"),
      stage("render", title: "初次渲染")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state), [.plan: .done, .render: .active, .critique: .pending, .refine: .pending])
  }

  // MARK: - plot 任务

  func testPlotJobHasThreeNodesWithCodeGenLabelAndNoRefine() throws {
    let job = try makeJob(status: "running", taskName: "plot", stages: [stage("planner", title: "统计图规划")])
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.map(\.id), [.plan, .render, .critique])
    XCTAssertEqual(state.nodes.map(\.label), ["代码生成", "渲染", "评审"])
    XCTAssertEqual(state.nodes.first?.phase, .active)
    XCTAssertEqual(state.accessibilitySummary, "代码生成中")
  }

  func testPlotJobEnhanceStageMarksAllThreeNodesDone() throws {
    // plot 在 2K/4K + 支持图生图的 provider 上也会发精修放大 stage，但 plot 无精修节点：
    // 三个节点全部 done（基础流水线已完成），摘要仍报精修中。
    let job = try makeJob(status: "running", taskName: "plot", stages: [
      stage("planner", title: "统计图规划"),
      stage("render", title: "统计图初次渲染"),
      stage("critic", title: "统计图评审（第1轮）", round: 1),
      stage("render", title: "精修放大（2K）")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.map(\.phase), [.done, .done, .done])
    XCTAssertEqual(state.accessibilitySummary, "精修中")
  }

  // MARK: - succeeded

  func testSucceededJobMarksAllNodesDoneEvenWithPartialStages() throws {
    let job = try makeJob(status: "succeeded", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(state.nodes.map(\.phase), [.done, .done, .done, .done])
    XCTAssertEqual(state.accessibilitySummary, "已完成全部阶段")
  }

  // MARK: - failed

  func testFailedJobMarksCurrentNodeFailed() throws {
    let job = try makeJob(status: "failed", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染")
    ])
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
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("upload"),
      stage("render", title: "初次渲染"),
      stage("telemetry")
    ])
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

  // MARK: - 拼写兼容（历史数据）

  func testLegacyPlanSpellingAlsoMapsToPlanNode() throws {
    // 后端实际发 `planner`；`plan` 拼写兼容历史数据（小程序匹配 'plan' || 'planner'）。
    let job = try makeJob(status: "running", stages: [stage("plan", title: "规划")])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state)[.plan], .active)
    XCTAssertEqual(state.accessibilitySummary, "规划中")
  }

  func testLegacyCritiqueSpellingAlsoMapsToCritiqueNode() throws {
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "规划"),
      stage("render", title: "初次渲染"),
      stage("critique", title: "图像评审（第2轮）", round: 2)
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state)[.critique], .active)
    XCTAssertEqual(state.nodes.first(where: { $0.id == .critique })?.round, 2)
  }

  // MARK: - 标题判定优先于 type（镜像小程序 stageMarker 顺序）

  func testRefineTitleOnPlannerStageMapsToRefineNode() throws {
    // runRefineJob 的规划阶段是 type:'planner' + 标题「精修规划」：
    // 小程序 stageMarker 的精修判定先于 type 判定（标记 '修'），这里镜像同一顺序。
    let job = try makeJob(status: "running", stages: [
      stage("planner", title: "精修规划"),
      stage("render", title: "精修渲染")
    ])
    let state = PipelineState(job: job)

    XCTAssertEqual(phases(state)[.refine], .active)
    XCTAssertEqual(phases(state)[.plan], .pending)
  }

  func testEnhanceLikeEnglishTypesAlsoMapToRefine() throws {
    // 小程序还按 type 含 refine/upscale/enhance 兜底判定精修，这里保持一致。
    for type in ["refine", "upscale", "enhance"] {
      let job = try makeJob(status: "running", stages: [
        stage("planner", title: "规划"),
        stage(type)
      ])
      let state = PipelineState(job: job)
      XCTAssertEqual(phases(state)[.refine], .active, "type=\(type) 应映射到精修节点")
    }
  }
}
