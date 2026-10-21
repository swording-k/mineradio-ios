import Foundation
import Network
import Combine
import WebKit
import UniformTypeIdentifiers

/// App-owned loopback service. Never listens on the LAN or sends account cookies
/// to a remote server controlled by the app developer.
@MainActor final class AppleLocalService: ObservableObject {
    @Published private(set) var origin: URL?
    @Published private(set) var failure: String?
    let sessionToken = UUID().uuidString
    private var listener: NWListener?
    private let api = NeteaseNativeAPI()
    private let media = NeteaseMediaStream()
    private let qq = QQMusicNativeAPI()
    private let kugou = KugouNativeAPI()
    private let qishuiCatalog = QishuiCatalogAPI()
    @Published private(set) var securityWebView: WKWebView?
    private lazy var qishui: QishuiAuthRuntime = {
        let runtime = QishuiAuthRuntime(bridge: Bundle.main.resourceURL?.appendingPathComponent("Web/qishui-xhr-bridge.js"))
        runtime.presentSecurity = { [weak self] web in self?.securityWebView = web }
        return runtime
    }()
    func cancelSecurity() { qishui.cancelSecurity() }
    private let resourceRoot: URL?
    private let generatedRoot: URL?
    private var active: [UUID: NWConnection] = [:]
    private var jobs: [UUID: Task<Void, Never>] = [:]
    private var port: UInt16

    init(resourceRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("public"),
         generatedRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("GeneratedWeb"), port: UInt16? = nil) {
        #if targetEnvironment(simulator)
        self.port = port ?? 0
        #else
        self.port = port ?? 19363
        #endif
        self.resourceRoot = resourceRoot
        self.generatedRoot = generatedRoot
    }

