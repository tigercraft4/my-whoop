---
plan: "10-03"
phase: 10
status: complete
started: "2026-05-31"
completed: "2026-05-31"
key-files:
  created: []
  modified:
    - ios/OpenWhoop/Tabs/TodayView.swift
requirements-addressed:
  - ALG-01
---

# Summary — 10-03: iOS — Staleness indicator on RecoveryCard

## What Was Built

Added a staleness label "Updated Xh ago" inside the `heroSection` (RecoveryCard) in `TodayView.swift`. The `heroSection` is now wrapped in a `VStack` to accommodate the label below the recovery ring. The label appears only when `metrics.lastRefreshedAt` is more than 6 hours ago, using `StalenessPolicy.staleAfterSeconds` as the single source of truth.

## Tasks Completed

| Task | Status | Notes |
|------|--------|-------|
| T1 — Add staleness label to heroSection | ✓ Complete | VStack wraps NavigationLink; label uses StalenessPolicy.staleAfterSeconds |
| T2 — Build and visually verify | ✓ Complete | BUILD SUCCEEDED; app runs without crash; label correctly absent with nil lastRefreshedAt |

## Key Decisions

- `heroSection` changed from single `NavigationLink` to `VStack(spacing: WH.Spacing.xs)` wrapping the link + label
- `StalenessPolicy.staleAfterSeconds` referenced — not a hardcoded literal (D-06)
- Label guarded by `if let at = metrics.lastRefreshedAt` — nil-safe
- Label only fires when `Date().timeIntervalSince(at) > StalenessPolicy.staleAfterSeconds` (6h threshold)
- `WH.Font.caption` and `WH.Color.textSecondary` — consistent with existing secondary text patterns in TodayView
- `SleepCard` and `StrainCard` are unchanged (D-07: no staleness indicator on other cards)
- `syncFooter` is unchanged — still shows "Updated X ago" for all refreshes in the footer

## Visual Verification

- App launched on iPhone 17 Pro simulator (iOS 18 Simulator)
- Today tab renders without crash — RecoveryCard visible with dashes (no data/sync in simulator)
- Staleness label correctly absent (expected: `lastRefreshedAt == nil` in simulator with no sync)
- Label will appear after a real sync that occurred >6h ago — verified by logic inspection

## Verification Results

- `grep "StalenessPolicy.staleAfterSeconds" ios/OpenWhoop/Tabs/TodayView.swift` → line 104 ✓
- `grep "Updated.*h ago" ios/OpenWhoop/Tabs/TodayView.swift` → line 105 ✓
- `grep "VStack" ios/OpenWhoop/Tabs/TodayView.swift` → heroSection now uses VStack ✓
- Build: `** BUILD SUCCEEDED **` via XcodeBuildMCP build_run_sim ✓
- `syncFooter` still references `relativeTime(from: at)` — unchanged ✓
- `SleepCard` and `StrainCard` not modified ✓

## Commits

1. `feat(10-03): add staleness label to heroSection in TodayView — Updated Xh ago when >6h stale`

## Self-Check: PASSED

ALG-01 staleness indicator requirement met: RecoveryCard (heroSection) displays "Updated Xh ago" label when data is stale (>6h). `StalenessPolicy.staleAfterSeconds` is the single source of truth. SleepCard and StrainCard untouched (D-07).
