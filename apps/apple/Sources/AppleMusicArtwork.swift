import MusicKit
import MediaPlayer
import UIKit

@MainActor enum AppleMusicArtwork {
    static func jpeg(_ artwork: Artwork?, size: Int) async -> Data? {
        guard let artwork else { return nil }
        guard let url = artwork.url(width: size, height: size) else {
            AppleDiagnostics.shared.recordAppleArtwork(stage: 10, success: false, code: 1); return nil
        }
        return await jpeg(url: url, size: size)
    }
    static func jpeg(url: URL, size: Int) async -> Data? {
        let data: Data
        if url.scheme?.lowercased() == "https", AppleMediaPolicy.allowed(url) {
            guard let hit = await AppleCoverCache.shared.image(for: url, referer: AppleMediaPolicy.referer(url)) else {
                AppleDiagnostics.shared.recordAppleArtwork(stage: 10, success: false, code: 2); return nil
            }
            data = hit.data
        } else {
            // URL comes exclusively from Artwork.url(), never a bridge argument or HTTP query.
            guard let pair = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 6)),
                  (pair.1 as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? true,
                  pair.0.count <= 6 * 1024 * 1024 else {
                AppleDiagnostics.shared.recordAppleArtwork(stage: 10, success: false, code: url.scheme == "https" ? 3 : 4); return nil
            }
            data = pair.0
        }
        return await Task.detached(priority: .utility) {
            AppleArtwork.decode(data, maxPixelSize: size).flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.88) }
        }.value
    }
    static func localSong(_ song: Song, size: Int) -> (data: Data?, storeID: String?) {
        // MusicKit library IDs can be opaque strings (i.…). They are not
        // MPMediaEntityPersistentIDs. Query by metadata, then verify the version.
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(MPMediaPropertyPredicate(value: song.title, forProperty: MPMediaItemPropertyTitle, comparisonType: .equalTo))
        let candidates = query.items ?? []
        var ids = Set<String>()
        for item in candidates.prefix(40) {
            guard item.title == song.title, item.artist == song.artistName,
                  song.albumTitle == nil || item.albumTitle == song.albumTitle,
                  song.duration == nil || abs(item.playbackDuration - (song.duration ?? 0)) < 3 else { continue }
            let id = AppleMusicMetadataArtwork.storeID(item.playbackStoreID)
            if let id { ids.insert(id) }
            if let data = item.artwork?.image(at: CGSize(width: size, height: size))?.jpegData(compressionQuality: 0.88) { return (data, id) }
        }
        return (nil, ids.count == 1 ? ids.first : nil)
    }
}
