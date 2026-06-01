---
phase: 7
plan: 07B
subsystem: iOS BLE Debug UI
tags: [swift, ble, debug, settings, toggle-imu]
key-files:
  created:
    - ios/OpenWhoop/BLE/BLEManager.swift (toggleIMUMode method added)
    - ios/OpenWhoop/Live/LiveViewModel.swift (toggleIMUMode passthrough added)
    - ios/OpenWhoop/Settings/SettingsView.swift (debug section added)
metrics:
  tasks_completed: 4
  tasks_total: 4
  files_changed: 3
  lines_added: ~47
---

## Summary

Plan 07B implemented a `#if DEBUG` TOGGLE_IMU_MODE button in the iOS Settings tab, enabling direct BLE command dispatch to the WHOOP 5.0 from the iPhone without requiring the Python harness.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| T1-T4 | 8874553 | feat(07B): add TOGGLE_IMU_MODE debug button to iOS Settings tab |

## What Was Built

**BLEManager.toggleIMUMode(on:)** — New public method added after `testAlarmBuzz()` in the Alarm API section. Sends `WhoopCommand.toggleIMUMode` (rawValue 106) with payload `[0x01]` (ON) or `[0x00]` (OFF) via the existing `send(_:payload:)` path. Uses `log()` for `.info`-level logging consistent with BLEManager conventions.

**LiveViewModel.toggleIMUMode(on:)** — Public passthrough to the private BLEManager instance. Follows the same delegation pattern as `testAlarmBuzz()`, `armStrapAlarm(at:)`, etc.

**SettingsView debug section** — Added:
- `@EnvironmentObject private var model: LiveViewModel` to SettingsView
- `@State private var imuModeOn: Bool = false` tracking toggle state
- `#if DEBUG` computed property `debugSection` with a "Developer" Section containing an IMU Mode button showing ON/OFF state in green/secondary
- `#if DEBUG debugSection #endif` at the bottom of the Form body (after footerSection)
- Preview updated to inject `LiveViewModel(deviceId: "preview")`

## Verification

- `grep "toggleIMUMode" Commands.swift` → exactly 1 enum case + 1 label case ✓
- `grep "= 106" Commands.swift` → exactly 1 match (no duplicate rawValue) ✓
- `grep "func toggleIMUMode" BLEManager.swift` → 1 match, accepts Bool, calls send(.toggleIMUMode) ✓
- `grep "imuModeOn" SettingsView.swift` → 4 matches (@State + toggle + call + label) ✓
- `grep "#if DEBUG" SettingsView.swift` → 2 matches (Form body + section definition) ✓
- `grep "debugSection" SettingsView.swift` → 2 matches (definition + usage) ✓
- `grep "IMU Mode" SettingsView.swift` → 1 match ✓
- Simulator build: **SUCCEEDED** (exit 0, no new errors) ✓

## Deviations

**LiveViewModel passthrough added (not in plan):** The plan specified using `@EnvironmentObject var ble: BLEManager` directly in SettingsView. However, BLEManager is `private` inside LiveViewModel and not injected into the environment — only `LiveViewModel` and `MetricsRepository` are injected. Resolution: added `toggleIMUMode(on:)` as a public passthrough in LiveViewModel following the established pattern (same as `testAlarmBuzz()`, `armStrapAlarm(at:)`, etc.). This is architecturally correct and avoids exposing BLEManager to the environment.

## Self-Check: PASSED

All 4 tasks completed. iOS build succeeds. Debug section is correctly gated with `#if DEBUG`. Button state maps `imuModeOn=true → [0x01]` and `imuModeOn=false → [0x00]` as specified. No new compilation errors introduced.
