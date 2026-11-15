import Foundation

@main struct AppleLibraryArtworkStoreTests {
    @MainActor static func main() async {
        let store = AppleLibraryArtworkStore()
        let id = "p.1 /?&+"
        let link = URL(string: store.path(.playlist, id))!
        var calls = 0
        @MainActor @Sendable func load(_ kind: AppleLibraryArtworkStore.Item, _ actual: String) async -> Data? {
            precondition(kind == .playlist && actual == id)
            calls += 1
            try? await Task.sleep(nanoseconds: 8_000_000)
            return Data([123])
        }
        async let one = store.image(at: link, load: load)
        async let two = store.image(at: link, load: load)
        let pair = await (one, two)
        precondition(pair.0 == Data([123]) && pair.1 == pair.0 && calls == 1)
        let cached = await store.image(at: link, load: load)
        precondition(cached == pair.0 && calls == 1)
        store.reset()
        let revoked = await store.image(at: link, load: load)
        precondition(revoked == nil && calls == 1)
        var active = 0, peak = 0
        await withTaskGroup(of: Void.self) { group in
            for n in 0..<12 {
                let url = URL(string: store.path(.song, String(n)))!
                group.addTask { @MainActor in
                    _ = await store.image(at: url) { _,_ in
                        active += 1; peak = max(peak, active)
                        try? await Task.sleep(nanoseconds: 12_000_000)
                        active -= 1; return nil
                    }
                }
            }
        }
        precondition(peak == 4)
        print("Artwork store: encoded IDs, deduplication, cache, disconnect and concurrency passed")
    }
}
