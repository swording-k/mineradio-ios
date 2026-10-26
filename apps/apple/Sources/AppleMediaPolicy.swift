import Foundation

enum AppleMediaPolicy {
    static func allowed(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme ?? ""), url.user == nil, url.password == nil,
              url.port == nil || url.port == 80 || url.port == 443 else { return false }
        if NeteaseContract.allowedMedia(url) || QQMusicContract.allowedMedia(url) || KugouContract.allowedMedia(url) || QishuiCatalogContract.allowedMedia(url) { return true }
        let host = url.host?.lowercased() ?? ""
        if host == "i.scdn.co" && url.path.hasPrefix("/image/") { return true }
        return (host == "y.qq.com" && url.path.hasPrefix("/music/photo_new/")) ||
            ["imge.kugou.com", "imgessl.kugou.com"].contains(host)
    }
    static func referer(_ url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host == "i.scdn.co" { return "https://open.spotify.com/" }
        if host == "qq.com" || host.hasSuffix(".qq.com") { return "https://y.qq.com/" }
        if host == "kugou.com" || host.hasSuffix(".kugou.com") { return "https://www.kugou.com/" }
        if QishuiCatalogContract.allowedMedia(url) { return "https://www.qishui.com/" }
        return "https://music.163.com/"
    }
}
