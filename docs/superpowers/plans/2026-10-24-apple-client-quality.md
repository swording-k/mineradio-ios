# Apple client quality and capability implementation plan

**Goal:** preserve Mineradio's original artistic experience while providing complete, dependable touch-first iPhone/iPad music workflows, balanced resource use and expanded providers.

**Architecture:** retain original public assets and stage; native per-provider adapters implement original API contracts; Apple-only navigation/touch code preserves supported actions. Instrument and isolate playback/render responsibilities before restoring expensive analysis. No user credential proxy.

**Worktree:** codex/ipad-client. **Tracking:** Refs #14, #15, #16. User has requested implementation; no additional design-approval pause is needed for this established direction.

## 1. Baseline and feature inventory

- Use docs/APPLE_FEATURE_PARITY.md as current evidence, task_plan.md for phase status, findings.md for external facts and progress.md for execution.
- Identify mineradio.cn Mac binary/source without replacing the installed app. Record asset/version/SHA/source commit where available. Preserve uncertainty if public download needs account access.
- Completed read-only baseline inspection: existing Mac DMG points to `chyzsnb-commits/Mineradio-mac-`, HEAD `23f232e`. Some members match; exact whole build commit remains unknown. See APPLE_FEATURE_PARITY.md. Align portable features from this line rather than treating paused main as the ceiling.
- Catalogue original UI paths with corresponding native services and touch entry points, including local media, reports, weather, AutoMix, DIY, presets and provider actions. Keep desktop-only OS capabilities separate from portable product features.

## 2. First implementation slice: QQ read paths

Files: apps/apple/Sources/QQMusicNativeAPI.swift, apps/apple/Tests/QQMusicFeatureTests.swift, apps/apple/Tests/QQMusicFeatureLiveProbe.swift, apps/apple/scripts/test-native.cjs.

- Write a failing fixture for original album/artist/comments contracts through handle(), preserving IDs, singers, album covers, durations and comment pagination.
- Reuse original server.js request modules/allowed official hosts. Extend native allowlist only for exact required paths. Reject invalid IDs, methods and nonzero provider codes; never turn denial into an empty successful response.
- Check no personal cookies are required by fixtures/probes; do not publish raw accounts, media URLs or user comments.
- Run meaningful QQ tests and opt-in anonymous reads; if upstream endpoint is denied, record that and investigate instead of claiming success.

## 3. Playback/resource diagnostic foundation

Files: new Apple-only Web diagnostic postlude + native local recorder; OriginalPlayerView message handler and build-web-bundle manifest wiring; native/JS regression tests.

- Collect bounded, allowlisted numeric render/media counters, not raw URL/title/lyrics/account data. Native recorder captures host app footprint, memory warning and WebContent exit; explicitly exclude claims of total WebKit/GPU memory.
- Track media time/backward jumps and source/reload/error events with timestamps; avoid diagnosing a user seek or intentional repeat as a crash. No auto-reload or automatic restart.
- Record when counters are unavailable. Limit sample cadence and file size, suspend sampling in background. No new user-facing technical dashboard.
- Test privacy filtering, bounded retention, event ordering, loop restart detection without content capture, and unchanged playback behavior.

## 4. Remaining functionality and interaction

- Complete Kugou and Qishui supported write/recommendation/comment contracts using original handlers; real-account state changes are manually accepted by owner, not fabricated with fixtures.
- Inventory every button; keep phone main controls compact, place secondary controls in explicit reachable sheet/panel, preserve iPad layout while testing sizing/resizing and safe areas. Add coherent return/close behavior and onboarding/account navigation.
- Research native audio separation with explicit callback/queue/seek/lyrics synchronization and audio session/Now Playing/background interruption behavior. Choose this after diagnostics show current restart ownership.
- Expand Spotify using official authorization, configured callback and token lifecycle. Make provider metadata versus audio capability clear. Do not make a nonfunctional platform tile merely to increase source count.

## Completed current slice

- QQ album/artist/comment reads; Kugou FM recommendation, heart check/toggle and playlist add; Qishui heart check/toggle, playlist/album collection, playlist add, comment list/post. New capability fixtures failed before implementation and pass afterward; signed-in platform acceptance remains open.
- Private diagnostic capture implemented and tested. This does not resolve old-iPad exits. External fonts are deferred after a real WebKit blank-start reproduction; the subsequent actual UI tests pass.
- Actual audio test reproduced a native main-thread activation warning. Move audio-session configuration/activation to a serial worker, coalesce concurrent calls, propagate failure and permit later reactivation; retain the real WAV/media-clock/analyser regression. Old-iPad sustained rendering still needs separate evidence.
- 39 JS checks, 19 native suites, signed device Debug build and packaged module integrity. Simulator portrait/landscape/pinch/library/DIY/HUD tests and local audio-signal check passed. No physical operations/upload.
- Spotify registration dependency checked against official PKCE/quota documentation: application Client ID and exact registered callback are required. Development mode currently allows five allowlisted users and requires Premium for its owner. Author's existing app configuration may be reusable only after confirming callback/access support; do not embed a client secret. Actual integration remains pending.

## 5. Verification and delivery

- Relevant Apple JS/native suites, device build/signature/bundle integrity, simulator actual WebKit touch flows. Shared desktop source changes additionally require desktop checks; this slice is Apple-only.
- Verify long-run original visuals + audio with real provider on actual phone/tablet, including rotation, library/DIY, sleep/interruption/AirPlay where supported. At least 30 minutes without unexpected media reset or WebContent exit, with recorded memory trend/counters.
- Maintain missing/unverified actions and physical evidence explicitly; keep Issues open. Produce a new numbered candidate only after its scope is concrete; preserve approved build 15. No upload or public website replacement during implementation.

Additional device-size check: both native phone interaction cases also passed on a fresh iPhone 14 Pro / iOS 27 Simulator (`quality-iphone14pro-20261024.xcresult`), covering portrait/landscape controls, native scene pinch, DIY/library dismissal and HUD hide/reveal. This is simulator geometry/interaction evidence, not the owner's physical iPhone or sustained rendering acceptance. Audio-worker replay passed with no runtime warning in its xcresult summary; 39 JS tests and all 19 native suites passed. Source work is saved as `c12bb7c` (provider features) and `1adce64` (UI blocking/diagnostics); no public release was changed.
