import Foundation
import Security

protocol BodianRequesting: Actor { func request(_ request: URLRequest) async throws -> [String: Any] }
private final class BodianRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
actor BodianTransport: BodianRequesting {
    private let session: URLSession
    init() {
        let c = URLSessionConfiguration.ephemeral
        c.httpCookieStorage = nil; c.timeoutIntervalForRequest = 12; c.timeoutIntervalForResource = 20
        session = URLSession(configuration: c, delegate: BodianRedirectGuard(), delegateQueue: nil)
    }
    func request(_ request: URLRequest) async throws -> [String: Any] {
        guard let u = request.url, BodianContract.allowedAPI(u) else { throw BodianFailure.invalidInput }
        let (bytes, response) = try await session.data(for: request)
        guard bytes.count <= 4 * 1024 * 1024, let http = response as? HTTPURLResponse, http.statusCode == 200, let final = http.url, BodianContract.allowedAPI(final), let json = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw BodianFailure.unavailable }
        return json
    }
}
enum BodianFailure: LocalizedError {
    case invalidInput, unavailable, sessionChanged, storage, upstream(Int)
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "波点请求参数不完整。"
        case .unavailable: return "波点接口暂不可用，请稍后重试。"
        case .sessionChanged: return "波点账号已切换，请重试。"
        case .storage: return "波点登录状态无法安全保存。"
        case .upstream(let code): return code == 407 ? "该资源仅限中国大陆地区使用。" : code == 11012 ? "请先登录波点音乐。" : "波点接口返回错误（\(code)）。"
        }
    }
}
actor BodianNativeAPI {
    private struct Session: Codable { let uid: String; let token: String; let nickname: String; let avatar: String }
    private let transport: any BodianRequesting
    private let keychainService: String?
    private let deviceID: String
    private var session: Session?
    private var qr: [String: Date] = [:]
    private var generation = 0
    init(transport: any BodianRequesting = BodianTransport(), keychainService: String? = "com.swordingk.mineradio.bodian.apple", deviceID: String? = nil) {
        self.transport = transport; self.keychainService = keychainService
        let key = "mineradio-bodian-device-id"
        let stored = UserDefaults.standard.string(forKey: key) ?? ""
        let device = deviceID ?? (stored.count == 32 ? stored : UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())
        self.deviceID = device
        if deviceID == nil { UserDefaults.standard.set(device, forKey: key) }
        if let service = keychainService {
            var value: CFTypeRef?
            if SecItemCopyMatching([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session", kSecReturnData as String: true] as CFDictionary, &value) == errSecSuccess, let d = value as? Data { session = try? JSONDecoder().decode(Session.self, from: d) }
        }
    }
    private func save(_ s: Session?) throws {
        guard let service = keychainService else { return }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        guard let s else { let code = SecItemDelete(q as CFDictionary); guard code == errSecSuccess || code == errSecItemNotFound else { throw BodianFailure.storage }; return }
        let fields: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(s)]
        let result = SecItemUpdate(q as CFDictionary, fields as CFDictionary)
        if result == errSecItemNotFound {
            guard SecItemAdd(q.merging(fields) { _, n in n }.merging([kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]) { _, n in n } as CFDictionary, nil) == errSecSuccess else { throw BodianFailure.storage }
        } else if result != errSecSuccess { throw BodianFailure.storage }
    }
    private func call(_ path: String, _ values: [String: String] = [:], signed: Bool = false, anonymous: Bool = false, body: [String: Any]? = nil, lyric: Bool = false) async throws -> [String: Any] {
        let expected = generation, account = anonymous ? nil : session
        var params = values; params["uid"] = account?.uid ?? "-1"; params["token"] = account?.token ?? ""
        let bytes = try body.map { try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys, .withoutEscapingSlashes]) }
        let bodyText = bytes.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        if signed { params["timestamp"] = String(Int64(Date().timeIntervalSince1970 * 1000)) }
        // URLSearchParams uses application/x-www-form-urlencoded encoding (space -> +).
        func form(_ s: String) -> String { s.utf8.map { b in ((48...57).contains(b) || (65...90).contains(b) || (97...122).contains(b) || [42,45,46,95].contains(b)) ? String(UnicodeScalar(b)) : b == 32 ? "+" : String(format: "%%%02X", b) }.joined() }
        var query = params.keys.sorted().map { form($0) + "=" + form(params[$0]!) }.joined(separator: "&")
        if signed { query += "&sign=" + BodianContract.sign(path: path, query: query, body: bodyText) }
        guard let u = URL(string: (lyric ? "https://mlyric.kuwo.cn" : "https://bd-api.kuwo.cn") + path + "?" + query), BodianContract.allowedAPI(u) else { throw BodianFailure.invalidInput }
        var r = URLRequest(url: u); r.httpMethod = body == nil ? "GET" : "POST"; r.httpBody = bytes
        r.allHTTPHeaderFields = ["User-Agent": "Dart/3.3 (dart:io)", "plat": "win", "channel": "W1", "ver": "1.1.7", "svrver": "13", "api-ver": "application/json", "brand": "Windows", "net": "wifi", "devid": deviceID, "qimei36": deviceID, "Content-Type": "application/json"]
        if let account { r.setValue(account.uid, forHTTPHeaderField: "uid"); r.setValue(account.token, forHTTPHeaderField: "token") }
        let json = try await transport.request(r)
        guard expected == generation else { throw BodianFailure.sessionChanged }
        let code = Int(BodianContract.text(json["code"])) ?? 0
        guard code == 200 else { throw BodianFailure.upstream(code) }
        return json["data"] as? [String: Any] ?? [:]
    }
    private func status() -> [String: Any] { ["provider": "bodian", "loggedIn": session != nil, "userId": session?.uid ?? "", "nickname": session?.nickname ?? "波点音乐", "avatar": session?.avatar ?? "", "membershipKnown": false] }
    func handle(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ k: String) -> String { parts.first { $0.name == k }?.value ?? "" }
        let path = url.path
        if path == "/api/bodian/logout" && method == "POST" { try save(nil); generation += 1; session = nil; qr.removeAll(); return status() }
        guard method == "GET" else { throw BodianFailure.invalidInput }
        if path == "/api/bodian/login/status" { return status() }
        if path == "/api/bodian/login/qr/key" {
            qr = qr.filter { $0.value > Date() }; guard qr.count < 5 else { throw BodianFailure.unavailable }
            let d = try await call("/api/ucenter/login/qrCode", signed: true, anonymous: true), key = BodianContract.text(d["qrCode"])
            guard !key.isEmpty, key.count <= 512 else { throw BodianFailure.unavailable }
            qr[key] = Date().addingTimeInterval(300)
            var c = URLComponents(string: "https://bodian-oia.kuwo.cn/bodian/download.html")!
            c.queryItems = [URLQueryItem(name: "pageName", value: "login_pc"), URLQueryItem(name: "pt", value: "3"), URLQueryItem(name: "id", value: key)]
            return ["provider": "bodian", "ok": true, "key": key, "url": c.url!.absoluteString, "message": "请使用波点音乐 App 扫码"]
        }
        if path == "/api/bodian/login/qr/check" {
            let key = q("key"); guard let expiry = qr[key], expiry > Date() else { return ["provider": "bodian", "code": 800, "status": "expired"] }
            let d = try await call("/api/ucenter/login/qrCodeStatus", ["qrCode": key], signed: true, anonymous: true)
            let state = Int(BodianContract.text(d["status"])) ?? 0
            if state == 1 { return ["provider": "bodian", "code": 801, "status": "wait"] }
            if state == 2 { qr[key] = nil; return ["provider": "bodian", "code": 800, "status": "expired"] }
            guard state == 3 else { throw BodianFailure.unavailable }
            let login: [String: Any]
            do { login = try await call("/api/ucenter/users/login", signed: true, anonymous: true, body: ["authType": 10, "qrCode": key]) }
            catch BodianFailure.upstream(11027) { return ["provider": "bodian", "code": 802, "status": "scanned"] }
            guard qr[key] == expiry, expiry > Date() else { throw BodianFailure.sessionChanged }
            let user = (login["userInfo"] ?? login["user"]) as? [String: Any] ?? [:]
            let ids = [login["id"], login["uid"], user["id"], user["uid"]].compactMap { value -> String? in guard let value else { return nil }; return BodianContract.text(value) }
            let token = BodianContract.text(login["token"])
            guard let uid = ids.first, BodianContract.id(uid), ids.allSatisfy({ $0 == uid }), !token.isEmpty, token.count <= 8192 else { throw BodianFailure.unavailable }
            let s = Session(uid: uid, token: token, nickname: BodianContract.text(user["nickname"]), avatar: BodianContract.text(user["headImg"] ?? user["avatarUrl"]))
            try save(s); session = s; generation += 1; qr.removeAll()
            return status().merging(["code": 803, "status": "confirmed"]) { _, n in n }
        }
        let limit = min(100, max(1, Int(q("limit")) ?? 30)), offset = min(100000, max(0, Int(q("offset")) ?? 0))
        if path == "/api/bodian/search" {
            let keyword = q("keywords").isEmpty ? q("keyword") : q("keywords")
            guard !keyword.isEmpty, keyword.count <= 500 else { throw BodianFailure.invalidInput }
            let d = try await call("/api/search/music/list", ["keyword": keyword, "correct": "1", "pn": String(offset / limit), "rn": String(limit)])
            let raw = d["resultList"] as? [[String: Any]] ?? [], songs = raw.compactMap(BodianContract.song)
            return ["provider": "bodian", "songs": songs, "offset": offset, "limit": limit, "nextOffset": offset + raw.count, "hasMore": offset + raw.count < (Int(BodianContract.text(d["total"])) ?? offset + raw.count)]
        }
        let id = q("id")
        if path == "/api/bodian/song/url" {
            guard BodianContract.id(id) else { throw BodianFailure.invalidInput }
            let right = try await call("/api/play/music/v2/checkRight", ["musicId": id, "freeSign": ""], signed: true)
            let state = Int(BodianContract.text(right["status"]))
            if state == 3 {
                let a = right["audition"] as? [String: Any] ?? [:], link = BodianContract.text(a["https"] ?? a["url"])
                guard BodianContract.allowedMedia(link), let start = Double(BodianContract.text(a["start"])), let end = Double(BodianContract.text(a["end"])), start.isFinite, end.isFinite, start >= 0, end > start else { throw BodianFailure.unavailable }
                return ["provider": "bodian", "url": link, "playable": true, "trial": true, "trialInfo": ["startTime": start, "endTime": end], "loggedIn": session != nil]
            }
            guard let state, state != 7 else { return ["provider": "bodian", "url": "", "playable": false, "reason": session == nil ? "login_required" : "vip_required"] }
            let quality = q("quality").isEmpty ? q("level") : q("quality")
            let lossless = ["lossless", "hires"].contains(quality), standard = quality == "standard"
            let d = try await call("/api/play/music/v2/audioUrl", ["musicId": id, "freeSign": "", "devId": deviceID, "format": lossless ? "flac" : "mp3", "br": lossless ? "2000kflac" : standard ? "128kmp3" : "320kmp3"], signed: true)
            let link = BodianContract.text(d["audioHttpsUrl"] ?? d["audioUrl"])
            guard BodianContract.allowedMedia(link) else { throw BodianFailure.unavailable }
            return ["provider": "bodian", "url": link, "playable": true, "trial": false, "level": quality, "loggedIn": session != nil]
        }
        if path == "/api/bodian/lyric" {
            guard BodianContract.id(id) else { throw BodianFailure.invalidInput }
            let query = "type=lyric&req=2&lrcx=1&rid=\(id)&songname=&artist=&corp=kuwo&fromchannel=bodian"
            let d = try await call("/mobi.s", ["f": "bodian", "q": Data(query.utf8).base64EncodedString()], lyric: true)
            let raw = Data(base64Encoded: BodianContract.text(d["content"])).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let clean = raw.replacingOccurrences(of: "<-?\\d+,-?\\d+>|\\[kuwo:[^\\]]*\\]", with: "", options: .regularExpression)
            return ["provider": "bodian", "lyric": clean, "wordByWordLyric": ""]
        }
        if path == "/api/bodian/user/playlists" {
            guard let uid = session?.uid else { return ["provider": "bodian", "loggedIn": false, "playlists": []] }
            let mine = try await call("/api/service/playlist/userCreate", ["userId": uid, "fromUid": uid])
            let liked = try await call("/api/service/playlist/fond", ["userId": uid, "fromUid": uid])
            var cards = (mine["playLists"] as? [[String: Any]] ?? []).compactMap { BodianContract.playlist($0, source: 4) }
            if let card = BodianContract.playlist(liked, source: 5) { cards.append(card) }
            return ["provider": "bodian", "loggedIn": true, "playlists": cards, "userId": uid]
        }
        if path == "/api/bodian/playlist/tracks" {
            guard BodianContract.id(id) else { throw BodianFailure.invalidInput }
            let source = q("source") == "5" ? 5 : 4
            var data: [String: Any] = [:]
            for s in [source, source == 4 ? 5 : 4] {
                data = try await call("/api/service/playlist/\(id)/musicList", ["source": String(s), "pn": String(offset / limit + 1), "rn": String(limit)])
                if !(data["list"] as? [[String: Any]] ?? data["resultList"] as? [[String: Any]] ?? []).isEmpty { break }
            }
            let raw = data["list"] as? [[String: Any]] ?? data["resultList"] as? [[String: Any]] ?? []
            let total = Int(BodianContract.text(data["total"])) ?? raw.count
            return ["provider": "bodian", "tracks": raw.compactMap(BodianContract.song), "total": total, "nextOffset": offset + raw.count, "hasMore": offset + raw.count < total]
        }
        throw BodianFailure.invalidInput
    }
}
