import Foundation
@main struct OfficialLoginPolicyTests {
    static func main() {
        precondition(OfficialLoginPolicy.entry("qq")?.host == "y.qq.com")
        precondition(OfficialLoginPolicy.entry("kugou")?.host == "www.kugou.com")
        precondition(OfficialLoginPolicy.entry("unknown") == nil)
        precondition(OfficialLoginPolicy.allows(URL(string: "https://xui.ptlogin2.qq.com/cgi-bin/xlogin")!, provider: "qq"))
        for value in ["http://y.qq.com/", "https://qq.com.evil.test/", "https://user@y.qq.com/", "https://y.qq.com:444/", "file:///private/a"] {
            precondition(!OfficialLoginPolicy.allows(URL(string: value)!, provider: "qq"))
        }
        precondition(!OfficialLoginPolicy.allows(URL(string: "https://y.qq.com/")!, provider: "kugou"))
        let relevant = HTTPCookie(properties: [.domain: ".qq.com", .path: "/", .name: "uin", .value: "fixture", .secure: "TRUE"])!
        let unrelated = HTTPCookie(properties: [.domain: ".example.com", .path: "/", .name: "uin", .value: "unrelated"])!
        precondition(OfficialLoginPolicy.cookies([relevant, unrelated], provider: "qq").count == 1)
        print("Official login: provider entry, HTTPS exact-domain boundaries and cookie isolation passed")
    }
}
