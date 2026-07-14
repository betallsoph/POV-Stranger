# MongoDB Atlas — POV-Stranger Backend

Setup guide for cloud relay (Phase 4). Local app uses **SwiftData**; Atlas is HTTPS-only.

## Prerequisites

- [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) account
- Cluster: **M0** (dev) or **M10+** (prod), MongoDB 6.0+
- Atlas App Services app linked to cluster (for Functions)

## 1. Create cluster & database

1. New project → `pov-stranger-dev`
2. Create cluster (M0 free tier OK)
3. Database name: `povstranger`

## 2. Apply schema indexes

From project root, with [mongosh](https://www.mongodb.com/docs/mongodb-shell/) installed:

```bash
mongosh "<YOUR_CONNECTION_STRING>" --file backend/atlas/schema/init-indexes.js
```

Or paste `init-indexes.js` into Atlas → Browse Collections → `_MONGOSH` tab.

## 3. Deploy Atlas Functions

Copy each file from `backend/atlas/functions/` into Atlas App Services → Functions:

| Function | File | Purpose |
|----------|------|---------|
| `matchEnqueue` | `matchEnqueue.js` | Join queue + pair strangers |
| `registerDeviceToken` | `registerDeviceToken.js` | Save APNs token |
| `getActiveSession` | `getActiveSession.js` | Fetch current session for user |
| `uploadPhoto` | `uploadPhoto.js` | Upload JPEG to GridFS + `hour_uploads` |
| `getPartnerPhoto` | `getPartnerPhoto.js` | Download partner photo for hour |
| `submitFarewell` | `submitFarewell.js` | Send farewell message (T-2h) |
| `sessionLifecycle` | `sessionLifecycle.js` | **Scheduled** — farewell/end/purge |

**Dependencies:** Add `_lib/` helpers: `canPair.js`, `isoWeek.js`, `session.js`, `apns.js`, `farewell.js`, `purge.js`.

Link cluster data source name: `mongodb-atlas` (default).

## 4. HTTPS Endpoints

For each function, create an HTTPS Endpoint (authenticated) in App Services:

| Endpoint name | Function | Method |
|---------------|----------|--------|
| `matchEnqueue` | `matchEnqueue` | POST |
| `registerDeviceToken` | `registerDeviceToken` | POST |
| `getActiveSession` | `getActiveSession` | POST |
| `uploadPhoto` | `uploadPhoto` | POST |
| `getPartnerPhoto` | `getPartnerPhoto` | POST |
| `submitFarewell` | `submitFarewell` | POST |

**Scheduled Trigger:** `sessionLifecycle` every **15 minutes** (no HTTPS endpoint).

Copy the **App Services HTTP base URL** — iOS needs it in `Secrets.xcconfig`.

Example base (yours will differ):

```
https://data.mongodb-api.com/app/<APP_ID>/endpoint
```

## 5. iOS secrets

```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Edit Config/Secrets.xcconfig with your endpoint base URL
```

In Xcode: Project → Info → Configurations → set Debug/Release to use `Config/Secrets.xcconfig` if desired, or add keys to build settings.

Keys:

| Key | Description |
|-----|-------------|
| `ATLAS_ENDPOINT_BASE` | HTTPS endpoint base URL (no trailing slash) |
| `ATLAS_APP_ID` | App Services App ID (required for Sign in with Apple) |

When `ATLAS_ENDPOINT_BASE` is empty, iOS uses **MockSessionService** (no sign-in required).

When **both** keys are set, iOS requires **Sign in with Apple** before matching.

## 6. Auth — Sign in with Apple

### Apple Developer (mày làm)

1. [developer.apple.com](https://developer.apple.com) → Identifiers → `antt.POV-Stranger`
2. Enable **Sign in with Apple** capability
3. Xcode → Target → Signing & Capabilities → verify capability added

### Atlas App Services

1. App Services → **Authentication** → Enable **Apple**
2. Set bundle ID: `antt.POV-Stranger`
3. Copy **App ID** → paste into `ATLAS_APP_ID` in `Secrets.xcconfig`

### iOS flow (đã code sẵn)

1. User taps Sign in with Apple
2. App gets Apple `identityToken` → POST to Atlas auth API
3. Atlas returns `access_token` → stored in Keychain/UserDefaults
4. All function calls send `Authorization: Bearer <token>`

Functions use `context.user.id` as the MongoDB user id.

## 7. APNs — silent push (Phase 4d)

In App Services → **Values** (or Secrets):

| Key | Description |
|-----|-------------|
| `APNS_KEY_ID` | Apple Key ID (from `.p8` key) |
| `APNS_TEAM_ID` | Apple Team ID |
| `APNS_BUNDLE_ID` | `antt.POV-Stranger` |
| `APNS_PRIVATE_KEY` | Full contents of your `.p8` file |
| `APNS_USE_SANDBOX` | `true` for dev/TestFlight, `false` for App Store |

After `uploadPhoto`, partner receives silent push:

```json
{ "aps": { "content-available": 1 }, "type": "partner.photo", "sessionId": "...", "hourIndex": 3 }
```

iOS fetches photo via `getPartnerPhoto` and reloads widget. Upload works without APNs keys — push is skipped.

## Collections

See [`docs/BACKEND.md`](../../docs/BACKEND.md) §5 for field definitions.
