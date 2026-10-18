import Foundation
import WebKit
import UniformTypeIdentifiers

/// Serves the original public/ folder without modifying or duplicating its source.
/// API routes have no implementation in offline preview and explicitly return 503.
final class BundledPlayerHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let root = Bundle.main.resourceURL?.appendingPathComponent("public", isDirectory: true) else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let relative = url.path == "/" ? "index.html" : String(url.path.dropFirst())
        let file = root.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
        let safeRoot = root.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        guard file.path.hasPrefix(safeRoot) else {
            task.didFailWithError(URLError(.noPermissionsToReadFile)); return
        }
        if let data = try? Data(contentsOf: file) {
            let mime: String
            switch file.pathExtension.lowercased() {
            case "js": mime = "application/javascript"
            case "css": mime = "text/css"
            case "html": mime = "text/html"
            case "json": mime = "application/json"
            case "wasm": mime = "application/wasm"
            default: mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            }
            respond(task, url: url, status: 200, mime: mime, data: data)
        } else {
            let data = Data("{\"code\":503,\"error\":\"APPLE_OFFLINE_PREVIEW\",\"message\":\"离线预览没有音乐平台接口，请连接开发服务。\"}".utf8)
            respond(task, url: url, status: 503, mime: "application/json", data: data)
        }
    }

    private func respond(_ task: WKURLSchemeTask, url: URL, status: Int, mime: String, data: Data) {
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": mime, "Access-Control-Allow-Origin": "*", "Cache-Control": "no-store"
        ]) else { task.didFailWithError(URLError(.badServerResponse)); return }
        task.didReceive(response); task.didReceive(data); task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
