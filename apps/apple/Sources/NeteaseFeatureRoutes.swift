import Foundation

// Port the original server.js contracts and the installed GPL-compatible
// NeteaseCloudMusicApi module payloads. All sessions stay in the existing native transport.
extension NeteaseNativeAPI {
    static let featureRoutes: Set<String> = [
        "/api/song/like/check", "/api/song/like", "/api/playlist/create", "/api/playlist/add-song",
        "/api/playlist/subscribe", "/api/album/detail", "/api/album/subscribe", "/api/album/subscribe/check",
        "/api/artist/detail", "/api/song/comments", "/api/song/comments/like", "/api/podcast/search",
        "/api/podcast/hot", "/api/podcast/detail", "/api/podcast/programs", "/api/podcast/my", "/api/podcast/my/items"
    ]

    func handleFeature(_ url: URL, method: String, body: Data) async throws -> [String: Any]? {
        guard Self.featureRoutes.contains(url.path) else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var input: [String: Any] = [:]
        if !body.isEmpty {
            guard let decoded = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return featureError("INVALID_JSON") }
            input = decoded
        }
        func value(_ names: String...) -> String {
            for name in names {
                if let found = input[name], !(found is NSNull) { return String(describing: found) }
                if let found = query.first(where: { $0.name == name })?.value { return found }
            }
            return ""
        }
        func number(_ key: String, _ fallback: Int, _ maxValue: Int) -> Int { min(maxValue, max(0, Int(value(key)) ?? fallback)) }
        func flag(_ key: String) -> Bool { !["false", "0"].contains(value(key).lowercased()) }
        func identifier(_ text: String) -> Bool { !text.isEmpty && text.utf8.count < 24 && text.utf8.allSatisfy { (48...57).contains($0) } }
        let id = value("id", "albumId", "playlistId", "rid")
        let writes: Set<String> = ["/api/song/like", "/api/playlist/create", "/api/playlist/add-song", "/api/playlist/subscribe", "/api/album/subscribe", "/api/song/comments/like"]
        let writing = writes.contains(url.path) || (url.path == "/api/song/comments" && method == "POST")
        if writing && method != "POST" { return featureError("METHOD_NOT_ALLOWED", code: 405) }
        if !writing && method != "GET" { return featureError("METHOD_NOT_ALLOWED", code: 405) }
        var account: [String: Any] = [:]
        if writing || ["/api/song/like/check", "/api/album/subscribe/check", "/api/podcast/my", "/api/podcast/my/items"].contains(url.path) {
            account = try await status()
            guard account["loggedIn"] as? Bool == true else {
                return ["loggedIn": false, "success": false, "created": false, "error": "NETEASE_AUTH_REQUIRED", "message": "请先连接网易云账号。", "items": [], "collections": []]
            }
        }
        switch url.path {
        case "/api/song/like/check":
            let ids = value("ids", "id").split(separator: ",").map(String.init)
            guard !ids.isEmpty, ids.count <= 200, ids.allSatisfy(identifier) else { return featureError("INVALID_SONG_IDS") }
            let result = try await transport.call("/api/song/like/get", ["uid": account["userId"] ?? ""])
            if let failure = platformFailure(result) { return failure }
            guard let raw = result["ids"] as? [Any] else { return featureError("INVALID_PLATFORM_RESPONSE", code: 502) }
            let liked = Set(raw.map { String(describing: $0) })
            return ["loggedIn": true, "ids": ids, "liked": Dictionary(uniqueKeysWithValues: Set(ids).map { ($0, liked.contains($0)) })]
        case "/api/song/like":
            guard identifier(id) else { return featureError("INVALID_SONG_ID") }
            let liked = flag("like")
            let response = try await transport.call("/api/radio/like", ["trackId": id, "like": liked, "alg": "itembased", "time": "3"])
            return mutation(response, fields: ["id": id, "liked": liked])
        case "/api/playlist/create":
            let name = value("name").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 200 else { return featureError("INVALID_PLAYLIST_NAME") }
            let privacy = value("privacy") == "10" ? "10" : "0"
            let result = try await transport.call("/api/playlist/create", ["name": name, "privacy": privacy, "type": "NORMAL"])
            if let failure = platformFailure(result) { return failure }
            guard let created = result["playlist"] as? [String: Any] ?? result["data"] as? [String: Any], created["id"] != nil else { return featureError("INVALID_PLATFORM_RESPONSE", code: 502) }
            return ["loggedIn": true, "success": true, "playlist": NeteaseContract.playlist(created)]
        case "/api/playlist/add-song":
            let pid = value("pid", "playlistId"), ids = value("ids", "id").split(separator: ",").map(String.init)
            guard identifier(pid), !ids.isEmpty, ids.count <= 200, ids.allSatisfy(identifier) else { return featureError("INVALID_PLAYLIST_OR_SONG_IDS") }
            let encoded = String(decoding: try JSONSerialization.data(withJSONObject: ids), as: UTF8.self)
            let result = try await transport.call("/api/playlist/manipulate/tracks", ["op": "add", "pid": pid, "trackIds": encoded, "imme": "true"])
            return mutation(result, fields: ["pid": pid, "id": ids.joined(separator: ",")])
        case "/api/playlist/subscribe", "/api/album/subscribe":
            guard identifier(id) else { return featureError("INVALID_COLLECTION_ID") }
            let subscribed = flag("subscribed")
            let path = url.path == "/api/playlist/subscribe" ? "/api/playlist/\(subscribed ? "subscribe" : "unsubscribe")" : "/api/album/\(subscribed ? "sub" : "unsub")"
            return mutation(try await transport.call(path, ["id": id]), fields: ["provider": "netease", "id": id, "subscribed": subscribed])
        case "/api/album/subscribe/check":
            let ids = value("ids", "id").split(separator: ",").map(String.init)
            guard !ids.isEmpty, ids.count <= 200, ids.allSatisfy(identifier) else { return featureError("INVALID_ALBUM_IDS") }
            var found = Set<String>(), offset = 0
            for _ in 0..<8 {
                let result = try await transport.call("/api/album/sublist", ["limit": 50, "offset": offset, "total": true])
                if let failure = platformFailure(result) { return failure }
                guard let rows = result["data"] as? [[String: Any]] ?? result["albums"] as? [[String: Any]] else { return featureError("INVALID_PLATFORM_RESPONSE", code: 502) }
                found.formUnion(rows.compactMap { $0["id"].map { String(describing: $0) } })
                if Set(ids).isSubset(of: found) || result["hasMore"] as? Bool != true || rows.isEmpty { break }
                offset += rows.count
            }
            return ["provider": "netease", "ids": ids, "subscribed": Dictionary(uniqueKeysWithValues: Set(ids).map { ($0, found.contains($0)) })]
        case "/api/album/detail":
            guard identifier(id) else { return featureError("INVALID_ALBUM_ID") }
            let result = try await transport.call("/api/v1/album/\(id)", [:])
            if let failure = platformFailure(result) { return failure }
            let album = result["album"] as? [String: Any] ?? [:]
            let songs = result["songs"] as? [[String: Any]] ?? album["songs"] as? [[String: Any]] ?? []
            let artists = album["artists"] as? [[String: Any]] ?? []
            return ["provider": "netease", "album": ["provider": "netease", "id": album["id"] ?? id, "albumId": album["id"] ?? id,
                    "name": album["name"] ?? "", "artist": artists.compactMap { $0["name"] as? String }.joined(separator: " / "), "artists": artists,
                    "cover": album["picUrl"] ?? "", "releaseDate": album["publishTime"] ?? "", "trackCount": album["size"] ?? songs.count],
                    "songs": songs.prefix(max(1, number("limit", 80, 120))).map(NeteaseContract.song), "total": album["size"] ?? songs.count]
        case "/api/artist/detail":
            guard identifier(id) else { return featureError("INVALID_ARTIST_ID") }
            let detail = try await transport.call("/api/artist/head/info/get", ["id": id])
            if let failure = platformFailure(detail) { return failure }
            let data = detail["data"] as? [String: Any] ?? detail
            let artist = data["artist"] as? [String: Any] ?? [:]
            let limit = max(1, number("limit", 30, 80))
            var tracks = try await transport.call("/api/v1/artist/songs", ["id": id, "private_cloud": "true", "work_type": 1, "order": "hot", "limit": limit, "offset": 0])
            if tracks["songs"] as? [[String: Any]] == nil || (tracks["songs"] as? [[String: Any]])?.isEmpty == true {
                tracks = try await transport.call("/api/artist/top/song", ["id": id])
            }
            if let failure = platformFailure(tracks) { return failure }
            return ["id": id, "artist": ["id": artist["id"] ?? id, "name": artist["name"] ?? "", "avatar": artist["avatar"] ?? artist["cover"] ?? "",
                    "brief": artist["briefDesc"] ?? "", "musicSize": artist["musicSize"] ?? 0, "albumSize": artist["albumSize"] ?? 0],
                    "songs": (tracks["songs"] as? [[String: Any]] ?? []).prefix(limit).map(NeteaseContract.song)]
        case "/api/song/comments":
            guard identifier(id) else { return featureError("INVALID_SONG_ID") }
            if method == "POST" {
                let content = value("content", "text").trimmingCharacters(in: .whitespacesAndNewlines), reply = value("replyTo")
                guard !content.isEmpty, content.count <= 2000, reply.isEmpty || identifier(reply) else { return featureError("INVALID_COMMENT") }
                var fields: [String: Any] = ["threadId": "R_SO_4_" + id, "content": content]
                if !reply.isEmpty { fields["commentId"] = reply }
                let result = try await transport.call("/api/resource/comments/\(reply.isEmpty ? "add" : "reply")", fields)
                return mutation(result, fields: ["provider": "netease", "id": id, "created": true])
            }
            let offset = number("offset", 0, 100000)
            let result = try await transport.call("/api/v1/resource/comments/R_SO_4_\(id)", ["rid": id, "limit": max(1, number("limit", 20, 50)), "offset": offset, "beforeTime": 0])
            if let failure = platformFailure(result) { return failure }
            let hot = offset == 0 && result["hotComments"] is [[String: Any]]
            let rows = (hot ? result["hotComments"] : result["comments"]) as? [[String: Any]] ?? []
            return ["id": id, "total": result["total"] ?? 0, "hot": hot, "comments": rows.map { row -> [String: Any] in
                let user = row["user"] as? [String: Any] ?? [:]
                return ["id": row["commentId"] ?? "", "content": row["content"] ?? "", "likedCount": row["likedCount"] ?? 0, "time": row["time"] ?? 0,
                        "user": ["id": user["userId"] ?? "", "nickname": user["nickname"] ?? "", "avatar": user["avatarUrl"] ?? ""]]
            }]
        case "/api/song/comments/like":
            let cid = value("commentId", "cid"), liked = flag("liked")
            guard identifier(id), identifier(cid) else { return featureError("INVALID_COMMENT_ID") }
            return mutation(try await transport.call("/api/v1/comment/\(liked ? "like" : "unlike")", ["threadId": "R_SO_4_" + id, "commentId": cid]), fields: ["id": id, "commentId": cid, "liked": liked])
        case "/api/podcast/search":
            let keywords = value("keywords").trimmingCharacters(in: .whitespacesAndNewlines)
            if keywords.isEmpty { return ["podcasts": [], "total": 0] }
            let result = try await transport.call("/api/cloudsearch/pc", ["s": keywords, "type": 1009, "limit": max(1, number("limit", 18, 30)), "offset": number("offset", 0, 100000), "total": true])
            if let failure = platformFailure(result) { return failure }
            let data = result["result"] as? [String: Any] ?? [:]
            let rows = NeteaseFeatureContract.rows(data, keys: ["djRadios", "djradios", "radios"])
            return ["podcasts": rows.map(NeteaseFeatureContract.radio), "total": data["djRadiosCount"] ?? rows.count]
        case "/api/podcast/hot":
            let result = try await transport.call("/api/djradio/hot/v1", ["limit": max(1, number("limit", 18, 30)), "offset": number("offset", 0, 100000)])
            if let failure = platformFailure(result) { return failure }
            return ["podcasts": NeteaseFeatureContract.rows(result, keys: ["djRadios", "djradios", "radios", "data"]).map(NeteaseFeatureContract.radio), "more": result["hasMore"] ?? false]
        case "/api/podcast/detail":
            guard identifier(id) else { return featureError("INVALID_PODCAST_ID") }
            let result = try await transport.call("/api/djradio/v2/get", ["id": id])
            if let failure = platformFailure(result) { return failure }
            return ["podcast": NeteaseFeatureContract.radio(result["data"] as? [String: Any] ?? result["djRadio"] as? [String: Any] ?? [:])]
        case "/api/podcast/programs":
            guard identifier(id) else { return featureError("INVALID_PODCAST_ID") }
            let offset = number("offset", 0, 100000), limit = max(1, number("limit", 30, 60))
            let result = try await transport.call("/api/dj/program/byradio", ["radioId": id, "limit": limit, "offset": offset, "asc": false])
            if let failure = platformFailure(result) { return failure }
            let rows = NeteaseFeatureContract.rows(result, keys: ["programs", "data"])
            let radio = rows.first?["radio"] as? [String: Any] ?? ["id": id]
            return ["radio": NeteaseFeatureContract.radio(radio), "programs": rows.map { NeteaseFeatureContract.program($0, radio: radio) }, "more": result["more"] ?? false,
                    "total": result["count"] ?? rows.count, "nextOffset": offset + rows.count, "offset": offset, "limit": limit]
        case "/api/podcast/my/items":
            let key = value("key").isEmpty ? "collect" : value("key")
            guard ["collect", "created", "liked"].contains(key) else { return featureError("INVALID_PODCAST_COLLECTION") }
            let items = try await podcastItems(key, userID: account["userId"] ?? "", limit: max(1, number("limit", 48, 60)), offset: number("offset", 0, 100000))
            return ["loggedIn": true, "key": key, "itemType": key == "liked" ? "voice" : "radio", "items": items,
                    "title": NeteaseFeatureContract.collectionTitle(key), "count": items.count, "cover": items.first?["cover"] ?? ""]
        case "/api/podcast/my":
            var collections: [[String: Any]] = []
            for key in ["collect", "created", "liked"] {
                let items = try await podcastItems(key, userID: account["userId"] ?? "", limit: 12, offset: 0)
                collections.append(["key": key, "title": NeteaseFeatureContract.collectionTitle(key), "sub": "", "itemType": key == "liked" ? "voice" : "radio", "count": items.count, "cover": items.first?["cover"] ?? ""])
            }
            return ["loggedIn": true, "collections": collections]
        default: return nil
        }
    }

    private func podcastItems(_ key: String, userID: Any, limit: Int, offset: Int) async throws -> [[String: Any]] {
        var result: [String: Any]
        switch key {
        case "collect": result = try await transport.call("/api/djradio/get/subed", ["limit": limit, "offset": offset, "total": true])
        case "created": result = try await transport.call("/api/djradio/get/byuser", ["userId": userID])
        default:
            result = (try? await transport.call("/api/voice/sati/resource/sub/list", [:])) ?? [:]
            if NeteaseFeatureContract.rows(result, keys: ["data", "resources", "list"]).isEmpty {
                result = try await transport.call("/api/play-record/voice/list", ["limit": limit])
            }
        }
        if let failure = platformFailure(result) { throw NSError(domain: "Mineradio.Netease", code: (failure["code"] as? Int) ?? 502, userInfo: [NSLocalizedDescriptionKey: failure["message"] ?? "播客获取失败"] ) }
        let rows = NeteaseFeatureContract.rows(result, keys: ["djRadios", "djradios", "radios", "data", "resources", "list"])
        return rows.map { key == "liked" ? NeteaseFeatureContract.voice($0) : NeteaseFeatureContract.collectionRadio($0, key: key) }
    }

    private func featureError(_ error: String, code: Int = 400) -> [String: Any] {
        ["ok": false, "success": false, "created": false, "error": error, "code": code]
    }
    private func platformFailure(_ result: [String: Any]) -> [String: Any]? {
        guard let code = (result["code"] as? NSNumber)?.intValue, code == 200, result["error"] == nil else {
            var failure = featureError("NETEASE_REQUEST_FAILED", code: (result["code"] as? NSNumber)?.intValue ?? 502)
            failure["message"] = result["message"] ?? result["msg"] ?? "网易云未接受该操作，请检查账号和平台提示。"
            return failure
        }
        return nil
    }
    private func mutation(_ result: [String: Any], fields: [String: Any]) -> [String: Any] {
        if let failure = platformFailure(result) { return failure }
        return fields.merging(["loggedIn": true, "success": true, "code": 200]) { _, new in new }
    }
}
