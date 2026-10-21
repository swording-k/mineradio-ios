import Foundation
private actor QQFixture: QQMusicRequesting {
    var rejected = false
    func reject() { rejected = true }
    func request(_ request: URLRequest) throws -> QQMusicHTTPResponse {
        let url = request.url!
        var value: [String: Any] = [:]
        if url.path.contains("profile_homepage") { value = ["code": 0, "data": ["creator": ["uin": "123", "nick": "Fixture"]]] }
        else if url.path.contains("musicu") {
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            if body["req_0"] != nil {value = rejected ? ["req_0": ["code": 1000]] : ["req_0": ["code": 0, "data": ["songlist": [], "dirinfo": ["uin": "123"]]]]}
        } else if url.path.contains("fcg_user_created_diss") {
            value = ["code": 0, "data": ["disslist": [["dissid": "456", "diss_name": "Created", "song_cnt": 2]]]]
        } else if url.path.contains("fcg_get_profile_order_asset") {
            value = ["code": 0, "data": ["cdlist": [["dissid": "789", "diss_name": "Collected", "song_cnt": 1]]]]
        } else if url.path.contains("getcdinfo") {
            value = ["code": 0, "cdlist": [["dissname": "Created", "total_song_num": 2, "songlist": [["songmid": "mid1", "songname": "First", "interval": 1]]]]]
        } else if url.path.contains("musics") {
            value = ["req": ["code": 0, "data": ["body": ["item_song": [["mid": "mid1", "name": "Song", "interval": 100, "singer": [["name": "Artist"]], "album": ["mid": "alb"]]]]]]]
        }
        return QQMusicHTTPResponse(data: try JSONSerialization.data(withJSONObject: value), status: 200, url: url)
    }
    func probe(_ url: URL, budget: TimeInterval) -> Bool { false }
}
@main struct QQMusicNativeTests {
    static func main() async throws {
        precondition(QQMusicContract.searchSign(Data("fixture".utf8)) == "zzc0fca11ecohavyruywqpsso7tfjwbd5n3hk11b5e2f3")
        let fixture = QQFixture()
        let api = QQMusicNativeAPI(transport: fixture, keychainService: nil)
        let cookie = HTTPCookie(properties: [.domain: ".qq.com", .path: "/", .name: "uin", .value: "o123"])!
        let key = HTTPCookie(properties: [.domain: ".qq.com", .path: "/", .name: "qqmusic_key", .value: "fixture"])!
        let status = try await api.setSession([cookie, key])
        precondition(status["loggedIn"] as? Bool == true)
        precondition(status["membershipKnown"] as? Bool == false)
        precondition(status["cookie"] == nil)
        let lists = try await api.handle(URL(string: "http://127.0.0.1/api/qq/user/playlists")!, method: "GET", body: Data())
        let cards = lists["playlists"] as! [[String: Any]]
        precondition(cards.count == 3 && cards[0]["id"] as? String == "liked")
        let page = try await api.handle(URL(string: "http://127.0.0.1/api/qq/playlist/tracks?id=456&limit=1&offset=0")!, method: "GET", body: Data())
        precondition(page["nextOffset"] as? Int == 1 && page["hasMore"] as? Bool == true)
        let invalidHostCookie = HTTPCookie(properties: [.domain: "qq.com.evil.test", .path: "/", .name: "qqmusic_key", .value: "fixture"])!
        let isolated = QQMusicNativeAPI(transport: fixture, keychainService: nil)
        let invalid = try await isolated.setSession([cookie, invalidHostCookie])
        precondition(invalid["loggedIn"] as? Bool == false)
        await fixture.reject()
        let denied = try await api.handle(URL(string: "http://127.0.0.1/api/qq/login/status")!, method: "GET", body: Data())
        precondition(denied["loggedIn"] as? Bool == false)
        let search = try await api.handle(URL(string: "http://127.0.0.1/api/qq/search?keywords=Fixture")!, method: "GET", body: Data())
        let song = (search["songs"] as! [[String: Any]])[0]
        precondition(song["duration"] as? Int == 100000)
        precondition(song["provider"] as? String == "qq")
        precondition(!QQMusicContract.allowedAPI(URL(string: "https://u.y.qq.com.evil.test/cgi-bin/musicu.fcg")!))
        precondition(!QQMusicContract.allowedMedia(URL(string: "https://127.0.0.1/a.mp3")!))
        precondition(QQMusicContract.allowedMedia(URL(string: "https://ws.stream.qqmusic.qq.com/a.mp3")!))
        let loggedOut = try await api.handle(URL(string: "http://127.0.0.1/api/qq/logout")!, method: "GET", body: Data())
        precondition(loggedOut["loggedIn"] as? Bool == false)
        print("QQMusic fixtures: authenticated status denial, cookie privacy, unknown membership, mapping, media boundary and logout passed")
    }
}
