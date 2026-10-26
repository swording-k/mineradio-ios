import Foundation
import Security

/// Spotify metadata/library adapter. Never returns OAuth credentials to WebKit.
/// Playback uses the original authorized-provider matching flow, not Spotify DRM.
actor SpotifyNativeAPI {
    private struct Token: Codable { var access: String; var refresh: String; var expiry: Date }
    private struct Attempt { let verifier: String; let state: String; let started: Date; let generation: Int }
    private let clientID: String
    private let transport: any SpotifyRequesting
    private let keychainService: String?
    private var token: Token?
    private var attempt: Attempt?
    private var generation = 0
    private var refreshJob: Task<Token, Error>?
    private var profile: [String: Any]?
    private var profileChecked = Date.distantPast
    private var rateLimitUntil = Date.distantPast

    init(clientID: String = Bundle.main.object(forInfoDictionaryKey: "MineradioSpotifyClientID") as? String ?? "", transport: any SpotifyRequesting = SpotifyTransport(), keychainService: String? = "com.swordingk.mineradio.spotify.apple") {
        self.clientID = SpotifyContract.clientID(clientID); self.transport = transport; self.keychainService = keychainService
        // Scope storage to the registered app: changing Client ID never reuses
        // a token granted to a different Spotify application.
        if let service = keychainService, !self.clientID.isEmpty {
            var value: CFTypeRef?
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: self.clientID, kSecReturnData as String: true]
            if SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data { token = try? JSONDecoder().decode(Token.self, from: data) }
        }
    }
    private func persist() throws {
        guard let service = keychainService else { return }
        let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: clientID]
        if let token {
            let fields: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(token), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
            let updated = SecItemUpdate(key as CFDictionary, fields as CFDictionary)
            if updated == errSecItemNotFound {
                guard SecItemAdd(key.merging(fields) {_, new in new} as CFDictionary, nil) == errSecSuccess else { throw Failure.storage }
            } else if updated != errSecSuccess { throw Failure.storage }
        } else {
            let status = SecItemDelete(key as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.storage }
        }
    }
    func beginAuthorization() throws -> URL {
        guard !clientID.isEmpty else { throw Failure.configuration }
        guard attempt == nil else { throw Failure.busy }
        let next = Attempt(verifier: try SpotifyContract.random(), state: try SpotifyContract.random(), started: Date(), generation: generation)
        var url = URLComponents(string: "https://accounts.spotify.com/authorize")!
        url.queryItems = ["client_id": clientID, "response_type": "code", "redirect_uri": SpotifyContract.redirectURI, "scope": SpotifyContract.scopes, "code_challenge_method": "S256", "code_challenge": SpotifyContract.challenge(next.verifier), "state": next.state].map { URLQueryItem(name: $0.key, value: $0.value) }
        attempt = next; return url.url!
    }
    func cancelAuthorization() { attempt = nil }
    func finishAuthorization(_ callback: URL) async throws -> [String: Any] {
        let current = attempt; attempt = nil
        guard let current, current.generation == generation, Date().timeIntervalSince(current.started) < 300,
              let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              parts.scheme == "com.swordingk.mineradio.apple", parts.host == "spotify", parts.path == "/callback", parts.port == nil, parts.user == nil, parts.password == nil, parts.fragment == nil else { throw Failure.callback }
        let query = parts.queryItems ?? []
        guard query.filter({$0.name == "state"}).count == 1, query.first(where: {$0.name == "state"})?.value == current.state,
              query.first(where: {$0.name == "error"}) == nil, query.filter({$0.name == "code"}).count == 1,
              let code = query.first(where: {$0.name == "code"})?.value, !code.isEmpty else { throw Failure.callback }
        let next = try await exchange(["grant_type": "authorization_code", "code": code, "code_verifier": current.verifier, "redirect_uri": SpotifyContract.redirectURI])
        guard generation == current.generation else { throw CancellationError() }
        token = next; profile = nil
        do { try persist() } catch { token = nil; throw error }
        return try await status()
    }
    private func exchange(_ fields: [String: String], previousRefresh: String = "") async throws -> Token {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!, timeoutInterval: 20)
        request.httpMethod = "POST"; request.httpBody = SpotifyContract.form(fields.merging(["client_id": clientID]) { _, new in new })
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let response = try await transport.request(request)
        if response.status == 429 { rateLimitUntil = Date().addingTimeInterval(Double(max(1, response.retryAfter))); throw Failure.rate(response.retryAfter) }
        guard response.status == 200, let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let access = object["access_token"] as? String, !access.isEmpty else { throw Failure.authorization }
        return Token(access: access, refresh: object["refresh_token"] as? String ?? previousRefresh, expiry: Date().addingTimeInterval(Double(object["expires_in"] as? Int ?? 3600)))
    }
    private func access(forceRefresh: Bool = false) async throws -> String {
        guard let saved = token else { throw Failure.authorization }
        if !forceRefresh && saved.expiry.timeIntervalSinceNow > 45 { return saved.access }
        guard !saved.refresh.isEmpty else { throw Failure.authorization }
        let owner = generation
        let job: Task<Token, Error>
        if let refreshJob { job = refreshJob }
        else {
            job = Task { try await self.exchange(["grant_type": "refresh_token", "refresh_token": saved.refresh], previousRefresh: saved.refresh) }; refreshJob = job
        }
        do {
            let next = try await job.value
            guard owner == generation else { throw CancellationError() }
            refreshJob = nil; token = next; try persist(); return next.access
        } catch {
            if owner == generation {
                refreshJob = nil
                if let failure = error as? Failure, failure.code == "SPOTIFY_AUTH_REQUIRED" { token = nil; profile = nil; try? persist() }
            }
            throw error
        }
    }
    private func request(_ path: String, method: String = "GET", query: [String: String] = [:], body: [String: Any]? = nil, retry: Bool = true) async throws -> Any {
        if rateLimitUntil > Date() { throw Failure.rate(Int(ceil(rateLimitUntil.timeIntervalSinceNow))) }
        let owner = generation, bearer = try await access()
        guard owner == generation else { throw CancellationError() }
        var url = URLComponents(string: "https://api.spotify.com/v1" + path)!
        url.queryItems = query.sorted {$0.key < $1.key}.map {URLQueryItem(name: $0.key, value: $0.value)}
        var request = URLRequest(url: url.url!, timeoutInterval: 20); request.httpMethod = method
        request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let response = try await transport.request(request)
        guard owner == generation else { throw CancellationError() }
        if response.status == 401 && retry {
            _ = try await access(forceRefresh: true)
            return try await self.request(path, method: method, query: query, body: body, retry: false)
        }
        if response.status == 429 { rateLimitUntil = Date().addingTimeInterval(Double(max(1, response.retryAfter))); throw Failure.rate(response.retryAfter) }
        if response.status == 401 { token = nil; profile = nil; try? persist(); throw Failure.authorization }
        guard (200..<300).contains(response.status) else { throw Failure.http(response.status) }
        return response.data.isEmpty ? [:] : try JSONSerialization.jsonObject(with: response.data)
    }
    private func status() async throws -> [String: Any] {
        var result: [String: Any] = ["provider": "spotify", "configured": !clientID.isEmpty, "oauthConfigured": !clientID.isEmpty, "redirectUri": SpotifyContract.redirectURI,
             "loggedIn": false, "membershipKnown": false, "playbackMode": "recommend-match", "directPlayback": false,
             "message": clientID.isEmpty ? "团队尚未配置 Spotify 授权应用；无需用户自行注册。" : "连接 Spotify 读取歌单；播放按可用音乐源匹配。"]
        guard token != nil else { return result }
        if profile == nil || Date().timeIntervalSince(profileChecked) > 30 { profile = try await request("/me") as? [String: Any]; profileChecked = Date() }
        guard let profile, let id = profile["id"] as? String, !id.isEmpty else { throw Failure.authorization }
        result.merge(["loggedIn": true, "tokenConfigured": true, "searchReady": true, "userId": id, "nickname": profile["display_name"] as? String ?? id,
             "avatar": SpotifyContract.image(profile), "product": profile["product"] as? String ?? "", "membershipKnown": profile["product"] is String,
             "capabilities": ["search": true, "library": true], "playbackKeyReady": true]) { _, new in new }
        return result
    }
    func handle(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        let path = String(url.path.dropFirst("/api/spotify".count))
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ name: String) -> String { query.first {$0.name == name}?.value ?? "" }
        let writes = ["/logout", "/song/like", "/album/like", "/playlist/add-song", "/playlist/create", "/playlist/collect"]
        guard method == (writes.contains(path) ? "POST" : "GET") else { return ["provider": "spotify", "error": "METHOD_NOT_ALLOWED", "code": 405] }
        let offset = min(100000, max(0, Int(q("offset")) ?? 0)), limit = min(50, max(1, Int(q("limit")) ?? 30))
        func id(_ raw: String) throws -> String { guard SpotifyContract.validID(raw) else { throw Failure.id }; return raw }
        let payload = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        do {
            switch path {
            case "/status": return try await status()
            case "/logout":
                generation += 1; attempt = nil; refreshJob?.cancel(); refreshJob = nil; token = nil; profile = nil; rateLimitUntil = .distantPast; try persist()
                return ["provider": "spotify", "ok": true, "loggedIn": false]
            case "/user/playlists":
                let info = try await status(), raw = try await request("/me/playlists", query: ["limit": String(limit), "offset": String(offset)]) as? [String: Any] ?? [:]
                let rows = (raw["items"] as? [[String: Any]] ?? []).map { list -> [String: Any] in
                    let own = (list["owner"] as? [String: Any])?["id"] as? String == info["userId"] as? String
                    return ["provider": "spotify", "source": "spotify", "id": list["id"] as? String ?? "", "name": list["name"] as? String ?? "", "cover": SpotifyContract.image(list), "trackCount": ((list["items"] ?? list["tracks"]) as? [String: Any])?["total"] as? Int ?? 0, "canAddSongs": own || list["collaborative"] as? Bool == true, "owned": own]
                }
                var page = SpotifyContract.page(raw, rows: rows, offset: offset, key: "playlists")
                if offset == 0 {
                    page["playlists"] = [["provider": "spotify", "source": "spotify", "id": "spotify-liked", "name": "Spotify 喜欢的歌曲", "virtual": true, "shelfPane": "fav", "specialType": 5, "canAddSongs": false]] + rows
                }
                return page
            case "/playlist/tracks":
                let endpoint = q("id") == "spotify-liked" ? "/me/tracks" : try "/playlists/" + id(q("id")) + "/items"
                let raw = try await request(endpoint, query: ["limit": String(limit), "offset": String(offset)]) as? [String: Any] ?? [:]
                let songs = (raw["items"] as? [[String: Any]] ?? []).compactMap { row in (row["item"] ?? row["track"]) as? [String: Any] }.compactMap(SpotifyContract.song)
                var page = SpotifyContract.page(raw, rows: songs, offset: offset, key: "tracks")
                page["songs"] = songs
                return page
            case "/search":
                let raw = try await request("/search", query: ["q": String(q("keywords").prefix(200)), "type": "track", "limit": String(min(10, limit)), "offset": String(offset)]) as? [String: Any] ?? [:]
                let tracks = raw["tracks"] as? [String: Any] ?? [:]
                return SpotifyContract.page(tracks, rows: (tracks["items"] as? [[String: Any]] ?? []).compactMap(SpotifyContract.song), offset: offset, key: "songs")
            case "/recommendations":
                let raw = try await request("/me/top/tracks", query: ["limit": String(limit), "offset": String(offset)]) as? [String: Any] ?? [:]
                var page = SpotifyContract.page(raw, rows: (raw["items"] as? [[String: Any]] ?? []).compactMap(SpotifyContract.song), offset: offset, key: "songs")
                page["mode"] = "personal-top"; page["provenance"] = "spotify-web-api"; return page
            case "/album/detail":
                let raw = try await request("/albums/" + id(q("id"))) as? [String: Any] ?? [:], tracks = raw["tracks"] as? [String: Any] ?? [:]
                let songs = (tracks["items"] as? [[String: Any]] ?? []).compactMap { item -> [String: Any]? in var song = item; song["album"] = ["id": raw["id"] ?? "", "name": raw["name"] ?? "", "images": raw["images"] ?? []]; return SpotifyContract.song(song) }
                return ["provider": "spotify", "album": raw, "songs": songs, "total": raw["total_tracks"] ?? songs.count]
            case "/song/like/check", "/album/like/check":
                let ids = Array(try Set((q("ids").isEmpty ? q("id") : q("ids")).split(separator: ",").prefix(50).map { try id(String($0)) })).sorted()
                let type = path.hasPrefix("/album") ? "album" : "track"
                let values = try await request("/me/library/contains", query: ["uris": ids.map {"spotify:" + type + ":" + $0}.joined(separator: ",")]) as? [Bool] ?? []
                let map = Dictionary(uniqueKeysWithValues: zip(ids, values))
                return ["provider": "spotify", "likedMap": map, "liked": map, "ids": ids, "contains": values]
            case "/song/like", "/album/like":
                let song = payload["song"] as? [String: Any] ?? payload
                let target = try id(song["spotifyId"] as? String ?? song["albumId"] as? String ?? song["id"] as? String ?? ""), like = payload["like"] as? Bool ?? true, type = path.hasPrefix("/album") ? "album" : "track"
                _ = try await request("/me/library", method: like ? "PUT" : "DELETE", query: ["uris": "spotify:" + type + ":" + target])
                return ["provider": "spotify", "ok": true, "success": true, "id": target, "liked": like]
            case "/playlist/add-song":
                let item = payload["song"] as? [String: Any] ?? payload
                let playlist = try id(payload["playlistId"] as? String ?? payload["pid"] as? String ?? ""), song = try id(item["spotifyId"] as? String ?? payload["songId"] as? String ?? item["id"] as? String ?? "")
                _ = try await request("/playlists/" + playlist + "/items", method: "POST", body: ["uris": ["spotify:track:" + song]])
                return ["provider": "spotify", "ok": true, "success": true]
            case "/playlist/collect":
                let playlist = try id(payload["playlistId"] as? String ?? payload["id"] as? String ?? ""), collected = payload["collected"] as? Bool ?? payload["subscribed"] as? Bool ?? true
                _ = try await request("/me/library", method: collected ? "PUT" : "DELETE", query: ["uris": "spotify:playlist:" + playlist])
                return ["provider": "spotify", "ok": true, "success": true, "collected": collected]
            case "/playlist/create":
                let name = String((payload["name"] as? String ?? "").prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { throw Failure.id }
                let raw = try await request("/me/playlists", method: "POST", body: ["name": name, "public": payload["public"] as? Bool ?? false])
                return ["provider": "spotify", "ok": true, "playlist": raw]
            case "/song/url": return ["provider": "spotify", "url": "", "playable": false, "playbackMode": "recommend-match", "message": "Spotify 仅提供曲目信息，请匹配已授权音乐源。"]
            case "/lyric": return ["provider": "spotify", "lyric": "", "tlyric": ""]
            default: return ["provider": "spotify", "supported": false, "error": "SPOTIFY_APPLE_CAPABILITY_NOT_IMPLEMENTED", "code": 501]
            }
        } catch let error as Failure {
            return ["provider": "spotify", "ok": false, "error": error.code, "message": error.localizedDescription, "retryAfter": error.retryAfter, "reauthRequired": error.code == "SPOTIFY_AUTH_REQUIRED"]
        }
    }
    enum Failure: LocalizedError {
        case configuration, busy, callback, authorization, storage, id, rate(Int), http(Int)
        var code: String { switch self { case .configuration: return "SPOTIFY_OAUTH_NOT_CONFIGURED"; case .authorization: return "SPOTIFY_AUTH_REQUIRED"; case .rate: return "SPOTIFY_RATE_LIMITED"; case .callback: return "SPOTIFY_CALLBACK_INVALID"; case .busy: return "SPOTIFY_LOGIN_BUSY"; case .storage: return "SPOTIFY_STORAGE_FAILED"; case .id: return "SPOTIFY_INVALID_ID"; case .http: return "SPOTIFY_API_FAILED" } }
        var retryAfter: Int { if case let .rate(seconds) = self { return seconds }; return 0 }
        var errorDescription: String? { switch self {
        case .configuration: return "团队尚未配置 Spotify Client ID。"
        case .busy: return "Spotify 授权已打开，请先完成或取消。"
        case .callback: return "Spotify 授权回调不匹配或已过期，请重新连接。"
        case .authorization: return "Spotify 登录失效，请重新连接。"
        case .storage: return "无法安全保存 Spotify 授权，请重试。"
        case .id: return "Spotify 曲目或歌单标识无效。"
        case let .rate(seconds): return "Spotify 请求过于频繁，请约 \(seconds) 秒后重试。"
        case .http(403): return "Spotify 拒绝访问，请确认开发应用已允许此账号及所需权限。"
        case .http(404): return "Spotify 内容不存在，或当前账号无权访问。"
        case .http: return "Spotify 服务暂不可用，请稍后重试。"
        } }
    }
}
