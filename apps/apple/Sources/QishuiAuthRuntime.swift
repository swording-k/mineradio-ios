import Foundation
import WebKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import CryptoKit
import Security

/// Experimental isolated Passport runtime. It deliberately does not report a
/// complete account connection before a catalogue adapter validates identity.
@MainActor final class QishuiAuthRuntime: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private(set) var diagnostics: [String: Any] = [:]
    private let assets: URL
    private let bridge: URL
    private var webView: WKWebView?
    private var initialized = false
    private var initializing: Task<Void, Error>?
    private var navigationFailure = false
    private var generation = 0
    private var activeToken = ""
    private var msToken = ""
    private var browserInfo = ""
    private var cookies: [String: String] = [:]
    private var inFlight = 0
    private var jobs: [String: Task<Void, Never>] = [:]
    private let identityKey = "com.swordingk.mineradio.qishui.apple.identity"
    private let cookieService = "com.swordingk.mineradio.qishui.apple.passport"
    private let requestSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: QishuiNoRedirect(), delegateQueue: nil)
    }()

    init(assets: URL? = nil, bridge: URL? = nil) {
        self.assets = assets ?? Bundle.main.resourceURL!.appendingPathComponent("qishui-auth-v6")
        self.bridge = bridge ?? Bundle.main.resourceURL!.appendingPathComponent("QishuiWeb/qishui-xhr-bridge.js")
        super.init()
        var saved: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: cookieService,
            kSecAttrAccount as String: "session", kSecReturnData as String: true]
        if SecItemCopyMatching(query as CFDictionary, &saved) == errSecSuccess, let data = saved as? Data {
            cookies = (try? JSONSerialization.jsonObject(with: data) as? [String: String]) ?? [:]
        }
    }
    private var cookieReady: Bool { ["sessionid", "sessionid_ss", "sid_guard", "sid_tt"].contains { !(cookies[$0] ?? "").isEmpty } }
    // Native adapter handoff only; never sent to either player or signer JavaScript.
    func sessionSnapshot() -> [String: String] { cookies }
    func status() -> [String: Any] {
        ["provider": "qishui", "loggedIn": false, "cookieReady": cookieReady, "configured": true,
         "status": cookieReady ? "verifying" : "not_connected", "membershipKnown": false,
         "supported": true, "loginPrototype": true, "libraryReady": false,
         "message": cookieReady ? "已保存扫码会话，Apple 账号与曲库验证尚未完成。" : "请使用抖音 App 扫码；Apple 汽水登录仍处于适配验证阶段。"]
    }
    func createQrCode() async throws -> [String: Any] {
        generation += 1; let expected = generation; activeToken = ""
        try await initialize()
        let result = try await request("GET", path: "/passport/web/get_qrcode/", params: ["next": "https://api.qishui.com", "need_logo": "false", "need_short_url": "false"])
        guard expected == generation else { throw Failure.replaced }
        let data = result["data"] as? [String: Any] ?? [:]
        diagnostics["providerCode"] = data["error_code"] ?? -1
        diagnostics["tokenPresent"] = !(data["token"] as? String ?? "").isEmpty
        diagnostics["indexHost"] = URLComponents(string: data["qrcode_index_url"] as? String ?? "")?.host ?? ""
        guard result["message"] as? String == "success", (data["error_code"] as? NSNumber)?.intValue == 0,
              let token = data["token"] as? String, !token.isEmpty, token.count <= 2048,
              let index = data["qrcode_index_url"] as? String,
              let scan = QishuiAuthContract.scanURL(index) else { throw Failure.invalidResponse }
        let qr = try Self.qrImage(scan.absoluteString)
        activeToken = token
        return ["provider": "qishui", "token": token, "qrcode": qr, "qrcodeIndexUrl": index,
                "expireTime": data["expire_time"] ?? 0, "message": "请使用抖音 App 扫码并确认登录"]
    }
    func checkQrCode(_ token: String) async throws -> [String: Any] {
        guard !token.isEmpty, token == activeToken else { return ["provider": "qishui", "loggedIn": false, "status": "expired", "errorCode": 2] }
        let expected = generation
        let result = try await request("POST", path: "/passport/web/check_qrconnect/", body: ["need_logo": "false", "need_short_url": "false", "is_frontier": "true", "token": token, "is_new_login": "1", "next": "https://api.qishui.com"])
        guard expected == generation, token == activeToken else { throw Failure.replaced }
        return QishuiAuthContract.poll(result["data"] as? [String: Any] ?? [:], cookieReady: cookieReady)
    }
    func releaseSigningEnvironment() {
        generation += 1; activeToken = ""; initialized = false
        initializing?.cancel(); initializing = nil
        jobs.values.forEach { $0.cancel() }; jobs.removeAll()
        webView?.stopLoading(); webView?.configuration.userContentController.removeScriptMessageHandler(forName: "qishuiRequest")
        webView?.navigationDelegate = nil; webView = nil
        msToken = ""; browserInfo = ""
    }
    func logout() async throws -> [String: Any] {
        releaseSigningEnvironment()
        cookies = [:]
        let code = SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: cookieService, kSecAttrAccount as String: "session"] as CFDictionary)
        guard code == errSecSuccess || code == errSecItemNotFound else { throw Failure.keychain }
        return status()
    }
    private func identity() -> [String: String] {
        var result = UserDefaults.standard.dictionary(forKey: identityKey) as? [String: String] ?? [:]
        if result["deviceId"] == nil { result["deviceId"] = String(Int.random(in: 1000000000000000...8999999999999999)) }
        if result["installId"] == nil { result["installId"] = String(Int.random(in: 100000000000000...899999999999999)) }
        if result["portrait"] == nil { result["portrait"] = UUID().uuidString + ".login" }
        UserDefaults.standard.set(result, forKey: identityKey)
        return result
    }
    private func initialize() async throws {
        if initialized { return }
        if let initializing { return try await initializing.value }
        let task = Task { @MainActor in try await self.prepareWebView() }
        initializing = task
        defer { initializing = nil }
        do { try await task.value }
        catch {
            webView?.stopLoading()
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "qishuiRequest")
            webView?.navigationDelegate = nil; webView = nil; initialized = false
            throw error
        }
    }
    private func prepareWebView() async throws {
        guard FileManager.default.fileExists(atPath: assets.appendingPathComponent("security_host.html").path), FileManager.default.fileExists(atPath: bridge.path) else { throw Failure.missingAssets }
        msToken = (0..<88).map { _ in UInt8.random(in: 0...255) }.withUnsafeBytes { Data($0).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_") }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(QishuiAssetHandler(assets: assets, bridge: bridge), forURLScheme: "qishui-auth")
        config.userContentController.add(QishuiWeakHandler(self), name: "qishuiRequest")
        let encoded = String(data: try JSONSerialization.data(withJSONObject: [msToken]), encoding: .utf8)!
        config.userContentController.addUserScript(WKUserScript(source: "try { const t = \(encoded)[0]; localStorage.setItem('xmst', t); localStorage.setItem('xmsty', t); } catch (_) { window.__qishuiStorageUnavailable = true; }", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 980, height: 760), configuration: config)
        web.customUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) SodaMusic/3.2.1 Chrome/136.0.7103.59 Electron/36.4.0 Safari/537.36"
        diagnostics["phase"] = "security-load"
        navigationFailure = false; web.navigationDelegate = self; webView = web
        web.load(URLRequest(url: URL(string: "qishui-auth://security/security_host.html")!))
        for _ in 0..<200 {
            try Task.checkCancellation()
            guard !navigationFailure else { throw Failure.securityRuntime }
            if let ready = try? await web.evaluateJavaScript("Boolean(window.bdms && window.__qishuiBrowserInfo && !window.__qishuiStorageUnavailable)"), ready as? Bool == true {
                diagnostics["phase"] = "browser-info"
                let info = try await web.callAsyncJavaScript("return await window.__qishuiBrowserInfo()", arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
                guard let value = info?["encrypted"] as? String, !value.isEmpty else { throw Failure.securityRuntime }
                browserInfo = value; initialized = true; diagnostics["phase"] = "ready"; return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw Failure.securityRuntime
    }
    private func request(_ method: String, path: String, params: [String: String] = [:], body: [String: String]? = nil) async throws -> [String: Any] {
        try await initialize()
        guard let webView else { throw Failure.securityRuntime }
        let id = identity(), trace = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        var query = ["passport_jssdk_version": "2.4.13", "passport_jssdk_type": "normal", "is_from_ttaccountsdk": "1", "aid": "386088", "language": "zh", "account_sdk_source": "web", "p_js_v": "2.4.13", "p_js_t": "pro", "p_zt": "3.3.5", "p_ver": "1.0.29", "request_host": "app%3A%2F%2Fresources", "p_bd": "1.0.0.41", "biz_trace_id": String(trace.prefix(8)), "is_new_login": "1", "is_from_iesaccountsaas": "1", "device_id": id["deviceId"]!, "install_id": id["installId"]!, "did": id["deviceId"]!, "iid": id["installId"]!, "device_platform": "PC", "version_code": "3.5.2", "account_sdk_source_info": browserInfo, "msToken": msToken]
        query.merge(params) { _, new in new }
        var url = URLComponents(string: "https://api.qishui.com" + path)!
        url.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }.sorted { $0.name < $1.name }
        var headers = ["Accept": "application/json, text/javascript", "x-tt-passport-verify-portrait": id["portrait"]!, "x-tt-passport-trace-id": String(trace.prefix(8)), "x-tt-trace-id": "00-\(trace)-\(trace.prefix(16))-01"]
        var payload: [String: Any] = ["method": method, "url": url.url!.absoluteString, "headers": headers, "timeout": 25000]
        if let body {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "*-._"))
            let encoded = body.sorted { $0.key < $1.key }.map { key, value in
                "\(key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!.replacingOccurrences(of: "%20", with: "+"))"
            }.joined(separator: "&")
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            headers["x-ss-stub"] = Insecure.MD5.hash(data: Data(encoded.utf8)).map { String(format: "%02X", $0) }.joined()
            payload["headers"] = headers; payload["body"] = encoded
        }
        diagnostics["phase"] = "signed-request"
        let result = try await webView.callAsyncJavaScript("return await window.__qishuiRequest(request)", arguments: ["request": payload], in: nil, contentWorld: .page) as? [String: Any]
        diagnostics["responseStatus"] = result?["status"] ?? -1
        guard let status = result?["status"] as? Int, (200..<400).contains(status), let text = result?["body"] as? String,
              let data = text.data(using: .utf8), let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalidResponse }
        return json
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "qishuiRequest", message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.scheme == "qishui-auth", message.frameInfo.request.url?.host == "security",
              let payload = message.body as? [String: Any], let id = payload["id"] as? String, id.count < 32,
              jobs[id] == nil, inFlight < 4 else { return }
        let expected = generation
        inFlight += 1
        jobs[id] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.inFlight -= 1; self.jobs[id] = nil }
            do {
                let response = try await self.forward(payload, generation: expected)
                guard expected == self.generation else { return }
                _ = try? await self.webView?.callAsyncJavaScript("window.__qishuiNativeComplete(id, response)", arguments: ["id": id, "response": response], in: nil, contentWorld: .page)
            } catch {
                guard expected == self.generation else { return }
                _ = try? await self.webView?.callAsyncJavaScript("window.__qishuiNativeComplete(id, {error:true})", arguments: ["id": id], in: nil, contentWorld: .page)
            }
        }
    }
    private func forward(_ payload: [String: Any], generation expected: Int) async throws -> [String: Any] {
        if let raw = payload["url"] as? String, let c = URLComponents(string: raw) {
            diagnostics["signatureLength"] = c.queryItems?.first { $0.name == "a_bogus" }?.value?.count ?? 0
            diagnostics["tokenMatches"] = c.queryItems?.first { $0.name == "msToken" }?.value == msToken
        }
        guard let raw = payload["url"] as? String, raw.utf8.count < 32768, let url = URL(string: raw),
              let method = payload["method"] as? String, QishuiAuthContract.allowedRequest(url, method: method),
              QishuiAuthContract.validSignedURL(url, token: msToken) else { throw Failure.requestDenied }
        diagnostics["phase"] = "native-forward"
        var request = URLRequest(url: url); request.httpMethod = method
        let headers = payload["headers"] as? [String: String] ?? [:]
        for (key, value) in headers where ["accept", "content-type", "x-ss-stub", "x-tt-passport-verify-portrait", "x-tt-passport-trace-id", "x-tt-trace-id"].contains(key.lowercased()) {
            guard value.count < 4096, !value.contains("\r"), !value.contains("\n") else { throw Failure.requestDenied }
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(webView?.customUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookies.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; "), forHTTPHeaderField: "Cookie")
        if let body = payload["body"] as? String { guard body.utf8.count < 32768 else { throw Failure.requestDenied }; request.httpBody = Data(body.utf8) }
        let (bytes, response) = try await requestSession.data(for: request)
        guard expected == generation, bytes.count < 1024 * 1024, let http = response as? HTTPURLResponse,
              http.url == url, let json = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw Failure.invalidResponse }
        diagnostics["nativeHTTP"] = http.statusCode
        let responseHeaders = http.allHeaderFields.reduce(into: [String: String]()) { $0[String(describing: $1.key)] = String(describing: $1.value) }
        for cookie in HTTPCookie.cookies(withResponseHeaderFields: responseHeaders, for: url) where cookie.domain == "api.qishui.com" || cookie.domain == ".qishui.com" {
            cookies[cookie.name] = cookie.value
        }
        var sanitized = json
        if var data = json["data"] as? [String: Any] {
            if let value = data.removeValue(forKey: "session_cookie") as? String {
                for pair in value.split(separator: ";") {
                    let entry = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    if entry.count == 2, ["sessionid", "sessionid_ss", "sid_guard", "sid_tt", "uid_tt", "uid_tt_ss"].contains(entry[0]), !entry[1].contains("\r"), !entry[1].contains("\n") { cookies[entry[0]] = entry[1] }
                }
            }
            sanitized["data"] = data
        }
        try saveCookies()
        return ["status": http.statusCode, "body": String(data: try JSONSerialization.data(withJSONObject: sanitized), encoding: .utf8)!]
    }
    private func saveCookies() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: cookieService, kSecAttrAccount as String: "session"]
        let data = try JSONSerialization.data(withJSONObject: cookies)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var insert = query; insert[kSecValueData as String] = data; insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw Failure.keychain }
        } else if update != errSecSuccess { throw Failure.keychain }
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(action.request.url?.scheme == "qishui-auth" && action.request.url?.host == "security" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailure = true }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailure = true }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { navigationFailure = true; initialized = false }
    private static func qrImage(_ text: String) throws -> String {
        let filter = CIFilter(name: "CIQRCodeGenerator")!; filter.setValue(Data(text.utf8), forKey: "inputMessage")
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let cg = CIContext().createCGImage(image, from: image.extent) else { throw Failure.invalidResponse }
        let data = NSMutableData(); guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw Failure.invalidResponse }
        CGImageDestinationAddImage(destination, cg, nil); guard CGImageDestinationFinalize(destination) else { throw Failure.invalidResponse }
        return "data:image/png;base64," + (data as Data).base64EncodedString()
    }
    enum Failure: LocalizedError {
        case missingAssets, securityRuntime, invalidResponse, replaced, keychain, requestDenied
        var errorDescription: String? {
            switch self {
            case .missingAssets: return "Apple 汽水安全组件资源未打包。"
            case .securityRuntime: return "汽水安全组件尚未在 WebKit 中就绪；登录适配仍待验证。"
            case .invalidResponse: return "汽水登录返回了无法识别的响应。"
            case .replaced: return "二维码已被刷新，请使用最新二维码。"
            case .keychain: return "无法安全保存汽水登录会话。"
            case .requestDenied: return "汽水安全请求不符合已允许的登录接口契约。"
            }
        }
    }
}

