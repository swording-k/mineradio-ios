import SwiftUI
import WebKit

private struct SecurityWebView: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> WKWebView { web.removeFromSuperview(); return web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
struct QishuiSecuritySheet: View {
    let web: WKWebView?
    let cancel: () -> Void
    var body: some View {
        NavigationStack {
            Group {
                if let web { SecurityWebView(web: web) }
                else { ProgressView() }
            }
            .navigationTitle("汽水音乐安全验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消", action: cancel) } }
        }.interactiveDismissDisabled()
    }
}
