import Foundation
@main struct QishuiAuthContractTests {
    static func main() throws {
        let base = "https://api.qishui.com/passport/web/get_qrcode/?a_bogus=" + String(repeating: "A", count: 44) + "&msToken=fixture"
        precondition(QishuiAuthContract.allowedRequest(URL(string: base)!, method: "GET"))
        for bad in [base.replacingOccurrences(of: "api.qishui.com", with: "api.qishui.com.evil.test"), base.replacingOccurrences(of: "https:", with: "http:"), base.replacingOccurrences(of: "/passport/web/get_qrcode/", with: "/private"), base.replacingOccurrences(of: "api.qishui.com", with: "user@api.qishui.com")] {
            precondition(!QishuiAuthContract.allowedRequest(URL(string: bad)!, method: "GET"))
        }
        precondition(!QishuiAuthContract.allowedRequest(URL(string: base)!, method: "POST"))
        precondition(QishuiAuthContract.validSignedURL(URL(string: base)!, token: "fixture"))
        precondition(!QishuiAuthContract.validSignedURL(URL(string: base)!, token: "other"))
        precondition(QishuiAuthContract.poll(["error_code": 0, "status": "3"], cookieReady: false)["loggedIn"] as? Bool == false)
        precondition(QishuiAuthContract.poll(["error_code": 0, "status": "3"], cookieReady: true)["status"] as? String == "verifying")
        precondition(QishuiAuthContract.poll(["error_code": 2046], cookieReady: false)["status"] as? String == "mfa_required")
        precondition(QishuiAuthContract.poll(["error_code": 7], cookieReady: false)["retryAfterMs"] as? Int == 60000)
        precondition(QishuiAuthContract.scanURL("https://bff-pc.qishui.com/light/invoke/scan_login?token=fixture")?.host == "bff-pc.qishui.com")
        precondition(QishuiAuthContract.scanURL("https://api.qishui.com/passport/qr?token=fixture") != nil)
        precondition(QishuiAuthContract.scanURL("https://evil.test/scan?token=fixture") == nil)
        precondition(QishuiAuthContract.scanURL("https://bff-pc.qishui.com/scan") == nil)
        print("Qishui auth: exact host/path/method, signed token binding, no fabricated account login, MFA/limit states passed")
    }
}