private final class QishuiWeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: QishuiAuthRuntime?
    init(_ target: QishuiAuthRuntime) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { target?.userContentController(controller, didReceive: message) }
}
private final class QishuiNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

private final class QishuiAssetHandler: NSObject, WKURLSchemeHandler {
    let assets: URL, bridge: URL
    init(assets: URL, bridge: URL) { self.assets = assets; self.bridge = bridge }
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        do {
            guard let url = task.request.url, url.host == "security", url.query == nil,
                  ["/security_host.html", "/react.js", "/react-dom.js", "/sdk-glue.js", "/bdms.js", "/qishui-xhr-bridge.js"].contains(url.path) else { throw URLError(.noPermissionsToReadFile) }
            var data = try Data(contentsOf: url.path == "/qishui-xhr-bridge.js" ? bridge : assets.appendingPathComponent(String(url.path.dropFirst())))
            if url.path == "/security_host.html" {
                var html = String(decoding: data, as: UTF8.self)
                html = html.replacingOccurrences(of: "<head>", with: "<head><script src=\"qishui-xhr-bridge.js\"></script>")
                html = html.replacingOccurrences(of: "<script src=\"sdk-glue.js\"></script>", with: "<script src=\"sdk-glue.js\"></script><script src=\"bdms.js\"></script>")
                data = Data(html.utf8)
            }
            task.didReceive(URLResponse(url: url, mimeType: url.path.hasSuffix(".js") ? "application/javascript" : "text/html", expectedContentLength: data.count, textEncodingName: "utf-8"))
            task.didReceive(data); task.didFinish()
        } catch { task.didFailWithError(error) }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
