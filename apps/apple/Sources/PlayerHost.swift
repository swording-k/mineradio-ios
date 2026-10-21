import SwiftUI

struct PlayerHost: View {
    @StateObject private var service = AppleLocalService()
    @StateObject private var officialLogin = OfficialAccountLogin()
    @State private var endpoint: URL?
    @State private var failure: String?
    @State private var revision = UUID()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let endpoint {
                OriginalPlayerView(endpoint: endpoint, failure: $failure, sessionToken: service.sessionToken, accountPresented: officialLogin.ticket != nil, openAccount: { provider in
                    await officialLogin.open(provider) { platform, cookies in try await service.importAccount(platform, cookies: cookies) }
                }).id(revision)
                    .ignoresSafeArea(edges: .bottom)

                if let failure {
                    VStack(spacing: 16) {
                        Text("未能加载原版播放器").font(.headline)
                        Text(failure).font(.footnote).multilineTextAlignment(.center)
                        Button("重试") { self.failure = nil; revision = UUID() }
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
        .fullScreenCover(isPresented: Binding(get: { officialLogin.ticket != nil }, set: { if !$0 { officialLogin.cancel() } })) {
            OfficialAccountLoginSheet(login: officialLogin)
        }
        .onAppear {
            service.start()
            #if DEBUG && targetEnvironment(simulator)
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--apple-official-login-smoke"),
               ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
                let provider = ProcessInfo.processInfo.arguments[index + 1]
                Task { @MainActor in
                    _ = await officialLogin.open(provider) { platform, cookies in try await service.importAccount(platform, cookies: cookies) }
                }
            }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--qishui-smoke") {
                Task { @MainActor in
                    let runtime = QishuiAuthRuntime(bridge: Bundle.main.resourceURL?.appendingPathComponent("Web/qishui-xhr-bridge.js"))
                    let result: [String: Any]
                    do {
                        let qr = try await runtime.createQrCode()
                        result = ["qrAvailable": !(qr["qrcode"] as? String ?? "").isEmpty,
                                  "tokenAvailable": !(qr["token"] as? String ?? "").isEmpty]
                    } catch { result = ["qrAvailable": false, "error": error.localizedDescription, "diagnostics": runtime.diagnostics, "jsMessage": (error as NSError).userInfo["WKJavaScriptExceptionMessage"] as? String ?? ""] }
                    if let data = try? JSONSerialization.data(withJSONObject: result),
                       let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        try? data.write(to: directory.appendingPathComponent("qishui-smoke.json"))
                    }
                }
            }
            if ProcessInfo.processInfo.arguments.contains("--offline-preview") {
                endpoint = URL(string: "mineradio-app://player/index.html")
            }
            #endif
        }
        .onReceive(service.$origin) { origin in
            if let origin { endpoint = origin; failure = nil }
        }
    }

}
