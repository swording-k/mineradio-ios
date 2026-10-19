import Foundation

enum NeteaseContract {
    static func song(_ raw: [String: Any]) -> [String: Any] {
        let artists = raw["ar"] as? [[String: Any]] ?? raw["artists"] as? [[String: Any]] ?? []
        let album = raw["al"] as? [String: Any] ?? raw["album"] as? [String: Any] ?? [:]
        return ["provider": "netease", "source": "netease", "type": "song",
                "id": raw["id"] ?? "", "name": raw["name"] ?? "",
                "artist": artists.compactMap { $0["name"] as? String }.joined(separator: " / "),
                "artists": artists, "artistId": artists.first?["id"] ?? "",
                "album": album["name"] ?? "", "albumId": album["id"] ?? "",
                "cover": album["picUrl"] ?? album["coverUrl"] ?? "",
                "duration": raw["dt"] ?? raw["duration"] ?? 0, "fee": raw["fee"] ?? 0]
    }

    static func playlist(_ raw: [String: Any]) -> [String: Any] {
        let creator = raw["creator"] as? [String: Any] ?? [:]
        return ["id": raw["id"] ?? "", "name": raw["name"] ?? "",
                "cover": raw["coverImgUrl"] ?? raw["picUrl"] ?? "",
                "trackCount": raw["trackCount"] ?? 0, "playCount": raw["playCount"] ?? 0,
                "creator": creator["nickname"] ?? "", "subscribed": raw["subscribed"] ?? false,
                "specialType": raw["specialType"] ?? 0]
    }

    static func allowedMedia(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), ["http", "https"].contains(url.scheme ?? ""),
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 || url.port == 80 else { return false }
        return ["music.126.net", "music.163.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func playback(_ body: [String: Any]) -> [String: Any] {
        guard let track = (body["data"] as? [[String: Any]])?.first,
              let text = track["url"] as? String, let url = URL(string: text), allowedMedia(url) else {
            return ["playable": false, "reason": "source_unavailable", "message": "网易云未提供可播放音源，请检查登录与歌曲权益。"]
        }
        let trial = track["freeTrialInfo"] as? [String: Any] != nil
        return ["url": text, "playable": true, "trial": trial, "provider": "netease",
                "source": "netease-native-eapi", "level": track["level"] ?? "standard",
                "duration": ((track["time"] as? NSNumber)?.doubleValue ?? 0) / 1000,
                "br": track["br"] ?? 0]
    }
}
