# Apple client implementation plan

**Goal:** Run the unchanged Mineradio web experience in a universal iPad/iPhone development client. Refs #14.

**Architecture:** SwiftUI hosts WKWebView with persistent web storage. The existing web server supplies the exact frontend and APIs for the first connected prototype. This explicitly requires a developer-controlled server; it is not an independent mobile release. No desktop source or branding is modified.

**Tech Stack:** SwiftUI, WebKit, AVFAudio, XcodeGen; no additional runtime packages.

## Steps

- [x] Add endpoint policy and executable regression checks for HTTPS, local development HTTP, invalid URLs and embedded credentials (15 cases passed).
- [x] Create universal Apple project with original web content, connection configuration, load failure/retry and process recovery. Open external links in system browser; deny unsupported schemes. Bundle public/ unchanged for offline visual preview.
- [x] Configure inline media and playback audio session without claiming background playback verified.
- [ ] Build for iOS Simulator and device SDK without distribution signing. Install and inspect on iPad simulator if runtime becomes available.
- [x] Record exact evidence and remaining service, login, background-audio and device acceptance gates. Commit changes in issue branch; do not publish installation packages.

Both simulator and device SDK builds succeeded; exact resource comparison passed.
Runtime install/launch remains pending (8.05 GB runtime download in progress).

## Acceptance

Native build and endpoint policy pass. The exact existing web page loads from a configured origin; no recreated product UI is substituted. Simulator checks, native audio checks and true standalone operation must be reported independently. Desktop files remain unchanged.
