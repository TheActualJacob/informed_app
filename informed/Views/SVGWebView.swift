import SwiftUI
import WebKit

/// A read-only WKWebView that renders an SVG string.
/// JavaScript is disabled, scrolling is disabled, and navigation is blocked.
struct SVGWebView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; }
        body { background: transparent; }
        svg { width: 100% !important; height: auto !important; display: block; max-width: 100%; }
        </style>
        </head>
        <body>\(sanitizedSVG(svg))</body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// Remove explicit width/height attributes from the <svg> opening tag so the
    /// CSS width:100%/height:auto controls sizing correctly in WKWebView.
    private func sanitizedSVG(_ raw: String) -> String {
        guard let tagRange = raw.range(of: #"<svg[^>]*>"#, options: .regularExpression) else {
            return raw
        }
        var tag = String(raw[tagRange])
        tag = tag.replacingOccurrences(of: #"\s*width="[^"]*""#, with: "", options: .regularExpression)
        tag = tag.replacingOccurrences(of: #"\s*height="[^"]*""#, with: "", options: .regularExpression)
        return raw.replacingCharacters(in: tagRange, with: tag)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        /// Block all navigation — the diagram is read-only.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .other {
                decisionHandler(.allow) // Allow initial HTML load
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}
