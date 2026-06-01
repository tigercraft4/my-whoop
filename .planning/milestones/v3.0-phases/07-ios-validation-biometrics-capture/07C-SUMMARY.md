---
phase: 7
plan: 07C
subsystem: iOS Validation + Maestro E2E Tests
tags: [ios, maestro, ble, background-reconnect, ios-08, today-view, sleep-view]
key-files:
  created:
    - ios/maestro/07_ios08_background_reconnect.yaml
  modified:
    - .planning/REQUIREMENTS.md (IOS-03/04/05/08 status notes updated)
metrics:
  tasks_completed: 5
  tasks_total: 5
  maestro_tests_created: 1
  hardware_validations_pending: 3
---

## Summary

Plan 07C created the Maestro E2E test for IOS-08 background reconnect via willRestoreState, documented the status of TodayView/SleepView validation (hardware pending), and updated REQUIREMENTS.md with Phase 7 status notes. IOS-05 is correctly deferred to Phase 9. TrendsView and MetricKind.swift were not modified.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| T1-T5 | ece9277 | feat(07C): add Maestro IOS-08 background reconnect test + update requirements |

## What Was Built

**ios/maestro/07_ios08_background_reconnect.yaml** — New Maestro E2E test following the exact pattern of tests 01–06:
- `appId: com.openwhoop.OpenWhoop` (exact match)
- Two `launchApp` calls (before and after `stopApp`)
- `runFlow: utils/allow_notifications.yaml` (after each launchApp)
- `stopApp` command to simulate force-quit (SIGKILL equivalent)
- `waitForAnimationToEnd` with timeout 30000ms after relaunch (IOS-08 criterion: reconnects within 30s)
- Two `assertVisible` calls with text "Connected" (actual UI string from LiveView.swift line 182: `state.connected ? "Connected" : "Disconnected"`)
- Six `takeScreenshot` calls documenting: initial, device tab, connected, relaunch, reconnected, final

**REQUIREMENTS.md updated:**
- IOS-03: annotated "hardware validation pending (requires physical device + Phase 6 backfill)"
- IOS-04: annotated "hardware validation pending (requires physical device + Phase 6 backfill)"
- IOS-05: marked "deferred to Phase 9 SwiftUI Redesign"
- IOS-08: noted "Maestro test ready; hardware execution pending"

## Task Status

**T1 (IOS-03 TodayView validation):** Hardware validation pending — requires physical iPhone with WHOOP 5.0 and Phase 6 backfill functional. TodayView code confirmed to show "—" placeholders when `metrics.today` is nil and real values when populated (line 119: `Text("—")`). No code changes required — validation is observational.

**T2 (IOS-04 SleepView validation):** Hardware validation pending — same hardware requirement. SleepView SpO₂ HYPOTHESIS comment at lines 305–306 confirmed present and unchanged (as required by plan).

**T3 (Maestro test creation):** COMPLETED — `07_ios08_background_reconnect.yaml` created with all required elements. `assertVisible` text "Connected" sourced from LiveView.swift line 182 (actual UI string, not placeholder).

**T4 (Maestro test execution):** Hardware pending — "hardware test pending — test file ready for execution". Physical iPhone + WHOOP 5.0 in range required for `maestro test` execution.

**T5 (REQUIREMENTS.md update):** COMPLETED — IOS-03/04/05/08 updated. IOS-05 remains `[ ]` (deferred). TrendsView.swift and MetricKind.swift confirmed unmodified (`git diff --name-only` returned no matches).

## Verification

1. `ls ios/maestro/07_ios08_background_reconnect.yaml` — file exists ✓
2. `grep "stopApp" ...yaml` — force-quit step present ✓
3. `grep "30000" ...yaml` — 30s reconnect timeout present ✓
4. `grep '"\[ \].*IOS-05"'` — IOS-05 remains unchecked ✓
5. `grep "deferred" REQUIREMENTS.md` — deferred note present ✓
6. `git diff --name-only | grep -E "TrendsView|MetricKind"` — returns nothing ✓

## Deviations

**IOS-03 and IOS-04 not marked [x]:** Physical device validation was not possible in automated context. The plan explicitly states: "If data does not appear (Phase 6 fix not yet deployed or backfill incomplete): document the blocker explicitly — do NOT mark IOS-03 done." Blocker documented: hardware validation pending.

**IOS-08 Maestro test not executed:** Plan explicitly states: "If the Maestro test cannot be run on CI (no physical device): document 'manual validation required — physical iPhone + WHOOP 5.0 in range' as the blocker. The test file is still committed as the artifact; hardware execution is the validation." Test file committed; IOS-08 remains `[ ]`.

## Self-Check: PASSED

All 5 tasks completed. Maestro test file created with all required elements and correct UI strings. IOS-05 deferred correctly. TrendsView/MetricKind.swift not modified. REQUIREMENTS.md updated accurately. Hardware-dependent validations documented with explicit blockers per plan instructions.
