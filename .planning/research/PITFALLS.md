# Domain Pitfalls — OpenWhoop v2.0

**Domain:** BLE wearable + HealthKit + algorithm integration + SwiftUI redesign
**Researched:** 2026-05-31
**Confidence:** HIGH on BLE/backfill (grounded in actual code + v1.0 lessons); MEDIUM on HealthKit
and SwiftUI restructure (Apple docs + Context7 verified); MEDIUM on JADX (legal analysis).

> This file covers v2.0 integration pitfalls only. For v1.0 protocol RE pitfalls see the
> version of this file tagged at v1.0 (covers framing, capture, epoch correlation, etc.).

---

## Summary

Five distinct integration surfaces each carry independent failure modes. Risk ranking:

1. **Backfill / CoreBluetooth** — already broken in production; the ack-timing invariant is
   fragile and Maverick framing adds invisible off-by-one risk. Any new `.withResponse` write
   anywhere in the codebase can storm the handshake.
2. **HealthKit** — zero entitlement, zero plist keys, zero HealthKit code exists yet. Authorization
   denial is silent and permanent; the entire entitlement/plist/capability stack must be built
   from scratch before the first API call.
3. **Algorithm integration** — server-computed scores are displayed without staleness indication;
   offline degradation is not handled in the UI layer yet.
4. **SwiftUI tab restructure** — `RootTabView` has no selection binding and no state persistence;
   adding tabs while preserving existing navigation is fragile.
5. **JADX reference** — layout XML reveals structure but not data semantics; legal constraints
   apply to what can be reproduced.

---

## HealthKit Pitfalls

### HK-P1: Missing entitlement and plist keys will crash or silently no-op before the first line of HealthKit code runs

**What goes wrong:** `HKHealthStore().requestAuthorization(toShare:read:)` cannot be called until
two prerequisites exist: (1) the HealthKit capability is enabled in the Xcode target (which
auto-generates an `.entitlements` file with `com.apple.developer.healthkit = true`), and (2)
`NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` string keys exist in
`Info.plist`. Without the entitlement the binary is rejected at App Store submission. Without the
plist keys iOS raises a runtime exception before the authorization sheet appears.

**Current state:** `Info.plist` has no HealthKit usage description keys. No `.entitlements` file
exists in the project. Both must be created before any HealthKit symbol is even imported.

**Prevention:**
- Add the HealthKit capability in Xcode target settings first (auto-generates `.entitlements`).
- Add both usage description keys to `Info.plist` with user-facing Portuguese text.
- Add `UIBackgroundModes` entry `health-research` only if using `HKLiveWorkoutBuilder` — not
  needed for v2.0 (write-only export; the `bluetooth-central` mode already keeps the app alive).

### HK-P2: Authorization denial is silent and permanent — the app always receives "success"

**What goes wrong:** The user taps "Don't Allow" on the HealthKit authorization sheet. Apple's
privacy design always calls the completion handler with `success = true` regardless of the actual
choice. All subsequent `save()` calls also return no error, but nothing is written to the Health
store. The app's logs look clean; Health shows nothing.

**Consequences:** Data appears to export fine in all diagnostic surfaces; the user has no
feedback that export is broken.

**Prevention:**
- After requesting authorization call `HKHealthStore().authorizationStatus(for:)` for each
  quantity type. Surface a non-intrusive banner ("Acesso ao HealthKit negado — abrir Definições?")
  when `.sharingDenied` is returned.
- Never assume the authorization sheet will appear a second time — iOS only shows it once per
  type per app install. `requestAuthorization` after the first time is a no-op that calls
  completion immediately with `success = true`.

### HK-P3: HKQuantityType unit mismatches — the WhoopStore schema and HealthKit use different units

**What goes wrong:** Heart rate in HealthKit uses `HKUnit.count().unitDivided(by: .minute())`, not
raw `Int` BPM. HRV uses `HKUnit.secondUnit(with: .milli)` for RMSSD/SDNN (milliseconds). SpO₂
uses `HKUnit.percent()` with values in the range `0.0–1.0`, not `0–100`. Sleep sessions use
`HKCategoryType` (not `HKQuantityType`) and require explicit stage metadata.

