---
plan: "11-02"
title: "HealthKitExporter Actor — HR, HRV, Sleep Export + Highwater Cursors"
status: complete
phase: 11
wave: 2
completed: "2026-05-31"
---

# Summary: 11-02 HealthKitExporter Actor

## What Was Built

Created the `HealthKitExporter` actor that exports WHOOP biometric data to Apple Health: HR samples via highwater cursor (HK-01), HRV RMSSD per sleep session via `avgHrv` (HK-02), and sleep sessions with stage mapping via delete+reinsert (HK-04). Also added two new WhoopStore read methods for highwater-based export.

## Tasks Completed

| Task | Title | Status |
|------|-------|--------|
| 11-02-T1 | Add hrSamples(since:) and sleepSessions() to WhoopStore | ✓ Complete |
| 11-02-T2 | Create HealthKitExporter actor | ✓ Complete |

## Key Files Created/Modified

### key-files.modified
- `Packages/WhoopStore/Sources/WhoopStore/Reads.swift` — added `hrSamples(deviceId:since:limit:)` and `sleepSessions(deviceId:)` public methods

### key-files.created
- `ios/OpenWhoop/HealthKit/HealthKitExporter.swift` — full actor implementation with HR/HRV/sleep export, highwater cursors, stage mapping

## Deviations

None. Implementation followed the plan exactly.

## Self-Check

### Verification Results

1. `grep "func hrSamples(deviceId: String, since: Int, limit: Int)" Reads.swift` → ✓ match
2. `grep "func sleepSessions(deviceId: String)" Reads.swift` → ✓ match
3. `swift build` from Packages/WhoopStore/ → ✓ Build complete
4. `grep "^actor HealthKitExporter" HealthKitExporter.swift` → ✓ match
5. `grep "hrHighwaterKey\|hrvHighwaterKey" HealthKitExporter.swift` → ✓ both keys present
6. `grep "deleteObjects" HealthKitExporter.swift` → ✓ delete+reinsert sleep idempotence
7. `grep "asleepCore\|asleepDeep\|asleepREM\|\.awake" HealthKitExporter.swift` → ✓ all 4 stages
8. `grep -i "spo2\|oxygenSaturation" HealthKitExporter.swift` → ✓ zero matches (HK-03 absent)
9. `xcodebuild build -scheme OpenWhoop ...` → ✓ SUCCEEDED (via xcodebuildmcp)
10. `grep -r "import HealthKit" ios/ | grep -v HealthKitExporter` → ✓ zero other files

**Self-Check: PASSED**

## Notes

- `exportSleep()` uses `store.deleteObjects(of: HKCategoryType(.sleepAnalysis), predicate:)` before inserting — ensures idempotent re-export never creates overlapping segments
- Stage mapping: "light"/"core" → `.asleepCore`, "deep" → `.asleepDeep`, "rem" → `.asleepREM`, "awake" → `.awake` — unknown stages are skipped with a log message
- HRV export uses `avgHrv` from `CachedSleepSession` (one SDNN sample per sleep session), not raw RR interval computation
- `SleepSegment` is a private `Decodable` struct for parsing `stagesJSON: [{start, end, stage}]`
