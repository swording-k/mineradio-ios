import Foundation

@main struct AppleDiagnosticsTests {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mineradio-diagnostics-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("runtime.json")
        let store = AppleDiagnostics(file: file, capacity: 8)
        store.recordWeb(["event": "sample", "metrics": ["textures": 12, "fps": 30, "mediaTime": 10, "cookie": "PRIVATE", "url": "https://private.test", "hostFootprintBytes": 123, "lyrics": "PRIVATE", "name": "PRIVATE", "duration": Double.infinity]])
        precondition(store.records.count == 1)
        let first = store.records[0]
        precondition(first.metrics["textures"] == 12 && first.metrics["cookie"] == nil && first.metrics["hostFootprintBytes"] == nil && first.metrics["duration"] == nil)
        store.recordWeb(["event": "https://private.test", "metrics": ["textures": 2]])
        precondition(store.records.count == 1)
        for _ in 0..<20 { store.recordNative("memory-warning") }
        precondition(store.records.count == 8)
        precondition(store.records.last?.metrics["hostFootprintBytes"] != nil)
        store.waitForPendingWrites()
        let bytes = try Data(contentsOf: file)
        precondition(bytes.count < 192 * 1024)
        let text = String(decoding: bytes, as: UTF8.self)
        precondition(!text.contains("PRIVATE") && !text.contains("private.test"))
        let restored = AppleDiagnostics(file: file, capacity: 8)
        precondition(restored.records.count == 8, "Previous launch evidence must survive the next view creation")
        print("Apple diagnostics: private allowlist, host-only footprint, bounded retained evidence and reload passed")
    }
}
