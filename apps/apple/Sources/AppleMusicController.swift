import SwiftUI
import MusicKit

/// MusicKit owns protected playback and credentials. The web view receives metadata only.
@MainActor final class AppleMusicController: ObservableObject {
    static let shared = AppleMusicController()
    @Published private(set) var authorized = MusicAuthorization.currentStatus == .authorized
    @Published private(set) var busy = false
    @Published private(set) var message = "连接 Apple Music，访问音乐资料库和歌曲。完整曲库播放需要有效的 Apple Music 订阅。"
    @Published private(set) var songs: [Song] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var canPlay = false
    @Published private(set) var active = false
    struct DisplayArtwork: Equatable { let path: String; let artwork: Artwork }
    @Published private(set) var displayArtwork: DisplayArtwork?
    private let artworkStore = AppleLibraryArtworkStore()
    private let player = ApplicationMusicPlayer.shared
    private var pulse: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var artworkTrackID = ""
    private var artworkVersions: [String: Int] = [:]
    private var requestGeneration = 0
    private var songCache: [String: Song] = [:]
    private var queuedSongs: [String: Song] = [:]
    private var connectionFailed = false
    private var detached = UserDefaults.standard.bool(forKey: "apple-music-disconnected")
    var prepare: (() async throws -> Void)?
    var publish: (([String: Any]) -> Void)?

