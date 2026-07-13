# POV-Stranger

> See a life you'll never know. For one day only.

Anonymous 24-hour photo exchange with a random stranger on the other side of the world. Inspired by [Locket](https://locket.camera), but for strangers — no names, no chat, no history.

## Concept

| Locket | POV-Stranger |
|--------|--------------|
| Close friends | Complete strangers |
| Photos saved forever | Ephemeral — gone after 24h |
| Know who you're sharing with | Anonymous — distance, weather, country only |
| Ongoing connection | One session, then never again |

### Core loop

1. **Match** — paired randomly with someone far away (e.g. Vietnam ↔ Iceland)
2. **Exchange** — each hour, both capture a photo; partner's latest appears on your widget
3. **Observe** — see their world through metadata: distance, local weather, local time, country silhouette
4. **Farewell** — in the last 2 hours, send one final message (message in a bottle)
5. **Vanish** — session ends; all photos deleted; strangers never reconnect

## Tech stack

| Layer | Choice |
|-------|--------|
| UI | SwiftUI (iOS 26, Liquid Glass) |
| Persistence | SwiftData (active session only, ephemeral) |
| Widget | WidgetKit + App Groups *(planned)* |
| Auth | Sign in with Apple → MongoDB Atlas |
| Local DB | **SwiftData** (Apple stack) |
| Backend | **MongoDB Atlas** + Atlas Functions — [`docs/BACKEND.md`](docs/BACKEND.md) |
| Storage | GridFS (photos, 25h TTL) |
| Push | APNs from Atlas Functions |
| Rematch | Same strangers can meet again — **not in the same ISO week** |

## Project location

This repo lives on an external SSD to save internal storage:

```
/Volumes/990evo/xcode/projects/POV-Stranger/
```

Xcode is configured with:
- **DerivedData** → `/Volumes/990evo/xcode/DerivedData`
- **Xcode.app** → `/Volumes/990evo/xcode/Xcode.app`

## Getting started

### Requirements

- macOS with Xcode 26.5+
- iOS 26.5 Simulator or device
- External drive mounted at `/Volumes/990evo` (or adjust paths)

### Build & run

```bash
cd "/Volumes/990evo/xcode/projects/POV-Stranger"
xcodebuild -project POV-Stranger.xcodeproj \
  -scheme POV-Stranger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /Volumes/990evo/xcode/DerivedData \
  build
```

Or open in Xcode and run on simulator (⌘R).

### Xcode Previews on external drive

If Canvas shows *"Failed to setup simulator"*:

1. Run on Simulator first (⌘R) — previews often work after a successful run
2. Ensure simulator data isn't corrupted: **Device → Erase All Content and Settings**
3. Consider symlinking CoreSimulator to the external drive (see `docs/PLAN.md` → Dev Environment)
4. As fallback, use `#Preview` with in-memory SwiftData (already used in views)

## Project structure

```
POV-Stranger/
├── POV-Stranger/
│   ├── App/                 # Entry point
│   ├── Models/              # SwiftData models
│   ├── Services/            # Session, notifications, widget store
│   ├── Views/               # Screens + components
│   └── Assets.xcassets/
├── POVStrangerWidget/       # Home Screen widget extension
├── Shared/                  # App Group types shared with widget
├── docs/
│   ├── PLAN.md              # Implementation checklist
│   └── BACKEND.md           # Backend & storage architecture
└── README.md                # This file
```

## Current status

See [docs/PLAN.md](docs/PLAN.md) for the full checklist. Summary:

- [x] Project scaffold (SwiftUI + SwiftData template)
- [x] Build succeeds on external drive
- [x] Documentation (README + PLAN)
- [x] Domain models
- [x] Mock session / pairing
- [x] Main UI flow
- [x] Camera capture (basic)
- [x] Hourly local notifications
- [x] Widget extension (basic)
- [ ] Backend relay
- [ ] Push notifications
- [ ] App Store safety (moderation, 17+)

## Safety & privacy

This app exchanges photos between strangers. Before App Store submission:

- Age gate (17+)
- Report / block / instant unmatch
- CSAM moderation (Apple APIs + server-side)
- No precise GPS shared — country + approximate distance only
- No real-time chat — single farewell message only
- Ephemeral storage with server-side TTL

## License

Private — not yet licensed for distribution.

## Contributors

See git log. Read `docs/PLAN.md` before picking up any task.
