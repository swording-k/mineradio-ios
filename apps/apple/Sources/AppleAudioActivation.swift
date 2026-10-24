import Foundation
#if os(iOS)
import AVFAudio
#endif

actor AppleAudioActivation {
    #if os(iOS)
    static let shared = AppleAudioActivation {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
    #endif
    private let operation: @Sendable () throws -> Void
    private let queue = DispatchQueue(label: "mineradio.audio-session", qos: .userInitiated)
    private var inFlight: Task<Void, Error>?
    init(operation: @escaping @Sendable () throws -> Void) { self.operation = operation }
    func activate() async throws {
        if let inFlight { return try await inFlight.value }
        let task = Task { [queue, operation] in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                queue.async {
                    do { try operation(); continuation.resume() }
                    catch { continuation.resume(throwing: error) }
                }
            }
        }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }
}
