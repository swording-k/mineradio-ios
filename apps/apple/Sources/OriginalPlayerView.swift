import SwiftUI
import WebKit

struct OriginalPlayerView: UIViewRepresentable {
    let endpoint: URL
    @Binding var failure: String?
    var sessionToken: String? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.setURLSchemeHandler(BundledPlayerHandler(), forURLScheme: "mineradio-app")
        if let sessionToken, let tokenJSON = try? JSONSerialization.data(withJSONObject: [sessionToken]),
           let tokenText = String(data: tokenJSON, encoding: .utf8) {
            let script = """
            (() => {
              if (location.origin !== 'http://127.0.0.1:19363') return;
              const token = \(tokenText)[0], originalFetch = window.fetch.bind(window);
              window.fetch = (input, init) => {
                const request = new Request(input, init), url = new URL(request.url);
                if (url.origin === location.origin && url.pathname.startsWith('/api/')) {
                  const headers = new Headers(request.headers);
                  headers.set('X-Mineradio-Session', token);
                  return originalFetch(new Request(request, {headers}));
                }
                return originalFetch(request);
              };
            })();
            """
            config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
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
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.failure = nil
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--native-smoke"), webView.url?.host == "127.0.0.1" {
                webView.callAsyncJavaScript("""
                    const key = await fetch('/api/login/qr/key').then(r => r.json());
                    const results = await fetch('/api/search?keywords=Beethoven&limit=2').then(r => r.json());
                    return { origin: location.origin, qrKeyAvailable: !!key.key,
                             songCount: Array.isArray(results.songs) ? results.songs.length : 0 };
                    """, arguments: [:], in: nil, in: .page) { result in
                    let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("native-smoke.json")
                    if case .success(let value) = result,
                       let data = try? JSONSerialization.data(withJSONObject: value) { try? data.write(to: file) }
                    else { try? Data("{\"passed\":false}".utf8).write(to: file) }
                }
            }
            #endif
        }
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
