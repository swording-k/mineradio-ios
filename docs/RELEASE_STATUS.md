# Release status

Snapshot: 2026-10-18. GitHub Release assets/tags and linked Issue evidence are the
current distribution and acceptance records; update this snapshot at promotion.

| Channel | Source / package | Status |
| --- | --- | --- |
| Public macOS | `v2.2.0-community.3`, source `26fc655`, Apple Silicon | Developer ID signed, Apple notarized, DMG stapled; Gatekeeper reports `Notarized Developer ID`. Qishui full-playback preview; stability/user acceptance remains pending. |
| Local macOS | Installed runtime from `26fc655`; fix merged via PR #8 | Same app runtime as public community.3. Official Qishui Mac 2.9.1 dependency. Long-run/user acceptance pending; Windows/macOS code checks passed. |
| community.3 channel | tag `v2.2.0-community.3` | User explicitly authorized public preview after the earlier hold; this is not a stable release. |
| Public Windows | upstream `XxHuberrr/Mineradio-paused` v2.2.0 | Original upstream EXE; this community has not performed Windows native acceptance. |
| iPad / iPhone | no public package; development `codex/ipad-client` 0.4.6 (14); local archive 0.4.4 (12) held | User confirmed Netease/Qishui login on iPad on 2026-10-21 and requested internal beta preparation. Icon/archive prepared but not uploaded. User subsequently confirmed iPhone sound works. Builds 11–12 had two passing simulator WebKit tests. Build 13 added compact controls. Build 14 fixes phone panel dismissal, HUD reveal and pinch; 36 JS tests passed; the simulator auto-hide/restore and final pinch/rotation/panel flows passed in separate recorded runs (details in apps/apple/README.md); signed device Debug build 0.4.6/14 and bundle integrity passed; physical orientation/touch acceptance and iPad restart/WebContent exits keep TestFlight upload on hold. QQ/Kugou account flows, Qishui full playback and long-run stability remain unaccepted. |

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