    func importAccount(_ provider: String, cookies: [HTTPCookie]) async throws -> [String: Any] {
        switch provider {
        case "qq": return try await qq.setSession(cookies)
        case "kugou":
            try await kugou.setSession(cookies)
            return try await kugou.handle(URL(string: "http://127.0.0.1:\(port)/api/kugou/login/status")!, method: "GET", body: Data())
        default: return ["loggedIn": false, "message": "此平台不使用官方网页会话导入。"]
        }
    }
    private func qishuiAPI(_ url: URL, method: String, body: Data) async throws -> [String: Any] {
        switch url.path {
        case "/api/qishui/login/qrcode": return try await qishui.createQrCode()
        case "/api/qishui/login/check":
            let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "token" }?.value ?? ""
            var status = try await qishui.checkQrCode(token)
            if QishuiAuthContract.mayValidateAccount(status) {
                await qishuiCatalog.setSession(qishui.sessionSnapshot())
                let verified = await qishuiCatalog.validateAccount()
                if verified["loggedIn"] as? Bool == true {
                    status.merge(verified) { _, new in new }; status["status"] = "confirmed"
                    qishui.releaseSigningEnvironment()
                } else if verified["reauthRequired"] as? Bool == true {
                    status["status"] = "reauth_required"; status["reauthRequired"] = true
                }
            }
            if status["status"] as? String == "mfa_required" { qishui.releaseSigningEnvironment() }
            return status
        case "/api/qishui/logout":
            _ = try await qishui.logout(); await qishuiCatalog.setSession([:])
            return ["ok": true, "provider": "qishui", "loggedIn": false]
        default:
            await qishuiCatalog.setSession(qishui.sessionSnapshot())
            return try await qishuiCatalog.handle(url, method: method, body: body)
        }
    }
    func start() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    if case .ready = state, let port = self.listener?.port?.rawValue {
                        self.port = port; self.origin = URL(string: "http://127.0.0.1:\(port)")
                    }
                    if case .failed = state { self.failure = "无法启动设备内的音乐服务，请退出 App 后重试。" }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: .main)
        } catch { failure = "无法启动设备内的音乐服务：" + error.localizedDescription }
    }

    private func accept(_ connection: NWConnection) {
        guard active.count < 32 else { connection.cancel(); return }
        let id = UUID()
        active[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { Task { @MainActor in self?.active[id] = nil; self?.jobs.removeValue(forKey: id)?.cancel() } }
        }
        connection.start(queue: .main)
        receive(connection, id: id, collected: Data())
    }

    private func receive(_ connection: NWConnection, id: UUID, collected: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                var buffer = collected
                buffer.append(data ?? Data())
                guard buffer.count <= 1024 * 1024, error == nil else { connection.cancel(); return }
                if let split = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    guard split.lowerBound < 16384,
                          let text = String(data: buffer[..<split.lowerBound], encoding: .utf8) else { connection.cancel(); return }
                    let lines = text.components(separatedBy: "\r\n")
                    let first = (lines.first ?? "").split(separator: " ")
                    guard first.count == 3, ["GET", "POST", "HEAD"].contains(String(first[0])),
                          first[1].hasPrefix("/"), !first[1].hasPrefix("//") else { connection.cancel(); return }
                    var headers: [String: String] = [:]
                    for line in lines.dropFirst() {
                        if let colon = line.firstIndex(of: ":") {
                            let key = line[..<colon].lowercased()
                            guard headers[key] == nil else { connection.cancel(); return }
                            headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                        }
                    }
                    guard headers["transfer-encoding"] == nil,
                          headers["host"] == "127.0.0.1:\(self.port)",
                          headers["origin"] == nil || headers["origin"] == self.origin?.absoluteString else { connection.cancel(); return }
                    let length = Int(headers["content-length"] ?? "0") ?? -1
                    guard (0...1048576).contains(length) else { connection.cancel(); return }
                    if buffer.count - split.upperBound >= length {
                        let body = Data(buffer[split.upperBound..<split.upperBound + length])
                        let url = URL(string: "http://127.0.0.1:\(self.port)\(first[1])")!
                        let method = String(first[0])
                        self.jobs[id] = Task { [weak self] in
                            guard let self else { return }
                            await self.respond(connection, url: url, method: method, headers: headers, body: body)
                            self.jobs[id] = nil
                        }
                        return
                    }
                }
                if complete { connection.cancel() }
                else { self.receive(connection, id: id, collected: buffer) }
            }
        }
    }

    private func respond(_ connection: NWConnection, url: URL, method: String, headers: [String: String], body: Data) async {
        do {
            if url.path == "/api/audio" || url.path == "/api/cover" {
                let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "url" }?.value ?? ""
                guard var target = URL(string: text), AppleMediaPolicy.allowed(target) else {
                    send(connection, status: 403, type: "application/json", data: Data("{\"error\":\"MEDIA_HOST_NOT_ALLOWED\"}".utf8)); return
                }
                // Upgrade CDN HTTP links before leaving the device.
                if target.scheme == "http" { var c = URLComponents(url: target, resolvingAgainstBaseURL: false)!; c.scheme = "https"; if c.port == 80 { c.port = nil }; target = c.url! }
                var request = URLRequest(url: target, timeoutInterval: 20)
                request.httpMethod = method
                request.setValue(AppleMediaPolicy.referer(target), forHTTPHeaderField: "Referer")
                if let range = headers["range"] { request.setValue(range, forHTTPHeaderField: "Range") }
                // If the client disconnects or the source fails after headers,
                // close the stream rather than append a second HTTP response.
                do {
                    try await media.transfer(request) { chunk in try await Self.write(chunk, to: connection) }
                } catch { /* The player observes the incomplete response and may retry. */ }
                connection.cancel()
            } else if url.path.hasPrefix("/api/") {
                guard headers["x-mineradio-session"] == sessionToken else {
                    send(connection, status: 403, type: "application/json", data: Data("{\"error\":\"LOCAL_SESSION_REQUIRED\"}".utf8)); return
                }
                let result: [String: Any]
                if url.path.hasPrefix("/api/qq/") { result = try await qq.handle(url, method: method, body: body) }
                else if url.path.hasPrefix("/api/kugou/") { result = try await kugou.handle(url, method: method, body: body) }
                else if url.path.hasPrefix("/api/qishui/") { result = try await qishuiAPI(url, method: method, body: body) }
                else { result = try await api.handle(url, method: method, body: body) }
                send(connection, status: 200, type: "application/json", data: try JSONSerialization.data(withJSONObject: result))
            } else {
                guard method == "GET", let root = resourceRoot else { throw URLError(.fileDoesNotExist) }
                let relative = url.path == "/" ? "index.html" : String(url.path.dropFirst())
                let file = root.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
                guard file.path.hasPrefix(root.standardizedFileURL.resolvingSymlinksInPath().path + "/") else { throw URLError(.noPermissionsToReadFile) }
                // Same ordered source as index-loader, served in one request on Apple.
                let source = url.path == "/js/index-loader.js" ? generatedRoot?.appendingPathComponent("index-modules.js") ?? file : file
                let data = try Data(contentsOf: source)
                let type = file.pathExtension == "js" ? "application/javascript" : (UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream")
                send(connection, status: 200, type: type, data: data)
            }
        } catch {
            let result = ["ok": false, "error": "APPLE_NATIVE_REQUEST_FAILED", "message": error.localizedDescription] as [String: Any]
            send(connection, status: 502, type: "application/json", data: (try? JSONSerialization.data(withJSONObject: result)) ?? Data())
        }
    }

    private nonisolated static func write(_ data: Data, to connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    private func send(_ connection: NWConnection, status: Int, type: String, data: Data, extra: [String: String] = [:]) {
        var head = "HTTP/1.1 \(status) Response\r\nContent-Type: \(type)\r\nContent-Length: \(data.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n"
        for (key, value) in extra { head += "\(key): \(value)\r\n" }
        var packet = Data((head + "\r\n").utf8)
        packet.append(data)
        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }
}

