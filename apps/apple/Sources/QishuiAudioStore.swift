import Foundation

/// Opaque, short-lived local media tickets. Credentials never enter WebKit URLs.
actor QishuiAudioStore {
    struct Decoded { let data: Data; let contentType: String }
    struct Reply { let status: Int; let type: String; let data: Data; let headers: [String: String] }
    enum Failure: Error { case invalidSource, missingTicket, tooLarge, busy, invalidResponse }
    typealias Download = (URL, Int) async throws -> URL
    typealias Decode = (Data, String) throws -> Decoded
    private struct Ticket { let url: URL; let auth: String; let expires: Date }
    private let download: Download
    private let decode: Decode
    private let now: () -> Date
    private let limit: Int
    private var tickets: [String: Ticket] = [:]
    private var cache: (key: String, file: URL, count: Int, type: String)?
    private var active: (key: String, task: Task<Decoded, Error>)?
    private var epoch = 0
    init(limit: Int = 32 * 1024 * 1024, now: @escaping () -> Date = Date.init,
         download: @escaping Download = { url, limit in try await QishuiAudioDownload.fetch(url, limit: limit) },
         decode: @escaping Decode) {
        self.limit = limit; self.now = now; self.download = download; self.decode = decode
    }
    func register(remoteURL: URL, auth: String) throws -> String {
        guard remoteURL.scheme == "https", remoteURL.fragment == nil,
              QishuiCatalogContract.allowedMedia(remoteURL), !auth.isEmpty, auth.utf8.count <= 8192 else { throw Failure.invalidSource }
        prune()
        if let existing = tickets.first(where: { $0.value.url == remoteURL && $0.value.auth == auth }) { return existing.key }
        // 快速切歌不能耗尽五分钟票池。保留正在解码的票，其余最早到期者可被新歌曲替换。
        if tickets.count >= 16 {
            guard let oldest = tickets.filter({ $0.key != active?.key }).min(by: { $0.value.expires < $1.value.expires })?.key else { throw Failure.busy }
            tickets[oldest] = nil
            if let cache, cache.key == oldest { try? FileManager.default.removeItem(at: cache.file); self.cache = nil }
        }
        let key = UUID().uuidString
        tickets[key] = Ticket(url: remoteURL, auth: auth, expires: now().addingTimeInterval(300))
        return key
    }
    func clear() {
        epoch += 1; tickets.removeAll(); active?.task.cancel(); active = nil
        if let cache { try? FileManager.default.removeItem(at: cache.file) }; cache = nil
    }
    private func prune() {
        tickets = tickets.filter { $0.value.expires > now() }
        if let cache, tickets[cache.key] == nil { try? FileManager.default.removeItem(at: cache.file); self.cache = nil }
    }
    func response(ticket key: String, method: String = "GET", range: String? = nil) async throws -> Reply {
        guard method == "GET" || method == "HEAD" else { throw Failure.invalidResponse }
        prune(); guard let ticket = tickets[key] else { throw Failure.missingTicket }
        let generation = epoch
        if cache?.key != key {
            let job: Task<Decoded, Error>
            if let active {
                guard active.key == key else { throw Failure.busy }; job = active.task
            } else {
                let download = self.download, decode = self.decode, limit = self.limit
                job = Task {
                    let file = try await download(ticket.url, limit)
                    defer { try? FileManager.default.removeItem(at: file) }
                    try Task.checkCancellation()
                    let count = (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    guard count > 0, count <= limit else { throw Failure.tooLarge }
                    let decoded = try decode(Data(contentsOf: file, options: .mappedIfSafe), ticket.auth)
                    guard !decoded.data.isEmpty, decoded.data.count <= limit else { throw Failure.tooLarge }
                    return decoded
                }
                active = (key, job)
            }
            let decoded: Decoded
            do { decoded = try await job.value } catch { if epoch == generation, active?.key == key { active = nil }; throw error }
            guard epoch == generation, tickets[key]?.expires ?? .distantPast > now() else { throw Failure.missingTicket }
            if cache?.key != key {
                let file = FileManager.default.temporaryDirectory.appendingPathComponent("mineradio-qishui-" + UUID().uuidString)
                try decoded.data.write(to: file, options: .atomic)
                if let cache { try? FileManager.default.removeItem(at: cache.file) }
                cache = (key, file, decoded.data.count, decoded.contentType)
            }
            active = nil
        }
        guard let cache, cache.key == key else { throw Failure.missingTicket }
        var headers = ["Accept-Ranges": "bytes", "Cache-Control": "no-store"]
        let slice = Self.slice(range, count: cache.count)
        guard let slice else { headers["Content-Range"] = "bytes */\(cache.count)"; return Reply(status: 416, type: cache.type, data: Data(), headers: headers) }
        let status = range == nil ? 200 : 206
        headers["Content-Length"] = String(slice.count)
        if range != nil { headers["Content-Range"] = "bytes \(slice.lowerBound)-\(slice.upperBound - 1)/\(cache.count)" }
        let bytes: Data
        if method == "HEAD" { bytes = Data() }
        else {
            let handle = try FileHandle(forReadingFrom: cache.file); defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(slice.lowerBound)); bytes = try handle.read(upToCount: slice.count) ?? Data()
        }
        return Reply(status: status, type: cache.type, data: bytes, headers: headers)
    }
    static func slice(_ text: String?, count: Int) -> Range<Int>? {
        guard count > 0 else { return nil }; guard let text else { return 0..<count }
        guard text.hasPrefix("bytes="), !text.contains(",") else { return nil }
        let pair = text.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard pair.count == 2 else { return nil }
        if pair[0].isEmpty { guard let n = Int(pair[1]), n > 0 else { return nil }; return max(0, count - n)..<count }
        guard let start = Int(pair[0]), start >= 0, start < count else { return nil }
        if pair[1].isEmpty { return start..<count }
        guard let end = Int(pair[1]), end >= start else { return nil }; return start..<(min(end, count - 1) + 1)
    }
}

/// Stream into a private temporary file, enforcing the limit before each write.
private final class QishuiAudioDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let file: URL
    private let handle: FileHandle
    private let limit: Int
    private var count = 0
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private init(limit: Int) throws {
        self.limit = limit; file = FileManager.default.temporaryDirectory.appendingPathComponent("mineradio-qishui-download-" + UUID().uuidString)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        handle = try FileHandle(forWritingTo: file)
    }
    static func fetch(_ url: URL, limit: Int) async throws -> URL {
        let owner = try QishuiAudioDownload(limit: limit)
        return try await withCheckedThrowingContinuation { continuation in
            owner.continuation = continuation
            let config = URLSessionConfiguration.ephemeral; config.httpShouldSetCookies = false; config.httpCookieStorage = nil
            config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 60
            let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
            let session = URLSession(configuration: config, delegate: owner, delegateQueue: queue); owner.session = session
            var request = URLRequest(url: url); request.setValue("https://www.qishui.com/", forHTTPHeaderField: "Referer")
            session.dataTask(with: request).resume()
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.expectedContentLength <= Int64(limit) else { completionHandler(.cancel); return }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard count <= limit - data.count else { dataTask.cancel(); return }
        do { try handle.write(contentsOf: data); count += data.count } catch { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle.close()
        if let error { try? FileManager.default.removeItem(at: file); continuation?.resume(throwing: error) }
        else { continuation?.resume(returning: file) }
        continuation = nil; session.finishTasksAndInvalidate(); self.session = nil
    }
}
