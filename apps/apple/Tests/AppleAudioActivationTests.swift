import Foundation

private final class ActivationFixture: @unchecked Sendable {
    let lock = NSLock()
    private var count = 0
    var fail = false
    enum Failure: Error { case denied }
    func activate() throws {
        precondition(!Thread.isMainThread, "Audio session activation must not block the UI thread")
        lock.lock(); count += 1; let denied = fail; lock.unlock()
        Thread.sleep(forTimeInterval: 0.1)
        if denied { throw Failure.denied }
    }
    func calls() -> Int { lock.lock(); defer { lock.unlock() }; return count }
    func deny(_ flag: Bool) { lock.lock(); fail = flag; lock.unlock() }
}

@main struct AppleAudioActivationTests {
    @MainActor static func main() async throws {
        let fixture = ActivationFixture()
        let activation = AppleAudioActivation(operation: { try fixture.activate() })
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 { group.addTask { try await activation.activate() } }
            try await group.waitForAll()
        }
        precondition(fixture.calls() == 1, "Concurrent play requests must share one activation")
        try await activation.activate()
        precondition(fixture.calls() == 2, "A later play must reactivate after a possible interruption")
        fixture.deny(true)
        do { try await activation.activate(); preconditionFailure("Activation denial ignored") } catch {}
        fixture.deny(false)
        try await activation.activate()
        precondition(fixture.calls() == 4, "A failed activation must not poison later attempts")
        print("Apple audio activation: background execution, coalesced concurrent play, reactivation and error retry passed")
    }
}
