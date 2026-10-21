import Foundation

private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 206, httpVersion: "HTTP/1.1", headerFields: [
            "Content-Type": "audio/mpeg", "Content-Length": "4", "Content-Range": "bytes 0-3/4"
        ])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data([1, 2]))
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { [self] in
            client?.urlProtocol(self, didLoad: Data([3, 4]))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

private actor Receipt {
    var packets: [(Double, Data)] = []
    func append(_ packet: Data) { packets.append((Date().timeIntervalSince1970, packet)) }
    func snapshot() -> [(Double, Data)] { packets }
}

@main struct MediaStreamTests {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureProtocol.self]
        let stream = NeteaseMediaStream(configuration: config, chunkSize: 2)
        for address in ["https://m7.music.126.net/fixture.mp3", "https://isure.stream.qqmusic.qq.com/fixture.m4a", "https://imge.kugou.com/fixture.mp3", "https://audio.douyincdn.com/fixture.mp3"] {
        let receipt = Receipt()
        try await stream.transfer(URLRequest(url: URL(string: address)!)) { data in
            await receipt.append(data)
        }
        let packets = await receipt.snapshot()
        precondition(packets.count == 3)
        let header = String(decoding: packets[0].1, as: UTF8.self)
        precondition(header.contains("206"))
        precondition(header.contains("Content-Range: bytes 0-3/4"))
        precondition(packets[1].1 == Data([1, 2]))
        precondition(packets[2].1 == Data([3, 4]))
        precondition(packets[2].0 - packets[1].0 > 0.2, "First audio bytes were held until EOF")
        }
        print("Media stream: header and first bytes forwarded before source completion, Range preserved")
    }
}
