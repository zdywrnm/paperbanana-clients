import SwiftUI

/// 全屏图片查看器（fullScreenCover + zoom 过渡的目标端）。
///
/// 栅格图：捏合 1x–4x、双击 1x/2x 切换、单击切换 chrome、
/// 缩放为 1x 时下滑超过阈值（位移 > 120pt 或快速甩动）关闭。
/// SVG：交给可缩放的 WKWebView（系统捏合手势），保留顶部 chrome。
struct ImageViewer: View {
  enum Content {
    case raster(URL)
    case svg(URL)
  }

  let content: Content
  let title: String
  /// 可分享的远端 URL（data: 等不可分享来源传 nil 则隐藏分享按钮）。
  var shareURL: URL?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var zoom: CGFloat = 1
  @GestureState private var pinchDelta: CGFloat = 1
  @State private var panOffset: CGSize = .zero
  @State private var dragTranslation: CGSize = .zero
  @State private var isChromeVisible = true
  /// 本轮手势序列里是否发生过捏合：1x 捏合的质心下移会同时喂给 drag，
  /// 一旦捏合参与就整轮抑制下滑关闭路径，drag 结束时复位。
  @State private var pinchedDuringDrag = false

  private static let dismissDistance: CGFloat = 120
  private static let dismissVelocity: CGFloat = 900
  /// 平移超界时的 rubber-band 阻尼系数（进行中允许小幅超界，松手钳制回弹）。
  private static let rubberBandDamping: CGFloat = 3

  /// 下滑关闭进度（0–1）：背景透明度与图片缩小量都从这里派生。
  private var dismissProgress: CGFloat {
    guard zoom <= 1.01 else { return 0 }
    return min(max(dragTranslation.height, 0) / 400, 1)
  }

  var body: some View {
    ZStack {
      Color.black
        .opacity(1 - dismissProgress * 0.5)
        .ignoresSafeArea()

      switch content {
      case .raster(let url):
        rasterViewer(url: url)
      case .svg(let url):
        SVGWebPreview(url: url, zoomable: true)
          .ignoresSafeArea(edges: .bottom)
          .accessibilityLabel("\(title) SVG 矢量图，可捏合缩放")
          .accessibilityAction(.escape) { dismiss() }
      }
    }
    .overlay(alignment: .top) {
      if isChromeVisible {
        chrome
          .transition(.opacity)
      }
    }
    .animation(Theme.Motion.stateChange, value: isChromeVisible)
    .statusBarHidden(!isChromeVisible)
  }

  // MARK: - 栅格图

  private func rasterViewer(url: URL) -> some View {
    GeometryReader { proxy in
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFit()
        case .failure:
          Image(systemName: "photo.badge.exclamationmark")
            .font(.largeTitle)
            .foregroundStyle(.white.opacity(0.6))
        default:
          ProgressView()
            .tint(.white)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .scaleEffect((zoom * pinchDelta) * (1 - dismissProgress * 0.15))
      .offset(
        x: panOffset.width + (zoom > 1.01 ? dragTranslation.width : 0),
        y: panOffset.height + dragTranslation.height
      )
      .gesture(magnification(containerSize: proxy.size))
      .simultaneousGesture(drag(containerSize: proxy.size))
      .onTapGesture(count: 2) { toggleDoubleTapZoom() }
      .onTapGesture { isChromeVisible.toggle() }
    }
    .accessibilityLabel(title)
    .accessibilityHint("可在转子操作中选择放大、还原，或用两指擦除手势关闭")
    .accessibilityAddTraits(.isImage)
    .accessibilityAction(named: "放大") {
      withAnimation(reduceMotion ? nil : Theme.Motion.stateChange) {
        zoom = min(zoom * 2, 4)
      }
    }
    .accessibilityAction(named: "还原") {
      withAnimation(reduceMotion ? nil : Theme.Motion.stateChange) {
        zoom = 1
        resetPan()
      }
    }
    .accessibilityAction(.escape) { dismiss() }
  }

