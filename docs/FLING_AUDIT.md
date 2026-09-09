# Fling → inSync Audit

Read-only inspection of `pratheepkumar1207/fling-flutter-app` (Flutter client), `fling-backend-FINAL` (Node/Express backend), and `fling-admin-dashboard` (React admin), performed before any inSync integration work. No files were modified to produce this document.

**Headline finding: this is not a greenfield build.** Fling already implements the large majority of the feature surface the inSync spec describes — games (chess, ludo), gifts, wallet/coins/KYC/cashout/VIP/referral/spin-wheel, live broadcast, swipe-based discovery/matching, communities, messaging, calls, a separate React admin dashboard. The genuinely missing/weak piece is the **persistent cross-mode Party session and a unified playback session that survives lock/PiP/background** — which is also exactly what the inSync source package (see `INSYNC_MIGRATION_MAP.md`) is scoped to. Treat this audit's job as: confirm what's real, find what's actually broken, and scope the integration to that — not as justification to rebuild features that already work.

Also note: the app is already **partially rebranded**. `pubspec.yaml`'s `description` and the app icon (`assets/icon/insync-icon.png`) say "Insync"; `RoomPresenceService`'s Android notification text says "in an Insync room." The Flutter package name (`fling`), Android `applicationId` (`com.fling.app`), and iOS bundle id (`com.fling.fling`) are not renamed.

## 1. Existing architecture

Flutter 3.44, Dart SDK `>=3.3.0`. State management: `provider` (`ChangeNotifier`-based controllers), not Riverpod/Bloc. Navigation: standard `Navigator`/`MaterialPageRoute`, not GoRouter. No `features/{domain,data,application,presentation}` layering convention anywhere except the one module I added in a prior session (`lib/features/player/`, native Media3 adapter — see §11). Everything else lives under:

- `lib/screens/<area>/` — one folder per product area (party, wallet, discover, feed, communities, calls, messages, etc.), each mixing UI + controller logic in the same files.
- `lib/core/` — cross-cutting services: `api_client.dart` (REST base URL + auth header), `socket_service.dart` (Socket.IO connection), `active_room_holder.dart`, `background_audio_handler.dart`, `pip_service.dart`, `room_presence_service.dart`, `auth_provider.dart`, `supabase_service.dart`, `google_auth_service.dart`, `google_content_service.dart`.
- `lib/models/`, `lib/widgets/`, `lib/theme/`.

Backend: Node/Express + Sequelize (SQL, via `src/config/db.js`) + raw Socket.IO (`src/sockets/syncHandler.js`, ~1360 lines, one file handling room join/leave/playback/queue/chat/polls/games/calls/host-transfer). 42 Sequelize models, ~28 REST route files. Hosted on Railway (`fling-backend-production-581f.up.railway.app` — confirmed live base URL in `api_client.dart`).

Admin: separate React/Vite project (`fling-admin-dashboard`), not part of the Flutter app.

## 2. Existing features (confirmed present, not aspirational)

