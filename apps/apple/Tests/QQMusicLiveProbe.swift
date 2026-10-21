import Foundation
@main struct QQMusicLiveProbe {
    static func main() async throws {
        let api = QQMusicNativeAPI(keychainService: nil)
        let response = try await api.handle(URL(string: "http://127.0.0.1/api/qq/search?keywords=Beethoven&limit=2")!, method: "GET", body: Data())
        let songs = response["songs"] as? [[String: Any]] ?? []
        print("QQ anonymous search song count: \(songs.count)")
        if let song = songs.first, let mid = song["mid"] as? String {
            var c = URLComponents(string: "http://127.0.0.1/api/qq/song/url")!
            c.queryItems = [URLQueryItem(name: "mid", value: mid), URLQueryItem(name: "mediaMid", value: song["mediaMid"] as? String ?? ""), URLQueryItem(name: "quality", value: "standard")]
            let playback = try await api.handle(c.url!, method: "GET", body: Data())
            print("QQ anonymous playback playable: \(playback["playable"] as? Bool ?? false)")
            let lyric = try await api.handle(URL(string: "http://127.0.0.1/api/qq/lyric?mid=\(mid)")!, method: "GET", body: Data())
            print("QQ anonymous lyric available: \(!(lyric["lyric"] as? String ?? "").isEmpty)")
        }
    }
}
