import Foundation
import Security

protocol KugouRequesting: Actor { func request(_ request: URLRequest) async throws -> [String: Any] }
actor KugouHTTPTransport: KugouRequesting {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.timeoutIntervalForRequest = 12; config.timeoutIntervalForResource = 20
        session = URLSession(configuration: config, delegate: KugouRedirectGuard(), delegateQueue: nil)
    }
    func request(_ request: URLRequest) async throws -> [String: Any] {
        guard let url = request.url, KugouContract.allowedAPI(url), ["GET", "POST"].contains(request.httpMethod ?? "GET") else { throw KugouFailure.requestDenied }
        let (bytes, response) = try await session.data(for: request)
        guard bytes.count <= 4 * 1024 * 1024, let http = response as? HTTPURLResponse, let final = http.url, KugouContract.allowedAPI(final),
              (200..<300).contains(http.statusCode), let value = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw KugouFailure.invalidResponse }
        return value
    }
}
private final class KugouRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Session cookies must never be redirected to a different service.
        completionHandler(nil)
    }
}
enum KugouFailure: LocalizedError {
    case requestDenied, invalidResponse, keychain, sessionChanged, invalidInput
    var errorDescription: String? {
        switch self {
        case .requestDenied: return "酷狗请求地址不在允许的接口范围内。"
        case .invalidResponse: return "酷狗接口暂未返回有效数据。"
        case .keychain: return "酷狗会话无法安全保存。"
        case .sessionChanged: return "酷狗账号已切换，请重试。"
        case .invalidInput: return "酷狗请求参数不完整。"
        }
    }
}
struct KugouSessionStore {
    let service: String
    func load() -> [String: String] {
        var value: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session", kSecReturnData as String: true]
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let bytes = value as? Data else { return [:] }
        return (try? JSONSerialization.jsonObject(with: bytes) as? [String: String]) ?? [:]
    }
    func save(_ values: [String: String]) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        if values.isEmpty { let result = SecItemDelete(query as CFDictionary); guard result == errSecSuccess || result == errSecItemNotFound else { throw KugouFailure.keychain }; return }
        let data = try JSONSerialization.data(withJSONObject: values)
        let result = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if result == errSecItemNotFound {
            var insert = query; insert[kSecValueData as String] = data; insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw KugouFailure.keychain }
        } else if result != errSecSuccess { throw KugouFailure.keychain }
    }
}
