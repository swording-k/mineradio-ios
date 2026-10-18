import SwiftUI
import WebKit

struct OriginalPlayerView: UIViewRepresentable {
    let endpoint: URL
    @Binding var failure: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.setURLSchemeHandler(BundledPlayerHandler(), forURLScheme: "mineradio-app")
        config.allowsInlineMediaPlayback = true
        // Keep playback gesture-gated; do not start audio just by opening the app.
        config.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.load(URLRequest(url: endpoint, timeoutInterval: 20))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.parent = self }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: OriginalPlayerView
        init(_ parent: OriginalPlayerView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.failure = nil }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.failure = "页面进程已退出。请重试；如重复发生，需要降低动效资源占用。"
        }
        private func report(_ error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                parent.failure = "请确认开发服务已启动、设备网络可达并允许本地网络访问。\n" + error.localizedDescription
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            guard ["http", "https", "about", "blob", "mineradio-app"].contains(url.scheme ?? "") else { decisionHandler(.cancel); return }
            if action.navigationType == .linkActivated, action.targetFrame?.isMainFrame != false,
               url.host != parent.endpoint.host {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url, ["http", "https"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
            return nil
        }
    }
}
