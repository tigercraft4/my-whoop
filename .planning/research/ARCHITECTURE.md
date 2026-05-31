# Architecture: iOS v2.0 Integration

**Milestone:** v2.0 — Backfill fix, HealthKit, algorithm results, WHOOP-style UI
**Researched:** 2026-05-31
**Confidence:** HIGH — based on direct reading of existing source files

---

## Summary

The existing architecture is already well-structured for v2.0 extensions. The core data pipeline is:

```
WHOOP 5.0 strap
  → BLEManager (CoreBluetooth, @MainActor)
  → Backfiller (historical type-47 frames, chunk state machine)
  → WhoopStore (GRDB actor, decoded tables: hr, rr, spo2, skin_temp, resp, gravity)
  → Uploader (POST /v1/ingest-decoded, opportunistic, 30s timer)
  → Server (FastAPI + TimescaleDB)
    → compute_day() → daily_metrics + sleep_sessions + exercise_sessions
  → ServerSync.pullDerived() → DailyMetric + CachedSleepSession back to phone
  → MetricsRepository (@MainActor, @Published today/lastNight)
  → RootTabView → TodayView / SleepView / TrendsView / WorkoutsView
```

All four v2.0 integration points slot into this pipeline without restructuring it. The key insight: **the algorithm results already flow through the pipeline via /v1/daily and ServerSync.pullDerived()**. The UI already consumes DailyMetric fields for recovery, strain, sleep. The gaps are: (1) HealthKit write layer does not exist yet, (2) the Backfiller has a known stuck state, and (3) the UI needs card-level enhancement for WHOOP-style presentation.

---

## HealthKit Integration Pattern

### Recommended pattern: write-on-ingest, singleton HKHealthStore

**Why not on-demand:** On-demand export requires the user to trigger it manually and creates a sync-state problem (which rows have been exported?). Write-on-ingest makes HealthKit a passive mirror that stays current automatically.

**Why not background:** Background HealthKit writes via `HKObserverQuery` or background tasks add complexity (entitlements, background modes, BGTaskScheduler) with no benefit here — we already have the data when the BLE backfill completes.

**Correct trigger point:**

```
BLEManager.onBackfillComplete
  → MetricsRepository.computeLocalMetrics()   (already wired in AppRootCoordinator)
  → [NEW] HealthKitExporter.exportNewSamples() (add after computeLocalMetrics returns)
```

`HealthKitExporter` holds a singleton `HKHealthStore` and a cursor per stream type (`hk_hw_hr`, `hk_hw_rr`, `hk_hw_sleep`) stored in UserDefaults. On each call it reads rows from WhoopStore above the cursor, writes them to HealthKit, then advances the cursor only on success.

**Authorization flow:**

- `HKHealthStore.requestAuthorization(toShare:read:)` must be called before the first write. This shows the system sheet once; subsequent calls to authorized types are no-ops.
- Call it once from the first view that needs it (TodayView.task{} or a dedicated onboarding step). NOT inside AppRootCoordinator.init() — the sheet can only appear when a view is on screen.
- Request only the types you write: `.heartRate`, `.heartRateVariabilitySDNN`, `.oxygenSaturation`, `.sleepAnalysis`. Do not request read permissions unless displaying Apple Health data in the app.

**HKHealthStore singleton:**

```swift
// HealthKitStore.swift
final class HealthKitStore {
    static let shared = HKHealthStore()
}
```

One `HKHealthStore` instance per app. Do NOT create one per view or per export call.

**Write types and HealthKit sample mapping:**

| WhoopStore data | HealthKit type | HK sample type |
|-----------------|---------------|----------------|
| HRSample (ts, bpm) | .heartRate | HKQuantitySample, unit: count/min |
| RRInterval (ts, rrMs) | .heartRateVariabilitySDNN | HKQuantitySample, unit: ms — NOTE: HealthKit only stores ONE SDNN/RMSSD value per sample, not individual intervals; compute RMSSD over an RR window before writing |
| SpO2Sample (red, ir) | .oxygenSaturation | HKQuantitySample, unit: % — DEFER until PROTO-11 VERIFIED; write only calibrated values |
| CachedSleepSession | .sleepAnalysis | HKCategorySample per stage segment; parse stagesJSON to generate per-stage samples (Deep/REM/Light/Awake) |

