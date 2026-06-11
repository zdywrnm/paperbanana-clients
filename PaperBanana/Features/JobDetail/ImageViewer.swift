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

  private static let dismissDistance: CGFloat = 120
  private static let dismissVelocity: CGFloat = 900

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
      .gesture(magnification)
      .simultaneousGesture(drag)
      .onTapGesture(count: 2) { toggleDoubleTapZoom() }
      .onTapGesture { isChromeVisible.toggle() }
    }
    .accessibilityLabel(title)
    .accessibilityHint("双击放大或还原，向下轻扫关闭")
    .accessibilityAddTraits(.isImage)
  }

  private var magnification: some Gesture {
    MagnifyGesture()
      .updating($pinchDelta) { value, state, _ in
        state = value.magnification
      }
      .onEnded { value in
        withAnimation(Theme.Motion.stateChange) {
          zoom = min(max(zoom * value.magnification, 1), 4)
          if zoom <= 1.01 { resetPan() }
        }
      }
  }

  private var drag: some Gesture {
    DragGesture()
      .onChanged { value in
        if zoom > 1.01 {
          dragTranslation = value.translation
        } else {
          // 1x 只跟随竖直方向（下滑关闭手势）。
          dragTranslation = CGSize(width: 0, height: max(0, value.translation.height))
        }
      }
      .onEnded { value in
        if zoom > 1.01 {
          panOffset.width += value.translation.width
          panOffset.height += value.translation.height
          dragTranslation = .zero
        } else if value.translation.height > Self.dismissDistance
          || value.predictedEndTranslation.height - value.translation.height > Self.dismissVelocity / 4 {
          dismiss()
        } else {
          withAnimation(Theme.Motion.stateChange) {
            dragTranslation = .zero
          }
        }
      }
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
