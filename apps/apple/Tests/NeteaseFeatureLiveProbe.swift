import Foundation

// Opt-in anonymous read-only probe. Never uses the user's saved session or performs writes.
@main struct NeteaseFeatureLiveProbe {
    static func main() async throws {
        let transport = NeteaseTransport(service: "com.swordingk.mineradio.feature-probe." + UUID().uuidString)
        let api = NeteaseNativeAPI(transport: transport)
        func read(_ route: String) async throws -> [String: Any] {
            let result = try await api.handle(URL(string: "http://127.0.0.1:19363" + route)!, method: "GET", body: Data())
            if result["error"] != nil { throw NSError(domain: "FeatureProbe", code: (result["code"] as? Int) ?? 502, userInfo: [NSLocalizedDescriptionKey: "\(route.components(separatedBy: "?").first!) failed: \(result["error"]!)"]) }
            return result
        }
        do {
            let search = try await read("/api/search?keywords=Beethoven&limit=1")
            guard let song = (search["songs"] as? [[String: Any]])?.first else { throw URLError(.cannotParseResponse) }
            let album = try await read("/api/album/detail?id=\(song["albumId"]!)")
            guard !(album["songs"] as? [[String: Any]] ?? []).isEmpty else { throw URLError(.cannotParseResponse) }
            print("Anonymous album detail: real album with songs")
            let artist = try await read("/api/artist/detail?id=\(song["artistId"]!)")
            guard !(artist["songs"] as? [[String: Any]] ?? []).isEmpty else { throw URLError(.cannotParseResponse) }
            print("Anonymous artist detail: real artist with songs")
            let comments = try await read("/api/song/comments?id=\(song["id"]!)")
            guard comments["comments"] is [[String: Any]] else { throw URLError(.cannotParseResponse) }
            print("Anonymous comments: valid platform response")
            let radios = try await read("/api/podcast/hot?limit=1")
            guard let radio = (radios["podcasts"] as? [[String: Any]])?.first else { throw URLError(.cannotParseResponse) }
            let programs = try await read("/api/podcast/programs?id=\(radio["id"]!)&limit=1")
            guard !(programs["programs"] as? [[String: Any]] ?? []).isEmpty else { throw URLError(.cannotParseResponse) }
            print("Anonymous podcasts: real hot radio and playable episode metadata")
            try await transport.clear()
        } catch { try? await transport.clear(); throw error }
    }
}
