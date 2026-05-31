---
plan: "10-02"
phase: 10
status: complete
started: "2026-05-31"
completed: "2026-05-31"
key-files:
  created: []
  modified:
    - ios/OpenWhoop/Upload/ServerSync.swift
    - ios/OpenWhoop/Metrics/MetricsRepository.swift
requirements-addressed:
  - ALG-01
  - ALG-02
  - ALG-03
---

# Summary — 10-02: iOS — ServerSync pulls /v1/today; server wins over LocalMetricsComputer

## What Was Built

Added `getTodayMetric()` to `ServerSync.swift` that fetches `/v1/today?device=<id>` and parses a single `DailyMetric`. Integrated the call into `pullDerivedWindow()` so the most-recent daily row is always upserted after a sync — even if it falls outside the 60-day derived window. Verified server-wins precedence is already correctly implemented and documented in `MetricsRepository.swift`.

## Tasks Completed

| Task | Status | Notes |
|------|--------|-------|
| T1 — Add getTodayMetric() to ServerSync.swift | ✓ Complete | Private method, same field mapping as getDaily, recovery / 100.0 |
| T2 — Call getTodayMetric() in pullDerivedWindow() | ✓ Complete | After window pull, guarded if let |
| T3 — Verify server-wins precedence in MetricsRepository | ✓ Complete | Already documented; body unchanged (D-08, D-10) |
| T4 — Build iOS target | ✓ Complete | BUILD SUCCEEDED — no Swift errors |

## Key Decisions

- `getTodayMetric()` is `private` — internal to `ServerSync`; mirrors `getDaily` pattern
- JSON null handled: `if json is NSNull { return nil }` — server returns null when no rows
- Recovery normalized `/ 100.0` — consistent with `getDaily` (server sends 0–100 score)
- `MetricsRepository.refresh()` comment already stated "server values take priority via ON CONFLICT DO UPDATE" — no body change required (D-08, D-10 confirmed)
- `LocalMetricsComputer` is still step 1 in `refresh()` — offline-first preserved (D-10)

## Verification Results

- `grep "func getTodayMetric" ios/OpenWhoop/Upload/ServerSync.swift` → line 386 ✓
- `grep "getTodayMetric" ios/OpenWhoop/Upload/ServerSync.swift` → definition (386) + call (338) ✓
- `grep "LocalMetricsComputer" ios/OpenWhoop/Metrics/MetricsRepository.swift` → still present ✓
- Build: `** BUILD SUCCEEDED **` via XcodeBuildMCP build_sim ✓
- No new Swift compiler errors in `ServerSync.swift` or `MetricsRepository.swift` ✓
- Existing warnings (BLEManager, try?) are pre-existing — not introduced by this plan ✓

## Commits

1. `feat(10-02): add getTodayMetric() to ServerSync — fetches /v1/today with DailyMetric parse`
2. `feat(10-02): call getTodayMetric() in pullDerivedWindow — ensures most-recent row outside window`

## Self-Check: PASSED

ALG-01, ALG-02, ALG-03 addressed: recovery/strain/sleep staging values flow from server `compute_day()` output through `/v1/today` → `getTodayMetric()` → `upsertDailyMetrics` → `DailyMetric.recovery/.strain/.totalSleepMin` → TodayView. Server-computed values overwrite local estimates via ON CONFLICT DO UPDATE (existing mechanism, now also triggered for the most-recent row via `/v1/today`).
