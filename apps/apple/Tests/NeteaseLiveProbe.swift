import Foundation

/// Opt-in anonymous network smoke. Never logs session cookies or QR keys.
@main struct NeteaseLiveProbe {
    static func main() async throws {
        let api = NeteaseNativeAPI(transport: NeteaseTransport(service: "com.swordingk.mineradio.anonymous-probe"))
        let result = try await api.handle(URL(string: "http://127.0.0.1:19363/api/login/qr/key")!, method: "GET", body: Data())
        guard let key = result["key"] as? String, !key.isEmpty else {
            print("QR key request failed: \(result["code"] ?? "unknown") \(result["message"] ?? "")"); exit(1)
        }
        print("Anonymous QR key: valid (value withheld)")
        let qrURL = URL(string: "http://127.0.0.1:19363/api/login/qr/create?key=\(key)")!
        let qr = try await api.handle(qrURL, method: "GET", body: Data())
        guard (qr["img"] as? String)?.hasPrefix("data:image/png;base64,") == true else { exit(2) }
        print("QR image: generated")
        let status = try await api.handle(URL(string: "http://127.0.0.1:19363/api/login/status")!, method: "GET", body: Data())
        print("Anonymous account reports loggedIn: \(status["loggedIn"] ?? "unknown")")
        let search = try await api.handle(URL(string: "http://127.0.0.1:19363/api/search?keywords=Beethoven&limit=2")!, method: "GET", body: Data())
        guard let songs = search["songs"] as? [[String: Any]], !songs.isEmpty else {
            print("Search failed: \(search["code"] ?? "unknown") \(search["message"] ?? "")"); exit(3)
        }
        print("Search: \(songs.count) real song records")
        let songID = String(describing: songs[0]["id"]!)
        let lyric = try await api.handle(URL(string: "http://127.0.0.1:19363/api/lyric?id=\(songID)")!, method: "GET", body: Data())
        guard lyric["lyric"] is String else { exit(4) }
        print("Lyrics: valid response (may be empty for instrumental tracks)")
        let playback = try await api.handle(URL(string: "http://127.0.0.1:19363/api/song/url?id=\(songID)&quality=standard")!, method: "GET", body: Data())
        print("Anonymous audio: playable=\(playback["playable"] ?? false), trial=\(playback["trial"] ?? "unknown") (URL withheld)")
    }
}
