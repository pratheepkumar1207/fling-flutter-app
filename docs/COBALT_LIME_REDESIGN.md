# Cobalt / lime design rollout

## Implemented
- Shared `insync_clay.dart`: sculpted surfaces, raised cobalt/lime icon tiles, responsive section banners, compact route headings.
- Home uses the same shared surface implementation as the rest of the app.
- Feed: section banner and padded clay post cards.
- Discover: sculpted discovery emblem and larger filter control.
- Messages: compact section header and separated clay conversation cards; chat bubbles have subtle depth.
- Profile: elevated profile panel with readable navy surfaces.
- Wallet: cobalt balance card and rewards header.
- Settings: section header, cobalt icon badges and roomier rows.
- Room creation: invitation header, consistent game gradients and readable lime selection markers.
- 27 secondary routes use sculpted headings (friends, communities, events, achievements, challenges, browse screens, notifications, profile editing, settings and wallet flows).
- Watch/voice/game room surfaces, call background, onboarding gradients and shared modal/button/chip styling now use the same palette.

## Scope and validation limits
This is a visual styling rollout. Secondary routes retain their existing content layouts and workflows. Game boards retain their functional game colors. Existing API calls, authentication and playback lifecycle logic were not redesigned in this pass.

No new package or database changes. No release APK, emulator visual pass or full interaction test was performed for this rollout. Per-screen visual review at small sizes and enlarged text remains required before calling the entire redesign production-ready.

## Android validation — 28 September 2026
- Clean rebuilt APK successfully installed and launched on the fling_test emulator.
- Prior invalid Dart-kernel startup failure no longer occurs after rebuilding generated artifacts.
- Emulator exposed a real onboarding overflow at 320 x 640. Replaced fixed-height decorative columns with a scrollable cobalt/lime layout and the existing 3D watch artwork.
- Added a regression check with doubled text size and keyboard inset; all four UI checks pass.
- Flutter analyzer reports no issues after the onboarding correction.
- APK incorporating that correction is being rebuilt. Authenticated screen validation awaits the user's test account; no account was created or authentication bypassed.
