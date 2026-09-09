# inSync Migration Map

Compares `inSync_COMPLETE_SOURCE_PACKAGE.zip` (extracted, inspected file-by-file) against the real repository audited in `FLING_AUDIT.md`.

## What the package actually contains

Its own `docs/MASTER_STATUS.md` is explicit about this, and direct inspection confirms it: **"Architecture: COMPLETE, Source foundations: GENERATED, Actual Fling repository integration: NOT YET MERGED."** The package is 19 files: 6 documentation files (README, 3 backend `.md` stubs, 1 admin README, 4 `docs/*.md`), one `MANIFEST.json`, 12 Dart files (interfaces + minimal implementations for the party/playback/media domain layer only — no UI, no camera/AR/karaoke/games/matching/messaging/economy/admin code despite the README and `FEATURE_MATRIX.md` listing all of those as "included"), one Supabase migration, and one placeholder test file whose two assertions are tautologies against hardcoded literals, not tests of real behavior.

**Read the README/FEATURE_MATRIX contents literally and you'd conclude far more was delivered than actually exists in the zip.** Treat this migration map as covering only the Dart files that are actually present: `PlaybackSession`, `PlaybackAdapter`, `PlaybackSessionManager`, `PlaybackSurface`, `LifecycleCoordinator`, `RoomClock` (all under `lib/core/playback/`), `MediaSource`, `MediaProvider` (`lib/features/media/domain/`), `PartySession`, `PartyEngine`, `PartyQueue`/`QueueItem` (`lib/features/party/domain/`), `PartyRealtimeAdapter` (`lib/features/party/data/`), and one SQL migration.

## Module-by-module map

### PartySession / PartyEngine

