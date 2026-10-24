import Foundation
import Security
import CryptoKit

struct QQMusicHTTPResponse { let data: Data; let status: Int; let url: URL }
protocol QQMusicRequesting: Actor {
    func request(_ request: URLRequest) async throws -> QQMusicHTTPResponse
    func probe(_ url: URL, budget: TimeInterval) async throws -> Bool
}

enum QQMusicContract {
    static let cookieNames: Set<String> = ["uin", "p_uin", "qqmusic_uin", "wxuin", "wxopenid", "login_type", "qm_keyst", "qqmusic_key", "music_key", "wxskey", "p_skey", "skey", "psrf_qqaccess_token", "psrf_qqrefresh_token", "wxrefresh_token"]
    static func qqDomain(_ host: String) -> Bool {host == "qq.com" || host.hasSuffix(".qq.com")}
    static func allowedAPI(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.port == nil || url.port == 443, url.fragment == nil else {return false}
        let paths: [String: Set<String>] = ["u.y.qq.com": ["/cgi-bin/musicu.fcg", "/cgi-bin/musics.fcg"], "c.y.qq.com": ["/rsc/fcgi-bin/fcg_get_profile_homepage.fcg", "/rsc/fcgi-bin/fcg_user_created_diss", "/fav/fcgi-bin/fcg_get_profile_order_asset.fcg", "/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg", "/lyric/fcgi-bin/fcg_query_lyric_new.fcg", "/splcloud/fcgi-bin/smartbox_new.fcg"]]
        let detailPaths: Set<String> = ["/v8/fcg-bin/fcg_v8_album_info_cp.fcg", "/base/fcgi-bin/fcg_global_comment_h5.fcg"]
        return paths[url.host ?? ""]?.contains(url.path) == true || (url.host == "c.y.qq.com" && detailPaths.contains(url.path))
    }
    static func allowedMedia(_ url: URL) -> Bool {
        guard ["https", "http"].contains(url.scheme ?? ""), url.user == nil, url.password == nil, url.port == nil || [80, 443].contains(url.port!) else {return false}
        let h = url.host?.lowercased() ?? ""
        return h == "stream.qqmusic.qq.com" || h.hasSuffix(".stream.qqmusic.qq.com") || h == "qqmusic.tc.qq.com" || h.hasSuffix(".qqmusic.tc.qq.com")
    }
    static func song(_ raw: [String: Any]) -> [String: Any] {
        let track = raw["track_info"] as? [String: Any] ?? raw["songInfo"] as? [String: Any] ?? raw["songinfo"] as? [String: Any] ?? raw["song"] as? [String: Any] ?? raw
        let album = track["album"] as? [String: Any] ?? [:]
        let artists = track["singer"] as? [[String: Any]] ?? []
        let mid = text(track["mid"] ?? track["songmid"] ?? track["id"] ?? track["songid"])
        let albumMid = text(album["mid"] ?? album["pmid"] ?? track["albummid"])
        return ["provider": "qq", "source": "qq", "type": "qq", "id": mid, "mid": mid, "songmid": mid,
                "qqId": track["id"] ?? track["songid"] ?? "", "name": track["name"] ?? track["songname"] ?? track["title"] ?? "",
                "mediaMid": (track["file"] as? [String: Any])?["media_mid"] ?? track["strMediaMid"] ?? "", "artists": artists,
                "artist": artists.compactMap { $0["name"] as? String }.joined(separator: " / "),
                "album": album["name"] ?? album["title"] ?? track["albumname"] ?? "", "albumMid": albumMid,
                "cover": albumMid.isEmpty ? "" : "https://y.qq.com/music/photo_new/T002R300x300M000\(albumMid).jpg",
                "duration": integer(track["interval"]) * 1000, "fee": integer((track["pay"] as? [String: Any])?["pay_play"]) > 0 ? 1 : 0, "playable": false]
    }
    static func playlist(_ raw: [String: Any], subscribed: Bool) -> [String: Any] {
        let dir = text(raw["dirid"] ?? raw["dir_id"])
        let favorite = dir == "201"
        return ["provider": "qq", "source": "qq", "id": favorite ? "liked" : text(raw["dissid"] ?? raw["tid"] ?? raw["diss_id"] ?? raw["id"] ?? raw["dirid"]),
                "dirid": dir, "name": favorite ? "我的喜欢" : text(raw["diss_name"] ?? raw["dissname"] ?? raw["name"] ?? raw["title"]),
                "cover": raw["diss_cover"] ?? raw["logo"] ?? raw["picurl"] ?? "", "trackCount": integer(raw["song_cnt"] ?? raw["songnum"] ?? raw["song_count"]),
                "subscribed": subscribed, "specialType": favorite ? 5 : 0, "virtual": favorite]
    }
    static func text(_ value: Any?) -> String {value.map {String(describing: $0)} ?? ""}
    static func integer(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? Int(text(value)) ?? 0 }
    static func searchSign(_ data: Data) -> String {
        let hash = Insecure.SHA1.hash(data: data).map {String(format: "%02x", $0)}.joined()
        let chars = Array(hash)
        let one = [23,14,6,36,16,40,7,19].compactMap { $0 < chars.count ? String(chars[$0]) : nil }.joined()
        let two = [16,1,32,12,19,27,8,5].map {String(chars[$0])}.joined()
        let scramble: [UInt8] = [89,39,179,150,218,82,58,252,177,52,186,123,120,64,242,133,143,161,121,179]
        let digest = Array(Insecure.SHA1.hash(data: data))
        let middle = Data(zip(scramble, digest).map { $0 ^ $1 }).base64EncodedString().filter { !"/+=\\".contains($0) }
        return ("zzc" + one + middle + two).lowercased()
    }
}

