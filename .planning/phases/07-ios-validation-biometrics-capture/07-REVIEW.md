---
phase: "07"
phase_name: ios-validation-biometrics-capture
status: clean
depth: standard
files_reviewed: 3
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
reviewed_at: "2026-05-31"
---

# Code Review — Phase 07: iOS Validation + Biometrics Capture

**Files reviewed:** 3 (Swift source files modified in Phase 7)
- `ios/OpenWhoop/BLE/BLEManager.swift`
- `ios/OpenWhoop/Live/LiveViewModel.swift`
- `ios/OpenWhoop/Settings/SettingsView.swift`

## Summary

All 3 files are clean. No critical issues, no warnings. One informational note about the `@EnvironmentObject` injection pattern used in SettingsView for `LiveViewModel`.

---

## Findings

### INFO-01: SettingsView now depends on both MetricsRepository and LiveViewModel environment objects

**Severity:** Info
**File:** `ios/OpenWhoop/Settings/SettingsView.swift`
**Lines:** 79–80

**Description:**
SettingsView now has `@EnvironmentObject private var model: LiveViewModel` alongside `@EnvironmentObject private var metrics: MetricsRepository`. This is architecturally correct and follows the established injection pattern (`OpenWhoopApp.swift` already injects `LiveViewModel` via `AppRoot.environmentObject(coordinator.live)`). However, if SettingsView is ever presented in a context that does not inject `LiveViewModel` (e.g., a new onboarding sheet or a test harness), it will crash with `@EnvironmentObject was not found`. The Preview already correctly injects both objects.

**Impact:** None in the current codebase — SettingsView is only presented from LiveView (via `showingSettings` sheet), which inherits environment objects from AppRoot. The `#if DEBUG` guard limits the usage of `model` to debug builds only, which further reduces risk.

**Recommendation:** No action required. Document the environment object requirement in the `// MARK: - SettingsView` comment for future maintainers.

---

## Positive Notes

**BLEManager.toggleIMUMode(on:):**
- Correctly delegates to `send(.toggleIMUMode, payload:)` with the right payload mapping (`[0x01]`/`[0x00]`)
- Access control is `public` (consistent with `send()`, `captureRawAccel()`, etc.)
- Uses `log()` for internal logging (correct — matches all other BLEManager command methods)
- Well-documented with HYPOTHESIS annotation matching the project's confidence tracking convention

**LiveViewModel.toggleIMUMode(on:):**
- One-liner passthrough following the exact pattern of `testAlarmBuzz()`, `disableStrapAlarm()`, etc.
- `public` visibility consistent with other LiveViewModel command passthroughs

**SettingsView debugSection:**
- `#if DEBUG` guard correctly applied to both the computed property definition and its usage in Form body
- `imuModeOn` state correctly maps to `[0x01]`/`[0x00]` payload via `toggleIMUMode(on:)`
- Visual indicator (ON/OFF with green/secondary color) is clear and consistent with app style

**No regressions:** Build SUCCEEDED on iOS Simulator (Debug configuration) with zero new errors or warnings introduced by Phase 7 changes.
