# Music

## What's already real

Confirmed by direct code review: search (reuses `/youtube/search`, no separate music search endpoint — and none is needed, since every song here *is* a YouTube video, not a separate audio catalog), queue/play/pause/next (flows through the same generic, now-versioned queue system every other phase hardened — no separate music protocol exists, `sourceType: 'youtube'` items are just queue items), favorites (`LikedSong` model + `likedSongs.js`), playlists (`Playlist`/`PlaylistSong`/`PlaylistLike` models + `playlists.js`), history (`SongHistory`, append-only, deduped on read), and Party integration (`smart_play_song.dart` — tapping a song from Profile/History/Liked either queues it into your current active room or spins up a new one).

## Fixed this phase

`playSongSmart`/`playPlaylistSmart` (`lib/core/smart_play_song.dart`) fired `queue:add` at the shared socket directly and **unconditionally showed "Added to \<room\>"** immediately after, regardless of whether the server actually added anything. The backend's `queue:add` handler already silently rejects (and emits `queue:denied`) when the room's `songPermission` setting is `'host'` and the caller isn't the host — a real, pre-existing, correctly-implemented server-side rule that this client path simply never checked. Someone tapping "smart play" on a song from their Profile while active in someone else's host-only room would see a success message and get navigated into a party where their song was never queued. Same family of bug as the Voice phase's silent-failure fix.

Fixed by waiting briefly for a `queue:denied` response before showing success (no ack-based "yes it worked" signal exists for a *successful* add — `queue:state` broadcasts to the whole room, not a targeted reply — so a short window with no denial is treated as success, the same trust level this call already had). Applied the same lesson from the realtime-recovery phase: the listener is registered and removed by a named reference (`socket.off('queue:denied', onDenied)`), not the blanket no-argument form, since a live `RoomSocketController` for the same room may already have its own listener on this identical shared socket.

## What's confirmed missing, and why "track rights" wasn't built

Spec Step 13 asks for per-track rights flags: `partyAllowed`/`reelAllowed`/`storyAllowed`/`karaokeAllowed`/`liveAllowed`. Confirmed: zero such fields exist on any music model (`LikedSong`, `Playlist`, `PlaylistSong`, `SongHistory`), and nothing in either repo enforces or even records a cross-context usage restriction on any track.

**This wasn't skipped for lack of time — it doesn't map onto how this app actually sources music.** Every song here is an arbitrary YouTube video URL, not a licensed entry in a curated audio catalog the way that flag set implies (the pattern reads like it's designed for a TikTok/Instagram-style licensed short-clip library, where a label genuinely might permit a track for Reels but not for a public Karaoke performance). Fling has no such catalog and no rights-management relationship with any label — inventing `partyAllowed`/`karaokeAllowed`-style flags on a `LikedSong` row would just be five boolean columns with no real distinction ever set differently, since nothing here has separately-licensed usage terms across contexts. Adding it would satisfy the letter of the spec while providing zero real value — busywork, not a feature. If this app later adds a genuinely rights-managed audio catalog (e.g. for Karaoke's authorized backing tracks, see the karaoke phase), that's the point where per-context rights flags become meaningful and worth building for real.

## What's a real, smaller gap

No dedicated playlist management screen exists — create/rename-visibility/add-song/remove-song all work as backend endpoints (`playlists.js`), but there's no single screen for full CRUD; playlist creation and song-adding happen through smaller, scattered widgets (inline forms, `queue_sheet.dart`). Not fixed this phase (a UI-scope feature, not a bug), noted here for whoever picks up the Creator/Communities or general UI-polish phases later.
