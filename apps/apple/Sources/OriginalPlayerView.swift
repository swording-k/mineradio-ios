import SwiftUI
import WebKit
import AVFAudio

struct OriginalPlayerView: UIViewRepresentable {
    let endpoint: URL
    @Binding var failure: String?
    var sessionToken: String? = nil
    var accountPresented = false
    var openAccount: ((String) async -> [String: Any])? = nil
    /// 原生播放状态中心；iPhone 上同时启用原生控制条。
    var nowPlaying: NowPlayingModel? = nil
    var nativeControlBar = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.ignoresViewportScaleLimits = false
        if openAccount != nil {
            config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleAccountLogin")
        }
        config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleAudioActivate")
        config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleDiagnostics")
        if nowPlaying != nil {
            config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleNowPlaying")
            if nativeControlBar {
                config.userContentController.addUserScript(WKUserScript(source: "window.__mineradioAppleNativeControls = true;",
                                                                        injectionTime: .atDocumentStart, forMainFrameOnly: true))
            }
        }
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
        // WebKit 不提供 navigator.deviceMemory，原版引擎因此无法识别低内存设备。
        // 在模块加载前提供真实物理内存（GB，取整），让原版 lowSpec 判定生效。
        let memoryGB = max(1, Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded()))
        config.userContentController.addUserScript(WKUserScript(source: """
            (() => { try { if (!('deviceMemory' in navigator)) Object.defineProperty(Navigator.prototype, 'deviceMemory', {configurable: true, get: () => \(memoryGB)}); } catch (_) {} })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--apple-power-smoke") {
            config.userContentController.addUserScript(WKUserScript(source: ApplePowerSmoke.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        if ProcessInfo.processInfo.arguments.contains("--apple-audio-smoke") {
            config.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "appleAudioProbe")
            config.userContentController.addUserScript(WKUserScript(source: ApplePlaybackSmoke.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        #endif
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--apple-layout-smoke") {
            let autoHidePrelude = ProcessInfo.processInfo.arguments.contains("--apple-controls-auto-hide-smoke") ? "window.__appleSmokeAutoHide=true;" : ""
            config.userContentController.addUserScript(WKUserScript(source: autoHidePrelude + AppleLayoutSmoke.script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        #endif
        config.allowsInlineMediaPlayback = true
        // Provider URLs resolve asynchronously after a tap. Audio must remain
        // playable after that await; video retains WebKit's gesture requirement.
        config.mediaTypesRequiringUserActionForPlayback = [.video]
        let view = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = view
        nowPlaying?.send = { [weak view] name, value in
            guard let view, let data = try? JSONSerialization.data(withJSONObject: [name, value ?? NSNull()]),
                  let args = String(data: data, encoding: .utf8) else { return }
            view.evaluateJavaScript("window.__mineradioAppleCommand && window.__mineradioAppleCommand.apply(null, \(args))", completionHandler: nil)
        }
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.contentInsetAdjustmentBehavior = .never
        // Scene pinch is handled by the Apple pointer bridge. Viewport limits prevent
        // page zoom from scaling/moving every HUD target along with the visual stage.
        // This does not disable iOS's system accessibility Zoom.
        view.scrollView.bouncesZoom = false
        view.load(URLRequest(url: endpoint, timeoutInterval: 20))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateAccountPresentation(view)
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandlerWithReply {
        var parent: OriginalPlayerView
        private var presentedState: Bool?
        private var memoryWarning: NSObjectProtocol?
        weak var webView: WKWebView?
        /// 当前内存压力档位（0-3），WebContent 重启后据此恢复，避免重启后立刻再次爆内存。
        private var pressureLevel = 0
        private var recoveries: [Date] = []
        init(_ parent: OriginalPlayerView) {
            self.parent = parent
            super.init()
            AppleDiagnostics.shared.recordNative("view-created")
            memoryWarning = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    AppleDiagnostics.shared.recordNative("memory-warning")
                    self?.relieveMemoryPressure()
                }
            }
        }
        /// 把系统内存警告转交给原版引擎：逐级降低内部渲染分辨率并深度裁剪缓存（apple-memory.js）。
        private func relieveMemoryPressure() {
            webView?.evaluateJavaScript("window.__mineradioAppleMemoryPressure ? window.__mineradioAppleMemoryPressure('warning').level : -1") { [weak self] result, _ in
                Task { @MainActor in
                    if let level = result as? Int, level >= 0 { self?.pressureLevel = max(self?.pressureLevel ?? 0, level) }
                }
            }
        }
        deinit { if let memoryWarning { NotificationCenter.default.removeObserver(memoryWarning) } }
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
            if message.name == "appleDiagnostics", let input = message.body as? [String: Any] {
                AppleDiagnostics.shared.recordWeb(input)
                replyHandler(["recorded": true], nil); return
            }
            if message.name == "appleNowPlaying", let input = message.body as? [String: Any] {
                parent.nowPlaying?.receive(input)
                replyHandler(nil, nil); return
            }
            if message.name == "appleAudioActivate" {
                Task { @MainActor in
                    do {
                        try await AppleAudioActivation.shared.activate()
                        replyHandler(["active": true], nil)
                    } catch { replyHandler(nil, "音频会话启动失败：" + error.localizedDescription) }
                }
                return
            }
            guard message.name == "appleAccountLogin", let input = message.body as? [String: Any],
                  let provider = input["provider"] as? String, provider == "spotify" || OfficialLoginPolicy.entry(provider) != nil,
                  let open = parent.openAccount else { replyHandler(nil, "Unsupported login request"); return }
            Task { @MainActor in replyHandler(await open(provider), nil) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            AppleDiagnostics.shared.recordNative("page-loaded")
            // WebKit may configure its scroll recognizers while loading the page.
            webView.scrollView.bouncesZoom = false
            parent.failure = nil
            updateAccountPresentation(webView, force: true)
            if pressureLevel > 0 {
                webView.evaluateJavaScript("window.__mineradioAppleMemoryPressure && window.__mineradioAppleMemoryPressure('restore', \(pressureLevel))", completionHandler: nil)
            }
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
            AppleDiagnostics.shared.recordNative("webcontent-terminated")
            // 页面进程被系统回收时自动恢复，而不是停在黑屏/错误页。
            // 每次恢复提高一档内存压力；3 分钟内连续 3 次才交给用户手动重试，防止无限重启。
            let now = Date()
            recoveries = recoveries.filter { now.timeIntervalSince($0) < 180 } + [now]
            pressureLevel = min(3, pressureLevel + 1)
            if recoveries.count <= 2 {
                webView.reload()
            } else {
                parent.failure = "播放器页面多次被系统回收（内存不足）。请点重试；建议在视觉控制台降低画质档位。"
            }
        }
        private func report(_ error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                AppleDiagnostics.shared.recordNative("page-load-failed")
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