actor QQMusicTransport: QQMusicRequesting {
    func request(_ request: URLRequest) async throws -> QQMusicHTTPResponse {
        guard let url = request.url, QQMusicContract.allowedAPI(url) else {throw URLError(.unsupportedURL)}
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.timeoutIntervalForRequest = 12; configuration.timeoutIntervalForResource = 18
        let session = URLSession(configuration: configuration, delegate: QQMusicNoRedirect(), delegateQueue: nil)
        defer {session.invalidateAndCancel()}
        let (bytes, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.url == url, bytes.count <= 8 * 1024 * 1024 else {throw URLError(.badServerResponse)}
        return QQMusicHTTPResponse(data: bytes, status: http.statusCode, url: url)
    }
    func probe(_ input: URL, budget: TimeInterval) async throws -> Bool {
        guard QQMusicContract.allowedMedia(input) else {return false}
        var c = URLComponents(url: input, resolvingAgainstBaseURL: false)!; c.scheme = "https"; if c.port == 80 {c.port = nil}
        let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil; config.timeoutIntervalForResource = max(0.25, min(6, budget))
        let session = URLSession(configuration: config, delegate: QQMusicNoRedirect(), delegateQueue: nil)
        defer {session.invalidateAndCancel()}
        var request = URLRequest(url: c.url!, timeoutInterval: max(0.25, min(4, budget)))
        request.setValue("bytes=0-8191", forHTTPHeaderField: "Range"); request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, [200, 206].contains(http.statusCode), !(http.mimeType ?? "").contains("text"), !(http.mimeType ?? "").contains("json") else {return false}
        var prefix: [UInt8] = []; prefix.reserveCapacity(8192)
        for try await b in bytes {prefix.append(b); if prefix.count >= 8192 {break}}
        guard prefix.count >= 512 else {return false}
        let first = String(bytes: prefix.prefix(4), encoding: .ascii) ?? ""
        if first.hasPrefix("ID3") || first == "fLaC" || first == "OggS" {return true}
        if prefix.count >= 8, String(bytes: prefix[4..<8], encoding: .ascii) == "ftyp" {return true}
        for i in 0..<min(2048, prefix.count - 1) {if prefix[i] == 255 && prefix[i + 1] & 224 == 224 {return true}}
        return false
    }
}
private final class QQMusicNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {completionHandler(nil)}
}

