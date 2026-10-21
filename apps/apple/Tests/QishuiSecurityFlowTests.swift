import Foundation
@main struct QishuiSecurityFlowTests {
    @MainActor static func main() async throws {
        var polls = 0, challenges = 0
        let result = try await QishuiSecurityFlow.run(poll: { retry in
            polls += 1
            if let retry {
                precondition(retry["ticket"] == "a b" && retry["nested"] == "{\"v\":1}")
                return ["data": ["error_code": 0, "status": "3"]]
            }
            return ["message": "error", "data": ["error_code": 2046, "verify_from": "verify_center", "biz_params": "ticket=a+b&nested=%7B%22v%22%3A1%7D"]]
        }, verify: { decision in
            challenges += 1
            precondition(decision["verify_from"] as? String == "verify_center")
            return true
        })
        precondition(polls == 2 && challenges == 1 && (result["data"] as? [String: Any])?["status"] as? String == "3")
        polls = 0
        do {
            _ = try await QishuiSecurityFlow.run(poll: { _ in polls += 1; return ["data": ["error_code": 2046]] }, verify: { _ in false })
            preconditionFailure("Cancelled challenge must not retry or log in")
        } catch { precondition(polls == 1) }
        polls = 0
        do {
            _ = try await QishuiSecurityFlow.run(poll: { _ in polls += 1; return ["data": ["error_code": 2046]] }, verify: { _ in true })
            preconditionFailure("Repeated MFA must terminate")
        } catch { precondition(polls == 2) }
        var called = false
        _ = try await QishuiSecurityFlow.run(poll: { _ in ["data": ["error_code": 0, "status": "1"]] }, verify: { _ in called = true; return true })
        precondition(!called)
        print("Qishui security: official decision merge, retry parameters, cancellation and finite challenge flow passed")
    }
}
