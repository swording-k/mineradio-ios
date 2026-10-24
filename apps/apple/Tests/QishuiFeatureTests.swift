import Foundation

private actor FeatureFixture: QishuiCatalogRequesting {
    var writes: [String] = []
    var libraryReads = 0
    var denied = false
    var malformed = false
    func deny() { denied = true }
    func malformedResponse() { malformed = true; denied = false }
    func counts() -> (Int, Int) { (libraryReads, writes.count) }
    func request(_ url: URL, headers: [String: String]) throws -> [String: Any] {
        precondition(QishuiCatalogContract.allowedAPI(url))
        precondition(headers["Cookie"] == "sessionid=fixture")
        switch url.path {
        case "/luna/pc/me": return ["status_code": 0, "data": ["my_info": ["user_id": "42", "nickname": "Fixture"]]]
        case "/luna/pc/user/playlist": libraryReads += 1; return ["status_code": 0, "data": ["playlists": [["playlist_id": "9", "title": "我喜欢", "count_tracks": 1]]]]
        case "/luna/pc/me/collection/mixed": return ["status_code": 0, "data": ["items": [["id": "101", "name": "Track"]]]]
        case "/luna/pc/playlist/detail": return ["status_code": 0, "data": ["tracks": [["id": "101", "name": "Track"]], "has_more": false]]
        case "/luna/pc/comments":
            let q = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
            precondition(q.first { $0.name == "group_id" }?.value == "101")
            precondition(q.first { $0.name == "cursor" }?.value == "next")
            return ["status_code": 0, "data": ["comments": [["id": "c1", "text": "Fixture", "create_time": 1700000000, "like_count": 3, "user": ["id": "7", "nickname": "Reader"]]], "total": 8, "next_cursor": "next2", "has_more": true]]
        default: return ["status_code": 0, "data": ["items": []]]
        }
    }
    func post(_ url: URL, headers: [String: String], body: Data) throws -> [String: Any] {
        writes.append(url.path)
        precondition(QishuiCatalogContract.allowedAPI(url))
        precondition(headers["Cookie"] == "sessionid=fixture" && headers["Content-Type"] == "application/json" && headers["Referer"] == "https://www.qishui.com/")
        let payload = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        if url.path.contains("collection/media") { precondition((payload["media"] as? [[String: Any]])?.first?["id"] as? String == "101") }
        else if url.path.contains("collection/playlist") { precondition(payload["playlist_ids"] as? [String] == ["9"]) }
        else if url.path.contains("collection/album") { precondition(payload["album_ids"] as? [String] == ["8"]) }
        else if url.path.contains("playlist/media/append") { precondition(payload["playlist_id"] as? String == "9") }
        else if url.path.contains("comments/create") { precondition(payload["group_id"] as? String == "101" && payload["text"] as? String == "Hello") }
        else { preconditionFailure("Unexpected mutation") }
        if denied { return ["status_code": 401] }
        if malformed { return [:] }
        return ["status_code": 0, "data": ["id": "c2", "text": "Hello"]]
    }
}

@main struct QishuiFeatureTests {
    static func main() async throws {
        let fixture = FeatureFixture(), api = QishuiCatalogAPI(transport: fixture)
        func run(_ path: String, _ method: String = "GET", _ body: [String: Any] = [:]) async throws -> [String: Any] {
            try await api.handle(URL(string: "http://127.0.0.1/api/qishui/" + path)!, method: method, body: try JSONSerialization.data(withJSONObject: body))
        }
        let guest = try await run("song/like", "POST", ["song": ["id": "101"], "like": true])
        precondition(guest["error"] as? String == "QISHUI_COOKIE_REQUIRED", "Missing native collection route")
        let guestCounts = await fixture.counts(); precondition(guestCounts == (0, 0))
        await api.setSession(["sessionid": "fixture", "unrelated": "never-forward"])
        let likes = try await run("song/like/check?ids=101,102")
        precondition((likes["liked"] as? [String: Bool])?["101"] == true)
        precondition((likes["liked"] as? [String: Bool])?["102"] == false && likes["complete"] as? Bool == true)
        for flag in [true, false] {
            let liked = try await run("song/like", "POST", ["song": ["providerSongId": "101"], "like": flag])
            precondition(liked["success"] as? Bool == true && liked["liked"] as? Bool == flag)
            let playlist = try await run("playlist/collect", "POST", ["id": "qishui:9", "collected": flag])
            precondition(playlist["collected"] as? Bool == flag)
            let album = try await run("album/collect", "POST", ["id": "8", "collected": flag])
            precondition(album["collected"] as? Bool == flag)
        }
        let appended = try await run("playlist/add-song", "POST", ["pid": "9", "song": ["id": "101"]])
        precondition(appended["success"] as? Bool == true)
        _ = try await run("song/like/check?ids=101")
        let refetched = await fixture.counts(); precondition(refetched.0 == 2, "Writes must invalidate the library")
        let comments = try await run("song/comments?id=101&cursor=next&limit=2")
        let comment = (comments["comments"] as? [[String: Any]])?.first
        precondition(comment?["content"] as? String == "Fixture" && comment?["time"] as? Double == 1700000000000)
        precondition(comments["nextCursor"] as? String == "next2" && comments["hasMore"] as? Bool == true)
        let created = try await run("song/comments?id=101", "POST", ["content": " Hello "])
        precondition(created["created"] as? Bool == true && (created["comment"] as? [String: Any])?["content"] as? String == "Hello")
        let before = await fixture.counts()
        for (path, method, payload) in [("song/like", "GET", ["song": ["id": "101"]]), ("playlist/add-song", "POST", ["pid": "../bad", "song": ["id": "101"]]), ("song/comments?id=101", "POST", ["content": " "]), ("song/like", "POST", ["song": ["id": "101"], "like": "false"])] {
            do { _ = try await run(path, method, payload); preconditionFailure("Invalid action accepted") } catch {}
        }
        let after = await fixture.counts(); precondition(before == after)
        await fixture.deny()
        do { _ = try await run("song/like", "POST", ["song": ["id": "101"]]); preconditionFailure("Denied mutation accepted") } catch {}
        await fixture.malformedResponse()
        do { _ = try await run("song/like", "POST", ["song": ["id": "101"]]); preconditionFailure("Empty response accepted") } catch {}
        do { try QishuiCatalogContract.check(["status_code": "401"]); preconditionFailure("String denial became success") } catch {}
        do { try QishuiCatalogContract.check(["status_code": "invalid"]); preconditionFailure("Malformed status became success") } catch {}
        _ = try await run("logout")
        print("Qishui features: liked state, collections, playlist add, paged comments/post, invalid writes, cache invalidation and provider denials passed")
    }
}
