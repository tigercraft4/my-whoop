---
phase: 12-ui-parity
plan: "03"
subsystem: ios-metrics
tags: [metrics, trends, sleep, ui-parity, tdd]
dependency_graph:
  requires: []
  provides: [MetricKind.sleepPerformance, MetricKindTests]
  affects: [TrendsView, TodayView, DayDetailView]
tech_stack:
  added: []
  patterns: [TDD RED/GREEN, MetricKind enum extension]
key_files:
  created:
    - ios/OpenWhoopTests/MetricKindTests.swift
  modified:
    - ios/OpenWhoop/Charts/MetricKind.swift
    - ios/OpenWhoop/Tabs/TodayView.swift
    - ios/OpenWhoop/Tabs/DayDetailView.swift
decisions:
  - sleepDuration kept in enum (not in dailyCases) so existing TodayView/DayDetail references compile
  - sleepPerformance uses sleepPurple color matching existing sleep visual language
  - ProfileUnitsTests pre-existing build failure deferred (out of scope, unrelated to this plan)
metrics:
  duration_seconds: 286
  completed_date: "2026-06-01"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 4
---

# Phase 12 Plan 03: Sleep Performance Metric + Label Parity Summary

**One-liner:** Sleep Performance (0-100%) added as primary Trends sleep metric sourced from DailyMetric.efficiency, with RHR/SKIN TEMP label fixes for WHOOP parity.

## What Was Built

- `MetricKind.sleepPerformance`: new enum case with title "Sleep Performance", unit "%", bar chart, 0-100 fixed y-domain, value mapped from `efficiency * 100` (D-09/D-10)
- `dailyCases` updated: `.sleepDuration` replaced by `.sleepPerformance` — TrendsView automatically shows Sleep Performance card via its `ForEach` loop (D-11)
- `MetricKind.rhr` title shortened from "Resting HR" to "RHR" (D-14)
- `TodayView` sleep `NavigationLink` now points to `.sleepPerformance` (D-09/D-11)
- `TodayView` rhrCard title updated to "RHR" (D-14)
- `DayDetailView` RHR label updated to "RHR" (D-14)
- `DayDetailView` skin temp card title changed from "Skin Temp Dev" to "SKIN TEMP" with unit "°C from baseline" (D-13)
- `MetricKindTests.swift` created with 14 unit tests covering all behavior

## TDD Gate Compliance

- RED: `test(12-03)` commit f3b4453 — MetricKindTests with compile errors (sleepPerformance missing)
- GREEN: `feat(12-03)` commit c143a76 — implementation added, app builds

## Commits

| Hash | Type | Description |
|------|------|-------------|
| f3b4453 | test | Failing MetricKindTests (RED phase) |
| c143a76 | feat | MetricKind.sleepPerformance implementation (GREEN phase) |
| 07fec17 | feat | TodayView + DayDetailView label fixes |

## Deviations from Plan

### Out-of-Scope Pre-existing Issue (Deferred)

**ProfileUnitsTests compile failure** — `ProfileUnitsTests.swift` references `ProfileUnits` which the test target cannot find, causing `xcodebuild test` to cancel before running any tests. This failure pre-dates this plan (first commit in repo history). The app BUILD SUCCEEDED, confirming MetricKind changes compile correctly. Test suite pass verification blocked by this pre-existing issue.

- **Logged to:** `.planning/phases/12-ui-parity/deferred-items.md`
- **Impact:** MetricKindTests cannot be run via xcodebuild until ProfileUnitsTests is fixed

## Known Stubs

None — all metric mappings wire to real `DailyMetric.efficiency` data.

## Threat Flags

None — UI label changes and enum extension only; no new network endpoints or auth paths.

## Self-Check: PASSED

- [x] `ios/OpenWhoop/Charts/MetricKind.swift` exists and contains `sleepPerformance`
- [x] `ios/OpenWhoopTests/MetricKindTests.swift` exists (96 lines)
- [x] `ios/OpenWhoop/Tabs/TodayView.swift` contains `kind: .sleepPerformance`
- [x] `ios/OpenWhoop/Tabs/DayDetailView.swift` contains `SKIN TEMP`, no `Skin Temp Dev`, no `Resting HR`
- [x] Commits f3b4453, c143a76, 07fec17 exist in git log
- [x] App builds: BUILD SUCCEEDED
