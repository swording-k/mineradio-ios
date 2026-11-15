import Foundation

/// Only exact song/album resources and their catalog relationship may supply art.
enum AppleMusicMetadataArtwork {
    static func url(_ response: [String: Any], size: Int) -> URL? {
        func resource(_ object: [String: Any], depth: Int) -> URL? {
            guard depth < 3 else { return nil }
            if let attrs = object["attributes"] as? [String: Any],
               let artwork = attrs["artwork"] as? [String: Any], let template = artwork["url"] as? String {
                let value = template.replacingOccurrences(of: "{w}", with: String(size))
                    .replacingOccurrences(of: "{h}", with: String(size)).replacingOccurrences(of: "{f}", with: "jpg")
                if let url = URL(string: value), url.scheme == "https", let host = url.host?.lowercased(),
                   (host == "mzstatic.com" || host.hasSuffix(".mzstatic.com")),
                   url.user == nil, url.password == nil { return url }
            }
            if let relationships = object["relationships"] as? [String: Any] {
                for key in ["catalog", "albums"] {
                    if let relationship = relationships[key] as? [String: Any], let data = relationship["data"] as? [[String: Any]] {
                        for item in data { if let found = resource(item, depth: depth + 1) { return found } }
                    }
                }
            }
            return nil
        }
        for item in response["data"] as? [[String: Any]] ?? [] {
            if let result = resource(item, depth: 0) { return result }
        }
        return nil
    }
}
