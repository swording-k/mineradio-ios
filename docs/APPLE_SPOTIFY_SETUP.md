# Spotify on iOS / iPadOS

The Apple client keeps the original visual frontend in WKWebView. Swift provides
the device-local provider APIs and system account integration; Electron and Node
are not embedded in the iOS application.

## What is implemented

- Application-owned OAuth Authorization Code + PKCE, with a fresh verifier/state,
  a five-minute callback window, exact redirect validation and single-use attempts.
- AuthenticationServices opens the official Spotify authorization page. Passwords
  and browser cookies stay with the system. WebKit receives account metadata only.
- Tokens live in the device Keychain, scoped to Client ID. Refresh requests are
  coalesced; logout invalidates in-flight work. A 401 is retried once, and a 429
  suspends further calls for the indicated interval rather than retrying in a loop.
- Account status, paged playlists / liked songs, search, top tracks, album details,
  library checks/add/remove, playlist create/add/collect. Removed playlist entries
  still advance the paging cursor. Membership remains unknown when Spotify does
  not return `product`.
- Spotify is available in the Apple login, account and search surfaces. Existing
  four-provider flows and shared Windows/macOS modules are preserved.

These are implemented contracts, not a claim of successful live authorization.
The configuration and real-account gates below remain necessary.

## Team configuration

`Client ID` identifies the registered Spotify application. It is public; it is
neither a Spotify account password nor an Apple signing certificate. The Client
Secret must never be embedded in a mobile application. PKCE avoids that need.

The team may reuse an existing registration if its owner permits this Apple
client and registers the exact additional redirect:

```text
com.swordingk.mineradio.apple://spotify/callback
```

Set the Xcode application's `SPOTIFY_CLIENT_ID` build setting to that registration's
32-character Client ID. `project.yml` defaults it to empty. The generated Info.plist
expands this setting into `MineradioSpotifyClientID`; the URL scheme is registered
by the same project specification. Do not edit the generated Info.plist directly.

For a local build without changing project defaults:

```sh
xcodebuild -project apps/apple/MineradioApple.xcodeproj \
  -scheme MineradioApple -configuration Debug \
  -destination 'generic/platform=iOS' \
  SPOTIFY_CLIENT_ID='<public application Client ID>' build
```

Use the same setting for the intended archive. Verify the built Info.plist and
redirect registration before testing. Development-mode user allowlisting and
production access approval are owned by the Spotify application administrator;
a valid Client ID alone does not grant unrestricted public access.

Without this configuration the Apple UI says that team configuration is pending
and disables authorization. Ordinary users are not asked to create developer apps.

## Playback boundary

This integration supplies Spotify metadata and library actions. It does **not**
extract Spotify audio, supply a Spotify DRM stream, or claim that previews are
full tracks. `/api/spotify/song/url` intentionally returns an empty URL and
`playable: false`. The original player then attempts matching through available
music sources with their own account, catalog and playback rights. A match may
be a different release/version, and may be unavailable. Live matching remains an
acceptance requirement; a mocked response or a local WAV cannot establish it.

## Remaining acceptance

- Registered team Client ID + exact callback, successful allowlisted-account login.
- Cancel, revoked/expired session, refresh, restart restoration and logout.
- Private/owned/collaborative playlist access under the application's actual quota
  mode; search paging, liked songs and authorized writes with read-back.
- Authorized matching playback, lyrics, seeking, interruptions and backgrounding
  on physical iPhone and iPad. Long-running resource acceptance is separate.
- New numbered archive and upload only after the next candidate is accepted.
  This source is not the already approved TestFlight build 15 binary.

References: [Spotify PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow),
[application registration](https://developer.spotify.com/documentation/web-api/concepts/apps),
[quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes),
[2026 migration](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide).
