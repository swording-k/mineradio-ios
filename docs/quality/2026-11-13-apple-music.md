# Apple Music candidate 1.0.3 (24)

## Scope
- Native MusicKit authorization, subscription check, personal songs/playlists, catalog song search, paged song loading and protected playback.
- Apple-only platform entries open a SwiftUI music browser. Native queue follows the songs loaded at playback start. Loading more songs updates the browser; restart playback to adopt the expanded queue.
- Existing cover stage/native transport receives metadata, artwork and progress; no protected audio URL is extracted. Source transitions pause the old engine. Lyrics and PCM-based spectrum/beat analysis are not implemented. Library initially loads up to 100 playlists; playlist pagination is still a limitation.
- MusicKit App Service must be enabled for the existing App ID in the developer portal. This has not been checked or changed in this session. No secret/token is embedded. No filing claim.

## Verification
- 75 Apple JavaScript tests passed, including native state clock/queue, transport/seek, source handoff, failed handoff, and invalidating old web playback.
- Native media policy test passed for Apple artwork allowed paths and deceptive-host rejection, with existing provider boundaries intact.
- Release iOS device-target build and code signing succeeded; bundle 1.0.3 (24) includes NSAppleMusicUsageDescription.
- iPhone simulator Debug build launched. A real bundled-web Apple Music button handler was invoked by the debug inspector and opened the native authorization sheet. Local screenshots: .inspect/apple-music-20261113/iphone-entry.png and iphone-library.png. This verifies entry/presentation, not real authorization or playback.
- No physical device installation or operation, no subscription/real-account acceptance, no TestFlight upload.

## Physical acceptance
Enable MusicKit App Service first. Use an Apple Music subscriber: grant/deny permissions, load library, open playlist, search songs, start playback, pause/resume/seek/skip, change to a different platform and back; verify one source at a time. Check iPhone/iPad rotation, locked/background audio, headset interruptions and artwork. Empty libraries, non-subscribers and network errors must report their state. Original desktop code is unchanged.

## Rollback
Previous source baseline is 80a1d8e. Work is isolated on feat/apple-music-20261113. Generated project/Info.plist are rebuilt from project.yml and remain ignored as before.