actor QQMusicNativeAPI {
    private let transport: any QQMusicRequesting
    private let keychainService: String?
    private var cookies: [String: String]
    private var cachedStatus: [String: Any]?
    private var checked = Date.distantPast
    init(transport: any QQMusicRequesting = QQMusicTransport(), keychainService: String? = "com.swordingk.mineradio.qqmusic.apple") {
        self.transport = transport; self.keychainService = keychainService
        var saved: CFTypeRef?
        if let service = keychainService, SecItemCopyMatching([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session", kSecReturnData as String: true] as CFDictionary, &saved) == errSecSuccess, let data = saved as? Data {
            cookies = (try? JSONSerialization.jsonObject(with: data) as? [String: String]) ?? [:]
        } else {cookies = [:]}
    }
    @discardableResult func setSession(_ values: [HTTPCookie]) async throws -> [String: Any] {
        var next: [String: String] = [:]
        // Prefer host-specific y.qq.com cookies over broad OAuth-domain cookies.
        for cookie in values.sorted(by: {$0.domain.count < $1.domain.count}) where QQMusicContract.qqDomain(cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain) && QQMusicContract.cookieNames.contains(cookie.name) {
            guard !cookie.value.contains("\r"), !cookie.value.contains("\n"), !cookie.value.contains(";"), cookie.value.utf8.count < 16384 else {continue}
            if let expires = cookie.expiresDate, expires < Date() {continue}
            next[cookie.name] = cookie.value
        }
        cookies = next; cachedStatus = nil
        try save(); return try await status(force: true)
    }
    func handle(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ name: String) -> String {items.first {$0.name == name}?.value ?? ""}
        let limit = min(100, max(1, Int(q("limit")) ?? 48)), offset = max(0, Int(q("offset")) ?? 0)
        switch url.path {
        case "/api/qq/status", "/api/qq/login/status": return try await status(force: true)
        case "/api/qq/logout":
            cookies = [:]; cachedStatus = nil; try save(); return noSession()
        case "/api/qq/user/playlists": return try await playlists()
        case "/api/qq/playlist/tracks": return try await playlistTracks(q("id"), limit: limit, offset: offset)
        case "/api/qq/search": return try await search(q("keywords"), limit: min(30, limit), offset: offset)
        case "/api/qq/song/url": return try await songURL(q("mid").isEmpty ? q("id") : q("mid"), media: q("mediaMid"), quality: q("quality"))
        case "/api/qq/lyric": return try await lyric(q("mid").isEmpty ? q("id") : q("mid"))
        case "/api/qq/album/detail", "/api/qq/artist/detail", "/api/qq/song/comments":
            guard method == "GET" else { return ["provider": "qq", "error": "METHOD_NOT_ALLOWED", "code": 405] }
            if url.path == "/api/qq/album/detail" { return try await albumDetail(q("mid").isEmpty ? (q("albummid").isEmpty ? q("albumMid") : q("albummid")) : q("mid"), limit: limit) }
            if url.path == "/api/qq/artist/detail" { return try await artistDetail(q("mid").isEmpty ? q("singermid") : q("mid"), limit: min(80, limit)) }
            return try await comments(id: q("id").isEmpty ? q("qqId") : q("id"), mid: q("mid").isEmpty ? q("songmid") : q("mid"), limit: min(50, limit), offset: offset)
        default: return ["provider": "qq", "supported": false, "code": 501, "error": "QQ_APPLE_CAPABILITY_NOT_IMPLEMENTED"]
        }
    }
    private var uin: String {
        let raw = cookies["wxopenid"] != nil || cookies["login_type"] == "2" ? cookies["wxuin"] ?? cookies["uin"] ?? cookies["p_uin"] : cookies["uin"] ?? cookies["qqmusic_uin"] ?? cookies["p_uin"] ?? cookies["wxuin"]
        let digits = (raw ?? "").filter {$0.isASCII && $0.isNumber}; return String(digits.drop(while: {$0 == "0"}))
    }
    private var musicKey: String {cookies["qm_keyst"] ?? cookies["qqmusic_key"] ?? cookies["music_key"] ?? cookies["wxskey"] ?? ""}
    private func noSession() -> [String: Any] { ["provider": "qq", "loggedIn": false, "hasCookie": !cookies.isEmpty, "membershipKnown": false, "playbackKeyReady": false, "playbackReady": false] }
    private func status(force: Bool = false) async throws -> [String: Any] {
        if !force, let cachedStatus, Date().timeIntervalSince(checked) < 8 {return cachedStatus}
        if force {cachedStatus = nil}
        guard !uin.isEmpty, !musicKey.isEmpty else {return noSession()}
        let profile = try await get("https://c.y.qq.com/rsc/fcgi-bin/fcg_get_profile_homepage.fcg", ["cid": "205360838", "userid": uin, "reqfrom": "1", "g_tk": "5381", "loginUin": uin])
        guard QQMusicContract.integer(profile["code"]) == 0, let data = profile["data"] as? [String: Any], let creator = data["creator"] as? [String: Any], !(creator["nick"] as? String ?? creator["nickname"] as? String ?? "").isEmpty else {return noSession()}
        // Public profile lookup is insufficient to verify a session. Require an
        // account-scoped "my liked songs" request to succeed with this authst.
        let liked = try await music(["req_0": ["module": "music.srfDissInfo.DissInfo", "method": "CgiGetDiss", "param": ["disstid": 0, "dirid": 201, "tag": 1, "song_begin": 0, "song_num": 1, "userinfo": 1, "orderlist": 1]]])
        guard let block = liked["req_0"] as? [String: Any], QQMusicContract.integer(block["code"]) == 0, let account = block["data"] as? [String: Any], account["songlist"] is [Any] else {return noSession()}
        let directory = account["dirinfo"] as? [String: Any] ?? [:]
        let owner = QQMusicContract.text(directory["uin"] ?? directory["hostuin"] ?? directory["creator_uin"] ?? (account["userinfo"] as? [String: Any])?["uin"])
        guard !owner.isEmpty, owner == uin else {return noSession()}
        let result: [String: Any] = ["provider": "qq", "loggedIn": true, "userId": uin, "nickname": creator["nick"] ?? creator["nickname"] ?? "QQ 音乐", "avatar": creator["headpic"] ?? creator["avatar"] ?? "", "hasCookie": true, "playbackKeyReady": true, "playbackReady": true, "membershipKnown": false, "isVip": false, "isSvip": false, "vipLabel": "权益待核验", "profileSource": "qq-profile-and-account-liked", "vipSyncState": "unknown"]
        cachedStatus = result; checked = Date(); return result
    }
    private func playlists() async throws -> [String: Any] {
        let info = try await status(); guard info["loggedIn"] as? Bool == true else {return ["provider": "qq", "loggedIn": false, "playlists": []]}
        var cards: [[String: Any]] = [["provider": "qq", "source": "qq", "id": "liked", "dirid": "201", "name": "我的喜欢", "virtual": true, "specialType": 5, "trackCount": 0]]
        for collected in [false, true] {
            for page in 0..<25 {
                let start = page * 200
                let response = try await get(collected ? "https://c.y.qq.com/fav/fcgi-bin/fcg_get_profile_order_asset.fcg" : "https://c.y.qq.com/rsc/fcgi-bin/fcg_user_created_diss", collected ? ["ct": "20", "cid": "205360956", "userid": uin, "reqtype": "3", "sin": String(start), "ein": String(start + 199)] : ["hostUin": "0", "hostuin": uin, "sin": String(start), "size": "200", "loginUin": uin, "g_tk": "5381"])
                guard QQMusicContract.integer(response["code"]) == 0 else {throw Failure.denied}
                let data = response["data"] as? [String: Any] ?? [:]
                let rows = data[collected ? "cdlist" : "disslist"] as? [[String: Any]] ?? []
                cards += rows.map { QQMusicContract.playlist($0, subscribed: collected) }; if rows.count < 200 {break}
            }
        }
        var seen: Set<String> = []; cards = cards.filter {let id = QQMusicContract.text($0["id"]); return !id.isEmpty && seen.insert(id).inserted}
        return ["provider": "qq", "loggedIn": true, "userId": uin, "playlists": cards]
    }
    private func playlistTracks(_ id: String, limit: Int, offset: Int) async throws -> [String: Any] {
        guard try await status()["loggedIn"] as? Bool == true else {return ["provider": "qq", "loggedIn": false, "tracks": []]}
        let data: [String: Any]
        if ["liked", "qq_favorite", "201"].contains(id) {
            let response = try await music(["req_0": ["module": "music.srfDissInfo.DissInfo", "method": "CgiGetDiss", "param": ["disstid": 0, "dirid": 201, "tag": 1, "song_begin": offset, "song_num": limit, "userinfo": 1, "orderlist": 1]]])
            let block = response["req_0"] as? [String: Any] ?? [:]; guard QQMusicContract.integer(block["code"]) == 0, let value = block["data"] as? [String: Any] else {throw Failure.denied}; data = value
        } else {
            guard !id.isEmpty, id.count <= 24, id.allSatisfy({$0.isASCII && $0.isNumber}) else {throw Failure.invalidRequest}
            let response = try await get("https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg", ["type": "1", "utf8": "1", "disstid": id, "song_begin": String(offset), "song_num": String(limit), "loginUin": uin])
            guard QQMusicContract.integer(response["code"]) == 0, let list = response["cdlist"] as? [[String: Any]], let first = list.first else {throw Failure.denied}; data = first
        }
        let raw = data["songlist"] as? [[String: Any]] ?? []
        let songs = Array(raw.prefix(limit)).map(QQMusicContract.song)
        let total = QQMusicContract.integer(data["total_song_num"] ?? data["songnum"])
        let next = offset + songs.count
        return ["provider": "qq", "loggedIn": true, "tracks": songs, "playlist": ["provider": "qq", "id": id, "name": data["dissname"] ?? (id == "liked" ? "我的喜欢" : "")], "offset": offset, "limit": limit, "nextOffset": next, "total": total, "hasMore": next < total || QQMusicContract.integer(data["hasmore"]) > 0, "partial": true]
    }
    private func search(_ term: String, limit: Int, offset: Int) async throws -> [String: Any] {
        guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, term.utf8.count <= 1024 else {return ["provider": "qq", "songs": []]}
        let response = try await music(["comm": ["ct": "11", "cv": "14090508", "v": "14090508", "tmeAppID": "qqmusic", "phonetype": "EBG-AN10", "os_ver": "12", "OpenUDID": "0", "QIMEI36": "0", "udid": "0", "chid": "0", "aid": "0", "oaid": "0", "taid": "0", "tid": "0", "wid": "0", "uid": "0", "sid": "0", "modeSwitch": "6", "teenMode": "0", "ui_mode": "2", "nettype": "1020"], "req": ["module": "music.search.SearchCgiService", "method": "DoSearchForQQMusicMobile", "param": ["search_type": 0, "searchid": String(Int(Date().timeIntervalSince1970 * 1000)), "query": term, "page_num": offset / limit + 1, "num_per_page": limit, "highlight": 0, "nqc_flag": 0, "multi_zhida": 0, "cat": 2, "grp": 1, "sin": offset, "sem": 0]]], signed: true)
        let block = response["req"] as? [String: Any] ?? [:]; guard QQMusicContract.integer(block["code"]) == 0 else {throw Failure.denied}
        let data = block["data"] as? [String: Any] ?? [:], body = data["body"] as? [String: Any] ?? data, song = body["song"] as? [String: Any] ?? [:]
        let rawSongs = body["item_song"] as? [[String: Any]] ?? song["list"] as? [[String: Any]] ?? body["list"] as? [[String: Any]] ?? []
        let songs = rawSongs.map(QQMusicContract.song)
        let total = QQMusicContract.integer(song["sum"] ?? data["sum"])
        return ["provider": "qq", "songs": songs, "total": total, "offset": offset, "limit": limit, "nextOffset": offset + songs.count, "hasMore": total > 0 ? offset + songs.count < total : songs.count == limit]
    }
    private func songURL(_ mid: String, media: String, quality: String) async throws -> [String: Any] {
        guard validMid(mid), media.isEmpty || validMid(media) else {throw Failure.invalidRequest}
        let all: [(String, String, String)] = [("RS01", ".flac", "hires"), ("F000", ".flac", "lossless"), ("M800", ".mp3", "exhigh"), ("M500", ".mp3", "standard"), ("C400", ".m4a", "aac")]
        let start = all.firstIndex {$0.2 == quality} ?? 2
        let candidates = Array(all[start...]); let fileMid = media.isEmpty ? mid : media
        let filenames = candidates.map {$0.0 + fileMid + $0.1}
        let response = try await music(["req_0": ["module": "vkey.GetVkeyServer", "method": "CgiGetVkey", "param": ["guid": String(Int.random(in: 10000000...99999999)), "songmid": filenames.map {_ in mid}, "songtype": filenames.map {_ in 0}, "uin": uin.isEmpty ? "0" : uin, "loginflag": 1, "platform": "20", "filename": filenames]]])
        let block = response["req_0"] as? [String: Any] ?? [:], data = block["data"] as? [String: Any] ?? [:]
        let infos = data["midurlinfo"] as? [[String: Any]] ?? [], sips = data["sip"] as? [String] ?? ["https://ws.stream.qqmusic.qq.com/"]
        let deadline = Date().addingTimeInterval(6.2)
        for info in infos.prefix(5) {
            guard let path = info["purl"] as? String, !path.isEmpty, !path.hasPrefix("//"), !path.contains("://") else {continue}
            for sip in sips.prefix(2) {
                let remaining = deadline.timeIntervalSinceNow; if remaining < 0.3 {break}
                guard var c = URLComponents(string: sip + path), let initial = c.url, QQMusicContract.allowedMedia(initial) else {continue}
                c.scheme = "https"; if c.port == 80 {c.port = nil}; guard let url = c.url, (try? await transport.probe(url, budget: min(2, remaining))) == true else {continue}
                let filename = QQMusicContract.text(info["filename"]), index = filenames.firstIndex(of: filename) ?? 0
                return ["provider": "qq", "url": url.absoluteString, "playable": true, "playbackReady": true, "trialKnown": false, "loggedIn": !uin.isEmpty && !musicKey.isEmpty, "quality": candidates[index].2, "level": candidates[index].2, "filename": filename]
            }
        }
        return ["provider": "qq", "url": "", "playable": false, "error": "QQ_URL_UNAVAILABLE", "message": "QQ 音乐未提供可验证的播放音源，请检查账号授权或歌曲权限。", "qqCode": block["code"] ?? -1]
    }
    private func lyric(_ mid: String) async throws -> [String: Any] {
        guard validMid(mid) else {throw Failure.invalidRequest}
        let response = try await music(["lyric": ["module": "music.musichallSong.PlayLyricInfo", "method": "GetPlayLyricInfo", "param": ["songMID": mid]]])
        let block = response["lyric"] as? [String: Any] ?? [:], data = block["data"] as? [String: Any] ?? [:]
        func decode(_ value: Any?) -> String {let text = QQMusicContract.text(value); return Data(base64Encoded: text).flatMap {String(data: $0, encoding: .utf8)} ?? text}
        return ["provider": "qq", "mid": mid, "lyric": decode(data["lyric"]), "tlyric": decode(data["trans"]), "qrc": decode(data["qrc"]), "roma": decode(data["roma"]), "yrc": ""]
    }
    private func albumDetail(_ mid: String, limit: Int) async throws -> [String: Any] {
        guard validMid(mid) else { throw Failure.invalidRequest }
        let response = try await get("https://c.y.qq.com/v8/fcg-bin/fcg_v8_album_info_cp.fcg", ["albummid": mid, "g_tk": "5381", "loginUin": uin.isEmpty ? "0" : uin, "hostUin": "0"])
        guard response["code"] != nil, QQMusicContract.integer(response["code"]) == 0, let data = response["data"] as? [String: Any] else { throw Failure.denied }
        let raw = data["list"] as? [[String: Any]] ?? data["songlist"] as? [[String: Any]] ?? []
        let name = QQMusicContract.text(data["name"] ?? data["title"] ?? data["albumname"])
        let songs = raw.prefix(limit).map { row -> [String: Any] in
            var track = row
            if QQMusicContract.text(track["albummid"]).isEmpty { track["albummid"] = mid }
            if QQMusicContract.text(track["albumname"]).isEmpty { track["albumname"] = name }
            return QQMusicContract.song(track)
        }
        let total = QQMusicContract.integer(data["total_song_num"] ?? data["total"] ?? data["songnum"] ?? raw.count)
        let album: [String: Any] = ["provider": "qq", "id": data["id"] ?? data["albumid"] ?? "", "mid": mid, "albumMid": mid, "name": name,
                "artist": data["singername"] ?? data["singerName"] ?? songs.first?["artist"] ?? "", "cover": "https://y.qq.com/music/photo_new/T002R300x300M000\(mid).jpg",
                "releaseDate": data["aDate"] ?? data["publictime"] ?? "", "trackCount": total]
        return ["provider": "qq", "album": album, "songs": songs, "total": total]
    }
    private func artistDetail(_ mid: String, limit: Int) async throws -> [String: Any] {
        guard validMid(mid) else { throw Failure.invalidRequest }
        let response = try await music(["singer": ["module": "music.web_singer_info_svr", "method": "get_singer_detail_info", "param": ["sort": 5, "singermid": mid, "sin": 0, "num": limit]]])
        guard (response["code"] == nil || QQMusicContract.integer(response["code"]) == 0), let block = response["singer"] as? [String: Any], block["code"] != nil,
              QQMusicContract.integer(block["code"]) == 0, let data = block["data"] as? [String: Any] else { throw Failure.denied }
        let info = data["singer_info"] as? [String: Any] ?? data["singerInfo"] as? [String: Any] ?? [:]
        let songs = (data["songlist"] as? [[String: Any]] ?? []).prefix(limit).map(QQMusicContract.song)
        let total = QQMusicContract.integer(data["total_song"] ?? data["song_count"] ?? songs.count)
        return ["provider": "qq", "total": total, "songs": songs,
                "artist": ["provider": "qq", "id": info["id"] ?? "", "mid": info["mid"] ?? mid, "name": info["name"] ?? info["title"] ?? "",
                           "avatar": info["pic"] ?? info["avatar"] ?? "https://y.qq.com/music/photo_new/T001R300x300M000\(mid).jpg",
                           "fans": QQMusicContract.integer(info["fans"]), "musicSize": total, "albumSize": QQMusicContract.integer(data["total_album"]), "mvSize": QQMusicContract.integer(data["total_mv"])]]
    }
    private func comments(id: String, mid: String, limit: Int, offset: Int) async throws -> [String: Any] {
        var songID = id
        if songID.isEmpty {
            guard validMid(mid) else { throw Failure.invalidRequest }
            let response = try await music(["songinfo": ["module": "music.pf_song_detail_svr", "method": "get_song_detail_yqq", "param": ["song_mid": mid]]])
            guard let block = response["songinfo"] as? [String: Any], block["code"] != nil, QQMusicContract.integer(block["code"]) == 0,
                  let data = block["data"] as? [String: Any], let track = data["track_info"] as? [String: Any] else { throw Failure.denied }
            songID = QQMusicContract.text(track["id"] ?? track["songid"])
        }
        guard !songID.isEmpty, songID.count < 24, songID.utf8.allSatisfy({ (48...57).contains($0) }) else { throw Failure.invalidRequest }
        let page = offset / limit, skip = offset % limit
        func fetchPage(_ number: Int) async throws -> [String: Any] {
            let response = try await get("https://c.y.qq.com/base/fcgi-bin/fcg_global_comment_h5.fcg", ["g_tk": "5381", "loginUin": uin.isEmpty ? "0" : uin, "hostUin": "0", "cid": "205360772", "reqtype": "2", "biztype": "1", "topid": songID, "cmd": "8", "needmusiccrit": "0", "pagenum": String(number), "pagesize": String(limit)])
            guard response["code"] != nil, QQMusicContract.integer(response["code"]) == 0 else { throw Failure.denied }
            return response
        }
        let response = try await fetchPage(page)
        let regular = response["comment"] as? [String: Any] ?? [:]
        let hotRows = (response["hot_comment"] as? [String: Any])?["commentlist"] as? [[String: Any]] ?? []
        let hot = offset == 0 && !hotRows.isEmpty
        var rows = hot ? hotRows : regular["commentlist"] as? [[String: Any]] ?? []
        let total = QQMusicContract.integer(regular["commenttotal"] ?? regular["comment_total"] ?? rows.count)
        if !hot && skip > 0 && rows.count >= limit && offset + limit < total {
            let second = try await fetchPage(page + 1)
            rows += (second["comment"] as? [String: Any])?["commentlist"] as? [[String: Any]] ?? []
        }
        let selected = hot ? Array(rows.prefix(limit)) : Array(rows.dropFirst(skip).prefix(limit))
        let comments = selected.map { raw -> [String: Any] in
            let user = raw["user"] as? [String: Any] ?? [:]
            let seconds = Int64(QQMusicContract.integer(raw["time"] ?? raw["commenttime"] ?? raw["createTime"]))
            return ["id": raw["commentid"] ?? raw["commentId"] ?? raw["id"] ?? "", "content": raw["rootcommentcontent"] ?? raw["content"] ?? "",
                    "likedCount": QQMusicContract.integer(raw["praisenum"] ?? raw["praise_num"] ?? raw["likedCount"]), "time": seconds > 0 && seconds < 10000000000 ? seconds * 1000 : seconds,
                    "user": ["id": raw["encrypt_uin"] ?? raw["uin"] ?? user["uin"] ?? "", "nickname": raw["nick"] ?? raw["nickname"] ?? user["nickname"] ?? "QQ 音乐用户", "avatar": raw["avatarurl"] ?? user["avatarurl"] ?? ""]]
        }
        return ["provider": "qq", "id": songID, "total": total, "comments": comments, "hot": hot, "offset": offset, "nextOffset": offset + selected.count, "hasMore": !hot && offset + selected.count < total]
    }
    private func validMid(_ value: String) -> Bool {!value.isEmpty && value.count <= 64 && value.allSatisfy {$0.isASCII && ($0.isLetter || $0.isNumber)}}
    private func get(_ base: String, _ values: [String: String]) async throws -> [String: Any] {
        var url = URLComponents(string: base)!
        var fields = ["format": "json", "inCharset": "utf8", "outCharset": "utf-8", "notice": "0", "platform": "yqq.json", "needNewCode": "0"]
        fields.merge(values) {_, new in new}; url.queryItems = fields.sorted {$0.key < $1.key}.map {URLQueryItem(name: $0.key, value: $0.value)}
        return try await send(URLRequest(url: url.url!))
    }
    private func music(_ value: [String: Any], signed: Bool = false) async throws -> [String: Any] {
        var payload = value
        if payload["comm"] == nil {
            var comm: [String: Any] = ["uin": uin.isEmpty ? "0" : uin, "format": "json", "ct": musicKey.isEmpty ? 24 : 19, "cv": 0]
            if !musicKey.isEmpty {comm["authst"] = musicKey}; payload["comm"] = comm
        }
        let body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
        var c = URLComponents(string: "https://u.y.qq.com/cgi-bin/" + (signed ? "musics.fcg" : "musicu.fcg"))!
        if signed {c.queryItems = [URLQueryItem(name: "sign", value: QQMusicContract.searchSign(body))]}
        var request = URLRequest(url: c.url!, timeoutInterval: signed ? 10 : 6); request.httpMethod = "POST"; request.httpBody = body
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        if signed {request.setValue("QQMusic 14090508(android 12)", forHTTPHeaderField: "User-Agent")}
        return try await send(request)
    }
    private func send(_ input: URLRequest) async throws -> [String: Any] {
        guard let url = input.url, QQMusicContract.allowedAPI(url) else {throw Failure.invalidRequest}
        var request = input
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        if request.value(forHTTPHeaderField: "User-Agent") == nil {request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15", forHTTPHeaderField: "User-Agent")}
        request.setValue(cookies.sorted {$0.key < $1.key}.map {"\($0.key)=\($0.value)"}.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        let response = try await transport.request(request)
        guard response.url == url, (200..<300).contains(response.status), response.data.count <= 8 * 1024 * 1024 else {throw Failure.denied}
        var text = String(decoding: response.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("callback("), let last = text.lastIndex(of: ")") {text = String(text[text.index(text.startIndex, offsetBy: 9)..<last])}
        guard let data = text.data(using: .utf8), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {throw Failure.invalidResponse}
        return object
    }
    private func save() throws {
        guard let service = keychainService else {return}
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        if cookies.isEmpty {let result = SecItemDelete(query as CFDictionary); guard result == errSecSuccess || result == errSecItemNotFound else {throw Failure.keychain}; return}
        let bytes = try JSONSerialization.data(withJSONObject: cookies)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
        if status == errSecItemNotFound {var insert = query; insert[kSecValueData as String] = bytes; insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly; status = SecItemAdd(insert as CFDictionary, nil)}
        guard status == errSecSuccess else {throw Failure.keychain}
    }
    enum Failure: LocalizedError {case invalidRequest, invalidResponse, denied, keychain
        var errorDescription: String? {switch self {case .invalidRequest: return "QQ 音乐请求参数无效。"; case .invalidResponse: return "QQ 音乐返回的数据无法识别。"; case .denied: return "QQ 音乐暂未授权此请求，请重新登录或稍后重试。"; case .keychain: return "无法安全保存 QQ 音乐会话。"}}
    }
}
