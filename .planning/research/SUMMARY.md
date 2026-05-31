# Research Summary — WHOOP 5.0 iOS v2.0

**Project:** OpenWhoop WHOOP 5.0 — v2.0 milestone
**Domain:** BLE wearable + HealthKit + algorithm integration + SwiftUI redesign
**Researched:** 2026-05-31
**Confidence:** HIGH

---

## Summary

v2.0 completes a product that is structurally already built but data-starved. The server algorithm
stack (Recovery, Sleep staging, Strain) is fully implemented and deployed on gonzaga. The iOS view
layer already has the correct tab structure, card hierarchy, and even a `HypnogramView.swift`.
`ServerSync.pullDerived()` already fetches algorithm results from the server and upserts them into
the local GRDB store. The reason every metric shows "—" is not a UI bug or a missing feature — it
is a single blocked pipe: the WHOOP 5.0 backfill pipeline is not pulling historical data.

Fix the backfill and the entire stack lights up. The confirmed root cause is a race condition in
the FF key exchange: `requestSync(.connect)` fires on a fixed 1.5 s delay, but the
SEND_NEXT_FF/SET_FF_VALUE exchange can take >1.5 s on a congested BLE link, causing
SEND_HISTORICAL_DATA to fire before the exchange completes. The strap silently returns
HISTORY_COMPLETE with 0 frames. The secondary guard (`connectHandshakeDone`) correctly prevents
handshake storms during offload and must never be reset except on disconnect.

With the pipeline fixed, v2.0 execution follows four independent workstreams that can overlap
after Phase 6: iOS stream validation with real data, JADX APK UI analysis, HealthKit export
implementation, and SwiftUI card enhancements. No new Swift packages are needed — HealthKit is a
system framework, all algorithm data is already in the local GRDB store, the JADX toolchain is
already installed via Brewfile, and `HypnogramView.swift` already exists.

---

## Stack Additions

No new Swift packages. No new server frameworks. The following additions are needed and nothing more.

**HealthKit (Apple system framework — no SPM dependency):**

| Stream | HKQuantityType identifier | Unit | Conversion required |
|--------|--------------------------|------|---------------------|
| Heart Rate | `HKQuantityType(.heartRate)` | `HKUnit.count().unitDivided(by: .minute())` | `Double(bpm)` — no scale change |
| HRV (RMSSD) | `HKQuantityType(.heartRateVariabilitySDNN)` | `HKUnit.secondUnit(with: .milli)` | Export RMSSD using SDNN type — known Apple mismatch |
| SpO2 | `HKQuantityType(.oxygenSaturation)` | `HKUnit.percent()` | `Double(spo2_pct) / 100.0` — CRITICAL: must be 0.0-1.0, not 0-100 |
| Sleep | `HKCategoryType(.sleepAnalysis)` | `HKCategoryValueSleepAnalysis` | `wake->.awake`, `light->.asleepCore`, `deep->.asleepDeep`, `rem->.asleepREM` |

**project.yml additions:**
- `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` in `info.properties`
- `com.apple.developer.healthkit: true` entitlement (background delivery: false)

**One new server endpoint — `GET /v1/today?device=<id>`:**
Returns the single most-recent `daily_metrics` row. Eliminates the UTC midnight boundary edge
case in `pullDerived()`. Implementation is 3 lines of SQL in `read.py` + one route in `main.py`.
All other endpoints remain unchanged.

**JADX scope expansion (no new tools):**
Navigate to `Resources > res/layout/` in JADX-GUI (already installed via Brewfile) instead of
the Java tree. Record layout XML structure only — tab order, card hierarchy, field placement.
Write findings to `re/capture/samples/apk/notes-ui-draft.md` (gitignored); transfer only
structure notes to a committed doc.

**WhoopStore schema addition:**
One new GRDB migration table: `hk_export_highwater (streamKind TEXT, deviceId TEXT, highwaterTs INTEGER)`
to persist export cursors across app reinstall. Not a new package — a migration inside the
existing `WhoopStore` package.

---

## Critical Path