**Current store format:** `hrSample` rows store `bpm: Int`. `rrInterval` rows store millisecond
integers (per WHOOP protocol). SpO₂ is stored as a percentage integer. All need a conversion
layer at the HealthKit boundary — do not mutate the WhoopStore schema to match HealthKit units.

**Prevention:**
- Create a dedicated `HealthKitExporter` class (not inline in `BLEManager` or `Backfiller`) that
  converts at the boundary: `Double(bpm)` with `count/min`, `Double(rr_ms) / 1000.0` with `s`,
  `Double(spo2_pct) / 100.0` with `%`.
- For sleep sessions use `HKCategoryValueSleepAnalysis` with `.asleepCore`, `.asleepREM`,
  `.asleepDeep`, `.awake`. These values were added in iOS 16 — confirm before targeting lower.
  This project targets iOS 16+, so use the new stage enum directly.

### HK-P4: Write conflicts with Apple Watch and third-party apps create duplicate samples

**What goes wrong:** Apple Watch writes HR every 5 s; OpenWhoop writes HR from the WHOOP strap
every 1–2 s (from the historical offload). Both appear in Health with no deduplication. The user
sees two HR sources, doubled data density, and skewed HRV averages.

**Prevention:**
- Accept duplicates in v2.0 as a known limitation. Tag all written samples with the app's
  `HKSource` (bundle ID) so power users can filter by source.
- Batch-write HR samples from the historical offload rather than writing in real time — this
  reduces contention frequency and lets Health coalesce display.
- Full pre-write deduplication (query existing samples in the window before inserting) is a
  v3 concern; it requires `HKSampleQuery` round-trips that complicate the already-loaded
  `onBackfillComplete` path.

### HK-P5: HKCategoryType sleep sessions must not overlap — the store has no overlap protection

**What goes wrong:** If two `HKCategoryType.sleepAnalysis` samples overlap in time, HealthKit
accepts both without error but the Health app displays erratic hypnogram artifacts and incorrect
total sleep figures. `LocalMetricsComputer` currently computes sleep sessions from raw BLE
streams with no overlap check against existing HealthKit data.

**Prevention:**
- Before writing a sleep session, query existing `HKCategoryType.sleepAnalysis` samples in the
  `[startTs, endTs]` window from this app's source. Skip or trim the new sample if overlap exists.
- The simpler v2.0 approach: delete all existing samples from this bundle ID in the session
  window, then insert fresh — safe because the source is keyed to this app's bundle ID only.

---

## Algorithm Integration Pitfalls

### ALG-P1: Stale algorithm results displayed as current without a staleness indicator

**What goes wrong:** `MetricsRepository.today` is set once per backfill completion and retained
until the next `refresh()`. If the server is unreachable, `today` shows yesterday's Recovery
score with today's date string. The current `TodayView` reads `coordinator.metrics.today` with no
age check and no "last updated" label.

**Current state:** `MetricsRepository` already publishes `lastRefreshedAt: Date?`. The field
exists but is not plumbed through to any view.

**Prevention:**
- Wire `lastRefreshedAt` to a subtitle on the Recovery card: "Actualizado há 2h".
- Define a staleness threshold (e.g. 4 hours). If `Date() - lastRefreshedAt > threshold` and
  connectivity is available, auto-trigger `refresh()` in the background from `.task`.
- Do not use `today?.day` (a date string) as a freshness proxy — a row can exist for today with
  values that were computed yesterday if the compute ran before midnight.

### ALG-P2: Offline-first compute and server-priority upsert produce a mixed-source display

**What goes wrong:** `refresh()` runs `computeLocalMetrics()` first (writes offline-derived values
to the DB), then `serverSync?.pullDerived()` (overwrites via `ON CONFLICT DO UPDATE`). If the
server returns `200` with an empty body (no rows computed yet for the newly-uploaded data), the
upsert is a no-op and offline values survive — which is correct. But if the server returns partial
data (some days computed, others not), the UI shows a mix of server-computed and locally-derived
values without any distinction.