  private func magnification(containerSize: CGSize) -> some Gesture {
    MagnifyGesture()
      .updating($pinchDelta) { value, state, _ in
        state = value.magnification
      }
      .onChanged { _ in
        // 捏合进行中：标记本轮手势序列，并清掉质心位移喂进来的下滑量。
        pinchedDuringDrag = true
        if zoom <= 1.01 { dragTranslation = .zero }
      }
      .onEnded { value in
        withAnimation(Theme.Motion.stateChange) {
          zoom = min(max(zoom * value.magnification, 1), 4)
          if zoom <= 1.01 {
            resetPan()
          } else {
            // 缩小后原 pan 可能超出新边界：立即钳回。
            panOffset = clampedPanOffset(panOffset, containerSize: containerSize)
          }
        }
      }
  }

  private func drag(containerSize: CGSize) -> some Gesture {
    DragGesture()
      .onChanged { value in
        if zoom > 1.01 {
          // 超界部分按阻尼跟随（rubber-band），松手时钳制回弹。
          let proposed = CGSize(
            width: panOffset.width + value.translation.width,
            height: panOffset.height + value.translation.height
          )
          let clamped = clampedPanOffset(proposed, containerSize: containerSize)
          dragTranslation = CGSize(
            width: clamped.width + (proposed.width - clamped.width) / Self.rubberBandDamping - panOffset.width,
            height: clamped.height + (proposed.height - clamped.height) / Self.rubberBandDamping - panOffset.height
          )
        } else if pinchedDuringDrag || pinchDelta != 1 {
          // 捏合进行/参与过的序列：质心位移不是下滑关闭意图。
          dragTranslation = .zero
        } else {
          // 1x 只跟随竖直方向（下滑关闭手势）。
          dragTranslation = CGSize(width: 0, height: max(0, value.translation.height))
        }
      }
      .onEnded { value in
        defer { pinchedDuringDrag = false }
        if zoom > 1.01 {
          let proposed = CGSize(
            width: panOffset.width + dragTranslation.width,
            height: panOffset.height + dragTranslation.height
          )
          withAnimation(Theme.Motion.playful) {
            panOffset = clampedPanOffset(proposed, containerSize: containerSize)
            dragTranslation = .zero
          }
        } else if !pinchedDuringDrag, pinchDelta == 1,
          dragTranslation.height > 0,
          value.translation.height > Self.dismissDistance
            || value.predictedEndTranslation.height - value.translation.height > Self.dismissVelocity / 4 {
          dismiss()
        } else {
          withAnimation(Theme.Motion.stateChange) {
            dragTranslation = .zero
          }
        }
      }
  }

  /// 把平移量钳制到缩放后图片能覆盖容器的范围内（scaledToFit 下以容器为图片外接框近似）。
  private func clampedPanOffset(_ offset: CGSize, containerSize: CGSize) -> CGSize {
    let maxX = max(0, (zoom - 1) * containerSize.width / 2)
    let maxY = max(0, (zoom - 1) * containerSize.height / 2)
    return CGSize(
      width: min(max(offset.width, -maxX), maxX),
      height: min(max(offset.height, -maxY), maxY)
    )
  }

  private func toggleDoubleTapZoom() {
    withAnimation(reduceMotion ? nil : Theme.Motion.stateChange) {
      if zoom > 1.01 {
        zoom = 1
        resetPan()
      } else {
        zoom = 2
      }
    }
  }

  private func resetPan() {
    panOffset = .zero
    dragTranslation = .zero
  }

  // MARK: - Chrome

  private var chrome: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.body.weight(.semibold))
          .frame(width: 44, height: 44)
      }
      .paperGlassButton()
      .buttonBorderShape(.circle)
      .accessibilityLabel("关闭查看器")

      Spacer()

      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)

      Spacer()

      if let shareURL {
        ShareLink(item: shareURL) {
          Image(systemName: "square.and.arrow.up")
            .font(.body.weight(.semibold))
            .frame(width: 44, height: 44)
        }
        .paperGlassButton()
        .buttonBorderShape(.circle)
        .accessibilityLabel("分享图片")
      } else {
        // 占位保持标题居中。
        Color.clear.frame(width: 44, height: 44)
      }
    }
    .padding(.horizontal, Theme.Spacing.lg)
    .padding(.top, Theme.Spacing.sm)
  }
}

#if DEBUG
#Preview("栅格查看器") {
  ImageViewer(
    content: .raster(URL(string: JobPreviewFixtures.sampleImageDataURL)!),
    title: "候选 1"
  )
}
#endif