```
BF-01: Fix FF key exchange race condition
  Gate requestSync(.connect) on ffExchangePending == false
  Call requestSync(.connect) from inside setFFValues() once exchange completes
  Verify connectHandshakeDone guard holds on reconnect
  |
  v
BF-02: 14+ days backfill with safe-trim invariant confirmed
  |
  v
IOS-03/04/05/06/08: Real data flows through pipeline
  WhoopStore populates -> Uploader uploads -> compute_day() runs -> pullDerived() fetches
  MetricsRepository publishes non-nil today/lastNight
  All iOS views validate with real data
  |
  +-- HK-01/02/04: HealthKit export (HR + HRV + sleep) -- needs real store data
  |     |
  |     +-- HK-03: SpO2 export -- gated on PROTO-11 VERIFIED
  |
  +-- UI-03/04/05: Recovery/Sleep/Strain card enhancements -- validate with real data
  |
  +-- ALG-01/02/03: Algorithm display confirmed -- pipeline already built, needs data
        PROTO-11/12/14: Biometric verification -- need real backfill data

UI-01: JADX APK analysis -- INDEPENDENT, can start in parallel with Phase 6
```

**Blocking dependency:** Every v2.0 feature except JADX analysis requires BF-01 to complete
first. `compute_day()` returns `{"status": "no_data"}` when `hr_samples`, `rr_intervals`, and
`gravity_samples` are empty — which is the current state.

---

## Feature Table

| Feature | Status | Blocker |
|---------|--------|---------|
| BF-01: Backfill pipeline fix | Hard dependency | FF key exchange race + connectHandshakeDone guard |
| BF-02: 14-day safe-trim backfill | Hard dependency | Depends on BF-01 |
| IOS-03: Today view with real data | Hard dependency | BF-01 |
| IOS-04: Sleep view with real data | Hard dependency | BF-01 |
| IOS-05: Trends with real charts | Hard dependency | BF-01 |
| IOS-08: Background reconnect validated | Hard dependency | BF-01 (needs real session) |
| ALG-01: Recovery score displayed | Mostly wiring | BF-01 — data already cached in DailyMetric.recovery |
| ALG-02: Sleep hypnogram | Mostly wiring | BF-01 — HypnogramView.swift exists; parse stagesJSON |
| ALG-03: Strain score displayed | Mostly wiring | BF-01 — DailyMetric.strain already cached |
| UI-01: JADX APK analysis | New work (research task) | None — fully independent |
| UI-02: WHOOP-style tab bar | New work | UI-01 (inform design), BF-01 (validate with data) |
| UI-03: Recovery card enhancements | UI evolution | BF-01 for real data validation |
| UI-04: Sleep card + stage minutes | UI evolution | BF-01 + stagesJSON |
| UI-05: Strain card + HR zones | UI evolution | BF-01 |
| HK-01: HealthKit HR export | New work | BF-01 — needs real HR in WhoopStore |
| HK-02: HealthKit HRV export | New work | BF-01 |
| HK-03: HealthKit SpO2 export | New work (gated) | BF-01 + PROTO-11 VERIFIED |
| HK-04: HealthKit sleep export | New work | BF-01 + stagesJSON |
| PROTO-11: SpO2 VERIFIED | Biometric validation | BF-01 (needs captured data) |
| PROTO-12: Skin temp VERIFIED | Biometric validation | BF-01 |
| PROTO-14: IMU/gravity VERIFIED | Biometric validation | BF-01 |

---

## Architecture Decisions

The following decisions are already made by the v1.0 codebase and constrain v2.0 implementation.

**Algorithm pipeline is server-side only.** `compute_day()` on the server produces all algorithm
outputs. The iOS app has a `LocalMetricsComputer` for offline fallback (RHR, RMSSD, sleep
detection) but recovery score, sleep staging, and strain are server-only — they require
multi-night baselines, historical HR max, and the neurokit2 pipeline. Do not re-implement these
on device.

**`ServerSync.pullDerived()` already fetches all algorithm results.** It calls `/v1/daily` (all
`DailyMetric` fields including `recovery`, `strain`, `avg_hrv`, `spo2_pct`, `skin_temp_dev_c`)
and `/v1/sleep` (including `stagesJSON`). No new iOS-to-server data-fetch path is needed.

