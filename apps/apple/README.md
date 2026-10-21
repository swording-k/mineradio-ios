# Mineradio Apple development client

Universal iPad/iPhone development port on `codex/ipad-client`. Refs #14, #15 and #16. **Internal build 0.4.4 (12) is not a public/stable release and is not ready for final user acceptance.**

## Architecture

The original `public/` UI and visual engine run in WKWebView. Original modules remain unchanged and are bundled in their original order; Apple postludes add touch, control anchoring, bounded lyric residency and native login invocation. A loopback service runs inside the app. No Mac server is required. Production uses stable `127.0.0.1:19363`; simulators/tests use independent ports so parallel clients do not collide.

QQ/Kugou open isolated official WKWebView login windows using the original desktop entry URLs. Native cookie observation hands only matching provider cookies to the native adapter. The player receives verified status, never raw credentials. Cancel closes the window and restores rendering; covered stage rendering uses the existing sleep path. Account state is verified against remote account-scoped responses; a cookie or public profile alone is insufficient. Cookies persist in separate Keychain entries and are cleared on provider logout.

Qishui reuses the original GPL Passport signer assets in an on-demand WKWebView and forwards only explicitly allowed signed requests to native networking. The current QR channel requires **Douyin**, not the Qishui app scanner; the server's confirmation page identifies the desktop channel as Windows. QR confirmation is followed by `/luna/pc/me` identity validation before `loggedIn=true`. Old cookies must not complete a still-waiting QR generation.

## Implemented routes and limits

| Provider | Native implementation | Actual acceptance boundary |
| --- | --- | --- |
| Netease | QR, account, search, playlists/tracks, lyrics, playback URL | Previous physical user playback worked; new long-run stability still pending. |
| QQ Music | Official login sheet, account validation, created/collected/liked playlists, pagination, search, lyric and authorized vkey URL | Fixtures and anonymous search/lyric passed. Private-account login and membership playback not verified. |
| Kugou | Official login sheet, account validation, playlists/tracks, search, H5/Web/Mobile playback and lyrics | Fixtures and anonymous search passed. Private-account playback not verified; anonymous denial is preserved. |
| Qishui | Passport QR/poll, native account verification, playlists/tracks/feed/search/lyrics and returned unencrypted playback URLs | Anonymous QR/waiting passed on host WebKit. Official second-verification presentation/resend is integrated; real authorization/MFA and private playback not verified. Mac-only `bdms.node` full-track signing is not portable to iOS. |

Unknown/unsupported routes return explicit capability failures. Provider rights are preserved: no fabricated VIP, session, URL or full-track claim. Qishui MFA reuses the unchanged desktop official security component in a native full-screen sheet, with cancellation, a two-minute deadline and one resend after successful verification. Native challenge networking is allowed only while the challenge is active, for exact official Passport hosts. This integration has fixture/build coverage; a real account challenge has not been accepted. Write actions/other desktop integrations are not declared complete.

The bounded streaming relay handles Range/HEAD and forwards bytes before download completion. Provider CDN/cover boundaries and Referer are explicit; arbitrary/private hosts are rejected. This does not convert provider authorization denial into playable audio.

## Build and checks

Requirements: Xcode with iOS SDK/runtime, Node.js and XcodeGen. From repository root:

```sh
node apps/apple/scripts/test-native.cjs
node apps/apple/scripts/build-web-bundle.cjs
xcodegen generate --spec apps/apple/project.yml
xcodebuild -project apps/apple/MineradioApple.xcodeproj -scheme MineradioApple -sdk iphoneos -configuration Debug -derivedDataPath apps/apple/build-device -allowProvisioningUpdates build
```

The native test runner uses `xcrun swiftc`, verifies that executables are generated, runs fixtures, and cleans its temporary outputs. Do not rely on a PATH shim reporting compiler success. Live probes in `Tests/*LiveProbe.swift` are opt-in anonymous checks, never personal-account CI.