**Prevention:**
- Add a `source` column (`"local"` | `"server"`) to `DailyMetric` (or at minimum to
  `CachedSleepSession`) in the next GRDB migration. Show a small indicator ("Estimado" vs
  "Calculado") in the card subtitle. This documents intent in the data layer, making future
  debugging unambiguous.

### ALG-P3: Server pipeline latency causes empty metric views immediately after first backfill

**What goes wrong:** On first launch the store is empty. The backfill uploads 14 days of data;
the server's `compute_day` pipeline takes 5–30 seconds per day. `pullDerived()` returns `[]`.
The UI shows "Sem dados" despite a full local store, because step 1 (`computeLocalMetrics`)
derived values that were then not surfaced by `load()` until step 3 ran.

**Prevention:**
- Verify that `refresh()` surfaces locally-derived metrics after step 1 without waiting for
  step 2 to complete. Currently `isRefreshing` stays `true` through all three steps — consider
  publishing a separate `isServerRefreshing` flag so the UI can render local data (step 1
  result) and show a spinner only for the server pull (step 2).

### ALG-P4: Algorithm version discontinuity appears as a data error in trend charts

**What goes wrong:** `openwhoop-algos` is updated on the server with an improved Recovery
algorithm. Old rows in `dailyMetric` retain old values. New rows get new values. The trend chart
shows a discontinuity at the upgrade date that is indistinguishable from a data collection gap.

**Prevention:**
- Tag each `DailyMetric` row with an `algo_version` string returned from the server response.
- When a version bump is detected, optionally trigger a server-side batch recompute for the
  historical window. This is a server operation; the client only needs to display the version
  and request the recompute.

---

## Backfill / CoreBluetooth Pitfalls

### BF-P1: `connectHandshakeDone` is the single most critical invariant — any new `.withResponse` write threatens it

**What goes wrong:** `didWriteValueFor` fires on every `.withResponse` write: the bond write,
every `SEND_HISTORICAL_DATA`, every `HISTORY_END` ack. Without the `connectHandshakeDone` guard
each re-entry would re-blast `GET_HELLO`/`SET_CLOCK` at the strap mid-offload and stop it from
streaming type-47 frames. This was the confirmed iOS-side root cause of the backfill stall
(BLEManager.swift line 803).

**Risk for v2.0:** New features — HealthKit export triggering a `SET_CLOCK` refresh, an alarm
feature calling `.withResponse`, a new protocol command — all produce `didWriteValueFor`
callbacks. If any code path bypasses or prematurely resets `connectHandshakeDone`, the handshake
storms the strap again.

**Prevention:**
- Never reset `connectHandshakeDone` except in `didDisconnectPeripheral`.
- Any new `.withResponse` command added anywhere in the codebase requires a code review
  specifically checking: (a) does it fire `didWriteValueFor`? (b) does the `guard
  !connectHandshakeDone else { return }` at line 804 short-circuit it correctly?
- The `ackHistoricalChunk` path already passes through this guard safely — verify any new path
  does the same before merging.

### BF-P2: Maverick frame offset errors corrupt chunk classification silently

**What goes wrong:** Maverick-wrapped frames have `packet_type` at `frame[8]` (not `frame[4]`
for Gen4). `isOffloadFrame()` already handles this via `isMaverick` detection. But any new code
that reads packet fields with hardcoded offsets (e.g. inside `classifyHistoricalMeta`) will
silently misclassify frames. A `HISTORY_END` misidentified as `.other` means the chunk is never
committed and the strap never receives the ack — the offload stalls without any error log.

**Prevention:**
- All frame-parsing must go through `parseFrame()`. Never read raw byte offsets outside
  `parseFrame()` and `isOffloadFrame()`.
- When debugging a stalled backfill: add a temporary log of the raw `meta` value from
  `classifyHistoricalMeta` for every frame in `Backfiller.ingest()`. A long run of `.other`
  for frames that should be `.end` reveals an offset bug immediately.

### BF-P3: Watchdog timeout shortened during debugging cuts sessions mid-drain

**What goes wrong:** `backfillIdleTimeoutSeconds = 60`. The WHOOP 5.0's continuous type-43 raw
flood (`REALTIME_RAW_DATA`) consumes BLE airtime and causes multi-second lulls between genuine
offload frames. If the watchdog is shortened (natural impulse when debugging a "stuck" backfill),
it fires mid-offload. `chunk` is cleared without acking. The `strap_trim` cursor does not
advance; the next offload resends the same chunk; the offload makes no progress.