- **Zip**: `PartySession` is an immutable data class (`roomId`, `sessionId`, `hostId`, `mode: PartyMode`, `members: List<PartyMember>`, `playback: PlaybackSession?`, `queueVersion`, `connected`). `PartyEngine` is an `abstract interface class` (`current`, `join`, `leave`, `changeMode`, `sendMessage`, `sendReaction`) with **no implementation provided**.
- **Existing**: `ActiveRoomHolder` (static holder — see audit §3) + `RoomSocketController` (`ChangeNotifier` with the real event surface).
- **Migration strategy**: Do not replace `ActiveRoomHolder`. Add a `PartySession` snapshot type (adopt the zip's shape, add the missing `PartyMode`) that `RoomSocketController` can produce from its existing fields on demand, and a concrete `PartyEngineImpl` that wraps `ActiveRoomHolder`'s static calls (`join` → existing room-join flow, `leave` → `ActiveRoomHolder.leave()`, `changeMode` → new, since no explicit mode concept exists yet). `current` reads `ActiveRoomHolder`'s live state, not a separately-tracked copy, to avoid two sources of truth.
- **Files affected**: new `lib/features/party/domain/party_session.dart`, `party_engine.dart`; new `lib/features/party/data/party_engine_impl.dart` wrapping `active_room_holder.dart` + `room_socket_controller.dart`. No changes to the existing files' public API needed for this step.
- **Risk**: Low if additive. High if `ActiveRoomHolder`'s static fields are removed/replaced instead of wrapped — three files depend on them directly (audit §14).

### PartyRealtimeAdapter

- **Zip**: `abstract interface class PartyRealtimeAdapter { connect, reconnect, disconnect, events (Stream), emit }`. No implementation.
- **Existing**: `socket_service.dart` (raw connection) + `RoomSocketController` (typed event handling via `ChangeNotifier`, not a generic `Stream<Map>`).
- **Migration strategy**: exactly what spec Step 4 asks for — implement `PartyRealtimeAdapter` as a thin wrapper that calls into the *existing* Socket.IO client, translating `notifyListeners()`-style updates into a synthetic broadcast `Stream<Map<String, dynamic>>` for anything genuinely generic (e.g. a future cross-cutting logger), while `RoomSocketController`'s own typed methods (`play`, `queueAdd`, `voteSkip`, etc.) remain the real call sites the UI uses — the adapter does not replace them, it's a secondary generic-access facade. **Do not rewrite `syncHandler.js` or the socket event names.**
- **Files affected**: new `lib/features/party/data/socket_party_realtime_adapter.dart`. Zero backend changes required for this step.
- **Risk**: Low — purely additive if scoped as above.

### PlaybackSession / PlaybackSessionManager / PlaybackAdapter / LifecycleCoordinator / RoomClock

- **Zip**: Clean, small skeleton. `PlaybackSession` (immutable snapshot incl. `expectedPosition(serverNow)` — same drift formula as `RoomClock`, duplicated between the two zip files themselves). `PlaybackAdapter` (interface: `providerId`, `capabilities`, `initialize/load/play/pause/seek/position/setSurface/snapshot/dispose`). `PlaybackSessionManager` (holds one `PlaybackAdapter`, tracks `PlaybackSurface`, delegates play/pause/seek, `enterPip`/`enterBackground`/`enterForeground` only ever call `adapter.setSurface(...)` — **never** play/pause — which is exactly spec Step 5's critical rule, correctly implemented). `LifecycleCoordinator` maps `PlaybackIntent` (enteringPip/leavingPip/enteringBackground/returningForeground/etc.) to `PlaybackSessionManager` surface calls only.
- **Existing**: This session already built `lib/features/player/` (`VideoPlayerAdapter`, `VideoSource`, `PlaybackStateSnapshot`, `Media3PlayerAdapter`, native `Media3PlayerView` Kotlon platform view) — functionally the same role as the zip's `PlaybackAdapter`, different shape (method names, no `providerId`/`capabilities`/`setSurface`). Plus the real, working (if imperfect) lifecycle handling already inside `sync_video_player.dart`/`drive_video_player.dart` (audit §4-5), which does the right thing today (no lifecycle-triggered shared-pause) but duplicates drift-correction logic per-player instead of in one shared manager.
- **Migration strategy**: **This is the one place two competing implementations now exist (mine from last session, and the zip's) — reconcile, don't stack a third.** The zip's `PlaybackAdapter`/`PlaybackSessionManager`/`PlaybackSurface`/`LifecycleCoordinator`/`RoomClock` shape is the better target (it already models PiP/background/foreground as first-class surfaces, which my earlier `VideoPlayerAdapter` didn't need to since it was scoped to "just get Media3 compiling," not the full lifecycle problem). Plan: adopt the zip's `PlaybackSession`/`PlaybackAdapter`/`PlaybackSessionManager`/`PlaybackSurface`/`LifecycleCoordinator`/`RoomClock` files as the target interfaces, and make `Media3PlayerAdapter` (already built, already Gradle-compiles) implement the zip's `PlaybackAdapter` shape instead of my prior `VideoPlayerAdapter` shape — a rename/reshape, not new native code. Then wire `sync_video_player.dart`/`drive_video_player.dart`'s existing lifecycle observers to call into a shared `PlaybackSessionManager`/`LifecycleCoordinator` instead of each having its own bespoke `AppLifecycleState` handling — this is where the Drive 300ms-delay bug and the iOS `UIBackgroundModes` gap actually get fixed, in one place instead of two.
- **Files affected**: supersede `lib/features/player/domain/video_player_adapter.dart`'s role with the zip's `PlaybackAdapter` (keep `VideoSource`/`PlaybackStateSnapshot`, reshape to match); add `lib/core/playback/` (session, adapter, manager, surface, lifecycle_coordinator, room_clock) adapted from the zip; modify `sync_video_player.dart` and `drive_video_player.dart` to delegate lifecycle handling to `LifecycleCoordinator` instead of their own `didChangeAppLifecycleState` bodies; fix `ios/Runner/Info.plist` (add `UIBackgroundModes: [audio]`); fix `background_audio_handler.dart`'s handoff delay/cold-reload.
- **Tests required**: the zip's `invariants_test.dart` pattern, made real — assert against actual `LifecycleCoordinator`/`PlaybackSessionManager` behavior (e.g. "enteringPip never calls adapter.pause()") instead of hardcoded literals.
- **Risk**: Medium-high — this touches the two live, working room players. Must be done incrementally per file, compiled after each change, and (per audit §14) cannot be runtime-verified in this environment — real-device testing before shipping is mandatory, not optional, for this module specifically.

### MediaSource / MediaProvider

- **Zip**: `MediaSource` (id, title, type: youtube/drive/web/ott/insync/authorizedAudio, provider, url, `backgroundAudio`/`pip`/`foregroundVideo` capability flags). `MediaProvider` interface (`search`, `resolve`).
- **Existing**: `lib/core/room_source_types.dart` + backend `Room.sourceType` enum (`youtube`, `drive`, `netflix`, `amazon`, `youtube_surf`, `hotstar`, `aha`, `sunnxt`, `sonyliv`, `airtel_xstream`) — a richer, real enum than the zip's 6-value one, already reflected in the source picker UI.
- **Migration strategy**: extend the zip's `MediaSourceType` to match the real backend enum (don't shrink real capability to fit the skeleton) and derive the `backgroundAudio`/`pip`/`foregroundVideo` flags per-type from what's actually true today (per audit §4-5: Drive → `backgroundAudio: true`, YouTube → `backgroundAudio: false`, all OTT/webview types → `pip: false, backgroundAudio: false`).
- **Files affected**: new `lib/features/media/domain/media_source.dart`, `media_provider.dart`; no changes to `room_source_types.dart` needed, just a mapping function between the two.
- **Risk**: Low.

### PartyQueue / QueueItem

- **Zip**: minimal (`items`, `currentIndex`, `version`, `current` getter).
- **Existing**: `RoomSocketController.queue` + full backend queue system (`queueAdd/Init/Jump/Remove/Next/Skip`, majority vote-to-skip/vote-to-add, already covers spec Step 11's "add/remove/reorder/next/skip/skip voting/versioning").
- **Migration strategy**: the existing system already exceeds the zip's skeleton (it has voting, the zip doesn't). Add the zip's `PartyQueue`/`QueueItem` as a typed snapshot view derived from `RoomSocketController.queue`'s existing raw map, not a new queue implementation.
- **Risk**: Low.

### Supabase migration (`0040_insync_final_domains.sql`)

- **Zip**: creates `party_sessions`, `party_queue`, `playback_state`, `usage_daily`, `admin_audit_log` tables in Supabase Postgres.
- **Reality** (audit §6): the app's actual party/queue/playback state lives in the Node backend's Sequelize models + in-memory `Map`s, not Supabase. Supabase today is Google-Sign-In auth only.
- **Migration strategy**: **do not apply the `party_sessions`/`party_queue`/`playback_state` table creations.** They would create a second, disconnected data model with nothing reading or writing to it — direct violation of the "do not leave two competing systems" rule this whole request is built around. `usage_daily` and `admin_audit_log` are plausible candidates for a *future* Supabase-hosted analytics/admin layer (they don't conflict with anything live today), but that decision belongs with Step 29/30 (Cost Guard/Admin), not this phase, and should be evaluated against extending the existing React admin dashboard's own backend access first.
- **Risk**: High if applied blindly — flagged explicitly per the request's own Step 32 instruction ("compare against current database... do NOT blindly create duplicate tables").

## Summary table

| Zip module | Real equivalent | Action |
|---|---|---|
| `PartySession`/`PartyEngine` | `ActiveRoomHolder` + `RoomSocketController` | Wrap, add explicit `PartyMode` |
| `PartyRealtimeAdapter` | `socket_service.dart` + `RoomSocketController` | Thin wrapper, keep existing events |
| `PlaybackAdapter`/`PlaybackSessionManager`/`LifecycleCoordinator`/`RoomClock` | This session's `lib/features/player/` (Media3) + per-player lifecycle code | Reconcile into one shared manager; fix Drive handoff delay + iOS background-audio gap here |
| `MediaSource`/`MediaProvider` | `room_source_types.dart` + `Room.sourceType` | Extend zip's enum to match real one |
| `PartyQueue`/`QueueItem` | `RoomSocketController.queue` + backend vote system | Typed view over existing, richer system |
| SQL migration (party/queue/playback tables) | Sequelize + in-memory Maps | **Do not apply** those three tables |
| SQL migration (`usage_daily`, `admin_audit_log`) | Nothing yet | Defer to Admin/Cost Guard phase |
| Everything else the README/FEATURE_MATRIX lists (camera, AR, karaoke, games beyond chess/ludo, matching, messaging, economy, communities, admin, AI, notifications) | Mostly already real in Fling (audit §2), or genuinely not built | Not in scope for this phase — see "most important execution rule": work in dependency order, starting with PartySession + PlaybackSession only |
