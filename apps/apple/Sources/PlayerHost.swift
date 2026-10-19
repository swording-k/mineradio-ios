import SwiftUI

struct PlayerHost: View {
    @AppStorage("apple-development-origin") private var storedOrigin = ""
    @State private var draft = ""
    @State private var endpoint: URL?
    @State private var showConnection = false
    @State private var failure: String?
    @State private var revision = UUID()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let endpoint {
                OriginalPlayerView(endpoint: endpoint, failure: $failure).id(revision)
                    .ignoresSafeArea(edges: .bottom)
                Button { draft = storedOrigin; showConnection = true } label: {
                    Image(systemName: "network").padding(12).background(.ultraThinMaterial, in: Circle())
                }.padding(8).accessibilityLabel("开发连接设置")
                if let failure {
                    VStack(spacing: 16) {
                        Text("未能加载原版播放器").font(.headline)
                        Text(failure).font(.footnote).multilineTextAlignment(.center)
                        Button("重试") { self.failure = nil; revision = UUID() }
                        Button("修改服务地址") { draft = storedOrigin; showConnection = true }
                    }.padding(28).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .frame(maxWidth: 440).frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                }
            } else {
                connectionForm
            }
        }
        .sheet(isPresented: $showConnection) { connectionForm }
        .onAppear {
            draft = storedOrigin
            endpoint = EndpointPolicy.parse(storedOrigin)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--offline-preview") {
                endpoint = URL(string: "mineradio-app://player/index.html")
            }
            #endif
        }
    }

    private var connectionForm: some View {
        NavigationStack {
            Form {
                Section("原版网页 · Apple 开发预览") {
                    Text("直接运行现有 Mineradio 页面和动效。这一阶段需要连接你自己的开发服务，尚非独立运行的移动客户端。")
                    TextField("https://你的服务地址", text: $draft)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("连接播放器") {
                        guard let url = EndpointPolicy.parse(draft) else { return }
                        storedOrigin = url.absoluteString
                        endpoint = url; failure = nil; revision = UUID(); showConnection = false
                    }.disabled(EndpointPolicy.parse(draft) == nil)
                    Button("打开内置原版界面（离线预览）") {
                        endpoint = URL(string: "mineradio-app://player/index.html")
                        failure = nil; revision = UUID(); showConnection = false
                    }
                    Text("内置界面直接使用仓库 public 目录。离线模式不提供音乐平台服务；不会显示虚构的歌单或登录成功状态。")
                        .font(.footnote)
                }
                Section("连接说明") {
                    Text("iPad 真机填写同一局域网内 Mac 的地址，例如 http://192.168.1.20:3000。模拟器可填写 http://127.0.0.1:3000。请使用独立测试服务与测试账号。")
                    Text("基于 Mineradio 开源项目，遵循 GPL-3.0-only。此预览不改变原项目品牌，不代表官方 Apple 版本。")
                }
            }.navigationTitle("Mineradio")
        }
    }
}
