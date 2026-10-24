import Foundation

enum NeteaseFeatureContract {
    static func rows(_ body: [String: Any], keys: [String]) -> [[String: Any]] {
        for key in keys {
            if let rows = body[key] as? [[String: Any]] { return rows }
            if let nested = body[key] as? [String: Any] {
                for name in ["list", "data", "resources", "programs"] {
                    if let rows = nested[name] as? [[String: Any]] { return rows }
                }
            }
        }
        return []
    }
    static func radio(_ raw: [String: Any]) -> [String: Any] {
        let dj = raw["dj"] as? [String: Any] ?? raw["djSimple"] as? [String: Any] ?? [:]
        let id = raw["id"] ?? raw["rid"] ?? raw["radioId"] ?? ""
        return ["id": id, "rid": id, "name": raw["name"] ?? raw["radioName"] ?? "",
                "cover": raw["picUrl"] ?? raw["coverUrl"] ?? "", "desc": raw["desc"] ?? raw["description"] ?? "",
                "djName": dj["nickname"] ?? raw["djName"] ?? "", "category": raw["category"] ?? raw["categoryName"] ?? "",
                "programCount": raw["programCount"] ?? raw["programNum"] ?? 0, "subCount": raw["subCount"] ?? 0]
    }
    static func program(_ raw: [String: Any], radio fallback: [String: Any]) -> [String: Any] {
        let main = raw["mainSong"] as? [String: Any] ?? raw["song"] as? [String: Any] ?? [:]
        let sourceRadio = raw["radio"] as? [String: Any] ?? fallback
        let mapped = radio(sourceRadio)
        var song = NeteaseContract.song(main)
        song.merge(["type": "podcast", "source": "podcast", "id": main["id"] ?? raw["mainSongId"] ?? raw["songId"] ?? "",
            "programId": raw["id"] ?? raw["programId"] ?? "", "radioId": mapped["id"] ?? "", "name": raw["name"] ?? main["name"] ?? "",
            "artist": mapped["name"] ?? "", "album": mapped["name"] ?? "Podcast", "cover": raw["coverUrl"] ?? mapped["cover"] ?? "",
            "duration": raw["duration"] ?? main["dt"] ?? main["duration"] ?? 0, "djName": mapped["djName"] ?? "", "radioName": mapped["name"] ?? "",
            "desc": raw["description"] ?? raw["desc"] ?? "", "createTime": raw["createTime"] ?? 0, "serialNum": raw["serialNum"] ?? 0]) { _, new in new }
        return song
    }
    static func collectionRadio(_ raw: [String: Any], key: String) -> [String: Any] {
        var mapped = radio(raw)
        mapped["type"] = "podcast-radio"; mapped["sourceType"] = "podcast-radio"; mapped["collectionKey"] = key
        mapped["radioId"] = mapped["id"]; mapped["artist"] = mapped["djName"]; mapped["album"] = mapped["category"]
        return mapped
    }
    static func voice(_ item: [String: Any]) -> [String: Any] {
        let raw = item["resource"] as? [String: Any] ?? item["voice"] as? [String: Any] ?? item["data"] as? [String: Any] ?? item
        let song = raw["mainSong"] as? [String: Any] ?? raw["song"] as? [String: Any] ?? [:]
        let radio = raw["radio"] as? [String: Any] ?? raw["voiceList"] as? [String: Any] ?? [:]
        return ["type": "podcast", "source": "podcast", "sourceType": "podcast-voice", "id": raw["trackId"] ?? raw["songId"] ?? song["id"] ?? raw["id"] ?? "",
                "programId": raw["programId"] ?? raw["voiceId"] ?? raw["id"] ?? "", "radioId": radio["id"] ?? raw["radioId"] ?? "",
                "name": raw["name"] ?? raw["title"] ?? song["name"] ?? "", "artist": radio["name"] ?? raw["djName"] ?? "Voice",
                "album": radio["name"] ?? "Podcast", "cover": raw["coverUrl"] ?? raw["picUrl"] ?? radio["picUrl"] ?? "",
                "duration": raw["duration"] ?? raw["durationMs"] ?? song["dt"] ?? 0]
    }
    static func collectionTitle(_ key: String) -> String { ["collect": "收藏播客", "created": "创建播客", "liked": "喜欢的声音"][key] ?? key }
}
