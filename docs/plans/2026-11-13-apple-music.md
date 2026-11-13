# Apple Music integration

Use Apple's MusicKit for authorization, subscription checks, personal library, catalog search, playlist tracks and protected playback. Keep native browser controls responsive on iPhone/iPad; reuse the original cover stage and native transport bar through a narrowly scoped bridge. Pause the WebAudio player before native playback and pause MusicKit before returning to another source. Never expose a protected stream as an HTML audio URL.

MusicKit App Service must be enabled for the existing App ID by the account owner. Add NSAppleMusicUsageDescription; automatic developer/user token management means no secrets in the bundle. Playback, search and account access must be physically verified using an Apple Music subscription. No filing exemption is claimed.

Verification: bridge behavioral tests for state/transport/source switching; compile both iOS targets; device authorization and playback remain acceptance gates. Lyrics and PCM spectrum access are not provided by this integration and must not be faked.
