# Apple feature parity — working record

Refs #14 and #15. Baseline: upstream `d43de565acabfdc1a9c9820a27e81a98ccbebcef`, desktop 2.2.0. The owner reports TestFlight approval for build 15; approval is not feature acceptance. Build 15 remains the submitted candidate; this work does not modify its archive or upload a replacement.

## Corrected source finding

Upstream `9402566` removed Spotify from HTML, provider ordering, startup and Electron IPC, and rejects all `/api/spotify*` calls with `404 PROVIDER_REMOVED`. Its `tests/provider-removal-diy-cinema-preload.test.js` explicitly checks this. The remaining `spotify-api.js` and dormant functions do not constitute supported Spotify integration. Earlier statements that the current desktop source supports Spotify were incorrect. The exact richer Mac distribution the owner saw is not yet identified.

## Scope and implementation sequence

Preserve the original HTML, original ordered JS modules, Three.js stage, DIY and functional interaction design. Extend device-local Swift adapters, without a hosted account proxy or desktop backend dependency. Phone layouts may reposition controls but must retain reachable actions. Never restore full-song PCM allocations blindly to claim visual parity.

- [x] Add 17 NetEase library, album/artist, comment and podcast API routes using installed NeteaseCloudMusicApi payloads and the existing native transport. Implementation is present; real-account writes remain unaccepted.
- [x] Regression checks: unauthenticated writes make no remote mutation, upstream denial remains failure, POST/body/id validation, liked state, album mapping, podcast playable song IDs and pagination.
- [x] Build the Apple target and verify bundled original-module integrity. No physical-device interaction or upload.
- [ ] Compare the identified Mac distribution with current source, separating upstream-removed functions, Apple API gaps, touch access gaps and desktop OS-only functions.
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
| QQ | Existing login/library/search/play/lyric adapter; desktop artist/album/comments and liked-state capability need completion. |
| Kugou | Existing login/library/search/play/lyric adapter; recommendations, hearts and adding to playlists need completion. |
| Qishui | Existing QR/MFA/library/feed/search/play/lyric adapter; hearts, collection, add-to-playlist and comments need completion; full playback remains unaccepted. |
| Local functionality / OS services | Weather, listening reports, local-file import, AutoMix/cuefield, beat-cache and camera gesture paths require individual implementation/validation; desktop wallpaper/window APIs need iOS-specific decisions. |
| Spotify | Removed upstream in 2.2.0 and absent in this Mac's installed HTML. A separately identified distribution may differ; restoring it would be an additional integration, not alignment with current upstream main. |

Next gate: identify the owner's comparison distribution, complete remaining adapters, verify every retained entry in phone/tablet orientations, and perform authorized real-account and sustained device playback checks. Keep issues #14/#15 open.
