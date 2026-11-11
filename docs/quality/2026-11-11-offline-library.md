# 1.0.1 (21) local audio candidate

## Changes
- Apple-only adapter reuses the original file importer, queue, playback and visualization. No new production dependency.
- Device-local IndexedDB stores selected audio Files; page-local blob URLs are rebuilt when opening the saved library. Multiple import, deduplication and explicit two-tap clear are available from the upload surface.
- Exact DOM slots restore controls across viewport breakpoint changes.
- Apple resize scheduling merges continuous resize events into one pending animation-frame refresh and one settling refresh, preserving non-resize recovery.
- Explicit stream trial status replaces stale catalog/previous playback state; known trial duration bounds the progress display.
- Online provider capabilities remain available. This is not a pure-offline release and no exemption from filing is claimed.

## Verification
- Existing aggregate: 75 JavaScript checks and all 24 native suites passed.
- Updated focused JS run: 20 checks passed (layout, power, trial duration).
- Temporary fake-indexeddb harness verified audio byte persistence, reading in a fresh page context, working blob URL and duplicate import. This is storage-contract evidence, not physical-device playback.
- Release device-target compile without signing; no upload or physical device installation.

## Manual acceptance before submission
1. Import downloaded MP3/M4A/WAV using 本地音乐, verify sound and playback controls.
2. Terminate and reopen. Open 本地曲库, enable airplane mode, play, pause, seek and switch tracks.
3. Verify landscape/portrait on iPhone and iPad, including picker cancel.
4. Clear stored library, terminate and reopen; original source files remain intact.
5. Test quota/storage failure and unsupported codecs. WebKit/OS storage removal or app uninstall removes the library.
6. Cloud-provider documents must be downloaded before offline import.
