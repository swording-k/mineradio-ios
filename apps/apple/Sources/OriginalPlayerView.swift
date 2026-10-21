import SwiftUI
import WebKit
import AVFAudio

struct OriginalPlayerView: UIViewRepresentable {
    let endpoint: URL
    @Binding var failure: String?
    var sessionToken: String? = nil
    var accountPresented = false
    var openAccount: ((String) async -> [String: Any])? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        if openAccount != nil {
            config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleAccountLogin")
        }
        config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleAudioActivate")
        config.setURLSchemeHandler(BundledPlayerHandler(), forURLScheme: "mineradio-app")
        if let sessionToken, let tokenJSON = try? JSONSerialization.data(withJSONObject: [sessionToken]),
           let tokenText = String(data: tokenJSON, encoding: .utf8) {
            let targetOrigin = "\(endpoint.scheme ?? "")://\(endpoint.host ?? "")" + (endpoint.port.map { ":\($0)" } ?? "")
            let originData = try! JSONSerialization.data(withJSONObject: [targetOrigin])
            let originText = String(decoding: originData, as: UTF8.self)
            let script = """
            (() => {
              if (location.origin !== \(originText)[0]) return;
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
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--apple-audio-smoke") {
            config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleAudioProbe")
            config.userContentController.addUserScript(WKUserScript(source: ApplePlaybackSmoke.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        #endif
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--apple-layout-smoke") {
            config.userContentController.addUserScript(WKUserScript(source: AppleLayoutSmoke.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        #endif
        config.allowsInlineMediaPlayback = true
        // Provider URLs resolve asynchronously after a tap. Audio must remain
        // playable after that await; video retains WebKit's gesture requirement.
        config.mediaTypesRequiringUserActionForPlayback = [.video]
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

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateAccountPresentation(view)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandlerWithReply {
        var parent: OriginalPlayerView
        private var presentedState: Bool?
        init(_ parent: OriginalPlayerView) { self.parent = parent }
        func updateAccountPresentation(_ view: WKWebView, force: Bool = false) {
            guard force || presentedState != parent.accountPresented else { return }
            presentedState = parent.accountPresented
            view.evaluateJavaScript("window.__mineradioAppleSetAuthPresentation && window.__mineradioAppleSetAuthPresentation(\(parent.accountPresented ? "true" : "false"))", completionHandler: nil)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                                   replyHandler: @escaping (Any?, String?) -> Void) {
            guard message.frameInfo.isMainFrame,
                  let url = message.frameInfo.request.url, url.scheme == "http", url.host == "127.0.0.1", url.port == parent.endpoint.port else {
                replyHandler(nil, "Unsupported origin"); return
            }
            #if DEBUG && targetEnvironment(simulator)
            if message.name == "appleAudioProbe", let body = message.body as? [String: Any] {
                let report = body.filter { ["state", "mediaTime", "signal", "error"].contains($0.key) }
                if let bytes = try? JSONSerialization.data(withJSONObject: report),
                   let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? bytes.write(to: root.appendingPathComponent("apple-audio-probe.json"))
                }
                replyHandler(["recorded": true], nil); return
            }
            #endif
            if message.name == "appleAudioActivate" {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .default)
                    try session.setActive(true)
                    replyHandler(["active": true], nil)
                } catch { replyHandler(nil, "音频会话启动失败：" + error.localizedDescription) }
                return
            }
            guard message.name == "appleAccountLogin", let input = message.body as? [String: Any],
                  let provider = input["provider"] as? String, OfficialLoginPolicy.entry(provider) != nil,
                  let open = parent.openAccount else { replyHandler(nil, "Unsupported login request"); return }
            Task { @MainActor in replyHandler(await open(provider), nil) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.failure = nil
            updateAccountPresentation(webView, force: true)
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
                parent.failure = "设备内播放器页面加载失败，请重试。\n" + error.localizedDescription
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
