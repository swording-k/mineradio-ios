import Foundation
import MediaPlayer
import UIKit

/// 原生播放状态中心（IOS_PLAN 阶段 C）。
/// 网页里的原版播放器推送状态（apple-native-controls.js），这里统一驱动：
/// iPhone 原生控制条、锁屏 / 控制中心「正在播放」、耳机与锁屏远程控制命令。
@MainActor final class NowPlayingModel: ObservableObject {
    struct State: Equatable {
        var hasSong = false, title = "", artist = "", cover = ""
        var playing = false, current = 0.0, duration = 0.0
        var liked = false, trial = false, immersive = false, splash = false, modal = false
        var autoHide = true, webBar = false
    }
    @Published private(set) var state = State()
    /// 原生控制条当前是否展开（自动隐藏 / 舞台点按唤出）。
    @Published var barVisible = true
    /// 由 OriginalPlayerView 注入：把命令转给网页里的原版播放器。
    var send: ((String, Any?) -> Void)?

    private var hideTask: Task<Void, Never>?
    private var artworkURL = ""
    private var artwork: MPMediaItemArtwork?
    private var commandsInstalled = false

    var showsBar: Bool { state.hasSong && !state.immersive && !state.splash && !state.modal && !state.webBar }

    func command(_ name: String, _ value: Any? = nil) {
        send?(name, value)
        reveal()
    }

    func receive(_ body: [String: Any]) {
        switch body["type"] as? String {
        case "reveal": reveal()
        case "state":
            guard let raw = body["state"] as? [String: Any] else { return }
            func s(_ k: String) -> String { String((raw[k] as? String ?? "").prefix(2048)) }
            func d(_ k: String) -> Double { let v = (raw[k] as? NSNumber)?.doubleValue ?? 0; return v.isFinite && v > 0 ? v : 0 }
            func b(_ k: String) -> Bool { raw[k] as? Bool ?? false }
            var next = State(hasSong: b("hasSong"), title: s("title"), artist: s("artist"), cover: s("cover"),
                             playing: b("playing"), current: d("current"), duration: d("duration"),
                             liked: b("liked"), trial: b("trial"), immersive: b("immersive"), splash: b("splash"), modal: b("modal"),
                             autoHide: raw["autoHide"] as? Bool ?? true, webBar: b("webBar"))
            if next.duration > 0 { next.current = min(next.current, next.duration) }
            let started = next.playing && !state.playing
            let trackChanged = next.title != state.title || next.cover != state.cover
            state = next
            installRemoteCommands()
            updateSystemNowPlaying(trackChanged: trackChanged)
            if started || !next.playing { reveal() }
        default: break
        }
    }

    /// 唤出控制条；播放中且开启自动隐藏时 6 秒无操作后收起，与原版控制条习惯一致。
    func reveal() {
        barVisible = true
        hideTask?.cancel()
        guard state.playing, state.autoHide else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled, let self, self.state.playing, self.state.autoHide else { return }
            self.barVisible = false
        }
    }

    // MARK: 锁屏 / 控制中心

    private func installRemoteCommands() {
        guard !commandsInstalled else { return }
        commandsInstalled = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.send?("play", nil); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.send?("pause", nil); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.send?("toggle", nil); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.send?("next", nil); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.send?("prev", nil); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.send?("seek", event.positionTime); return .success
        }
    }

    private func updateSystemNowPlaying(trackChanged: Bool) {
        let center = MPNowPlayingInfoCenter.default()
        guard state.hasSong else { center.nowPlayingInfo = nil; return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: state.title.isEmpty ? "Mineradio" : state.title,
                                   MPMediaItemPropertyArtist: state.artist,
                                   MPNowPlayingInfoPropertyElapsedPlaybackTime: state.current,
                                   MPNowPlayingInfoPropertyPlaybackRate: state.playing ? 1.0 : 0.0]
        if state.duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = state.duration }
        if let artwork, artworkURL == state.cover { info[MPMediaItemPropertyArtwork] = artwork }
        center.nowPlayingInfo = info
        center.playbackState = state.playing ? .playing : .paused
        if trackChanged { loadArtwork(state.cover) }
    }

    private func loadArtwork(_ link: String) {
        artworkURL = link; artwork = nil
        guard let url = URL(string: link), url.scheme == "https" else { return }
        Task { [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200, data.count < 4 * 1024 * 1024,
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                guard let self, self.artworkURL == link else { return }
                self.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateSystemNowPlaying(trackChanged: false)
            }
        }
    }
}
