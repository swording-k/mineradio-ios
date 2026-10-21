import Foundation
private actor Fixtures: KugouRequesting {
    var calls: [URLRequest] = []
    var reject = false
    func request(_ request: URLRequest) async throws -> [String: Any] {
        calls.append(request)
        switch request.url!.path {
        case "/v7/get_all_list":
            if reject { return ["status": 0, "error_code": 20010] }
            return ["status": 1, "data": ["info": [["listid": 55, "name": "My list", "list_create_userid": 123, "nickname": "Fixture"]]]]
        case "/v4/get_list_all_file":
            let payload = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any] ?? [:]
            let page = (payload["page"] as? Int) ?? 1
            return ["status": 1, "data": ["count": 3, "info": [["hash": String(repeating: "a", count: 32), "name": "Track\(page)", "duration": 120, "singerinfo": [["name": "Artist"]]]]]]
        case "/song_search_v2": return ["status": 1, "data": ["lists": [["FileHash": String(repeating: "a", count: 32), "SongName": "Track", "SingerName": "Artist", "Duration": 120]]]]
        case "/play/songinfo": return ["status": 1, "data": ["play_url": "https://webfs.kugou.com/fixture.mp3", "is_free_part": 1]]
        case "/search": return ["candidates": [["id": "42", "accesskey": "fixture"]]]
        case "/download": return ["content": Data("[00:00.00]Fixture".utf8).base64EncodedString()]
        default: return [:]
        }
    }
    func deny() { reject = true }
    func count() -> Int { calls.count }
    func cookieHeaders() -> [String] { calls.compactMap { $0.value(forHTTPHeaderField: "Cookie") } }
}
@main struct KugouNativeTests {
    static func main() async throws {
        precondition(KugouContract.signature(["appid": "1014", "userid": "123", "token": "fixture"], body: "{\"page\":1,\"userid\":123}") == "66dba5fe685bd55b0cccf0ecc2abc3fa")
        precondition(!KugouContract.allowedAPI(URL(string: "https://songsearch.kugou.com.evil.test/song_search_v2")!))
        precondition(!KugouContract.allowedMedia(URL(string: "http://127.0.0.1/a")!))
        let fixture = Fixtures(), key = "com.swordingk.mineradio.kugou.test.\(UUID())"
        let api = KugouNativeAPI(transport: fixture, keychainService: key)
        func route(_ path: String) -> URL { URL(string: "http://127.0.0.1:19363/api/kugou/" + path)! }
        let guest = try await api.handle(route("login/status"), method: "GET", body: Data())
        precondition(guest["loggedIn"] as? Bool == false)
        let cookie = { (name: String, value: String) in HTTPCookie(properties: [.domain: ".kugou.com", .path: "/", .name: name, .value: value])! }
        try await api.setSession([cookie("userid", "123"), cookie("token", "fixture"), HTTPCookie(properties: [.domain: "evil.test", .path: "/", .name: "token", .value: "evil"])!])
        let status = try await api.handle(route("login/status"), method: "GET", body: Data())
        precondition(status["loggedIn"] as? Bool == true)
        precondition(status["membershipKnown"] as? Bool == false)
        precondition(status["token"] == nil && status["cookie"] == nil)
        let sent = await fixture.cookieHeaders()
        precondition(sent.allSatisfy { !$0.contains("evil") && $0.contains("token=fixture") })
        let requestCount = await fixture.count()
        try await api.setSession([cookie("userid", "123"), cookie("token", "fixture")])
        _ = try await api.handle(route("login/status"), method: "GET", body: Data())
        let unchangedCount = await fixture.count()
        precondition(unchangedCount == requestCount)
        let playlists = try await api.handle(route("user/playlists"), method: "GET", body: Data())
        precondition((playlists["playlists"] as? [[String: Any]])?.count == 1)
        let tracks = try await api.handle(route("playlist/tracks?id=55&offset=0&limit=1"), method: "GET", body: Data())
        precondition((tracks["tracks"] as? [[String: Any]])?.first?["duration"] as? Double == 120000)
        precondition((tracks["tracks"] as? [[String: Any]])?.first?["name"] as? String == "Track3")
        let playback = try await api.handle(route("song/url?id=" + String(repeating: "a", count: 32)), method: "GET", body: Data())
        precondition(playback["trial"] as? Bool == true)
        let lyrics = try await api.handle(route("lyric?hash=" + String(repeating: "a", count: 32)), method: "GET", body: Data())
        precondition(lyrics["lyric"] as? String == "[00:00.00]Fixture")
        await fixture.deny()
        try await api.setSession([cookie("userid", "123"), cookie("token", "expired")])
        let rejected = try await api.handle(route("login/status"), method: "GET", body: Data())
        precondition(rejected["loggedIn"] as? Bool == false)
        _ = try await api.handle(route("logout"), method: "GET", body: Data())
        print("Kugou: H5 signature, session verification, playlists/tracks, trial retention, lyric decoding and URL boundaries passed")
    }
}
