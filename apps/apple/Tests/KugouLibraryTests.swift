import Foundation

private actor LibraryFixture: KugouRequesting {
    var mutations: [URLRequest] = []
    var reads = 0
    var denied = false
    var oversized = false
    let hash = String(repeating: "a", count: 32)
    func deny() { denied = true }
    func large() { oversized = true }
    func counts() -> (Int, Int) { (reads, mutations.count) }
    func request(_ request: URLRequest) throws -> [String: Any] {
        let url = request.url!
        precondition(KugouContract.allowedAPI(url))
        let payload = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
        switch url.path {
        case "/v7/get_all_list":
            return ["status": 1, "data": ["info": [["listid": 55, "name": "我喜欢", "list_create_userid": 123]]]]
        case "/v4/get_list_all_file":
            reads += 1
            if oversized { return ["status": 1, "data": ["count": 900, "info": Array(repeating: ["hash": String(repeating: "b", count: 32), "fileid": 99], count: 50)]] }
            return ["status": 1, "data": ["count": 1, "info": [["hash": hash, "fileid": 77, "name": "Fixture", "duration": 120]]]]
        case "/v1/app_song_list_offset":
            precondition(request.httpMethod == "POST" && request.value(forHTTPHeaderField: "x-router") == "fm.service.kugou.com")
            precondition(payload["appid"] as? Int == 1005 && payload["clientver"] as? Int == 20489)
            precondition((payload["data"] as? [[String: Any]])?.first?["size"] as? Int == 4)
            var params = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
            let signature = params.removeValue(forKey: "signature"), salt = "OIlwieks28dk2k092lksi2UIkp"
            let signed = salt + params.keys.sorted().map { "\($0)=\(params[$0]!)" }.joined() + String(decoding: request.httpBody!, as: UTF8.self) + salt
            precondition(signature == KugouContract.md5(signed))
            return denied ? ["status": 0, "error_code": 20010] : ["status": 1, "data": ["song_list": [["hash": hash, "name": "Recommended", "duration": 180, "singerinfo": [["name": "Artist"]]]]]]
        case "/v6/add_song", "/v4/delete_songs":
            mutations.append(request)
            precondition(request.httpMethod == "POST" && payload["userid"] as? Int == 123 && payload["listid"] as? Int == 55)
            precondition(request.value(forHTTPHeaderField: "x-router") == "cloudlist.service.kugou.com")
            var params = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
            let signature = params.removeValue(forKey: "signature")
            precondition(signature == KugouContract.signature(params, body: String(decoding: request.httpBody!, as: UTF8.self)))
            let song = (payload["data"] as! [[String: Any]])[0]
            if url.path == "/v6/add_song" {
                precondition(params["last_area"] == "gztx" && params["last_time"] != nil)
                precondition(song["hash"] as? String == hash && song["timelen"] as? Int == 120000 && song["mixsongid"] as? Int == 42)
            } else { precondition(song["fileid"] as? Int == 77, "Removal must use verified remote file ID") }
            return denied ? ["status": 0, "error_code": 20010] : ["status": 1, "data": [:]]
        default: return [:]
        }
    }
}

@main struct KugouLibraryTests {
    static func main() async throws {
        let fixture = LibraryFixture(), api = KugouNativeAPI(transport: fixture, keychainService: "mineradio.kugou.library-test.\(UUID())")
        let hash = String(repeating: "a", count: 32)
        func run(_ path: String, _ method: String = "GET", _ body: [String: Any] = [:]) async throws -> [String: Any] {
            try await api.handle(URL(string: "http://127.0.0.1/api/kugou/" + path)!, method: method, body: try JSONSerialization.data(withJSONObject: body))
        }
        let song: [String: Any] = ["hash": hash, "name": "Fixture", "duration": 120000, "albumAudioId": "42", "fileId": "999"]
        let guest = try await run("song/like", "POST", ["song": song, "like": true])
        precondition(guest["error"] as? String == "KUGOU_AUTH_REQUIRED", "Missing native heart route")
        let guestCounts = await fixture.counts(); precondition(guestCounts == (0, 0))
        func cookie(_ name: String, _ value: String) -> HTTPCookie { HTTPCookie(properties: [.domain: ".kugou.com", .path: "/", .name: name, .value: value])! }
        try await api.setSession([cookie("userid", "123"), cookie("token", "fixture")])
        let recommended = try await run("recommendations?limit=4")
        precondition((recommended["songs"] as? [[String: Any]])?.first?["name"] as? String == "Recommended", "Missing FM recommendation route")
        let checked = try await run("song/like/check?hashes=" + hash.uppercased())
        precondition((checked["liked"] as? [String: Bool])?[hash] == true && checked["listId"] as? String == "55")
        let liked = try await run("song/like", "POST", ["song": song, "like": true])
        precondition(liked["success"] as? Bool == true && liked["liked"] as? Bool == true)
        let added = try await run("playlist/add-song", "POST", ["pid": "55", "song": song])
        precondition(added["success"] as? Bool == true)
        let removed = try await run("song/like", "POST", ["song": song, "like": false])
        precondition(removed["success"] as? Bool == true && removed["liked"] as? Bool == false)
        let before = await fixture.counts()
        for (path, method, body) in [("song/like", "GET", ["song": song]), ("playlist/add-song", "POST", ["pid": "../55", "song": song]), ("song/like", "POST", ["song": ["hash": "invalid"]]), ("song/like", "POST", ["song": song, "like": "false"])] {
            do { _ = try await run(path, method, body); preconditionFailure("Invalid write accepted") } catch {}
        }
        let after = await fixture.counts(); precondition(before == after)
        await fixture.deny()
        do { _ = try await run("song/like", "POST", ["song": song, "like": true]); preconditionFailure("Provider denial became success") } catch {}
        do { _ = try await run("recommendations?limit=4"); preconditionFailure("Denied FM became empty success") } catch {}
        await fixture.large()
        let partial = try await run("song/like/check?hashes=" + hash)
        precondition(partial["error"] as? String == "KUGOU_LIKE_SCAN_LIMIT" && partial["partial"] as? Bool == true)
        let final = await fixture.counts(); precondition(final.0 - after.0 <= 13, "Favorite scan must be bounded")
        _ = try await run("logout")
        try await api.setSession([cookie("userid", String(repeating: "9", count: 40)), cookie("token", "fixture")])
        let invalidAccount = try await run("login/status")
        precondition(invalidAccount["loggedIn"] as? Bool == false, "Unrepresentable user IDs must not enter numeric payloads")
        _ = try await run("logout")
        print("Kugou library: heart check/add/remove, playlist add, signed payloads, denial, invalid writes and bounded scans passed")
    }
}
