# Playback architecture

## Two layers, deliberately not yet merged

**Layer 1 — the new shared architecture** (`lib/core/playback/`): `PlaybackSession`, `PlaybackAdapter`, `PlaybackSessionManager`, `PlaybackSurface`, `LifecycleCoordinator`, `RoomClock`. Added this phase, wraps the native Media3 adapter (`lib/features/player/data/media3_playback_adapter.dart`). Enforces the critical invariant — a lifecycle transition can only ever call `PlaybackAdapter.setSurface(...)`, never `play()`/`pause()` — by construction, verified by 12 tests in `test/core/playback/lifecycle_coordinator_test.dart`.

**Layer 2 — the existing, live, already-correct players** (`sync_video_player.dart` for YouTube, `drive_video_player.dart` for Drive): each owns its own `WidgetsBindingObserver` with bespoke, production-debugged disambiguation logic. **Verified by direct code inspection (`FLING_AUDIT.md` §4): neither ever emits `playback:pause` from a lifecycle callback.** They already satisfy the same invariant Layer 1 enforces structurally — just via hand-written per-file logic instead of a shared component.

**These two layers are intentionally not wired together yet.** Here's why, and what would change that.

## Why the existing players were not retrofitted onto LifecycleCoordinator in this phase

Reading both files' lifecycle handlers in full (not just grepping for the pause bug) surfaced logic far more subtle than "handle background, handle resume":

- `drive_video_player.dart`'s 300ms delay before handing off to background audio is **not** arbitrary latency. Its own comment states plainly: a prior version handed off immediately, which paused the video the instant auto-PiP (home-button PiP, not the in-app button) was entered — because `PipService.isInPip` is set optimistically by the in-app PiP button but only flips true *asynchronously*, after a native `onPipModeChanged` round trip, for auto-PiP. That immediate-handoff version shipped and produced a confirmed, live "video freezes for the whole PiP session" bug. The 300ms delay plus a re-check right before committing is the fix for that bug, not the bug itself.
- `sync_video_player.dart`'s resume handler extends its "was this actually PiP" suppression window by an *additional* 1200ms after PiP is detected, specifically to absorb a delayed WebView `StateChange` event that Chromium sends asynchronously around the PiP transition — without that extension, a late "paused" event was reaching `_maybeReportPlayState` and getting broadcast to the whole room as a real pause that then never got undone. Also a confirmed, previously-live bug, also already fixed.

Both timers exist because a straightforward version of this logic was tried, shipped, and produced real regressions. **Rewriting either method to route through `LifecycleCoordinator` — even if the end behavior were logically equivalent — means re-deriving two independently-discovered, non-obvious timing fixes from scratch, with no physical device or emulator available in this environment to confirm the rewrite doesn't reintroduce either bug** (`FLING_AUDIT.md` §14; confirmed no Android system images are installable here, same virtualization limitation that blocks Docker Desktop). Per the integration ground rules ("do not delete working Fling functionality without first understanding it," "do not claim completion just because files compile"), the responsible call is: leave this logic exactly as it is, since it is already correct, and reserve `LifecycleCoordinator` for playback surfaces that don't have it yet.

**This will get revisited** once either (a) real-device testing is available to verify a migration doesn't regress the two fixed bugs above, or (b) a new mode built on the Media3 adapter needs shared surface management badly enough to justify the risk of touching the legacy players instead of just leaving both layers to coexist.

## The three bugs `FLING_AUDIT.md` found, and their actual status

1. **iOS has no `UIBackgroundModes` audio capability declared.** Fixed this phase (`ios/Runner/Info.plist`) — unambiguous, additive, no existing behavior to regress.
2. **Drive's background-audio handoff does a cold `just_audio` source reload** (pause local video → `setAudioSource()` on a fresh network stream → play). This is real and is the most likely source of an audible gap on lock/background for Drive rooms specifically. **Correction to this document's own earlier draft** (see git history of `FLING_AUDIT.md` if you're looking for the original, more glib "eliminate the delay" framing): the 300ms delay described above is not part of this problem and must not be shortened — the cold-reload gap happens *after* the delay, once a handoff is already confirmed genuine. A real fix (e.g. proactively pre-buffering the background source before the delay elapses, so the eventual handoff is a `seek+play` on a warm source instead of a cold one) is possible but adds its own failure modes (wasted network/battery on a PiP dip that turns out not to need it) and needs device-level profiling to validate — not done blind in this pass.
3. **YouTube rooms have no background-audio path at all.** Confirmed as a genuine platform/ToS constraint, not a bug: a backgrounded WebView's media is suspended by the OS, and there is no legitimate way to extract YouTube audio without the video surface visible. The existing resync-on-resume behavior (`widget.onRequestState()`) is the correct fallback given that constraint, not something to "fix" further.

## What a future consumer of `PlaybackSessionManager` looks like

Any *new* playback surface (e.g. the Media3 adapter once it's wired into a real screen, or a future Voice/Music mode's audio) should be built directly on `PlaybackSessionManager`/`LifecycleCoordinator` from the start, rather than writing a third bespoke `WidgetsBindingObserver`. See `lib/features/player/data/media3_playback_adapter.dart` for the pattern.
