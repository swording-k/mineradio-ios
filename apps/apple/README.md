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

Generated project, bundled JS and build outputs are ignored. Device builds use Apple Development signing, not the Mac Developer ID certificate. Normal startup selects the internal service; the obsolete developer-server connection form has been removed. `--native-smoke` is an anonymous simulator probe, not user acceptance.

## Evidence and remaining work (2026-10-19)

- Encryption vectors, native route fixtures, loopback access controls, bundle ordering and incremental media streaming have dedicated checks.
- Anonymous host-network probe returned QR key, search results, lyrics and a playable URL. This does not prove real iPad playback.
- Simulator build passed and original startup rendered. End-to-end simulator QR/search probe remains unresolved.
- Physical iPad Air 4 ran version 0.2.0 (2), but user reports severe freezing and no usable playback. It has NOT passed acceptance.
- A 16-second read-only Activity Monitor trace measured WebContent about 578 MiB average physical footprint; app about 121 MiB, GPU process about 148 MiB, networking about 8 MiB. The approximate process sum is 855 MiB; it is not an exact unique-memory total. Thermal state remained Nominal. No JavaScript stack profile was obtained, so these measurements do not establish a single rendering bottleneck.
- Version 0.3.0 (3) contains the synchronous-loader and whole-audio-buffer fixes. It is not yet measured or accepted on the physical iPad. Device control stopped at the user's request; do not resume without authorization.

Still verify login, playlist traversal, play/pause/seek, uninterrupted long playback, frame pacing, memory, touch, rotation and iPhone layout on real hardware. Background/lock-screen playback, interruptions and AirPlay are not accepted. The Mac Qishui signature component cannot be reused on iOS.

Original GPL-3.0-only, copyright and upstream notices remain; see bundled LICENSE, NOTICE.md and THIRD_PARTY_NOTICES.md. This is not an official upstream Apple release.

## 2026-10-20 follow-up: resource lifetime and touch

Apple-only postlude now forwards primary touch/pen drags to existing mouse-driven 3D handlers, with pointer capture and cancel cleanup. It does not intercept playlist or button events outside the scene canvas. Desktop free-camera pointer-lock mode remains unsupported for finger input.

On splash completion, release the separate splash WebGL buffer/program/context and reduce its backing canvas to 1×1. Original code previously stopped animation but retained these resources. This is a specific lifetime fix, not evidence that all WebContent termination is solved. Version 0.3.1 (4) needs physical acceptance; no physical installation or UI automation was performed.

Read-only device records: JetsamEvent 2026-10-19 16:09:57 lists Mineradio and related WebKit processes in coalition 837. WebContent lifetimeMax 53840 pages ×16384 bytes ≈841 MiB; GPU lifetimeMax 22128 pages ≈346 MiB. Peaks are separate lifetime maxima, not simultaneous totals. Neither process entry reports a termination reason; the record does not establish that Mineradio was the Jetsam victim. No WebContent-named crash report was returned by the recursive search. Raw system records stay local and are not committed.

## DIY controls (0.3.2 development candidate)

The original DIY mode toggle lived in the desktop titlebar and its alternate entry required hover/fullscreen. Apple-only CSS exposes the existing alternate toggle at the safe-area top right and keeps the visual-console entry reachable by touch. It calls original toggleDiyMode and preserves original customization controls. Normal mode still hides the visual console until DIY is enabled. Removed the native globe/server configuration form: normal playback uses the internal loopback service.

## Experimental Qishui Passport adapter

The original GPL Passport security assets are referenced as folder resources, not edited or duplicated. A separate on-demand WKWebView runs the existing signer; only two exact HTTPS Passport routes may cross the native XHR bridge. Redirects, arbitrary hosts/paths/methods and mismatched signing tokens are rejected. Cookies stay in a native Keychain entry, and QR generation prevents stale confirmation. Failed initialization releases its WebView.

The first anonymous macOS WebKit probe successfully generated a real QR PNG and returned waiting from the polling API. This is a host-WebKit protocol check, not iOS or physical-user acceptance. Initial iOS simulator probe failed with a JavaScript exception. A diagnostic rebuild passed, but a repeat end-to-end probe was blocked by an unresponsive simulator installation/launch workflow; iOS QR is not accepted. The QR index URL legitimately uses bff-pc.qishui.com; scan URL validation accepts that exact host and api.qishui.com.

The adapter intentionally returns loggedIn=false / verifying after cookie confirmation until the Apple account/catalogue adapter validates identity. Secondary verification (MFA), account/library and full-track playback are not implemented. The Mac-only native signature helper is not bundled. Other music providers remain unsupported. This login prototype must not be advertised as a working Qishui client.

Eight JS adapter/bridge/bundle checks and the Swift host/signature/poll/QR contract checks pass. Actual iPad QR, confirmation, logout and long-run playback are separate outstanding gates. Debug --qishui-smoke writes only safe booleans/stages to the simulator's Documents folder; never commit QR tokens, cookies or raw network responses.

## 0.3.3 (6): bounded lyric resources and original control anchors

A newer read-only device record, JetsamEvent-2026-10-20-001922, identifies the GPU process in the same coalition as foreground Mineradio with reason highwater: 19430 pages ×16384 bytes ≈303.6 MiB. WebContent was the largest process; lifetime peak 79955 pages ≈1249.3 MiB. This supersedes the earlier inconclusive records for that event, but does not establish the precise allocation responsible or the cause of every reported exit. Raw device logs are not committed.

Source inspection confirms whole-song text runway preloading and retention: original trimStageLyricPersistentTrackRows evicts effect layers but preserves text rows. The Apple-only adapter now disables the additional whole-song runway, retains the original visible offsets and 24-line lookahead (plus small eviction hysteresis), releases offscreen rows through disposeStageLyricResidentRow, and caps the optional high-quality lyric texture pool at 24 MiB. This bounds these caches rather than promising a total app-memory cap. Seeking may need to rebuild evicted lines and requires acceptance testing. Current visible lyric styling is preserved.

DIY now follows the original fullscreen account-region CSS anchors and tracking. The FX button moves above the playback controls when visible, with larger side/bottom spacing and matching panel inset. No desktop shared files changed.

Seven JS regression checks pass, including a 1000-line fixture with translated visible rows, bounded retention, disabled whole-song runway and texture-pool budget. Physical memory/FPS, seeking, button placement and long playback remain pending. No physical installation, launch or UI control was performed.