**Prevention:**
- Do not shorten the watchdog below 60 s during debugging — use the `BF: frame #N type=X`
  counter log to judge progress instead.
- The `isOffloadFrame()` filter already excludes type-43 from re-arming the watchdog. Any
  new frame type added must explicitly be classified as offload or live — no default inclusion.

### BF-P4: Both `gen4DataNotifChar` and `dataNotifyChar` carry offload frames — routing must cover both

**What goes wrong:** Historical type-47 frames arrive on `gen4DataNotifChar` (61080005), not only
on `dataNotifyChar` (FD4B0005). The current `didUpdateValueFor` handles both. A refactor that
consolidates the routing code into only one characteristic handler silently drops all frames
arriving on the other.

**Prevention:**
- The `backfilling` flag and `routeBackfillFrame()` call must appear in handlers for both
  `gen4DataNotifChar` and `dataNotifyChar`. A unit test that injects frames on both mock
  characteristics during a backfill session and asserts correct frame counts is the only reliable
  regression guard.

### BF-P5: Frame queue drain task re-entrancy across `await` suspension points

**What goes wrong:** `backfillFrameQueue` is mutated synchronously in `routeBackfillFrame()`
(on `@MainActor`) and drained in `Task { @MainActor in ... }`. The `backfillDraining` guard
prevents double-drain. But if an `await` is inserted between `removeFirst()` and
`backfiller?.ingest(f)` in a future edit, re-entrancy becomes possible — Swift's `@MainActor`
serialisation does NOT protect across `await` suspension points.

**Prevention:**
- Keep the drain loop's body as a single `await backfiller?.ingest(f)` with no additional
  `await` calls interleaved. Never `await` upload or server-pull inside the drain loop.
- The current implementation already respects this ordering (upload/pull are deferred to
  `exitBackfilling`). Any edit that adds an `await` inside the drain while loop requires
  explicit concurrency review.

### BF-P6: Duplicate detection must be verified for every new biometric stream

**What goes wrong:** The backfill re-offloads the full 14-day strap store every 15 minutes.
If any new biometric stream added in v2.0 (SpO₂, skin temp, respiration) uses a plain `INSERT`
path rather than `ON CONFLICT (device_id, ts) DO UPDATE` or `DO NOTHING`, every periodic
backfill multiplies the row count. Duplicate rows corrupt HRV averages and sleep duration
calculations.

**Prevention:**
- Verify every new stream's insert path in the GRDB migration uses upsert semantics.
- Add a post-backfill assertion in debug builds that counts rows before and after and logs
  a warning if the count grew by more than the expected new records.

---

## SwiftUI Restructure Pitfalls

### UI-P1: `RootTabView` has no selection binding — adding tabs resets state and blocks deep links

**What goes wrong:** The current `RootTabView` uses `TabView { ... }` with no `selection`
binding and no `@SceneStorage`. Adding or reordering tabs changes the default selected index.
A user backgrounded on the Sleep tab wakes to TodayView with no indication anything changed.
Programmatic navigation (e.g. deep-link to a specific tab from a morning recovery notification)
is impossible without a selection binding.

**Prevention:**
- Add `@SceneStorage("selectedTab") private var selectedTab: Tab = .today` and bind it:
  `TabView(selection: $selectedTab)`. Do this as the first step of the tab restructure,
  before any tab is added or reordered, so existing tab indices are stable during the
  transition.
- Define tab positions as a typed `enum Tab: String, CaseIterable` (use `String` raw value
  for `@SceneStorage` and future Handoff compatibility) rather than `Int` so a reorder does
  not silently map a persisted integer to the wrong tab.

### UI-P2: Double `NavigationStack` when the new tab architecture meets the existing Device tab

**What goes wrong:** The current Device tab already wraps `LiveView()` in a `NavigationStack`.
If the new WHOOP-style root also applies a `NavigationStack` at the `TabView` level (a pattern
sometimes used for deep linking), the Device tab ends up with two stacked `NavigationStack`
instances. This causes duplicate back buttons, broken `.toolbar` placement, and navigation
title conflicts. SwiftUI does not warn about this; it silently misbehaves.

