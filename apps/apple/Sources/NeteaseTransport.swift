import Foundation
import Security

protocol NeteaseRequesting: Actor {
    func call(_ path: String, _ fields: [String: Any]) async throws -> [String: Any]
    func clear() async throws
}

actor NeteaseTransport: NeteaseRequesting {
    private let session: URLSession
    private let service: String
    private var cookies: [String: String]
    private let deviceID: String

    init(service: String = "com.swordingk.mineradio.netease") {
        self.service = service
        var saved: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "session",
            kSecReturnData as String: true]
        if SecItemCopyMatching(query as CFDictionary, &saved) == errSecSuccess,
           let data = saved as? Data,
           let value = try? JSONSerialization.jsonObject(with: data) as? [String: String] { cookies = value }
        else { cookies = [:] }
        let key = "apple-netease-device-id"
        deviceID = UserDefaults.standard.string(forKey: key) ?? UUID().uuidString
        UserDefaults.standard.set(deviceID, forKey: key)
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        session = URLSession(configuration: config, delegate: NeteaseRequestGuard(), delegateQueue: nil)
    }

    func clear() throws {
        cookies = [:]
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "session"] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TransportError.keychain }
    }

    func call(_ path: String, _ fields: [String: Any] = [:]) async throws -> [String: Any] {
        guard path.hasPrefix("/api/"), !path.contains(".."), !path.contains("?") else { throw TransportError.invalidRequest }
        var header: [String: Any] = ["os": "iPhone OS", "osver": "17.0", "appver": "9.0.90",
            "deviceId": deviceID, "versioncode": "140", "channel": "distribution",
            "__csrf": cookies["__csrf"] ?? "", "requestId": "\(Int(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 1000...9999))"]
        for (key, value) in cookies { header[key] = value }
        let useWeb = ["/api/w/nuser/account/get", "/api/user/playlist", "/api/v3/discovery/recommend/songs", "/api/personalized/playlist"].contains(path)
        var payload = fields
        if useWeb { payload["csrf_token"] = cookies["__csrf"] ?? "" }
        else { payload["header"] = header }
        payload["e_r"] = false
        let json = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
        let text = String(decoding: json, as: UTF8.self)
        let encoded = useWeb ? try NeteaseEAPI.weapi(json: text) : ["params": try NeteaseEAPI.encrypt(path: path, json: text)]
        let url = URL(string: (useWeb ? "https://music.163.com/weapi/" : "https://interface.music.163.com/eapi/") + path.dropFirst(5))!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("NeteaseMusic/9.0.90 (iPhone; iOS 17.0)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        let cookieAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: ";=+&\r\n"))
        request.setValue(header.map { key, value in
            "\(key)=\(String(describing: value).addingPercentEncoding(withAllowedCharacters: cookieAllowed) ?? "")"
        }.sorted().joined(separator: "; "), forHTTPHeaderField: "Cookie")
        let formAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.httpBody = Data(encoded.sorted { $0.key < $1.key }.map {
            "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: formAllowed)!)"
        }.joined(separator: "&").utf8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              ["interface.music.163.com", "music.163.com"].contains(http.url?.host ?? ""), (200...299).contains(http.statusCode),
              let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TransportError.invalidResponse }
        let responseHeaders = http.allHeaderFields.reduce(into: [String: String]()) { value, item in
            value[String(describing: item.key)] = String(describing: item.value)
        }
        var changed = false
        for cookie in HTTPCookie.cookies(withResponseHeaderFields: responseHeaders, for: url)
        where ["MUSIC_U", "MUSIC_A", "__csrf"].contains(cookie.name) {
            cookies[cookie.name] = cookie.value
            changed = true
        }
        if changed { try persist() }
        return body
    }

    private func persist() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        let data = try JSONSerialization.data(withJSONObject: cookies)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var entry = query
            entry[kSecValueData as String] = data
            entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(entry as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw TransportError.keychain }
    }

    enum TransportError: LocalizedError {
        case invalidRequest, invalidResponse, keychain
        var errorDescription: String? {
            switch self {
            case .invalidRequest: return "网易云请求参数无效。"
            case .invalidResponse: return "网易云没有返回有效响应，请稍后重试。"
            case .keychain: return "无法在此设备的钥匙串保存登录状态。"
            }
        }
    }
}

private final class NeteaseRequestGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let allowed = request.url?.scheme == "https" && ["music.163.com", "interface.music.163.com"].contains(request.url?.host ?? "")
        completionHandler(allowed ? request : nil)
    }
}
