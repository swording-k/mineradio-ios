import Foundation
import Darwin

/// Private local evidence, not telemetry. Host footprint excludes WebContent and GPU processes.
@MainActor final class AppleDiagnostics {
    struct Record: Codable {
        let event: String
        let timestamp: Double
        let uptime: Double
        let session: UUID
        let metrics: [String: Double]
    }
    static let shared = AppleDiagnostics()
    private(set) var records: [Record] = []
    private let file: URL
    private let capacity: Int
    private let persistence = DispatchQueue(label: "mineradio.local-diagnostics", qos: .utility)
    private let session = UUID()
    private let webEvents: Set<String> = ["sample", "media-play", "media-pause", "media-playing", "media-waiting", "media-stalled", "media-seeking", "media-seeked", "media-ended", "media-emptied", "media-loadedmetadata", "media-error", "media-time-regressed"]
    private let nativeEvents: Set<String> = ["view-created", "page-loaded", "page-load-failed", "webcontent-terminated", "memory-warning"]
    private let webKeys: Set<String> = ["textures", "geometries", "programs", "canvasWidth", "canvasHeight", "pixelRatio", "fps", "targetFps", "frameCostMs", "pressure", "mediaTime", "duration", "paused", "seeking", "ended", "readyState", "networkState", "mediaCode", "sourceEpoch", "recentSeek"]
    private var windowStarted = Date.distantPast
    private var webRecordsInWindow = 0

    init(file: URL? = nil, capacity: Int = 240) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MineradioDiagnostics/runtime.json")
        self.capacity = min(240, max(1, capacity))
        if let size = try? self.file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 192 * 1024,
           let data = try? Data(contentsOf: self.file), let old = try? JSONDecoder().decode([Record].self, from: data) {
            // Load bounded known-schema evidence from the preceding app launch.
            records = old.filter { (webEvents.contains($0.event) || nativeEvents.contains($0.event)) && $0.metrics.allSatisfy { webKeys.contains($0.key) || $0.key == "hostFootprintBytes" } }.suffix(self.capacity).map { $0 }
        }
    }
    func recordWeb(_ input: [String: Any]) {
        guard let event = input["event"] as? String, webEvents.contains(event) else { return }
        let now = Date()
        if now.timeIntervalSince(windowStarted) >= 60 { windowStarted = now; webRecordsInWindow = 0 }
        guard webRecordsInWindow < 60 else { return }
        webRecordsInWindow += 1
        let raw = input["metrics"] as? [String: Any] ?? [:]
        var values: [String: Double] = [:]
        for key in webKeys {
            if let number = raw[key] as? NSNumber, number.doubleValue.isFinite, (0...1e15).contains(number.doubleValue) { values[key] = number.doubleValue }
        }
        append(event, metrics: values)
    }
    func recordNative(_ event: String) {
        guard nativeEvents.contains(event) else { return }
        var values: [String: Double] = [:]
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        if result == KERN_SUCCESS { values["hostFootprintBytes"] = Double(info.phys_footprint) }
        append(event, metrics: values)
    }
    private func append(_ event: String, metrics: [String: Double]) {
        records.append(Record(event: event, timestamp: Date().timeIntervalSince1970, uptime: ProcessInfo.processInfo.systemUptime, session: session, metrics: metrics))
        records = Array(records.suffix(capacity))
        let snapshot = records, destination = file
        persistence.async {
            guard let data = try? JSONEncoder().encode(snapshot), data.count <= 192 * 1024 else { return }
            do {
                let folder = destination.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: destination, options: .atomic)
                var excluded = folder; var values = URLResourceValues(); values.isExcludedFromBackup = true
                try? excluded.setResourceValues(values)
                #if os(iOS)
                try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
                #endif
            } catch { /* Diagnostics must never block or restart music playback. */ }
        }
    }
    // Used by deterministic local tests; production never waits on disk writes.
    func waitForPendingWrites() { persistence.sync {} }
}
