import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

actor NeteaseNativeAPI {
    let transport: any NeteaseRequesting
    private var cachedStatus: [String: Any]?
    private var statusCheckedAt = Date.distantPast
    init(transport: any NeteaseRequesting = NeteaseTransport()) { self.transport = transport }

    func handle(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ name: String) -> String { query.first { $0.name == name }?.value ?? "" }
        func number(_ name: String, _ fallback: Int, _ maxValue: Int) -> Int { min(maxValue, max(0, Int(q(name)) ?? fallback)) }
        func id() throws -> String {
            let value = q("id")
            guard !value.isEmpty, value.count < 24, value.allSatisfy(\.isNumber) else { throw NeteaseTransport.TransportError.invalidRequest }
            return value
        }
        switch url.path {
        case "/api/login/qr/key":
            let result = try await transport.call("/api/login/qrcode/unikey", ["type": 3])
            let data = result["data"] as? [String: Any] ?? result
            guard let key = data["unikey"] as? String else { return failure(result) }
            return ["key": key]
        case "/api/login/qr/create":
            let key = q("key")
            guard !key.isEmpty, key.count < 512 else { throw NeteaseTransport.TransportError.invalidRequest }
            var components = URLComponents(string: "https://music.163.com/login")!
            components.queryItems = [URLQueryItem(name: "codekey", value: key)]
            let text = components.url!.absoluteString
            let filter = CIFilter(name: "CIQRCodeGenerator")!
            filter.setValue(Data(text.utf8), forKey: "inputMessage")
            guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
                  let cgImage = CIContext().createCGImage(image, from: image.extent) else { throw NeteaseTransport.TransportError.invalidResponse }
            let png = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else { throw NeteaseTransport.TransportError.invalidResponse }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else { throw NeteaseTransport.TransportError.invalidResponse }
            return ["img": "data:image/png;base64," + (png as Data).base64EncodedString(), "url": text]
        case "/api/login/qr/check":
            let result = try await transport.call("/api/login/qrcode/client/login", ["key": q("key"), "type": 3])
            let code = (result["code"] as? NSNumber)?.intValue ?? 0
            var output: [String: Any] = ["code": code, "message": result["message"] ?? "", "nickname": result["nickname"] ?? "", "avatar": result["avatarUrl"] ?? ""]
            if code == 803 {
                cachedStatus = nil
                output.merge(try await status()) { _, new in new }
            }
            return output
        case "/api/login/status": return try await status()
        case "/api/logout":
            try await transport.clear()
            cachedStatus = nil
            return ["ok": true]
        case "/api/user/playlists":
            let account = try await status()
            guard account["loggedIn"] as? Bool == true, let uid = account["userId"] else { return ["loggedIn": false, "playlists": []] }
            let limit = number("limit", 48, 200), offset = number("offset", 0, 100000)
            let result = try await transport.call("/api/user/playlist", ["uid": uid, "limit": limit, "offset": offset, "includeVideo": true])
            guard let lists = result["playlist"] as? [[String: Any]] else { return failure(result) }
            let more = result["more"] as? Bool ?? (lists.count == limit)
            return ["loggedIn": true, "userId": uid, "playlists": lists.map(NeteaseContract.playlist),
                    "offset": offset, "limit": limit, "nextOffset": offset + lists.count, "hasMore": more, "partial": true]
        case "/api/playlist/tracks":
            let playlistID = try id(), limit = number("limit", 48, 200), offset = number("offset", 0, 100000)
            let result = try await transport.call("/api/v6/playlist/detail", ["id": playlistID, "n": 100000, "s": 0])
            guard let list = result["playlist"] as? [String: Any], let ids = list["trackIds"] as? [[String: Any]] else { return failure(result) }
            let page = ids.dropFirst(offset).prefix(limit).compactMap { $0["id"] }.map { ["id": $0] }
            var tracks: [[String: Any]] = []
            if !page.isEmpty {
                let c = String(decoding: try JSONSerialization.data(withJSONObject: page), as: UTF8.self)
                let detail = try await transport.call("/api/v3/song/detail", ["c": c])
                guard let songs = detail["songs"] as? [[String: Any]] else { return failure(detail) }
                tracks = songs.map(NeteaseContract.song)
            }
            return ["playlist": NeteaseContract.playlist(list), "tracks": tracks, "offset": offset, "limit": limit,
                    "nextOffset": offset + page.count, "total": ids.count, "hasMore": offset + page.count < ids.count, "partial": true]
        case "/api/search":
            let limit = number("limit", 20, 50), offset = number("offset", 0, 100000)
            let result = try await transport.call("/api/cloudsearch/pc", ["s": q("keywords"), "type": 1, "limit": limit, "offset": offset, "total": true])
            guard let found = result["result"] as? [String: Any] else { return failure(result) }
            let songs = found["songs"] as? [[String: Any]] ?? []
            let total = (found["songCount"] as? NSNumber)?.intValue ?? offset + songs.count
            return ["songs": songs.map(NeteaseContract.song), "offset": offset, "limit": limit,
                    "nextOffset": offset + songs.count, "hasMore": offset + songs.count < total]
        case "/api/song/url":
            let songID = try id()
            let quality = ["standard", "exhigh", "lossless", "hires", "jymaster"].contains(q("quality")) ? q("quality") : "exhigh"
            let result = try await transport.call("/api/song/enhance/player/url/v1", ["ids": "[\(songID)]", "level": quality, "encodeType": "aac"])
            return NeteaseContract.playback(result)
        case "/api/lyric":
            let result = try await transport.call("/api/song/lyric", ["id": try id(), "tv": -1, "lv": -1, "rv": -1, "kv": -1])
            var output: [String: Any] = ["source": "netease-native-eapi"]
            for key in ["lrc", "tlyric", "yrc", "ytlrc", "romalrc", "yromalrc"] {
                output[key == "lrc" ? "lyric" : key] = (result[key] as? [String: Any])?["lyric"] ?? ""
            }
            return output
        case "/api/discover/home":
            let account = try await status()
            let personalized = try await transport.call("/api/personalized/playlist", ["limit": 12, "total": true, "n": 1000])
            var daily: [[String: Any]] = []
            if account["loggedIn"] as? Bool == true {
                let recommended = try await transport.call("/api/v3/discovery/recommend/songs", [:])
                daily = ((recommended["data"] as? [String: Any])?["dailySongs"] as? [[String: Any]] ?? []).map(NeteaseContract.song)
            }
            return ["loggedIn": account["loggedIn"] ?? false, "dailySongs": daily,
                    "playlists": (personalized["result"] as? [[String: Any]] ?? []).map(NeteaseContract.playlist), "podcasts": []]
        default:
            if let result = try await handleFeature(url, method: method, body: body) { return result }
            return ["ok": false, "code": 501, "supported": false, "error": "APPLE_CAPABILITY_NOT_IMPLEMENTED",
                    "message": "此功能尚未完成 Apple 端适配。", "loggedIn": false, "songs": [], "playlists": []]
        }
    }

    func status() async throws -> [String: Any] {
        if let cachedStatus, Date().timeIntervalSince(statusCheckedAt) < 5 { return cachedStatus }
        let body = try await transport.call("/api/w/nuser/account/get", [:])
        let profile = body["profile"] as? [String: Any] ?? [:]
        let account = body["account"] as? [String: Any] ?? [:]
        guard let uid = profile["userId"] ?? account["id"], !(uid is NSNull) else {
            return ["loggedIn": false, "membershipKnown": false]
        }
        // A profile VIP badge is not authoritative proof of tier/playback rights.
        let result: [String: Any] = ["loggedIn": true, "userId": uid, "nickname": profile["nickname"] ?? "网易云用户",
                "avatar": profile["avatarUrl"] ?? "", "vipType": profile["vipType"] ?? 0,
                "membershipKnown": false, "vipLevel": "unknown", "isVip": false, "isSvip": false, "vipLabel": "权益待核验"]
        cachedStatus = result; statusCheckedAt = Date()
        return result
    }

    private func failure(_ result: [String: Any]) -> [String: Any] {
        ["ok": false, "code": result["code"] ?? 502, "error": "NETEASE_REQUEST_FAILED",
         "message": result["message"] ?? "网易云没有返回所需数据，请确认登录状态后重试。"]
    }
}
