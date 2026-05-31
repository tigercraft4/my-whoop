# Technology Stack — v2.0 Milestone

**Project:** OpenWhoop WHOOP 5.0 — v2.0 new capabilities
**Researched:** 2026-05-31
**Scope:** Stack additions/changes for HealthKit export, openwhoop-algos iOS integration, JADX UI analysis, IMU/SpO₂ capture

---

## Summary

v2.0 adds four new capability surfaces onto a stable v1.0 core. The headline finding is that **the server algorithm stack is already fully implemented and deployed** — Recovery score, Sleep staging, and Strain are all computed by `compute_day()` and already flowing into the iOS local cache via `ServerSync.pullDerived()`. The iOS side needs to read and display this data, not re-compute it.

The other headline: **no new Swift packages are needed**. HealthKit is a system framework (iOS 8+), all algorithm data is already in the local GRDB store, and the JADX toolchain is already installed.

What v2.0 actually requires:

1. **HealthKit export** — one new Swift class (`HealthKitExporter`), two Info.plist keys, one entitlement. Pure Apple framework; no SPM dependency.
2. **Algorithm display in iOS** — wire `DailyMetric.recovery`, `DailyMetric.strain`, and `CachedSleepSession.stagesJSON` into the view layer. Data is already cached locally.
3. **JADX UI scope expansion** — the toolchain is already installed; the new target is `res/layout/` XML (view hierarchy) rather than protocol enum Java classes.
4. **IMU/SpO₂ capture** — `TOGGLE_IMU_MODE` and `captureRawAccel()` are already in the codebase; this is a BLE command + capture session, not a stack change.

---

## HealthKit Stack

### Framework choice

Use **pure HealthKit** (Apple system framework). No third-party SPM wrapper. The API surface needed is small — 4 write types, 1 authorization call, 1 save batch — and adding a wrapper package introduces a maintenance dependency for zero benefit.

**Confidence: HIGH** — pure `HKHealthStore` is the universal pattern in every production HealthKit integration. Third-party wrappers exist (HealthKitReporter, CareKit) but add read-side complexity this project does not need.

### Required HKObjectType subtypes

| Metric | HealthKit identifier | HKSampleType class | Apple Health display |
|--------|---------------------|--------------------|----------------------|
| Heart Rate | `.heartRate` | `HKQuantitySample` | "Heart Rate" in Vitals |
| HRV | `.heartRateVariabilitySDNN` | `HKQuantitySample` | "Heart Rate Variability" in Vitals |
| SpO₂ | `.oxygenSaturation` | `HKQuantitySample` | "Blood Oxygen" in Respiratory |
| Sleep | `.sleepAnalysis` | `HKCategorySample` | "Sleep" in Sleep tab |

**Heart Rate:** `HKQuantityType(.heartRate)`, unit `HKUnit.count().unitDivided(by: .minute())`. Export one sample per row from `WhoopStore.hrSamples()`. Use a `UserDefaults` highwater cursor (same pattern as `Uploader.drain()`) so re-exports are not duplicated — HealthKit deduplicates by `(startDate, endDate, value, source)` but the cursor avoids the round-trip.

