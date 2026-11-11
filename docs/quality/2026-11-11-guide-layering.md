# 1.0.1 (22) guide layering and duplicate entry fix

- Removed the duplicate 本地音乐 text button next to the upload icon. Existing upload menu retains import, saved library and clear actions.
- Root cause: original guide z-index 620 is below Apple header/search/panel layers (1100–1500). Raised the entire isolated guide overlay, ordered scrim/ring/card, and kept navigation actions accessible on short screens.
- Native state bridge treats visual-guide-active as a modal so native playback controls yield; the original web bar becomes visible for its guide target.
- Tapping guide navigation no longer triggers the touch library's outside-panel dismissal handler.
- 25 focused tests passed: guide safe viewport geometry, Apple layout interactions and native overlay suppression/restoration.
- Added simulator-only GuideOverlayUITests for actual next/skip taps across rotation. Simulator startup is currently stalled; do not count this as a passed UI test.
- Final unsigned Release device-target build succeeded; product Info.plist verified 1.0.1 (22).
- Physical device verification and submission remain with the user.
