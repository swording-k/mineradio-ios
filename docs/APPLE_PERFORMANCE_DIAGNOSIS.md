# Apple performance investigation — 2026-10-22

Tracking: #14, #15. Branch: `codex/ipad-client`. This is a diagnosis record, not a performance fix or device acceptance.

## Current report

The owner reports submitting build 0.4.6 (14) for TestFlight beta review, but App Store Connect submission/status was not independently inspected. They report severe iPad lag, repeated playback restarts and eventual WebContent-termination UI. Simulator interaction tests and signed builds do not establish sustained iPad playback.

The local archive dated 2026-10-22 02:56 identifies version 0.4.6 / build 14. Archive presence does not prove which binary Apple received.

## Read-only evidence

Device inventory identifies iPad Air (4th generation), `iPad13,1`. No app was installed, launched or operated. Crash-log listing and copying were read-only. Raw device reports stay outside Git; no accounts, cookies or device identifiers are recorded here.

Jetsam reports use a 16,384-byte page size. Values below are resident pages or lifetime maximum pages converted to MiB, not JavaScript heap measurements. Lifetime maxima are not simultaneous totals.

| Report | Same-coalition process | Resident MiB | Lifetime max MiB | Report reason |
| --- | --- | ---: | ---: | --- |
| 2026-10-20 00:19:22 | Mineradio | 29.6 | 44.8 | none |
| same | WebContent | 538.5 | 1249.3 | none |
| same | GPU | 303.6 | 303.6 | highwater |
| 2026-10-21 18:06:30 | Mineradio | 42.3 | 61.0 | none |
| same | WebContent | 1414.5 | 1448.5 | none |
| same | GPU | 300.1 | 300.1 | highwater |

A second GPU process in the latest report belongs to a different coalition and is excluded. The 2026-10-19 16:09:57 event killed pointeruid, not Mineradio; it is not evidence of a Mineradio termination.

On retrieval, the newest available JetsamEvent was 2026-10-21 18:06:30 and the WebKit filename filter returned no separate reports. These reports predate build 14 and do NOT establish the precise cause of its newly reported restart. Absence of a newer report does not mean no current failure.

## Source findings

- `OriginalPlayerView.Coordinator.webViewWebContentProcessDidTerminate` emits the resource-reduction message for any WebContent termination. It neither measures memory nor distinguishes GPU termination, WebContent memory limit, crash or other exit causes.
- PlayerHost only replaces its WebView on the explicit Retry action. The termination handler does not automatically reload; repeated song restart still needs a correlated media timeline, navigation and GPU/WebContent event trace.
- Playback and the visual scene live inside the same WKWebView. Their lifecycle remains coupled: rendering process loss can take the media element with it. This is a risk, not proof of the cause of every restart.
- Original Three.js rendering, canvas-backed lyric textures, cover textures and particle buffers are retained. The Apple 24 MiB cap covers only the optional high-quality lyric pool, NOT all textures, JS memory or GPU memory.
- Whole-track PCM/beat analysis and whole-song lyric runway were already disabled in Apple adaptation. Those changes did not provide sustained physical iPad acceptance.

## Required next evidence and architecture decision

Do not apply another blanket quality reduction and claim resolution. Reproduce on the physical baseline only when authorized; preserve the user's manual-device-testing boundary. Collect sanitized frame time, rendered pixels, texture/geometry counts and estimated bytes, lyric resident-row counts, audio element/buffer counts, native process memory and WebContent/GPU exit timestamps. Native host memory alone misses the large WebKit child processes.

Use repeatable A/B runs of the same track with lyrics, cover/particles and audio preloading isolated. Identify live allocation ownership and growth before setting bounded mobile budgets. Preserve the original artistic design; reduce only measured expensive resolution/count/preload paths adaptively.

Evaluate native audio ownership separately from the WebView so render recovery can preserve playback/position. This is a larger architecture change and has not been implemented. Do not promise a full native visual rewrite or that a wrapper alone makes desktop resource use mobile-safe.

Acceptance proposal: baseline iPad portrait/landscape; at least 30 minutes continuous playback with repeated track changes and seeking; no unintended restart, WebContent/GPU exit or unbounded memory growth; controls remain responsive. This is our engineering gate, not an Apple-published TestFlight threshold. Current iPad performance remains OPEN; do not describe the build as stable.

Apple references: [Jetsam reports](https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports), [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Review rejection messages](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages/).
