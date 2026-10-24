# Apple feature parity — working record

Refs #14 and #15. Baseline: upstream `d43de565acabfdc1a9c9820a27e81a98ccbebcef`, desktop 2.2.0. The owner reports TestFlight approval for build 15; approval is not feature acceptance. Build 15 remains the submitted candidate; this work does not modify its archive or upload a replacement.

## Corrected source finding

Upstream `9402566` removed Spotify from HTML, provider ordering, startup and Electron IPC, and rejects all `/api/spotify*` calls with `404 PROVIDER_REMOVED`. Its `tests/provider-removal-diy-cinema-preload.test.js` explicitly checks this. The remaining `spotify-api.js` and dormant functions do not constitute supported Spotify integration. Earlier statements that the paused source already supplies active Spotify were incorrect. The owner's downloaded Mac package belongs to a separate development line, identified below; the paused repository is not the full feature baseline.

## Scope and implementation sequence

Preserve the original HTML, original ordered JS modules, Three.js stage, DIY and functional interaction design. Extend device-local Swift adapters, without a hosted account proxy or desktop backend dependency. Phone layouts may reposition controls but must retain reachable actions. Never restore full-song PCM allocations blindly to claim visual parity.

- [x] Add 17 NetEase library, album/artist, comment and podcast API routes using installed NeteaseCloudMusicApi payloads and the existing native transport. Implementation is present; real-account writes remain unaccepted.
- [x] Regression checks: unauthenticated writes make no remote mutation, upstream denial remains failure, POST/body/id validation, liked state, album mapping, podcast playable song IDs and pagination.
- [x] Build the Apple target and verify bundled original-module integrity. No physical-device interaction or upload.
- [x] Identify and inspect the separate Mac distribution; record portable features and desktop-specific services. Complete button-by-button alignment remains open.
- [ ] Complete remaining QQ/Kugou/Qishui and local feature gaps, then run account-authorized device acceptance and sustained performance checks. These remain open until actually exercised.

## Known gaps before this change

The native NetEase adapter only covers QR/account, playlists/tracks, search, URL, lyrics and discovery. Album/artist detail, all library mutations, comments and all podcast routes fall into a 501 fallback. QQ/Kugou/Qishui have separate incomplete route sets. Whole-track MR/DJ beat-cache generation is disabled for memory reasons. Native desktop windows, wallpaper/Wallpaper Engine, filesystem import, camera gestures, listening reports, weather and AutoMix services require individual assessment; the presence of original frontend controls is not proof of implementation.

No overall desktop parity, Spotify support, real-account mutation success, sustained iPad stability or release readiness is claimed by this record.

## 2026-10-24 evidence

The fixture failed before implementation on `/api/song/like/check`; it now passes through `NeteaseNativeAPI.handle`, including denied playlist/comment mutations and unauthenticated/malformed/GET writes. All 36 Apple JS tests and 13 native suites passed. `xcodebuild` Debug iphoneos build and strict codesign verification passed. Packaged 105-module manifest hashes match. `public/index.html` is byte-identical to the installed Mac app and the rebuilt Apple app (SHA-256 `f5fbbcb5e856b105220c63d67667ab0e8aa1eb14392594d0087ce6a3aa23cc7b`). The original HTML is reused in full; this does not prove every original service or visual mode works on iOS.

An opt-in anonymous probe using a fresh isolated Keychain service successfully fetched real album tracks, artist songs, comments, hot podcasts and program metadata. It performed no account mutation and cleared its temporary session. This verifies network contracts on this Mac, not a physical iPhone/iPad or authenticated account features.

Local logs: `apps/apple/build/TestResults/feature-parity-20261024/`. The device Debug product at `apps/apple/build-device/Build/Products/Debug-iphoneos/Mineradio.app` includes the new code. The previously uploaded 0.4.6 (15) archive has not changed; this is unreleased source and not a newly uploaded build.

| Area | Current evidence / remaining work |
| --- | --- |
| Original visual frontend | Full HTML and 105 original modules bundled; Apple postludes alter touch/layout/resource policy. Real visual and layout parity still needs comparison with the owner's reference Mac version. |
| NetEase hearts, create/add/collect playlists | Native routes and success/denial fixtures present; real signed-in operations and playlist-add fallback/check-token behavior require validation. |
| NetEase album/artist/comments | Native routes, fixtures and anonymous real-network reads passed; authenticated collection/comment operations remain unverified. |
| NetEase podcasts | Search/hot/detail/programs/my collections routes present; real anonymous hot/program metadata passed; subscription/created/liked libraries and long episode playback remain unaccepted. |
| QQ | Native login/library/search/play/lyrics plus new album/artist/comments read routes and fixtures. Anonymous live probe timed out at QQ search; new real-network detail paths and account actions remain unaccepted. |
| Kugou | Native login/library/search/play/lyrics plus new FM recommendations, bounded liked-state checks, heart add/remove and playlist-add routes. Signed-payload/denial fixtures pass; real-account reads/writes and playback remain unaccepted. |
| Qishui | Native QR/MFA/library/feed/search/play/lyrics plus new heart check/toggle, playlist/album collection, playlist-add and comments read/post routes. Method/body/session/denial/cache fixtures pass; real-account writes and full playback remain unaccepted. |
| Local functionality / OS services | Weather, listening reports, local-file import, AutoMix/cuefield, beat-cache and camera gesture paths require individual implementation/validation; desktop wallpaper/window APIs need iOS-specific decisions. |
| Spotify | Removed in paused upstream, active in the separate Mac distribution. Not implemented in this Apple target. Requires an app-owned Client ID/registered callback and actual OAuth acceptance; its metadata support must not be represented as direct Spotify audio. |

