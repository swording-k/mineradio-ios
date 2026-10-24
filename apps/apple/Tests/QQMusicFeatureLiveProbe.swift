import Foundation

// Opt-in anonymous read-only validation; never loads account Keychain entries.
@main struct QQMusicFeatureLiveProbe {
    static func main() async throws {
        let api = QQMusicNativeAPI(keychainService: nil)
        func read(_ path: String) async throws -> [String: Any] { try await api.handle(URL(string: "http://127.0.0.1" + path)!, method: "GET", body: Data()) }
        let search = try await read("/api/qq/search?keywords=Beethoven&limit=2")
        guard let song = (search["songs"] as? [[String: Any]])?.first else { throw URLError(.cannotParseResponse) }
        let albumMid = QQMusicContract.text(song["albumMid"])
        let artistMid = QQMusicContract.text((song["artists"] as? [[String: Any]])?.first?["mid"])
        let routes = ["album": "/api/qq/album/detail?mid=\(albumMid)", "artist": "/api/qq/artist/detail?mid=\(artistMid)", "comments": "/api/qq/song/comments?id=\(QQMusicContract.text(song["qqId"]))&limit=2"]
        var failures = 0
        for key in ["album", "artist", "comments"] {
            do {
                let result = try await read(routes[key]!)
                let rows = result[key == "comments" ? "comments" : "songs"] as? [[String: Any]]
                guard rows != nil, result["error"] == nil else { throw URLError(.cannotParseResponse) }
                print("QQ anonymous \(key): valid platform response (\(rows!.count) records; contents withheld)")
            } catch { failures += 1; print("QQ anonymous \(key): NOT VERIFIED (\(error.localizedDescription))") }
        }
        guard failures == 0 else { throw URLError(.resourceUnavailable) }
    }
}
