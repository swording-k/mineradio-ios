# Mineradio Apple development client

Refs [#14](https://github.com/swording-k/Mineradio/issues/14). Universal iPhone/iPad
development prototype. No rebrand, installer release or desktop modification.

## What exists

- SwiftUI hosts WKWebView and packages the repository's exact `public/` directory
  as a folder resource. There is no rewritten particle engine or replacement UI.
- Offline preview loads that directory through a bundle-only URL scheme. Missing
  routes return an explicit unavailable response, not fabricated platform data.
- Connected mode loads the original page and APIs from a user-configured server.
  Persistent WKWebView storage is used. Inline playback is enabled and audio is
  gesture-gated; application startup does not deliberately start audio.
- Loading errors, retry and web process termination have visible recovery paths.
- Supports both device families and portrait/landscape. This is configuration,
  not proof that every original panel is usable at every size.

## Build

Requirements: Xcode with iOS SDK, XcodeGen. From repository root:

```sh
xcodegen generate --spec apps/apple/project.yml
xcodebuild -project apps/apple/MineradioApple.xcodeproj \
  -scheme MineradioApple -sdk iphonesimulator -configuration Debug \
  -derivedDataPath apps/apple/build CODE_SIGNING_ALLOWED=NO build
swiftc apps/apple/Sources/EndpointPolicy.swift \
  apps/apple/Tests/EndpointPolicyTests.swift -o /tmp/mineradio-endpoint-tests
/tmp/mineradio-endpoint-tests
```

Generated project and Info.plist are ignored; `project.yml` is the source of truth.
Device builds need Apple Development signing, provisioning and a trusted device
for installation; the Mac Developer ID distribution certificate is not used.

## Use

Open the generated Xcode project, choose an iPad simulator, run, then select
“打开内置原版界面（离线预览）”. No platform service is provided in offline mode.

For connected testing, run an isolated development instance of the existing
server with test credentials. In a simulator, configure its loopback origin,
for example `http://127.0.0.1:3000`. On a real iPad use your developer server's
LAN address. Use a trusted test network: the existing backend was designed for
desktop/local use, and this change does not turn it into a secure public service.
Do not expose the desktop app's personal authenticated server publicly.

HTTPS origins and local HTTP development origins are accepted; embedded account
credentials, query strings and paths are rejected. Web login popups currently
open in the system browser; account session transfer is not implemented.

## Evidence (2026-10-19)

- Endpoint validation: 15 cases passed.
- iOS Simulator SDK build: passed without distribution signing.
- iPhone/iPad device SDK build: passed without distribution signing.
- Packaged `public/` contents compared byte-for-byte with repository source.
- No iOS simulator runtime was installed initially. Runtime download was started;
  simulator install/launch and screenshots are **not yet verified**.
- No available iPad or iPhone was connected for device acceptance.

## Remaining gates

This is not an App Store-ready or standalone streaming client. Verify the custom
scheme, WebGL, font loading, file import, visual presets, touch, rotation and
split-window sizing in WebKit. Then implement/verify service independence,
platform-specific account login, full audio entitlements, background/lock-screen
playback, audio interruptions, AirPlay and sustained GPU/memory behavior.
The Mac Qishui 2.9.1 signature component cannot be reused on iOS.

The original copyright notices and GPL-3.0-only remain applicable. Bundled visual
assets retain their original notices; this is a development port, not a claim of
authorship or official upstream endorsement.
