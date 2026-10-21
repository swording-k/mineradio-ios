import SwiftUI
import WebKit

/// Uses the same official login entry points as desktop, with native-only cookies.
@MainActor final class OfficialAccountLogin: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
    struct Ticket: Identifiable { let id = UUID(); let provider: String }
    @Published private(set) var ticket: Ticket?
    @Published private(set) var webView: WKWebView?
    @Published private(set) var popup: WKWebView?
    @Published private(set) var message = "请在官方页面完成登录。"
    @Published private(set) var verifying = false
    @Published private(set) var pageReady = false
    @Published private(set) var entryReady = false
    private var continuation: CheckedContinuation<[String: Any], Never>?
    private var verifier: ((String, [HTTPCookie]) async throws -> [String: Any])?
    private var checkTask: Task<Void, Never>?
    private var lastAttempt = Date.distantPast
    private var traceEntries: [[String: String]] = []
    private var observedStores: [WKHTTPCookieStore] = []

    private func trace(_ event: String, url: URL? = nil, code: Int? = nil) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--apple-official-login-smoke"), let provider = ticket?.provider else { return }
        var item = ["event": event]
        if let url { item["scheme"] = url.scheme ?? ""; item["host"] = url.host ?? ""; item["path"] = url.path }
        if let code { item["code"] = String(code) }
        traceEntries.append(item); traceEntries = Array(traceEntries.suffix(100))
        if let data = try? JSONSerialization.data(withJSONObject: traceEntries), let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: root.appendingPathComponent("official-\(provider)-diagnostics.json"))
        }
        #endif
    }
    func open(_ provider: String, verify: @escaping (String, [HTTPCookie]) async throws -> [String: Any]) async -> [String: Any] {
        guard let url = OfficialLoginPolicy.entry(provider), ticket == nil else {
            return ["loggedIn": false, "message": "登录窗口正在使用中或平台不受支持。"]
        }
        let ticket = Ticket(provider: provider)
        verifier = verify; self.ticket = ticket
        pageReady = false; entryReady = false
        message = "请在官方页面打开登录，扫码或按平台支持的方式授权。"; lastAttempt = .distantPast
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = self; web.uiDelegate = self
        webView = web; observe(configuration.websiteDataStore.httpCookieStore)
        return await withCheckedContinuation { pending in
            continuation = pending
            web.load(URLRequest(url: url))
        }
    }
    func cancel() { finish(["loggedIn": false, "cancelled": true, "message": "已取消登录。"] ) }
    func closePopup() {
        popup?.stopLoading(); popup?.navigationDelegate = nil; popup?.uiDelegate = nil; popup = nil
    }
    func check(force: Bool = false) {
        guard let ticket, !verifying, force || Date().timeIntervalSince(lastAttempt) > 1 else { return }
        checkTask?.cancel()
        checkTask = Task { @MainActor [weak self] in
            guard let self, let store = self.webView?.configuration.websiteDataStore.httpCookieStore else { return }
            let cookies = await store.allCookies()
            guard self.ticket?.id == ticket.id, !Task.isCancelled else { return }
            let relevant = OfficialLoginPolicy.cookies(cookies, provider: ticket.provider)
            guard !relevant.isEmpty, let verify = self.verifier else { return }
            self.verifying = true; self.lastAttempt = Date()
            defer { self.verifying = false }
            do {
                let status = try await verify(ticket.provider, relevant)
                guard self.ticket?.id == ticket.id, !Task.isCancelled else { return }
                if status["loggedIn"] as? Bool == true { self.finish(status) }
                else if force { self.message = status["message"] as? String ?? "尚未取得有效音乐账号，请完成官方页面授权后再验证。" }
            } catch {
                guard self.ticket?.id == ticket.id else { return }
                if force { self.message = "账号验证未通过，请稍后重试。" }
            }
        }
    }
    private func observe(_ store: WKHTTPCookieStore) {
        guard !observedStores.contains(where: { $0 === store }) else { return }
        store.add(self); observedStores.append(store)
    }
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) { check() }
    private func finish(_ result: [String: Any]) {
        checkTask?.cancel(); checkTask = nil
        observedStores.forEach { $0.remove(self) }; observedStores = []
        for web in [webView, popup].compactMap({ $0 }) {
            web.stopLoading(); web.navigationDelegate = nil; web.uiDelegate = nil
        }
        popup = nil; webView = nil; ticket = nil; verifier = nil
        let pending = continuation; continuation = nil; pending?.resume(returning: result)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let provider = ticket?.provider, let url = action.request.url else { decisionHandler(.cancel); return }
        // about:blank is used for official OAuth popup bootstrap, never as a network destination.
        let allowed = url.absoluteString == "about:blank" || OfficialLoginPolicy.allows(url, provider: provider)
        trace(allowed ? "navigation-allowed" : "navigation-denied", url: url)
        decisionHandler(allowed ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let provider = ticket?.provider, let url = action.request.url,
              url.absoluteString == "about:blank" || OfficialLoginPolicy.allows(url, provider: provider) else { return nil }
        closePopup()
        let child = WKWebView(frame: .zero, configuration: configuration)
        child.navigationDelegate = self; child.uiDelegate = self
        observe(configuration.websiteDataStore.httpCookieStore); popup = child
        return child
    }
    func webViewDidClose(_ webView: WKWebView) { if webView === popup { closePopup(); check(force: true) } }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        trace("page-finished", url: webView.url)
        if let provider = ticket?.provider, let url = webView.url, OfficialLoginPolicy.allows(url, provider: provider) { pageReady = true }
        check()
        // Reuse desktop's login-entry discovery; do not click authorization/consent.
        guard webView === self.webView, let url = webView.url,
              url.host == "y.qq.com" || url.host == "www.kugou.com" else { return }
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            let opened = try? await webView.callAsyncJavaScript("""
                const visible = node => { const r = node.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
                const loginVisible = () => Array.from(document.querySelectorAll('iframe')).some(frame => visible(frame) && /login|ptlogin|passport/i.test(frame.src)) ||
                    /扫码登录|账号密码登录|验证码登录|二维码登录/.test(document.body.innerText || '');
                let clicked = false;
                for (let attempt = 0; attempt < 60; attempt++) {
                    if (loginVisible()) return true;
                    if (!clicked) {
                        const exact = document.querySelector('.cmhead1_d5._login');
                        const nodes = Array.from(document.querySelectorAll('a,button,span,div'));
                        const entry = exact && visible(exact) ? exact : nodes.find(node => {
                            const text = (node.textContent || '').replace(/\\s/g, '');
                            return /^(立即)?登[录陆]$/.test(text) && visible(node);
                        });
                        if (entry) { entry.click(); clicked = true; }
                    }
                    await new Promise(resolve => setTimeout(resolve, 250));
                }
                return false;
                """, arguments: [:], in: nil, contentWorld: .page)
            guard self.webView === webView, self.ticket != nil else { return }
            self.entryReady = opened as? Bool == true
            if !self.entryReady { self.message = "官方页面已加载。若登录面板尚未出现，请点击页面内的登录入口。" }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        trace("page-load-error", url: webView.url, code: (error as NSError).code)
        if (error as NSError).code != NSURLErrorCancelled { message = "官方登录页未能加载，请检查网络后重试。" }
    }
    func reload() { (popup ?? webView)?.reload() }
}

