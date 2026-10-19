import Foundation

@main struct NeteaseContractTests {
    static func main() throws {
        let fixture = "1CA81A97B7BAEB099F29A9B99A25CD6E58E7BA5B35F25231033065C776830C0ACD212933C9432002B586ED0F458155F631B44BD2C5B733983A66E6224C0585A52777484232CB13E16B21684479BA3B9B3CF9FA119BBE8E17B07F40E02346BE3781A9B22A53CC3C44EC77569FAD1631FF"
        let encrypted = try NeteaseEAPI.encrypt(path: "/api/login/qrcode/unikey", json: "{\"type\":3,\"e_r\":false}")
        precondition(encrypted == fixture)
        let web = try NeteaseEAPI.weapi(json: "{\"type\":3,\"csrf_token\":\"\"}", secret: "abcdefghijklmnop")
        precondition(web["params"] == "hF6PNHJUfpyQ63BomrD9i6sXEl/V/fqlWv5Gp/XPf1samRTRnO6XuhmaZv1dEHl2")
        precondition(web["encSecKey"] == "d15a1683c992095d0c234c19966605c5c5964911268bbeda8cb8d08d834913e59d53b32358903a121b5fca784c1f5ae44951fd02524df58ecc98e52cc7cf8689b42c2e93ddf05b0592512d87f5960467e2f086c018849d76014d323500e30f13ef4cafbb0cf5a66731a3f1776c75ca35d0062dac70a3e33245afabcf47938487")
        let song = NeteaseContract.song(["id": 12, "name": "Fixture", "ar": [["id": 3, "name": "Artist"]], "al": ["id": 4, "name": "Album", "picUrl": "https://p1.music.126.net/fixture.jpg"], "dt": 183000])
        precondition(song["artist"] as? String == "Artist")
        precondition(song["duration"] as? Int == 183000)
        precondition(song["provider"] as? String == "netease")
        let denied = NeteaseContract.playback(["code": 200, "data": [["code": 404, "url": NSNull()]]])
        precondition(denied["url"] == nil)
        let trial = NeteaseContract.playback(["data": [["url": "https://m7.music.126.net/song.mp3", "freeTrialInfo": ["start": 0, "end": 30], "time": 30000]]])
        precondition(trial["trial"] as? Bool == true)
        let full = NeteaseContract.playback(["data": [["url": "https://m7.music.126.net/song.mp3", "freeTrialInfo": NSNull(), "time": 183000]]])
        precondition(full["trial"] as? Bool == false)
        precondition(full["duration"] as? Double == 183)
        precondition(NeteaseContract.allowedMedia(URL(string: "https://m7.music.126.net/song.mp3")!))
        precondition(!NeteaseContract.allowedMedia(URL(string: "https://music.126.net.evil.example/song.mp3")!))
        precondition(!NeteaseContract.allowedMedia(URL(string: "http://127.0.0.1/private")!))
        print("Netease encryption and contract checks passed")
    }
}
