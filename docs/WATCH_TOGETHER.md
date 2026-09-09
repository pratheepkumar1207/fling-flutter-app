# Watch Together (Reel → Party)

Spec: "Reel → Watch With People → Create Party → Media automatically becomes Party context." **This is genuinely greenfield** — confirmed by searching the entire Flutter `lib/` tree for "watch together," "watch with," and "reel" near "party"/"room": zero matches. Nothing partial exists today, not even a stubbed button.

## Why nothing was shipped this phase, precisely

This isn't a UI-only feature. Three real, confirmed facts rule out a quick button:

1. **A Reel's video has no compatible `Room.sourceType`.** `Post.videoUrl` (the backend model Reels use) is a plain, direct, already-playable URL. `Room.sourceType` is a Postgres ENUM with exactly these values: `youtube`, `drive`, `netflix`, `amazon`, `youtube_surf`, `hotstar`, `aha`, `sunnxt`, `sonyliv`, `airtel_xstream` (`src/models/Room.js`). None of these fit: `youtube` expects a YouTube watch URL; `drive` is Drive-specific in a way that matters (below); the rest are DRM/webview "browse together" platforms with no sync at all. There is no "just play this direct URL" sourceType.

2. **`DriveVideoPlayer` cannot be pointed at a Reel's URL despite superficially looking like the right fit.** Its `videoUrl` constructor parameter is not actually a URL — it's a bare Google Drive file id, used to build a Drive-specific proxy endpoint: `'${ApiClient.baseUrl}/drive/stream/$fileId?roomId=...'` (`drive_video_player.dart`). Handing it a Reel's already-complete direct URL would make it request `.../drive/stream/https://.../reel123.mp4`, which is nonsense — this isn't a naming inconsistency to paper over, it's two genuinely different kinds of input.

3. **The one component built for exactly this case has never run.** This session's earlier work (`lib/features/player/` + the native `android/.../media3/Media3PlayerView.kt`) is a real `PlaybackAdapter` implementation built specifically to play an arbitrary direct URL — precisely what a Reel needs. It's Gradle-compile-verified (`compileDebugKotlin` succeeded against real Media3 1.5.1 dependencies) and `flutter analyze`-clean, but **it has never actually been exercised on a device or emulator** — none is available in this environment (confirmed twice now: no Docker virtualization, no installable Android system images). Wiring it into `party_screen.dart` as a new, live, user-facing player path — the first time this code would ever run for real — is a materially different risk than the backend/Dart-only changes made elsewhere this session, which could at least be reasoned about and verified by tracing or compiling. Shipping an untested native platform-view integration as a tappable feature means the first real signal of whether it works at all arrives in a user's hands.

4. **Even the one seemingly-trivial backend piece (add a new `sourceType` enum value) isn't safe to do blind.** `Room.sourceType` is a native Postgres ENUM. This backend has no migrations folder — schema changes happen via `sequelize.sync({ alter: shouldAlterSchema })` at boot (`server.js:153-155`), and `shouldAlterSchema` is deliberately `false` in production unless `DB_FORCE_ALTER=true` is explicitly set. That's an intentional safety rail already built into this app, and it means editing the model's ENUM definition wouldn't actually add the value to the live database at all under normal operation — it would either silently do nothing (if nobody sets that flag) or, if the flag is ever set for an unrelated reason, apply `alter: true` against whatever schema drift has accumulated since, a blast radius far bigger than one enum value. This isn't the kind of change to make by editing a model file and hoping; it needs a real, deliberate migration step outside this pass's scope.

## What this phase concluded, concretely

- **Confirmed exactly what's missing** (this document) rather than guessing or shipping a partial/broken button.
- **Did not** add a new `sourceType`, touch `Room.js`, or add any UI entry point to Reels — each would either not work, silently no-op, or ship an unverified native code path as a live feature.
- **Did** fix the adjacent, safely-scoped, real gap in the same problem space: queue versioning (see `PARTY.md`) — genuinely completable and verifiable without a device or a schema change.

## What actually needs to happen, in order, before this can ship

1. A real migration (not a model-file edit) adding the new `sourceType` value to the live Postgres ENUM, run deliberately against the actual production database — outside this session's ability to do responsibly without more context on how this team runs migrations today.
2. `party_screen.dart`'s existing sourceType-based player-selection logic gets a new branch for that value, rendering `Media3PlayerView` instead of the existing three players.
3. **Real-device verification that Media3PlayerView actually plays a video at all** — this has never been confirmed outside a Gradle compile. Per the request's own Step 35: "Do not declare playback solved until real-device testing succeeds." This step cannot be skipped or simulated.
4. Only then: the actual "Watch With People" button in `reels_feed.dart`/`post_detail_screen.dart`, calling the existing `POST /rooms` (which already accepts `sourceType`+`videoUrl` at creation — no backend route changes needed there) with the Reel's own `videoUrl` and the new sourceType, then navigating to `PartyScreen` with the resulting room id.

Steps 2 and 4 are ordinary Flutter work once 1 and 3 are done. 1 and 3 are the actual blockers, and neither can be responsibly completed inside this sandbox.
