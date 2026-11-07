#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Exercise the real SwiftUI controls without accounts, network or WebGL load.
struct NativeControlsSmoke: View {
    @StateObject private var model = NowPlayingModel(systemIntegration: false)
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Button("唤出原生控制条") { model.reveal() }
                .foregroundStyle(.white)
            VStack {
                Text(model.barVisible ? "原生控制条已展开" : "原生控制条已收起")
                    .foregroundStyle(.white).padding(.top, 10)
                Spacer()
                if model.showsBar && model.barVisible {
                    NativeControlBar(model: model).padding(.horizontal, 10).padding(.bottom, 4)
                }
            }
        }
        .onAppear {
            model.send = { command, _ in
                if command == "toggle" {
                    model.receive(["type": "state", "state": ["hasSong": true, "playing": false, "autoHide": true,
                        "title": "长歌曲名称与歌手信息在小屏幕上也能使用", "artist": "测试歌手", "duration": 300, "current": 60]])
                }
            }
            model.receive(["type": "state", "state": ["hasSong": true, "playing": true, "autoHide": true,
                "title": "长歌曲名称与歌手信息在小屏幕上也能使用", "artist": "测试歌手", "duration": 300, "current": 60]])
        }
    }
}
#endif
