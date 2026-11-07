import SwiftUI

/// iPhone 原生播放控制条（IOS_PLAN 阶段 C）。
/// 三行布局：歌曲信息 / 细进度条 / 播放控制。歌名始终有独立的一整行，不会被按钮挤掉。
/// 所有动作都转给原版播放器函数执行，播放逻辑仍与桌面同源。
struct NativeControlBar: View {
    @ObservedObject var model: NowPlayingModel
    @State private var scrubbing = false
    @State private var scrubValue = 0.0

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var state: NowPlayingModel.State { model.state }
    /// iPad（横竖屏）与 iPhone 横屏宽度足够，用单行布局；iPhone 竖屏用三行。
    private var wide: Bool { verticalSizeClass == .compact || horizontalSizeClass == .regular }
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        Group {
            if wide {
                GeometryReader { geometry in
                    if geometry.size.width >= (isPad ? 850 : 700) {
                        landscapeBar
                    } else {
                        compactLandscapeBar
                    }
                }
                .frame(height: isPad ? 84 : 68)
            } else { portraitBar }
        }
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.1)))
        .environment(\.colorScheme, .dark)
        .onDisappear {
            scrubbing = false
            model.setInteracting(false)
        }
    }

    /// 横屏：单行 64pt，不遮挡舞台；进度条在中间占剩余宽度。
    private var landscapeBar: some View {
        HStack(spacing: 10) {
            Button { model.command("detail") } label: {
                HStack(spacing: 10) {
                    cover
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.title.isEmpty ? "未在播放" : state.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text(state.trial ? "试听片段 · " + state.artist : state.artist)
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                    }
                    .frame(width: isPad ? 260 : 150, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("歌曲详情：\(state.title) \(state.artist)")
            progress.frame(minWidth: 120)
            control("backward.fill", "上一首", size: 17) { model.command("prev") }
            playButton(size: 44)
            control("forward.fill", "下一首", size: 17) { model.command("next") }
            control(state.liked ? "heart.fill" : "heart", "红心喜欢", size: 17, tint: state.liked ? Color(red: 1, green: 0.36, blue: 0.48) : .white) { model.command("like") }
            if state.immersive { control("arrow.down.right.and.arrow.up.left", "退出沉浸模式", size: 17) { model.command("immersive") } }
            else { control("music.note.list", "歌单与播放队列", size: 17) { model.command("library") } }
            moreMenu
        }
        .padding(.horizontal, isPad ? 18 : 12).padding(.vertical, isPad ? 10 : 6)
    }

    /// Narrow landscape and iPad split windows keep playback accessible without
    /// squeezing fixed-width controls outside the available safe area.
    private var compactLandscapeBar: some View {
        HStack(spacing: 10) {
            cover
            VStack(alignment: .leading, spacing: 2) {
                Button { model.command("detail") } label: {
                    Text(state.title.isEmpty ? "未在播放" : state.title)
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                progress
            }
            .frame(minWidth: 80)
            playButton(size: 44)
            control("forward.fill", "下一首", size: 17) { model.command("next") }
            moreMenu
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func playButton(size: CGFloat) -> some View {
        Button { model.command("toggle") } label: {
            Image(systemName: state.playing ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.black)
                .frame(width: size, height: size).background(Circle().fill(.white))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.playing ? "暂停" : "播放")
    }

    private var moreMenu: some View {
        Menu {
            Button { model.command("prev") } label: { Label("上一首", systemImage: "backward.fill") }
            Button { model.command("like") } label: { Label(state.liked ? "取消喜欢" : "红心喜欢", systemImage: state.liked ? "heart.fill" : "heart") }
            Button { model.command("library") } label: { Label("歌单与播放队列", systemImage: "music.note.list") }
            Button { model.command("lyrics") } label: { Label("歌词", systemImage: "quote.bubble") }
            Button { model.command("mode") } label: { Label("切换播放顺序", systemImage: "repeat") }
            Button { model.command("immersive") } label: {
                Label(state.immersive ? "退出沉浸模式" : "沉浸模式（点画面唤出控制条）",
                      systemImage: state.immersive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            Button { model.command("webBar", true) } label: { Label("音质、音量与更多", systemImage: "slider.horizontal.3") }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("更多播放设置")
    }

    private var portraitBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button { model.command("detail") } label: {
                    HStack(spacing: 12) {
                        cover
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.title.isEmpty ? "未在播放" : state.title)
                                .font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            Text(state.trial ? "试听片段 · " + state.artist : state.artist)
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("歌曲详情：\(state.title) \(state.artist)")
                control(state.liked ? "heart.fill" : "heart", "红心喜欢", size: 18, tint: state.liked ? Color(red: 1, green: 0.36, blue: 0.48) : .white) { model.command("like") }
            }
            progress
            HStack(spacing: 0) {
                if state.immersive { control("arrow.down.right.and.arrow.up.left", "退出沉浸模式", size: 18) { model.command("immersive") } }
                else { control("music.note.list", "歌单与播放队列", size: 18) { model.command("library") } }
                Spacer(minLength: 4)
                control("backward.fill", "上一首", size: 20) { model.command("prev") }
                Spacer(minLength: 4)
                playButton(size: 52)
                Spacer(minLength: 4)
                control("forward.fill", "下一首", size: 20) { model.command("next") }
                Spacer(minLength: 4)
                moreMenu
            }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
    }

    private var cover: some View {
        Group {
            if let image = model.coverImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.08))
            }
        }
        .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityHidden(true)
    }

    /// 细进度条：4pt 轨道，拖动时变粗；整行 28pt 高都可以拖，方便手指操作。
    private var progress: some View {
        let duration = max(state.duration, 0)
        let value = scrubbing ? scrubValue : min(state.current, duration)
        let fraction = duration > 0 ? value / duration : 0
        return VStack(spacing: 3) {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(.white.opacity(0.9)).frame(width: width * fraction)
                }
                .frame(height: scrubbing ? 7 : 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard duration > 0 else { return }
                        if !scrubbing { model.setInteracting(true) }
                        scrubbing = true
                        scrubValue = min(max(drag.location.x / width, 0), 1) * duration
                    }
                    .onEnded { _ in
                        guard scrubbing else { return }
                        scrubbing = false
                        model.setInteracting(false)
                        model.command("seek", scrubValue)
                    })
                .animation(.easeOut(duration: 0.15), value: scrubbing)
            }
            .frame(height: 20)
            HStack {
                Text(Self.time(value)); Spacer(); Text(Self.time(duration))
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit()).foregroundStyle(.white.opacity(0.5))
        }
        .accessibilityElement()
        .accessibilityLabel("播放进度")
        .accessibilityValue("\(Self.time(value))，共 \(Self.time(duration))")
        .accessibilityAdjustableAction { direction in
            guard duration > 0 else { return }
            let step = direction == .increment ? 10.0 : -10.0
            model.command("seek", min(max(value + step, 0), duration))
        }
    }

    private func control(_ symbol: String, _ label: String, size: CGFloat = 17, tint: Color = .white,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
