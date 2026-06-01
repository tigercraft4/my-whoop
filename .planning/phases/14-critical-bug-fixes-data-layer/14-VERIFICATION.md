---
phase: 14
phase_name: critical-bug-fixes-data-layer
status: passed
verified: 2026-06-01
verifier: orchestrator (inline)
plans_verified: 2
requirements_verified:
  - BUGFIX-01
  - BUGFIX-02
  - BUGFIX-03
---

# Phase 14 Verification — Critical Bug Fixes (Data Layer)

**Goal:** Metrics already computed by `LocalMetricsComputer` are correctly displayed and the recovery baseline is free of corrupt HRV values.

## Verification Results

### BUGFIX-01 — SleepCard displays sleepNeededMin ✓

**Success Criterion:** SleepCard and SleepView display the `sleepNeededMin` value (ALG-12 output) instead of nothing.

**Evidence:**
- `SleepCard.swift` contains `private var sleepNeededLabel: String` reading `daily?.sleepNeededMin`
- `statColumn(label: "SLEEP NEEDED", value: sleepNeededLabel)` present in HStack stats row
- 3 calls to `statColumn()` confirmed: "HOURS OF SLEEP", "SLEEP PERFORMANCE", "SLEEP NEEDED"
- `formatMinutes()` helper correctly formats minutes as "7h 30m"
- When `sleepNeededMin` is nil, shows "—"
- **PASS**

### BUGFIX-02 — sleepPerformance replaces efficiency in SleepCard and RecoveryCard ✓

**Success Criterion:** SleepCard and RecoveryCard show the composite `sleepPerformance` score (0–100) rather than raw `efficiency` (0.0–1.0) in both locations.

**Evidence:**
- `SleepCard.sleepPerformanceLabel`: reads `daily?.sleepPerformance`, no reference to `daily?.efficiency` or `session?.efficiency` in display properties
- `RecoveryCard.sleepLabel`: reads `daily?.sleepPerformance.map { "\(Int($0.rounded()))%" }`, no reference to `daily?.efficiency`
- Format correct: `Int(score.rounded())%` (no ×100 — sleepPerformance is already 0–100)
- Shows "—" when nil in both cards
- **PASS**

### Dead code removal — SleepView.headlineSection ✓

**Evidence:**
- `grep -n "headlineSection" ios/OpenWhoop/Tabs/SleepView.swift` returns no results
- `scrollContent` unchanged — still references `SleepCard` correctly
- Stale TODO comment removed
- **PASS**

### BUGFIX-03 — Migration v10 behaviour test ✓

**Success Criterion:** After GRDB migration v10, no `avgHrv` values stored before commit e65fa31 (corrupt V128 RR offsets) remain in the recovery baseline — they are purged or flagged.

**Evidence:**
- `testMigrationV10PurgesInvalidRRAndClearsAvgHrv` added to `MigrationTests.swift`
- Tests: invalid rrMs (50, 65535) deleted; valid rrMs (200, 800, 2000) preserved; avgHrv=NULL
- All 6 MigrationTests pass (60 total WhoopStore tests, 0 failures)
- Database.swift not touched (D-09 honoured)
- **PASS**

### Build verification ✓

- `xcodebuild` (OpenWhoop.xcodeproj, iPhone 17 Pro, iOS 26.5): **SUCCEEDED**, 0 errors, 0 warnings
- `swift test --package-path Packages/WhoopStore`: **60 tests, 0 failures**

## Requirements Coverage

| REQ-ID | Status | Evidence |
|--------|--------|----------|
| BUGFIX-01 | ✓ Verified | SleepCard has "SLEEP NEEDED" column reading sleepNeededMin |
| BUGFIX-02 | ✓ Verified | Both cards read sleepPerformance, not efficiency |
| BUGFIX-03 | ✓ Verified | testMigrationV10PurgesInvalidRRAndClearsAvgHrv passes |

## Must-Haves Verified

From 14-01:
- [x] DailyMetric.sleepPerformance is Double? in range 0–100 — no ×100 conversion applied
- [x] DailyMetric.sleepNeededMin formatted with formatMinutes()
- [x] efficiency not in SleepCard or RecoveryCard display properties
- [x] headlineSection removed
- [x] SleepCard.statColumn() used for 3rd column

From 14-02:
- [x] Migration v10 not touched
- [x] rrMs 200 and 2000 are inclusive boundaries (NOT deleted)
- [x] rrMs 50 and 65535 deleted
- [x] avgHrv NULL for all dailyMetric after v10

## Conclusion

**status: passed**

All 3 requirements (BUGFIX-01, BUGFIX-02, BUGFIX-03) verified. Build clean. 60 tests pass. No regressions.