    func connect() async {
        guard !busy else { return }
        requestGeneration += 1; let generation = requestGeneration
        busy = true; defer { if generation == requestGeneration { busy = false } }
        connectionFailed = false
        let permission = await MusicAuthorization.request()
        authorized = permission == .authorized
        guard authorized else { message = "未获音乐资料访问权限。请到系统设置中允许 Mineradio 访问媒体与 Apple Music。"; return }
        do {
            let subscription = try await MusicSubscription.current
            canPlay = subscription.canPlayCatalogContent
            var library = MusicLibraryRequest<Song>(); library.limit = 100
            let songResult = try await library.response().items
            var lists = MusicLibraryRequest<Playlist>(); lists.limit = 100
            let listResult = try await lists.response().items
            guard generation == requestGeneration else { return }
            songs = Array(songResult); playlists = Array(listResult)
            message = canPlay ? "Apple Music 已连接" : "音乐资料已授权；当前账户无法播放 Apple Music 曲库，请检查订阅。"
        } catch { connectionFailed = true; fail(error) }
    }
    func play(_ song: Song, queue: [Song]? = nil) async -> Bool {
        guard !busy else { return false }; busy = true; defer { busy = false }
        do {
            canPlay = try await MusicSubscription.current.canPlayCatalogContent
            guard authorized, canPlay else { message = "请先授权并确认 Apple Music 订阅有效。"; return false }
            guard let prepare else { message = "播放舞台尚未就绪，请稍后重试。"; return false }
            try await prepare()
            remember(queue ?? songs)
            let items = queue ?? songs
            let nativeQueue = ApplicationMusicPlayer.Queue(for: items, startingAt: song)
            queuedSongs = Dictionary(uniqueKeysWithValues: zip(nativeQueue.entries.map(\.id), items))
            player.queue = nativeQueue
            try await player.play()
            active = true; message = "Apple Music 正在播放"
            emit(); startPulse(); return true
        } catch { fail(error); return false }
    }
    func artworkData(at url: URL) async -> Data? {
        guard !detached, MusicAuthorization.currentStatus == .authorized else {
            AppleDiagnostics.shared.recordAppleArtwork(stage: 5, success: false, code: detached ? 1 : 2); return nil
        }
        return await artworkStore.image(at: url) { [weak self] kind, id in
            guard let self else { return nil }
            switch kind {
            case .song:
                // A queue entry can resolve to a new library/catalog ID after playback
                // starts. Keep the emitting identity available to the image endpoint.
                guard let song = self.songCache[id] ?? (self.currentSong?.id.rawValue == id ? self.currentSong : nil) else {
                    AppleDiagnostics.shared.recordAppleArtwork(stage: 6, success: false); return nil
                }
                AppleDiagnostics.shared.recordAppleArtwork(stage: 7, success: true)
                return await self.songArtwork(song, size: 600)
            case .library:
                for song in self.songs.prefix(8) {
                    if let image = await self.songArtwork(song, size: 320) { return image }
                }
            case .playlist:
                guard let list = self.playlists.first(where: { $0.id.rawValue == id }) else { return nil }
                if let data = await AppleMusicArtwork.jpeg(list.artwork, size: 400) { return data }
                guard let detailed = try? await list.with(.tracks, preferredSource: .library) else { return nil }
                if detailed.artwork != list.artwork, let data = await AppleMusicArtwork.jpeg(detailed.artwork, size: 400) { return data }
                for track in (detailed.tracks?.prefix(8) ?? []) {
                    if Task.isCancelled { return nil }
                    if case .song(let song) = track, let image = await self.songArtwork(song, size: 320) { return image }
                }
            }
            return nil
        }
    }
    private func songArtwork(_ song: Song, size: Int) async -> Data? {
        // Queue entries may gain artwork after playback starts even when the
        // original library Song retained in songCache never gains artwork.
        let entryArt = currentSong?.id == song.id ? player.queue.currentEntry?.artwork : nil
        if let direct = await AppleMusicArtwork.jpeg(entryArt, size: size) { return direct }
        if entryArt != song.artwork, let direct = await AppleMusicArtwork.jpeg(song.artwork, size: size) { return direct }
        let local = AppleMusicArtwork.localSong(song, size: size)
        if let image = local.data { return image }
        let catalogID = catalogArtworkID(song) ?? local.storeID
        if let id = catalogID, let image = await exactStoreArtwork(id, size: size) { return image }
        if song.id.rawValue.hasPrefix("i."), song.id.rawValue.utf8.count < 256 {
            var components = URLComponents(string: "https://api.music.apple.com")!
            components.path = "/v1/me/library/songs/" + song.id.rawValue
            components.queryItems = [URLQueryItem(name: "include", value: "catalog,albums")]
            do {
                let response = try await MusicDataRequest(urlRequest: URLRequest(url: components.url!)).response()
                if let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                   let url = AppleMusicMetadataArtwork.url(json, size: size),
                   let data = await AppleMusicArtwork.jpeg(url: url, size: size) { return data }
            } catch {
                AppleDiagnostics.shared.recordAppleArtwork(stage: 1, success: false, code: (error as NSError).code)
            }
        }
        // Library relationships and catalog relationships are distinct; try the
        // library album before the catalog. Do not search by a vaguely similar name.
        if let detailed = try? await song.with(.albums, preferredSource: .library) {
            if let data = await AppleMusicArtwork.jpeg(detailed.artwork, size: size) { return data }
            if let album = detailed.albums?.first, let data = await AppleMusicArtwork.jpeg(album.artwork, size: size) { return data }
        }
        if let detailed = try? await song.with(.albums, preferredSource: .catalog) {
            if let data = await AppleMusicArtwork.jpeg(detailed.artwork, size: size) { return data }
            if let album = detailed.albums?.first, let data = await AppleMusicArtwork.jpeg(album.artwork, size: size) { return data }
        }
        if let id = catalogID {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
            if let catalog = try? await request.response().items.first {
                if let data = await AppleMusicArtwork.jpeg(catalog.artwork, size: size) { return data }
            }
        }
        // Search only for the playing track with no usable exact-ID art.
        // Library scrolling must never start a metadata search per row.
        if active, currentSong?.id == song.id, let album = song.albumTitle, !album.isEmpty, !Task.isCancelled {
            var search = MusicCatalogSearchRequest(term: song.title + " " + song.artistName, types: [Song.self])
            search.limit = 12
            do {
                let matches = try await search.response().songs.filter {
                    AppleMusicMetadataArtwork.sameRelease([song.title, song.artistName, album],
                        [$0.title, $0.artistName, $0.albumTitle ?? ""], duration: song.duration, otherDuration: $0.duration)
                        && (song.isrc == nil || $0.isrc == nil || song.isrc == $0.isrc)
                }
                if let item = matches.first, Set(matches.map(\.id)).count == 1 {
                    if let data = await AppleMusicArtwork.jpeg(item.artwork, size: size) { return data }
                    if let id = AppleMusicMetadataArtwork.storeID(item.id.rawValue), id != catalogID,
                       let data = await exactStoreArtwork(id, size: size) { return data }
                }
            } catch { AppleDiagnostics.shared.recordAppleArtwork(stage: 3, success: false, code: (error as NSError).code) }
        }
        if active, currentSong?.id == song.id {
            // Which metadata existed at the failing boundary; no names, IDs or URLs.
            let flags = (entryArt != nil ? 1 : 0) | (song.artwork != nil ? 2 : 0) | (catalogID != nil ? 4 : 0) | (local.storeID != nil ? 8 : 0)
            AppleDiagnostics.shared.recordAppleArtwork(stage: 4, success: false, code: flags)
        }
        return nil
    }
    private func resolvePlayingArtwork(_ song: Song) {
        artworkTrackID = song.id.rawValue
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            // Resolve once per track and retry only transient failures. The URL
            // revision lets both WebGL and native controls recover from a first miss.
            for delay: UInt64 in [0, 3, 8] {
                if delay > 0 { try? await Task.sleep(nanoseconds: delay * 1_000_000_000) }
                guard !Task.isCancelled, let self, self.active else { return }
                let url = URL(string: self.artworkStore.path(.song, song.id.rawValue))!
                if await self.artworkData(at: url) != nil {
                    guard !Task.isCancelled else { return }
                    AppleDiagnostics.shared.recordAppleArtwork(stage: 2, success: true)
                    self.artworkVersions[song.id.rawValue] = (self.artworkVersions[song.id.rawValue] ?? 0) + 1
                    self.emit(); return
                }
            }
            guard !Task.isCancelled else { return }
            self?.recordArtworkMiss()
        }
    }
    private func recordArtworkMiss() { AppleDiagnostics.shared.recordAppleArtwork(stage: 2, success: false) }
    private func catalogArtworkID(_ song: Song) -> String? {
        guard let parameters = song.playParameters,
              let bytes = try? JSONEncoder().encode(parameters),
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return nil }
        return AppleMusicMetadataArtwork.catalogID(object)
    }

    private func exactStoreArtwork(_ id: String, size: Int) async -> Data? {
        guard !Task.isCancelled else { return nil }
        let region = (try? await MusicDataRequest.currentCountryCode) ?? Locale.current.region?.identifier
        guard let region, region.count == 2 else { return nil }
        var parts = URLComponents(string: "https://itunes.apple.com/lookup")!
        parts.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "country", value: region)]
        guard let url = parts.url,
              let (bytes, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 5)),
              (response as? HTTPURLResponse)?.statusCode == 200, bytes.count <= 262144,
              let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let image = AppleMusicMetadataArtwork.storeArtwork(json, id: id, size: size) else { return nil }
        return await AppleMusicArtwork.jpeg(url: image, size: size)
    }
    private func mapped(_ song: Song) -> [String: Any] {
        let remembered = songCache[song.id.rawValue]
        return ["id": song.id.rawValue, "providerSongId": song.id.rawValue, "provider": "applemusic", "source": "applemusic", "type": "applemusic",
                "name": song.title, "artist": song.artistName, "album": song.albumTitle ?? remembered?.albumTitle ?? "",
                "duration": song.duration ?? remembered?.duration ?? 0,
                "cover": artworkStore.path(.song, song.id.rawValue) + "&art=" + String(artworkVersions[song.id.rawValue] ?? 0)]
    }

    private func remember(_ values: [Song]) { for song in values { songCache[song.id.rawValue] = song } }
    private func status() -> [String: Any] {
        ["provider": "applemusic", "loggedIn": MusicAuthorization.currentStatus == .authorized && !detached,
         "nickname": "Apple Music", "userId": "apple-music-device", "canPlay": canPlay, "message": message]
    }
    func request(_ input: [String: Any]) async -> [String: Any] {
        let action = input["action"] as? String ?? ""
        if action == "status" { return status() }
        if action == "authorize" {
            detached = false; UserDefaults.standard.set(false, forKey: "apple-music-disconnected")
            await connect(); if connectionFailed { return ["ok": false, "message": message] }; return status()
        }
        if action == "logout" {
            _ = await command("stop"); detached = true; UserDefaults.standard.set(true, forKey: "apple-music-disconnected")
            artworkTask?.cancel(); artworkVersions.removeAll(); songCache.removeAll(); songs = []; playlists = []; queuedSongs.removeAll(); artworkStore.reset(); return ["ok": true, "loggedIn": false]
        }
        if ["library", "tracks", "search", "playID"].contains(action) {
            guard MusicAuthorization.currentStatus == .authorized && !detached else { return ["ok": false, "message": "请先连接 Apple Music。"] }
            do {
                if action == "library" {
                    if playlists.isEmpty && songs.isEmpty { await connect() }
                    guard !connectionFailed else { return ["ok": false, "message": message] }
                    remember(songs)
                    let liked: [String: Any] = ["id": "applemusic-library", "provider": "applemusic", "name": "Apple Music 资料库", "virtual": true, "trackCount": songs.count, "cover": artworkStore.path(.library, "songs"), "shelfPane": "mine"]
                    let rows: [[String: Any]] = playlists.map { ["id": $0.id.rawValue, "provider": "applemusic", "source": "applemusic", "name": $0.name, "cover": artworkStore.path(.playlist, $0.id.rawValue), "trackCount": $0.tracks?.count ?? 0, "shelfPane": "mine"] }
                    return ["ok": true, "playlists": [liked] + rows, "canPlay": canPlay]
                }
                let offset = min(5000, max(0, input["offset"] as? Int ?? 0)), limit = min(100, max(1, input["limit"] as? Int ?? 50))
                if action == "search" {
                    var query = MusicCatalogSearchRequest(term: String((input["query"] as? String ?? "").prefix(200)), types: [Song.self]); query.limit = limit
                    let result = try await query.response(); var page = result.songs
                    var values = Array(page)
                    while values.count < offset + limit, page.hasNextBatch, let next = try await page.nextBatch(limit: 100) { page = next; values += next }
                    remember(values)
                    return ["ok": true, "songs": Array(values.dropFirst(offset).prefix(limit)).map(mapped), "hasMore": page.hasNextBatch || values.count > offset + limit]
                }
                let id = input["id"] as? String ?? ""
                if action == "tracks" {
                    var values: [Song] = []; var more = false; var consumed = 0
                    if id == "applemusic-library" {
                        var req = MusicLibraryRequest<Song>(); req.limit = limit; req.offset = offset
                        let page = try await req.response().items; values = Array(page); consumed = values.count; more = page.hasNextBatch
                    } else {
                        guard let list = playlists.first(where: { $0.id.rawValue == id }) else { return ["ok": false, "message": "歌单尚未载入，请刷新 Apple Music 歌单。"] }
                        let loaded = try await list.with(.tracks)
                        if var page = loaded.tracks {
                            var tracks = Array(page)
                            while tracks.count < offset + limit, page.hasNextBatch, let next = try await page.nextBatch(limit: 100) { page = next; tracks += next }
                            let slice = tracks.dropFirst(offset).prefix(limit); consumed = slice.count
                            values = slice.compactMap { if case .song(let song) = $0 { return song }; return nil }
                            more = page.hasNextBatch || tracks.count > offset + limit
                        }
                    }
                    remember(values)
                    return ["ok": true, "tracks": values.map(mapped), "offset": offset, "nextOffset": offset + consumed, "hasMore": more, "total": offset + consumed + (more ? 1 : 0)]
                }
                if action == "playID" {
                    if songCache[id] == nil {
                        if id.allSatisfy({ $0.isNumber }), !id.isEmpty {
                            let lookup = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
                            if let item = try await lookup.response().items.first { remember([item]) }
                        } else {
                            var lookup = MusicLibraryRequest<Song>(); lookup.filter(matching: \.id, equalTo: MusicItemID(id)); lookup.limit = 1
                            if let item = try await lookup.response().items.first { remember([item]) }
                        }
                    }
                    guard let selected = songCache[id] else { return ["ok": false, "message": "歌曲已不在 Apple Music 资料库中，请刷新歌单。"] }
                    let ids = input["ids"] as? [String] ?? [id]
                    let queue = ids.prefix(500).compactMap { songCache[$0] }
                    let started = await play(selected, queue: queue.isEmpty ? [selected] : queue)
                    return ["ok": started, "message": message]
                }
            } catch { fail(error); return ["ok": false, "message": message] }
        }
        return await command(action, value: (input["value"] as? NSNumber)?.doubleValue)
    }
    func command(_ action: String, value: Double? = nil) async -> [String: Any] {
        do {
            switch action {
            case "stop": artworkTrackID = ""; artworkTask?.cancel(); player.pause(); active = false; pulse?.cancel(); emit()
            case "pause": player.pause()
            case "play": if active { try await player.play() }
            case "toggle": if active { if player.state.playbackStatus == .playing { player.pause() } else { try await player.play() } }
            case "next": if active { try await player.skipToNextEntry(); if let song = currentSong { resolvePlayingArtwork(song) } }
            case "prev": if active { try await player.skipToPreviousEntry(); if let song = currentSong { resolvePlayingArtwork(song) } }
            case "seek": if active, let value, value.isFinite { player.playbackTime = min(max(0, value), duration) }
            default: break
            }
            emit(); return ["ok": true]
        } catch { fail(error); return ["ok": false, "message": message] }
    }
    private var currentSong: Song? {
        guard let entry = player.queue.currentEntry else { return nil }
        if let song = queuedSongs[entry.id] { return song }
        if case .song(let song) = entry.item { return song }
        return nil
    }
    private var duration: Double { currentSong.map { $0.duration ?? songCache[$0.id.rawValue]?.duration ?? 0 } ?? 0 }
    private func emit() {
        var state: [String: Any] = ["active": active, "playing": active && player.state.playbackStatus == .playing,
                                  "current": max(0, player.playbackTime), "duration": duration]
        var display: DisplayArtwork?
        if let song = currentSong {
            remember([song])
            if active, let art = player.queue.currentEntry?.artwork ?? song.artwork {
                display = DisplayArtwork(path: artworkStore.path(.song, song.id.rawValue), artwork: art)
            }
            if active && artworkTrackID != song.id.rawValue { resolvePlayingArtwork(song) }
            state["song"] = mapped(song)
        }
        if display != displayArtwork { displayArtwork = display }
        publish?(state)
    }
    private func startPulse() {
        pulse?.cancel()
        pulse = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.active else { return }
                self.emit()
            }
        }
    }
    private func fail(_ error: Error) {
        message = "Apple Music 请求未完成：" + error.localizedDescription + "。请检查系统音乐账户、网络及 App 的 MusicKit 服务配置。"
    }
}
