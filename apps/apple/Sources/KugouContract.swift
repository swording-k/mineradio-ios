import Foundation
import CryptoKit

/// Protocol/mapping port of the repository's GPL-3.0-only kugou-api.js.
enum KugouContract {
    static let cookieNames: Set<String> = ["KuGoo", "Kugou", "kugou", "token", "Token", "userid", "UserId", "KugooID", "kugouID", "kg_mid", "KG_MID", "kg_dfid", "KG_DFID", "NickName"]
    static func md5(_ value: String) -> String { Insecure.MD5.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func signature(_ params: [String: String], body: String = "") -> String {
        let salt = "NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt"
        return md5(salt + params.keys.sorted().map { "\($0)=\(params[$0]!)" }.joined() + body + salt)
    }
    static func allowedAPI(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.fragment == nil,
              url.port == nil || url.port == 443 else { return false }
        let paths: [String: Set<String>] = [
            "songsearch.kugou.com": ["/song_search_v2"],
            "gateway.kugou.com": ["/v7/get_all_list", "/v4/get_list_all_file", "/v5/url", "/v6/add_song", "/v4/delete_songs", "/v1/app_song_list_offset"],
            "wwwapi.kugou.com": ["/play/songinfo"], "wwwapiretry.kugou.com": ["/play/songinfo"],
            "m.kugou.com": ["/app/i/getSongInfo.php"], "krcs.kugou.com": ["/search", "/download"],
            "vip.kugou.com": ["/recharge/roleinfo"]]
        return paths[url.host ?? ""]?.contains(url.path) == true
    }
    static func allowedMedia(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme ?? ""), url.user == nil, url.password == nil,
              url.port == nil || url.port == 80 || url.port == 443, let host = url.host?.lowercased() else { return false }
        return ["kugou.com", "kgimg.com", "kugou.net"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func text(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        return String(describing: value).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func number(_ value: Any?) -> Double { (value as? NSNumber)?.doubleValue ?? Double(text(value)) ?? 0 }
    static func first(_ item: [String: Any], _ keys: [String]) -> Any? { keys.compactMap { item[$0] }.first { !text($0).isEmpty } }
    static func song(_ item: [String: Any]) -> [String: Any] {
        let singers = (item["Singers"] ?? item["singerinfo"]) as? [[String: Any]] ?? []
        var artists: [[String: Any]] = singers.map { ["id": text(first($0, ["id", "SingerId"])), "name": text(first($0, ["name", "SingerName"]))] }
        if artists.isEmpty { artists = text(item["SingerName"]).components(separatedBy: "、").filter { !$0.isEmpty }.map { ["id": "", "name": $0] } }
        let hash = text(first(item, ["FileHash", "hash"])), mix = text(first(item, ["MixSongID", "mixsongid", "album_audio_id"]))
        let album = item["albuminfo"] as? [String: Any] ?? [:]
        let audio = mix.allSatisfy(\.isNumber) && !mix.isEmpty ? mix : text(first(item, ["EMixSongID", "AlbumAudioID", "album_audio_id"]))
        let duration = number(first(item, ["Duration", "duration"])) * 1000
        let privilege = number(first(item, ["Privilege", "media_privilege", "privilege"]))
        var title = text(first(item, ["SongName", "name", "FileName", "filename", "OriSongName"]))
        let artist = artists.map { text($0["name"]) }.joined(separator: " / ")
        if !artist.isEmpty && title.hasPrefix(artist + " - ") { title = String(title.dropFirst(artist.count + 3)) }
        return ["provider": "kugou", "source": "kugou", "type": "kugou", "id": hash.isEmpty ? mix : hash,
            "hash": hash, "fileHash": hash, "name": title, "artist": artist, "artists": artists,
            "albumId": text(first(item, ["AlbumID", "album_id"]) ?? album["id"]), "albumAudioId": audio, "album_audio_id": audio,
            "album": text(first(item, ["AlbumName", "album_name"]) ?? album["name"]), "mixSongId": mix,
            "duration": duration > 0 ? duration : number(item["timelen"]),
            "cover": text(first(item, ["Image", "cover", "img", "album_cover"]) ?? (item["trans_param"] as? [String: Any])?["union_cover"]).replacingOccurrences(of: "{size}", with: "240"),
            "fee": privilege >= 10 ? 1 : 0, "privilege": privilege, "playable": privilege <= 8,
            "hqHash": text(item["HQFileHash"]), "sqHash": text(item["SQFileHash"]), "resHash": text(item["ResFileHash"])]
    }
    static func playlist(_ item: [String: Any]) -> [String: Any] {
        let id = text(first(item, ["global_collection_id", "specialid", "listid", "list_id", "id"]))
        return ["provider": "kugou", "source": "kugou", "id": id, "listId": text(first(item, ["list_create_listid", "listid", "list_id"]) ?? id),
                "name": text(first(item, ["name", "listname", "specialname", "title"])),
                "cover": text(first(item, ["pic", "img", "imgurl", "sizable_cover", "create_user_pic"])).replacingOccurrences(of: "{size}", with: "240"),
                "trackCount": number(first(item, ["count", "m_count", "song_count", "total", "list_count"])),
                "creator": text(first(item, ["nickname", "username", "user_name", "list_create_username"]))]
    }
    static func listRows(_ input: [String: Any]) -> [[String: Any]]? {
        let data = input["data"] as? [String: Any] ?? input
        if let info = data["info"] as? [[String: Any]] { return info }
        let info = data["info"] as? [String: Any] ?? data
        var result: [[String: Any]] = [], found = false
        for key in ["collect", "love", "self", "list"] { if let list = info[key] as? [[String: Any]] { result += list; found = true } }
        if info["list"] == nil, let list = data["list"] as? [[String: Any]] { result += list; found = true }
        return found ? result : nil
    }
    static func playback(_ input: [String: Any]) -> [String: Any] {
        let data = input["data"] as? [String: Any] ?? [:]
        func find(_ value: Any?) -> String? {
            if let array = value as? [Any] { return array.compactMap(find).first }
            guard let string = value as? String, let url = URL(string: string), allowedMedia(url) else { return nil }
            return string
        }
        let keys = ["url", "play_url", "backupUrl", "backup_url", "play_backup_url"]
        let url = (keys.compactMap { find(input[$0]) } + keys.compactMap { find(data[$0]) }).first ?? ""
        let trial = [input, data].contains { row in ["is_free_part", "isFreePart", "trial", "is_trial", "isTrial"].contains { key in let value = text(row[key]).lowercased(); return value == "true" || value == "1" } }
        guard number(input["status"]) == 1, !url.isEmpty else {
            let code = number(first(input, ["err_code", "error_code", "errcode", "errno"]))
            return ["provider": "kugou", "playable": false, "url": "", "reason": code == 30020 ? "verification_required" : (code == 30022 ? "client_only" : "url_unavailable"), "upstreamCode": code,
                    "message": code == 30020 ? "酷狗需要在官方登录窗口完成安全验证" : "酷狗未返回当前账号可播放的音源"]
        }
        let bitrate = number(data["bitrate"]), kbps = bitrate >= 10000 ? bitrate / 1000 : bitrate
        let level = kbps >= 900 ? "lossless" : (kbps >= 300 ? "exhigh" : "standard")
        return ["provider": "kugou", "playable": true, "url": url, "trial": trial, "level": level, "quality": level, "playbackSource": "kugou-official"]
    }
}
