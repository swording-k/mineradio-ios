# Apple provider completion

Goal: Finish provider login, verified session, library and playback paths without requiring a Mac server or changing desktop source. Keep original product UI.

Architecture: Original player invokes an Apple-specific message bridge. QQ/Kugou present isolated official WKWebView login sheets; cookies stay native and are handed to provider actors for remote validation. Qishui Passport cookies remain in the isolated signer and feed a native catalogue adapter; account verification gates login success. Existing native loopback service dispatches provider APIs. Media relay permits each provider's precise CDN boundaries.

- [x] Inspect original desktop official-login implementation and source protocols.
- [x] Implement official login policy, sheet/cancel/popup/session observation and player invocation.
- [x] Implement QQ account/library/search/audio/lyrics adapter with injectable transport and fixtures.
- [x] Implement Kugou equivalent, preserving original H5 signatures and rights.
- [x] Implement Qishui account/library adapter and validate before loggedIn=true.
- [x] Integrate platform media relay/CDN checks, cancellation and session cleanup.
- [x] Run provider fixture tests, anonymous real requests, native builds and simulator UI tests.
- [ ] Verify sustained playback/resources; do not claim private-account success without authorized user completion.

No public installer publication. User has asked to avoid further intermediate acceptance of unfinished features and has not revoked the stop on physical iPad UI control. Real account authorization cannot be fabricated or automated past user authentication.

2026-10-21 evidence: native fixture binaries and JS regressions execute successfully; anonymous QQ/Kugou/Qishui search each returned two records. QQ lyrics returned data. Anonymous playback returned no acceptable URL and remains a rejection, not playback proof. First simulator UI run passed two page/cancel checks; attachment review exposed missing login-panel activation. Follow-up strengthens detection and UI tests. Real private account/MFA/full-playback and old-iPad stability gates are still open.

2026-10-21 final verification: 11 native suites and Apple JS tests passed; iOS device build and codesign verification passed; simulator official sheet/cancel tests passed 2/2. Manual screenshot review confirmed both QQ and Kugou QR images (not authenticated accounts). Desktop npm test passed 222/222 after installing locked dependencies; npm run check passed in Node-only mode. No shared desktop/public source changed. Qishui MFA and full-track signer remain implementation gaps; no installer publication or physical-device interaction.

2026-10-21 follow-up: added the desktop official MFA decision/verification/resend orchestration, a native security sheet, provider-scoped active-challenge transport and cancellation/deadline cleanup. Fixtures cover a successful challenge, cancelled challenge, repeated 2046, URL boundaries and timeout while SDK loading. This is integration/build evidence only; no real user challenge or full-member stream has been verified.

Full-stream source audit (2026-10-21): desktop/qishui-native-playback.js uses the Mac official bdms.node to sign the complete POST /luna/pc/track_v2 request with x-helios/x-medusa. Passport a_bogus is not a replacement. Apple has neither that signer nor authorized encrypted-media processing. The repository has readable qishui-audio-decryptor JS, but porting it alone cannot provide authorized stream URLs and whole-song multi-Buffer processing is unsuitable for old iPads. Public libmssdk (https://github.com/sodahub-org/libmssdk) wraps an external desktop binary; libresoda (https://github.com/sodahub-org/libresoda) still requires that signer. Neither establishes a distributable native iOS solution. Ask upstream for an authorized iOS streaming/signing SDK or documented mobile integration. Do not introduce a remote Cookie/signing service or restore a Mac dependency without an explicit product decision. App Store submission is a separate gate from internal build and user acceptance.
