# Mineradio Apple development client

Refs [#14](https://github.com/swording-k/Mineradio/issues/14). Universal iPad/iPhone development port; not a public release or accepted stable client.

## Architecture

The original `public/` UI and visual engine run in WKWebView. An app-owned service listens only on `127.0.0.1:19363`; no Mac server is required for the implemented Netease routes. Swift implements Netease request encryption, QR login, account status, playlist pagination, search, lyrics and playback URL lookup. Session cookies stay in Keychain. Other music platforms are not implemented in this Apple port. Provider playback URLs determine access; this client does not grant membership or bypass trial restrictions.

Apple builds combine the original 105 JavaScript modules in original order, avoiding the upstream loader's synchronous XHR startup. The build manifest records source hashes. Desktop source is unchanged. Audio uses a bounded streaming relay with Range support rather than buffering a whole song before replying. These changes preserve the visual presets.

## Build

Requires Xcode with iOS SDK, Node.js and XcodeGen. From repository root:

```sh
node apps/apple/scripts/build-web-bundle.cjs
xcodegen generate --spec apps/apple/project.yml
xcodebuild -project apps/apple/MineradioApple.xcodeproj -scheme MineradioApple -sdk iphonesimulator -configuration Debug -derivedDataPath apps/apple/build CODE_SIGNING_ALLOWED=NO build
node --test apps/apple/Tests/web-bundle.test.cjs
```

Generated project, bundled JS and build outputs are ignored. Device builds use Apple Development signing, not the Mac Developer ID certificate. Normal startup selects the internal service; the globe button is a development override. `--native-smoke` is an anonymous simulator probe, not user acceptance.

## Evidence and remaining work (2026-10-19)

- Encryption vectors, native route fixtures, loopback access controls, bundle ordering and incremental media streaming have dedicated checks.
- Anonymous host-network probe returned QR key, search results, lyrics and a playable URL. This does not prove real iPad playback.
- Simulator build passed and original startup rendered. End-to-end simulator QR/search probe remains unresolved.
- Physical iPad Air 4 ran version 0.2.0 (2), but user reports severe freezing and no usable playback. It has NOT passed acceptance.
- A 16-second read-only Activity Monitor trace measured WebContent about 578 MiB average physical footprint; app about 121 MiB, GPU process about 148 MiB, networking about 8 MiB. The approximate process sum is 855 MiB; it is not an exact unique-memory total. Thermal state remained Nominal. No JavaScript stack profile was obtained, so these measurements do not establish a single rendering bottleneck.
- Version 0.3.0 (3) contains the synchronous-loader and whole-audio-buffer fixes. It is not yet measured or accepted on the physical iPad. Device control stopped at the user's request; do not resume without authorization.

Still verify login, playlist traversal, play/pause/seek, uninterrupted long playback, frame pacing, memory, touch, rotation and iPhone layout on real hardware. Background/lock-screen playback, interruptions and AirPlay are not accepted. The Mac Qishui signature component cannot be reused on iOS.

Original GPL-3.0-only, copyright and upstream notices remain; see bundled LICENSE, NOTICE.md and THIRD_PARTY_NOTICES.md. This is not an official upstream Apple release.