**RMSSD vs SDNN naming:** Despite the type name `.heartRateVariabilitySDNN`, Apple's Health app writes RMSSD values to this type. Use RMSSD from your RR windows. The server's `hrv.nightly_hrv()` already computes RMSSD per segment.

**Cursor strategy:** Advance only after `HKHealthStore.save(_:withCompletion:)` calls back with no error. Batch up to 1000 samples per save call. Never advance the cursor before the write succeeds.

**Where to wire it:** `AppRootCoordinator.wireBackfill()` already runs `computeLocalMetrics()` after each backfill. Add the HealthKit export call after that:

```swift
l.onBackfillComplete {
    Task {
        await m.computeLocalMetrics()
        await HealthKitExporter.shared.exportNewSamples()  // NEW
    }
}
```

Also hook it in `MetricsRepository.refresh()` after `runLocalCompute()` for the manual pull-to-refresh path.

**Entitlements required:** Add `com.apple.developer.healthkit` to the app entitlements file and `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` to Info.plist. Without NSHealthUpdateUsageDescription the app crashes on the first authorization request.

---

## Algorithm Data Flow

### Current state

The algorithm results already exist in the data flow. `compute_day()` on the server produces:
- `recovery` (0.0–1.0 float, requires multi-night baseline — null until calibrated)
- `strain` (0.0–21.0 float, TRIMP-based)
- `avg_hrv` (RMSSD ms)
- `resting_hr` (bpm)
- `total_sleep_min`, `efficiency`, `deep_min`, `rem_min`, `light_min`
- `spo2_pct`, `skin_temp_dev_c`, `resp_rate_bpm`
- `sleep_sessions` with `stages` JSON per night
- `exercise_sessions` with `zone_time_pct`, `calories_kcal`

`ServerSync.pullDerived()` already fetches all of this via `/v1/daily` and `/v1/sleep` and upserts into GRDB. `MetricsRepository` reads those tables and publishes `today: DailyMetric` and `lastNight: CachedSleepSession`. `TodayView` already reads `metrics.today?.recovery`, `.strain`, `.totalSleepMin`, `.avgHrv`, `.restingHr`.

**The server-to-app algorithm data flow is already complete.** The requirement is to confirm the data surfaces correctly after a working backfill, not to build a new pipeline.

### What is actually missing

1. **Recovery cold-start UX:** `recovery` is null until the server has enough nights for the Winsorized-EWMA baseline. The UI shows "—" which is correct, but there is no explanation for why. Add a `recoveryCalibrating` state that TodayView displays as "Calibrating (N nights needed)".

2. **No need for new REST endpoints.** The existing `/v1/daily` and `/v1/sleep` endpoints return all algorithm outputs. Do NOT add per-metric endpoints (`/v1/recovery`, `/v1/strain`) — they duplicate `/v1/daily`.

3. **Trigger timing:** The 120s recompute cooldown on the server means there may be up to 2 minutes of lag between data upload and metrics appearing. The app should not poll — the pull-to-refresh on TodayView.task{} handles this.

### Local vs server computation split

| Computation | Location | Rationale |
|-------------|----------|-----------|
| Sleep detection | Both (LocalMetricsComputer + server) | Server wins via ON CONFLICT DO UPDATE |
| Resting HR | Both | Server wins |
| HRV (RMSSD) | Both | Server's last-SWS tiered RMSSD is more accurate |
| Recovery score | Server only | Needs multi-night baseline, heavy computation |
| Strain | Server only | Needs 90-day HRmax history |
| Sleep stages (REM/Deep/Light) | Server only | Uses neurokit pipeline |
| Exercise sessions | Server only | Needs HRmax, calorie formula, user profile |

---

## UI Architecture Evolution

### Current structure

`RootTabView` has five tabs: Today / Sleep / Trends / Workouts / Device. All tabs are implemented. This is already close to WHOOP-style.

**WHOOP tab structure (from JADX reference goal):**
Overview (today summary) / Sleep / Strain / Coach. The main difference: WHOOP uses "Strain" not "Trends", and "Coach" for recommendations.

### Recommended evolution: minimal restructure, evolve in-place

Do NOT rebuild from scratch. The existing tab structure maps cleanly:

