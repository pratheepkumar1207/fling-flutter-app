# Economy & Premium

## Already real, and genuinely well-built — the strongest audit result of this whole project

Checked the security-critical paths directly rather than trusting a surface read. `POST /wallet/buy/verify` (`routes/wallet.js`): real HMAC-SHA256 signature verification against Razorpay's own secret, **constant-time comparison** (`crypto.timingSafeEqual`, correctly guards against timing attacks — not a naive `===` string compare), row-level locking (`transaction.LOCK.UPDATE`) inside a real DB transaction, and idempotency enforced by only processing a `Transaction` row that's still `status: 'pending'` — replaying the same verify call twice cannot double-credit. `POST /wallet/gift` has the same shape: locked rows, a server-side insufficient-balance check, and a real double-entry audit trail (`gift_sent` + `gift_received` rows created atomically in the same transaction). This is exactly spec Step 22's "every financial mutation requires: transaction, idempotency, audit" — already true, not aspirational.

**Coins ≠ XP ≠ Creator Earnings** is also already real and separate: `User.coinBalance` (spendable currency) and `User.xp` (a plain progression counter, confirmed in `FLING_AUDIT.md` §1) are distinct fields with no code path conflating them.

## Premium/VIP works differently than the spec's literal wording, for a good reason

Step 23 assumes native App Store/Google Play in-app purchases for Premium specifically ("Purchase: App Store/Google Play → server verification → entitlement"). Fling's actual model is a level removed: real money → Razorpay → coins (server-verified exactly as described above) → coins spent on VIP via `POST /wallet/buy-vip`, which deducts `VIP_COST_COINS` from the already-verified `coinBalance` server-side. There's no second real-money transaction for VIP itself that would need App Store/Play receipt validation — it's an internal economy spend, checked server-side the same way a gift send is. This is a coherent, consistent design (one real-money entry point, everything downstream is an internal ledger operation), not a shortcut around purchase verification — the actual real-money boundary (Razorpay) is the one that's cryptographically verified.

No code changes made this phase. Investigation found a well-built system; this is one of the phases where the honest finding is simply "already correct."
