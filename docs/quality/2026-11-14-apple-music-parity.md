# Apple Music 1.0.3 (25) integrated provider correction

## Root causes and changes
- Build 24 appended plain buttons opening a disconnected SwiftUI browser. Register a full workflow node, system-authorize action, account status, search provider and playlist/tracks bridge in the existing UI; remove the separate native sheet.
- Original virtual playlist grouping and merged search results were limited to known providers. Both now retain extension providers; original built-in provider order is preserved. Tests execute the original functions, not copies.
- Keep Apple playlists after asynchronous original-provider catalog rebuilds. System disconnect clears the app association; revocation remains in Settings. Authorization/catalog errors are not treated as an empty successful library.
- Playback no longer replaces an existing Apple queue with a single song. Native playID uses loaded MusicKit objects, never an HTML stream URL. Renderer retains native source identity and handles late artwork, first-play alpha, play icon and progress.
- Synchronized stage lyrics now read native position with bounded interpolation instead of paused WebAudio.currentTime. The existing NetEase matcher supplies only matching title/artist and close duration; display a matching-source notice. No claim of Apple-provided lyrics or protected PCM analysis.
- Profile errors, no subscription, permission denial, missing cached songs and source handoff failures remain explicit. Initial personal-playlist fetch is limited to 100; native playback queue uses at most 500 loaded Apple songs. These are current implementation bounds, not full parity claims.

## Evidence
- 84 Apple JS regression tests passed, including actual virtual renderer and actual merged search, provider authorization/library merge, strict lyric mismatch rejection, native queue preservation/late art and transport/source switching.
- 228 shared JS tests passed after the two extension-provider changes. This does not represent Windows or macOS physical testing.
- Signed Release device build and Debug simulator build succeeded (verify final product version 1.0.3 / 25).
- Actual bundled WebKit showed the Apple Music workflow card alongside other platforms (local screenshot .inspect/apple-music-parity-20261113/login.png).
- Public iTunes metadata for Coldplay / Yellow was passed as a simulator-only native-state fixture: real Apple artwork reached the original proxy and WebGL renderer (uHasCover=1). Existing matching returned 54 lyric lines. This validates the visual/lyric path, not a subscriber streaming session. Stage screenshot .inspect/apple-music-parity-20261113/stage.png.
- Real-page library fixture initially exposed the omitted-renderer-group bug (array contained Apple playlists but DOM did not); this drove the renderer fix and regression test. Do not count this as real account/library acceptance.
- No physical device operation, no TestFlight upload. Build 25 needs real-account authorize → library → playlist → play/seek/skip → another source → back, plus rotation/background acceptance.

## Git
Baseline e3c0f14 (build 24) remains available. Corrections stay on feat/apple-music-20261113.

Final verification: signed iOS Release product confirms 1.0.3 (25). Final simulator reinstallation succeeded but relaunch/boot readiness became unreliable; the final grouping/search fixes are covered by original-function regression tests, not a second successful live-page library fixture.
