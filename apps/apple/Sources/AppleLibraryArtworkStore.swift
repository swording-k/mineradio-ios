import Foundation


/// Artwork URLs supplied by a device library aren't necessarily web URLs. Only native
/// MusicKit objects can supply a source; the web view receives a session-scoped path.
@MainActor final class AppleLibraryArtworkStore {
    enum Item: String { case playlist, library, song }
    static let prefix = "/api/apple-music-art/"
    private var session = UUID().uuidString
    private let cache = NSCache<NSString, NSData>()
    private var pending: [String: Task<Data?, Never>] = [:]
    private var misses: [String: Date] = [:]
    private var activeLoads = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private func acquire() async {
        if activeLoads < 4 { activeLoads += 1; return }
        await withCheckedContinuation { waiting.append($0) }
    }
    private func release() {
        if waiting.isEmpty { activeLoads -= 1 } else { waiting.removeFirst().resume() }
    }
    init() { cache.totalCostLimit = 8 * 1024 * 1024; cache.countLimit = 100 }
    func path(_ kind: Item, _ id: String) -> String {
        var parts = URLComponents()
        parts.path = Self.prefix + session + "/" + kind.rawValue
        parts.queryItems = [URLQueryItem(name: "id", value: id)]
        return parts.string ?? ""
    }
    func reset() {
        session = UUID().uuidString
        for task in pending.values { task.cancel() }
        pending.removeAll(); cache.removeAllObjects(); misses.removeAll()
    }

    /// On-demand and coalesced: browsing the library doesn't eagerly hydrate 100 playlists.
    func image(at url: URL, load: @escaping (Item, String) async -> Data?) async -> Data? {
        let base = Self.prefix + session + "/"
        guard url.path.hasPrefix(base), let kind = Item(rawValue: String(url.path.dropFirst(base.count))),
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value,
              !id.isEmpty, id.utf8.count <= 512 else { return nil }
        let key = kind.rawValue + ":" + id
        if let data = cache.object(forKey: key as NSString) { return data as Data }
        if let expiry = misses[key], expiry > Date() { return nil }
        if let running = pending[key] {
            let generation = session
            let value = await running.value
            return generation == session ? value : nil
        }
        let generation = session
        let task = Task<Data?, Never> {
            await acquire()
            defer { release() }
            guard !Task.isCancelled else { return nil }
            return await load(kind, id)
        }
        pending[key] = task
        let result = await task.value
        guard generation == session else { return nil }
        pending[key] = nil
        if let result { cache.setObject(result as NSData, forKey: key as NSString, cost: result.count) }
        else {
            if misses.count >= 256 { misses.removeAll() }
            misses[key] = Date().addingTimeInterval(30)
        }
        return result
    }

}