private struct OfficialLoginWebView: UIViewRepresentable {
    let view: WKWebView
    let width: CGFloat
    func makeUIView(context: Context) -> WKWebView { view.pageZoom = max(0.3, min(1, width / 1280)); return view }
    func updateUIView(_ uiView: WKWebView, context: Context) { uiView.pageZoom = max(0.3, min(1, width / 1280)) }
}
struct OfficialAccountLoginSheet: View {
    @ObservedObject var login: OfficialAccountLogin
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(login.entryReady ? "官方登录入口已打开" : (login.pageReady ? "正在打开官方登录入口…" : "正在加载官方登录页…")).font(.caption).accessibilityIdentifier("official-page-state")
                Text(login.message).font(.footnote).frame(maxWidth: .infinity, alignment: .leading).padding()
                if let web = login.popup ?? login.webView { GeometryReader { geometry in OfficialLoginWebView(view: web, width: geometry.size.width).id(ObjectIdentifier(web)) } }
                else { ProgressView().frame(maxHeight: .infinity) }
            }
            .navigationTitle(login.ticket?.provider == "qq" ? "QQ 音乐官方登录" : "酷狗音乐官方登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { login.cancel() } }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("刷新") { login.reload() }
                    Button("完成并验证") { login.check(force: true) }.disabled(login.verifying)
                }
            }
        }.interactiveDismissDisabled()
    }
}
