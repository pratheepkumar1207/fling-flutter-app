# Moderation

## Already real

`Report` (reporter/reportedUser/reason/status: open/reviewed/dismissed) and `Block` models are real. Per-room mute exists via the already-audited `call:forceMute`/`forceUnmute` (`VOICE.md`). A user-level ban exists: `User.isBanned` (boolean). `AdminAuditLog` is a real, already-in-use append-only audit table — its own comment states plainly it exists "so a disputed ban/KYC decision/cashout/settings change can be traced back to a specific admin and time, which nothing did before this," and `action` values like `"user.ban"`/`"kyc.approve"`/`"cashout.mark-paid"` confirm ban/moderation actions already flow through it.

## Confirmed gaps

- **No escalation ladder.** `isBanned` is a single boolean — permanent, all-or-nothing. The spec's `Strike → Suspend → Ban` progression (graduated consequences before a permanent ban) doesn't exist; today it's just banned or not, with no duration field, no strike count, no temporary-suspension state.
- **No "Restrict."** The lighter-touch moderation tier (like Instagram's Restrict: the restricted user can still interact, but their comments/messages are only visible to themselves, no notification that they've been restricted) has no equivalent — the only levers today are the binary Block and the binary ban.
- **No appeal mechanism.** A banned/reported user has no way to contest the action anywhere in either repo — confirmed via search, zero matches for "appeal" that aren't unrelated word collisions (a game's "restricted move," etc.).

No code changes made this phase. These are real, additive features — a strike/duration field on the ban model, a new Restrict relationship (structurally similar to the existing `Block` model), and an appeal submission+review flow — none blocked by a device, licensing, or live-migration risk the way earlier phases' gaps were, just not the highest-priority items found while working through this list.