**Prevention:**
- Each tab must own its own `NavigationStack`. The root `TabView` must NOT wrap all tabs in a
  single outer `NavigationStack`. The current `NavigationStack { LiveView() }` pattern on the
  Device tab is correct — apply it consistently to all other tabs that require navigation.

### UI-P3: New `@EnvironmentObject` injected lazily in `.onAppear` is nil on first render

**What goes wrong:** `AppRootCoordinator.init()` wires `MetricsRepository` and `LiveViewModel`
synchronously before SwiftUI evaluates `body`. If a new service (e.g. `HealthKitExporter`) for
v2.0 is injected lazily in `.onAppear`, it is `nil` during the first render frame. SwiftUI
crashes with "No ObservableObject of type X found" at the first `@EnvironmentObject` access.

**Current state:** The comment in `OpenWhoopApp.swift` lines 22–34 explicitly documents that
all env objects must be wired in `AppRootCoordinator.init()` before `body` is evaluated.

**Prevention:**
- Create every new `@EnvironmentObject`-injectable service inside `AppRootCoordinator.init()`,
  not in `.onAppear`. Follow the existing pattern exactly. If a service requires async
  initialisation, use the lazy-open pattern already established in `MetricsRepository`.

### UI-P4: Local `@State` caches in views diverge from `MetricsRepository` published state

**What goes wrong:** A view adds `@State var recovery: Int?` to avoid an `@EnvironmentObject`
read. The state is loaded in `.task` or `.onAppear`. When `MetricsRepository.today` updates
(triggered by `onBackfillComplete`), the local `@State` does not — the view shows stale data
until the user navigates away and back.

**Prevention:**
- Views must read directly from `@EnvironmentObject private var metrics: MetricsRepository`
  via its `@Published` properties. Use `@State` only for transient UI state (sheet
  presentation, animation toggles). Never cache repository data in `@State`.

### UI-P5: Hardcoded dark colours break light mode and bypass the semantic colour system

**What goes wrong:** WHOOP's aesthetic uses near-black card backgrounds. Implementing this with
hardcoded `Color.black` or `Color(red: 0.05, green: 0.05, blue: 0.05)` ignores the system
appearance setting and produces black-on-white cards in light mode.

**Prevention:**
- Choose one of two explicit strategies and commit to it:
  - Apply `.preferredColorScheme(.dark)` to the root `WindowGroup` to lock the entire app to
    dark mode (acceptable for a sports/fitness app aesthetic, must be documented).
  - Use `Color(.systemBackground)` and semantic colors (`Color.primary`, `Color.secondary`)
    combined with a custom `Color` asset that has light and dark appearances.
- Do not mix strategies across views.

---

## JADX Reference Pitfalls

### JADX-P1: XML layout hierarchy reveals structure, not data semantics

**What goes wrong:** An Android `RecyclerView` adapter, `Fragment` arguments, and `ViewModel`
`LiveData` fields are not visible in layout XML. `<TextView android:id="@+id/recovery_score"/>`
shows where a number is displayed but not which endpoint provides it, what unit it is in, or
how it is computed. Building a SwiftUI view with placeholder data from the XML and then binding
it to the wrong field produces a structurally correct UI with semantically wrong data.

**Prevention:**
- Use JADX XML only for layout structure (card hierarchy, tab order, field placement). Use
  `FINDINGS_5.md` and the `openwhoop-algos` output schema as the authoritative data source.
  Never derive data semantics from XML label strings or Android resource IDs.
- Before implementing any card, document the data source explicitly: which field in
  `DailyMetric` or `CachedSleepSession` will bind to this slot. If no source can be
  identified, the card is not yet buildable — defer until backfill is fixed and real data flows.

### JADX-P2: Android metric labels may not match `openwhoop-algos` field definitions

**What goes wrong:** An Android layout `@string/hrv_label` with value `"HRV (ms)"` appears to
imply RMSSD in milliseconds. But the WHOOP Android app may compute SDNN and label it "HRV"; the
units or averaging window may differ from `openwhoop-algos`. Copying the label into the SwiftUI
card and binding it to `hrv_rmssd` without verifying creates a subtle misrepresentation.

