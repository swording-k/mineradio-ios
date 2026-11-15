import Foundation

/// Only exact song/album resources and their catalog relationship may supply art.
enum AppleMusicMetadataArtwork {
    // A numeric Song.id from MusicLibraryRequest may be a device-local
    // persistent ID. Only an explicit store/catalog ID is safe for a lookup.
    static func storeID(_ value: Any?) -> String? {
        let text = (value as? String) ?? (value as? NSNumber)?.stringValue ?? ""
        guard !text.isEmpty, text != "0", text.count <= 20, text.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return text
    }

    static func sameRelease(_ a: [String], _ b: [String], duration: Double?, otherDuration: Double?) -> Bool {
        func key(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
        let left = a.map(key)
        return left.count == 3 && !left.contains("") && left == b.map(key)
            && (duration ?? 0) > 0 && (otherDuration ?? 0) > 0 && abs((duration ?? 0) - (otherDuration ?? 0)) < 3
    }

    static func catalogID(_ parameters: [String: Any]) -> String? {
        if let catalog = storeID(parameters["catalogId"] ?? parameters["catalogID"]) { return catalog }
        guard parameters["isLibrary"] as? Bool == false else { return nil }
        return storeID(parameters["id"])
    }

    // Public Apple metadata is used only for the exact store ID. Never pick
    // the first search result for a similar title or an unrelated release.
    static func storeArtwork(_ json: [String: Any], id: String, size: Int) -> URL? {
        guard storeID(id) != nil, let rows = json["results"] as? [[String: Any]],
              let row = rows.first(where: { $0["kind"] as? String == "song" && storeID($0["trackId"]) == id }),
              let raw = row["artworkUrl100"] as? String, let url = URL(string: raw),
              url.scheme == "https", url.host?.hasSuffix(".mzstatic.com") == true,
              url.path.hasPrefix("/image/"), url.user == nil, url.password == nil else { return nil }
        guard url.lastPathComponent == "100x100bb.jpg" else { return url }
        return url.deletingLastPathComponent().appendingPathComponent("\(size)x\(size)bb.jpg")
    }

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
