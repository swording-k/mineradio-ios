import Foundation

private actor CatalogFixture: QishuiCatalogRequesting {
    var invalid = false
    var sessions = 0
    func invalidate() { invalid = true }
    func request(_ url: URL, headers: [String: String]) async throws -> [String: Any] {
        if url.path == "/luna/pc/me" {
            sessions += 1
            if invalid { return ["status_code": 1000016] }
            return ["status_code": 0, "data": ["my_info": ["user_id": "42", "nickname": "Fixture"], "vip_info": ["is_vip": true, "vip_expire_time": 4102444800]]]
        }
        if url.path == "/luna/pc/user/playlist" {
            return ["data": ["playlists": [["playlist_id": "9", "title": "收藏歌单", "count_tracks": 2]]]]
        }
        if url.path == "/luna/pc/me/collection/mixed" || url.path == "/luna/pc/me/recently-played-media" { return ["data": ["items": []]] }
        if url.path == "/luna/pc/playlist/detail" {
            let cursor = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "cursor" }?.value ?? ""
            let id = cursor.isEmpty ? "101" : "102"
            return ["data": ["playlist": ["playlist_id": "9", "title": "收藏歌单", "count_tracks": 2], "tracks": [["id": id, "name": "Track " + id, "duration_ms": 180000]], "next_cursor": cursor.isEmpty ? "next" : "", "has_more": cursor.isEmpty]]
        }
        if url.path == "/luna/pc/search/track" { return ["data": ["result_groups": [["data": [["track_wrapper": ["track": ["base_info": ["id": "101", "name": "Song", "duration_ms": 180000]]]]]]], "has_more": false]] }
        if url.path == "/luna/pc/track_v2" { return ["status_code": 0, "data": ["track": ["id": "101", "duration_ms": 180000, "audio_info": ["play_info_list": [["url": "https://music.douyincdn.com/free.m4a", "duration": 180]]]]]] }
        return ["data": [:]]
    }
}
@main struct QishuiCatalogTests {
    static func main() async throws {
        let fixture = CatalogFixture()
        let api = QishuiCatalogAPI(transport: fixture)
        let anonymous = await api.validateAccount()
        precondition(anonymous["loggedIn"] as? Bool == false)
        await api.setSession(["sessionid": "fixture", "unrelated": "never-forward"])
        let status = await api.validateAccount()
        precondition(status["loggedIn"] as? Bool == true && status["userId"] as? String == "42")
        precondition(status["membershipKnown"] as? Bool == true && status["isVip"] as? Bool == true)
        precondition(status["cookie"] == nil)
        let playlists = try await api.handle(URL(string: "http://127.0.0.1/api/qishui/user/playlists")!, method: "GET", body: Data())
        precondition((playlists["playlists"] as? [[String: Any]])?.contains { $0["id"] as? String == "9" } == true)
        let first = try await api.handle(URL(string: "http://127.0.0.1/api/qishui/playlist/tracks?id=9&limit=1")!, method: "GET", body: Data())
        precondition((first["tracks"] as? [[String: Any]])?.first?["id"] as? String == "101")
        let second = try await api.handle(URL(string: "http://127.0.0.1/api/qishui/playlist/tracks?id=9&limit=1&offset=1")!, method: "GET", body: Data())
        precondition((second["tracks"] as? [[String: Any]])?.first?["id"] as? String == "102")
        let searched = try await api.handle(URL(string: "http://127.0.0.1/api/qishui/search?keywords=Song")!, method: "GET", body: Data())
        precondition((searched["songs"] as? [[String: Any]])?.first?["duration"] as? Double == 180)
        let playback = try await api.handle(URL(string: "http://127.0.0.1/api/qishui/song/url?id=101")!, method: "GET", body: Data())
        precondition(playback["playable"] as? Bool == true && playback["trial"] as? Bool == false)
        precondition(!QishuiCatalogContract.allowedAPI(URL(string: "https://api.qishui.com.evil.test/luna/pc/me")!))
        precondition(!QishuiCatalogContract.allowedAPI(URL(string: "https://api.qishui.com/private")!))
        precondition(!QishuiCatalogContract.allowedMedia(URL(string: "https://127.0.0.1/audio.m4a")!))
        precondition(QishuiCatalogContract.playback(["data": ["track": ["id": "1", "duration_ms": 180000, "label_info": ["only_vip_playable": true], "audio_info": ["play_info_list": [["url": "https://music.douyincdn.com/private.m4a", "duration": 180]]]]]], membership: [:], publicSource: false)["playable"] as? Bool == false)
        let svipOnly: [String: Any] = ["data": ["track": ["id": "1", "duration_ms": 180000, "audio_info": ["play_info_list": [["url": "https://music.douyincdn.com/hires.flac", "duration": 180, "quality": "hires"]]]]]]
        precondition(QishuiCatalogContract.playback(svipOnly, membership: ["membershipKnown": true, "isVip": true, "isSvip": false], publicSource: false)["playable"] as? Bool == false)
        let audition: [String: Any] = ["data": ["track": ["id": "1", "duration_ms": 180000, "audition_info": ["duration_ms": 30000], "label_info": ["only_vip_playable": true], "audio_info": ["play_info_list": [["url": "https://music.douyincdn.com/preview.m4a", "duration": 30, "bitrate": 128000]]]]]]
        precondition(QishuiCatalogContract.playback(audition, membership: [:], publicSource: true)["trial"] as? Bool == true)
        let encrypted: [String: Any] = ["data": ["track": ["id": "1", "duration_ms": 180000, "play_auth": "encrypted-fixture", "url": "https://music.douyincdn.com/full.m4a", "duration": 180]]]
        precondition(QishuiCatalogContract.playback(encrypted, membership: [:], publicSource: false)["playable"] as? Bool == false)
        let timedLyrics = QishuiCatalogContract.lyrics(["data": ["track": ["lyric_info": ["lyric_entity": ["content": "[1000,800]<0,300,0>Hello <300,500,0>world"]]]]])
        precondition(timedLyrics["lyric"] as? String == "[00:01.00]Hello world")
        precondition(timedLyrics["yrc"] as? String == "[1000,800](1000,300,0)Hello (1300,500,0)world")
        precondition(QishuiCatalogContract.playback(audition, membership: [:], publicSource: true, expectedID: "wrong-id")["playable"] as? Bool == false)
        await api.setSession(["sessionid": "replacement"]); await fixture.invalidate()
        let expired = await api.validateAccount()
        precondition(expired["loggedIn"] as? Bool == false && expired["reauthRequired"] as? Bool == true)
        print("Qishui catalogue: verified identity, expiry, no cookie disclosure, playlists/cursors/search, playback rights and URL boundaries passed")
    }
}
