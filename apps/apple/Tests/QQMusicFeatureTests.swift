import Foundation

private actor QQFeatureFixture: QQMusicRequesting {
    private var denied = false
    private var calls = 0
    func deny() { denied = true }
    func count() -> Int { calls }
    func request(_ request: URLRequest) throws -> QQMusicHTTPResponse {
        calls += 1
        let url = request.url!
        precondition(QQMusicContract.allowedAPI(url))
        let params = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        var json: [String: Any]
        if url.path.contains("album_info") {
            precondition(params["albummid"] == "album123")
            json = ["code": 0, "data": ["id": 5, "name": "Album", "singername": "Artist", "list": [["songmid": "track123", "songname": "Track", "interval": 180, "singer": [["mid": "artist123", "name": "Artist"]]]]]]
        } else if url.path.contains("global_comment") {
            precondition(params["topid"] == "7" && params["pagenum"] == "1" && params["pagesize"] == "2")
            json = ["code": 0, "comment": ["commenttotal": 9, "commentlist": [["commentid": "c7", "rootcommentcontent": "Fixture", "time": 1700000000, "nick": "Reader", "praisenum": 2]]]]
        } else {
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            if let block = body["singer"] as? [String: Any] {
                precondition(block["module"] as? String == "music.web_singer_info_svr")
                json = ["singer": ["code": 0, "data": ["singer_info": ["mid": "artist123", "name": "Artist"], "total_song": 1, "songlist": [["mid": "track123", "name": "Track", "interval": 180]]]]]
            } else {
                precondition(body["songinfo"] != nil)
                json = ["songinfo": ["code": 0, "data": ["track_info": ["id": 7, "mid": "track123"]]]]
            }
        }
        if denied { json = ["code": 1000, "message": "Fixture denied"] }
        return QQMusicHTTPResponse(data: try JSONSerialization.data(withJSONObject: json), status: 200, url: url)
    }
    func probe(_ url: URL, budget: TimeInterval) -> Bool { false }
}

@main struct QQMusicFeatureTests {
    static func main() async throws {
        let fixture = QQFeatureFixture()
        let tested = QQMusicNativeAPI(transport: fixture, keychainService: nil)
        func get(_ path: String) async throws -> [String: Any] { try await tested.handle(URL(string: "http://127.0.0.1" + path)!, method: "GET", body: Data()) }
        let album = try await get("/api/qq/album/detail?mid=album123")
        precondition((album["album"] as? [String: Any])?["name"] as? String == "Album", "Original QQ album entry needs its native route")
        let song = (album["songs"] as? [[String: Any]])?.first
        precondition(song?["albumMid"] as? String == "album123" && song?["duration"] as? Int == 180000)
        let artist = try await get("/api/qq/artist/detail?mid=artist123")
        precondition((artist["artist"] as? [String: Any])?["name"] as? String == "Artist")
        let comments = try await get("/api/qq/song/comments?mid=track123&limit=2&offset=2")
        let comment = (comments["comments"] as? [[String: Any]])?.first
        precondition(comment?["content"] as? String == "Fixture" && comment?["time"] as? Int64 == 1700000000000)
        precondition(comments["nextOffset"] as? Int == 3 && comments["hasMore"] as? Bool == true)
        let before = await fixture.count()
        do { _ = try await get("/api/qq/album/detail?mid=../bad"); preconditionFailure("Invalid mid accepted") } catch {}
        let method = try await tested.handle(URL(string: "http://127.0.0.1/api/qq/album/detail?mid=album123")!, method: "POST", body: Data())
        precondition(method["error"] as? String == "METHOD_NOT_ALLOWED")
        let after = await fixture.count(); precondition(before == after)
        await fixture.deny()
        do { _ = try await get("/api/qq/artist/detail?mid=artist123"); preconditionFailure("Denied response treated as success") } catch {}
        precondition(!QQMusicContract.allowedAPI(URL(string: "https://c.y.qq.com/base/private.fcg")!))
        print("QQ feature routes: album, artist, comment mid lookup/paging, invalid/method/denial boundaries passed")
    }
}