**`MetricsRepository` publishes `lastRefreshedAt: Date?`.** The field exists but is not plumbed
to any view. Wire it as a subtitle on the Recovery card and use it for the staleness threshold
(>4h triggers background refresh).

**`HypnogramView.swift` already exists** at `ios/OpenWhoop/Tabs/HypnogramView.swift`. It needs
to decode `stagesJSON` using standard `Codable` and render per-stage colour bars. No new view
file required.

**`RootTabView` has no selection binding.** Adding `@SceneStorage("selectedTab")` is a
prerequisite for any tab restructure. Do this as the first UI change — before adding or
reordering any tabs — to prevent index-to-tab mapping from silently breaking.

**`HealthKitExporter` must be a singleton, not an `@EnvironmentObject`.** It has no published
state views observe. Wire it in `AppRootCoordinator.init()` and call it from the
`onBackfillComplete` closure after `computeLocalMetrics()` returns.

**`connectHandshakeDone` is an invariant, not a flag.** It must only be reset in
`didDisconnectPeripheral`. Any new `.withResponse` write added anywhere in the codebase requires
an explicit code review checking whether `didWriteValueFor` re-entry is correctly short-circuited
by the guard at line 804 of BLEManager.swift.

**Sleep stage enum values require iOS 16+.** `.asleepCore`, `.asleepDeep`, `.asleepREM`, `.awake`
in `HKCategoryValueSleepAnalysis` were added in iOS 16. The project targets iOS 16+ — use these
enum cases directly.

---

## Top Pitfalls

**1. BF-P1: connectHandshakeDone guard — any new `.withResponse` command breaks backfill.**
`didWriteValueFor` fires on every `.withResponse` write. The guard at BLEManager.swift line 804
prevents handshake re-entry during offload. Any new command bypassing this guard will storm the
strap and stall the offload silently. Prevention: never reset `connectHandshakeDone` except in
`didDisconnectPeripheral`. Code-review every new `.withResponse` addition for this re-entry path
before merging.

**2. HK-P1: HealthKit capability and entitlements must be added before importing HealthKit.**
Without `com.apple.developer.healthkit` in the entitlements file and both
`NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` in Info.plist, the binary
crashes before `requestAuthorization` is ever called. Neither key exists yet. Add both in
`project.yml` and enable the Xcode target capability as the very first step of HealthKit work.

**3. HK-P2: Unit conversions are not optional — wrong units write silent bad data to Apple Health.**
HealthKit requires: Heart Rate in `count/min` (not raw Int bpm), HRV in `ms` (already correct),
SpO2 in `0.0-1.0` (not 0-100 — divide `spo2_pct` by 100.0). Create a dedicated
`HealthKitExporter` class that performs all conversions at the boundary. Unit-test all conversions
without a live `HKHealthStore`.

**4. ALG-P1: Staleness indicator needed on `MetricsRepository.lastRefreshedAt`.**
`today` retains yesterday's Recovery score if the server is unreachable. The current UI shows no
"last updated" label. Wire `lastRefreshedAt` to a subtitle on the Recovery card ("Actualizado ha Xh").
Define a 4-hour staleness threshold that auto-triggers `refresh()` in the background from `.task`.
Do not use `today?.day` as a freshness proxy.

**5. UI-P1: `RootTabView` needs a selection binding before adding new tabs.**
The current `TabView` has no `selection` binding and no `@SceneStorage`. Adding a tab changes
the default selected index and silently maps persisted integers to the wrong tab. Add
`@SceneStorage("selectedTab") private var selectedTab: Tab = .today` and bind it as the first
step of the tab restructure. Define tabs as a `String` rawValue enum, not `Int`.

---

## Roadmap Implications

Recommended 6-phase structure for v2.0 (continuing from Phase 5 which concluded v1.0 work):

