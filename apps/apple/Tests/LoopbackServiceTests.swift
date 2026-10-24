import Foundation

@main struct LoopbackServiceTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("public")
        let service = AppleLocalService(resourceRoot: root, generatedRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("apps/apple/GeneratedWeb"), port: 0)
        service.start()
        for _ in 0..<100 {
            if service.origin != nil || service.failure != nil { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let origin = service.origin else { fatalError(service.failure ?? "Listener did not become ready") }
        let (html, page) = try await URLSession.shared.data(from: origin)
        precondition((page as? HTTPURLResponse)?.statusCode == 200)
        let originalHTML = try Data(contentsOf: root.appendingPathComponent("index.html"))
        precondition(html == AppleHTMLPolicy.prepare(originalHTML))
        precondition(html != originalHTML, "External fonts are deferred by the native delivery policy")
        let (bundle, bundleResponse) = try await URLSession.shared.data(from: origin.appendingPathComponent("js/index-loader.js"))
        precondition((bundleResponse as? HTTPURLResponse)?.statusCode == 200)
        let expectedBundle = try Data(contentsOf: URL(fileURLWithPath: "apps/apple/GeneratedWeb/index-modules.js"))
        precondition(bundle == expectedBundle)
        let endpoint = origin.appendingPathComponent("api/login/status")
        let (_, denied) = try await URLSession.shared.data(from: endpoint)
        precondition((denied as? HTTPURLResponse)?.statusCode == 403)
        var unsupported = URLRequest(url: origin.appendingPathComponent("api/unsupported-fixture"))
        unsupported.setValue(service.sessionToken, forHTTPHeaderField: "X-Mineradio-Session")
        let (json, allowed) = try await URLSession.shared.data(for: unsupported)
        precondition((allowed as? HTTPURLResponse)?.statusCode == 200)
        let result = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        precondition(result["supported"] as? Bool == false)
        let (_, rejectedMedia) = try await URLSession.shared.data(from: URL(string: origin.absoluteString + "/api/audio?url=http%3A%2F%2F127.0.0.1%2Fprivate")!)
        precondition((rejectedMedia as? HTTPURLResponse)?.statusCode == 403)
        print("Loopback: original HTML with deferred external fonts, exact module bundle, private API gate, explicit unsupported route and media host boundary passed")
    }
}