**Prevention:**
- Cross-reference every metric label found in JADX with `openwhoop-algos` output field names
  and the WHOOP protocol documentation. When they disagree, use the protocol definition and
  the algorithm's documented output, not the UI label.

### JADX-P3: Reproducing colour values, spacing constants, or drawable resources is copyright infringement

**What goes wrong:** JADX decompiles `colors.xml`, `dimens.xml`, and drawable resources.
Copying exact hex colour values or dimension constants constitutes reproduction of copyrighted
material, even if the visual result looks different. `PROJECT.md` calls this out explicitly
under Out of Scope.

**Prevention:**
- Extract structural patterns only: "Recovery card has score prominently at top, three
  sub-metrics in a horizontal row below." Implement colours, typography, and spacing
  independently using Apple's Human Interface Guidelines and the existing `Design/` directory.
- Document in code comments which JADX screen inspired a given view's layout — never which
  values were copied.

### JADX-P4: Android tab order is a reference, not a contract — use a typed enum from the start

**What goes wrong:** The WHOOP Android app may order tabs as [Overview, Sleep, Strain, Coach].
The iOS app adds a Device tab not present in the Android app. If tabs are ordered as integers
and `@SceneStorage` persists those integers, any future reorder silently maps a user's
persisted selection to the wrong tab.

**Prevention:**
- Use a `String`-rawValue enum for tab identifiers (see UI-P1). The Device tab gets its own
  enum case that survives reorders. The JADX tab order is the starting reference, not a
  permanent constraint.

---

## Prevention Strategy

### High-priority gates — block merge if violated

| Area | Gate |
|------|------|
| HealthKit | Entitlement + plist keys present before any HK API call compiles |
| HealthKit | `authorizationStatus(for:)` checked and surfaced in UI before any write |
| HealthKit | Conversion layer unit-tested without a live `HKHealthStore` |
| Backfill | `connectHandshakeDone` never reset except in `didDisconnectPeripheral` |
| Backfill | Every new `.withResponse` write audited for `didWriteValueFor` re-entry path |
| Backfill | Every new biometric stream insert path verified as upsert, not plain INSERT |
| SwiftUI | `TabView(selection:)` binding added before any tab is added or reordered |
| SwiftUI | No new `@EnvironmentObject` injected lazily (must be in `AppRootCoordinator.init`) |
| JADX | Every SwiftUI card has a documented data source field before implementation begins |

### Testing strategy per area

**HealthKit:**
- Unit-test `HealthKitExporter` conversions (BPM → count/min, rr_ms → seconds, spo2_int → 0–1)
  using a protocol mock instead of a live `HKHealthStore`.
- Manual: deny HealthKit authorization at the iOS prompt → verify a banner appears, not a crash
  or silent failure. Repeat with "Don't Allow Read" only to verify write failure is also caught.

**Algorithm integration:**
- Simulate server downtime (invalid URL in Secrets.xcconfig) → verify locally-derived metrics
  still appear in TodayView. This is the offline-first regression test.
- Simulate server returning empty `[]` → verify no crash and local values remain visible with
  appropriate staleness indicator.

**Backfill:**
- After adding any new `.withResponse` write, run a full backfill session and verify via the
  `CMD_RESP: cmd=X` log on FD4B0003 that the frame count increases normally (not stuck at 1).
- On-device only: the type-47 frame counter (`BF: frame #N`) must reach a nonzero count within
  the first 60 seconds of a bonded session. If it remains at 0, the handshake was re-triggered.

**SwiftUI:**
- After adding the selection binding: navigate to Sleep tab → background the app → kill in
  switcher → relaunch → verify Sleep tab is restored (not TodayView).
- Fresh install test: verify no "No ObservableObject of type X found" crash with no prior
  `@SceneStorage` value.

**JADX:**
- Before any card implementation, review the card's data source field mapping against the
  actual `DailyMetric` / `CachedSleepSession` schema. Blocked cards (no data source yet) must
  be marked with a `// TODO(BF-01)` comment linking the dependency to the backfill fix.
