import Foundation

@main struct AppleHTMLPolicyTests {
    static func main() throws {
        let original = Data("<head><link href=\"https://fonts.googleapis.com/css2?family=Inter&amp;display=swap\" rel=\"stylesheet\"><link href=\"css/index.css\" rel=\"stylesheet\"></head><body>Original</body>".utf8)
        let transformed = AppleHTMLPolicy.prepare(original)
        let html = String(decoding: transformed, as: UTF8.self)
        precondition(html.contains("media=\"print\""), "Remote fonts must not block the original UI from parsing")
        precondition(html.contains("onload=\"this.media='all'\""))
        precondition(html.contains("<link href=\"css/index.css\" rel=\"stylesheet\">"))
        precondition(html.contains("<body>Original</body>"))
        precondition(AppleHTMLPolicy.prepare(transformed) == transformed)
        print("Apple HTML: remote fonts deferred, local styles/body unchanged, repeated processing stable")
    }
}
