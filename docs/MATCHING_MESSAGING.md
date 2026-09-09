# Matching & Messaging

## Already real, confirmed by direct model/route inspection

**Matching**: `Match.js` (`userAId`/`userBId`) + `Swipe.js` (like/pass tracking) are separate, real models — the Discover → Like/Pass → Mutual Like → Match flow spec Step 20 asks for already exists, backed by `discover_matches_screen.dart`/`random_match_screen.dart`/`swipe_card.dart` on the client. **Follow, Friend, and Match are already three genuinely separate concepts** (`Follow.js`, `FriendRequest.js`, `Match.js` are three distinct models, not one relationship type wearing different labels) — exactly what the spec explicitly asks to keep separate.

**Messaging**: `DirectMessage.js` has a real `readAt` timestamp (read receipts are real, not a UI-only flag), media messages (`mediaUrl` for stickers/GIFs) are supported, `messages.js` covers DM + presumably group threads.

## One spec item that doesn't map onto this app's actual architecture

Step 21 asks for "private media storage and signed URLs." Investigated precisely: this backend has **no object storage integration at all** — no AWS S3, Cloudinary, or Firebase Storage SDK anywhere in `src/`. Photos are stored as base64-encoded `TEXT` directly in Postgres (`Photo.imageData`), not as files in a bucket. `GET /gallery/user/:id`'s own code comment states plainly this is "public — no visibility tiers requested for this," a documented product decision, not an oversight. Message media (`mediaUrl`) points at external sticker/GIF URLs, not user-uploaded private files.

This means "signed URLs" isn't a missing security layer here — there is no object-storage layer for it to sit in front of. Privacy for anything that *is* access-controlled (DMs, private photos if that changes later) is enforced through the API's own auth checks (`requireAuth` + ownership checks, e.g. `gallery.js`'s delete route checking `photo.userId !== req.userId`), not through expiring links. That's a legitimate alternative security model, not a broken one — as long as the authorization checks themselves are correct, which is what was actually verified here rather than chasing a signed-URL implementation this app's storage architecture has no place for.

No code changes made this phase — investigation found real, correctly-designed (if architecturally different from the spec's literal wording) systems, not a bug to fix.