### Phase 6: Backfill Fix (BF-01, BF-02)
**Rationale:** Hard prerequisite for every other feature. All iOS views show "—", all algorithm
results are empty, and HealthKit has nothing to export until historical data flows through the
pipeline.
**Delivers:** End-to-end historical data pull — WhoopStore populated, Uploader uploading,
`compute_day()` running, `pullDerived()` returning real metrics.
**Key tasks:** Gate `requestSync(.connect)` on `ffExchangePending == false`; call it from inside
`setFFValues()` at exchange completion; log gen4 frame byte lengths for fragmentation check;
add chunk-level logging.
**Avoids:** BF-P1 (connectHandshakeDone invariant), BF-P3 (watchdog timeout during debugging).
**Research flag:** None needed — root cause confirmed, fix is mechanical.

### Phase 7: iOS Validation with Real Data (IOS-03/04/05/06/08, PROTO-11/12/14)
**Rationale:** After Phase 6, the full pipeline self-validates. All view layer integration points
must be exercised with real WHOOP data before UI redesign or HealthKit export — otherwise the
redesign has no truth to validate against.
**Delivers:** All iOS views showing real biometric data; SpO2, skin temp, IMU streams VERIFIED or
explicitly marked HYPOTHESIS; Today/Sleep/Trends/Workouts all confirmed end-to-end.
**Avoids:** ALG-P1 (staleness indicator), ALG-P3 (server latency / empty first-render).
**Research flag:** None needed — validation only, data flows from Phase 6.

### Phase 8: JADX APK Analysis + UI Design Document (UI-01)
**Rationale:** Independent of the data pipeline — can start in parallel with Phase 6. Must
complete before Phase 9 (SwiftUI redesign) to inform card hierarchy and tab structure.
**Delivers:** Committed `docs/` document describing WHOOP app screen structure: tab order, card
hierarchy per screen, field placement, metric labels from `res/values/strings.xml`.
**Avoids:** JADX-P1 (structure vs data semantics), JADX-P3 (copyright on colours/assets).
**Research flag:** None needed — JADX toolchain installed, runbook exists in `re/capture/jadx.md`.

### Phase 9: SwiftUI Redesign WHOOP-Style (UI-02/03/04/05)
**Rationale:** Needs Phase 7 (real data to validate cards) and Phase 8 (design reference).
Evolve in-place — do not rebuild from scratch.
**Delivers:** `RootTabView` with selection binding; Recovery ring with colour bands; Sleep card
with stage minutes and hypnogram rendering `stagesJSON`; Strain card with gauge arc; tab labels
updated.
**Avoids:** UI-P1 (selection binding first), UI-P2 (double NavigationStack), UI-P5
(hardcoded dark colours).
**Research flag:** None needed — design decisions informed by Phase 8.

### Phase 10: Algorithms Display + GET /v1/today Endpoint (ALG-01/02/03)
**Rationale:** All algorithm data is already in the local GRDB store after Phase 7. This phase
wires it into the view layer and adds the recommended `GET /v1/today` server endpoint.
**Delivers:** Recovery score with calibration state; sleep hypnogram parsing `stagesJSON` in
`HypnogramView`; Strain card; `GET /v1/today` endpoint; `lastRefreshedAt` staleness label.
**Avoids:** ALG-P1 (staleness indicator), ALG-P2 (mixed-source display), ALG-P4 (version
discontinuity in trend charts).
**Research flag:** None needed — server implementation is 3 lines of SQL.

### Phase 11: HealthKit Export (HK-01/02/04, HK-03 gated on PROTO-11)
**Rationale:** Build last — after real data is confirmed in the store (Phase 7) and the view
layer is stable (Phases 9/10). Implement with synthetic fixtures first (unit-testable without
a physical device), then validate with real data.
**Delivers:** `HealthKitExporter` singleton with cursor-per-stream; HR, HRV, and sleep session
export triggered from `onBackfillComplete`; manual export toggle in `SettingsView`; entitlement
and plist keys; authorization status check with user-facing banner.
**SpO2 export (HK-03):** Gated behind PROTO-11 VERIFIED. Do not export SpO2 until the
biometric offset is validated against a calibrated oximeter.
**Avoids:** HK-P1 (entitlement before code), HK-P2 (unit conversions), HK-P4 (duplicate
samples), HK-P5 (overlapping sleep sessions).
**Research flag:** None needed — HealthKit API is stable Apple framework, all type identifiers
confirmed HIGH confidence.

