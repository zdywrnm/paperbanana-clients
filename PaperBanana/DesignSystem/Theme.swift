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
    /// 系统控件 tint 走 Assets 的 AccentColor（浅 #8F6D12 / 深 #F5CC57，带高对比变体），
    /// 与这里同一品牌方向；视图代码引用品牌色仍用本 token，不要直接写 Color.accentColor。
    static let banana = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.96, green: 0.80, blue: 0.34, alpha: 1) // ≈ #F5CC57
        : UIColor(red: 0.90, green: 0.71, blue: 0.22, alpha: 1) // ≈ #E6B538
    })

    /// 香蕉黄的小字版本：浅色界面亮黄对白底只有 ~1.9:1，小字（caption 级）必须用
    /// 深 ochre 保证 ≥4.5:1；深色界面沿用亮黄。底色 / 图形仍用 `banana`。
    static let bananaText = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.96, green: 0.80, blue: 0.34, alpha: 1) // ≈ #F5CC57
        : UIColor(red: 0.48, green: 0.36, blue: 0.06, alpha: 1) // ≈ #7A5C0F 深 ochre
    })

    /// 警示色（轮询中断等非致命异常）。
    static let warning = Color.orange

    /// 警示色的小字版本：系统橙对白底只有 ~2.2:1，小字（caption 级）浅色界面用
    /// 加深的橙棕（#9A4A00，对白底 6.3:1），深色界面用亮橙保证深底对比。
    /// 底色 / 图形仍用 `warning`。
    static let warningText = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 1.00, green: 0.70, blue: 0.25, alpha: 1) // ≈ #FFB340 亮橙
        : UIColor(red: 0.60, green: 0.29, blue: 0.00, alpha: 1) // ≈ #9A4A00 橙棕
    })

    /// 小程序纸感 UI 的墨绿主色。用于主要操作、选中态、登录态、反馈 FAB。
    static let paperGreen = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.47, green: 0.72, blue: 0.63, alpha: 1) // ≈ #78B8A1
        : UIColor(red: 0.19, green: 0.37, blue: 0.32, alpha: 1) // ≈ #315F51
    })

    /// 墨绿小字版本：浅色同主色，深色稍提亮以保证玻璃/深底对比。
    static let paperGreenText = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.65, green: 0.84, blue: 0.76, alpha: 1) // ≈ #A6D6C2
        : UIColor(red: 0.16, green: 0.31, blue: 0.26, alpha: 1) // ≈ #284F43
    })

    /// 纸感卡片内的暖灰井底，用于替代小程序 field/picker-value。
    static let paperWell = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.13, green: 0.15, blue: 0.14, alpha: 0.72)
        : UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 0.82) // ≈ #F3F2EC
    })

    /// 小程序式纸面卡片底色：保留足够不透明度，让信息结构稳定，但仍允许 Liquid Glass 参与折射。
    static let paperPanel = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.08, green: 0.10, blue: 0.09, alpha: 0.84)
        : UIColor(red: 1.00, green: 1.00, blue: 0.98, alpha: 0.94) // ≈ #FFFFFB
    })

    /// 小程序纸面细边框。
    static let paperBorder = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.35, green: 0.38, blue: 0.34, alpha: 0.44)
        : UIColor(red: 0.85, green: 0.84, blue: 0.80, alpha: 1) // ≈ #D9D6CC
    })

    /// 轻量次级操作底色。
    static let paperGreenWell = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.15, green: 0.25, blue: 0.21, alpha: 0.78)
        : UIColor(red: 0.93, green: 0.96, blue: 0.94, alpha: 1) // ≈ #EDF6EF
    })

    /// 小程序提示色，保留琥珀而不把品牌整体推成单一黄色。
    static let paperAmber = Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.72, green: 0.55, blue: 0.18, alpha: 1)
        : UIColor(red: 0.93, green: 0.79, blue: 0.40, alpha: 1) // ≈ #EAD28D
    })

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

    /// JobStatus → 小字前景色：running 用 `bananaText`（浅色亮黄小字对比不足），其余同 tint。
    static func textTint(for status: JobStatus) -> Color {
      status == .running ? bananaText : tint(for: status)
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
