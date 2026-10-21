import Foundation
@main struct KugouLiveProbe {
    static func main() async {
        let api = KugouNativeAPI(keychainService: "com.swordingk.mineradio.kugou.anonymous-probe")
        do {
            let response = try await api.handle(URL(string: "http://127.0.0.1:19363/api/kugou/search?keywords=%E5%91%A8%E6%9D%B0%E4%BC%A6&limit=2")!, method: "GET", body: Data())
            let songs = response["songs"] as? [[String: Any]] ?? []
            print("Anonymous Kugou search songCount=\(songs.count)")
            if let hash = songs.first?["hash"] as? String, !hash.isEmpty {
                let album = songs.first?["albumId"] as? String ?? ""
                let audio = songs.first?["albumAudioId"] as? String ?? ""
                var parts = URLComponents(string: "http://127.0.0.1:19363/api/kugou/song/url")!
                parts.queryItems = [URLQueryItem(name: "hash", value: hash), URLQueryItem(name: "albumId", value: album), URLQueryItem(name: "albumAudioId", value: audio)]
                let url = parts.url!
                let playback = try await api.handle(url, method: "GET", body: Data())
                print("Anonymous Kugou URL playable=\(playback["playable"] ?? false), trial=\(playback["trial"] ?? false)")
            }
        } catch { print("Anonymous Kugou probe failed: \(error.localizedDescription)") }
    }
}
