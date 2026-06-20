import SwiftUI
import WebKit

struct SVGPreviewCard: View {
  let url: URL?

  var body: some View {
    Group {
      if let url {
        GeometryReader { proxy in
          SVGWebPreview(url: url)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
      } else {
        Label("SVG 矢量图", systemImage: "doc.richtext")
      }
    }
    .aspectRatio(4 / 3, contentMode: .fit)
    .frame(maxWidth: .infinity, minHeight: 140)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .accessibilityLabel("SVG 矢量图预览")
  }
}

struct SVGWebPreview: UIViewRepresentable {
  let url: URL
  /// 全屏查看器模式：开启滚动与捏合缩放（内联缩略图保持静态）。
  var zoomable = false

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    if zoomable {
      configuration.ignoresViewportScaleLimits = true
    }

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = zoomable
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    if zoomable {
      webView.scrollView.minimumZoomScale = 1
      webView.scrollView.maximumZoomScale = 4
      webView.scrollView.bouncesZoom = true
    }
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    guard context.coordinator.lastURL != url else { return }
    context.coordinator.lastURL = url
    webView.load(URLRequest(url: url))
  }

  final class Coordinator {
    var lastURL: URL?
  }
}
