import Foundation

/// Native network/session adapter. DTOs and H5 signing follow kugou-api.js.
/// Account validity is established by an authenticated official catalogue probe.
actor KugouNativeAPI {
    private let transport: any KugouRequesting
    private let store: KugouSessionStore
    private var cookies: [String: String]
    private var generation = 0
    private var cachedLists: [[String: Any]]?
    private var checkedAt = Date.distantPast
    private var account: [String: Any]?
    private let guestMid = KugouContract.md5(UUID().uuidString)
    init(transport: any KugouRequesting = KugouHTTPTransport(), keychainService: String = "com.swordingk.mineradio.kugou.apple") {
        self.transport = transport; store = KugouSessionStore(service: keychainService); cookies = store.load().filter { KugouContract.cookieNames.contains($0.key) }
    }
    func setSession(_ values: [HTTPCookie]) throws {
        var selected: [String: String] = [:]
        for cookie in values {
            let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard domain == "kugou.com" || domain.hasSuffix(".kugou.com"), KugouContract.cookieNames.contains(cookie.name),
                  cookie.expiresDate == nil || cookie.expiresDate! > Date(), !cookie.value.contains("\r"), !cookie.value.contains("\n"), cookie.value.count <= 8192 else { continue }
            selected[cookie.name] = cookie.value
        }
        guard selected != cookies else { return }
        try store.save(selected)
        cookies = selected; generation += 1; cachedLists = nil; checkedAt = .distantPast; account = nil
    }
    private var auth: (uid: String, token: String, mid: String, dfid: String, nickname: String) {
        var compound: [String: String] = [:]
        let raw = cookies["KuGoo"] ?? cookies["Kugou"] ?? cookies["kugou"] ?? ""
        for item in (raw.removingPercentEncoding ?? raw).components(separatedBy: "&") {
            let pair = item.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { compound[pair[0]] = pair[1].removingPercentEncoding ?? pair[1] }
        }
        let uid = cookies["userid"] ?? cookies["UserId"] ?? cookies["KugooID"] ?? cookies["kugouID"] ?? compound["KugooID"] ?? compound["userid"] ?? ""
        let token = cookies["token"] ?? cookies["Token"] ?? compound["t"] ?? compound["token"] ?? ""
        let clean = uid.allSatisfy(\.isNumber) && uid != "0" ? uid : ""
        return (clean, token, cookies["kg_mid"] ?? cookies["KG_MID"] ?? KugouContract.md5("mineradio-kugou:" + (clean.isEmpty ? (token.isEmpty ? "guest" : token) : clean)), cookies["kg_dfid"] ?? cookies["KG_DFID"] ?? "-", compound["NickName"] ?? cookies["NickName"] ?? "")
    }
    private func h5Params(_ extra: [String: String] = [:]) -> [String: String] {
        let a = auth, now = String(Int(Date().timeIntervalSince1970 * 1000))
        return ["srcappid": "2919", "clientver": "20000", "clienttime": now, "mid": a.mid.isEmpty ? guestMid : a.mid,
                "uuid": now, "dfid": a.dfid, "appid": "1014", "token": a.token, "userid": a.uid.isEmpty ? "0" : a.uid].merging(extra) { _, new in new }
    }
    private func request(_ host: String, _ path: String, params: [String: String], body: Data? = nil, router: String? = nil, timeout: TimeInterval = 12) async throws -> [String: Any] {
        var url = URLComponents(string: "https://" + host + path)!
        url.queryItems = params.keys.sorted().map { URLQueryItem(name: $0, value: params[$0]) }
        guard let target = url.url, KugouContract.allowedAPI(target) else { throw KugouFailure.requestDenied }
        var request = URLRequest(url: target, timeoutInterval: timeout)
        request.httpMethod = body == nil ? "GET" : "POST"; request.httpBody = body
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.kugou.com/", forHTTPHeaderField: "Referer")
        var session = cookies
        if session["kg_mid"] == nil { session["kg_mid"] = auth.mid }
        if session["kg_dfid"] == nil { session["kg_dfid"] = auth.dfid }
        request.setValue(session.keys.sorted().map { "\($0)=\(session[$0]!)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let router { request.setValue(router, forHTTPHeaderField: "x-router") }
        return try await transport.request(request)
    }
    private func gateway(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard !auth.uid.isEmpty, !auth.token.isEmpty else { throw KugouFailure.invalidInput }
        let bytes = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        var params = h5Params(["plat": "1"])
        params["signature"] = KugouContract.signature(params, body: String(decoding: bytes, as: UTF8.self))
        return try await request("gateway.kugou.com", path, params: params, body: bytes, router: "cloudlist.service.kugou.com")
    }
    private func signedWeb(_ host: String, hash: String, album: String, audio: String) async throws -> [String: Any] {
        var params = h5Params(["uuid": auth.mid, "platid": "4", "hash": hash, "album_id": album.isEmpty ? "0" : album])
        if !audio.isEmpty { params["album_audio_id"] = audio }
        params["signature"] = KugouContract.signature(params)
        return try await request(host, "/play/songinfo", params: params, timeout: 2.5)
    }
    private func signedH5(hash: String, album: String, audio: String, quality: String, member: Bool) async throws -> [String: Any] {
        let a = auth, fileHash = hash.lowercased()
        let paramQuality = ["jymaster": "viper_tape", "hires": "hires", "lossless": "flac", "exhigh": "320", "standard": "128"][quality] ?? "128"
        var params = h5Params(["album_id": album.isEmpty ? "0" : album, "area_code": "1", "hash": fileHash,
            "ssa_flag": "is_fromtrack", "version": "11430", "quality": paramQuality, "album_audio_id": audio.isEmpty ? "0" : audio,
            "behavior": "play", "pid": "2", "cmd": "26", "pidversion": "3001", "IsFreePart": member ? "0" : "1", "cdnBackup": "1", "module": ""])
        params["key"] = KugouContract.md5(fileHash + "57ae12eb6890223e355ccfcb74edf70d" + "1014" + a.mid + a.uid)
        params["signature"] = KugouContract.signature(params)
        return try await request("gateway.kugou.com", "/v5/url", params: params, router: "trackercdn.kugou.com", timeout: 2.5)
    }
    private func unavailableStatus(_ reason: String = "not_connected") -> [String: Any] {
        ["provider": "kugou", "loggedIn": false, "configured": true, "supported": true, "libraryReady": false,
         "playbackReady": false, "playbackKeyReady": false, "membershipKnown": false, "membershipVerified": false,
         "status": reason, "message": "请在酷狗官方登录窗口登录，账号将通过官方接口验证。"]
    }
    private func status(force: Bool = false) async throws -> [String: Any] {
        if !force, Date().timeIntervalSince(checkedAt) < 15, let account { return account }
        guard !auth.uid.isEmpty, !auth.token.isEmpty else { return unavailableStatus() }
        let expected = generation, a = auth
        let json = try await gateway("/v7/get_all_list", body: ["userid": Int64(a.uid) ?? 0, "token": a.token, "total_ver": 979, "type": 2, "page": 1, "pagesize": 50])
        guard generation == expected else { throw KugouFailure.sessionChanged }
        guard KugouContract.number(json["status"]) == 1, let lists = KugouContract.listRows(json) else {
            account = unavailableStatus("session_rejected"); cachedLists = nil; checkedAt = Date(); return account!
        }
        cachedLists = lists
        let owner = lists.first { item in KugouContract.text(KugouContract.first(item, ["list_create_userid", "userid", "user_id"])) == a.uid } ?? [:]
        let nickname = !a.nickname.isEmpty ? a.nickname : KugouContract.text(KugouContract.first(owner, ["nickname", "username", "list_create_username"]))
        var info: [String: Any] = ["provider": "kugou", "loggedIn": true, "configured": true, "supported": true,
            "libraryReady": true, "playbackReady": true, "playbackKeyReady": true, "userId": a.uid,
            "nickname": nickname.isEmpty ? "酷狗用户" : nickname,
            "avatar": KugouContract.text(KugouContract.first(owner, ["create_user_pic", "user_pic", "avatar"])).replacingOccurrences(of: "{size}", with: "120"),
            "isVip": false, "isSvip": false, "membershipKnown": false, "membershipVerified": false, "vipSyncState": "unknown", "vipLabel": "权益待核验"]
        // Cookies and playback access are deliberately not treated as evidence of membership.
        if let membership = try? await request("vip.kugou.com", "/recharge/roleinfo", params: ["n": String(Int(Date().timeIntervalSince1970 * 1000))]),
           generation == expected, KugouContract.number(membership["status"]) != 0 {
            let data = membership["data"] as? [String: Any] ?? [:]
            let returnedUID = KugouContract.text(KugouContract.first(data, ["userid", "user_id", "uid"]))
            if returnedUID == a.uid, let role = data["role"] as? NSNumber {
                let svip = [6, 11, 13].contains(role.intValue), vip = svip || [1, 2].contains(role.intValue)
                info["isVip"] = vip; info["isSvip"] = svip; info["membershipKnown"] = true; info["membershipVerified"] = true
                info["vipSyncState"] = "checked"; info["vipLabel"] = svip ? "SVIP" : (vip ? "VIP" : "无VIP")
            }
        }
        guard generation == expected else { throw KugouFailure.sessionChanged }
        checkedAt = Date(); account = info; return info
    }
    func handle(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        let expected = generation
        let result = try await route(url, method: method, body: body)
        guard generation == expected || url.path == "/api/kugou/logout" else { throw KugouFailure.sessionChanged }
        return result
    }
    private func route(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        guard ["GET", "POST"].contains(method) else { throw KugouFailure.invalidInput }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ key: String) -> String { items.first { $0.name == key }?.value ?? "" }
        func number(_ key: String, _ value: Int, max: Int) -> Int { min(max, Swift.max(0, Int(q(key)) ?? value)) }
        switch url.path {
        case "/api/kugou/login/status": return try await status()
        case "/api/kugou/logout":
            try store.save([:]); cookies = [:]; account = nil; cachedLists = nil; checkedAt = .distantPast; generation += 1
            var info = unavailableStatus(); info["ok"] = true; return info
        case "/api/kugou/user/playlists":
            var info = try await status()
            info["playlists"] = (cachedLists ?? []).map(KugouContract.playlist).filter { !KugouContract.text($0["id"]).isEmpty }
            return info
        case "/api/kugou/playlist/tracks":
            guard (try await status())["loggedIn"] as? Bool == true else { return ["provider": "kugou", "tracks": [], "error": "KUGOU_AUTH_REQUIRED"] }
            var id = q("id").isEmpty ? q("global_collection_id") : q("id")
            if id.hasPrefix("collection_") { let parts = id.split(separator: "_"); if parts.count >= 5 { id = String(parts[3]) } }
            guard !id.isEmpty, id.count < 32, id.allSatisfy(\.isNumber) else { throw KugouFailure.invalidInput }
            let offset = number("offset", 0, max: 100000), limit = Swift.max(1, number("limit", 50, max: 50)), a = auth
            func fetchPage(_ page: Int) async throws -> (rows: [[String: Any]], total: Int) {
                let json = try await gateway("/v4/get_list_all_file", body: ["listid": Int64(id) ?? 0, "userid": Int64(a.uid) ?? 0, "area_code": 1, "show_relate_goods": 0, "pagesize": limit, "allplatform": 1, "show_cover": 1, "type": 0, "token": a.token, "page": page])
                let data = json["data"] as? [String: Any] ?? [:]
                let rows = ["info", "songs", "lists", "file"].compactMap { data[$0] as? [[String: Any]] }.first
                    ?? (data["info"] as? [String: Any])?["file"] as? [[String: Any]]
                guard KugouContract.number(json["status"]) == 1, let rows else { throw KugouFailure.invalidResponse }
                return (rows, Int(KugouContract.number(data["count"])))
            }
            // Match the original app: newest additions first even though the
            // upstream cloud-list endpoint returns oldest first.
            let probe = try await fetchPage(1), total = probe.total > 0 ? probe.total : probe.rows.count
            var all: [[String: Any]] = []
            let start = Swift.max(0, total - offset - limit), end = Swift.max(0, total - offset)
            var position = start
            while position < end {
                let page = position / limit + 1
                let response = page == 1 ? probe : try await fetchPage(page)
                let chunk = Array(response.rows.dropFirst(position % limit).prefix(end - position))
                all += chunk; position += chunk.count
                if chunk.isEmpty || response.rows.count < limit { break }
            }
            let tracks = Array(all.reversed()).enumerated().map { index, item -> [String: Any] in
                var song = KugouContract.song(item); song["playlistIndex"] = offset + index
                song["addedAt"] = KugouContract.number(KugouContract.first(item, ["addtime", "add_time", "collect_time", "ctime"]))
                return song
            }
            return ["provider": "kugou", "id": q("id"), "tracks": tracks, "total": total, "offset": offset, "limit": limit, "nextOffset": offset + tracks.count, "hasMore": offset + tracks.count < total, "partial": true]
        case "/api/kugou/search":
            let keywords = q("keywords").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !keywords.isEmpty, keywords.count <= 300 else { return ["provider": "kugou", "songs": []] }
            let limit = Swift.max(1, number("limit", 10, max: 20)), offset = number("offset", 0, max: 100000), a = auth
            var params = ["keyword": keywords, "page": String(offset / limit + 1), "pagesize": String(limit), "userid": a.uid.isEmpty ? "-1" : a.uid, "clientver": "2000", "platform": "WebFilter", "tag": "em", "filter": "2", "iscorrection": "1", "privilege_filter": "0", "filter_ver": "2", "appid": "1014", "token": a.token, "mid": a.mid]
            var songs: [[String: Any]] = [], total = 0
            for pageDelta in 0...1 {
                params["page"] = String(offset / limit + 1 + pageDelta)
                let json = try await request("songsearch.kugou.com", "/song_search_v2", params: params)
                let data = json["data"] as? [String: Any] ?? [:]
                guard KugouContract.number(json["status"]) == 1, let rows = data["lists"] as? [[String: Any]] else { throw KugouFailure.invalidResponse }
                total = Int(KugouContract.number(data["total"]))
                songs += rows.map(KugouContract.song)
                if offset % limit == 0 || songs.count >= offset % limit + limit || rows.count < limit { break }
            }
            let sliced = Array(songs.dropFirst(offset % limit).prefix(limit))
            return ["provider": "kugou", "songs": sliced, "offset": offset, "limit": limit, "nextOffset": offset + sliced.count, "hasMore": offset + sliced.count < total]
        case "/api/kugou/song/url":
            let hash = q("hash").isEmpty ? q("id") : q("hash")
            guard hash.count == 32, hash.allSatisfy({ $0.isHexDigit }) else { throw KugouFailure.invalidInput }
            let album = q("albumId").isEmpty ? q("album_id") : q("albumId"), audio = q("albumAudioId").isEmpty ? q("album_audio_id") : q("albumAudioId")
            var last: [String: Any] = ["provider": "kugou", "playable": false, "url": "", "reason": "url_unavailable"]
            var trialCandidate: [String: Any]?
            if !auth.uid.isEmpty, !auth.token.isEmpty {
                let membership = try? await status()
                let member = membership?["membershipVerified"] as? Bool == true && membership?["isVip"] as? Bool == true
                let svip = member && membership?["isSvip"] as? Bool == true
                let requested = q("quality").isEmpty ? "standard" : q("quality")
                let quality = !member ? "standard" : (!svip && ["hires", "jymaster"].contains(requested) ? "lossless" : requested)
                if let json = try? await signedH5(hash: hash, album: album, audio: audio, quality: quality, member: member) {
                    let mapped = KugouContract.playback(json)
                    if mapped["playable"] as? Bool == true {
                        if mapped["trial"] as? Bool == true { trialCandidate = mapped }
                        else { return mapped }
                    }
                }
            }
            for host in ["wwwapi.kugou.com", "wwwapiretry.kugou.com"] {
                if let json = try? await signedWeb(host, hash: hash, album: album, audio: audio) {
                    let mapped = KugouContract.playback(json); last = mapped
                    if mapped["playable"] as? Bool == true {
                        if mapped["trial"] as? Bool == true { if trialCandidate == nil { trialCandidate = mapped } }
                        else { return mapped }
                    }
                }
            }
            if let json = try? await request("m.kugou.com", "/app/i/getSongInfo.php", params: ["cmd": "playInfo", "hash": hash, "key": KugouContract.md5(hash + "kgcloud"), "album_id": album.isEmpty ? "0" : album, "pid": "1", "forceDown": "0", "userid": auth.uid, "token": auth.token], timeout: 2.5) {
                let mapped = KugouContract.playback(json)
                if mapped["playable"] as? Bool == true {
                        if mapped["trial"] as? Bool == true { if trialCandidate == nil { trialCandidate = mapped } }
                        else { return mapped }
                    }
                last = mapped
            }
            return trialCandidate ?? last
        case "/api/kugou/lyric":
            let hash = q("hash").isEmpty ? q("id") : q("hash")
            guard hash.count == 32, hash.allSatisfy({ $0.isHexDigit }) else { throw KugouFailure.invalidInput }
            let found = try await request("krcs.kugou.com", "/search", params: ["ver": "1", "man": "yes", "client": "pc", "keyword": "", "duration": q("duration"), "hash": hash, "album_audio_id": q("albumAudioId")])
            guard let candidate = (found["candidates"] as? [[String: Any]])?.first, let id = candidate["id"] else { return ["provider": "kugou", "lyric": "", "trans": ""] }
            let json = try await request("krcs.kugou.com", "/download", params: ["ver": "1", "client": "pc", "id": KugouContract.text(id), "accesskey": KugouContract.text(candidate["accesskey"]), "fmt": "lrc", "charset": "utf8"])
            let encoded = KugouContract.text(json["content"]), lyric = Data(base64Encoded: encoded).flatMap { String(data: $0, encoding: .utf8) } ?? encoded
            return ["provider": "kugou", "hash": hash, "lyric": lyric, "trans": ""]
        default: return ["provider": "kugou", "ok": false, "code": 501, "supported": false, "error": "APPLE_CAPABILITY_NOT_IMPLEMENTED", "message": "此酷狗功能尚未完成 Apple 端适配。"]
        }
    }
}
