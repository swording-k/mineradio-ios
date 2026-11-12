# 1.0.2 (23) Qishui membership attribution fix

## Change
- `/luna/pc/me` membership scanning now matches the team Mac client: structured fields first, then official response text (`svip_type`, `vip_type`, member labels, expiry-aware structured values remain authoritative first).
- Root cause fixed: iOS previously left membership unknown when the official response used nested member containers it did not visit. Desktop PC `track_v2` full streams were then rejected and playback fell back to public SEO auditions (~30–60s), even for signed-in VIP users.
- Public SEO remains audition-only. Encrypted native-auth candidates and VIP/SVIP boundaries are unchanged.

## Verification
- 228 aggregate JavaScript tests passed after restoring dependencies.
- Native Qishui catalogue behavior suite passed, including VIP/SVIP rejection, public audition boundaries, encrypted-source gating, PC POST/GET/Web fallbacks and expected-ID checks.
- Signed Release iOS device build succeeded; product bundle verifies as 1.0.2 (23).
- Real-device playback still requires user acceptance; this is build evidence, not live platform acceptance.
