import Foundation

enum AppleHTMLPolicy {
    /// Preserve the source and requested font families, but don't make first UI
    /// availability depend on an external stylesheet reachable from this device.
    static func prepare(_ data: Data) -> Data {
        guard var html = String(data: data, encoding: .utf8),
              let pattern = try? NSRegularExpression(pattern: #"<link\b[^>]*href="https://fonts\.googleapis\.com/[^"]+"[^>]*>"#, options: [.caseInsensitive]) else { return data }
        let matches = pattern.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])
            if tag.contains("data-apple-fonts-deferred") { continue }
            html.replaceSubrange(range, with: String(tag.dropLast()) + #" media="print" onload="this.media='all'" data-apple-fonts-deferred="true">"#)
        }
        return Data(html.utf8)
    }
}
