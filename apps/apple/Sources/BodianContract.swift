import Foundation
import CryptoKit

enum BodianContract {
    static func text(_ value: Any?) -> String { if let s = value as? String { return s }; if let n = value as? NSNumber { return n.stringValue }; return "" }
    static func md5(_ s: String) -> String { Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func sign(path: String, query: String, body: String) -> String {
        let ascii = query.utf8.filter { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }.sorted()
        return md5("kuwotest" + String(bytes: ascii, encoding: .utf8)! + (body.isEmpty ? "" : md5(body + "kuwotest")) + path)
    }
    static func allowedAPI(_ u: URL) -> Bool {
        u.scheme == "https" && ["bd-api.kuwo.cn", "mlyric.kuwo.cn"].contains(u.host?.lowercased() ?? "") && u.user == nil && u.password == nil && (u.port == nil || u.port == 443)
    }
    static func allowedMedia(_ s: String) -> Bool {
        guard let u = URL(string: s), ["https", "http"].contains(u.scheme ?? ""), let h = u.host?.lowercased(), u.user == nil, u.password == nil, u.port == nil else { return false }
        return ["kuwo.cn", "kwcdn.kuwo.cn"].contains { h == $0 || h.hasSuffix("." + $0) }
    }
    static func id(_ s: String) -> Bool { !s.isEmpty && s.count <= 20 && s.utf8.allSatisfy { (48...57).contains($0) } && s.contains(where: { $0 != "0" }) }
    static func song(_ r: [String: Any]) -> [String: Any]? {
        let id = text(r["id"] ?? r["musicId"] ?? r["rid"]), name = text(r["name"] ?? r["musicName"] ?? r["songName"])
        guard Self.id(id), !name.isEmpty else { return nil }
        let artists = r["artists"] as? [[String: Any]] ?? []
        let artist = text(r["artist"]).isEmpty ? artists.map { text($0["name"]) }.joined(separator: " / ") : text(r["artist"])
        let pic = text(r["albumPic"] ?? r["albumPic120"] ?? r["pic"] ?? r["img"] ?? r["cover"])
        let pay = r["payInfo"] as? [String: Any] ?? [:]
        let fee = pay["feeType"] as? [String: Any] ?? [:]
        let vip = text(pay["listen_fragment"]) == "1" || text(fee["vip"]) == "1" || text(fee["song"]) == "1"
        return ["provider": "bodian", "source": "bodian", "type": "bodian", "id": id, "mediaId": id, "name": name, "title": name, "artist": artist, "album": text(r["album"] ?? r["albumName"]), "albumId": text(r["albumId"]), "cover": pic, "pic": pic, "duration": Double(text(r["duration"])) ?? 0, "vipRequired": vip, "trialOnly": text(pay["listen_fragment"]) == "1", "playable": text(pay["cannotOnlinePlay"]) != "1"]
    }
    static func playlist(_ r: [String: Any], source: Int) -> [String: Any]? {
        let id = text(r["id"] ?? r["playListId"] ?? r["playlistId"])
        guard Self.id(id) else { return nil }
        return ["provider": "bodian", "id": id, "name": text(r["name"] ?? r["title"]), "cover": text(r["img"] ?? r["pic"] ?? r["cover"]), "trackCount": Int(text(r["total"] ?? r["musicCount"] ?? r["songCount"])) ?? 0, "source": Int(text(r["sourceType"])) ?? source, "liked": source == 5]
    }
}
