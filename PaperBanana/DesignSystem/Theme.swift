import SwiftUI
import UIKit

/// 全局设计 token：间距 / 圆角 / 动画 / 色板。
/// 所有 UI 数值常量集中在这里，feature 页面逐步迁移（Phase 5）。
enum Theme {
  // MARK: - 间距

  enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
  }

  // MARK: - 圆角

  /// 胶囊（pill）不在这里定义半径——直接用 `Capsule` / `.capsule` 形状。
  enum Radius {
    static let card: CGFloat = 22
    static let control: CGFloat = 14
  }

  // MARK: - 动画

  /// 动画一律取 Motion 语义常量，不要在 feature 代码手写 .spring/.easeInOut。
  enum Motion {
    /// 状态切换（选中、展开、内容替换）。
    static let stateChange: Animation = .snappy
    /// 元素入场 / 出场。
    static let entrance: Animation = .smooth
    /// 强调性反馈（成功、完成庆祝）。
    static let playful: Animation = .bouncy(extraBounce: 0.1)
    /// 背景 mesh 漂移一圈的周期（秒）。
    static let backgroundDriftPeriod: TimeInterval = 8
    /// 流水线 active 节点呼吸脉冲一个来回的周期（秒）。
    static let pulsePeriod: TimeInterval = 1.6
    /// 流水线 active 节点脉冲的单程曲线（半个周期）。
    static let pulseSegment: Animation = .easeInOut(duration: pulsePeriod / 2)
    /// 流水线连接线渐变流动一圈的周期（秒）。
    static let flowPeriod: TimeInterval = 2
  }

  // MARK: - 色板

  enum Palette {
    /// 品牌香蕉黄：浅色界面用偏深的金黄保证对比，深色界面用亮黄。
    static let banana = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.96, green: 0.80, blue: 0.34, alpha: 1) // ≈ #F5CC57
        : UIColor(red: 0.90, green: 0.71, blue: 0.22, alpha: 1) // ≈ #E6B538
    })

    /// 警示色（轮询中断等非致命异常）。
    static let warning = Color.orange

    /// JobStatus → 语义 tint 映射。
    static func tint(for status: JobStatus) -> Color {
      switch status {
      case .queued: .blue
      case .running: banana
      case .succeeded: .green
      case .failed: .red
      case .unknown: .gray
      }
    }

    // MARK: 背景画布色（AppBackground MeshGradient 专用）

    // 浅色：beige → white 品牌方向
    static let canvasPaper = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let canvasMist = Color(red: 0.95, green: 0.98, blue: 0.98)
    static let canvasBeige = Color(red: 1.00, green: 0.97, blue: 0.88)
    /// 低饱和香蕉黄角点点缀（浅色）。
    static let bananaGlowLight = Color(red: 0.99, green: 0.94, blue: 0.78)

    // 深色：charcoal → olive 品牌方向
    static let canvasCharcoal = Color(red: 0.04, green: 0.05, blue: 0.05)
    static let canvasOlive = Color(red: 0.10, green: 0.15, blue: 0.14)
    static let canvasUmber = Color(red: 0.15, green: 0.13, blue: 0.08)
    /// 低饱和香蕉黄角点点缀（深色）。
    static let bananaGlowDark = Color(red: 0.22, green: 0.18, blue: 0.09)
  }
}
