import Foundation

private actor FeatureFixture: NeteaseRequesting {
    var loggedIn = true
    var mutationCount = 0
    func clear() { loggedIn = false }
    func mutations() -> Int { mutationCount }
    func call(_ path: String, _ fields: [String: Any]) throws -> [String: Any] {
        switch path {
        case "/api/w/nuser/account/get": return loggedIn ? ["profile": ["userId": 123, "nickname": "Fixture"]] : ["code": 200]
        case "/api/song/like/get": return ["code": 200, "ids": [7, 9]]
        case "/api/radio/like":
            mutationCount += 1
            precondition(fields["trackId"] as? String == "7" && fields["like"] as? Bool == false)
            return ["code": 200]
        case "/api/playlist/create":
            mutationCount += 1
            precondition(fields["name"] as? String == "Test list")
            return ["code": 200, "playlist": ["id": 42, "name": "Test list"]]
        case "/api/playlist/manipulate/tracks":
            mutationCount += 1
            precondition(fields["pid"] as? String == "42")
            precondition(fields["trackIds"] as? String == "[\"7\",\"8\"]")
            return ["code": 403, "message": "Fixture denied"]
        case "/api/playlist/subscribe": mutationCount += 1; return ["code": 200]
        case "/api/album/sub": mutationCount += 1; return ["code": 200]
        case "/api/album/sublist": return ["code": 200, "data": [["id": 4]], "hasMore": false]
        case "/api/v1/album/4": return ["code": 200, "album": ["id": 4, "name": "Album", "size": 1, "artists": [["id": 3, "name": "Artist"]]], "songs": [["id": 7, "name": "Track", "dt": 180000]]]
        case "/api/artist/head/info/get": return ["code": 200, "data": ["artist": ["id": 3, "name": "Artist", "cover": "https://p1.music.126.net/artist.jpg"]]]
        case "/api/v1/artist/songs": return ["code": 200, "songs": [["id": 7, "name": "Track"]]]
        case "/api/v1/resource/comments/R_SO_4_7": return ["code": 200, "total": 2, "hotComments": [["commentId": 9, "content": "Hot", "user": ["userId": 3, "nickname": "A"]]], "comments": [["commentId": 10, "content": "New"]]]
        case "/api/resource/comments/add":
            mutationCount += 1
            precondition(fields["threadId"] as? String == "R_SO_4_7" && fields["content"] as? String == "Hello")
            return ["code": 403, "message": "Denied"]
        case "/api/v1/comment/like": mutationCount += 1; return ["code": 200]
        case "/api/djradio/hot/v1", "/api/djradio/get/subed", "/api/djradio/get/byuser":
            return ["code": 200, "djRadios": [["id": 5, "name": "Radio", "dj": ["nickname": "Host"]]], "hasMore": true]
        case "/api/djradio/v2/get": return ["code": 200, "data": ["id": 5, "name": "Radio"]]
        case "/api/dj/program/byradio":
            precondition(fields["offset"] as? Int == 2)
            return ["code": 200, "count": 4, "more": true, "programs": [["id": 88, "name": "Episode", "mainSong": ["id": 7, "dt": 180000], "radio": ["id": 5, "name": "Radio"]]]]
        case "/api/cloudsearch/pc":
            precondition(fields["type"] as? Int == 1009)
            return ["code": 200, "result": ["djRadios": [["id": 5, "name": "Radio"]], "djRadiosCount": 1]]
        case "/api/voice/sati/resource/sub/list": return ["code": 200, "data": [["id": 88, "trackId": 7, "name": "Voice"]]]
        default: preconditionFailure("Unexpected native upstream path: \(path)")
        }
    }
}

