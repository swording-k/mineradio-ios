import Foundation

enum OfficialLoginPolicy {
    static func entry(_ provider: String) -> URL? {
        switch provider {
        case "qq": return URL(string: "https://y.qq.com/n/ryqq/profile")
        case "kugou": return URL(string: "https://www.kugou.com/")
        default: return nil
        }
    }
    static func domain(_ host: String, provider: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let root = provider == "qq" ? "qq.com" : (provider == "kugou" ? "kugou.com" : "")
        return !root.isEmpty && (host == root || host.hasSuffix("." + root))
    }
    static func allows(_ url: URL, provider: String) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil &&
        (url.port == nil || url.port == 443) && domain(url.host ?? "", provider: provider)
    }
    static func cookies(_ values: [HTTPCookie], provider: String) -> [HTTPCookie] {
        values.filter { domain($0.domain, provider: provider) && $0.expiresDate.map { $0 > Date() } != false }
    }
}
