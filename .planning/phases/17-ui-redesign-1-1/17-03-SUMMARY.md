---
plan: "17-03"
phase: "17"
status: complete
completed: "2026-06-01"
duration_minutes: 25
tasks_completed: 5
tasks_total: 5
---

# Summary — 17-03: UI-02/03 Home/Recovery Screen Redesign + Snapshot

## What Was Built

Redesigned `RecoveryCard.swift` and `TodayView.swift` with verified WH.* tokens. Added `RecoveryCardSnapshotTests.swift` with 3 tests. Validated in simulator.

## Key Files

### Modified
- `ios/OpenWhoop/Design/Components/RecoveryCard.swift` — Color.black → WH.Color.surface; added NEED stat column (sleepNeededMin)
- `ios/OpenWhoop/Tabs/TodayView.swift` — zone-aware strain color helper

### Created
- `ios/OpenWhoopTests/SnapshotTests/RecoveryCardSnapshotTests.swift` — 3 snapshot tests
- `ios/OpenWhoopTests/SnapshotTests/__Snapshots__/RecoveryCardSnapshotTests/` — 3 PNG references

## Notable Changes

- `RecoveryCard` background changed from `Color.black` → `WH.Color.surface` (#1A2227) — now visually distinct from app background (#000000)
- Added "NEED" stat column showing `sleepNeededMin` (ALG-12) — matches WHOOP official layout
- `TodayView` strain card now uses zone-aware color: blue/medium-blue/dark-blue per zone
- Snapshot tests use `UIHostingController` (required for SnapshotTesting 1.17.6 API)

## Simulator Validation

Screenshot confirms:
- Background: #000000 (pure black) ✓
- Cards: #1A2227 (Grey Blue from Assets.car) ✓
- HRV | RHR | SLEEP | NEED columns visible ✓
- No crash, clean empty state ✓

## Self-Check

- [x] `grep "Color.black" RecoveryCard.swift` → 0 matches
- [x] `grep "WH.Color.surface" RecoveryCard.swift` → 1 match
- [x] Snapshot tests: 3/3 pass
- [x] Build: BUILD SUCCEEDED

## Self-Check: PASSED
