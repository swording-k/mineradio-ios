import Foundation

enum QishuiCatalogContract {
    static let writePaths: Set<String> = ["/luna/pc/me/collection/media", "/luna/pc/me/collection/media/delete", "/luna/pc/me/collection/playlist", "/luna/pc/me/collection/playlist/delete", "/luna/pc/me/collection/album", "/luna/pc/me/collection/album/delete", "/luna/pc/me/playlist/media/append", "/luna/pc/comments/create"]
    static func text(_ value: Any?) -> String {
        if let value = value as? String { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }
    static func truth(_ value: Any?) -> Bool { ["1", "true", "yes", "active", "valid", "enabled"].contains(text(value).lowercased()) }
    static func firstDictionary(_ values: Any?...) -> [String: Any] { values.compactMap { $0 as? [String: Any] }.first { !$0.isEmpty } ?? [:] }
    static func data(_ json: [String: Any]) -> [String: Any] { json["data"] as? [String: Any] ?? json }
    static func allowedAPI(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.fragment == nil, url.port == nil || url.port == 443 else { return false }
        if url.host == "api.qishui.com" {
            return writePaths.contains(url.path) || Set(["/luna/pc/me", "/luna/pc/user/playlist", "/luna/pc/me/collection/mixed", "/luna/pc/me/recently-played-media", "/luna/pc/playlist/detail", "/luna/pc/search/track", "/luna/feed/song-tab", "/luna/pc/feed/song-tab", "/luna/pc/track_v2", "/luna/pc/comments"]).contains(url.path)
        }
        if url.host == "api-vehicle.volcengine.com" { return ["/v2/search/type", "/v2/custom/contents"].contains(url.path) }
        return url.host == "beta-luna.douyin.com" && url.path == "/luna/h5/seo_track"
    }
    static func allowedMedia(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme ?? ""), let host = url.host?.lowercased(), url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 || url.port == 80 else { return false }
        return ["douyincdn.com", "douyinvod.com", "bytecdn.cn", "bytecdn.com", "byteimg.com", "ibytedtos.com", "pstatp.com", "amemv.com", "volces.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func check(_ json: [String: Any]) throws {
        guard let raw = json["status_code"] ?? json["error_code"] else { return }
        guard let code = Int(text(raw)) else { throw QishuiCatalogFailure.invalidResponse }
        if code == 1000016 || code == 401 { throw QishuiCatalogFailure.sessionExpired }
        if code != 0 { throw QishuiCatalogFailure.invalidResponse }
    }
    static func disconnected(expired: Bool = false, error: String = "") -> [String: Any] {
        ["provider": "qishui", "loggedIn": false, "configured": false, "webSession": false, "profileReady": false,
         "sessionValidated": false, "libraryReady": false, "membershipKnown": false, "isVip": false, "isSvip": false,
         "vipLevel": "unknown", "vipLabel": "会员权益待核验", "reauthRequired": expired, "stale": !error.isEmpty && !expired,
         "error": error, "message": expired ? "汽水登录状态已失效，请重新扫码。" : (error.isEmpty ? "请先扫码连接汽水音乐。" : error)]
    }
    static func unsupported() -> [String: Any] { ["provider": "qishui", "ok": false, "supported": false, "code": 501, "error": "APPLE_CAPABILITY_NOT_IMPLEMENTED", "message": "此汽水功能尚未完成 Apple 端适配。"] }
    static func comment(_ raw: [String: Any]) -> [String: Any] {
        let row = firstDictionary(raw["comment"], raw["comment_info"], raw["commentInfo"], raw)
        let user = firstDictionary(row["user"], row["user_info"], row["userInfo"], row["author"], raw["user"], raw["author"])
        func pick(_ keys: [String], _ source: [String: Any]) -> String { keys.map { text(source[$0]) }.first { !$0.isEmpty } ?? "" }
        let time = Double(pick(["create_time", "createTime", "created_at", "createdAt", "time"], row)) ?? 0
        return ["id": pick(["id", "comment_id", "commentId"], row), "content": pick(["text", "content", "comment_text", "commentText"], row), "likedCount": Double(pick(["like_count", "likeCount", "digg_count", "diggCount", "liked_count"], row)) ?? 0,
                "time": time > 0 && time < 10000000000 ? time * 1000 : time,
                "user": ["id": pick(["id", "user_id", "userId", "uid"], user), "nickname": pick(["nickname", "nick_name", "nickName", "name"], user), "avatar": image(user["avatar_url"], user["avatarUrl"], user["avatar"], user["medium_avatar_url"], user["larger_avatar_url"])]]
    }
    static func image(_ values: Any?...) -> String {
        func read(_ value: Any?, _ depth: Int) -> String {
            if depth > 4 { return "" }
            if let s = value as? String, let url = URL(string: s), allowedMedia(url) { return s }
            if let list = value as? [Any] { return list.map { read($0, depth + 1) }.first { !$0.isEmpty } ?? "" }
            if let node = value as? [String: Any] {
                let keys = ["urls", "url_list", "urlList", "url", "main_url", "cover_url", "image_url"]
                for key in keys { let result = read(node[key], depth + 1); if !result.isEmpty { return result } }
            }
            return ""
        }
        return values.map { read($0, 0) }.first { !$0.isEmpty } ?? ""
    }
    static func profile(_ json: [String: Any]) -> [String: Any] {
        let raw = data(json), user = firstDictionary(raw["my_info"], raw["myInfo"], raw["user"], raw["user_info"], raw["userInfo"], raw["account"], raw["me"], raw)
        func pick(_ keys: [String], _ source: [String: Any]) -> String { keys.map { text(source[$0]) }.first { !$0.isEmpty } ?? "" }
        let uid = pick(["user_id", "userId", "id", "uid", "sec_uid", "secUid", "open_id"], user)
        var result: [String: Any] = ["userId": uid.isEmpty ? pick(["user_id", "userId", "uid", "id"], raw) : uid,
                                     "nickname": pick(["nickname", "nick_name", "nickName", "display_name", "displayName", "name", "public_name", "douyin_id"], user),
                                     "avatar": image(user["larger_avatar_url"], user["medium_avatar_url"], user["avatar_url"], user["avatarUrl"], user["avatar"], user["pic"]),
                                     "douyinId": pick(["douyin_id", "unique_id", "short_id"], user)]
        result.merge(membership(raw)) { _, b in b }; return result
    }
    private static func membership(_ raw: [String: Any]) -> [String: Any] {
        var known = false, vip = false, svip = false, expiry = 0.0
        let vipKeys = Set(["isvip", "ismember", "hasvip", "hasmembership", "vipactive", "vipenabled", "viptype", "viplevel", "membertype", "memberlevel", "musicviptype", "musicviplevel"])
        let svipKeys = Set(["issvip", "issupervip", "hassvip", "svipactive", "svipenabled", "sviptype", "sviplevel", "superviptype", "superviplevel"])
        func positive(_ value: Any) -> Bool { if let n = value as? NSNumber { return n.doubleValue > 0 }; return truth(value) || ["vip", "svip", "premium", "member"].contains(text(value).lowercased()) }
        func normalized(_ s: String) -> String { String(s.lowercased().filter { $0.isLetter || $0.isNumber }) }
        func visit(_ node: [String: Any], _ depth: Int) {
            guard depth < 5 else { return }
            var fields: [String: Any] = [:]; node.forEach { fields[normalized($0.key)] = $0.value }
            var localExpiry = 0.0
            for (key, value) in fields where key.contains("expire") || key == "endtime" || key == "validuntil" {
                var t = Double(text(value)) ?? 0; if t > 0 && t < 10_000_000_000 { t *= 1000 }
                if t > 0 { localExpiry = localExpiry == 0 ? t : min(t, localExpiry) }
            }
            let explicitlyInactive = ["active", "valid", "enabled", "status"].contains { key in
                guard let value = fields[key] else { return false }
                return ["0", "false", "expired", "inactive", "invalid", "disabled"].contains(text(value).lowercased())
            }
            let active = !explicitlyInactive && (localExpiry == 0 || localExpiry > Date().timeIntervalSince1970 * 1000)
            for (key, value) in fields {
                if vipKeys.contains(key) { known = true; if active && positive(value) { vip = true; expiry = max(expiry, localExpiry) } }
                if svipKeys.contains(key) { known = true; if active && positive(value) { svip = true; vip = true; expiry = max(expiry, localExpiry) } }
                if let child = value as? [String: Any], ["myinfo", "user", "userinfo", "account", "me", "vipinfo", "vipdetail", "svipinfo", "svipdetail", "memberinfo", "membershipinfo", "membershipdetail"].contains(key) { visit(child, depth + 1) }
            }
        }
        visit(raw, 0)
        return ["membershipKnown": known, "isVip": vip, "isSvip": svip, "vipType": svip ? 2 : vip ? 1 : 0,
                "vipLevel": !known ? "unknown" : svip ? "svip" : vip ? "vip" : "none",
                "vipLabel": !known ? "会员权益待核验" : svip ? "SVIP" : vip ? "VIP" : "无VIP", "expiresAt": expiry]
    }
    static func mediaList(_ payload: [String: Any]) -> [[String: Any]] {
        let root = data(payload)
        let keys = ["media_resources", "media_list", "related_media", "medias", "media", "tracks", "track_list", "songs", "items", "list", "result", "song_list", "recommend_media_list", "data"]
        for key in keys { if let list = root[key] as? [[String: Any]], !list.isEmpty { return list } }
        var best: [[String: Any]] = []
        func visit(_ value: Any, _ depth: Int) {
            guard depth <= 5 else { return }
            if let list = value as? [[String: Any]] {
                let media = list.filter { $0["media"] != nil || $0["track_entity"] != nil || $0["track_wrapper"] != nil || $0["base_info"] != nil || $0["media_id"] != nil }
                if media.count > best.count { best = media }
                list.prefix(100).forEach { visit($0, depth + 1) }
            } else if let dict = value as? [String: Any] { dict.values.prefix(80).forEach { visit($0, depth + 1) } }
        }
        visit(root, 0); return best
    }
    static func songs(_ list: [[String: Any]]) -> [[String: Any]] {
        var seen = Set<String>()
        return list.compactMap { raw in
            if raw["playlist_id"] != nil || raw["count_tracks"] != nil || raw["playlist"] != nil { return nil }
            let entity = firstDictionary(raw["entity"], raw["data"], raw), media = firstDictionary(entity["media"], raw["media"], entity)
            let wrapper = firstDictionary(entity["track_wrapper"], media["track_wrapper"], raw["track_wrapper"])
            let track = firstDictionary(wrapper["track"], media["track_entity"], raw["track_entity"], media["track"], raw["track"], media)
            let base = firstDictionary(track["base_info"], media["base_info"], raw["base_info"], track)
            let display = firstDictionary(track["display_info"], media["display_info"], raw["display_info"])
            let related = firstDictionary(track["related_info"], media["related_info"], raw["related_info"])
            let id = [base["id"], track["id"], media["id"], raw["id"], raw["media_id"], raw["item_id"]].map(text).first { !$0.isEmpty } ?? ""
            let name = [base["name"], base["title"], track["name"], track["title"], raw["name"], raw["title"]].map(text).first { !$0.isEmpty } ?? ""
            guard !id.isEmpty, !name.isEmpty, seen.insert(id).inserted else { return nil }
            var artists = (related["artist_links"] as? [[String: Any]] ?? related["artists"] as? [[String: Any]] ?? base["artists"] as? [[String: Any]] ?? track["artists"] as? [[String: Any]] ?? []).compactMap { item -> [String: Any]? in
                let name = [item["name"], item["display_name"], item["title"], item["artist_name"]].map(text).first { !$0.isEmpty } ?? ""
                return name.isEmpty ? nil : ["name": name, "id": text(item["id"] ?? item["artist_id"])]
            }
            if artists.isEmpty { let fallback = [base["artist_name"], display["artist_name"], raw["artist_name"], (raw["author_info"] as? [String: Any])?["name"], raw["author"]].map(text).first { !$0.isEmpty } ?? ""; if !fallback.isEmpty { artists = [["id": "", "name": fallback]] } }
            let album = firstDictionary(related["album_link"], related["album"], base["album"], display["album"], track["album"])
            let duration = seconds(base["duration_ms"] ?? base["duration"] ?? track["duration_ms"] ?? track["duration"] ?? raw["duration"])
            return ["provider": "qishui", "source": "qishui", "type": "qishui", "id": id, "providerSongId": id, "name": name,
                    "artist": artists.compactMap { $0["name"] as? String }.joined(separator: " / "), "artists": artists,
                    "album": text(album["name"] ?? album["title"] ?? base["album_name"]), "albumId": text(album["id"]),
                    "cover": image(display["cover_url"], display["url_cover"], base["cover_url"], base["url_cover"], album["cover_url"], track["cover_url"], raw["cover"]),
                    "duration": duration, "fee": truth((track["label_info"] as? [String: Any])?["only_vip_playable"]) ? 1 : 0,
                    "playable": true, "playbackMode": "direct-url", "recommendationSource": "qishui-pc-session"]
        }
    }
    static func playlists(_ json: [String: Any]) -> [[String: Any]] {
        var result: [[String: Any]] = [], seen = Set<String>()
        func visit(_ value: Any, _ depth: Int) {
            guard depth <= 6 else { return }
            if let list = value as? [Any] { list.prefix(200).forEach { visit($0, depth + 1) }; return }
            guard let item = value as? [String: Any] else { return }
            let id = text(item["playlist_id"] ?? item["playlistId"] ?? item["collection_id"] ?? item["id"])
            let name = text(item["title"] ?? item["public_title"] ?? item["name"] ?? item["playlist_name"])
            let count = Int(text(item["count_tracks"] ?? item["track_count"] ?? item["media_count"] ?? item["song_count"])) ?? 0
            let kind = text(item["type"] ?? item["resource_type"]).lowercased()
            if !id.isEmpty, !name.isEmpty, count > 0 || kind.contains("playlist") || name.contains("喜欢") || name.contains("歌单"), seen.insert(id).inserted {
                result.append(["provider": "qishui", "source": "qishui", "type": "playlist", "id": id, "name": name,
                               "cover": image(item["cover_url"], item["cover"], item["image"]), "trackCount": count,
                               "creator": text(item["creator_name"] ?? item["author_name"]), "subscribed": true, "virtual": false, "webSession": true])
            }
            item.values.prefix(80).forEach { visit($0, depth + 1) }
        }
        visit(data(json), 0); return result
    }
    static func virtualPlaylist(_ id: String, _ name: String, tracks: [[String: Any]]) -> [String: Any] {
        ["provider": "qishui", "source": "qishui", "type": "playlist", "id": id, "name": name, "cover": tracks.first?["cover"] ?? "",
         "trackCount": tracks.count, "creator": "汽水音乐", "subscribed": false, "owned": true, "shelfPane": "mine", "virtual": true, "webSession": true]
    }
    static func seconds(_ value: Any?) -> Double { let n = Double(text(value)) ?? 0; return n > 1000 ? n / 1000 : n }
    static func lyrics(_ payload: [String: Any]) -> [String: Any] {
        var lyric = "", translated = "", visited = 0
        func lyricText(_ value: Any?, _ depth: Int = 0) -> String {
            guard depth <= 4 else { return "" }
            if let value = value as? String { return value.hasPrefix("http") ? "" : value }
            guard let dict = value as? [String: Any] else { return "" }
            for key in ["lyric_entity", "lyricEntity", "original_lyric", "content", "lyric_text", "text", "original_content"] { let s = lyricText(dict[key], depth + 1); if !s.isEmpty { return s } }
            return ""
        }
        func visit(_ value: Any, _ path: String, _ depth: Int) {
            guard depth <= 7, visited < 600 else { return }; visited += 1
            if let list = value as? [Any] { list.prefix(100).forEach { visit($0, path, depth + 1) }; return }
            guard let dict = value as? [String: Any] else { return }
            for (key, value) in dict.prefix(120) {
                let next = path + "." + key.lowercased()
                if key.lowercased().contains("lyric") || key.lowercased().contains("translation") {
                    let s = lyricText(value)
                    if !s.isEmpty { if next.contains("translat") || next.contains("tlyric") { if translated.isEmpty { translated = s } } else if lyric.isEmpty { lyric = s } }
                }
                if !["album_tracks", "artist_tracks", "chart_tracks", "comments", "recommend_media_list"].contains(key) { visit(value, next, depth + 1) }
            }
        }
        visit(payload, "", 0)
        let original = convertTimedLyric(lyric), translation = convertTimedLyric(translated)
        return ["provider": "qishui", "lyric": original.0, "tlyric": translation.0, "yrc": original.1, "ytlrc": translation.1, "source": "qishui-official-track"]
    }
    private static func convertTimedLyric(_ input: String) -> (String, String) {
        let linePattern = try! NSRegularExpression(pattern: #"^\[(\d+),(\d+)\](.*)$"#)
        let wordPattern = try! NSRegularExpression(pattern: #"([<(])(\d+),(\d+),(\d+)[>)]([^<(]*)"#)
        var lrc: [String] = [], yrc: [String] = []
        for line in input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").split(separator: "\n") {
            let source = String(line).trimmingCharacters(in: .whitespaces), ns = source as NSString
            guard let match = linePattern.firstMatch(in: source, range: NSRange(location: 0, length: ns.length)) else { continue }
            let start = Int(ns.substring(with: match.range(at: 1))) ?? 0, duration = Int(ns.substring(with: match.range(at: 2))) ?? 0
            let body = ns.substring(with: match.range(at: 3)), bodyNS = body as NSString
            let words = wordPattern.matches(in: body, range: NSRange(location: 0, length: bodyNS.length))
            var text = "", yrcBody = ""
            for word in words {
                let raw = Int(bodyNS.substring(with: word.range(at: 2))) ?? 0, wordDuration = Int(bodyNS.substring(with: word.range(at: 3))) ?? 0
                let content = bodyNS.substring(with: word.range(at: 5))
                let absolute = bodyNS.substring(with: word.range(at: 1)) == "<" ? start + raw : (raw >= max(0, start - 500) ? raw : start + raw)
                text += content; yrcBody += "(\(absolute),\(wordDuration),\(bodyNS.substring(with: word.range(at: 4))))" + content
            }
            if text.isEmpty { text = wordPattern.stringByReplacingMatches(in: body, range: NSRange(location: 0, length: bodyNS.length), withTemplate: "$5") }
            text = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            guard !text.isEmpty else { continue }
            lrc.append(String(format: "[%02d:%02d.%02d]", start / 60000, (start % 60000) / 1000, (start % 1000) / 10) + text)
            yrc.append("[\(start),\(duration)]" + (yrcBody.isEmpty ? text : yrcBody))
        }
        return lrc.isEmpty ? (input, "") : (lrc.joined(separator: "\n"), yrc.joined(separator: "\n"))
    }
    static func playbackUnavailable(_ reason: String = "apple_signer_unavailable") -> [String: Any] {
        ["provider": "qishui", "playable": false, "playbackKeyReady": false, "reason": reason,
         "message": "汽水未提供 Apple 端可直接播放的音源；桌面原生签名或加密播放适配尚不可用于 iOS。"]
    }
    static func playback(_ json: [String: Any], membership: [String: Any], publicSource: Bool, expectedID: String? = nil) -> [String: Any] {
        let raw = data(json), track = firstDictionary(raw["track"], raw["track_info"], raw["trackInfo"], (raw["seo_track"] as? [String: Any])?["track"])
        if let expectedID {
            let returned = text(track["id"] ?? track["track_id"] ?? (track["base_info"] as? [String: Any])?["id"])
            guard returned == expectedID else { return playbackUnavailable("track_mismatch") }
        }
        let full = seconds(track["duration_ms"] ?? track["duration"]), audition = seconds((track["audition_info"] as? [String: Any])?["duration_ms"])
        let required = truth((track["label_info"] as? [String: Any])?["only_vip_playable"])
        let requiredSvip = truth((track["label_info"] as? [String: Any])?["only_svip_playable"])
        var candidates: [(String, Double, Double, String)] = []
        var visits = 0
        func visit(_ value: Any, _ depth: Int) {
            guard depth <= 9, visits < 1200 else { return }; visits += 1
            if let list = value as? [Any] { list.prefix(100).forEach { visit($0, depth + 1) }; return }
            if let s = value as? String, s.first == "{", let bytes = s.data(using: .utf8), let nested = try? JSONSerialization.jsonObject(with: bytes) { visit(nested, depth + 1); return }
            guard let node = value as? [String: Any] else { return }
            let encrypted = ["play_auth", "PlayAuth", "spade_a", "SpadeA"].contains { !text(node[$0]).isEmpty } || !(firstDictionary(node["encrypt_info"], node["EncryptInfo"])).isEmpty
            if !encrypted {
                for key in ["url", "play_url", "main_play_url", "main_url", "MainPlayUrl", "MainUrl", "playUrl"] {
                    var s = text(node[key]); if key == "MainPlayUrl" || key == "MainUrl", !s.hasPrefix("http"), let bytes = Data(base64Encoded: s), let decoded = String(data: bytes, encoding: .utf8) { s = decoded }
                    if let url = URL(string: s), allowedMedia(url), !["jpg", "jpeg", "png", "webp", "gif"].contains(url.pathExtension.lowercased()) {
                        let bitrate = Double(text(node["bitrate"] ?? node["Bitrate"])) ?? 0
                        let kbps = bitrate > 1000 ? bitrate / 1000 : bitrate
                        let quality = text(node["quality"] ?? node["Quality"] ?? node["definition"] ?? node["Definition"]).lowercased()
                        let format = text(node["format"] ?? node["Format"]).lowercased()
                        let explicitTier = text(node["requiredTier"] ?? node["required_tier"] ?? node["membershipTier"] ?? node["membership_tier"]).lowercased()
                        let svip = explicitTier == "svip" || ["svip", "supervip", "hires", "highres", "master", "atmos", "dolby", "spatial"].contains { quality.contains($0) }
                        let vip = explicitTier == "vip" || kbps > 192 || ["lossless", "flac", "sq", "highest", "excellent", "higher", "hq", "exhigh", "320"].contains { quality.contains($0) } || ["flac", "alac", "wav"].contains(format)
                        candidates.append((s, seconds(node["duration"] ?? node["Duration"]), bitrate, svip ? "svip" : vip ? "vip" : "free"))
                    }
                }
                node.values.prefix(100).forEach { visit($0, depth + 1) }
            }
        }
        visit(track, 0)
        for (url, duration, bitrate, tier) in candidates.sorted(by: { $0.2 < $1.2 }) {
            let trial = duration > 0 && full > 0 && duration + 5 < full
            if publicSource {
                // Public H5 is only accepted as an explicitly described audition.
                guard audition > 0, audition <= 120, duration > 0, duration <= audition + 1, trial, tier == "free" else { continue }
            } else if !trial && (tier != "free" || required || requiredSvip) {
                guard membership["membershipKnown"] as? Bool == true, membership[tier == "svip" || requiredSvip ? "isSvip" : "isVip"] as? Bool == true else { continue }
            }
            if !trial && (duration <= 0 || full <= 0) { continue }
            return ["provider": "qishui", "source": publicSource ? "qishui-public-audition" : "qishui-pc-track-v2", "url": url,
                    "playable": true, "trial": trial, "duration": duration, "fullDuration": full, "trialDuration": trial ? duration : 0,
                    "level": "standard", "br": bitrate, "message": trial ? "此音源为平台返回的试听片段。" : ""]
        }
        return playbackUnavailable()
    }
}
