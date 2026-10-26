import SwiftUI

/// iPhone 原生播放控制条（IOS_PLAN 阶段 C）。
/// 取代网页底部控制条：按钮由 SwiftUI 布局，按安全区自动对齐，44pt 触控目标。
/// 所有动作都转给原版播放器函数执行，播放逻辑仍与桌面同源。
struct NativeControlBar: View {
    @ObservedObject var model: NowPlayingModel
    @State private var scrubbing = false
    @State private var scrubValue = 0.0

    private var state: NowPlayingModel.State { model.state }

    var body: some View {
        VStack(spacing: 6) {
            progress
            HStack(spacing: 10) {
                Button { model.command("detail") } label: {
                    HStack(spacing: 10) {
                        cover
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.title.isEmpty ? "未在播放" : state.title)
                                .font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(state.trial ? "试听片段 · " + state.artist : state.artist)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("歌曲详情：\(state.title) \(state.artist)")

                control(state.liked ? "heart.fill" : "heart", "红心喜欢", tint: state.liked ? .pink : .primary) { model.command("like") }
                control("backward.fill", "上一首") { model.command("prev") }
                control(state.playing ? "pause.fill" : "play.fill", state.playing ? "暂停" : "播放", size: 22) { model.command("toggle") }
                control("forward.fill", "下一首") { model.command("next") }
                control("music.note.list", "歌单与播放队列") { model.command("library") }
                Menu {
                    Button { model.command("lyrics") } label: { Label("歌词", systemImage: "quote.bubble") }
                    Button { model.command("mode") } label: { Label("切换播放顺序", systemImage: "repeat") }
                    Button { model.command("immersive") } label: { Label("沉浸模式", systemImage: "arrow.up.left.and.arrow.down.right") }
                    Button { model.command("webBar", true) } label: { Label("音质、音量与更多", systemImage: "slider.horizontal.3") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("更多播放设置")
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.08)))
        .environment(\.colorScheme, .dark)
    }

    private var cover: some View {
        AsyncImage(url: URL(string: state.cover)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "music.note").foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(0.06))
        }
        .frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private var progress: some View {
        let duration = max(state.duration, 0)
        let value = scrubbing ? scrubValue : min(state.current, duration)
        return HStack(spacing: 8) {
            Text(Self.time(value)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            Slider(value: Binding(get: { value }, set: { scrubValue = $0 }), in: 0...max(duration, 1)) { editing in
                if editing { scrubValue = value; scrubbing = true }
                else { scrubbing = false; model.command("seek", scrubValue) }
            }
            .disabled(duration <= 0)
            .tint(.white)
            .accessibilityLabel("播放进度")
            Text(Self.time(duration)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func control(_ symbol: String, _ label: String, size: CGFloat = 17, tint: Color = .primary,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 40, height: 44).contentShape(Rectangle())
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
