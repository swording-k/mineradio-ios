import Foundation
@main struct AppleMediaPolicyTests {
    static func main() {
        for text in ["https://m801.music.126.net/song.mp3", "https://isure.stream.qqmusic.qq.com/track.m4a", "https://imge.kugou.com/cover.jpg", "https://y.qq.com/music/photo_new/T002.jpg"] {
            precondition(AppleMediaPolicy.allowed(URL(string: text)!))
        }
        for text in ["https://y.qq.com/private", "http://127.0.0.1/a", "https://qqmusic.qq.com.evil.test/a", "https://user@imge.kugou.com/a"] {
            precondition(!AppleMediaPolicy.allowed(URL(string: text)!))
        }
        precondition(AppleMediaPolicy.referer(URL(string: "https://isure.stream.qqmusic.qq.com/a")!) == "https://y.qq.com/")
        precondition(AppleMediaPolicy.referer(URL(string: "https://imge.kugou.com/a")!) == "https://www.kugou.com/")
        print("Apple media: provider CDN boundaries, cover paths and provider Referer passed")
    }
}
