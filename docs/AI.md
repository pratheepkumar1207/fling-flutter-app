# AI

## Confirmed genuinely absent

Searched both repos for any AI provider integration (OpenAI, Anthropic, Gemini, or any generic "generative AI" reference) — zero matches anywhere. No `AiGateway` exists, no AI-backed feature (recommendations, moderation assistance, captions, a Party assistant, AI-generated quizzes/Truth-or-Dare prompts, AI-weighted discovery) has been started.

## Why nothing was built this phase

Every AI feature in the spec needs a real provider account and API key — the same category as Firebase, Agora, Razorpay, and Tenor elsewhere in this app, all of which are already documented in `pubspec.yaml`/code comments as "needs your own credentials," never something to fabricate or stub convincingly. There's no existing account/key to build against here, and spec Step 28's own rule — "do not put AI secrets in Flutter" — is trivially satisfied by there being no secret to place anywhere yet, not because a real gateway was built and secured.

## What a real `AiGateway` should look like when a provider is chosen

- **One interface, provider swappable behind it** — mirrors this codebase's existing `MediaProvider`/`PlaybackAdapter` abstraction pattern (see `PLAYBACK.md`), not a direct SDK call scattered through feature code.
- **Server-side only.** Every call goes through the backend, matching the existing shared-secret pattern already used for Razorpay/Agora tokens — the Flutter app should hold no more than it holds today for those (nothing).
- **Quota-limited from the start**, not bolted on later — ties naturally into the Cost Guard phase's usage-tracking, since AI requests are one of the metered categories that phase already lists.

Not attempted further than this scoping, since building against a provider with no account or key configured would mean writing entirely speculative integration code with no way to verify it actually calls anything real.
