import Foundation
import CryptoKit
import Security

enum SpotifyContract {
    static let redirectURI = "com.swordingk.mineradio.apple://spotify/callback"
    static let scopes = "playlist-read-private playlist-read-collaborative user-library-read user-library-modify user-top-read playlist-modify-private playlist-modify-public"
    static func validID(_ value: String) -> Bool { !value.isEmpty && value.count <= 128 && value.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } }
    static func clientID(_ value: String) -> String { value.count == 32 && value.allSatisfy { $0.isHexDigit } ? value : "" }
    static func base64URL(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    static func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw Failure.random }
        return base64URL(Data(bytes))
    }
    static func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }
    static func form(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return Data(fields.sorted { $0.key < $1.key }.map { $0.key + "=" + ($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") }.joined(separator: "&").utf8)
    }
    static func song(_ raw: [String: Any]) -> [String: Any]? {
        guard let id = raw["id"] as? String, validID(id), raw["is_local"] as? Bool != true else { return nil }
        let album = raw["album"] as? [String: Any] ?? [:], artists = raw["artists"] as? [[String: Any]] ?? []
        return ["provider": "spotify", "source": "spotify", "type": "spotify", "id": id, "spotifyId": id,
                "spotifyUri": "spotify:track:" + id, "uri": "spotify:track:" + id, "name": raw["name"] as? String ?? "",
                "artist": artists.compactMap {$0["name"] as? String}.joined(separator: " / "), "artists": artists,
                "album": album["name"] as? String ?? "", "albumId": album["id"] as? String ?? "",
                "cover": image(album), "duration": raw["duration_ms"] as? Int ?? 0, "playable": false]
    }
    static func image(_ raw: [String: Any]) -> String { (raw["images"] as? [[String: Any]])?.last?["url"] as? String ?? "" }
    static func page(_ raw: [String: Any], rows: [[String: Any]], offset: Int, key: String) -> [String: Any] {
        let consumed = (raw["items"] as? [Any])?.count ?? 0
        return ["provider": "spotify", key: rows, "total": raw["total"] as? Int ?? offset + consumed,
                "offset": offset, "nextOffset": offset + consumed, "hasMore": consumed > 0 && raw["next"] is String]
    }
    enum Failure: Error { case random }
}

struct SpotifyHTTPResponse { let data: Data; let status: Int; var retryAfter: Int = 0 }
protocol SpotifyRequesting: Actor { func request(_ request: URLRequest) async throws -> SpotifyHTTPResponse }
private final class SpotifyNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
actor SpotifyTransport: SpotifyRequesting {
    private let session = URLSession(configuration: .ephemeral, delegate: SpotifyNoRedirect(), delegateQueue: nil)
    func request(_ request: URLRequest) async throws -> SpotifyHTTPResponse {
        guard let url = request.url, url.scheme == "https", url.user == nil, url.password == nil,
              (url.host == "api.spotify.com" && url.path.hasPrefix("/v1/")) || (url.host == "accounts.spotify.com" && url.path == "/api/token") else { throw URLError(.unsupportedURL) }
        let (data, response) = try await session.data(for: request)
        guard data.count <= 8 * 1024 * 1024, let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return .init(data: data, status: http.statusCode, retryAfter: min(86400, max(1, Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5)))
    }
}
