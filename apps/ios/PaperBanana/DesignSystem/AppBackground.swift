import SwiftUI

/// 全局画布背景：3×3 MeshGradient，保留品牌方向
/// （浅色 beige→white、深色 charcoal→olive），角点加入低饱和香蕉黄点缀。
///
/// 纯展示组件：不依赖任何 store，"是否生成中"由调用方传入。
/// 生成中时控制点缓慢漂移（周期 ~8s，幅度克制）；开启"减弱动态效果"时静止。
struct AppBackground: View {
  var isGenerating: Bool = false

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// 本轮漂移动画的起始时刻：相位从 0 起，而不是取 wall-clock 相位。
  /// 否则进入生成态的第一帧控制点就从基准布局突跳到任意相位（P4 遗留）。
  /// nil 表示静止（未生成 / 减弱动态效果），渲染基准控制点布局。
  @State private var driftStart: Date?

  private var shouldDrift: Bool { isGenerating && !reduceMotion }

  var body: some View {
    // 单一 TimelineView 保持视图身份稳定：进出生成态只改 driftStart，
    // MeshGradient 控制点在同一视图内插值，退出时经 Theme.Motion 平滑回到基准布局
    // 而不是分支切换的一帧突跳。
    TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: driftStart == nil)) { context in
      mesh(at: driftStart.map { max(0, context.date.timeIntervalSince($0)) })
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
    .onChange(of: shouldDrift, initial: true) { _, active in
      if active {
        // 入场：相位从 0 起，首帧与基准布局重合，无需动画。
        driftStart = Date()
      } else {
        withAnimation(reduceMotion ? nil : Theme.Motion.entrance) {
          driftStart = nil
        }
      }
    }
  }

  /// `time == nil` 表示静止布局（基准控制点）。
  private func mesh(at time: TimeInterval?) -> MeshGradient {
    var dx: Float = 0
    var dy: Float = 0
    var ex: Float = 0
    var ey: Float = 0
    if let time {
      let angle = time * 2 * .pi / Theme.Motion.backgroundDriftPeriod
      // 全部用 sin：t=0 时所有偏移为 0，与静止基准布局重合，
      // 进入生成态时从基准平滑启动而不是跳到任意相位。
      // 中心点走 ∞ 字形，边中点沿各自边缘缓慢往复；幅度都很小。
      dx = Float(sin(angle)) * 0.05
      dy = Float(sin(angle * 2)) * 0.03
      ex = Float(sin(angle * 0.5)) * 0.035
      ey = Float(sin(angle * 0.7)) * 0.035
    }
    return MeshGradient(
      width: 3,
      height: 3,
      points: [
        [0, 0], [0.5 + ex, 0], [1, 0],
        [0, 0.5 + ey], [0.5 + dx, 0.5 + dy], [1, 0.5 - ey],
        [0, 1], [0.5 - ex, 1], [1, 1]
      ],
      colors: colorScheme == .dark ? darkColors : lightColors
    )
  }

  /// 行优先（上→下）：左上白纸 → 右下 beige，左下/右下角带香蕉黄微光。
  private var lightColors: [Color] {
    [
      Theme.Palette.canvasPaper, Theme.Palette.canvasPaper, Theme.Palette.canvasMist,
      Theme.Palette.canvasPaper, Theme.Palette.canvasMist, Theme.Palette.canvasBeige,
      Theme.Palette.bananaGlowLight, Theme.Palette.canvasBeige, Theme.Palette.bananaGlowLight
    ]
  }

  /// 行优先（上→下）：左上 charcoal → 右下 olive/umber，底部角点香蕉黄微光。
  private var darkColors: [Color] {
    [
      Theme.Palette.canvasCharcoal, Theme.Palette.canvasCharcoal, Theme.Palette.canvasOlive,
      Theme.Palette.canvasCharcoal, Theme.Palette.canvasOlive, Theme.Palette.canvasUmber,
      Theme.Palette.bananaGlowDark, Theme.Palette.canvasUmber, Theme.Palette.bananaGlowDark
    ]
  }
}
