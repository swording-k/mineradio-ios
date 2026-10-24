# Release status

Snapshot: 2026-10-24 for Apple development; public Mac distribution evidence below was last verified 2026-10-18. GitHub Release assets/tags and linked Issue evidence are the
current distribution and acceptance records; update this snapshot at promotion.

| Channel | Source / package | Status |
| --- | --- | --- |
| Public macOS | `v2.2.0-community.3`, source `26fc655`, Apple Silicon | Developer ID signed, Apple notarized, DMG stapled; Gatekeeper reports `Notarized Developer ID`. Qishui full-playback preview; stability/user acceptance remains pending. |
| Local macOS | Installed runtime from `26fc655`; fix merged via PR #8 | Same app runtime as public community.3. Official Qishui Mac 2.9.1 dependency. Long-run/user acceptance pending; Windows/macOS code checks passed. |
| community.3 channel | tag `v2.2.0-community.3` | User explicitly authorized public preview after the earlier hold; this is not a stable release. |
| Public Windows | upstream `XxHuberrr/Mineradio-paused` v2.2.0 | Original upstream EXE; this community has not performed Windows native acceptance. |
| iPad / iPhone | Owner reports TestFlight approval for 0.4.6 (15); later source is local on `codex/ipad-client` | Approved archive preserved; Apple server status not independently inspected. Unreleased provider/action, startup, audio-worker and diagnostic changes pass 39 JS checks, 19 native suites, device Debug/signature/module integrity, and simulator interaction/audio checks. Account writes, broader parity and sustained physical iPad stability remain open; no replacement upload. |

The user initially held installers, then explicitly requested that the website
provide the Mac build with the Qishui fix. Publish community.3 as a preview and
keep remaining acceptance visible; Windows remains the upstream EXE. On
2026-10-18, replaced the community.3 DMG with the same source/app build after
Apple notarization, stapling, strict signature validation and Gatekeeper
acceptance. Do not promote future stable releases without their own acceptance.

Windows/macOS code checks for the fix passed in run `39024986213`. The baseline
main Windows and macOS QA packaging passed in run `39025140274`; these internal
artifacts are not proof of Windows GUI/audio acceptance or replacements for the
upstream Windows download.

## Acceptance tracking

- [#1 Qishui VIP full playback](https://github.com/swording-k/Mineradio/issues/1):
  local fix; verify common playlists, prolonged playback and platform isolation.
- [#2 memory pressure / crash](https://github.com/swording-k/Mineradio/issues/2):
  mitigation shipped, original crash not yet conclusively resolved.
- [#3 native window lifecycle](https://github.com/swording-k/Mineradio/issues/3):
  full-screen check passed; minimization check and broader lifecycle pending.
- [#4 recommendation semantics](https://github.com/swording-k/Mineradio/issues/4):
  product backlog, not an implemented infinite feed.
- [#5 Windows baseline](https://github.com/swording-k/Mineradio/issues/5):
  shared CI, Windows candidate build and native QA tracked separately.
- [#6 real website demos](https://github.com/swording-k/Mineradio/issues/6):
  recordings/layout only; preserve installer versions.

No above Issue is resolved solely by creating it or merging code. Actual native
results and published version determine when a playback/window issue can close.

- [#10 resilient video playback](https://github.com/swording-k/Mineradio/issues/10):
  native video fallback, cache versions and clearer product/download information.

## 2026-10-22 owner-reported beta submission and iPad regression

The owner reports submitting 0.4.6 (14) for TestFlight beta review; App Store Connect status/upload was not independently verified here. The earlier local hold is an engineering readiness judgment, not a claim that no owner submission occurred. Severe iPad lag, repeated playback restart and WebContent exit remain OPEN. Read-only historical Jetsam evidence confirms prior same-coalition GPU highwater termination and large WebContent residency; it predates build 14 and must not be presented as its current crash proof. See [Apple performance diagnosis](APPLE_PERFORMANCE_DIAGNOSIS.md). No code or physical-device interaction occurred in this diagnostic follow-up.

## 2026-10-24 owner-reported TestFlight approval and feature parity work

The owner reports TestFlight approval after resubmitting build 15; this Apple server status was not independently inspected. The submitted archive is preserved. Subsequent local unreleased source adds 17 NetEase API contracts for library actions, albums/artists, comments and podcasts; 36 Apple JS tests, 13 native suites, an anonymous real-network read probe and a signed device Debug build passed. This does not establish authenticated writes, full desktop parity or physical-device stability. No install, upload or public download replacement occurred. See [Apple feature parity](APPLE_FEATURE_PARITY.md) for the corrected upstream Spotify removal finding and remaining platform gaps. Issues #14/#15 remain open.

Further unreleased work adds QQ detail/comments, Kugou recommendations/library actions, Qishui collections/comments, bounded private diagnostics and deferred external font loading. 39 JS checks, 19 native suites, device Debug build/signature/module integrity and three simulator interaction/audio cases passed; account writes, real provider playback and old-iPad sustained performance remain unaccepted. The richer reference Mac DMG points to a separate development repository, not paused upstream. No new archive/upload/public package was produced; local build number 15 does not imply these changes are in the approved TestFlight binary. See the feature-parity record and quality plan for exact scope.

Additional device-size check: both native phone interaction cases also passed on a fresh iPhone 14 Pro / iOS 27 Simulator (`quality-iphone14pro-20261024.xcresult`), covering portrait/landscape controls, native scene pinch, DIY/library dismissal and HUD hide/reveal. This is simulator geometry/interaction evidence, not the owner's physical iPhone or sustained rendering acceptance. Audio-worker replay passed with no runtime warning in its xcresult summary; 39 JS tests and all 19 native suites passed. Source work is saved as `c12bb7c` (provider features) and `1adce64` (UI blocking/diagnostics); no public release was changed.