| Current tab | Target state |
|-------------|-------------|
| Today | Rename label to "Overview", enhance recovery ring with colour zones |
| Sleep | Add stage minutes bar (deep/REM/light), SpO2/skin-temp signals when non-nil |
| Trends | Rename to "Strain", surface daily strain score + HR zone chart |
| Workouts | Keep as-is |
| Device | Keep as-is (BLE diagnostics) |

### Component pattern

- Cards are `View` structs with init params, no `@EnvironmentObject` inside — data comes from the parent view.
- Async loading stays in `.task{}` modifiers in the tab-level views via `MetricsRepository`.
- `NavigationLink` wraps cards for drill-down (already done in TodayView for all cards).

**Recovery ring:** Already `RecoveryRing(percent:size:strokeWidth:)`. Add colour gradient: green (>67%), yellow (34–66%), red (<34%).

**Sleep card (UI-04):** `CachedSleepSession.stagesJSON` contains stage segments. Parse them in SleepView to render a stacked bar. `DailyMetric.deepMin`, `.remMin`, `.lightMin` are already populated by the server.

**Strain card (UI-05):** `DailyMetric.strain` (0–21) is already in MetricsRepository. Render a gauge arc. HR zone data from exercise_sessions (WorkoutsView) can be reused.

### @EnvironmentObject injection — keep current pattern

`MetricsRepository` and `LiveViewModel` injected at `AppRoot` as `@EnvironmentObject` is correct. Do not change. New v2.0 concern: `HealthKitExporter` should NOT be an `@EnvironmentObject` — it has no published state that views observe. Keep it as a singleton.

---

## Backfill Investigation

### What the Backfiller does

The `Backfiller.ingest(_:)` state machine expects:
1. `HISTORY_START` frame → opens chunk, `chunkOpen = true`
2. `HISTORICAL_DATA` frames (type-47) → accumulates into `chunk[]`
3. `HISTORY_END` frame → `finishChunk()`: insert decoded → enqueueRaw → setCursor("strap_trim") → ackTrim
4. `HISTORY_COMPLETE` frame → `isBackfilling = false`

High-freq-sync sends records before the START frame, so `begin()` sets `chunkOpen = true` immediately on session start.

### Identified failure modes (ordered by likelihood)

**1. FF key exchange race — MEDIUM risk**

`requestSync(.connect)` fires via `asyncAfter(1.5s)` after the connect handshake. The FF exchange (SEND_NEXT_FF rounds + SET_FF_VALUE) is async and takes ~4 rounds × ~300ms = ~1.2s on a clean link. On a slow/congested BLE link the exchange can take >1.5s, causing SEND_HISTORICAL_DATA to fire before SET_FF_VALUE completes. The strap then returns HISTORY_COMPLETE with 0 frames (silent fail).

**Fix:** Gate `requestSync(.connect)` on `ffExchangePending == false` instead of a fixed delay. `setFFValues()` already sets `ffExchangePending = false` at the end of the exchange — use that as the trigger to call `requestSync(.connect)`.

**2. Handshake storm — CONFIRMED root cause, already fixed**

`didWriteValueFor` re-fires on every `.withResponse` write (bond write, every SEND_HISTORICAL_DATA, every HISTORY_END ack). Without `connectHandshakeDone`, the app re-sent GET_HELLO + SET_CLOCK + START_FF_KEY_EXCHANGE during the offload, interrupting type-47 streaming. The `connectHandshakeDone` guard is in place. Verify it holds across reconnects — the guard resets to `false` on disconnect, which is correct.

**3. gen4DataNotifChar fragmentation — UNKNOWN risk**

Historical frames arrive on `61080005` (gen4DataNotifChar). The BLEManager routes gen4 notifications directly to `routeBackfillFrame(bytes)` without passing through the `Reassembler`. If gen4 frames exceed the negotiated BLE MTU (typically 247 bytes on iOS 16+ with DLE), they are fragmented into multiple notifications. Without reassembly, the Backfiller receives partial frames and the state machine silently produces corrupt chunks.

**Detection:** Log the byte length of the first 50 gen4 notifications. If any are exactly 244 bytes (common fragmentation MTU), reassembly is needed.

**Fix (if fragmentation confirmed):** Pass gen4 frames through the existing `Reassembler` before `routeBackfillFrame`.

