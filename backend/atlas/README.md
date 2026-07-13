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

**Dependencies:** Add the `_lib/` helpers inline or as shared modules per Atlas UI.

Link cluster data source name: `mongodb-atlas` (default).

## 4. HTTPS endpoints

For each function, create an HTTPS Endpoint (authenticated) in App Services:

| Endpoint name | Function | Method |
|---------------|----------|--------|
| `matchEnqueue` | `matchEnqueue` | POST |
| `registerDeviceToken` | `registerDeviceToken` | POST |
| `getActiveSession` | `getActiveSession` | POST |

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
| `ATLAS_APP_ID` | App Services app id (optional, for logging) |

When `ATLAS_ENDPOINT_BASE` is empty, iOS uses **MockSessionService** automatically.

## 6. Auth (Phase 4b)

Enable **Sign in with Apple** in App Services Authentication, then pass JWT from iOS in `Authorization: Bearer <token>` header.

Functions read `context.user.id` as MongoDB user id.

## Collections

See [`docs/BACKEND.md`](../../docs/BACKEND.md) §5 for field definitions.
