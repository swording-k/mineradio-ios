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
    private let player = ApplicationMusicPlayer.shared
    private var pulse: Task<Void, Never>?
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
    private func mapped(_ song: Song) -> [String: Any] {
        let remembered = songCache[song.id.rawValue]
        let artwork = song.artwork ?? remembered?.artwork
        return ["id": song.id.rawValue, "providerSongId": song.id.rawValue, "provider": "applemusic", "source": "applemusic", "type": "applemusic",
                "name": song.title, "artist": song.artistName, "album": song.albumTitle ?? remembered?.albumTitle ?? "",
                "duration": song.duration ?? remembered?.duration ?? 0,
                "cover": artwork?.url(width: 800, height: 800)?.absoluteString ?? ""]
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
            songCache.removeAll(); return ["ok": true, "loggedIn": false]
        }
        if ["library", "tracks", "search", "playID"].contains(action) {
            guard MusicAuthorization.currentStatus == .authorized && !detached else { return ["ok": false, "message": "请先连接 Apple Music。"] }
            do {
                if action == "library" {
                    if playlists.isEmpty && songs.isEmpty { await connect() }
                    guard !connectionFailed else { return ["ok": false, "message": message] }
                    remember(songs)
                    let liked: [String: Any] = ["id": "applemusic-library", "provider": "applemusic", "name": "Apple Music 资料库", "virtual": true, "trackCount": songs.count, "cover": songs.first.map { mapped($0)["cover"] ?? "" } ?? "", "shelfPane": "mine"]
                    let rows: [[String: Any]] = playlists.map { ["id": $0.id.rawValue, "provider": "applemusic", "source": "applemusic", "name": $0.name, "cover": $0.artwork?.url(width: 400, height: 400)?.absoluteString ?? "", "trackCount": $0.tracks?.count ?? 0, "shelfPane": "mine"] }
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
                    guard let selected = songCache[id] else { return ["ok": false, "message": "歌曲尚未载入，请从 Apple Music 歌单或搜索中重新选择。"] }
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
            case "stop": player.pause(); active = false; pulse?.cancel(); emit()
            case "pause": player.pause()
            case "play": if active { try await player.play() }
            case "toggle": if active { if player.state.playbackStatus == .playing { player.pause() } else { try await player.play() } }
            case "next": if active { try await player.skipToNextEntry() }
            case "prev": if active { try await player.skipToPreviousEntry() }
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
        if let song = currentSong {
            state["song"] = mapped(song)
        }
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
