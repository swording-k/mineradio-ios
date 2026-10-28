import Foundation
import CoreImage
import UIKit

/// QQ 音乐 / 酷狗直连扫码登录（与网易云同一种方式：App 自己取二维码、自己轮询结果，不打开网页）。
/// 协议平行移植自 Mineradio-Android nodejs-project-src/qr-login-providers.js（其注释：移植自 folia Android）。
///  - QQ 音乐：ptqrshow → ptqrlogin → check_sig → oauth2.0 authorize → musicu QQLogin（取 qm_keyst）。用手机 QQ 扫码。
///  - 酷狗：login-user.kugou.com /v2/qrcode → /v2/get_userinfo_qrcode。用酷狗 App 扫码。
/// 账号凭证只交给本机的 QQ / 酷狗原生适配器，不经过网页，也不发给任何第三方服务器。
actor AppleDirectQrLogin {
    enum Failure: LocalizedError {
        case http(Int), missing(String)
        var errorDescription: String? {
            switch self {
            case .http(let code): return "登录服务暂时不可用（HTTP \(code)）"
            case .missing(let what): return "登录响应缺少 \(what)，请刷新二维码重试"
            }
        }
    }
    private static let chromeUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private let session: URLSession
    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }

    private struct Reply { let status: Int; let location: String; let cookies: [HTTPCookie]; let body: Data }
    private func send(_ url: URL, method: String = "GET", headers: [String: String], body: Data? = nil, timeout: TimeInterval = 12) async throws -> Reply {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method; request.httpBody = body; request.httpShouldHandleCookies = false
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.http(0) }
        var fields: [String: String] = [:]
        for (k, v) in http.allHeaderFields { if let k = k as? String, let v = v as? String { fields[k] = v } }
        return Reply(status: http.statusCode, location: http.value(forHTTPHeaderField: "Location") ?? "",
                     cookies: HTTPCookie.cookies(withResponseHeaderFields: fields, for: url), body: data)
    }

    // MARK: QQ 音乐

    private let qqAppID = "716027609", qqDaid = "383", qqAid = "100497308"
    private let qqU1 = "https://graph.qq.com/oauth2.0/login_jump"
    private let qqRedirect = "https://y.qq.com/portal/wx_redirect.html?login_type=1&surl=https://y.qq.com/"
    private var qqTicketFailures: [String: Int] = [:]

    static func hash33(_ text: String) -> Int {
        var e = 0
        for c in text.unicodeScalars { e = (e &+ (e << 5) &+ Int(c.value)) & 0xFFFFFFFF }
        return e & 2147483647
    }
    static func gtk(_ pSkey: String) -> Int {
        var h = 5381
        for c in pSkey.unicodeScalars { h = (h &+ (h << 5) &+ Int(c.value)) & 0xFFFFFFFF }
        return h & 2147483647
    }

    func qqCreate() async throws -> [String: Any] {
        var c = URLComponents(string: "https://ssl.ptlogin2.qq.com/ptqrshow")!
        c.queryItems = [("appid", qqAppID), ("e", "2"), ("l", "M"), ("s", "3"), ("d", "72"), ("v", "4"), ("t", String(Double.random(in: 0..<1))),
                        ("daid", qqDaid), ("pt_3rd_aid", qqAid), ("u1", qqU1)].map { URLQueryItem(name: $0.0, value: $0.1) }
        let r = try await send(c.url!, headers: ["User-Agent": Self.chromeUA, "Referer": "https://xui.ptlogin2.qq.com/", "Accept": "image/*,*/*;q=0.8"])
        guard r.status == 200 else { throw Failure.http(r.status) }
        guard let sig = r.cookies.first(where: { $0.name == "qrsig" })?.value, !sig.isEmpty else { throw Failure.missing("qrsig") }
        return ["provider": "qq", "img": "data:image/png;base64," + r.body.base64EncodedString(), "qrsig": sig, "ptqrtoken": String(Self.hash33(sig))]
    }

    private func qqRetry(_ sig: String, _ message: String) -> [String: Any] {
        let n = (qqTicketFailures[sig] ?? 0) + 1
        qqTicketFailures[sig] = n
        if qqTicketFailures.count > 32 { qqTicketFailures.removeAll() }
        return n <= 3 ? ["status": "wait", "message": message, "retryable": true] : ["status": "error", "message": message]
    }

    /// 返回 status: wait / scanned / expired / error / ok（ok 时带 cookies）。
    func qqCheck(qrsig: String, ptqrtoken: String) async -> (result: [String: Any], cookies: [HTTPCookie]) {
        let sig = qrsig.trimmingCharacters(in: .whitespaces)
        guard !sig.isEmpty, sig.count < 512 else { return (["status": "expired", "message": "缺少二维码会话"], []) }
        let token = ptqrtoken.isEmpty ? String(Self.hash33(sig)) : ptqrtoken
        var jar: [String: HTTPCookie] = [:]
        func merge(_ list: [HTTPCookie]) { for c in list where !c.value.isEmpty { jar[c.name] = c } }
        func header() -> String { (["qrsig=" + sig] + jar.values.filter { $0.name != "qrsig" }.map { "\($0.name)=\($0.value)" }).joined(separator: "; ") }

        var poll = URLComponents(string: "https://ssl.ptlogin2.qq.com/ptqrlogin")!
        poll.queryItems = [("u1", qqU1), ("ptqrtoken", token), ("ptredirect", "0"), ("h", "1"), ("t", "1"), ("g", "1"), ("from_ui", "1"),
                           ("ptlang", "2052"), ("action", "0-0-\(Int(Date().timeIntervalSince1970 * 1000))"), ("js_ver", "23111510"), ("js_type", "1"),
                           ("login_sig", ""), ("pt_uistyle", "40"), ("aid", qqAppID), ("daid", qqDaid), ("pt_3rd_aid", qqAid)].map { URLQueryItem(name: $0.0, value: $0.1) }
        let text: String
        do {
            let r = try await send(poll.url!, headers: ["User-Agent": Self.chromeUA, "Referer": "https://xui.ptlogin2.qq.com/", "Accept": "*/*", "Cookie": "qrsig=" + sig])
            merge(r.cookies); text = String(decoding: r.body, as: UTF8.self)
        } catch { return (["status": "wait", "message": "登录检查失败，将继续重试"], []) }
        let success = text.contains("登录成功") || text.contains("登陆成功")
        if !success {
            if (text.contains("已失效") || text.contains("已过期")) && !text.contains("未失效") { return (["status": "expired", "message": "二维码已失效，请刷新"], []) }
            if text.contains("认证中") || text.contains("扫描成功") || text.contains("已扫描") { return (["status": "scanned", "message": "已扫码，请在手机 QQ 上确认登录"], []) }
            return (["status": "wait", "message": "请用手机 QQ 扫码登录"], [])
        }
        // ptuiCB('0','0','https://…check_sig…','0','登录成功！','昵称')
        guard let range = text.range(of: #"'(https?://[^']+)'"#, options: .regularExpression) else { return (qqRetry(sig, "未拿到 check_sig 地址"), []) }
        let rawCheck = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
        let checkText = String(rawCheck.unicodeScalars.filter { $0.value >= 0x21 && $0.value <= 0x7E }).components(separatedBy: CharacterSet(charactersIn: ",;"))[0]
        guard let checkURL = URL(string: checkText), let host = checkURL.host, host == "qq.com" || host.hasSuffix(".qq.com") else { return (qqRetry(sig, "check_sig 地址无效"), []) }
        let uin = (URLComponents(url: checkURL, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "uin" }?.value ?? "").filter(\.isNumber)
        let nickname: String = {
            let parts = text.components(separatedBy: "'")
            return parts.count >= 12 ? parts[11] : ""
        }()
        // 1) check_sig
        do {
            let r = try await send(checkURL, headers: ["User-Agent": Self.chromeUA, "Referer": "https://xui.ptlogin2.qq.com/", "Accept": "text/html,*/*", "Cookie": header()])
            merge(r.cookies)
            if (300..<400).contains(r.status), let next = URL(string: r.location, relativeTo: checkURL)?.absoluteURL, next.host?.hasSuffix("qq.com") == true {
                merge(try await send(next, headers: ["User-Agent": Self.chromeUA, "Referer": checkText, "Accept": "text/html,*/*", "Cookie": header()]).cookies)
            }
        } catch { return (qqRetry(sig, "check_sig 失败"), []) }
        guard let pSkey = jar["p_skey"]?.value, !pSkey.isEmpty else { return (qqRetry(sig, "缺少 p_skey"), []) }
        let gtk = Self.gtk(pSkey)
        // 2) oauth2.0 authorize → code
        var form = URLComponents()
        form.queryItems = [("response_type", "code"), ("client_id", qqAid), ("redirect_uri", qqRedirect), ("scope", "get_user_info,get_app_friends"),
                           ("state", "state"), ("switch", ""), ("from_ptlogin", "1"), ("src", "1"), ("update_auth", "1"), ("openapi", "1010_1030"),
                           ("g_tk", String(gtk)), ("auth_time", String(Int(Date().timeIntervalSince1970 * 1000))), ("ui", UUID().uuidString)].map { URLQueryItem(name: $0.0, value: $0.1) }
        let formBody = (form.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
        var code = ""
        do {
            var r = try await send(URL(string: "https://graph.qq.com/oauth2.0/authorize")!, method: "POST",
                                   headers: ["User-Agent": Self.chromeUA, "Referer": "https://graph.qq.com/", "Origin": "https://graph.qq.com",
                                             "Content-Type": "application/x-www-form-urlencoded", "Cookie": header()], body: Data(formBody.utf8))
            merge(r.cookies)
            var location = r.location, hops = 0
            func extract(_ s: String) -> String? {
                guard let m = s.range(of: #"[?&]code=([^&"'\s]+)"#, options: .regularExpression) else { return nil }
                return String(s[m].split(separator: "=", maxSplits: 1)[1]).removingPercentEncoding
            }
            while code.isEmpty, (300..<400).contains(r.status), !location.isEmpty, hops < 4 {
                if let found = extract(location) { code = found; break }
                hops += 1
                guard let next = URL(string: location, relativeTo: URL(string: "https://graph.qq.com/"))?.absoluteURL, next.host?.hasSuffix("qq.com") == true else { break }
                r = try await send(next, headers: ["User-Agent": Self.chromeUA, "Referer": "https://graph.qq.com/", "Accept": "text/html,*/*", "Cookie": header()])
                merge(r.cookies); location = r.location
                if extract(location) == nil, let found = extract(String(decoding: r.body, as: UTF8.self)) { code = found }
            }
            if code.isEmpty, let found = extract(location) { code = found }
        } catch { return (qqRetry(sig, "授权请求失败"), []) }
        guard !code.isEmpty else { return (qqRetry(sig, "授权未返回 code"), []) }
        // 3) musicu QQLogin → qm_keyst
        var extra: [String: String] = [:]
        do {
            let payload: [String: Any] = ["comm": ["g_tk": gtk, "platform": "yqq", "ct": 24, "cv": 0],
                                          "req": ["module": "QQConnectLogin.LoginServer", "method": "QQLogin", "param": ["code": code]]]
            let r = try await send(URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg")!, method: "POST",
                                   headers: ["User-Agent": Self.chromeUA, "Referer": "https://y.qq.com/", "Origin": "https://y.qq.com",
                                             "Content-Type": "application/x-www-form-urlencoded", "Cookie": header()],
                                   body: try JSONSerialization.data(withJSONObject: payload))
            merge(r.cookies)
            if let json = try? JSONSerialization.jsonObject(with: r.body) as? [String: Any],
               let data = (json["req"] as? [String: Any])?["data"] as? [String: Any] {
                if let key = data["musickey"] as? String, !key.isEmpty { extra["qm_keyst"] = key }
                if let key = data["qqmusic_key"] as? String, !key.isEmpty { extra["qqmusic_key"] = key }
            }
        } catch { return (qqRetry(sig, "QQLogin 失败"), []) }
        var values = jar.mapValues(\.value)
        values.merge(extra) { _, new in new }
        values["login_type"] = "1"
        if !uin.isEmpty { values["uin"] = "o" + uin; if values["qqmusic_uin"] == nil { values["qqmusic_uin"] = "o" + uin } }
        guard values["qm_keyst"] != nil || values["qqmusic_key"] != nil else { return (qqRetry(sig, "登录成功但未拿到播放密钥"), []) }
        qqTicketFailures[sig] = nil
        return (["status": "ok", "message": "登录成功", "nickname": nickname, "uin": uin], Self.cookies(values, domain: ".qq.com"))
    }

    // MARK: 酷狗

    private let kgSalt = "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt"
    private var kgTimeouts: [String: Int] = [:]
    private func kgSignedGet(_ path: String, _ extra: [String: String], timeout: TimeInterval = 12) async throws -> [String: Any] {
        let mid = KugouContract.md5(String(Date().timeIntervalSince1970) + String(Double.random(in: 0..<1)))
        var params = ["dfid": "-", "mid": mid, "uuid": mid, "clientver": "11440", "clienttime": String(Int(Date().timeIntervalSince1970))]
        params.merge(extra) { _, new in new }
        params["signature"] = KugouContract.md5(kgSalt + params.keys.sorted().map { $0 + "=" + params[$0]! }.joined() + kgSalt)
        var c = URLComponents(string: "https://login-user.kugou.com" + path)!
        c.queryItems = params.keys.sorted().map { URLQueryItem(name: $0, value: params[$0]) }
        let r = try await send(c.url!, headers: ["User-Agent": Self.chromeUA, "Accept": "application/json, text/plain, */*", "Referer": "https://www.kugou.com/"], timeout: timeout)
        guard (200..<300).contains(r.status), let json = try JSONSerialization.jsonObject(with: r.body) as? [String: Any] else { throw Failure.http(r.status) }
        return json
    }

    func kugouCreate() async throws -> [String: Any] {
        let body = try await kgSignedGet("/v2/qrcode", ["appid": "1001", "type": "1", "plat": "4", "srcappid": "2919",
                                                         "qrcode_txt": "https://h5.kugou.com/apps/loginQRCode/html/index.html?appid=3116&"])
        let data = body["data"] as? [String: Any] ?? [:]
        let key = [data["qrcode"], data["qrcode_key"], data["key"], body["qrcode"], body["key"]].compactMap { $0 as? String }.first { !$0.isEmpty } ?? ""
        guard !key.isEmpty else { throw Failure.missing("二维码 key") }
        let link = "https://h5.kugou.com/apps/loginQRCode/html/index.html?qrcode=" + (key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
        return ["provider": "kugou", "key": key, "url": link, "img": Self.qrImage(link)]
    }

    func kugouCheck(key: String) async -> (result: [String: Any], cookies: [HTTPCookie]) {
        let key = key.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, key.count < 256 else { return (["status": "expired", "message": "缺少二维码 key"], []) }
        let body: [String: Any]
        do {
            body = try await kgSignedGet("/v2/get_userinfo_qrcode", ["plat": "4", "appid": "3116", "srcappid": "2919", "qrcode": key], timeout: 45)
            kgTimeouts[key] = nil
        } catch {
            let n = (kgTimeouts[key] ?? 0) + 1; kgTimeouts[key] = n
            return n < 3 ? (["status": "wait", "message": "请用酷狗 App 扫码"], []) : (["status": "error", "message": "酷狗登录检查失败，请刷新二维码"], [])
        }
        let data = body["data"] as? [String: Any] ?? [:]
        let status = Int("\(data["status"] ?? body["status"] ?? 0)") ?? 0
        switch status {
        case 0: return (["status": "expired", "message": "二维码已过期，请刷新"], [])
        case 1: return (["status": "wait", "message": "请用酷狗 App 扫码"], [])
        case 2: return (["status": "scanned", "message": "已扫码，请在酷狗 App 上确认"], [])
        case 4: break
        default: return (["status": "wait", "message": "等待扫码"], [])
        }
        func s(_ keys: [String]) -> String { keys.compactMap { k in data[k].map { "\($0)" } }.first { !$0.isEmpty && $0 != "<null>" } ?? "" }
        let uid = s(["userid", "user_id", "KugooID"]), token = s(["token", "t"])
        guard !uid.isEmpty, !token.isEmpty else { return (["status": "error", "message": "扫码成功但未返回登录令牌，请刷新二维码重试"], []) }
        let nickname = s(["nickname", "nick_name", "username"]).replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        var values = ["KuGoo": "KugooID=\(uid)&t=\(token)&userid=\(uid)&confirm_flag=1", "userid": uid, "KugooID": uid, "token": token]
        if !nickname.isEmpty { values["NickName"] = nickname.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? nickname }
        return (["status": "ok", "message": "登录成功", "nickname": nickname, "userId": uid], Self.cookies(values, domain: ".kugou.com"))
    }

    // MARK: 工具

    static func cookies(_ values: [String: String], domain: String) -> [HTTPCookie] {
        values.compactMap { name, value in
            HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: "/",
                                    .expires: Date().addingTimeInterval(30 * 86400)])
        }
    }
    static func qrImage(_ text: String) -> String {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return "" }
        filter.setValue(Data(text.utf8), forKey: "inputMessage"); filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent),
              let png = UIImage(cgImage: cg).pngData() else { return "" }
        return "data:image/png;base64," + png.base64EncodedString()
    }
}
