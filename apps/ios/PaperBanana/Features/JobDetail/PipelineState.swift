import Foundation

/// 从 `Job` 纯函数派生的流水线展示状态：View 零逻辑，全部边角在这里钉死。
///
/// 派生规则：
/// - diagram 任务节点为 规划/渲染/评审/精修；plot 任务为 代码生成/渲染/评审（无精修节点）。
/// - job 进行中（queued/running）时，最后一个**可识别** stage 的 type 是 active 节点；
///   其它节点按"该 type 最新出现位置是否在 active 位置之前"判定 done / pending——
///   这样多轮评审回跳（critic → render 再渲染）时评审保持 done、渲染重新 active。
/// - job succeeded 时全部 done；failed 时当前节点标记 failed（无 stages 则第一个节点 failed）。
/// - 未知 stage type 一律忽略（不抢 active、不影响排序）。stylist 也按未知处理：
///   小程序（utils/jobs.ts stageMarker）未把 stylist 并入任何节点（落入通用 '步' 标记），
///   这里跟随——styling 期间规划节点保持 active。
struct PipelineState: Equatable {
  enum NodeID: String, CaseIterable {
    case plan, render, critique, refine

    /// 后端 stage(type, title) → 节点映射，镜像小程序 utils/jobs.ts stageMarker 的真实契约：
    /// - 精修/放大判定**先于** type 判定：后端从不发 `refine` 类型，精修放大阶段记录为
    ///   `type:'render'`、标题含「精修」/「放大」（laf-functions/paperbanana-api.ts
    ///   enhanceCandidateToResolution / runRefineJob），靠标题区分；
    /// - `planner` 是后端实际拼写，`plan` 兼容历史数据；
    /// - `critic` 是后端实际拼写，`critique` 兼容历史数据；
    /// - `stylist` 不映射节点（跟随小程序的通用标记处理）。
    init?(stageType: String, title: String = "") {
      let type = stageType.lowercased()
      if title.contains("精修") || title.contains("放大")
        || type.contains("refine") || type.contains("upscale") || type.contains("enhance") {
        self = .refine
        return
      }
      switch type {
      case "plan", "planner": self = .plan
      case "render": self = .render
      case "critic", "critique": self = .critique
      default: return nil
      }
    }

    /// 节点图标（流水线节点与阶段卡共用）。
    var systemImage: String {
      switch self {
      case .plan: "list.bullet.clipboard"
      case .render: "paintbrush.pointed"
      case .critique: "magnifyingglass"
      case .refine: "wand.and.sparkles"
      }
    }
  }

  enum NodePhase: Equatable {
    case pending, active, done, failed
  }

  struct Node: Equatable {
    let id: NodeID
    let label: String
    let phase: NodePhase
    /// 评审节点的轮次徽标（round > 1 才显示）。
    let round: Int?
  }

  let nodes: [Node]
  /// 整卡 VoiceOver 摘要，如 "评审中，第 2 轮"。
  let accessibilitySummary: String

  init(job: Job) {
    let isPlot = job.taskName == .plot
    let nodeIDs: [NodeID] = isPlot ? [.plan, .render, .critique] : [.plan, .render, .critique, .refine]

    func label(for id: NodeID) -> String {
      switch id {
      case .plan: isPlot ? "代码生成" : "规划"
      case .render: "渲染"
      case .critique: "评审"
      case .refine: "精修"
      }
    }

    // 各 type 的最新出现位置 / 最新轮次（stage type 可能乱序、重复）。
    var latestPosition: [NodeID: Int] = [:]
    var latestRound: [NodeID: Int] = [:]
    for (index, stage) in job.stages.enumerated() {
      guard let id = NodeID(stageType: stage.type, title: stage.title) else { continue }
      latestPosition[id] = index
      latestRound[id] = stage.round
    }

    // active 节点 = 最后一个可识别 stage 的 type（末尾 unknown stage 不抢 active）。
    let activeID = job.stages.reversed().lazy
      .compactMap { NodeID(stageType: $0.type, title: $0.title) }
      .first
    let activePosition = activeID.flatMap { latestPosition[$0] }

    let status = job.statusKind

    nodes = nodeIDs.map { id in
      let phase: NodePhase
      switch status {
      case .succeeded:
        phase = .done
      case .failed:
        if let activeID, let activePosition {
          if id == activeID {
            phase = .failed
          } else if let position = latestPosition[id], position < activePosition {
            phase = .done
          } else {
            phase = .pending
          }
        } else {
          // 没有任何可识别 stage 就失败：标记第一个节点。
          phase = id == nodeIDs.first ? .failed : .pending
        }
      default: // queued / running / unknown
        if let activeID, let activePosition {
          if id == activeID {
            phase = .active
          } else if let position = latestPosition[id], position < activePosition {
            phase = .done
          } else {
            phase = .pending
          }
        } else {
          phase = .pending
        }
      }

      let round: Int? = {
        guard id == .critique, let value = latestRound[.critique], value > 1 else { return nil }
        return value
      }()

      return Node(id: id, label: label(for: id), phase: phase, round: round)
    }

    accessibilitySummary = Self.summary(
      status: status,
      activeID: activeID,
      label: label(for:),
      criticRound: latestRound[.critique] ?? 0,
      hasStages: !job.stages.isEmpty
    )
  }

  private static func summary(
    status: JobStatus,
    activeID: NodeID?,
    label: (NodeID) -> String,
    criticRound: Int,
    hasStages: Bool
  ) -> String {
    switch status {
    case .succeeded:
      return "已完成全部阶段"
    case .failed:
      return "\(label(activeID ?? .plan))阶段失败"
    default:
      guard let activeID else {
        return hasStages ? "生成中" : "排队中，等待开始"
      }
      if activeID == .critique, criticRound > 1 {
        return "\(label(activeID))中，第 \(criticRound) 轮"
      }
      return "\(label(activeID))中"
    }
  }
}