**4. Idle timeout during legitimate inter-chunk pause — LOW-MEDIUM risk**

The idle watchdog is 60s, reset only by genuine offload frames (types 47/48/49/50). The strap waits for the HISTORY_END ack before sending the next chunk. The ack is a `.withResponse` write that may take several seconds on a congested link. If the ack round-trip exceeds 60s the watchdog fires and tears down the session.

**Fix:** Also reset the watchdog in `didWriteValueFor` for the `historicalDataResult` characteristic write (the ack). This keeps the timer alive during the ack round-trip.

**5. strap_trim cursor not set (cold start) — LOW risk**

If `setCursor("strap_trim")` has never been called (brand-new install), the Backfiller has no cursor to restore from and the strap resends all data from the beginning. This is correct behavior. But if the cursor is set to a value in the far past or future (e.g. due to a clock bug), the strap may serve 0 frames. Log the cursor value at session start.

**6. Stuck detector false positive during large first sync — LOW risk**

`StuckStrapDetector` compares `strapNewestTs` (from GET_DATA_RANGE) with the local frontier (max HR ts). On a large first sync, the frontier advances slowly — potentially triggering the "stuck" condition while the backfill is working normally. The 10-minute window and 5-minute `behindGapSeconds` need calibration against observed sync speeds.

**7. WHOOP 5.0 silent HISTORY_COMPLETE (caught-up case) — NOT a bug**

If the strap is already fully synced (local strap_trim == strap's newest ts), it sends HISTORY_COMPLETE immediately with 0 frames. The Backfiller handles this correctly. Log the distinction: "caught up (0 frames)" vs "stuck (0 frames after N seconds)".

---

## Build Order

### Phase 1: Fix Backfill (BF-01, BF-02) — FIRST, blocks everything else

**Rationale:** All iOS validation (IOS-03/04/05) requires real historical data. Without the backfill, MetricsRepository returns nil/empty for all metrics. The UI shows "—" not because of UI bugs but because there is no data.

**Concrete first actions:**
1. Fix the FF exchange race: add `guard !ffExchangePending` to `beginBackfill()`, and call `requestSync(.connect)` from inside `setFFValues()` once the exchange completes.
2. Log gen4 frame byte lengths to determine if reassembly is needed on the gen4 channel.
3. Add chunk-level logging: frames received per chunk, rows decoded per chunk, strap_trim value.
4. Add a debug read of the GRDB cursor table to confirm `strap_trim` is being set.

### Phase 2: Validate biometric streams with real data (PROTO-11/12/13/14, IOS-03/04/05)

After a working backfill, the data pipeline self-validates:
- WhoopStore tables populate.
- Uploader sends data to the server.
- `compute_day()` runs (throttled 120s).
- `pullDerived()` fetches metrics back.
- MetricsRepository publishes non-nil `today` and `lastNight`.

Validate each field manually against ground truth (oximeter for SpO2, thermometer for skin_temp, HR monitor for HR).

### Phase 3: HealthKit export (HK-01, HK-02, HK-04 — then HK-03 after PROTO-11)

Implement after Phase 1/2 so there is real data to write. Build the exporter with synthetic fixtures first (unit-testable), then validate with real data.

### Phase 4: UI redesign (UI-01 through UI-05)

Build last — when the data pipeline is confirmed and you can validate that card values are correct.

**UI-01 (JADX analysis)** is independent of the data pipeline and can start at any time. It is a pure research task.

### Dependency graph

```
BF-01 Backfill fixed
  ├── IOS-03/04/05  real data in views
  │     ├── UI-03/04/05  UI redesign validated with real data
  │     └── ALG-01/02/03  algorithms visible (pipeline already built, needs data)
  ├── PROTO-11/12/13/14  biometric verification (needs real backfill data)
  └── HK-01/02/04  HealthKit export (needs real store data)
        └── HK-03  SpO2 export (AFTER PROTO-11 VERIFIED)

UI-01  JADX APK analysis (independent, can start now)
```

### What can run in parallel after BF-01

- HealthKit implementation can be developed and unit-tested with synthetic data while PROTO-11 is pending.
- JADX APK analysis (UI-01) is independent of the data pipeline.
- Server-side algorithm validation can run as soon as the upload pipeline delivers data to the server.
