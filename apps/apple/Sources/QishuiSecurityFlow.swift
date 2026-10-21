import Foundation

/// Matches the desktop Passport flow: one official challenge, one resend.
/// The verifier must represent actual user completion, never cookie presence.
enum QishuiSecurityFlow {
    enum Failure: LocalizedError {
        case cancelled, repeated, invalidParameters
        var errorDescription: String? {
            switch self {
            case .cancelled: return "汽水安全验证未完成，请重新扫码。"
            case .repeated: return "汽水仍要求安全验证，请刷新二维码后重试。"
            case .invalidParameters: return "汽水安全验证参数格式无效。"
            }
        }
    }
    @MainActor static func run(poll: ([String: String]?) async throws -> [String: Any],
                               verify: ([String: Any]) async throws -> Bool) async throws -> [String: Any] {
        let first = try await poll(nil)
        guard code(first) == 2046 else { return first }
        var decision = first
        if let data = first["data"] as? [String: Any] { decision.merge(data) { _, new in new } }
        decision.removeValue(forKey: "data")
        let retry = try parameters(decision["biz_params"])
        guard try await verify(decision) else { throw Failure.cancelled }
        try Task.checkCancellation()
        let result = try await poll(retry)
        guard code(result) != 2046 else { throw Failure.repeated }
        return result
    }
    private static func code(_ envelope: [String: Any]) -> Int {
        let data = envelope["data"] as? [String: Any] ?? envelope
        return (data["error_code"] as? NSNumber)?.intValue ?? -1
    }
    private static func parameters(_ raw: Any?) throws -> [String: String] {
        guard let raw, !(raw is NSNull) else { return [:] }
        var object: Any = raw
        if let string = raw as? String {
            if let data = string.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) { object = json }
            else {
                let fields = string.split(separator: "&").map { $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false) }
                var result: [String: String] = [:]
                for field in fields {
                    func decode(_ value: Substring) -> String { String(value).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(value) }
                    result[decode(field[0])] = field.count == 2 ? decode(field[1]) : ""
                }
                return result
            }
        }
        guard let dictionary = object as? [String: Any] else { throw Failure.invalidParameters }
        var result: [String: String] = [:]
        for (key, value) in dictionary where !(value is NSNull) {
            if let value = value as? String { result[key] = value }
            else if let value = value as? NSNumber { result[key] = value.stringValue }
            else if JSONSerialization.isValidJSONObject(value) {
                result[key] = String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self)
            } else { throw Failure.invalidParameters }
        }
        return result
    }
}
