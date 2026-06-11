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

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
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
