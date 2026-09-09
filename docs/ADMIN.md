# Admin

## Already real, and more substantial than expected

A separate React/Vite project (`fling-admin-dashboard`) with **24 real pages**: Dashboard, Users, Admins, KYC, Photo Verification, Fraud Flags, Fake Users, Cashouts, Transactions, Coin Packages, Gifts, Reports, Complaints, Audit Log, Banners, Avatar Frames, Interests, Game Rooms, Livestream Requests, Broadcast, Settings — covering most of spec Step 30's requested section list already (Dashboard, Users, Content/Reports/Complaints, Games, Coins/Gifts, Moderation via Reports/Fraud Flags, Audit Logs, Settings-as-remote-config).

**RBAC is real and server-enforced, not UI-only** — confirmed by reading the actual middleware: `AdminUser.role` is a genuine 3-tier ENUM (`owner`/`moderator`/`finance`), and route-level guards like `requireRole('owner')` gate specific endpoints server-side (e.g. creating new admin accounts). `GET /admin/me` exists specifically so the frontend can check its own role rather than assume it — the right shape for "never rely on UI permissions alone."

## Confirmed gaps

- **3 role tiers, not 6.** Spec asks for Super Admin/Admin/Moderator/Support/Finance/Creator Ops. Today: `owner` (functions as super-admin), `moderator`, `finance` — no separate `admin` (below owner), `support`, or `creator ops` tier.
- **No Remote Config draft→validate→publish→rollback workflow.** `SettingsPage.jsx` exists but wasn't confirmed to implement the specific versioned-config lifecycle (key/type/value/version/updatedBy/updatedAt/reason) spec Step 31 describes — it's a settings page, not confirmed to be that particular workflow.
- **No dedicated Cost Guard or Infrastructure page** — consistent with `COST_GUARD.md`'s finding that the underlying usage-tracking data doesn't exist yet for a page to display.

No code changes made this phase. This is another "confirm what's real, document what isn't" result — the existing dashboard and its RBAC are a solid foundation, not something to rebuild.