- **Games**: `lib/widgets/chess_board.dart`, `ludo_board.dart`, `game_board_view.dart`; backend `src/games/chess.js`; socket events `game:join/move/reset`. UNO-style/quiz/trivia not found — likely genuinely absent.
- **Gifts/economy**: `lib/screens/wallet/` (wallet, buy, cashout, KYC, VIP store, spin wheel, referral, livestream dashboard), `lib/widgets/gift_bottom_sheet.dart`, backend `Transaction` model (typed enum incl. `gift_sent`/`gift_received`/`cashout_*`, Razorpay order/payment ids, `status: pending/completed/failed`) plus `webhook.js` for payment verification. This already satisfies most of spec Step 22's "server-side, transactional, idempotent" requirement — it is not a stub.
- **Live**: `lib/widgets/live_video_view.dart`, `live_tab.dart`, `LiveBroadcastController` (referenced from `ActiveRoomHolder`), Agora-backed.
- **Voice**: `agora_rtc_engine: 6.3.2` (pinned exactly — newer versions ship a native manifest-namespace collision that breaks Android's manifest merger; documented in `pubspec.yaml`). This is already a real WebRTC/SFU integration, not something to build from scratch.
- **Matching/Discover**: `lib/screens/discover/` — swipe cards, map-based explore (`flutter_map`/OpenStreetMap, no paid API key), random match.
- **Communities, Messaging, Calls**: present as full screen sets (`communities/`, `messages/`, `calls/` incl. `direct_call_controller.dart`).
- **Reels-equivalent**: `lib/widgets/reels_feed.dart`, `feed_screen.dart`.
- **Karaoke**: not found anywhere in `lib/` or the backend. Genuinely absent — spec Step 14 would be new work, not integration.
- **Camera/AR/effects**: not located in this pass; needs a dedicated look before Step 16 — not covered by this audit's scope (party/playback-focused).

## 3. Existing Party implementation

`ActiveRoomHolder` (`lib/core/active_room_holder.dart`) is Fling's existing answer to spec Step 3's `PartySession` — a **static, app-lifetime holder**, not a widget or a per-screen object:

- Holds `roomId`, `roomTitle`, `RoomSocketController controller`, `VoiceChatController? voice`, `LiveBroadcastController? live`, raw `room` map.
- `hasActive`, `activeLabel` (ValueNotifier, drives AppShell's mini-bar), `isRoomScreenVisible` (ValueNotifier — true only while `PartyScreen` is the on-screen route).
- `set(...)` is called once a join succeeds; `leave()` is the **only** real teardown path (disposes controller/voice/live, stops `RoomPresenceService`, stops background audio) — explicitly documented as "never call from a plain screen pop."
- `PartyScreen.dispose()` only calls `ActiveRoomHolder.leave()` when the user explicitly chose "Leave Room" (`_didLeaveRoom` flag); a back-navigation/minimize leaves the room socket, players, and voice/live controllers running.

**This already satisfies the spirit of "the Party is not a route, it's a persistent session object" and "changing screens must not recreate the Party."** What it does NOT have: an explicit `PartyMode` concept (watch/voice/music/karaoke/game/live as one first-class field with a change-mode operation) — mode today is implicit in which screen/controller is active, not a single state machine. That is the real gap against spec Step 3.

`RoomSocketController` (`lib/screens/party/room_socket_controller.dart`) is the actual realtime brain: a `ChangeNotifier` (not a `Stream`-based API) exposing `roster`, `messages`, `queue`, `poll`, `playback`, `skipVote`, `addVotes`, `hostId`, `call`, `game`, `settings`, `serverTimeOffsetMs`/`correctedNowMs` (NTP-lite clock sync), plus methods for playback (`play/pause/seek`, host-gated), queue (`queueAdd/Init/Jump/Remove/Next/Skip`, `voteSkip/voteAdd/unvoteAdd`, `queueReorder`), roster/host (`makeHost`, `kick`), mic (`micOn/Off`, `requestMic/approveMic/denyMic/removeMic/forceMute/forceUnmute`), chat, polls, and games.

## 4. Existing playback implementation

Three independent player widgets, each owning its own `WidgetsBindingObserver` (except one, see below), talking to `RoomSocketController` via callbacks (`onPlay`/`onPause`/`onSeek`/`onRequestState`):

- **`sync_video_player.dart`** (YouTube) — `flutter_inappwebview` navigated to this app's own `/youtube-embed.html` (backend-hosted IFrame API wrapper), not a YouTube Flutter package (both `youtube_player_flutter` and `youtube_player_iframe`'s spoofed-`baseUrl` trick stopped working — documented in the file's own header comment). Drift correction: rate-nudge for small drift, hard seek for large (added earlier this session).
- **`drive_video_player.dart`** (Drive-hosted files) — native `video_player` (`VideoPlayerController`), same drift-correction pattern.
- **`webview_room_player.dart`** (Netflix/Prime/Hotstar/etc. "browse together" + YouTube Surf) — real embedded WebView, genuinely **no playback sync at all**: DRM'd `<video>` elements don't expose play/pause/seek state to a WebView, so everyone just watches the same page and presses play themselves. This is a hard platform constraint (documented extensively in `Room.js`'s own comments), not a bug.

**Verified via direct grep of every call site (not inference): no lifecycle or dispose callback in any of the three players ever emits `playback:pause` to the socket.** Every `onPause`/`playback:pause` emission traces to a genuine user tap (`_handleTap()` / `_hostTogglePlay()`). `sync_video_player.dart`'s own periodic state-reporter explicitly guards `if (_backgrounded) return;` before it would otherwise report a state change. **This means the specific "app backgrounds → shared party state is incorrectly paused" bug described in the request does not exist today at the socket-emission level.** The real, confirmed problem is narrower and different — see §5.

## 5. Existing realtime implementation — and the actual playback bug

`socket_service.dart` connects to the same Railway base URL as REST, with `{'token': ...}` handshake auth. `syncHandler.js` is the single backend file handling every room event.

**What actually breaks on lock/background, precisely:**

1. **Drive rooms**: `DriveVideoPlayer.didChangeAppLifecycleState` on `paused` schedules a **300ms-delayed** `_handoffToBackgroundAudio()` (skipped if PiP is active), which pauses the local `VideoPlayerController` and then calls `BackgroundAudioHandler.loadAndPlay(url, headers, initialPosition, ...)` — a **fresh** `just_audio` `setAudioSource()` + `play()` against a **second, separate player instance**, re-streaming from `/drive/stream/:fileId` from scratch rather than continuing a warm source.
   **Correction after deeper reading (see `PLAYBACK.md`):** the 300ms delay itself is *not* the bug — it's a deliberate, previously-shipped fix for a worse, confirmed-live regression (immediate handoff paused the video the instant auto-PiP was entered, since `PipService.isInPip` only flips true asynchronously for the home-button PiP path; the delay-plus-recheck is what stops a genuine PiP dip from being misread as a real backgrounding). **Do not shorten or remove it.** The actually-fixable part is narrower: the *cold reload* once a handoff is confirmed genuine (fresh network source instead of a pre-warmed one) is the real, audible-gap-causing piece, and even that needs device-level profiling to fix safely — not done blind. See `PLAYBACK.md` for the full reasoning and why this was deliberately not touched further this phase.
2. **iOS has no `UIBackgroundModes` key in `Info.plist` at all** (confirmed: zero matches for `UIBackgroundModes`/`Background` in the file). This means even the real, working Android background-audio infrastructure (`FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission, `audio_service`) **cannot run in the background on iOS today** — the OS will suspend the process outright. This is a genuine, previously undocumented gap, not a design choice, and is cheap to fix (add the `audio` background mode).
3. **YouTube rooms have no background-audio path at all** (`BackgroundAudioHandler` is explicitly Drive-only — YouTube's terms require the player stay visible, and this was a deliberate decision documented in the handler's own header comment, confirmed accurate: WebView-hosted YouTube iframes get suspended by the OS the moment the app backgrounds, and there is no legitimate way to keep YouTube audio playing without the video surface visible). On resume, `sync_video_player.dart` correctly calls `widget.onRequestState()` to re-sync to the authoritative server position rather than restarting from zero — **this is the correct fallback given the platform constraint, not a bug to fix**, but it will still look/feel like "it stopped and now it's catching up," which is what a user would describe exactly the way this request's Step 5 does. This needs to be communicated as a hard platform limit for YouTube specifically, distinct from the genuinely fixable Drive/iOS issues above.

`PipService` (`lib/core/pip_service.dart`) is already architected correctly per spec Step 7: entering/exiting PiP only changes rendering (swaps to a bare-video `Scaffold`) and is read by the players purely to suppress their normal background-handoff logic — **it never calls play/pause/seek itself.** No rework needed here; this is a case where the existing implementation already matches the target architecture.

## 6. Existing database/API

Sequelize models (42) over a SQL database (dialect set via `src/config/db.js`, not inspected in this pass) — **not** Supabase Postgres. Supabase is used **only** for one auth path: Google Sign-In via `supabase_flutter`, verified server-side against `/auth/supabase`, which issues this app's own JWT. Confirmed via direct search: zero `.from(`, `.channel(`, or Supabase Storage calls anywhere in `lib/`. Any migration or architecture that assumes Supabase Postgres/Realtime is the party/queue/playback datastore **does not match reality** — see `INSYNC_MIGRATION_MAP.md`'s note on the inSync package's SQL migration file.

## 7. Existing native integrations

- Android: `MainActivity.kt` extends `AudioServiceActivity` (required by `audio_service`), hosts a PiP method channel (`com.fling.app/pip`), and — as of this session's earlier work — registers a native Media3 `PlatformView` (`fling/media3_player`, see §11). `AndroidManifest.xml` already declares `supportsPictureInPicture`, `resizeableActivity`, and all three foreground-service permissions needed for `flutter_foreground_task` (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`).
- iOS: no custom native Swift/ObjC code found beyond Flutter's default `AppDelegate`; missing the background-audio capability (§5).

## 8. Existing dependencies (selected, from `pubspec.yaml`)

`provider`, `socket_io_client 2.0.3+1`, `firebase_auth`/`firebase_messaging` (phone login + push), `google_sign_in` + `supabase_flutter` (Google login only), `agora_rtc_engine 6.3.2` (pinned — see §1), `video_player`, `flutter_inappwebview 6.2.0-beta.3` (pinned via `dependency_overrides` — stable 6.1.5's Android sub-package uses an AGP-rejected deprecated Proguard API), `audio_service`/`just_audio` (background audio), `flutter_foreground_task` (keep-socket-alive service), `razorpay_flutter`, `geolocator`/`flutter_map`/`latlong2` (no paid Maps key needed). No Riverpod, no GoRouter, no Media3/ExoPlayer Dart package (the native Kotlin integration added this session bypasses the need for one).

## 9. Duplicate/legacy systems

None found that constitute two *competing* implementations of the same concern today — `ActiveRoomHolder`/`RoomSocketController` is the one Party system, there is one Socket.IO client, one playback-drift algorithm (duplicated across two files but not competing — see §12). The one thing to actively avoid creating is a **second** Party/playback authority when integrating the inSync package's `PartyEngine`/`PlaybackSessionManager` skeletons (see migration map).

## 10. Bugs discovered (this pass)

1. **iOS: no `UIBackgroundModes` audio capability declared** — real background audio was currently impossible on iOS regardless of provider. **Fixed** (`ios/Runner/Info.plist`, see `PLAYBACK.md`).
2. **Drive background-audio handoff does a cold source reload** on an otherwise-correct, previously-debugged 300ms disambiguation delay — the delay itself must stay; the cold reload is the real, narrower, audible-gap-causing piece. **Not fixed** — needs device-level profiling to change safely; see `PLAYBACK.md`.
3. `webview_room_player.dart` has no `WidgetsBindingObserver` — not necessarily a bug (there's no sync state to preserve for DRM'd OTT anyway), but worth confirming intentional rather than an oversight before building the unified `PlaybackSessionManager`.

## 11. What can be reused as-is

`ActiveRoomHolder`, `RoomSocketController`'s entire event surface, `PipService` (architecturally already correct), the backend's `syncHandler.js` event set, the Transaction/wallet economy model, Agora voice/live integration, the native Media3 `PlatformView` added earlier this session (`android/.../media3/Media3PlayerView.kt` + `lib/features/player/`) — this already provides the `VideoPlayerAdapter`-shaped interface the inSync `PlaybackAdapter` skeleton wants, just under a different name (see migration map).

## 12. What needs refactoring

- Introduce an explicit `PartyMode` on top of `ActiveRoomHolder` rather than inferring mode from which controller is non-null.
- Reconcile the **two** drift-correction implementations (`sync_video_player.dart` and `drive_video_player.dart` each have their own `_checkDrift`) behind one shared `PlaybackSessionManager`/`RoomClock`-style component, per spec Step 6 — not a bug today (both are correct and were written together), but duplicated logic that a unified `PlaybackSessionManager` should absorb.
- The iOS background-audio capability gap (§5.2) is fixed. The Drive cold-reload piece of §5.1 is understood but deliberately not touched without device-level verification — see `PLAYBACK.md` for why retrofitting either existing player's lifecycle handler onto the new `LifecycleCoordinator` was deferred this phase rather than attempted blind.

## 13. What needs replacement

Nothing found that needs outright replacement rather than wrapping/refactoring. The existing Party and playback systems are functionally sound; the gap is a missing unifying abstraction and two concrete, scoped bugs, not broken foundations.

## 14. Migration risks

- `ActiveRoomHolder` is a **static class**, referenced directly from `party_screen.dart`, `persistent_room_audio.dart`, and `app_shell.dart`. Wrapping it behind a new `PartyEngine` interface must preserve every one of those call sites' behavior (especially `isRoomScreenVisible`, which `PersistentRoomAudio` depends on to avoid double audio) — this is the highest-risk single file to touch.
- `RoomSocketController` extends `ChangeNotifier`, not `Stream`-based; the inSync `PartyRealtimeAdapter` interface expects `Stream<Map<String, dynamic>> events(...)`. Bridging this needs a thin adapter (subscribe to `notifyListeners` and re-emit a synthetic stream), not a rewrite of the controller.
- The inSync package's Supabase migration (`0040_insync_final_domains.sql`) defines `party_sessions`/`party_queue`/`playback_state` tables — these **must not** become the source of truth for live party/queue/playback state, since the real backend already owns that via Sequelize + in-memory `Map`s in `syncHandler.js`. Applying that migration as-is would create a second, disconnected data model. (Detailed in `INSYNC_MIGRATION_MAP.md`.)
- No Android emulator or physical device is available in this environment (confirmed in a prior session: `flutter emulators` reports none, and no system images are installable — likely the same virtualization limitation that also blocks Docker Desktop here). All playback/lifecycle work can be compile-verified (`flutter analyze`, `flutter build apk`, Kotlin `compileDebugKotlin`) but **not** runtime-verified end-to-end (lock screen, Bluetooth routing, audio focus, PiP transition timing) until tested on a real device — spec Step 35 cannot be satisfied from this environment.