### Phase Ordering Rationale

- BF-01 blocks IOS-0x, ALG-0x, PROTO-1x, and HK-0x — it comes first unconditionally.
- UI-01 (JADX) is independent and starts in parallel with Phase 6 to avoid a sequential
  bottleneck before Phase 9.
- HealthKit goes last because it needs real data in the store AND stable view architecture.
  Unit-test implementation (synthetic fixtures) can start during Phase 9.
- ALG display (Phase 10) is separated from UI redesign (Phase 9) because the data wiring is
  mechanical while the UI work is design-intensive. They can overlap if bandwidth allows.

### Research Flags

No phase in this roadmap requires deeper research during planning. All technology decisions are
confirmed by direct codebase inspection at HIGH confidence. The only uncertainty is biometric
stream validation (PROTO-11/12/14) which is hardware-dependent and requires a working backfill.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All additions verified against existing codebase; no new packages required |
| Features | HIGH | Feature status determined by direct reading of Swift + Python source files |
| Architecture | HIGH | Data flow verified end-to-end by reading ServerSync.swift, MetricsRepository.swift, BLEManager.swift |
| Pitfalls | HIGH (BLE/backfill), MEDIUM (HealthKit) | BLE pitfalls grounded in code + v1.0 lessons; HealthKit from Apple docs |

**Overall confidence:** HIGH

### Gaps to Address

- **PROTO-11/12/14 validation:** SpO2, skin temp, and IMU stream correctness cannot be confirmed
  without a working backfill and a calibrated reference device. Gate HealthKit SpO2 export and
  display behind explicit PROTO-11 VERIFIED status.
- **gen4 frame fragmentation:** ARCHITECTURE.md rates gen4DataNotifChar fragmentation as UNKNOWN
  risk. Log byte lengths of first 50 gen4 notifications during Phase 6 to confirm whether the
  existing `Reassembler` needs to be wired to the gen4 channel.
- **Recovery cold-start UX:** Server returns `null` for `recovery` until 4 nights of baseline
  data exist. The "Calibrating" state needs a dedicated UI path — not yet designed.
- **HRV SDNN/RMSSD labelling:** HealthKit only exposes `.heartRateVariabilitySDNN` but the server
  computes RMSSD. Label clearly in the UI ("HRV (RMSSD)") to avoid misleading users who
  cross-reference with Apple Health's label.

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)

- `ios/OpenWhoop/App/AppRootCoordinator.swift` — onBackfillComplete wiring
- `ios/OpenWhoop/BLE/BLEManager.swift` — connectHandshakeDone guard (line 804), FF exchange
- `ios/OpenWhoop/BLE/Backfiller.swift` — chunk state machine, failure modes
- `ios/OpenWhoop/Metrics/MetricsRepository.swift` — lastRefreshedAt, pullDerived trigger
- `ios/OpenWhoop/Metrics/ServerSync.swift` — /v1/daily + /v1/sleep fetch confirmed
- `ios/OpenWhoop/Tabs/HypnogramView.swift` — existing file confirmed
- `ios/OpenWhoop/Tabs/TodayView.swift` — recovery/strain/hrv card wiring confirmed
- `server/ingest/app/analysis/recovery.py` — algorithm implementation confirmed
- `server/ingest/app/analysis/sleep.py` + `sleep_features.py` — staging pipeline confirmed
- `server/ingest/app/analysis/strain.py` — TRIMP implementation confirmed
- `server/ingest/app/main.py` — no /v1/today route confirmed (missing, needs adding)
- `server/ingest/tests/test_recovery.py`, `test_sleep.py`, `test_strain.py` — test coverage confirmed
- `.planning/PROJECT.md` — v2.0 requirements and constraints

### Secondary (MEDIUM confidence)

- Apple HealthKit system framework documentation — HKQuantityType identifiers, unit requirements
- `FINDINGS_5.md` — BLE protocol reference (v1.0 canonical)

---
*Research completed: 2026-05-31*
*Ready for roadmap: yes*
