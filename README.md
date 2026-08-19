# Fling — Flutter app

Native mobile client for the same Fling backend the web app (`fling-web-app`) talks to — same REST API, same Socket.IO real-time layer, same dark pink/purple theme. Built to run alongside the web app, not replace it.

## Setup

This project ships with `android/` and `ios/` platform folders already generated (Android additionally has a live `google-services.json` wired up — see "Real phone OTP login" below). You'll need the Flutter SDK installed locally; run `flutter pub get` after cloning to fetch dependencies (including `razorpay_flutter`, added for coin purchases — see below).

**Re-verified against the exact pinned SDK (`.metadata`'s `ee80f08bbf` / Flutter 3.44.6):** `flutter analyze` passes with 0 issues, including the new Razorpay checkout wiring (`wallet_buy_screen.dart`) and top-supporters list (`creator_profile_screen.dart`). No Android SDK was available in the environment this was re-verified from, so `flutter build apk` itself wasn't re-run — see the known Android issue below, unchanged from before.

**`flutter build web` currently fails — pre-existing, not caused by the changes in this pass.** Confirmed by building the original commit as-is (before any of the changes described in this README revision): `agora_rtc_engine: 6.3.2`'s web platform file (`global_video_view_controller_platform_web.dart`) references `ui.platformViewRegistry`, a `dart:ui` API that this SDK build no longer exposes (it moved to `dart:ui_web`'s `platformViewRegistry`). This contradicts this README's earlier claim that the web build passed — either the SDK moved out from under that verification, or the verification was run against a different revision than the one now pinned in `.metadata`. Same root cause as the Android issue below (agora_rtc_engine's platform integration code, pinned old to dodge the Android namespace collision), same fix options: wait for Agora to ship a version compatible with both platforms, or swap SDKs.

**Known Android build issue — not fixable from this project:** `agora_rtc_engine`'s bundled native SDK ships two AAR modules (`iris-rtc` and a "full SDK" module) that both declare the Android manifest namespace `io.agora.rtc`. Modern AGP's manifest merger rejects duplicate namespaces outright, and there's no suppression flag for it — confirmed across three different `agora_rtc_engine` versions (6.3.2 / 6.5.4 / 6.6.3) and cross-checked against Agora's own GitHub issues; this is a structural defect in how Agora packages their SDK, not something fixable via `build.gradle`. The Android build with `agora_rtc_engine` temporarily removed compiles clean (proving every other line of app code is Android-buildable) — voice chat is the only thing blocked. Options: wait for Agora to fix their AAR packaging, or swap to a different Agora Flutter wrapper / a different voice-call SDK entirely.

Along the way, fixing Android also required (all already applied in this project, for reference if you hit similar issues elsewhere): capping Gradle's JVM heap in `android/gradle.properties` (the Flutter template's default `-Xmx8G` exceeds many real machines' total RAM), overriding `flutter_inappwebview`'s version (the stable release's Android module uses a deprecated ProGuard API modern AGP rejects), and setting `compileSdk`/`rootProject.extra["compileSdkVersion"]` to 36 (several plugins' transitive `androidx` dependencies need 34+, higher than Flutter's own default).

```bash
cd fling-flutter-app
flutter pub get
flutter run
```

## Architecture

- **`lib/core/`** — `ApiClient` (REST, mirrors the web app's `src/api/client.js` — same base URL, same auth-header/401 handling), `AuthProvider` (token persistence + session state), `SocketService` (Socket.IO connection, same `auth: { token }` handshake as `src/realtime/SocketContext.jsx`).
- **`lib/models/`** — Dart classes mirroring the backend's serialized shapes (`User`, `DiscoverProfile`, `Post`, `Playlist`, `Song`, etc.)
- **`lib/theme/`** — color tokens copied 1:1 from the web app's `src/index.css` `@theme` block. Keep the two in sync if either changes.
- **`lib/screens/`** — one folder per feature area, same split as the web app's `src/pages/`.

The party/room real-time sync (`lib/screens/party/room_socket_controller.dart`) is a direct port of `src/realtime/useRoomSocket.js` — same event names, same payload shapes, talks to the same `syncHandler.js` on the backend without any server changes.

## What's fully wired

Auth (dev-login **and** real Firebase phone OTP — see below), Discover swipe with the flip-card detail view, Home, Feed (post/like/comment/save/**polls**), Profile (bio/gallery/playlists/history/liked/saved, edit form, **referral code generate/redeem**), other-user profiles (follow/friend/DM/block/report, **gifting**, **top-supporters list**), Messages (list + real-time thread), watch-party rooms (YouTube sync, host-controlled play/pause/seek/skip, reorderable queue with search/liked/history/playlist tabs, chat, roster with kick/make-host), voice chat scaffolding (Agora), Lobby (browse/create/join/invite), notifications bell, Wallet (balance, **buy coins via Razorpay checkout**, spin/VIP/cashout/KYC), Communities (**pinned messages**), Events, Leaderboards, Achievements, Challenges, Friends.

## Known limitations / things to finish

These need your own credentials or platform setup — not something to hand-wire without them:

- **Real phone OTP login** — the Dart side is fully wired (`lib/screens/auth/login_screen.dart` calls `FirebaseAuth.verifyPhoneNumber` → `otp_screen.dart` → `AuthProvider.loginWithFirebaseIdToken`), and Android already has native config (`android/app/google-services.json` + the `com.google.gms.google-services` Gradle plugin), so it should work as-is once built against that Firebase project. **iOS** has no `GoogleService-Info.plist` yet, so iOS builds fall back to dev-login until one is added via `flutterfire configure`.
- **Voice chat** — the Agora integration (`lib/screens/party/voice_chat_controller.dart`) is complete but inert until you set `kAgoraAppId` to your own Agora App ID (safe to ship client-side; the actual access-controlled token is still minted server-side). Also currently blocks the **Android** build specifically — see "Known Android build issue" above.
- **Buying coins** — `lib/screens/wallet/wallet_buy_screen.dart` now opens Razorpay's native checkout (`razorpay_flutter`) using the order + key the backend hands back from `POST /wallet/buy/order`, and verifies the result server-side via `POST /wallet/buy/verify` before crediting coins. No client-side Razorpay key needed — the key comes from the backend's own credentials. Not yet live-tested against a real payment (needs the backend's Razorpay account to be in live/test mode).

## Test data

The backend has a dev-only seed endpoint (`POST /auth/dev-seed-test-users`) that creates 10 fully-filled profiles for exercising Discover — see the backend's `src/routes/auth.js`.
