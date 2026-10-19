import SwiftUI

struct PlayerHost: View {
    @StateObject private var service = AppleLocalService()
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
                OriginalPlayerView(endpoint: endpoint, failure: $failure, sessionToken: service.sessionToken).id(revision)
                    .ignoresSafeArea(edges: .bottom)
                #if DEBUG
                Button { draft = storedOrigin; showConnection = true } label: {
                    Image(systemName: "network").padding(12).background(.ultraThinMaterial, in: Circle())
                }.padding(8).accessibilityLabel("开发连接设置")
                #endif
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
                VStack(spacing: 16) {
                    ProgressView()
                    Text(service.failure ?? "正在启动本机音乐服务…")
                    if service.failure != nil { Button("重试") { service.start() } }
                }
            }
        }
        .sheet(isPresented: $showConnection) { connectionForm }
        .onAppear {
            draft = storedOrigin
            service.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--offline-preview") {
                endpoint = URL(string: "mineradio-app://player/index.html")
            }
            #endif
        }
        .onReceive(service.$origin) { origin in
            if let origin { endpoint = origin; failure = nil }
        }
    }

    private var connectionForm: some View {
        NavigationStack {
            Form {
                Section("原版网页 · Apple 开发预览") {
                    Text("正常使用会自动连接 App 内置的网易云服务。此处仅供开发调试，平台功能仍需逐项验证。")
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
