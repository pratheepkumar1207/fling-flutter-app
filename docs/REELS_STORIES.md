# Reels & Stories

## Both already real — confirmed, not assumed

**Reels**: `lib/widgets/reels_feed.dart` + `feed_screen.dart` — a real fullscreen vertical feed. Per the original `FLING_AUDIT.md` §2, this predates this integration effort entirely.

**Stories**: also fully real, not a stub — backed by the same `Post` model as the regular feed via an `isStory` boolean flag rather than a separate table (`routes/feed.js`), with a real 24-hour expiry (`STORY_LIFETIME_MS`, `expiresAt`), photo/video/text/voice support, and — notably — **poll support built directly into the same creation endpoint** (`pollOptions` is accepted on any post, story or not). Client side: `story_bar.dart` (the gradient-ring avatar strip) + `story_viewer_screen.dart`, fetching from `GET /feed/stories` (active, non-expired, connections-only).

No code changes made this phase — investigation found real, already-working features, not bugs.

## Confirmed gaps (real, not built)

- **No viewer tracking.** Nothing records who watched a given story — no `StoryView`-style join table, no "seen by" list anywhere in `routes/feed.js`. A real gap against spec Step 19's "viewer tracking," and a reasonably well-scoped addition if picked up later: a join table (`storyId`, `viewerId`, `viewedAt`) plus a `POST /feed/stories/:id/view` endpoint and a "seen by" query — no architectural blockers, just not built.
- **No "close friends" visibility tier for stories.** `Playlist.visibility` already has a real enum pattern (`everyone`/`friends`/`followers`/`following`) that a `closeFriends` tier could follow, but stories today only use the same connections-based visibility as the rest of the feed — no separate close-friends list exists to scope a story to.
- **Questions/reactions/mentions on stories specifically**: not confirmed present as story-specific interactions (reactions/mentions exist elsewhere in the app, e.g. chat — whether they're wired to *stories* specifically wasn't found in this pass).

Neither gap was built this phase — both are real, moderate-sized, unblocked features (no device dependency, no licensing question, no live-migration risk like the sourceType/gameType gaps), just not the highest-priority fix found while working through this list. Worth picking up as a focused follow-up.
