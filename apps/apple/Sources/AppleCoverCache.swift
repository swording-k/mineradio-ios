import Foundation
import CryptoKit

/// 封面 / 头像的本机缓存（内存 + 磁盘）。
/// 原版前端每次刷新账号状态都会给头像地址加时间戳强制重载；桌面端本地服务足够快所以看不出，
/// 手机上每次都要重新走网络，表现为头像闪烁、封面加载慢。这里按「真实图片地址」缓存，
/// 时间戳参数不影响命中。只缓存图片，不缓存音频或账号数据。
actor AppleCoverCache {
    static let shared = AppleCoverCache()
    struct Image { let data: Data; let type: String }

    private let memory = NSCache<NSString, NSData>()
    private var types: [String: String] = [:]
    private let directory: URL?
    private let session: URLSession
    private var inFlight: [String: Task<Image?, Never>] = [:]
    private let maxBytes = 6 * 1024 * 1024
    private let maxFiles = 600

    init() {
        memory.totalCostLimit = 32 * 1024 * 1024
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("MineradioCovers", isDirectory: true)
        if let base { try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true) }
        directory = base
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)
    }

    func image(for url: URL, referer: String) async -> Image? {
        let key = Self.key(url)
        if let hit = memory.object(forKey: key as NSString) { return Image(data: hit as Data, type: types[key] ?? "image/jpeg") }
        if let file = directory?.appendingPathComponent(key), let data = try? Data(contentsOf: file), !data.isEmpty {
            let type = Self.sniff(data)
            remember(key, data, type)
            return Image(data: data, type: type)
        }
        if let running = inFlight[key] { return await running.value }
        let task = Task<Image?, Never> { [session, maxBytes] in
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue(referer, forHTTPHeaderField: "Referer")
            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  !data.isEmpty, data.count <= maxBytes else { return nil }
            let declared = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            let type = declared.hasPrefix("image/") ? declared : Self.sniff(data)
            guard type.hasPrefix("image/") else { return nil }
            return Image(data: data, type: type)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result {
            remember(key, result.data, result.type)
            if let file = directory?.appendingPathComponent(key) { try? result.data.write(to: file, options: .atomic) }
            trimDiskIfNeeded()
        }
        return result
    }

    private func remember(_ key: String, _ data: Data, _ type: String) {
        memory.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        types[key] = type
        if types.count > 2000 { types.removeAll(keepingCapacity: true) }
    }

    private var writesSinceTrim = 0
    private func trimDiskIfNeeded() {
        writesSinceTrim += 1
        guard writesSinceTrim >= 40, let directory else { return }
        writesSinceTrim = 0
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys), files.count > maxFiles else { return }
        let sorted = files.sorted {
            let a = (try? $0.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            return a < b
        }
        for file in sorted.prefix(files.count - maxFiles) { try? FileManager.default.removeItem(at: file) }
    }

    /// 缓存键只取真实地址（去掉前端加的 v= 时间戳），HTTP / HTTPS 视为同一张图。
    static func key(_ url: URL) -> String {
        var text = url.absoluteString
        if var c = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            c.scheme = "https"
            let kept = (c.queryItems ?? []).filter { $0.name != "v" }
            c.queryItems = kept.isEmpty ? nil : kept
            text = c.string ?? text
        }
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func sniff(_ data: Data) -> String {
        let b = [UInt8](data.prefix(12))
        if b.count >= 3, b[0] == 0xFF, b[1] == 0xD8 { return "image/jpeg" }
        if b.count >= 4, b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 { return "image/png" }
        if b.count >= 4, b[0] == 0x47, b[1] == 0x49, b[2] == 0x46 { return "image/gif" }
        if b.count >= 12, b[0] == 0x52, b[1] == 0x49, b[2] == 0x46, b[3] == 0x46, b[8] == 0x57, b[9] == 0x45 { return "image/webp" }
        if b.count >= 12, b[4] == 0x66, b[5] == 0x74, b[6] == 0x79, b[7] == 0x70 { return "image/heic" }
        return "application/octet-stream"
    }
}
