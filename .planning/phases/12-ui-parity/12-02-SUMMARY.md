---
phase: 12-ui-parity
plan: "02"
subsystem: ios-strain-training-state
tags: [swift, swiftui, strain, training-state, lookup-table, tdd]
dependency_graph:
  requires: []
  provides: [TrainingState.trainingState, recovery_to_strain bundle resource, StrainCard badge]
  affects: [ios/OpenWhoop/Design/Components/StrainCard.swift]
tech_stack:
  added: []
  patterns: [bundle resource loading, static let lookup table, TDD red-green]
key_files:
  created:
    - ios/OpenWhoop/Resources/recovery_to_strain.json
    - ios/OpenWhoop/BLE/TrainingState.swift
    - ios/OpenWhoopTests/TrainingStateTests.swift
    - ios/OpenWhoop/Settings/ProfileUnits.swift
  modified:
    - ios/OpenWhoop/Design/Components/StrainCard.swift
decisions:
  - "StrainView embeds StrainCard only; no independent zone label — no change needed to StrainView.swift"
  - "ProfileUnits.swift created as Rule-3 fix (blocked compilation of entire test target)"
  - "trainingStateBadgeColor computed from lookup result; ring colour stays strainAccent (D-08)"
metrics:
  duration: "425s (~7 min)"
  completed: "2026-06-01"
  tasks_completed: 2
  files_created: 4
  files_modified: 1
---

# Phase 12 Plan 02: Training State Badge on StrainCard Summary

**One-liner:** WHOOP Training State badge (RESTORATIVE/OPTIMAL/OVERREACHING) on the Strain card, driven by bundled recovery_to_strain.json lookup with full TDD coverage.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Bundle lookup table + TrainingState.swift | 8a503e1 | recovery_to_strain.json, TrainingState.swift, TrainingStateTests.swift, ProfileUnits.swift |
| 2 | Render Training State badge in StrainCard | aee5de6 | StrainCard.swift |

## Verification

- `recovery_to_strain.json` present in `ios/OpenWhoop/Resources/` and contains `lower_rec_strain` — PASSED
- `TrainingStateTests` (11 tests): all passed — `xcodebuild test` output: "Executed 11 tests, with 0 failures"
- `xcodebuild BUILD SUCCEEDED` after badge wiring — PASSED
- `StrainCard.swift` references `trainingState(` — PASSED

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] MetricKind.swift switch exhaustiveness**
- **Found during:** Task 1 — test build
- **Issue:** `MetricKind.formatShort()` and `value(from:)` were missing the `.sleepPerformance` case (left by another plan); `switch must be exhaustive` blocked compilation
- **Fix:** The file was already fixed by plan 12-03 running in parallel when re-read; no further action needed
- **Files modified:** none (pre-fixed)
- **Commit:** n/a

**2. [Rule 3 - Blocking] ProfileUnits missing from app target**
- **Found during:** Task 1 — test build
- **Issue:** `OpenWhoopTests/ProfileUnitsTests.swift` referenced `ProfileUnits` which did not exist in the app, causing 14 compile errors and blocking the entire test target
- **Fix:** Created `ios/OpenWhoop/Settings/ProfileUnits.swift` with imperial ↔ metric conversion helpers matching what the tests expected
- **Files modified:** `ios/OpenWhoop/Settings/ProfileUnits.swift` (new)
- **Commit:** 8a503e1

**3. [Rule 3 - Blocking] Xcode build database lock**
- **Found during:** Task 1 — first test run
- **Issue:** Build DB locked by concurrent process, preventing test execution
- **Fix:** Removed locked `.../XCBuildData/build.db`; retried — tests passed
- **Commit:** n/a

### StrainView — no change needed
`StrainView.swift` embeds `StrainCard` directly and has no independent zone label of its own. Badge appears automatically via the card. This case is recorded per plan instructions.

## Known Stubs

None — the badge is fully wired to the lookup table and live `DailyMetric.recovery`.

## Threat Surface Scan

No new network endpoints or auth paths introduced. `recovery_to_strain.json` is a static, version-controlled asset loaded read-only at runtime via `Bundle.main`. The threat register entry T-12-03 (loader returns nil on decode failure → badge omitted gracefully) is correctly implemented in `TrainingState.trainingState()`.

## Self-Check: PASSED

All created files found on disk. Both commits verified in git log.
