# Mobile navigation WebKit acceptance

Run from the repository: `zsh apps/apple/scripts/mobile-experience-qa/run.sh`.

Requires macOS, Xcode command line tools, Node and Python 3. Uses macOS WKWebView
with a nonpersistent store; does not access a physical phone or music account.
The local server serves the actual original HTML, release web bundle and mobile
CSS. Explicit synthetic fixtures supply playlists, artwork and a 12-second sine
wave. Evidence remains in `.inspect/mobile-experience-qa`.

Asserts primary action hit testing/no horizontal overflow at 320×568, 393×852,
430×932, 507×768, 852×393, 1024×768 and 1398×800. Tests the real welcome gate,
playlist→stage→same playlist, search, tab restoration, stale search rejection,
and original local audio clock plus mini-player pause. The pause assertion waits
for the original player's fade to finish. This does not validate subscriber
playback, iOS safe areas/keyboard/system lifecycle, actual iPad GPU memory, touch
performance, or a specific foldable device. No screenshot is subscriber proof.
