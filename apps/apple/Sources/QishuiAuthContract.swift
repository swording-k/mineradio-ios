import Foundation

/// Ported from the repository's GPL-3.0-only Passport bridge. Login capability
/// is separate from catalogue, membership and full-track playback capability.
enum QishuiAuthContract {
    static func mayValidateAccount(_ status: [String: Any]) -> Bool {
        status["cookieReady"] as? Bool == true && status["status"] as? String == "verifying"
    }
    static func scanURL(_ index: String) -> URL? {
        guard let source = URLComponents(string: index), source.scheme == "https",
              ["api.qishui.com", "bff-pc.qishui.com"].contains(source.host ?? ""),
              source.user == nil, source.password == nil, source.port == nil || source.port == 443,
              let items = source.queryItems?.filter({ $0.name == "token" }), items.count == 1,
              let token = items.first?.value, !token.isEmpty, token.count <= 2048 else { return nil }
        var scan = URLComponents(string: "https://bff-pc.qishui.com/light/invoke/scan_login")!
        scan.queryItems = [URLQueryItem(name: "token", value: token), URLQueryItem(name: "os", value: "Windows"), URLQueryItem(name: "computer_name", value: "Mineradio Apple")]
        return scan.url
    }
    static func allowedRequest(_ url: URL, method: String) -> Bool {
        guard url.scheme == "https", url.host == "api.qishui.com", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, url.fragment == nil else { return false }
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? ""
        return (path == "/passport/web/get_qrcode/" && method == "GET") ||
               (path == "/passport/web/check_qrconnect/" && method == "POST")
    }
    static func allowedSecurityRequest(_ url: URL, method: String) -> Bool {
        guard url.scheme == "https", ["api.qishui.com", "verify.zijieapi.com", "auth.zijieapi.com"].contains(url.host ?? ""),
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              url.fragment == nil, ["GET", "POST"].contains(method) else { return false }
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? ""
        return path.hasPrefix("/passport/") && !path.split(separator: "/").contains("..")
    }
    static func validSignedURL(_ url: URL, token: String) -> Bool {
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let signatures = q.filter { $0.name == "a_bogus" }
        let tokens = q.filter { $0.name == "msToken" }
        return signatures.count == 1 && signatures[0].value?.count == 44 &&
            tokens.count == 1 && tokens[0].value == token
    }
    static func poll(_ data: [String: Any], cookieReady: Bool) -> [String: Any] {
        let code = (data["error_code"] as? NSNumber)?.intValue ?? -1
        let raw = String(describing: data["status"] ?? "")
        let status: String
        switch code {
        case 2046: status = "mfa_required"
        case 2: status = "expired"
        case 7: status = "rate_limited"
        case 0:
            status = (raw == "3" || raw == "confirmed") && cookieReady ? "verifying" : (raw == "2" ? "scanned" : "waiting")
        default: status = "error"
        }
        return ["provider": "qishui", "loggedIn": false, "status": status, "errorCode": code,
                "error_code": code, "cookieReady": cookieReady, "retryAfterMs": code == 7 ? 60000 : 4500,
                "message": code == 2046 ? "汽水账号需要完成二次安全验证。" : (status == "verifying" ? "扫码已确认，Apple 账号与曲库验证尚未完成。" : "")]
    }
}
