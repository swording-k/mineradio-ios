import Foundation

/// Native port of qishui-api.js read-only PC catalogue routes (GPL-3.0-only).
/// Authentication cookies are supplied by the isolated Passport owner, never JS.
protocol QishuiCatalogRequesting: Actor {
    func request(_ url: URL, headers: [String: String]) async throws -> [String: Any]
}

actor QishuiCatalogAPI {
    private let transport: any QishuiCatalogRequesting
    private var cookies: [String: String] = [:]
    private var generation = 0
    private var checkedAt = Date.distantPast
    private var account: [String: Any]?
    private var cachedLibrary: [String: Any]?
    private var libraryAt = Date.distantPast
    private struct CursorState { var raw: [[String: Any]] = []; var cursor = ""; var hasMore = true; var metadata: [String: Any] = [:] }
    private var cursors: [String: CursorState] = [:]
    private var cursorOrder: [String] = []
    private var playlistReadInFlight = Set<String>()
    private let deviceID = String(UInt64.random(in: 1_000_000_000_000_000...8_999_999_999_999_999))

    init(transport: any QishuiCatalogRequesting = QishuiCatalogTransport()) { self.transport = transport }
    func setSession(_ values: [String: String]) {
        let names = Set(["sessionid", "sessionid_ss", "sid_guard", "sid_tt", "uid_tt", "uid_tt_ss", "odin_tt", "ttwid", "passport_csrf_token", "passport_csrf_token_default"])
        let filtered = values.filter { names.contains($0.key) && $0.value.utf8.count <= 8192 && !$0.value.contains("\r") && !$0.value.contains("\n") && !$0.value.contains(";") }
        guard filtered != cookies else { return }
        cookies = filtered; generation += 1; checkedAt = .distantPast; account = nil
        cachedLibrary = nil; cursors = [:]; cursorOrder = []
    }
    private var hasSession: Bool { ["sessionid", "sessionid_ss", "sid_guard", "sid_tt"].contains { !(cookies[$0] ?? "").isEmpty } }

    func validateAccount() async -> [String: Any] {
        guard hasSession else { return QishuiCatalogContract.disconnected() }
        if let account, Date().timeIntervalSince(checkedAt) < 5 { return account }
        do {
            let json = try await pc("/luna/pc/me")
            let profile = QishuiCatalogContract.profile(json)
            guard !(profile["userId"] as? String ?? "").isEmpty else { throw QishuiCatalogFailure.identityMissing }
            var result = profile
            result.merge(["provider": "qishui", "loggedIn": true, "configured": true, "webSession": true,
                          "sessionValidated": true, "profileReady": true, "libraryReady": cachedLibrary?["libraryReady"] ?? false,
                          "playbackKeyReady": false, "searchReady": true, "status": "connected",
                          "capabilities": ["userPlaylists": true, "playlistTracks": true, "feedSongTab": true, "playableUrl": true, "nativeFullPlayback": false]]) { _, new in new }
            account = result; checkedAt = Date(); return result
        } catch {
            account = nil; checkedAt = .distantPast; cachedLibrary = nil; cursors = [:]
            return QishuiCatalogContract.disconnected(expired: (error as? QishuiCatalogFailure) == .sessionExpired,
                                                       error: error.localizedDescription)
        }
    }

    func handle(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        guard method == "GET" || url.path == "/api/qishui/logout" else { return QishuiCatalogContract.unsupported() }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ key: String) -> String { query.first { $0.name == key }?.value ?? "" }
        func number(_ key: String, _ fallback: Int, _ cap: Int) -> Int { min(cap, max(0, Int(q(key)) ?? fallback)) }
        let limit = max(1, number("limit", 20, 50)), offset = number("offset", 0, 2500)
        switch url.path {
        case "/api/qishui/status", "/api/qishui/login/status": return await validateAccount()
        case "/api/qishui/logout": setSession([:]); return QishuiCatalogContract.disconnected()
        case "/api/qishui/search":
            let status = await validateAccount()
            guard status["loggedIn"] as? Bool == true else { return try await publicSearch(q("keywords"), limit: limit, offset: offset) }
            let json = try await pc("/luna/pc/search/track", ["q": String(q("keywords").prefix(300)), "cursor": String(offset), "count": String(limit), "search_method": "input"])
            let data = QishuiCatalogContract.data(json)
            let groups = data["result_groups"] as? [[String: Any]] ?? (data["search_result"] as? [String: Any])?["result_groups"] as? [[String: Any]] ?? []
            let raw = groups.isEmpty ? QishuiCatalogContract.mediaList(json) : groups.flatMap { QishuiCatalogContract.mediaList($0) }
            let songs = QishuiCatalogContract.songs(raw)
            return ["provider": "qishui", "loggedIn": true, "songs": Array(songs.prefix(limit)), "offset": offset,
                    "limit": limit, "nextOffset": offset + songs.count, "nextCursor": data["next_cursor"] ?? "",
                    "hasMore": QishuiCatalogContract.truth(data["has_more"]) || !(QishuiCatalogContract.text(data["next_cursor"])).isEmpty]
        case "/api/qishui/user/playlists": return try await library()
        case "/api/qishui/playlist/tracks":
            let id = try checkedID(q("id"))
            if id == "qishui-feed" {
                let feed = try await feed(limit: limit)
                let tracks = feed["songs"] as? [[String: Any]] ?? []
                return ["provider": "qishui", "tracks": tracks, "total": tracks.count, "offset": 0, "nextOffset": tracks.count, "hasMore": false,
                        "playlist": QishuiCatalogContract.virtualPlaylist(id, "汽水推荐", tracks: tracks)]
            }
            if id == "qishui-liked" || id == "qishui-recent" {
                let library = try await library()
                guard library["loggedIn"] as? Bool == true else { return library }
                let key = id == "qishui-liked" ? "likedTracks" : "recentTracks"
                let all = library[key] as? [[String: Any]] ?? []
                if all.isEmpty, id == "qishui-liked", let likedID = library["likedPlaylistID"] as? String, !likedID.isEmpty {
                    return try await playlist(likedID, limit: limit, offset: offset)
                }
                let tracks = Array(all.dropFirst(offset).prefix(limit))
                return ["provider": "qishui", "loggedIn": true, "tracks": tracks, "total": all.count, "offset": offset,
                        "nextOffset": offset + tracks.count, "hasMore": offset + tracks.count < all.count,
                        "playlist": QishuiCatalogContract.virtualPlaylist(id, id == "qishui-liked" ? "汽水我的喜欢" : "汽水最近播放", tracks: all)]
            }
            return try await playlist(id, limit: limit, offset: offset)
        case "/api/qishui/feed": return try await feed(limit: min(limit, 18))
        case "/api/qishui/lyric":
            let id = try checkedID(q("id"))
            if let payload = try? await publicTrack(id) {
                let result = QishuiCatalogContract.lyrics(payload)
                if !(result["lyric"] as? String ?? "").isEmpty { return result }
            }
            if hasSession, let payload = try? await pc("/luna/pc/track_v2", ["track_id": id, "media_type": "track"]) {
                let result = QishuiCatalogContract.lyrics(payload)
                if !(result["lyric"] as? String ?? "").isEmpty { return result }
            }
            var target = URLComponents(string: "https://api-vehicle.volcengine.com/v2/custom/contents")!
            target.queryItems = ["sources": "qishui", "need_author": "true", "need_album": "true", "need_ugc": "true", "need_stat": "true", "item_ids": id].map { URLQueryItem(name: $0.key, value: $0.value) }
            if let payload = try? await transport.request(target.url!, headers: ["Accept": "application/json", "User-Agent": "Mineradio Apple"]) { return QishuiCatalogContract.lyrics(payload) }
            return ["provider": "qishui", "lyric": "", "tlyric": "", "yrc": "", "ytlrc": "", "error": "LYRIC_UNAVAILABLE"]
        case "/api/qishui/song/url":
            let id = try checkedID(q("id")), status = await validateAccount()
            guard status["loggedIn"] as? Bool == true else { return status.merging(["playable": false, "reason": "login_required"]) { _, b in b } }
            do {
                let payload = try await pc("/luna/pc/track_v2", ["track_id": id, "media_type": "track"])
                let result = QishuiCatalogContract.playback(payload, membership: status, publicSource: false, expectedID: id)
                if result["playable"] as? Bool == true { return result }
            } catch QishuiCatalogFailure.sessionExpired { return QishuiCatalogContract.disconnected(expired: true).merging(["playable": false]) { _, b in b } }
            catch { /* Native PC signing is unavailable on iOS. A public audition remains explicit. */ }
            do { return QishuiCatalogContract.playback(try await publicTrack(id), membership: status, publicSource: true, expectedID: id) }
            catch { return QishuiCatalogContract.playbackUnavailable() }
        default: return QishuiCatalogContract.unsupported()
        }
    }

    private func publicSearch(_ keywords: String, limit: Int, offset: Int) async throws -> [String: Any] {
        let requestLimit = min(100, max(36, offset + limit * 3))
        var components = URLComponents(string: "https://api-vehicle.volcengine.com/v2/search/type")!
        components.queryItems = ["keyword": String(keywords.prefix(300)), "search_type": "music", "limit": String(requestLimit), "real_offset": "0", "search_source": "qishui"].map { URLQueryItem(name: $0.key, value: $0.value) }
        let json = try await transport.request(components.url!, headers: ["Accept": "application/json", "User-Agent": "Mineradio/2.1.0 (Qishui public catalog bridge)"])
        let raw = QishuiCatalogContract.data(json)["list"] as? [[String: Any]] ?? []
        var songs = QishuiCatalogContract.songs(raw)
        songs = Array(songs.dropFirst(offset).prefix(limit)).map { song in var mapped = song; mapped["recommendationSource"] = "qishui-public-catalog"; return mapped }
        return ["provider": "qishui", "loggedIn": false, "publicCatalog": true, "songs": songs, "offset": offset, "limit": limit,
                "nextOffset": offset + songs.count, "hasMore": offset + songs.count < raw.count]
    }
    private func checkedID(_ value: String) throws -> String {
        guard !value.isEmpty, value.utf8.count <= 128, value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { throw QishuiCatalogFailure.invalidRequest }
        return value
    }
    private func pc(_ path: String, _ parameters: [String: String] = [:], web: Bool = false) async throws -> [String: Any] {
        let expected = generation
        var components = URLComponents(string: "https://api.qishui.com" + path)!
        var common = ["aid": "386088", "app_name": "luna_pc", "region": "cn", "geo_region": "cn", "os_region": "cn", "sim_region": "", "device_id": deviceID,
                      "cdid": "", "iid": String((UInt64(deviceID) ?? 0) + 1), "version_name": "3.3.0", "version_code": "30030000", "channel": "official", "build_mode": "master",
                      "network_carrier": "", "ac": "wifi", "tz_name": "Asia/Shanghai", "resolution": "", "device_platform": "windows", "device_type": "Windows", "os_version": "Windows 11", "fp": deviceID]
        if web { common = ["aid": "386088", "app_name": "luna_pc", "device_platform": "web", "channel": "pc_web"] }
        common.merge(parameters) { _, new in new }
        components.queryItems = common.map { URLQueryItem(name: $0.key, value: $0.value) }.sorted { $0.name < $1.name }
        guard let url = components.url, QishuiCatalogContract.allowedAPI(url) else { throw QishuiCatalogFailure.invalidRequest }
        var headers = ["Accept": "application/json,text/plain,*/*", "User-Agent": "LunaPC/3.3.0(359450208)", "x-luna-background-type": "foreground", "x-luna-is-background-req": "0", "x-luna-is-local-user": "1"]
        headers["Cookie"] = cookies.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        let json = try await transport.request(url, headers: headers)
        guard generation == expected else { throw QishuiCatalogFailure.sessionChanged }
        try QishuiCatalogContract.check(json)
        return json
    }
    private func publicTrack(_ id: String) async throws -> [String: Any] {
        var components = URLComponents(string: "https://beta-luna.douyin.com/luna/h5/seo_track")!
        components.queryItems = [URLQueryItem(name: "track_id", value: id), URLQueryItem(name: "device_platform", value: "web")]
        let json = try await transport.request(components.url!, headers: ["Accept": "application/json", "User-Agent": "Mineradio Apple", "Referer": "https://www.douyin.com/"])
        try QishuiCatalogContract.check(json)
        return json
    }
    private func library() async throws -> [String: Any] {
        let status = await validateAccount()
        guard status["loggedIn"] as? Bool == true, let userID = status["userId"] as? String else { return status.merging(["playlists": []]) { _, b in b } }
        if let cachedLibrary, Date().timeIntervalSince(libraryAt) < 60 { return cachedLibrary }
        var cards: [[String: Any]] = [], liked: [[String: Any]] = [], recent: [[String: Any]] = [], errors: [String] = []
        for (label, path, parameters) in [("created", "/luna/pc/user/playlist", ["user_id": userID, "cursor": "", "count": "50"]),
                                          ("collection", "/luna/pc/me/collection/mixed", ["cursor": "", "count": "50"]),
                                          ("recent", "/luna/pc/me/recently-played-media", ["cursor": "", "count": "50"])] {
            do {
                let payload = try await pc(path, parameters)
                if label != "recent" {
                    cards += QishuiCatalogContract.playlists(payload).map { card in
                        var result = card
                        let owned = label == "created" || QishuiCatalogContract.text(card["name"]).contains("喜欢")
                        result["owned"] = owned; result["subscribed"] = !owned; result["shelfPane"] = owned ? "mine" : "fav"
                        return result
                    }
                }
                if label == "collection" { liked = QishuiCatalogContract.songs(QishuiCatalogContract.mediaList(payload)) }
                if label == "recent" { recent = QishuiCatalogContract.songs(QishuiCatalogContract.mediaList(payload)) }
            } catch QishuiCatalogFailure.sessionExpired { throw QishuiCatalogFailure.sessionExpired }
            catch { errors.append(label + ":unavailable") }
        }
        var seen = Set<String>(); cards = cards.filter { seen.insert(QishuiCatalogContract.text($0["id"])).inserted }
        let likedID = cards.first { QishuiCatalogContract.text($0["name"]).contains("喜欢") }?["id"] ?? ""
        let virtual = [QishuiCatalogContract.virtualPlaylist("qishui-liked", "汽水我的喜欢", tracks: liked), QishuiCatalogContract.virtualPlaylist("qishui-recent", "汽水最近播放", tracks: recent), QishuiCatalogContract.virtualPlaylist("qishui-feed", "汽水推荐", tracks: [])]
        let result: [String: Any] = ["provider": "qishui", "loggedIn": true, "configured": true, "webSession": true, "libraryReady": errors.isEmpty,
                                     "playlists": virtual + cards, "likedTracks": liked, "recentTracks": recent, "likedPlaylistID": likedID, "errors": errors]
        cachedLibrary = result; libraryAt = Date(); return result
    }
    private func playlist(_ id: String, limit: Int, offset: Int) async throws -> [String: Any] {
        let status = await validateAccount()
        guard status["loggedIn"] as? Bool == true else { return status.merging(["tracks": []]) { _, b in b } }
        guard !playlistReadInFlight.contains(id) else { throw QishuiCatalogFailure.busy }
        playlistReadInFlight.insert(id); defer { playlistReadInFlight.remove(id) }
        var state = cursors[id] ?? CursorState()
        let expected = generation
        var pages = 0
        while state.raw.count < offset + limit && state.hasMore && pages < 50 {
            let payload = try await pc("/luna/pc/playlist/detail", ["playlist_id": id, "cursor": state.cursor, "count": String(min(100, offset + limit - state.raw.count))])
            guard expected == generation else { throw QishuiCatalogFailure.sessionChanged }
            let data = QishuiCatalogContract.data(payload), raw = QishuiCatalogContract.mediaList(payload)
            state.raw += raw
            let next = QishuiCatalogContract.text(data["next_cursor"])
            state.hasMore = !raw.isEmpty && QishuiCatalogContract.truth(data["has_more"]) && !next.isEmpty && next != state.cursor
            state.cursor = next
            state.metadata = QishuiCatalogContract.firstDictionary(data["playlist"], data["playlist_info"])
            pages += 1
        }
        cursors[id] = state
        if !cursorOrder.contains(id) { cursorOrder.append(id) }
        while cursorOrder.count > 4 { cursors.removeValue(forKey: cursorOrder.removeFirst()) }
        let all = QishuiCatalogContract.songs(state.raw), tracks = Array(all.dropFirst(offset).prefix(limit))
        let total = (state.metadata["count_tracks"] as? NSNumber)?.intValue ?? (state.metadata["track_count"] as? NSNumber)?.intValue ?? all.count
        var card = QishuiCatalogContract.virtualPlaylist(id, QishuiCatalogContract.text(state.metadata["title"]).isEmpty ? "汽水歌单" : QishuiCatalogContract.text(state.metadata["title"]), tracks: all)
        card["virtual"] = false; card["trackCount"] = total
        return ["provider": "qishui", "loggedIn": true, "configured": true, "webSession": true, "playlist": card,
                "tracks": tracks, "total": total, "offset": offset, "limit": limit, "nextOffset": offset + tracks.count,
                "hasMore": state.hasMore || offset + tracks.count < all.count]
    }
    private func feed(limit: Int) async throws -> [String: Any] {
        let status = await validateAccount()
        guard status["loggedIn"] as? Bool == true else { return status.merging(["songs": []]) { _, b in b } }
        for path in ["/luna/feed/song-tab", "/luna/pc/feed/song-tab"] {
            do {
                let payload = try await pc(path, ["cursor": "0", "cnt": String(limit), "count": String(limit)], web: true)
                let songs = Array(QishuiCatalogContract.songs(QishuiCatalogContract.mediaList(payload)).prefix(limit))
                if !songs.isEmpty { return ["provider": "qishui", "loggedIn": true, "configured": true, "songs": songs] }
            } catch QishuiCatalogFailure.sessionExpired { throw QishuiCatalogFailure.sessionExpired }
            catch { continue }
        }
        return ["provider": "qishui", "loggedIn": true, "configured": true, "songs": [], "message": "汽水推荐暂未返回歌曲。"]
    }
}