UI tests use a simulator-only launch argument and real official sites; they do not scan or approve a login. The first run passed sheet/page load/cancel, but screenshots showed landing pages rather than login panels. Entry detection was then corrected to include Kugou's `div` control, wait for delayed rendering, and require the login iframe/panel. The corrected run displayed an actual Kugou QR. A subsequent QQ run also displayed a real QR in its captured screenshot; an image-label assertion failed because the official image has no matching accessibility label. That assertion is removed, and visual QR evidence remains separate from automated sheet/cancel checks and from actual account authorization.

Final 2026-10-21 checks: 12 native suites and Apple JS regressions passed; two simulator official-sheet/cancel tests passed; iOS device build and strict codesign verification passed. Shared desktop tests passed 222/222 and Node quick-check passed. No Windows native runtime evidence is implied.

Generated project, resource bundles, build outputs and local account data are ignored. Device builds use Apple Development signing. No new physical iPad installation, launch or interaction is authorized by this work; user requested manual testing only and no further intermediate acceptance.

## Performance evidence and pending gates

A read-only iPad Air 4 record from 2026-10-20 00:19:22 identifies the app's GPU process with `highwater`, about 303.6 MiB; WebContent lifetime peak was about 1249.3 MiB. These are not simultaneous unique-memory totals or proof of every exit's cause. Raw device logs remain local.

Apple adaptation releases splash graphics after exit, avoids synchronous 105-script loading and whole-song audio buffering, disables extra whole-song text-runway preloading, evicts distant lyric rows while preserving the visible window/lookahead, and caps the optional high-quality lyric texture pool at 24 MiB. The pool cap is not a total app-memory cap. Seeking/rebuild continuity, sustained memory, frame pacing and actual device stability remain unaccepted. Original DIY uses account-region anchors; FX controls avoid the playback bar.

Remaining release gates: real authorized login/library/member playback per provider; real Qishui MFA acceptance/full-playback solution; long playback/seek/rotation/background/interruption/AirPlay testing; iPhone native UI acceptance. Builds, fixtures, anonymous API checks, simulator UI and physical user acceptance are separate evidence. Do not upload installers or request final acceptance until these gates are honestly resolved or scope explicitly agreed.

Original GPL-3.0-only, copyright and upstream notices remain applicable. Bundled LICENSE, NOTICE.md and THIRD_PARTY_NOTICES.md retain attribution. This is not an official upstream Apple release.

## TestFlight candidate 0.4.1 (9)

On 2026-10-21 the user reported successful Netease and Qishui login on the physical iPad and requested an icon and a TestFlight candidate. This verifies login only; QQ/Kugou account authorization, Qishui full-track playback and sustained resource use remain unaccepted. This explicitly authorizes internal beta preparation, not a stable public release.

The AppIcon asset reuses `build/icon.png`, composited on black and scaled to an opaque sRGB 1024×1024 PNG; no new branding or shared desktop assets were changed. `project.yml` declares the asset catalog, AppIcon name and Release archive configuration.

The historical **0.4.1 (9)** archive is held and superseded; do not upload it. Open `MineradioApple.xcodeproj` from this worktree for current development. A later accepted candidate can be distributed through Xcode Organizer → Distribute App → App Store Connect. The App Store Connect app record must match `com.swordingk.mineradio.apple.preview` and team `NV5R86Q3MS`. The owner completes the account/encryption/tester configuration. Local archive and signature checks do not establish Apple server validation or upload success.

## Follow-up playback defects — 0.4.2 (10)

User reports after build 8: old iPad still sometimes restarts playback or loses WebContent; iPhone has difficult touch picking and silent playback. These are open defects, not dismissed as old hardware. Candidate 0.4.1 (9) has the MR icon and a locally successful Release archive, but TestFlight upload is held while investigating these reports.

Apple-only changes in build 10:
- Bridge one short touch tap to the existing canvas click handler, suppress duplicate native touch clicks, and never convert a drag/cancel into selection. Normalize 3D picking using the canvas CSS rectangle.
- Prime AudioContext on the first real gesture even while the upstream audio element is still null; explicitly use WebKit playback session type; activate native AVAudioSession before media play, resume suspended/interrupted analysis, and permit asynchronous audio URL playback after a tap. Video still requires a gesture. Physical iPhone sound is unverified.
- Skip both whole-track MR and DJ PCM/offline analysis, preserving the original realtime analyser and visual engine. This intentionally defers full-track beat-cache generation; it is not a claim that every desktop analysis feature is available. Existing source fetched and decoded complete songs, then allocated four full-length frequency bands, causing a substantial memory peak.