@main struct NeteaseFeatureRoutesTests {
    static func main() async throws {
        let fixture = FeatureFixture(), api = NeteaseNativeAPI(transport: FeatureFixture())
        let tested = NeteaseNativeAPI(transport: fixture)
        func request(_ path: String, _ body: [String: Any]? = nil) async throws -> [String: Any] {
            try await tested.handle(URL(string: "http://127.0.0.1:19363" + path)!, method: body == nil ? "GET" : "POST",
                                    body: body.map { try! JSONSerialization.data(withJSONObject: $0) } ?? Data())
        }
        let read = try await request("/api/song/like/check?ids=7,8")
        precondition((read["liked"] as? [String: Bool]) == ["7": true, "8": false], "Original heart control needs the liked-state API")
        let unliked = try await request("/api/song/like", ["id": "7", "like": false])
        precondition(unliked["liked"] as? Bool == false && unliked["success"] as? Bool == true)
        let created = try await request("/api/playlist/create", ["name": "Test list", "privacy": "10"])
        precondition((created["playlist"] as? [String: Any])?["id"] as? Int == 42)
        let denied = try await request("/api/playlist/add-song", ["pid": "42", "ids": "7,8"])
        precondition(denied["success"] as? Bool == false && denied["error"] as? String == "NETEASE_REQUEST_FAILED")
        let subscribe = try await request("/api/playlist/subscribe", ["id": "42", "subscribed": true])
        precondition(subscribe["success"] as? Bool == true)
        let album = try await request("/api/album/detail?id=4")
        precondition((album["songs"] as? [[String: Any]])?.first?["id"] as? Int == 7)
        precondition((album["album"] as? [String: Any])?["artist"] as? String == "Artist")
        let collected = try await request("/api/album/subscribe", ["id": "4", "subscribed": true])
        precondition(collected["success"] as? Bool == true)
        let albums = try await request("/api/album/subscribe/check?ids=4,6")
        precondition(albums["subscribed"] as? [String: Bool] == ["4": true, "6": false])
        let artist = try await request("/api/artist/detail?id=3")
        precondition((artist["artist"] as? [String: Any])?["name"] as? String == "Artist")
        let comments = try await request("/api/song/comments?id=7")
        precondition((comments["comments"] as? [[String: Any]])?.first?["content"] as? String == "Hot")
        let posted = try await request("/api/song/comments", ["id": "7", "content": "Hello"])
        precondition(posted["created"] as? Bool == false, "Upstream denial must never appear as a successful comment")
        let commentLike = try await request("/api/song/comments/like", ["id": "7", "commentId": "9", "liked": true])
        precondition(commentLike["success"] as? Bool == true)
        for path in ["/api/podcast/hot", "/api/podcast/search?keywords=Radio"] {
            let response = try await request(path)
            precondition((response["podcasts"] as? [[String: Any]])?.first?["id"] as? Int == 5)
        }
        let programs = try await request("/api/podcast/programs?id=5&offset=2&limit=1")
        let program = (programs["programs"] as? [[String: Any]])?.first
        precondition(program?["id"] as? Int == 7 && program?["programId"] as? Int == 88, "Playback uses mainSong.id, not the episode ID")
        precondition(programs["nextOffset"] as? Int == 3 && programs["more"] as? Bool == true)
        let radio = try await request("/api/podcast/detail?id=5")
        precondition((radio["podcast"] as? [String: Any])?["name"] as? String == "Radio")
        let own = try await request("/api/podcast/my")
        precondition((own["collections"] as? [[String: Any]])?.count == 3)
        let voices = try await request("/api/podcast/my/items?key=liked")
        precondition((voices["items"] as? [[String: Any]])?.first?["id"] as? Int == 7)
        let before = await fixture.mutations()
        let invalid = try await request("/api/song/like", ["id": "../bad", "like": false])
        precondition(invalid["success"] as? Bool == false)
        let attemptedGet = try await request("/api/playlist/create?name=Oops")
        precondition(attemptedGet["error"] as? String == "METHOD_NOT_ALLOWED")
        _ = try await request("/api/logout")
        let anonymous = try await request("/api/song/like", ["id": "7", "like": false])
        precondition(anonymous["loggedIn"] as? Bool == false && anonymous["success"] as? Bool == false)
        let after = await fixture.mutations()
        precondition(before == after, "Invalid/GET/anonymous writes must not reach the platform")
        _ = api // independently constructed adapter must not affect the injected session
        print("NetEase feature parity: hearts, playlists, albums, artist, comments, podcasts, denial and write guards passed")
    }
}
