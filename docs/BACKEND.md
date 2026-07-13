# POV-Stranger — Backend & Storage Architecture

> **Status:** Planning (pre-Phase 4)  
> **Last updated:** 2026-07-13  
> **Stack:** SwiftData (local) + MongoDB Atlas + Atlas Functions  
> **Audience:** Anyone implementing backend relay, iOS sync, or infra.

Read this before Phase 4 in [`PLAN.md`](PLAN.md).

---

## ℹ️ Note: Atlas Device Sync EOL (not used)

**MongoDB Atlas Device Sync (formerly Realm Sync) reached end-of-life on September 30, 2025.**

We **do not use** Realm or Device Sync. Local persistence stays **SwiftData** (Apple stack). MongoDB Atlas is **cloud-only** via HTTPS Functions.

| Product | Our usage |
|---------|-----------|
| SwiftData | ✅ Local session, hour slots, offline cache |
| MongoDB Atlas | ✅ Cloud DB + GridFS |
| Atlas Functions | ✅ Match, upload, push, purge |
| Realm / Device Sync | ❌ Not used |

---

## Table of contents

1. [What the backend must do](#1-what-the-backend-must-do)
2. [What the backend must NOT do](#2-what-the-backend-must-not-do)
3. [Recommended stack](#3-recommended-stack)
4. [System architecture](#4-system-architecture)
5. [Data model (MongoDB)](#5-data-model-mongodb)
6. [Local model (SwiftData on iOS)](#6-local-model-swiftdata-on-ios)
7. [Storage design & TTL](#7-storage-design--ttl)
8. [Matching & weekly rematch rule](#8-matching--weekly-rematch-rule)
9. [Photo relay flow](#9-photo-relay-flow)
10. [Push notifications (APNs)](#10-push-notifications-apns)
11. [Auth & identity](#11-auth--identity)
12. [Security & moderation](#12-security--moderation)
13. [iOS client integration](#13-ios-client-integration)
14. [Environments & secrets](#14-environments--secrets)
15. [Cost model](#15-cost-model)
16. [Implementation phases](#16-implementation-phases)
17. [Decision log](#17-decision-log)
18. [Timezone policy](#18-timezone-policy)

---

## 1. What the backend must do

| Capability | Detail |
|------------|--------|
| **Match strangers** | Pair two users for one 24h session |
| **Relay photos** | 1-1 per hour slot, no feed |
| **Deliver metadata** | Country, timezone, distance, weather summary |
| **Notify partner** | Silent APNs → download → widget refresh |
| **Farewell message** | One text per user, deliver once at end |
| **Expire & purge** | Delete session data ≤ 25h after match |
| **Weekly rematch rule** | Same pair **can** meet again — but **not in the same ISO calendar week** |
| **Report / block** | Instant unmatch; block overrides rematch |

### Non-functional requirements

| Requirement | Target |
|-------------|--------|
| Photo size | ≤ 80 KB JPEG, 800px max (client) |
| Storage retention | **25 hours max** |
| Cost at 1k DAU | < $30/month |
| Offline | SwiftData holds active session; sync when online |

---

## 2. What the backend must NOT do

- No social graph, no profiles, no chat (except farewell)
- No photo history or gallery
- No precise GPS on server
- No public photo URLs
- **No permanent "never pair again"** — rematch allowed after a new week

---

## 3. Recommended stack

### ✅ Decision: **SwiftData (local) + MongoDB Atlas + Atlas Functions**

| Layer | Technology | Role |
|-------|------------|------|
| **Local DB (iOS)** | **SwiftData** (`@Model`) | Active session, hour slots, offline cache — Apple stack |
| **Cloud DB** | MongoDB Atlas (M0 dev / M10 prod) | Sessions, queue, pair history, metadata |
| **Photo blobs** | **GridFS** on Atlas | JPEG storage, TTL index |
| **API / logic** | **Atlas Functions** + Triggers | Match, upload, confirm, farewell, purge |
| **Auth** | Sign in with Apple → Atlas Auth or custom JWT | Anonymous identity |
| **Push** | APNs HTTP/2 from Atlas Function | Silent push for widget |
| **Weather** | WeatherKit on iOS | Client sends summary with upload |

### Why SwiftData + Atlas (not Realm)?

| Reason | Detail |
|--------|--------|
| Apple-native | Same stack as SwiftUI, `@Query`, `#Preview` |
| Already in app | `StrangerSession`, `HourSlot` models exist |
| No migration cost | Phase 4 wires `AtlasSessionService` → existing SwiftData |
| Cloud separate | Atlas is HTTP relay only — no local sync framework needed |

---

## 4. System architecture

```
┌─────────────────────────────────────────────────────────┐
│                     iOS App                              │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ SwiftData    │  │ HTTPS client │  │ Widget / APNs  │ │
│  │ active sess  │  │ Atlas Funcs  │  │ handler        │ │
│  └──────┬───────┘  └──────┬───────┘  └────────────────┘ │
└─────────┼────────────────┼──────────────────────────────┘
          │                │
          │         HTTPS (JWT)
          ▼                ▼
┌─────────────────────────────────────────────────────────┐
│              MongoDB Atlas                               │
│  ┌──────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ Collections  │  │   GridFS    │  │ Atlas Functions │ │
│  │ sessions,    │  │  (photos)   │  │ match, upload,  │ │
│  │ queue, pairs │  │  TTL 25h    │  │ push, purge     │ │
│  └──────────────┘  └─────────────┘  └─────────────────┘ │
│  ┌──────────────┐                                        │
│  │ Atlas Trigger│  cron: expire sessions, purge blobs   │
│  └──────────────┘                                        │
└─────────────────────────────────────────────────────────┘
          │
          ▼
       APNs (Apple)
```

### Sync pattern

No automatic cloud sync framework. Manual relay:

1. **Write:** iOS → HTTPS Function → MongoDB + GridFS → update SwiftData
2. **Read:** Silent push or poll → HTTPS Function → download → update SwiftData → widget
3. **UI:** `@Query` / `@Bindable` on SwiftData models (unchanged)

---

## 5. Data model (MongoDB)

### Collections overview

```
users
match_queue
sessions
hour_uploads          (+ TTL index)
farewells             (+ TTL index)
pair_history          ← weekly rematch logic
blocks
reports
device_tokens
```

### `users`

```js
{
  _id: ObjectId,           // or auth provider id
  createdAt: ISODate,
  countryCode: "VN",       // ISO 3166-1 alpha-2
  timezoneId: "Asia/Ho_Chi_Minh",
  lastMatchedAt: ISODate,
  isBanned: false
}
```

### `sessions`

```js
{
  _id: ObjectId,
  userA: ObjectId,
  userB: ObjectId,
  startedAt: ISODate,
  expiresAt: ISODate,      // startedAt + 24h
  status: "active",        // active | farewell | ended | purged
  userACountry: "VN",
  userBCountry: "IS",
  userATimezone: "Asia/Ho_Chi_Minh",
  userBTimezone: "Atlantic/Reykjavik",
  isoWeek: 28,             // snapshot at match — for logging
  isoWeekYear: 2026
}
```

**Index:** `{ userA: 1, userB: 1, startedAt: -1 }`, `{ expiresAt: 1 }`

### `hour_uploads`

```js
{
  _id: ObjectId,
  sessionId: ObjectId,
  userId: ObjectId,
  hourIndex: 0,            // 0–23
  gridfsFileId: ObjectId,
  weatherSummary: "Rain · 28°C",
  capturedAt: ISODate,
  createdAt: ISODate       // TTL: expireAfterSeconds = 90000 (25h)
}
```

**Unique index:** `{ sessionId: 1, userId: 1, hourIndex: 1 }`

### `farewells`

```js
{
  _id: ObjectId,
  sessionId: ObjectId,
  userId: ObjectId,
  text: "Chúc mày bình an",   // max 280 chars
  sentAt: ISODate,
  deliveredAt: ISODate,
  createdAt: ISODate          // TTL 25h
}
```

**Unique index:** `{ sessionId: 1, userId: 1 }`

### `pair_history` — weekly rematch

```js
{
  _id: ObjectId,
  userA: ObjectId,           // canonical: lower id string first
  userB: ObjectId,
  sessionId: ObjectId,
  matchedAt: ISODate,
  isoWeek: 28,               // ISO week number (1–53)
  isoWeekYear: 2026          // year belonging to that ISO week
}
```

**Index:** `{ userA: 1, userB: 1, isoWeekYear: 1, isoWeek: 1 }`

> Records kept **permanently** (metadata only, no photos). Used for rematch rules + optional "you've met before" UX later.

### `blocks`

```js
{ blockerId: ObjectId, blockedId: ObjectId, createdAt: ISODate }
```

**Unique:** `{ blockerId: 1, blockedId: 1 }` — block always wins over rematch.

### `match_queue`

```js
{
  userId: ObjectId,
  enqueuedAt: ISODate,
  countryCode: "VN",
  timezoneId: "Asia/Ho_Chi_Minh"
}
```

---

## 6. Local model (SwiftData on iOS)

**Keep existing models** — no Realm migration.

```swift
@Model
final class StrangerSession { /* see Models/StrangerSession.swift */ }

@Model
final class HourSlot { /* see Models/HourSlot.swift */ }
```

### `AtlasSessionService` integration

```swift
// After HTTPS response from Atlas:
func applyRemoteUpdate(_ dto: SessionDTO, context: ModelContext) throws {
    // Upsert StrangerSession + HourSlot from server payload
    // WidgetDataStore.update(from: session)
    try context.save()
}
```

SwiftData = **cache of active session**. Atlas = **source of truth** while session lives. On purge / end → `context.delete(session)` locally + server TTL.

---

## 7. Storage design & TTL

### Photos: GridFS

```
fs.files / fs.chunks
  metadata: { sessionId, userId, hourIndex }
```

**TTL:** Atlas Trigger deletes GridFS files when `session.expiresAt + 1h` passed, or TTL on a shadow `photo_manifest` collection pointing to `fileId`.

### Purge schedule (Atlas Trigger, every 15 min)

1. Delete `hour_uploads` where `createdAt < now - 25h` (TTL index handles automatically)
2. Delete orphaned GridFS files
3. Set `sessions.status = "purged"` where `expiresAt < now - 1h`
4. **Keep** `pair_history` forever

---

## 8. Matching & weekly rematch rule

### Product rule: "Có duyên thì gặp lại"

> Same two strangers **may** be paired again — but **not during the same ISO calendar week**.  
> New week = new chance. Feels like fate, not a permanent block.

### Algorithm

```
function canPair(userA, userB):
  if blocked either direction → false
  if either in active session → false

  (canonicalA, canonicalB) = sort(userA, userB)
  currentWeek = isoWeek(now)
  currentYear = isoWeekYear(now)

  recent = pair_history.findOne({
    userA: canonicalA,
    userB: canonicalB,
    isoWeek: currentWeek,
    isoWeekYear: currentYear
  })

  if recent exists → false   // already met this week
  return true

function enqueue(user):
  candidate = best match in queue passing canPair()
  score by timezone distance + different country

  if candidate:
    create session (24h)
    insert pair_history { isoWeek, isoWeekYear }
    remove both from queue
    push both: session.matched
  else:
    add user to match_queue
```

### ISO week definition

- **ISO 8601 week** (Monday start, week 1 = week containing first Thursday)
- Computed in **UTC only** on the server at `matchedAt` — see [§18 Timezone policy](#18-timezone-policy)

### Optional future UX (not MVP)

- When rematch allowed and happens: subtle UI *"You've crossed paths before"* — no names, no date细节

### Edge cases

| Case | Behavior |
|------|----------|
| Matched Mon, next match Sun same week | ❌ Blocked |
| Matched Sun week 28, match Mon week 29 | ✅ Allowed |
| User blocked partner | ❌ Never (until unblock) |
| Queue wait > 15 min | Widen timezone scoring |

---

## 9. Photo relay flow

```
iOS: compress JPEG (80KB)
  → POST /upload/request { sessionId, hourIndex, weather }
  → Function validates slot + session membership
  → Returns upload token / presigned URL / GridFS upload endpoint
  → iOS uploads bytes
  → POST /upload/confirm
  → Function writes hour_uploads + APNs silent → partner
  → Partner: GET /partner/latest
  → Download blob → SwiftData + WidgetDataStore → widget reload
```

Server never stores precise GPS — only country/timezone from user profile.

---

## 10. Push notifications (APNs)

Same as before — **APNs direct** from Atlas Function (store `.p8` in Atlas Values/Secrets).

| Type | Silent? | When |
|------|---------|------|
| `partner.photo` | ✅ | New hour uploaded |
| `session.matched` | No | Pair found |
| `session.farewell` | No | T-2h |
| `session.ended` | No | 24h up |
| Hourly reminder | No | **Local only** (already on iOS) |

---

## 11. Auth & identity

### Sign in with Apple → Atlas

**Option A (preferred if Auth still works on your Atlas project):**  
Atlas App Services Authentication — Apple provider → user JWT for Functions.

**Option B (fallback):**  
Verify Apple identity token in Atlas Function → issue custom session token → MongoDB `users` upsert.

### Stored per user

✅ Anonymous `userId`, country, timezone, APNs token  
❌ Name, email in app, precise location

---

## 12. Security & moderation

Same as prior plan — report, block, client Vision check, CSAM before App Store.  
**Block always overrides weekly rematch.**

---

## 13. iOS client integration

### Dependencies

```swift
// No Realm. Existing Apple stack only:
// SwiftUI, SwiftData, WeatherKit, UserNotifications, WidgetKit
// + URLSession for Atlas Functions HTTPS calls
```

### Service protocol (unchanged pattern)

```swift
protocol SessionServiceProtocol {
    func findMatch() async throws -> StrangerSession
    func submitPhoto(_ data: Data, hourIndex: Int, weather: String) async throws
    func fetchPartnerPhoto(hourIndex: Int?) async throws -> Data?
    func submitFarewell(_ text: String) async throws
}

final class AtlasSessionService: SessionServiceProtocol { /* HTTPS → Functions */ }
final class MockSessionService: SessionServiceProtocol { /* current */ }
```

### Config (gitignored `Secrets.xcconfig`)

```
ATLAS_APP_ID = ...
ATLAS_FUNCTION_BASE_URL = https://...mongodb.net/api/client/v2.0/app/.../functions/call
MONGODB_ATLAS_GROUP_ID = ...
```

---

## 14. Environments & secrets

| Env | Atlas cluster | Functions |
|-----|---------------|-----------|
| `dev` | M0 free tier | `pov-stranger-dev` |
| `prod` | M10+ | `pov-stranger-prod` |

Secrets: `APNS_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID`, Apple Services ID

---

## 15. Cost model

| Resource | 1k pairs/day | Monthly est. |
|----------|--------------|--------------|
| M0 cluster | Dev | $0 |
| M10 prod | Production | ~$57/mo (or M2 ~$9) |
| GridFS storage | ~4 GB peak | Included in cluster |
| Functions invocations | ~150k/mo | Low / included |
| APNs | Free | $0 |

**MVP dev: $0.** Production: **~$10–60/mo** depending on cluster tier.

---

## 16. Implementation phases

### 4a — Atlas setup
- [ ] MongoDB Atlas project + cluster
- [ ] Collections + indexes + TTL
- [ ] GridFS bucket config
- [ ] SwiftData models already in app ✅

### 4b — Auth
- [ ] Sign in with Apple
- [ ] User upsert in `users`
- [ ] `device_tokens` registration

### 4c — Matching
- [ ] `matchEnqueue` Function + weekly `canPair` check
- [ ] `pair_history` with `isoWeek` / `isoWeekYear`
- [ ] iOS replace mock `findMatch`

### 4d — Photo relay
- [ ] GridFS upload/download Functions
- [ ] APNs silent push on confirm
- [ ] SwiftData cache + widget update

### 4e — Lifecycle
- [ ] Farewell send/fetch
- [ ] Scheduled purge Trigger
- [ ] Report + block

---

## 17. Decision log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-13 | ~~Supabase~~ → **MongoDB Atlas** | User choice; document model + TTL fit |
| 2026-07-13 | Local DB | **SwiftData only** — no Realm |
| 2026-07-13 | Photos in **GridFS** | Native MongoDB blob storage + TTL |
| 2026-07-13 | Rematch: **allowed after new ISO week** | "Có duyên thì gặp lại" — not same week |
| 2026-07-13 | `pair_history` kept permanently | Weekly check only; metadata, no photos |
| 2026-07-13 | Block > rematch | Safety override |
| 2026-07-13 | Weather: client WeatherKit | No server cost |
| 2026-07-13 | Push: APNs direct from Functions | Silent widget refresh |
| 2026-07-13 | **Timezone policy** | Store UTC; rematch week in UTC; display partner local; notifications device-local |
| 2026-07-13 | **Backend language** | **JS (Atlas Functions) for now**; revisit Go API if scale requires it |

---

## 18. Timezone policy

> **Decision (2026-07-13):** One rule per concern — don't use one timezone for everything.

### Summary table

| Concern | Timezone | Why |
|---------|----------|-----|
| **Server timestamps** | **UTC** (`ISODate`) | Single source of truth, no DST bugs |
| **Session 24h expiry** | **Absolute** (`startedAt + 24h` UTC) | Fair — both users same duration |
| **Hour slot index** | **Session-relative** (hour 0–23 from match) | No timezone math |
| **Weekly rematch** | **ISO week in UTC** | One canonical “tuần” for pair_history |
| **Partner clock in UI** | **Partner's `timezoneId`** | "2:14 AM in Iceland" — already in app |
| **Hourly notifications** | **Device local** | `UNCalendarNotificationTrigger` — user's clock |
| **Match scoring** | **UTC offset from `timezoneId`** | Maximize hour difference between strangers |

### Why UTC for rematch week (not user local)?

| Option | Problem |
|--------|---------|
| User A's timezone | Unfair — Iceland user could "skip" week boundary earlier |
| User B's timezone | Same, reversed |
| Both must be new week | Too strict — pair blocked until both calendars flip |
| **UTC (chosen)** | One server rule, predictable, can't game by changing device TZ |

**Edge case:** Sunday 11pm UTC vs Monday 8am Vietnam — server says same UTC week. That's OK: "tuần" is an internal rule, users never see "ISO week 28".

### Implementation

```js
// Atlas Function — at match time
function isoWeekUTC(date) {
  // Use a well-tested lib (e.g. date-fns getISOWeek) in the Function
  return { isoWeek, isoWeekYear }  // derived from UTC instant
}

function canPair(userA, userB) {
  const { isoWeek, isoWeekYear } = isoWeekUTC(new Date())
  const hit = pair_history.findOne({ userA, userB, isoWeek, isoWeekYear })
  return !hit
}
```

### iOS client

| Field | Source |
|-------|--------|
| `timezoneId` on upload / enqueue | `TimeZone.current.identifier` |
| Partner local time display | `session.partnerTimeZoneIdentifier` (from server at match) |
| Session countdown | Absolute `expiresAt` — `TimelineView` already UTC-safe |

### What we do NOT do

- ❌ Store "local midnight" for session end
- ❌ Compute hour slots in partner's timezone
- ❌ Let user pick timezone for rematch rules

---

## Next step

1. Create MongoDB Atlas cluster (M0)
2. Define collections + TTL indexes
3. Implement `canPair()` with ISO week check
4. Add `AtlasSessionService` writing to existing SwiftData models

See [`PLAN.md` → Phase 4](PLAN.md#phase-4--backend-relay).