**HRV:** `HKQuantityType(.heartRateVariabilitySDNN)`, unit `HKUnit.secondUnit(with: .milli)`. Apple Health has no `.heartRateVariabilityRMSSD` type. Export `DailyMetric.avgHrv` (which is the server's nightly RMSSD) using this type. This is the established pattern for third-party HRV apps. Label clearly as RMSSD in the app UI; the HealthKit type name is a mismatch Apple has not resolved. One sample per day, timestamped at `sleep_end`.

**SpO₂:** `HKQuantityType(.oxygenSaturation)`, unit `HKUnit.percent()`. Critical: the value passed to HealthKit must be in the range **0.0–1.0**, not 0–100. Divide `DailyMetric.spo2Pct` by 100 before creating the sample. Gate this behind `PROTO-11: SpO₂ VERIFIED` — do not export SpO₂ until the biometric offset is validated against a calibrated oximeter.

**Sleep:** `HKCategoryType(.sleepAnalysis)`. Use `HKCategorySample` with `HKCategoryValueSleepAnalysis`. The stage enum values available on iOS 16+ (the project's deployment target):

| Server stage string | HKCategoryValueSleepAnalysis | Int value |
|--------------------|------------------------------|-----------|
| `"wake"` | `.awake` | 2 |
| `"light"` | `.asleepCore` | 3 (N1/N2) |
| `"deep"` | `.asleepDeep` | 4 (N3) |
| `"rem"` | `.asleepREM` | 5 |
| (no stage data) | `.asleepUnspecified` | 1 |

Export one `HKCategorySample` per `StageSegment` from `CachedSleepSession.stagesJSON`. When `stagesJSON` is nil or empty, export a single `.asleepUnspecified` sample spanning the full session. `startDate` and `endDate` are `Date(timeIntervalSince1970:)` from `segment.start` and `segment.end`.

### HKHealthStore authorization flow

```swift
// HealthKitExporter.swift — app target only (NOT in WhoopProtocol or WhoopStore packages)
import HealthKit

@MainActor
final class HealthKitExporter {
    private let hkStore = HKHealthStore()

    static let shareTypes: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.oxygenSaturation),
        HKCategoryType(.sleepAnalysis),
    ]

    func requestAuthorizationIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await hkStore.requestAuthorization(toShare: Self.shareTypes, read: [])
    }

    func exportHR(_ samples: [HRSample]) async throws { ... }
    func exportHRV(_ metrics: [DailyMetric]) async throws { ... }
    func exportSleep(_ sessions: [CachedSleepSession]) async throws { ... }
}
```

**Authorization rules that matter:**

- Call `requestAuthorization` lazily on the first export attempt, not at app launch. Apple guidelines and App Review both require this — do not request HealthKit access until the user initiates an export action.
- `isHealthDataAvailable()` returns `false` on iPad and in the Simulator. Gate every HealthKit path behind this check; never call `HKHealthStore` APIs when it returns false.
- `requestAuthorization(toShare:read:)` with Swift concurrency (`async throws`) is available iOS 15.4+. The project deploys iOS 16, so this is safe.
- Request only share (write) types; `read: []`. This app writes to Health, does not read from it.
- The system authorization sheet appears once per type. Subsequent calls return immediately without UI.
- Do not use the completion-handler form — use the `async throws` form throughout.

### Info.plist additions (project.yml)

In `project.yml` under the `OpenWhoop` target's `info.properties`, add:

```yaml
NSHealthShareUsageDescription: "OpenWhoop exports heart rate, HRV, SpO₂, and sleep data from your WHOOP strap to Apple Health."
NSHealthUpdateUsageDescription: "OpenWhoop writes heart rate, HRV, SpO₂, and sleep data to Apple Health."
```

Both keys are required — App Review rejects apps with only one.

### Entitlement addition (project.yml)

Add to the `OpenWhoop` target:

```yaml
entitlements:
  path: OpenWhoop/OpenWhoop.entitlements
  properties:
    com.apple.developer.healthkit: true
    com.apple.developer.healthkit.background-delivery: false
```

Background delivery is not needed. This app pushes data after backfill; it does not observe HealthKit changes.

### Export trigger

Trigger HealthKit export from two places:
1. Inside `onBackfillComplete` in `BLEManager` — after each historical offload, enqueue an export of any new data since the last-exported highwater.
2. From a "Export to Apple Health" toggle/button in `SettingsView`.

Use a `UserDefaults` key per stream type (e.g. `hkExportHighwaterHR`, `hkExportHighwaterSleep`) to track the last exported timestamp. This matches the existing `Uploader.drain()` highwater pattern and avoids re-exporting on every backfill.

### Export batching

`HKHealthStore.save([HKSample], withCompletion:)` accepts arrays. Batch HR samples by day (up to ~1440 samples/day at 1 Hz). For sleep and HRV, batch size is small (one per night). Never save more than ~5000 samples in a single call to avoid memory pressure.

---

## Algorithm Server Stack

### What is already fully implemented (do not re-build)

The server's `analysis/` package is complete, deployed on gonzaga, and running. `compute_day(conn, device_id, day)` already produces:

| Output field | Implementation | Table |
|-------------|---------------|-------|
| `recovery` (0–100) | `recovery.py` — z-score+logistic composite (HRV 60%, RHR 20%, sleep efficiency 15%, resp 5%), Winsorized-EWMA personal baseline, cold-start gate | `daily_metrics.recovery` |
| `total_sleep_min`, `efficiency`, `deep_min`, `rem_min`, `light_min`, `disturbances` | `sleep.py` — Cole-Kripke accelerometer spine + neurokit2 cardiorespiratory classifier (wake/light/deep/rem per 30s epoch) | `daily_metrics.*` |
| `stages` (JSON array of `{start,end,stage}` segments) | `sleep.py` — same pipeline; segments stored as JSONB | `sleep_sessions.stages` |
| `strain` (0–21) | `strain.py` — Edwards TRIMP (5-zone HRR), logarithmic compression | `daily_metrics.strain` |
| `avg_hrv` (RMSSD, ms) | `hrv.py` — last-SWS tiered RMSSD, Kubios-style filters | `daily_metrics.avg_hrv` |
| `resting_hr` (bpm) | `recovery.py` — min of 5-min windowed means during sleep | `daily_metrics.resting_hr` |
| `spo2_pct` (%) | `units.spo2_percent_window()` — windowed ratio-of-ratios | `daily_metrics.spo2_pct` |
| `skin_temp_dev_c` (°C) | `units.skin_temp_deviation()` — slope × (tonight − baseline) | `daily_metrics.skin_temp_dev_c` |
| `resp_rate_bpm` | `units.resp_rate_from_signal()` — Welch peak | `daily_metrics.resp_rate_bpm` |
| exercise sessions | `exercise.py` — HR zone segmentation, calories (Keytel formula), per-bout intensity | `exercise_sessions` table |

`compute_day()` runs automatically after every `POST /v1/ingest-decoded` call (single-flight, debounced at 120s per device+day to avoid recomputing on every 30s upload heartbeat).

### What the iOS app already pulls

`ServerSync.pullDerived()` (called from `exitBackfilling()` after every backfill) already fetches:
- `GET /v1/daily?device=&from=&to=` → upserts into local `DailyMetric` cache (all fields including `recovery`, `strain`, `avg_hrv`, all sleep fields, `spo2_pct`, `skin_temp_dev_c`)
- `GET /v1/sleep?device=&date=` → upserts into local `CachedSleepSession` cache (including `stagesJSON`)

This data is already in the local GRDB store after every sync. The iOS view layer just needs to read it.

### What actually needs building for v2.0 algorithms — iOS side only

| Requirement | Data already cached locally | Build needed |
|-------------|----------------------------|--------------|
| ALG-01: Recovery score on Today view | `DailyMetric.recovery` (Double?) | Wire `TodayView` to show recovery value from `MetricsRepository.today?.recovery` |
| ALG-02: Sleep staging hypnogram | `CachedSleepSession.stagesJSON` (String?) | Parse the JSON array in `HypnogramView.swift` (file already exists) and render per-stage bars |
| ALG-03: Strain score display | `DailyMetric.strain` (Double?) | Add Strain card to `TodayView` or new `StrainView` tab |

`HypnogramView.swift` is already in the codebase at `ios/OpenWhoop/Tabs/HypnogramView.swift`. It needs to decode `stagesJSON` into the `{start, end, stage}` struct and draw the sleep architecture chart.

### One new server endpoint recommended: `/v1/today`

The current `pullDerived()` fetches `GET /v1/daily` with a date range. This works fine but requires the client to know today's date in UTC and construct the range. A dedicated endpoint:

```
GET /v1/today?device=<id>
```

Returns the single most-recent `daily_metrics` row for the device. This eliminates the UTC date calculation edge case (midnight boundary, timezone mismatch) and removes a latency round-trip when the app only needs today's recovery score. Implementation: 3 lines of SQL in `read.py` and one route in `main.py`.

```python
# read.py addition
def query_today(conn, device_id: str) -> dict | None:
    row = conn.execute(
        f"SELECT {', '.join(_DAILY_COLS)} FROM daily_metrics "
        "WHERE device_id = %s ORDER BY day DESC LIMIT 1",
        (device_id,),
    ).fetchone()
    return dict(zip(_DAILY_COLS, row)) if row else None
```

This is additive and does not change any existing endpoint contract.

### Backfill pipeline fix is a hard prerequisite

ALG-01, ALG-02, and ALG-03 all depend on `compute_day()` having input data. `compute_day()` reads from `hr_samples`, `rr_intervals`, `gravity_samples`, etc. If the backfill pipeline (BF-01) is not pulling historical data from the WHOOP 5.0, these tables are empty and every `compute_day()` call returns `{"status": "no_data"}`. Fix BF-01 first.

---

## JADX Workflow — v2.0 UI Analysis Scope

The existing `re/capture/jadx.md` runbook covers pulling the APK, navigating Java enums, and the legal recording rule (D-04). The toolchain (`jadx >= 1.5.1`, `adb >= 35.0.0`, `openjdk`) is already installed via `brew bundle`. Run `bash scripts/check-tools.sh` to confirm before starting.

For v2.0, the new goal is **UI structure analysis**: understanding how the WHOOP Android app organises its data presentation so the SwiftUI redesign can match the UX pattern without copying proprietary code.

### What to extract for UI-01 (tab structure and screen layout)

Navigate in JADX-GUI to the **Resources tree** (not the Java tree):

1. **`res/layout/` — Layout XML files** (unobfuscated resource files, not decompiled code). These describe the view hierarchy. Look for files named `activity_overview`, `fragment_recovery`, `fragment_sleep`, `fragment_strain`, `item_daily_summary`, etc. The naming pattern reveals how screens are structured.

   What to record:
   - Top-level container type per screen (`ScrollView`, `RecyclerView`, `ViewPager2`, `CoordinatorLayout`)
   - Card structure: how many nested `CardView` or `MaterialCardView` per screen, approximate hierarchy depth
   - Whether tab content is in Fragments (separate files) or Activities (single file with fragments)
   - `BottomNavigationView` or `TabLayout` item count and position (tells you tab bar structure)

2. **`res/values/strings.xml` — String resources** (also unobfuscated). Search for: `recovery`, `strain`, `sleep`, `hrv`, `resting`, `performance`. Record the exact label text used for each metric and any units shown (e.g., `"HRV"` vs `"Heart Rate Variability"`, `"ms"` vs no unit visible).

3. **`res/menu/` — Navigation menus**. Bottom navigation menus list tab labels and icon references in order. This gives the exact tab bar sequence.

4. **Java/Kotlin class names** (record names only, not bodies): search for `OverviewFragment`, `RecoveryFragment`, `SleepFragment`, `StrainFragment`. The presence and naming of these classes confirms the screen-per-tab structure.

### Legal boundary for UI analysis (D-04 extension)

Same locked rule as for enum RE. You MAY record:
- Layout XML element tag names (standard Android View class names — not proprietary)
- Resource file names
- String values from `strings.xml` (metric labels, units — factual UI text)
- Fragment/Activity class names

You MUST NOT record:
- Method bodies or business logic from decompiled Java/Kotlin
- Any `@BindingAdapter` or data binding expressions that expose API/data structure
- Drawable assets, icon files, or any copyrightable artwork
- String values that appear to be server API field names, endpoint paths, or internal identifiers

Record findings in `re/capture/samples/apk/notes-ui-draft.md` (gitignored). Transfer only structure notes to a committed doc under `docs/` or `FINDINGS_5.md`.

### No new tools required

Everything needed (`jadx-gui`, `adb`, Java) is already in the Brewfile. The only difference from the existing runbook is navigating to `Resources > res/layout/` instead of `Source code > eo0/`.

---

## Swift Package Additions

**None required for v2.0.**

| Capability | Why no package needed |
|-----------|----------------------|
| HealthKit export | Apple system framework; `import HealthKit` — no SPM dependency |
| Recovery/Strain/Sleep display | Data is already in `WhoopStore` GRDB tables via existing `ServerSync.pullDerived()` |
| Sleep hypnogram rendering | `HypnogramView.swift` already exists; needs JSON parsing (standard `Codable`) only |
| JADX UI analysis | Toolchain already installed via Brewfile |
| IMU/SpO₂ capture (`TOGGLE_IMU_MODE`) | `captureRawAccel()` already in `BLEManager.swift`; send `toggleIMUMode` command — no new code needed for the BLE layer |

**Minor additions to existing packages** (not new packages):

- `WhoopStore` may need one new GRDB migration to add a `hkExportHighwater` table (three columns: `streamKind TEXT, deviceId TEXT, highwaterTs INTEGER`) so export cursors survive app reinstall. This is a schema migration inside the existing `WhoopStore` package, not a new package.
- `project.yml` needs `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` in Info.plist and the `com.apple.developer.healthkit` entitlement.

---

## What NOT to Add

| Rejected addition | Why |
|-------------------|-----|
| Third-party HealthKit wrapper (HealthKitReporter, etc.) | No benefit over native API for write-only use case; adds maintenance burden |
| HealthKit background delivery entitlement | App pushes at backfill-complete; no need to observe HealthKit changes |
| Server-side HealthKit proxy or relay | Apple requires HealthKit writes originate from the device that collected the data |
| openwhoop-algos Python package (pip install) | Server already has a complete, tested implementation of the same methodology in `analysis/`; the pip package would be a parallel, unvalidated copy |
| ML framework on server (TensorFlow, PyTorch) | Sleep staging classifier already implemented as a transparent rule-based system (`sleep_features.classify_epochs`); adding a neural net requires PSG ground truth validation which is out of scope |
| sleepecg SPM or pip package | Server already does staging; client-side staging is unnecessary double-compute |
| Swift Charts extensions / third-party chart library | Swift Charts is a system framework (iOS 16+); `MetricChart.swift` and `TrendChartCard.swift` are already in the codebase |
| React Native, Flutter, or cross-platform layer | Out of scope — SwiftUI only per PROJECT.md constraints |
| WHOOP cloud API integration | Explicitly out of scope; local-first by design |

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| HealthKit object type identifiers | HIGH | Apple system framework docs (stable since iOS 8/iOS 16 for sleep stages); established pattern across all major HRV apps |
| SpO₂ unit is 0.0–1.0 | HIGH | `HKUnit.percent()` in HealthKit is always fractional — confirmed by Apple docs and consistent across all HealthKit samples |
| `.asleepCore/.asleepDeep/.asleepREM` available iOS 16 | HIGH | These values were added iOS 16.0; project min-deployment is iOS 16 |
| Server algorithm completeness | HIGH | Directly inspected `daily.py`, `recovery.py`, `sleep.py`, `sleep_features.py`, `strain.py`, `hrv.py` — all implemented and have test coverage in `server/ingest/tests/` |
| `ServerSync.pullDerived()` already pulls algorithm data | HIGH | Directly inspected `ServerSync.swift` — pulls `/v1/daily` (includes recovery, strain, sleep fields) and `/v1/sleep` (includes stages JSON) |
| No new Swift packages needed | HIGH | Verified against all v2.0 requirements; HealthKit is system framework, all other data is already local |
| JADX layout XML access | HIGH | Android `res/layout/` is a standard unobfuscated resource; JADX always exposes it in the Resources tree |
| HRV exported as `.heartRateVariabilitySDNN` despite being RMSSD | HIGH | This mismatch is well-known and universal — Apple has not added an RMSSD type; every production HRV app uses SDNN type for RMSSD values |
| `/v1/today` endpoint not yet implemented | HIGH | Verified by reading `main.py` exhaustively — no such route exists; it needs to be added |
