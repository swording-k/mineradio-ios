import Foundation
private actor Fixture: BodianRequesting {
    var calls = 0
    func request(_ r: URLRequest) async throws -> [String: Any] {
        calls += 1
        precondition(r.value(forHTTPHeaderField: "devid")?.count == 32)
        precondition(r.value(forHTTPHeaderField: "qimei36") == r.value(forHTTPHeaderField: "devid"))
        let p = r.url!.path
        if p.hasSuffix("qrCode") { return ["code": 200, "data": ["qrCode": "fixture-key"]] }
        if p.hasSuffix("qrCodeStatus") { return ["code": 200, "data": ["status": 3]] }
        if p.hasSuffix("/login") { return ["code": 200, "data": ["id": "42", "token": "fixture-token", "userInfo": ["id": "42", "nickname": "Fixture"]]] }
        if p.hasSuffix("checkRight") { return ["code": 200, "data": ["status": 3, "audition": ["start": 20, "end": 50, "https": "https://other.web.ra01.sycdn.kuwo.cn/fixture.mp3"]]] }
        return ["code": 200, "data": ["resultList": [["id": "7", "name": "Song", "artist": "Artist", "duration": 180]], "total": 1]]
    }
    func count() -> Int { calls }
}
@main struct BodianNativeTests {
    static func main() async throws {
        precondition(BodianContract.sign(path: "/test", query: "a=b+c&x=1", body: "") == "009f5c2bcb8507866fc48b3cf34a9417")
        precondition(!BodianContract.allowedAPI(URL(string: "https://bd-api.kuwo.cn.evil.test/api/search/music/list")!))
        let fixture = Fixture()
        let api = BodianNativeAPI(transport: fixture, keychainService: nil, deviceID: "1234567890abcdef1234567890abcdef")
        let qr = try await api.handle(URL(string: "http://127.0.0.1/api/bodian/login/qr/key")!, method: "GET", body: Data())
        precondition(qr["key"] as? String == "fixture-key")
        let login = try await api.handle(URL(string: "http://127.0.0.1/api/bodian/login/qr/check?key=fixture-key")!, method: "GET", body: Data())
        precondition(login["loggedIn"] as? Bool == true && login["token"] == nil)
        let search = try await api.handle(URL(string: "http://127.0.0.1/api/bodian/search?keywords=Song")!, method: "GET", body: Data())
        precondition((search["songs"] as? [[String: Any]])?.first?["provider"] as? String == "bodian")
        let play = try await api.handle(URL(string: "http://127.0.0.1/api/bodian/song/url?id=7")!, method: "GET", body: Data())
        precondition(play["trial"] as? Bool == true && play["playable"] as? Bool == true)
        let logout = try await api.handle(URL(string: "http://127.0.0.1/api/bodian/logout")!, method: "POST", body: Data())
        precondition(logout["loggedIn"] as? Bool == false)
        let replay = try await api.handle(URL(string: "http://127.0.0.1/api/bodian/login/qr/check?key=fixture-key")!, method: "GET", body: Data())
        precondition(replay["code"] as? Int == 800)
        let before = await fixture.count()
        do {
            _ = try await api.handle(URL(string: "http://127.0.0.1/api/bodian/song/url?id=invalid")!, method: "GET", body: Data())
            preconditionFailure("Invalid IDs must not reach upstream")
        } catch BodianFailure.invalidInput { }
        let after = await fixture.count()
        precondition(before == after)
        print("Bodian native: signature, domains, QR lifecycle, no credential disclosure, search, audition and logout passed")
    }
}
