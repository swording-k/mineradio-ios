import Foundation

private actor SpotifyFixture: SpotifyRequesting {
    var calls: [URLRequest] = []
    var expired = false
    var rateLimited = false
    var holdRefresh = false
    var heldRefresh: CheckedContinuation<Void, Never>?
    func pauseRefresh() { holdRefresh = true }
    func refreshWaiting() -> Bool { heldRefresh != nil }
    func releaseRefresh() { let held = heldRefresh; heldRefresh = nil; held?.resume() }
    func setExpired() { expired = true }
    func setRateLimited() { rateLimited = true }
    func requests() -> [URLRequest] { calls }
    func request(_ request: URLRequest) async throws -> SpotifyHTTPResponse {
        calls.append(request)
        let url = request.url!, path = url.path
        if rateLimited { return .init(data: Data(), status: 429, retryAfter: 25) }
        if path == "/api/token" {
            let body = String(decoding: request.httpBody!, as: UTF8.self)
            precondition(!body.contains("client_secret"))
            precondition(body.contains("client_id="))
            if body.contains("grant_type=authorization_code") { precondition(body.contains("code_verifier=")) }
            if holdRefresh && body.contains("grant_type=refresh_token") { await withCheckedContinuation { heldRefresh = $0 } }
            let json = "{\"access_token\":\"fixture-access\",\"refresh_token\":\"fixture-refresh\",\"expires_in\":3600}"
            return .init(data: Data(json.utf8), status: 200)
        }
        if expired { expired = false; return .init(data: Data(), status: 401) }
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-access")
        let json: String
        switch path {
        case "/v1/me": json = "{\"id\":\"reader\",\"display_name\":\"Fixture Reader\",\"images\":[]}"
        case "/v1/me/playlists": json = "{\"items\":[{\"id\":\"List1\",\"name\":\"Fixture list\",\"owner\":{\"id\":\"reader\"},\"items\":{\"total\":2}}],\"total\":2,\"next\":\"https://api.spotify.com/v1/me/playlists?offset=1\"}"
        case "/v1/playlists/List1/items":
            json = "{\"items\":[{\"item\":{\"id\":\"Track1\",\"name\":\"Song\",\"duration_ms\":180000,\"artists\":[{\"id\":\"Artist1\",\"name\":\"Artist\"}],\"album\":{\"id\":\"Album1\",\"name\":\"Album\",\"images\":[]}}},{\"item\":null}],\"total\":2,\"next\":null}"
        case "/v1/search": json = "{\"tracks\":{\"items\":[{\"id\":\"Track1\",\"name\":\"Song\",\"artists\":[]}],\"total\":1,\"next\":null}}"
        case "/v1/me/library/contains": json = "[true,false]"
        case "/v1/me/library": json = "{}"
        default: preconditionFailure("Unexpected Spotify request \(request.httpMethod ?? "") \(path)")
        }
        return .init(data: Data(json.utf8), status: 200)
    }
}
@main struct SpotifyNativeTests {
    static func main() async throws {
        // RFC 7636 example: actual SHA256 PKCE, not a fixed challenge.
        precondition(SpotifyContract.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let empty = SpotifyNativeAPI(clientID: "", transport: SpotifyFixture(), keychainService: nil)
        let absent = try await empty.handle(URL(string: "http://127.0.0.1/api/spotify/status")!, method: "GET", body: Data())
        precondition(absent["oauthConfigured"] as? Bool == false && absent["loggedIn"] as? Bool == false)
        do { _ = try await empty.beginAuthorization(); preconditionFailure("Unconfigured app started login") } catch {}
        let fixture = SpotifyFixture()
        let api = SpotifyNativeAPI(clientID: String(repeating: "a", count: 32), transport: fixture, keychainService: nil)
        let auth = try await api.beginAuthorization()
        let q = URLComponents(url: auth, resolvingAgainstBaseURL: false)!.queryItems!
        let state = q.first { $0.name == "state" }!.value!
        precondition(q.first {$0.name == "code_challenge_method"}?.value == "S256")
        precondition(q.first {$0.name == "redirect_uri"}?.value == SpotifyContract.redirectURI)
        do { _ = try await api.finishAuthorization(URL(string: SpotifyContract.redirectURI + "?code=fixture&state=wrong")!); preconditionFailure("State mismatch accepted") } catch {}
        // A rejected/cancelled attempt cannot be reused. Start a new session.
        let second = try await api.beginAuthorization()
        let secondState = URLComponents(url: second, resolvingAgainstBaseURL: false)!.queryItems!.first {$0.name == "state"}!.value!
        precondition(state != secondState)
        let status = try await api.finishAuthorization(URL(string: SpotifyContract.redirectURI + "?code=fixture&state=" + secondState)!)
        precondition(status["loggedIn"] as? Bool == true && status["nickname"] as? String == "Fixture Reader")
        precondition(status["membershipKnown"] as? Bool == false, "Absent product does not prove Free membership")
        precondition(status["access_token"] == nil && status["refresh_token"] == nil)
        func get(_ path: String, method: String = "GET", body: String = "") async throws -> [String: Any] {
            try await api.handle(URL(string: "http://127.0.0.1/api/spotify/" + path)!, method: method, body: Data(body.utf8))
        }
        let lists = try await get("user/playlists?limit=20&offset=0")
        precondition((lists["playlists"] as? [[String: Any]])?.first(where: {$0["id"] as? String == "List1"})?["canAddSongs"] as? Bool == true)
        precondition(lists["hasMore"] as? Bool == true && lists["nextOffset"] as? Int == 1)
        let songs = try await get("playlist/tracks?id=List1&limit=20&offset=0")
        precondition((songs["songs"] as? [[String: Any]])?.first?["provider"] as? String == "spotify")
        precondition((songs["tracks"] as? [[String: Any]])?.first?["id"] as? String == "Track1", "Original shelf and collection verification consume tracks")
        precondition(songs["nextOffset"] as? Int == 2, "Removed/null items still consume paging offsets")
        let media = try await get("song/url?id=Track1")
        precondition(media["url"] as? String == "" && media["playable"] as? Bool == false)
        await fixture.setExpired()
        let search = try await get("search?keywords=Song&limit=100")
        precondition((search["songs"] as? [Any])?.count == 1)
        let liked = try await get("song/like/check?ids=Track1,Track2")
        precondition((liked["likedMap"] as? [String: Bool])?["Track1"] == true)
        let saved = try await get("song/like", method: "POST", body: "{\"id\":\"Track1\",\"like\":true}")
        precondition(saved["ok"] as? Bool == true)
        let added = try await get("playlist/add-song", method: "POST", body: "{\"pid\":\"List1\",\"song\":{\"spotifyId\":\"Track1\"}}")
        precondition(added["success"] as? Bool == true)
        let collected = try await get("playlist/collect", method: "POST", body: "{\"playlistId\":\"List1\",\"collected\":true}")
        precondition(collected["success"] as? Bool == true)
        let calls = await fixture.requests()
        precondition(calls.contains {$0.url?.path == "/v1/playlists/List1/items"})
        precondition(!calls.contains {$0.url?.path == "/v1/playlists/List1/tracks"})
        let write = calls.first {$0.url?.path == "/v1/me/library"}!
        precondition(write.httpMethod == "PUT", "Method and path must not be reversed")
        let countBefore = calls.count
        _ = try await get("search?keywords=x", method: "POST")
        let invalid = try await get("playlist/tracks?id=../private")
        precondition(invalid["error"] as? String == "SPOTIFY_INVALID_ID")
        let countAfter = await fixture.requests().count; precondition(countBefore == countAfter)
        await fixture.setRateLimited()
        let limited = try await get("search?keywords=x")
        precondition(limited["error"] as? String == "SPOTIFY_RATE_LIMITED" && limited["retryAfter"] as? Int == 25)
        let rateCalls = await fixture.requests().count
        _ = try await get("search?keywords=y")
        let noExtraCall = await fixture.requests().count; precondition(rateCalls == noExtraCall)
        _ = try await get("logout", method: "POST")
        let loggedOut = try await get("status"); precondition(loggedOut["loggedIn"] as? Bool == false)
        let raceTransport = SpotifyFixture()
        // Use a separate isolated account store to exercise refresh/logout overlap.
        let raceAPI = SpotifyNativeAPI(clientID: String(repeating: "c", count: 32), transport: raceTransport, keychainService: nil)
        let raceURL = try await raceAPI.beginAuthorization()
        let raceState = URLComponents(url: raceURL, resolvingAgainstBaseURL: false)!.queryItems!.first {$0.name == "state"}!.value!
        let callback = URL(string: SpotifyContract.redirectURI + "?code=fixture&state=" + raceState)!
        _ = try await raceAPI.finishAuthorization(callback)
        do { _ = try await raceAPI.finishAuthorization(callback); preconditionFailure("Callback replay accepted") } catch {}
        await raceTransport.pauseRefresh(); await raceTransport.setExpired()
        let inflight = Task { try await raceAPI.handle(URL(string: "http://127.0.0.1/api/spotify/search?keywords=old")!, method: "GET", body: Data()) }
        for _ in 0..<100 { if await raceTransport.refreshWaiting() { break }; try await Task.sleep(nanoseconds: 5_000_000) }
        let waiting = await raceTransport.refreshWaiting(); precondition(waiting)
        _ = try await raceAPI.handle(URL(string: "http://127.0.0.1/api/spotify/logout")!, method: "POST", body: Data())
        await raceTransport.releaseRefresh()
        _ = try? await inflight.value
        let afterLogout = try await raceAPI.handle(URL(string: "http://127.0.0.1/api/spotify/status")!, method: "GET", body: Data())
        precondition(afterLogout["loggedIn"] as? Bool == false, "Late token refresh must not restore a logged-out account")
        print("Spotify: PKCE, state/replay, configuration gate, metadata/paging, refresh, library writes, no direct audio, rate-limit and logout boundaries passed")
    }
}