Next gate: finish portable feature alignment with the identified Mac line, verify every retained entry in phone/tablet orientations, and perform authorized real-account and sustained device playback checks. Keep issues #14/#15/#16 open.

## Distribution baseline follow-up

The owner clarified that the comparison Mac app was downloaded from the product website, rather than built directly from this checkout. The owner subsequently confirmed the exact domain `https://mineradio.cn/`, inspected on 2026-10-24. That page advertises Spotify and labels the Mac download 2.2.0, while its Mac changelog says 1.1.3 (merged Intel/Apple Silicon package). Its inline download configuration points to Quark share `805e91a9a0ee`, Baidu share `1MaqXaOh2oN39zpx6rIr6hw` and `https://xxhuber.lanzout.com/s/Mineradio-Mac`. These are not the Mac links recorded by upstream's 2.2.0-mac release. No installer from those links was downloaded or executed, so neither code ownership, exact source commit nor working Spotify functionality is established by the website text. Compare the actual distributed binary and corresponding source, rather than declaring parity from version labels, promotional text or dormant source files.

## Reference Mac package and development line

Read-only inspection of the existing `Desktop/Mine radio-MAC-2.2.0/Mineradio-2.2.0-arm64.dmg` identified a separate public repository: [chyzsnb-commits/Mineradio-mac-](https://github.com/chyzsnb-commits/Mineradio-mac-). DMG SHA-256 is `63d8de08512f8a89621919f42a2e71d044a502b4158c70c6d604a37cfb9b64d7` (141,860,193 bytes). It was mounted read-only, statically inspected and ejected; no installation, execution or login occurred. The owner identifies it as the website download; no download-source attribute independently proves that chain.

Its package/update metadata points to that repository. `spotify-api.js`, `desktop/preload.js` and third-party notices match public HEAD `23f232eefe52aea587533d19b812a37dc5019b13` byte-for-byte; main/server/HTML differ, so the exact whole-package source commit is unresolved. This line adds connected Spotify OAuth/library metadata, YouTube Music search/backend, AI stems via Python/ONNX, additional presets/lyric transitions, refreshed home and native local-library import. Spotify audio still uses matching against other providers; actual OAuth/playback was not exercised. Desktop Python subprocesses, filesystem/window/wallpaper interfaces require Apple-specific implementations. Existing Apple public assets have not been replaced by this fork's frontend.

## Current unreleased quality slice — 2026-10-24

- QQ: three detail/comment read routes. Kugou: FM recommendation, heart check/add/remove and playlist add. Qishui: heart check/toggle, playlist/album collection, playlist add, comments read/post. Reuse this repository's provider protocols; no new dependency or personal-account server. Requests reject invalid methods/IDs/bodies and platform denials. Kugou favorite scans are capped; incomplete scans leave unknown states unchanged. Qishui successful writes invalidate local library/cursor caches; missing/malformed status codes never become write success.
- Local diagnostic postlude records existing render counters, media events/backward-time observations, native memory warnings and WebContent termination. Numeric allowlist, 240-record/192 KiB retention, 10-second sampling and off-main disk writes; no song/account/cookie/media URL collection. Host memory excludes WebContent/GPU. This creates evidence, not a claimed crash fix or total memory measurement.
- Apple HTML delivery defers external Google Fonts stylesheets so the interface can parse without waiting for that service. Original HTML on disk and 105 modules remain unchanged; delivered HTML differs only by font-loading attributes. Do not equate source hashes with byte-identical HTML delivery after this policy.
- The real simulator audio run reproduced Apple's main-thread activation warning. Native category/activation operations now execute on a background serial queue and concurrent requests share one activation, retaining retry and later reactivation. A failed-before/passed-after regression verifies thread ownership, coalescing and failure recovery. This removes a known UI blocking path, not the separate WebContent/GPU crash mechanism.
- Actual iPhone 18 Pro / iOS 27 Simulator WebKit checks passed for portrait/landscape controls, native pinch without page zoom, volume hit testing, DIY close, library tabs and explicit/outside close, plus independent idle hide/reveal/dwell. Local WAV playback clock and nonzero analyser signal also passed. Layout drawing is intentionally asleep; these are interaction/audio fixtures, not real provider or sustained rendering acceptance.
- 39 JS tests and 19 native suites passed. Device Debug build, strict signature and packaged 105-module integrity checked separately. New live QQ probe is NOT VERIFIED because the existing search request timed out. No physical-device operation, TestFlight upload or installer replacement occurred; submitted archive 15 is preserved.

Evidence is retained locally under `apps/apple/build/TestResults/quality-20261024/`, with native UI results `quality-phone-complete-20261024.xcresult` and `quality-audio-20261024.xcresult`. The implementation sequence and unresolved gates are in [the quality plan](superpowers/plans/2026-10-24-apple-client-quality.md).

Additional device-size check: both native phone interaction cases also passed on a fresh iPhone 14 Pro / iOS 27 Simulator (`quality-iphone14pro-20261024.xcresult`), covering portrait/landscape controls, native scene pinch, DIY/library dismissal and HUD hide/reveal. This is simulator geometry/interaction evidence, not the owner's physical iPhone or sustained rendering acceptance. Audio-worker replay passed with no runtime warning in its xcresult summary; 39 JS tests and all 19 native suites passed. Source work is saved as `c12bb7c` (provider features) and `1adce64` (UI blocking/diagnostics); no public release was changed.
