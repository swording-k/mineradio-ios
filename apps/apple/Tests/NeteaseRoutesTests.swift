import Foundation

private actor FixtureTransport: NeteaseRequesting {
    var loggedOut = false
    func clear() { loggedOut = true }
    func call(_ path: String, _ fields: [String: Any]) throws -> [String: Any] {
        switch path {
        case "/api/login/qrcode/client/login": return ["code": 803]
        case "/api/w/nuser/account/get":
            return loggedOut ? ["code": 200] : ["code": 200, "profile": ["userId": 123, "nickname": "Fixture", "vipType": 11]]
        case "/api/user/playlist":
            precondition(fields["uid"] as? Int == 123)
            precondition(fields["limit"] as? Int == 2)
            return ["playlist": [["id": 42, "name": "Fixture list", "coverImgUrl": "https://p1.music.126.net/test.jpg", "trackCount": 3]], "more": true]
        case "/api/v6/playlist/detail":
            return ["playlist": ["id": 42, "name": "Fixture list", "trackIds": [["id": 1], ["id": 2], ["id": 3]]]]
        case "/api/v3/song/detail":
            let c = try JSONSerialization.jsonObject(with: Data((fields["c"] as! String).utf8)) as! [[String: Int]]
            precondition(c.map { $0["id"]! } == [2, 3])
            return ["songs": [["id": 2, "name": "Song 2"], ["id": 3, "name": "Song 3"]]]
        case "/api/song/enhance/player/url/v1": return ["data": [["code": 403, "url": NSNull()]]]
        default: preconditionFailure("Unexpected endpoint \(path)")
        }
    }
}

@main struct NeteaseRoutesTests {
    static func main() async throws {
        let api = NeteaseNativeAPI(transport: FixtureTransport())
        func request(_ path: String) async throws -> [String: Any] {
            try await api.handle(URL(string: "http://127.0.0.1:19363" + path)!, method: "GET", body: Data())
        }
        let login = try await request("/api/login/qr/check?key=fixture")
        precondition(login["loggedIn"] as? Bool == true)
        precondition(login["userId"] as? Int == 123)
        precondition(login["cookie"] == nil)
        precondition(login["membershipKnown"] as? Bool == false)
        precondition(login["isSvip"] as? Bool == false)
        let lists = try await request("/api/user/playlists?limit=2&offset=0")
        precondition((lists["playlists"] as? [[String: Any]])?.count == 1)
        precondition(lists["hasMore"] as? Bool == true)
        precondition(lists["nextOffset"] as? Int == 1)
        let page = try await request("/api/playlist/tracks?id=42&limit=2&offset=1")
        precondition((page["tracks"] as? [[String: Any]])?.count == 2)
        precondition(page["hasMore"] as? Bool == false)
        precondition(page["total"] as? Int == 3)
        let denied = try await request("/api/song/url?id=2")
        precondition(denied["url"] == nil)
        _ = try await request("/api/logout")
        let afterLogout = try await request("/api/login/status")
        precondition(afterLogout["loggedIn"] as? Bool == false)
        print("Netease routes: QR authorization, account identity, pagination, denied playback, no cookie disclosure and logout passed")
    }
}
