import SwiftUI
import MusicKit

/// MusicKit owns protected playback and credentials. The web view receives metadata only.
@MainActor final class AppleMusicController: ObservableObject {
    static let shared = AppleMusicController()
    @Published var presented = false
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
    private var songPage: MusicItemCollection<Song>?
    private var trackPage: MusicItemCollection<Track>?
    @Published private(set) var hasMore = false
    var prepare: (() async throws -> Void)?
    var publish: (([String: Any]) -> Void)?

    func connect() async {
        guard !busy else { return }
        requestGeneration += 1; let generation = requestGeneration
        busy = true; defer { if generation == requestGeneration { busy = false } }
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
            songPage = songResult; trackPage = nil; hasMore = songResult.hasNextBatch
            songs = Array(songResult); playlists = Array(listResult)
            message = canPlay ? "Apple Music 已连接" : "音乐资料已授权；当前账户无法播放 Apple Music 曲库，请检查订阅。"
        } catch { fail(error) }
    }
    func search(_ term: String) async {
        requestGeneration += 1; let generation = requestGeneration
        guard authorized, !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        busy = true; defer { if generation == requestGeneration { busy = false } }
        do {
            var request = MusicCatalogSearchRequest(term: String(term.prefix(200)), types: [Song.self]); request.limit = 25
            let result = try await request.response()
            guard generation == requestGeneration else { return }
            songPage = result.songs; trackPage = nil; hasMore = result.songs.hasNextBatch
            songs = Array(result.songs); message = songs.isEmpty ? "没有找到歌曲" : "Apple Music 搜索结果"
        } catch { if generation == requestGeneration { fail(error) } }
    }
    func open(_ playlist: Playlist) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        requestGeneration += 1; let generation = requestGeneration
        do {
            let detail = try await playlist.with(.tracks)
            guard generation == requestGeneration else { return }
            trackPage = detail.tracks; songPage = nil; hasMore = detail.tracks?.hasNextBatch ?? false
            songs = detail.tracks?.compactMap { track in if case .song(let song) = track { return song }; return nil } ?? []
            message = songs.isEmpty ? "歌单暂无可用歌曲" : playlist.name
        } catch { fail(error) }
    }
    func loadMore() async {
        guard !busy, hasMore else { return }
        busy = true; defer { busy = false }
        let generation = requestGeneration
        do {
            if let page = songPage {
                let next = try await page.nextBatch(limit: 100)
                guard generation == requestGeneration else { return }
                songPage = next; hasMore = next?.hasNextBatch ?? false
                if let next { let ids = Set(songs.map(\.id)); songs += next.filter { !ids.contains($0.id) } }
            } else if let page = trackPage {
                let next = try await page.nextBatch(limit: 100)
                guard generation == requestGeneration else { return }
                trackPage = next; hasMore = next?.hasNextBatch ?? false
                if let next {
                    let ids = Set(songs.map(\.id))
                    songs += next.compactMap { if case .song(let song) = $0, !ids.contains(song.id) { return song }; return nil }
                }
            }
        } catch { fail(error) }
    }
    func play(_ song: Song) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            canPlay = try await MusicSubscription.current.canPlayCatalogContent
            guard authorized, canPlay else { message = "请先授权并确认 Apple Music 订阅有效。"; return }
            guard let prepare else { message = "播放舞台尚未就绪，请稍后重试。"; return }
            try await prepare()
            player.queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: song)
            try await player.play()
            active = true; presented = false; message = "Apple Music 正在播放"
            emit(); startPulse()
        } catch { fail(error) }
    }
    func command(_ action: String, value: Double? = nil) async -> [String: Any] {
        do {
            switch action {
            case "open": presented = true
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
    private var currentSong: Song? { if case .song(let song) = player.queue.currentEntry?.item { return song }; return nil }
    private var duration: Double { currentSong?.duration ?? 0 }
    private func emit() {
        var state: [String: Any] = ["active": active, "playing": active && player.state.playbackStatus == .playing,
                                  "current": max(0, player.playbackTime), "duration": duration]
        if let song = currentSong {
            state["song"] = ["id": song.id.rawValue, "provider": "applemusic", "source": "applemusic", "type": "applemusic",
                             "name": song.title, "artist": song.artistName, "album": song.albumTitle ?? "", "duration": duration,
                             "cover": song.artwork?.url(width: 800, height: 800)?.absoluteString ?? ""]
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

struct AppleMusicLibrarySheet: View {
    @ObservedObject var music: AppleMusicController
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("由 Apple Music 提供音乐播放。当前接入支持封面舞台；不提供逐字歌词或音频频谱分析。").font(.caption).foregroundStyle(.secondary)
                    Text(music.message).font(.subheadline).foregroundStyle(.secondary)
                    if !music.authorized { Button("授权并连接 Apple Music") { Task { await music.connect() } } }
                    else { Button("刷新我的音乐库") { Task { await music.connect() } } }
                    if music.busy { ProgressView() }
                }
                if music.authorized {
                    if !music.playlists.isEmpty {
                        Section("我的歌单") {
                            ForEach(music.playlists) { playlist in
                                Button { Task { await music.open(playlist) } } label: {
                                    Label(playlist.name, systemImage: "music.note.list")
                                }.disabled(music.busy)
                            }
                        }
                    }
                    Section("歌曲") {
                        ForEach(music.songs) { song in
                            Button { Task { await music.play(song) } } label: {
                                HStack(spacing: 12) {
                                    if let artwork = song.artwork { ArtworkImage(artwork, width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 6)) }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(song.title).foregroundStyle(.primary).lineLimit(2)
                                        Text(song.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "play.fill").foregroundStyle(.pink)
                                }.padding(.vertical, 4).frame(minHeight: 48)
                            }.disabled(music.busy || !music.canPlay)
                        }
                        if music.hasMore { Button("加载更多歌曲") { Task { await music.loadMore() } }.disabled(music.busy) }
                    }
                }
            }
            .navigationTitle("Apple Music")
            .searchable(text: $query, prompt: "搜索 Apple Music 歌曲")
            .onSubmit(of: .search) { Task { await music.search(query) } }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { music.presented = false } } }
            .task { if music.authorized { await music.connect() } }
        }.preferredColorScheme(.dark).tint(.pink)
    }
}
