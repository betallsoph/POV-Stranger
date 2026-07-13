# POV-Stranger — Implementation Plan

> **For contributors:** Read this entire doc before writing code. Check boxes as you complete tasks. Each phase should be a separate PR or commit series. Do not skip safety requirements in Phase 6.

**Last updated:** 2026-07-13  
**Target:** iOS 26.5+, Xcode 26.5  
**Repo path:** `/Volumes/990evo/xcode/projects/POV-Stranger/`

---

## Table of contents

1. [Architecture overview](#1-architecture-overview)
2. [Data model spec](#2-data-model-spec)
3. [Phase 1 — Foundation (local / mock)](#phase-1--foundation-local--mock)
4. [Phase 2 — Camera & hourly slots](#phase-2--camera--hourly-slots)
5. [Phase 3 — Widget extension](#phase-3--widget-extension)
6. [Phase 4 — Backend relay](#phase-4--backend-relay)
7. [Phase 5 — End game & ephemeral purge](#phase-5--end-game--ephemeral-purge)
8. [Phase 6 — Safety & App Store](#phase-6--safety--app-store)
9. [Phase 7 — Polish & HIG](#phase-7--polish--hig)
10. [Dev environment (external drive)](#dev-environment-external-drive)
11. [File map](#file-map)
12. [Decision log](#decision-log)

---

## 1. Architecture overview

```
┌─────────────────────────────────────────────────────────┐
│                     POV-Stranger App                     │
├──────────────┬──────────────┬──────────────┬────────────┤
│    Views     │   Services   │    Models    │  Shared    │
│              │              │  (SwiftData) │  (Widget)  │
├──────────────┼──────────────┼──────────────┼────────────┤
│ RootView     │ SessionMgr   │ StrangerSess │ WidgetData │
│ WaitingView  │ MockPairing  │ HourSlot     │ (App Group)│
│ ActiveView   │ LocationMeta │ FarewellMsg  │            │
│ CaptureView  │ WeatherKit   │              │            │
│ FarewellView │ PhotoStore   │              │            │
└──────────────┴──────────────┴──────────────┴────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Backend (later)  │
                    │  Match + Relay    │
                    │  TTL 25h storage  │
                    └───────────────────┘
```

### Session lifecycle

```
[Idle] ──findMatch()──► [Matching] ──paired──► [Active 24h]
                                                  │
                                    ┌─────────────┼─────────────┐
                                    ▼             ▼             ▼
                              hourly slot   farewell window   expired
                              photo sync    (last 2h)         purge all
```

### Key constraints (iOS)

| Constraint | Impact | Workaround |
|------------|--------|------------|
| No background camera | Cannot auto-capture hourly | Local notification → user opens app to capture |
| WidgetKit refresh limits | Widget won't update exactly on the hour | APNs silent push + `WidgetCenter.reloadAllTimelines()` |
| No silent photo from partner | Partner must upload | Backend relay + push |
| Stranger photo sharing | App Review scrutiny | Moderation + 17+ + report flow |

---

## 2. Data model spec

### `StrangerSession`

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UUID` | Primary key |
| `startedAt` | `Date` | Match timestamp |
| `expiresAt` | `Date` | `startedAt + 24h` |
| `status` | `SessionStatus` | `.active`, `.farewell`, `.ended` |
| `partnerDistanceKm` | `Double` | Approximate, e.g. 12400 |
| `partnerCountryCode` | `String` | ISO 3166-1 alpha-2, e.g. `"IS"` |
| `partnerCountryName` | `String` | Display only, e.g. `"Iceland"` |
| `partnerWeatherSummary` | `String` | e.g. `"Snow · -2°C"` |
| `partnerTimeZoneIdentifier` | `String` | e.g. `"Atlantic/Reykjavik"` |
| `myFarewellText` | `String?` | Max 280 chars |
| `theirFarewellText` | `String?` | Delivered once at end |
| `slots` | `[HourSlot]` | Cascade delete |

### `HourSlot`

| Field | Type | Notes |
|-------|------|-------|
| `hourIndex` | `Int` | 0–23, relative to session start |
| `myPhotoData` | `Data?` | JPEG, max ~80KB compressed |
| `theirPhotoData` | `Data?` | From partner (mock in Phase 1) |
| `myCapturedAt` | `Date?` | When user submitted |
| `theirCapturedAt` | `Date?` | When partner submitted |

### `SessionStatus` enum

```swift
enum SessionStatus: String, Codable {
    case active      // Normal hourly exchange
    case farewell    // Last 2 hours — farewell message enabled
    case ended       // Session over, pending purge UI
}
```

### Business rules

- **Hour index:** `Int(session.elapsed / 3600)`, clamped 0–23
- **Farewell window:** when `expiresAt - now <= 2 hours` → status `.farewell`
- **Slot submission:** one photo per user per hour index
- **Purge:** on `.ended`, delete session + all photo data locally; server TTL 25h
- **No reconnect:** same pair never matched again (server enforces in Phase 4)

---

## Phase 1 — Foundation (local / mock)

> Goal: App runs end-to-end on simulator with fake partner. No network, no widget.

### 1.1 Documentation
- [x] `README.md` — project overview
- [x] `docs/PLAN.md` — this file

### 1.2 Domain models
- [ ] `Models/SessionStatus.swift`
- [ ] `Models/HourSlot.swift` — SwiftData `@Model`
- [ ] `Models/StrangerSession.swift` — SwiftData `@Model`
- [ ] Remove template `Item.swift`
- [ ] Update `POV_StrangerApp.swift` schema

### 1.3 Services
- [ ] `Services/MockPartner.swift` — preset strangers (Iceland, Brazil, Japan…)
- [ ] `Services/SessionManager.swift` — `@Observable`, MainActor
  - [ ] `findMatch()` — create session with random mock partner
  - [ ] `currentHourIndex(for:)` 
  - [ ] `updateSessionStatus(for:)` — active → farewell
  - [ ] `endSession(_:)` — purge SwiftData
  - [ ] `submitFarewell(_:text:)` 

### 1.4 Views
- [ ] `Views/RootView.swift` — routes by session state
- [ ] `Views/WaitingForMatchView.swift` — idle + "Find a stranger" CTA
- [ ] `Views/ActiveSessionView.swift` — partner metadata + timeline
- [ ] `Views/Components/PartnerMetadataCard.swift` — distance, weather, time
- [ ] `Views/Components/HourTimelineView.swift` — 24-slot grid
- [ ] `Views/Components/SessionCountdownView.swift` — time remaining
- [ ] `Views/SessionEndedView.swift` — show farewell + dismiss
- [ ] Replace `ContentView.swift` usage with `RootView`

### 1.5 Dev / debug
- [ ] `#Preview` blocks with in-memory ModelContainer
- [ ] Debug: fast-forward hour button (DEBUG only)

**Phase 1 done when:** User can tap Find → see mock partner metadata → see 24-slot timeline → session countdown ticks → farewell at T-2h → session ends and data purges.

---

## Phase 2 — Camera & hourly slots

> Goal: Real photo capture and slot submission.

### 2.1 Permissions
- [ ] `NSCameraUsageDescription` in Info.plist (via build setting)
- [ ] `Services/CameraPermission.swift` — check/request access

### 2.2 Photo capture
- [ ] `Views/CapturePhotoView.swift` — `UIImagePickerController` wrapper or `PhotosUI`
- [ ] `Services/PhotoCompressor.swift` — resize to max 800px, JPEG ~80KB
- [ ] `SessionManager.submitPhoto(_:image:for:)` — save to current hour slot

### 2.3 Hourly prompts (local only)
- [ ] `Services/HourlyReminderScheduler.swift` — `UNUserNotificationCenter`
- [ ] Schedule 24 notifications per session (or rolling next-hour)
- [ ] Cancel on session end

### 2.4 Mock partner photos
- [ ] `MockPartner.randomPhoto()` — placeholder images from assets or SF Symbol composite
- [ ] Simulate partner upload delay (2–10s after user submits)

**Phase 2 done when:** User captures photo → appears in their slot → mock partner photo appears in corresponding slot.

---

## Phase 3 — Widget extension

> Goal: Home Screen widget shows partner's latest photo + metadata.

### 3.1 Xcode target setup
- [ ] Add **Widget Extension** target: `POVStrangerWidget`
- [ ] Add **App Group**: `group.antt.POV-Stranger`
- [ ] Shared `Shared/WidgetSnapshot.swift` (or duplicate minimal struct)

### 3.2 Widget data flow
- [ ] `Services/WidgetDataStore.swift` — write snapshot to App Group `UserDefaults` or file
- [ ] Snapshot fields: `theirPhotoData`, `distanceKm`, `weather`, `localTime`, `hourIndex`, `expiresAt`
- [ ] Call `WidgetCenter.shared.reloadAllTimelines()` on photo receive

### 3.3 Widget UI
- [ ] `POVStrangerWidget.swift` — `StaticConfiguration` or `AppIntentConfiguration`
- [ ] Small + medium widget families
- [ ] Full-bleed partner photo + glass metadata overlay (iOS 26)
- [ ] Placeholder / empty state: "Waiting for your stranger…"

### 3.4 Deep link
- [ ] `povstranger://session` URL scheme → opens app to active session

**Phase 3 done when:** Widget on Home Screen updates when mock partner photo changes.

---

## Phase 4 — Backend relay

> Goal: Two real devices can match and exchange photos.

### 4.1 Choose backend
- [ ] Decision: Supabase vs Firebase (see [Decision log](#decision-log))
- [ ] Create project + env config

### 4.2 Auth
- [ ] Sign in with Apple
- [ ] Anonymous user ID (no profile, no name)

### 4.3 Database schema (Supabase example)

```sql
-- users: apple_user_id, created_at, last_matched_at, blocked_countries[]

-- match_queue: user_id, enqueued_at, timezone, country_code

-- sessions: id, user_a, user_b, started_at, expires_at, status

-- hour_uploads: session_id, user_id, hour_index, photo_url, captured_at
  -- TTL: auto-delete after 25h via pg_cron or bucket lifecycle

-- farewells: session_id, user_id, text, sent_at
  -- delivered once to partner, then deleted
```

### 4.4 Matching service
- [ ] Enqueue on "Find stranger"
- [ ] Pair users maximizing timezone distance
- [ ] Prevent rematch (same pair ever)
- [ ] Edge case: odd user out → wait or bot? (document choice)

### 4.5 Photo relay
- [ ] Upload compressed JPEG to storage bucket
- [ ] Notify partner via APNs silent push
- [ ] Partner app downloads → updates widget
- [ ] No long-term storage — bucket lifecycle 25h

### 4.6 Replace mock
- [ ] `SessionManager` uses `BackendSessionService` protocol
- [ ] `MockSessionService` kept for simulator / previews

**Phase 4 done when:** Two TestFlight devices match, exchange photos for 1+ hours, receive push updates.

---

## Phase 5 — End game & ephemeral purge

> Goal: Farewell message + complete data deletion.

### 5.1 Farewell flow
- [ ] `Views/FarewellComposeView.swift` — 280 char limit, one-shot
- [ ] Enable only when `status == .farewell`
- [ ] Disable after submit

### 5.2 Session end
- [ ] At `expiresAt`: server closes session
- [ ] Push both devices: "Your stranger is gone"
- [ ] `Views/SessionEndedView.swift` — reveal partner's farewell (once)
- [ ] Local purge: SwiftData delete + App Group clear + cancel notifications

### 5.3 Server purge
- [ ] Delete all `hour_uploads` for session
- [ ] Delete storage objects
- [ ] Keep only anonymized analytics (optional, no PII)

**Phase 5 done when:** After 24h, all photos gone locally and on server; farewell shown once then gone.

---

## Phase 6 — Safety & App Store

> **Blocking for release.** Do not ship without these.

### 6.1 Moderation
- [ ] On-device sensitive content check before upload (Apple Vision framework)
- [ ] Server-side CSAM hash checking
- [ ] Report button on every partner photo
- [ ] Report → instant unmatch + block + flag for review

### 6.2 Legal & compliance
- [ ] Age gate 17+ (App Store age rating + in-app confirmation)
- [ ] Privacy Policy + Terms of Service
- [ ] App Privacy Nutrition Labels (location: approximate country only)
- [ ] GDPR: data deletion on request

### 6.3 App Review prep
- [ ] Demo video showing full flow
- [ ] Review notes explaining stranger photo concept + moderation
- [ ] Test account or simulated match for reviewer

**Checklist:**
- [ ] Report flow works
- [ ] Block prevents rematch
- [ ] No precise GPS in network payloads
- [ ] No chat except farewell
- [ ] Photos deleted after session

---

## Phase 7 — Polish & HIG

### 7.1 Visual design (iOS 26)
- [ ] Liquid Glass on floating controls (`.glassEffect()`)
- [ ] Semantic system colors only
- [ ] SF Symbols throughout
- [ ] Dynamic Type support
- [ ] Dark mode + Tinted mode verified

### 7.2 Onboarding
- [ ] 3-screen onboarding: concept → permissions → find stranger
- [ ] Notification permission request (with context)

### 7.3 Accessibility
- [ ] VoiceOver labels on all interactive elements
- [ ] Reduce Motion respected
- [ ] Sufficient contrast on metadata overlays

### 7.4 Localization (optional)
- [ ] String Catalogs for EN + VI

---

## Dev environment (external drive)

### Current setup ✓
- Projects: `/Volumes/990evo/xcode/projects/`
- DerivedData: `/Volumes/990evo/xcode/DerivedData` (`IDECustomDerivedDataLocation`)
- Xcode: `/Volumes/990evo/xcode/Xcode.app` (`xcode-select -p`)

### Simulator still on internal drive
CoreSimulator (~2.5 GB) is at `~/Library/Developer/CoreSimulator`.

**Optional: move simulator to external drive**

```bash
# Quit Xcode and Simulator first!
mv ~/Library/Developer/CoreSimulator /Volumes/990evo/xcode/CoreSimulator-data
ln -s /Volumes/990evo/xcode/CoreSimulator-data ~/Library/Developer/CoreSimulator
```

### Preview failures
If Canvas shows "Failed to setup simulator":
1. Run on simulator once (⌘R)
2. Product → Clean Build Folder
3. Erase simulator content
4. Check external drive is mounted before opening Xcode

### Build from CLI

```bash
xcodebuild -project POV-Stranger.xcodeproj \
  -scheme POV-Stranger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /Volumes/990evo/xcode/DerivedData \
  build
```

---

## File map

```
POV-Stranger/
├── POV-Stranger/
│   ├── App/
│   │   └── POV_StrangerApp.swift
│   ├── Models/
│   │   ├── SessionStatus.swift
│   │   ├── HourSlot.swift
│   │   └── StrangerSession.swift
│   ├── Services/
│   │   ├── SessionManager.swift
│   │   ├── MockPartner.swift
│   │   ├── PhotoCompressor.swift          [Phase 2]
│   │   ├── HourlyReminderScheduler.swift  [Phase 2]
│   │   └── WidgetDataStore.swift          [Phase 3]
│   ├── Views/
│   │   ├── RootView.swift
│   │   ├── WaitingForMatchView.swift
│   │   ├── ActiveSessionView.swift
│   │   ├── CapturePhotoView.swift         [Phase 2]
│   │   ├── FarewellComposeView.swift      [Phase 5]
│   │   ├── SessionEndedView.swift
│   │   └── Components/
│   │       ├── PartnerMetadataCard.swift
│   │       ├── HourTimelineView.swift
│   │       └── SessionCountdownView.swift
│   └── Assets.xcassets/
├── POVStrangerWidget/                       [Phase 3]
├── docs/
│   └── PLAN.md
└── README.md
```

---

## Decision log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-13 | Project renamed `POV-Stranger` (no colon) | Colon in path breaks Xcode dependency files |
| 2026-07-13 | Session expires 24h from match time, not calendar midnight | Fair across timezones; simpler logic |
| 2026-07-13 | Farewell window = last 2 hours | Enough time without rushing |
| 2026-07-13 | Mock partner first, backend later | Unblock UI development |
| 2026-07-13 | SwiftData for local session | Native, fits ephemeral on-device cache |
| TBD | Supabase vs Firebase | Supabase: Postgres + RLS + TTL cron. Firebase: faster setup, pricier at scale |
| TBD | Exact photo compression target | Start 800px / 80KB JPEG, tune with real uploads |

---

## Commit convention

Use conventional commits per phase/task:

```
docs: add README and implementation plan
feat(models): add StrangerSession and HourSlot SwiftData models
feat(services): add SessionManager with mock pairing
feat(ui): add root navigation and active session view
feat(camera): add photo capture and slot submission
feat(widget): add home screen widget extension
feat(backend): add Supabase match and relay
```

One logical unit per commit. Do not mix unrelated changes.

---

## Questions for product owner

- [ ] Brand name final: `POV-Stranger` or rename to `Elsewhere` / `Parallel`?
- [ ] Farewell message: can partner see it before session ends, or only after?
- [ ] What happens if user captures 0 photos in 24h? Shame UI or neutral?
- [ ] Paid features? (second session per week, etc.)
- [ ] Android later?

---

*Update this doc when completing tasks or making architectural decisions.*
