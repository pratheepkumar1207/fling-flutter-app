# Cost Guard

## Adjacent infrastructure exists; the actual thing doesn't

Real `express-rate-limit` is already installed and used: a baseline app-wide limit (300 requests/15min, added specifically because there was previously none at all — any endpoint including auth could be hit as fast as a script could fire) plus a stricter limiter on `/admin/login`. That's a genuine defense against basic scripted abuse — but it's request-rate limiting, not cost/usage tracking, and it's a different concern from what this spec step actually asks for.

Confirmed absent: no tracking of storage, bandwidth, processing, party-minutes, voice-minutes, Live-minutes, realtime-event volume, or AI-request counts (moot for now — see `AI.md`) anywhere in either repo. No admin-facing cost dashboard, no quality-reduction/large-room/processing limit controls, no cost alerts.

## Why nothing was built this phase

Real usage/cost metering needs a decision this session can't make: what's actually worth measuring and at what granularity (per-room? per-user? per-day, matching the inSync package's own `usage_daily` table shape from `INSYNC_MIGRATION_MAP.md`, which was correctly not applied to this app's real database?), and where it should live — a new Postgres table written to on a cron/interval (cheap, simple, matches this backend's existing all-Postgres-no-cache architecture) versus Redis counters (this backend has no Redis at all today — confirmed nowhere in `package.json`'s dependencies — so that would be a new infrastructure dependency, not a small addition). That's a real architectural decision, not something to default into silently.

A reasonable minimal starting shape, for whoever picks this up: a `usage_daily(day, metric, value)`-style table (the inSync package's own shape is a fine starting point, just applied to the real Postgres database via a deliberate migration rather than blindly), incremented from the existing hot paths that already know what's happening (room join/leave already fires through `syncHandler.js`, voice/live joins already go through `POST /calls/token`) — additive counters on paths that already exist, not a new subsystem watching everything from outside.
