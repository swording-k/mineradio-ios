import Foundation

@main struct EndpointPolicyTests {
    static func main() {
        let accepted = ["https://music.example", "http://localhost:3000", "http://127.0.0.1:3000", "http://192.168.1.20:3000", "http://10.0.0.2:3000", "http://172.16.0.2:3000"]
        let rejected = ["file:///etc/passwd", "javascript:alert(1)", "https://user:secret@music.example", "http://music.example", "http://192.168.1.20.evil.example", "http://172.32.0.1", "", "https://music.example/path", "https://music.example?token=secret"]
        for value in accepted { precondition(EndpointPolicy.parse(value) != nil, "Rejected valid origin: \(value)") }
        for value in rejected { precondition(EndpointPolicy.parse(value) == nil, "Accepted invalid origin: \(value)") }
        print("Endpoint policy: \(accepted.count + rejected.count) cases passed")
    }
}
