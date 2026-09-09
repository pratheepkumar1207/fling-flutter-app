# Creator & Communities

## Already real

**Communities**: a genuinely real role model — `CommunityMember.role` is a proper 3-tier ENUM (`member`/`moderator`/`owner`), notably more built-out than the Voice system's binary host/non-host (see `VOICE.md`). Real routes for create/browse/mine/get, join/leave, member listing, promoting a moderator, pinned posts, and linking a community to a room (`GET /:id/community/room`) — covering community/members/roles/posts/Parties/moderation from spec Step 25's list.

**Creator**: real earnings (`GET /creators/me/earnings`), top-supporters, livestream application + dashboard. Followers already exist via the separate `Follow` model (confirmed real and distinct from Match/Friend in `MATCHING_MESSAGING.md`).

## Confirmed gaps

- **No separate paid "subscribers" tier.** Room's `'subscribers'` visibility value reuses the existing `Follow` relationship (a documented, deliberate choice from earlier in this app's history — there's no billing behind it) rather than a real monetized subscription product. Spec Step 24 lists "subscribers" alongside "followers" as if they're two different things; here they're the same relationship. Not a bug — there's no subscription billing system to back a genuinely separate tier, and building one wasn't in scope for this audit-and-fix pass.
- **No community events.** No event-scheduling routes found for communities specifically (`Room` has `scheduledAt` for a room, but nothing ties a community to a calendar of upcoming events).
- **No community leaderboard.** Spec Step 25 asks for one; not found in `communities.js`. `leaderboards.js` exists as its own route file but wasn't confirmed to be community-scoped in this pass.
- **No community-scoped "games/Live" browse.** A community can link to one room (`GET /:id/room`), but there's no view of "all of this community's active game/live rooms" as a set.

No code changes made this phase — the core role/moderation/membership system is real and solid; the gaps found are additive features (events, leaderboard, a richer community↔room relationship), not bugs in what exists.
