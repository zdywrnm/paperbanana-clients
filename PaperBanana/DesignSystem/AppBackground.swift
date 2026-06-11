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

  var body: some View {
    Group {
      if isGenerating && !reduceMotion {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
          mesh(at: context.date.timeIntervalSinceReferenceDate)
        }
      } else {
        mesh(at: nil)
      }
    }
    .ignoresSafeArea()
  }

  /// `time == nil` 表示静止布局（基准控制点）。
  private func mesh(at time: TimeInterval?) -> MeshGradient {
    var dx: Float = 0
    var dy: Float = 0
    var ex: Float = 0
    var ey: Float = 0
    if let time {
      let angle = time * 2 * .pi / Theme.Motion.backgroundDriftPeriod
      // 中心点画小圆，边中点沿各自边缘缓慢往复；幅度都很小。
      dx = Float(sin(angle)) * 0.05
      dy = Float(cos(angle)) * 0.05
      ex = Float(sin(angle * 0.5)) * 0.035
      ey = Float(cos(angle * 0.5)) * 0.035
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
