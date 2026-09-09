# Games

## What's already real — more than expected

Confirmed by direct code review: **five** working, server-authoritative games already exist — Chess, Ludo, TicTacToe, Truth or Dare, and UNO (`fling-backend-FINAL/src/games/{chess,ludo,tictactoe,truthOrDare,uno}.js`), dispatched through a clean, generic module registry (`GAME_MODULES` in `syncHandler.js`) that every `game:join`/`game:move`/`game:reset` socket event routes through identically regardless of which game is active. Server-authority is real, not nominal: `chess.js`'s `applyMove` computes checkmate and assigns `winner` itself; a module returns `null` for an illegal move (turn violation, invalid move) and the handler simply doesn't broadcast — the client cannot fabricate a move, a turn, or a win. UNO additionally supports per-player state redaction (`getStateForPlayer`) so each player only sees their own hand. This is a genuinely well-designed system, not a stub.

## Added this phase: Would You Rather (`would_you_rather`)

Spec Step 15 lists Would You Rather as one of the target games. Chose this one specifically because its shape is nearly identical to the existing `truthOrDare.js` (a prompt-reveal state machine, no board, no win condition) — a genuinely safe, low-risk addition that follows an established, working pattern exactly, unlike Karaoke's hard content/DSP blockers or the Co-host role redesign's live-permission-system risk.

`src/games/wouldYouRather.js`: 18 original prompts, a group-vote-then-reveal state machine (everyone answers the same prompt at once — auto-reveals the instant every joined player has voted, or any player can force an early reveal for a stalled round), registered in `GAME_MODULES` alongside the existing five. **Verified functionally, not just syntax-checked** — ran the module directly through `node -e` exercising every transition: waiting→playing at 2 players, auto-reveal on last vote, vote-after-reveal correctly rejected, round-advance resets state correctly, an invalid choice value rejected, a non-player's move rejected. All passed.

## What's built but not yet reachable — and why, precisely

**The new game cannot actually be started from a room yet.** `Room.gameType` is a live Postgres ENUM (`DataTypes.ENUM('tictactoe', 'ludo', 'truth_or_dare', 'chess', 'uno')`, `src/models/Room.js`) — the exact same situation as `Watch Together`'s `sourceType` gap: this backend has no migrations folder, and schema auto-alter (`sequelize.sync({ alter })`) is deliberately disabled in production unless `DB_FORCE_ALTER` is explicitly set. There's also an **application-level** gate before the database is even reached: `GAME_TYPES = ['tictactoe', 'ludo', 'truth_or_dare', 'chess', 'uno']` in `src/routes/room.js` validates `gameType` on `POST /rooms` and rejects anything not in that list with a clean 400.

Deliberately did **not** touch either list. Adding `'would_you_rather'` to the app-level `GAME_TYPES` array alone (safe on its own — it's plain JS, not a schema object) would make things *worse*, not better: a room-creation request would pass that check only to then fail with an ugly, unhandled Postgres enum-violation error at the database layer, instead of the clean 400 it gets today. The two have to move together, and the database side needs a real, deliberate migration — not a model-file edit — run against the live database, which isn't something to do blind from this sandbox (identical reasoning to `WATCH_TOGETHER.md`).

**What's ready the moment that migration happens**: add `'would_you_rather'` to both `GAME_TYPES` and `Room.gameType`'s enum (and optionally `GAME_LABELS` for a nicer auto-generated room title — currently falls back to a generic `"<host>'s Game Room"` for any unlabeled type, which already degrades gracefully). The socket-layer game logic itself needs zero further backend changes — it was written and verified against the existing dispatch mechanism, not a hypothetical one.

**A Flutter client widget for Would You Rather doesn't exist either** — deliberately not built this phase, since it would be equally unusable until the migration above lands (no room can be created with this gameType to test it against), and building UI for a feature that can't yet be exercised end-to-end risks the same "claims completion because it compiles" problem this whole project has been careful to avoid. The existing `truth_or_dare_panel.dart` is the closest reference pattern for what that widget should look like once the migration is in.

## What's still genuinely unbuilt

Quiz, Trivia, Charades, and Guess Song from the spec's list have no implementation anywhere in either repo — confirmed via search, zero matches beyond the word appearing nowhere at all (unlike Karaoke, these don't even show up as an interest tag or a dead enum value). Each is a reasonable future addition following the exact same module pattern demonstrated here, once the migration path for adding new `gameType` values is actually exercised for real.
