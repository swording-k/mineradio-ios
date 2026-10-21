import Foundation

/// Opt-in anonymous smoke. It does not read Keychain or print IDs/audio URLs.
@main struct QishuiCatalogLiveProbe {
    static func main() async throws {
        let transport = QishuiCatalogTransport()
        let api = QishuiCatalogAPI(transport: transport)
        let status = await api.validateAccount()
        precondition(status["loggedIn"] as? Bool == false)
        let search = try await api.handle(URL(string: "http://127.0.0.1/api/qishui/search?keywords=Beethoven&limit=2")!, method: "GET", body: Data())
        let songs = search["songs"] as? [[String: Any]] ?? []
        print("Anonymous public search returned \(songs.count) real records; loggedIn=\(search["loggedIn"] ?? false)")
        if let id = songs.first?["id"] as? String {
            var target = URLComponents(string: "https://beta-luna.douyin.com/luna/h5/seo_track")!
            target.queryItems = [URLQueryItem(name: "track_id", value: id), URLQueryItem(name: "device_platform", value: "web")]
            let raw = try await transport.request(target.url!, headers: ["Accept": "application/json", "User-Agent": "Mineradio Apple", "Referer": "https://www.douyin.com/"])
            let lyric = QishuiCatalogContract.lyrics(raw), playback = QishuiCatalogContract.playback(raw, membership: [:], publicSource: true)
            print("Public track response parsed; lyricsPresent=\(!(lyric["lyric"] as? String ?? "").isEmpty), auditionPlayable=\(playback["playable"] ?? false), trial=\(playback["trial"] ?? false) (URLs withheld)")
        }
    }
}