Regression fixtures reproduce the missing click, wrong canvas geometry, absent native audio activation and whole-track analysis allocation path, then pass with the Apple adapter. A simulator-only synthetic WAV test checks native session activation, the Web Audio analyser and media clock, without accessing user accounts. Its automation result is recorded separately from physical-device acceptance. No new physical installation or interaction occurred in this follow-up. Mid-track restart and long-run crash resolution remain unaccepted.

Build-10 evidence: 24 Apple JS tests passed after the latest adapter changes. An earlier 12-suite native run passed before the final JS-only audio-session/gesture additions; the latest native rerun was stopped during compilation when the host load exceeded 400. Simulator WAV verification did not pass: one fixture run failed because its test audio element was uninitialized, then the fixed-fixture run was stopped during an overloaded build. The test fixture is corrected, but no simulator audio success is claimed. iPhone audibility, mid-track restart and old-iPad stability therefore remain open.

Final build-10 local device build completed successfully with one Xcode build job; strict codesign validation passed and AppIcon metadata is present. The app was not installed on a physical device in this follow-up.

## iPhone layout follow-up — 0.4.3 (11)

User confirmed iPhone audio works. Root cause of shifted controls: original mobile and late desktop CSS conflict; desktop popup transforms survive on narrow screens. The Apple-only layout adapter groups portrait controls into three rows and landscape into two, restores volume/quality, uses 44px core targets, bounds panels to safe areas and adds touch close buttons. Quality and AutoMix keep their existing nodes/handlers and restore their original parents/order on tablet. Shared public/desktop sources remain unchanged.

Validation: 25 Apple JS tests passed, including repeated phone/tablet relocation. Original 105-module bundle and signed Debug iphoneos build 0.4.3 (11) succeeded. Browser fixtures at 320×667, 390×844 and 844×390 checked button/popup geometry; 834×1112 checked tablet restoration. Fixtures have no live music/accounts/3D and do not establish physical Safari touch or playback stability. No physical installation/operation or TestFlight upload occurred. iPad WebContent exits/restarts remain open.

## WebKit touch acceptance checks — 0.4.4 (12)

An actual iPhone Simulator/WebKit interaction test reproduced a second panel opening over the DIY close button: WebKit emits compatibility mouse movement after a tap, and the desktop left-edge trigger interprets it as a request to open the queue. The Apple adapter now permits that edge trigger only for a hover-capable fine pointer. Explicit queue controls remain available, and real mouse edge-hover keeps its original function. A regression test failed before this change and passed afterward. Shared desktop/public files remain unchanged.

Checks: all 26 Apple JS tests passed. Two iPhone 18 Pro / iOS 27 simulator UI tests passed: local WAV media-clock plus nonzero analyser signal, and portrait/landscape control geometry, volume-slider hit testing, and DIY panel close. The first audio run failed with a running context/advancing media clock but no signal at a fixed 700ms check; its fixture now polls for actual signal with a bounded 10-second deadline and still fails on silence. The first layout run reproduced the occluding queue; its rerun passed after gating edge-hover. Layout uses a simulator-only fixture state over the bundled original DOM/engine, not provider music or account authorization. Fixtures are absent from the Release executable.

Local Release archive: `/Users/baojian/Library/Developer/Xcode/Archives/2026-10-21/Mineradio-0.4.4-12.xcarchive`. Archive succeeded; strict signature validation, version/build 0.4.4/12, AppIcon presence, bundled 105-module SHA-256 integrity and inclusion of the edge-hover fix passed. This is an Apple Development-signed local archive, not an App Store Connect upload or Apple review result. Physical devices were not operated or installed. Long-run iPad memory/restart issues and real-account provider acceptance remain open; the archive is held for further validation.
