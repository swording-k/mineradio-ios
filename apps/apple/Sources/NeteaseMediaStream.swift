import Foundation

/// Bounded-memory media relay. Headers and chunks reach the player while the
/// source is downloading; no full-song Data buffer or UI-thread byte loop.
actor NeteaseMediaStream {
    private var inFlight = 0
    private let configuration: URLSessionConfiguration
    private let chunkSize: Int
    init(configuration: URLSessionConfiguration = .ephemeral, chunkSize: Int = 16384) {
        self.configuration = configuration
        self.chunkSize = max(1, chunkSize)
    }

    func transfer(_ input: URLRequest, write: @Sendable (Data) async throws -> Void) async throws {
        guard inFlight < 4, let url = input.url, NeteaseContract.allowedMedia(url) else { throw URLError(.resourceUnavailable) }
        inFlight += 1
        defer { inFlight -= 1 }
        let config = configuration.copy() as! URLSessionConfiguration
        config.httpCookieStorage = nil
        config.timeoutIntervalForResource = 180
        let session = URLSession(configuration: config, delegate: MediaRedirectGuard(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = input
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, let finalURL = http.url,
              NeteaseContract.allowedMedia(finalURL), [200, 206].contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let chunked = response.expectedContentLength < 0
        var header = "HTTP/1.1 \(http.statusCode) Response\r\nContent-Type: \(response.mimeType ?? "application/octet-stream")\r\nConnection: close\r\nCache-Control: no-store\r\nAccept-Ranges: bytes\r\n"
        if chunked { header += "Transfer-Encoding: chunked\r\n" }
        else { header += "Content-Length: \(response.expectedContentLength)\r\n" }
        if let range = http.value(forHTTPHeaderField: "Content-Range") { header += "Content-Range: \(range)\r\n" }
        try await write(Data((header + "\r\n").utf8))
        if request.httpMethod == "HEAD" { return }
        var chunk: [UInt8] = []
        chunk.reserveCapacity(chunkSize)
        func packet(_ chunk: [UInt8]) -> Data {
            guard chunked else { return Data(chunk) }
            var result = Data((String(chunk.count, radix: 16) + "\r\n").utf8)
            result.append(contentsOf: chunk); result.append(Data("\r\n".utf8))
            return result
        }
        for try await byte in bytes {
            guard !Task.isCancelled else { throw CancellationError() }
            chunk.append(byte)
            if chunk.count == chunkSize {
                try await write(packet(chunk))
                chunk.removeAll(keepingCapacity: true)
            }
        }
        if !chunk.isEmpty { try await write(packet(chunk)) }
        if chunked { try await write(Data("0\r\n\r\n".utf8)) }
    }
}

private final class MediaRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" && request.url.map(NeteaseContract.allowedMedia) == true ? request : nil)
    }
}
