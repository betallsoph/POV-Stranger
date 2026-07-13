# POV-Stranger — Backend & Storage Architecture

> **Status:** Planning (pre-Phase 4)  
> **Last updated:** 2026-07-13  
> **Audience:** Anyone implementing backend relay, iOS sync, or infra for this app.

Read this before touching Phase 4 in [`PLAN.md`](PLAN.md).

---

## Table of contents

1. [What the backend must do](#1-what-the-backend-must-do)
2. [What the backend must NOT do](#2-what-the-backend-must-not-do)
3. [Recommended stack (decision)](#3-recommended-stack-decision)
4. [Alternatives considered](#4-alternatives-considered)
5. [System architecture](#5-system-architecture)
6. [Data model](#6-data-model)
7. [Storage design & TTL](#7-storage-design--ttl)
8. [Matching service](#8-matching-service)
9. [Photo relay flow](#9-photo-relay-flow)
10. [Push notifications (APNs)](#10-push-notifications-apns)
11. [Auth & identity](#11-auth--identity)
12. [Security, moderation & abuse](#12-security-moderation--abuse)
13. [iOS client integration](#13-ios-client-integration)
14. [Environments & secrets](#14-environments--secrets)
15. [Cost model](#15-cost-model)
16. [Implementation phases](#16-implementation-phases)
17. [Open product decisions](#17-open-product-decisions)

---

## 1. What the backend must do

| Capability | Detail |
|------------|--------|
| **Match strangers** | Pair two users for exactly one 24h session |
| **Relay photos** | 1-1 upload/download per hour slot, no feed |
| **Deliver metadata** | Partner country, timezone, approximate distance, weather summary (client or server computed) |
| **Notify partner** | Silent push → partner app downloads photo → widget refresh |
| **Farewell message** | One text per user, deliver once at session end |
| **Expire & purge** | Auto-delete all session data ≤ 25h after match |
| **Block rematch** | Same two users never paired again |
| **Report / block** | Instant unmatch + prevent future pairing |

### Non-functional requirements

| Requirement | Target |
|-------------|--------|
| Photo size | ≤ 80 KB JPEG, max 800px (already enforced client-side) |
| Uploads per active pair per day | ≤ 48 (24 × 2 users) |
| Storage retention | **25 hours max** (buffer after 24h session) |
| Latency (photo to partner) | < 5s P95 (excluding user opening app) |
| Uptime | 99.5% (MVP) — app degrades gracefully offline |
| Cost at 1k DAU | **< $30/month** infra |

---

## 2. What the backend must NOT do

- **No social graph** — no friends, followers, profiles
- **No chat** — except one farewell message at end
- **No photo history** — no gallery, no replay, no backups
- **No precise GPS storage** — country + coarse region only
- **No public URLs** — photos are private to the paired session
- **No ML on server for MVP** — optional later; start with client-side + hash blocklist

---

## 3. Recommended stack (decision)

### ✅ Primary recommendation: **Supabase + APNs direct**

| Layer | Technology | Why |
|-------|------------|-----|
| **Auth** | Supabase Auth + Sign in with Apple | Native Apple provider, JWT for RLS |
| **Database** | Supabase Postgres | Relational fit for sessions, queue, blocks; RLS |
| **Object storage** | Supabase Storage | Same project, signed URLs, lifecycle rules |
| **API / logic** | Supabase Edge Functions (Deno/TS) | Matching, upload webhooks, push dispatch |
| **Scheduled jobs** | `pg_cron` + Edge Function | Session expiry, purge, queue cleanup |
| **Push** | **APNs HTTP/2 direct** from Edge Function | Silent push for widget; no FCM dependency |
| **Weather** | WeatherKit on **iOS client** | No server weather API cost; upload summary with photo |
| **Moderation (MVP)** | Client Vision framework + server report flag | Phase 6 adds hash checking |

### Why not Firebase as primary?

Firebase is valid for MVP speed, but POV-Stranger's needs map better to Postgres:

| Need | Supabase | Firebase |
|------|----------|----------|
| TTL / scheduled purge | `pg_cron`, SQL deletes | Cloud Functions scheduler + manual deletes |
| "Never pair again" query | Simple SQL join on `pair_history` | Doable but awkward in Firestore |
| Row-level security per session | Postgres RLS | Security rules, harder to audit |
| Cost at ephemeral scale | Storage + egress predictable | Firestore reads add up with polling |
| Vendor lock-in | Postgres is portable | Firestore is not |

**Verdict:** Firebase if you want fastest solo MVP with familiar SDK. **Supabase if you want the architecture to stay clean through Phase 6.**

### Why not Cloudflare R2 + Workers only?

Excellent for **storage cost**, but you'd still need a database for matching, blocks, and session state. Viable as **Phase 4b optimization** (move blobs to R2, keep Supabase Postgres). Not recommended as day-one solo stack — more moving parts.

---

## 4. Alternatives considered

| Stack | Pros | Cons | When to pick |
|-------|------|------|--------------|
| **Supabase full** | All-in-one, SQL, RLS, good Swift SDK | Edge Functions cold starts | **Default choice** |
| **Firebase** | Fast setup, FCM built-in | Firestore modeling for ephemeral TTL | Solo hackathon MVP |
| **Supabase DB + Cloudflare R2** | Cheapest blob storage | Two vendors, signed URL plumbing | >10k DAU, egress pain |
| **Custom (Fly.io + Postgres + S3)** | Full control | You operate everything | Not for this project |
| **Parse / Appwrite** | Open source BaaS | Smaller ecosystem | Skip |

---

## 5. System architecture

```
┌─────────────┐         ┌─────────────┐
│  iOS App A  │         │  iOS App B  │
│  (Vietnam)  │         │  (Iceland)  │
└──────┬──────┘         └──────┬──────┘
       │  Sign in with Apple   │
       ▼                       ▼
┌──────────────────────────────────────────┐
│            Supabase Auth (JWT)            │
└──────────────────────────────────────────┘
       │                       │
       ▼                       ▼
┌──────────────────────────────────────────┐
│              Edge Functions               │
│  ┌────────────┐ ┌──────────┐ ┌─────────┐ │
│  │ match-queue│ │ upload   │ │ session │ │
│  │ /enqueue   │ │ /confirm │ │ /expire │ │
│  └────────────┘ └──────────┘ └─────────┘ │
└──────────────────────────────────────────┘
       │            │              │
       ▼            ▼              ▼
┌────────────┐ ┌──────────┐ ┌───────────┐
│  Postgres  │ │ Storage  │ │   APNs    │
│  (RLS)     │ │ (photos) │ │  (push)   │
└────────────┘ └──────────┘ └───────────┘
```

### Trust boundaries

1. **Client** compresses photo, runs on-device moderation (Phase 6), requests signed upload URL
2. **Edge Function** validates session + hour slot, returns signed URL scoped to `session_id/user_id/hour_N.jpg`
3. **Storage** object is private; only partner can get signed download URL via RLS-guarded function
4. **APNs** silent push sent to partner device token after upload confirm
5. **Cron** deletes DB rows + storage objects after TTL

---

## 6. Data model

### Entity relationship

```
users ─────┬──── match_queue
           ├──── sessions (as user_a or user_b)
           ├──── device_tokens
           ├──── blocks
           └──── pair_history

sessions ──┬──── hour_uploads
           └──── farewells
```

### Tables (Postgres)

#### `users`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | Supabase auth user id |
| `created_at` | `timestamptz` | |
| `last_matched_at` | `timestamptz` nullable | Cooldown enforcement |
| `country_code` | `char(2)` | From client locale / coarse geo |
| `timezone_id` | `text` | e.g. `Asia/Ho_Chi_Minh` |
| `is_banned` | `boolean` default false | Admin flag |
| `match_cooldown_until` | `timestamptz` nullable | Optional: 1 session per 24h |

> **No** name, email display, avatar, or precise coordinates.

#### `device_tokens`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `user_id` | `uuid` FK → users | |
| `token` | `text` | APNs device token (hex) |
| `updated_at` | `timestamptz` | Upsert on app launch |

#### `match_queue`

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | `uuid` PK FK | One row per waiting user |
| `enqueued_at` | `timestamptz` | |
| `country_code` | `char(2)` | For distance scoring |
| `timezone_id` | `text` | For distance scoring |

#### `sessions`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `user_a` | `uuid` FK | Lower uuid canonical order |
| `user_b` | `uuid` FK | |
| `started_at` | `timestamptz` | |
| `expires_at` | `timestamptz` | `started_at + 24h` |
| `status` | `text` | `active` / `farewell` / `ended` / `purged` |
| `user_a_country` | `char(2)` | Snapshot at match time |
| `user_b_country` | `char(2)` | |
| `user_a_timezone` | `text` | |
| `user_b_timezone` | `text` | |

#### `hour_uploads`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `session_id` | `uuid` FK | |
| `user_id` | `uuid` FK | Uploader |
| `hour_index` | `smallint` | 0–23 |
| `storage_path` | `text` | `sessions/{id}/{user_id}/{hour}.jpg` |
| `weather_summary` | `text` nullable | Client-provided snapshot |
| `captured_at` | `timestamptz` | |
| `created_at` | `timestamptz` | For TTL purge |

**Unique constraint:** `(session_id, user_id, hour_index)` — one photo per user per hour.

#### `farewells`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `session_id` | `uuid` FK | |
| `user_id` | `uuid` FK | Sender |
| `text` | `varchar(280)` | |
| `sent_at` | `timestamptz` | |
| `delivered_at` | `timestamptz` nullable | Set when partner fetches |

**Unique constraint:** `(session_id, user_id)` — one farewell per user.

#### `pair_history`

| Column | Type | Notes |
|--------|------|-------|
| `user_a` | `uuid` | Canonical order (lower uuid first) |
| `user_b` | `uuid` | |
| `session_id` | `uuid` FK | |
| `matched_at` | `timestamptz` | |

**Unique constraint:** `(user_a, user_b)` — never match again.

#### `blocks`

| Column | Type | Notes |
|--------|------|-------|
| `blocker_id` | `uuid` | |
| `blocked_id` | `uuid` | |
| `created_at` | `timestamptz` | |

**Unique constraint:** `(blocker_id, blocked_id)`

#### `reports`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | |
| `reporter_id` | `uuid` | |
| `session_id` | `uuid` | |
| `reported_user_id` | `uuid` | |
| `reason` | `text` | |
| `created_at` | `timestamptz` | |

> Reports may reference purged sessions — store `session_id` + snapshot metadata, not photos.

---

## 7. Storage design & TTL

### Bucket structure

```
photos/                          # Private bucket, no public access
  sessions/
    {session_id}/
      {user_id}/
        00.jpg
        01.jpg
        ...
        23.jpg
```

### Upload flow (signed URL)

1. Client calls `POST /upload/request` with `{ session_id, hour_index, weather_summary }`
2. Edge Function validates:
   - User is in session
   - Hour index matches server-computed slot (or ±1 grace window)
   - Slot not already uploaded
3. Returns signed upload URL (PUT, 5 min expiry, max 100 KB)
4. Client uploads JPEG directly to Storage
5. Client calls `POST /upload/confirm`
6. Edge Function writes `hour_uploads` row, sends APNs to partner

### Download flow

1. Partner calls `GET /partner/latest` or `GET /partner/hour/{n}`
2. Edge Function verifies session membership
3. Returns signed download URL (60s expiry) — **not** a permanent link

### TTL / purge strategy

| Layer | Mechanism | Timing |
|-------|-----------|--------|
| **Storage objects** | Supabase Storage lifecycle OR cron deletes prefix | `expires_at + 1h` |
| **hour_uploads rows** | `pg_cron` job | `created_at > 25h` → delete |
| **farewells** | Delete after both delivered + session ended | `expires_at + 2h` |
| **sessions** | Status → `purged`, keep row 7d for reports only (no photos) | Configurable |
| **pair_history** | **Keep forever** (only uuids, no content) | Permanent |

```sql
-- Example purge job (runs every 15 min)
DELETE FROM hour_uploads WHERE created_at < now() - interval '25 hours';
DELETE FROM farewells WHERE sent_at < now() - interval '25 hours';
UPDATE sessions SET status = 'purged'
  WHERE expires_at < now() - interval '1 hour' AND status != 'purged';
```

---

## 8. Matching service

### Algorithm (MVP)

```
ON enqueue(user):
  1. Remove user from any existing queue row
  2. Find best candidate in match_queue WHERE:
     - user_id != current
     - NOT blocked either direction
     - NOT in pair_history
     - NOT currently in active session
  3. Score candidates by timezone_distance (maximize)
     bonus: different country_code
  4. IF candidate found:
     - CREATE session (24h)
     - INSERT pair_history
     - DELETE both from match_queue
     - PUSH both: "matched" notification
     - RETURN session
  5. ELSE:
     - INSERT into match_queue
     - RETURN waiting
```

### Timezone distance scoring

```ts
// Pseudo: maximize hour offset between timezones
function score(userA: QueueEntry, userB: QueueEntry): number {
  const tzDiff = Math.abs(utcOffset(userA.timezone) - utcOffset(userB.timezone))
  const countryBonus = userA.country_code !== userB.country_code ? 1000 : 0
  return tzDiff * 10 + countryBonus
}
```

### Edge cases

| Case | Decision |
|------|----------|
| Odd user waiting > 5 min | Widen matching (allow same continent) |
| Odd user waiting > 15 min | Allow any non-blocked, non-previous pair |
| User already in active session | Reject enqueue, return existing session |
| User banned | Reject |
| Cooldown (1 session / 24h) | **TBD** — recommend yes for abuse prevention |
| Simulator / dev | `MockSessionService` bypasses all of this |

---

## 9. Photo relay flow

```
User A captures photo (hour 7)
        │
        ▼
POST /upload/request ──► signed PUT URL
        │
        ▼
PUT photo to Storage (direct, no server proxy)
        │
        ▼
POST /upload/confirm ──► insert hour_uploads
        │                  send APNs silent → User B
        ▼
User B app wakes (background fetch / push handler)
        │
        ▼
GET /partner/latest ──► signed GET URL
        │
        ▼
Download JPEG → WidgetDataStore → WidgetCenter.reloadAllTimelines()
```

### Metadata bundled with upload

Client sends (no precise GPS):

```json
{
  "session_id": "uuid",
  "hour_index": 7,
  "weather_summary": "Rain · 28°C",
  "captured_at": "2026-07-13T13:00:00Z"
}
```

Partner distance is **computed client-side** from country centroids (already known at match) — server does not need lat/long.

---

## 10. Push notifications (APNs)

### Why direct APNs (not FCM)

- iOS-only app
- Need **silent push** (`content-available: 1`) for widget refresh
- FCM adds a hop; Apple still delivers via APNs
- One less vendor

### Notification types

| Type | Silent? | When |
|------|---------|------|
| `partner.photo` | ✅ Yes | Partner uploaded new hour |
| `session.matched` | No | Pair found |
| `session.farewell` | No | T-2h warning |
| `session.ended` | No | 24h expired |
| `hourly.reminder` | No | **Keep local** on device (already implemented) |

### Server requirements

- Apple `.p8` key (APNs Auth Key)
- Store in Supabase secrets
- Edge Function uses HTTP/2 to `api.push.apple.com`
- Device token registered on app launch via `POST /device-token`

### Payload example (silent)

```json
{
  "aps": {
    "content-available": 1
  },
  "pov": {
    "type": "partner.photo",
    "session_id": "...",
    "hour_index": 7
  }
}
```

---

## 11. Auth & identity

### Sign in with Apple → Supabase

```
iOS: AuthenticationServices → identity token
     → supabase.auth.signInWithIdToken(provider: .apple)
     → JWT stored in Keychain
     → All API calls: Authorization: Bearer <jwt>
```

### What we store about users

| Stored | Not stored |
|--------|------------|
| Anonymous `user.id` (uuid) | Real name |
| Country code (self-reported / locale) | Email (Supabase may have it from Apple; don't expose) |
| Timezone | Apple user identifier in app UI |
| APNs token | Profile photo |

### Row Level Security (RLS) principles

- Users can **read** only their own active session
- Users can **read** partner's `hour_uploads` only for their shared `session_id`
- Users can **insert** uploads only for their own `user_id` + valid session
- **No** client direct access to `match_queue` — Edge Functions only
- **No** public Storage bucket

---

## 12. Security, moderation & abuse

### MVP (Phase 4 — minimal)

- [ ] Signed URLs only, short expiry
- [ ] RLS on all tables
- [ ] Rate limit: max 1 upload per hour per session (DB constraint)
- [ ] Max file size 100 KB at Storage policy level

### Required before App Store (Phase 6)

- [ ] Client-side sensitive content (`VNClassifyImageRequest` or similar)
- [ ] Report → `reports` table + instant block + session terminate
- [ ] Server CSAM hash check (PhotoDNA API or Apple CSAM API when available)
- [ ] Ban hammer for repeat reporters / reportees
- [ ] Age gate 17+

### Abuse vectors

| Vector | Mitigation |
|--------|------------|
| Spam uploads | Unique constraint + rate limit |
| Harassment via photos | Report + block + ban |
| Stalking via metadata | Country-level only, no GPS |
| Bot farming | Sign in with Apple + cooldown |
| Scraping | Signed URLs, no public bucket |

---

## 13. iOS client integration

### Protocol-based service layer

```swift
protocol SessionServiceProtocol {
    func findMatch() async throws -> StrangerSession
    func submitPhoto(_ data: Data, hourIndex: Int, weather: String) async throws
    func fetchPartnerPhoto(hourIndex: Int?) async throws -> Data?
    func submitFarewell(_ text: String) async throws
    func pollSessionStatus() async throws -> SessionStatus
}

final class MockSessionService: SessionServiceProtocol { /* current behavior */ }
final class SupabaseSessionService: SessionServiceProtocol { /* Phase 4 */ }
```

### App wiring

```swift
#if DEBUG
let sessionService: SessionServiceProtocol = useMock ? MockSessionService() : SupabaseSessionService()
#else
let sessionService: SessionServiceProtocol = SupabaseSessionService()
#endif
```

### New iOS dependencies

| Package | Purpose |
|---------|---------|
| `supabase-swift` | Auth, REST, Storage, Functions |
| (existing) | WeatherKit, UserNotifications, WidgetKit |

### Background modes (Info.plist)

- `remote-notification` — for silent push photo fetch
- No `location` background needed

---

## 14. Environments & secrets

| Env | Supabase project | Storage bucket | APNs |
|-----|------------------|----------------|------|
| `dev` | `pov-stranger-dev` | `photos-dev` | Sandbox APNs |
| `staging` | `pov-stranger-stg` | `photos-stg` | Sandbox APNs |
| `prod` | `pov-stranger-prod` | `photos` | Production APNs |

### Secrets (never in repo)

```
SUPABASE_URL
SUPABASE_ANON_KEY          # iOS app — RLS protects data
SUPABASE_SERVICE_ROLE_KEY  # Edge Functions only
APNS_KEY_ID
APNS_TEAM_ID
APNS_PRIVATE_KEY           # .p8 contents
```

### iOS config

Use `xcconfig` files (gitignored) or Xcode build settings:

```
SUPABASE_URL = https://xxx.supabase.co
SUPABASE_ANON_KEY = eyJ...
```

---

## 15. Cost model

### Assumptions: 1,000 active pairs/day (2,000 DAU)

| Resource | Daily volume | Monthly est. |
|----------|--------------|--------------|
| Photo storage (peak) | ~4 GB (25h retention) | ~$0.10 (Supabase 100GB included) |
| Photo uploads | 48k files × 80KB ≈ 3.8 GB/day transfer | Within free tier initially |
| Postgres | < 1M rows/month | Free tier |
| Edge Functions | ~100k invocations/month | Free tier |
| APNs | Free | $0 |

**MVP estimate: $0–25/month** until ~10k DAU.

### When to add Cloudflare R2

When Supabase Storage egress exceeds ~$20/month — migrate blobs to R2, keep Postgres on Supabase. Photos are short-lived so migration is straightforward.

---

## 16. Implementation phases

### 4a — Foundation (week 1)

- [ ] Create Supabase project (dev)
- [ ] Run SQL migrations (tables + RLS)
- [ ] Sign in with Apple working on iOS
- [ ] `SupabaseSessionService` skeleton
- [ ] Device token registration

### 4b — Matching (week 1–2)

- [ ] `match-queue/enqueue` Edge Function
- [ ] Pair algorithm + `pair_history`
- [ ] iOS: replace mock `findMatch` with real

### 4c — Photo relay (week 2)

- [ ] Signed upload/download URLs
- [ ] `upload/confirm` → APNs silent push
- [ ] iOS background handler → download → widget

### 4d — Farewell & expiry (week 2–3)

- [ ] `farewells` send + fetch once
- [ ] `session/expire` cron job
- [ ] Purge Storage + DB

### 4e — Hardening (week 3)

- [ ] Report + block endpoints
- [ ] Rate limits
- [ ] Staging environment
- [ ] TestFlight two-device test

---

## 17. Open product decisions

| # | Question | Recommendation | Status |
|---|----------|----------------|--------|
| 1 | Supabase vs Firebase? | **Supabase** | ✅ Recommended |
| 2 | 1 session per user per 24h cooldown? | **Yes** — reduces abuse | ⏳ Confirm |
| 3 | Farewell visible before session ends? | **No** — only after `ended` | ⏳ Confirm |
| 4 | Store session row after purge for reports? | **Yes** — metadata only, 30 days | ⏳ Confirm |
| 5 | Weather from client or server? | **Client (WeatherKit)** | ✅ Recommended |
| 6 | Odd user out > 15 min? | Widen match criteria | ✅ Recommended |
| 7 | Android later? | Skip for MVP; Supabase still works | ⏳ Confirm |

---

## Decision log update

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-13 | Backend: **Supabase** (Postgres + Storage + Edge Functions) | Ephemeral TTL, RLS, matching queries, cost |
| 2026-07-13 | Push: **APNs direct** | Silent push for widget, iOS-only |
| 2026-07-13 | Weather: **client-side WeatherKit** | No server API cost |
| 2026-07-13 | Storage path: `sessions/{id}/{user_id}/{hour}.jpg` | Simple purge by prefix |
| 2026-07-13 | Retention: **25h** for photos, permanent `pair_history` | Ephemeral content, rematch prevention |

---

## Next step

Once product decisions in §17 are confirmed, start **Phase 4a**: Supabase project + SQL migration + Sign in with Apple.

See [`PLAN.md` → Phase 4](PLAN.md#phase-4--backend-relay) for iOS task checklist.