enum QishuiCatalogFailure: Error, LocalizedError {
    case invalidRequest, invalidResponse, sessionExpired, identityMissing, sessionChanged, busy
    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "汽水请求不符合已允许的接口契约。"
        case .invalidResponse: return "汽水接口响应不可用，请稍后重试。"
        case .sessionExpired: return "汽水登录状态已失效，请重新扫码。"
        case .identityMissing: return "汽水账号接口未返回可验证的用户身份。"
        case .sessionChanged: return "汽水会话已变更，请重试。"
        case .busy: return "汽水歌单正在加载，请稍后重试。"
        }
    }
}

actor QishuiCatalogTransport: QishuiCatalogRequesting {
    private let session: URLSession
    init(configuration: URLSessionConfiguration = .ephemeral) {
        let config = configuration.copy() as! URLSessionConfiguration
        config.httpCookieStorage = nil; config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 15
        session = URLSession(configuration: config, delegate: QishuiCatalogNoRedirect(), delegateQueue: nil)
    }
    func request(_ url: URL, headers: [String: String]) async throws -> [String: Any] {
        guard QishuiCatalogContract.allowedAPI(url) else { throw QishuiCatalogFailure.invalidRequest }
        var request = URLRequest(url: url); request.httpMethod = "GET"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (bytes, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.url == url else { throw QishuiCatalogFailure.invalidResponse }
        if http.statusCode == 401 { throw QishuiCatalogFailure.sessionExpired }
        guard (200...299).contains(http.statusCode), bytes.count <= 8 * 1024 * 1024,
              let json = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw QishuiCatalogFailure.invalidResponse }
        return json
    }
}
private final class QishuiCatalogNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
