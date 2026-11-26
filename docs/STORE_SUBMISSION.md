# Store submission guide (Google Play + App Store)

Everything the stores ask for that isn't code. Copy the text blocks into the
consoles. Server address used below: `https://fling-backend.onrender.com`.

---

## 1. Coin packs (Google Play Billing / App Store in-app purchase)

The app now buys coins only through the stores. Create these **consumable**
products, with the **same product id in both stores**:

| Product id | Coins | Suggested price |
|---|---|---|
| `coins_100` | 100 | ₹99 |
| `coins_550` | 550 | ₹499 |
| `coins_1200` | 1,200 | ₹999 |
| `coins_2600` | 2,600 | ₹1,999 |

- **Play Console** → your app → Monetize → Products → In-app products → Create.
- **App Store Connect** → your app → Monetization → In-App Purchases → Consumable.
- A new pack in the admin panel needs its `storeProductId` set to a product id
  that exists in both stores. Packs without one are hidden in the app.

Server settings (Render → Environment) so the server can check purchases:

| Variable | Where it comes from |
|---|---|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Google Cloud → service account → JSON key. In Play Console → Users and permissions, invite that service account with "View financial data" for this app. Paste the whole JSON. |
| `ANDROID_PACKAGE_NAME` | `com.fling.app` (default) |
| `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY` | App Store Connect → Users and Access → Integrations → In-App Purchase → generate key. Paste the .p8 file's contents. |
| `IOS_BUNDLE_ID` | `com.fling.app` (default) |
| `SAFETY_CONTACT_EMAIL` | A monitored inbox for child safety reports (shown on /child-safety). |

Not done yet: refunds made in the stores don't take coins back automatically
(Google "voided purchases" / Apple refund notifications). Handle these by hand
from the admin panel until that's built.

---

## 2. Sign in with Apple (iPhone)

The app shows **Sign in with Apple** above Google on iPhone. To switch it on:

1. Apple Developer → Certificates, IDs & Profiles → Identifiers → `com.fling.app`
   → tick **Sign in with Apple**. (The app already has the entitlement.)
2. Firebase Console → Authentication → Sign-in method → **Apple** → Enable.
3. Build the iPhone app on a Mac (Xcode) as usual.

---

## 3. Google Play: target audience and child safety

- Policy → App content → **Target audience**: 18 and over only.
- Policy → App content → **Child safety standards**:
  - Standards URL: `https://fling-backend.onrender.com/child-safety`
  - Contact: the `SAFETY_CONTACT_EMAIL` inbox.
  - In-app reporting: yes (Report on profiles, messages, posts, rooms, live).
- **Content rating** questionnaire: social features, user-generated content,
  users can interact, shares location (optional), digital purchases.
- App Store Connect → **Age rating**: answer for 18+ (dating/social, unrestricted
  web access via in-app browser, user-generated content).

---

## 4. Google Play declarations

**Foreground service: media playback**
> Insync keeps a watch party, music room or voice room playing while the app
> is in the background or the screen is off. The service runs only while the
> person is in a room and shows an "In room" notification; it stops when they
> leave. Video: open a room, start a video, press Home, the audio keeps playing.

Record a short screen video of exactly that and attach it.

**Full-screen intent (incoming calls)**
> Insync has one-to-one voice and video calls between friends. The full-screen
> notification is used only to show an incoming call while the phone is locked,
> like a phone call. If it isn't allowed, the call rings as a heads-up
> notification instead.

**Notification listener (watch together with Netflix / Prime Video)**
> When a room watches Netflix or Prime Video in their own apps, Insync uses
> notification access only to read and control those apps' media player (what
> is playing, its position, play/pause/seek) so everyone stays in sync. It never
> reads, stores or sends notification contents. The app explains this in a
> dialog before opening the setting, and works without it.

**Photos and videos**: no declaration needed any more. The app uses the
system photo picker and no longer asks for photo or video permission.

**Data safety** (match the iOS privacy manifest): name, email, phone, user
IDs, photos and videos, audio (voice notes, calls), messages and other
user content, approximate location (only if turned on), purchase history.
All for app functionality, none sold, none used for ads, encrypted in transit,
users can request deletion (in-app account deletion).

---

## 5. App Review notes (App Store) and test access (both stores)

**Test sign-in.** Reviewers need a way in. Pick one:
- Firebase Console → Authentication → Sign-in method → Phone → *Phone numbers
  for testing*: add e.g. `+91 99999 00001` with code `123456`, and turn phone
  sign-in on in the admin panel's login options. Give that number and code below.
- or Sign in with Apple / Google with the reviewer's own account (allowed, but
  a test number is faster for them).

**Review notes** (App Store Connect → App Review Information → Notes):
> **What Insync is:** a social app for adults (18+) to watch videos together
> in rooms, talk in voice rooms, go live, chat, call friends and play games.
>
> **Sign in:** phone +91 99999 00001, code 123456 (test number), or Sign in
> with Apple.
>
> **Where to find the main features:** Home → Create room → pick YouTube to
> watch together. Chat tab → message or call a friend. Wallet → Buy coins
> (App Store in-app purchase, consumable) → coins are used for gifts in rooms
> and VIP.
>
> **Netflix / Prime Video rooms:** each person signs in to their own
> subscription; Insync only keeps everyone's playback in time. No content is
> re-streamed.
>
> **Moderation:** Report and Block on every profile, message, post, room and
> live stream; reports are reviewed by people; child safety standards at
> https://fling-backend.onrender.com/child-safety.
>
> **Demo video:** (attach a screen recording on a real iPhone showing sign-in,
> a room, chat, a purchase in the sandbox, and Report/Block).

---

## 6. Still to decide before submitting

- **Staff-run "fake" accounts** (password login for seeded profiles): both
  stores treat fake profiles that real users can't tell apart as deceptive.
  Either label them clearly as Insync team/demo accounts or remove them.
- **Netflix / Prime logos** in the source picker: trademarks; Apple may ask
  for permission. Plain text labels avoid the question.
