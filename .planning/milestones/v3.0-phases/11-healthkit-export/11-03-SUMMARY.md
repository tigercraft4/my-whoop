---
plan: "11-03"
title: "TodayView Integration — Lazy Auth + Health-Not-Connected Banner"
status: complete
phase: 11
wave: 3
completed: "2026-05-31"
---

# Summary: 11-03 TodayView Integration

## What Was Built

Integrated HealthKitExporter into the app: `HealthKitExporterViewModel` (ObservableObject wrapper) injected via `AppRootCoordinator`, lazy HealthKit authorization triggered from `TodayView.task` only when `metrics.today != nil`, one-time "Health not connected" banner on denial, and simulator guard via `HKHealthStore.isHealthDataAvailable()`.

## Tasks Completed

| Task | Title | Status |
|------|-------|--------|
| 11-03-T1 | Inject HealthKitExporter into AppRoot and pass as EnvironmentObject | ✓ Complete |
| 11-03-T2 | Add lazy auth + export trigger in TodayView.task and banner | ✓ Complete |
| 11-03-T3 | Guard HealthKitExporter against simulator / unavailable HealthData | ✓ Complete |

## Key Files Created/Modified

### key-files.created
- `ios/OpenWhoop/HealthKit/HealthKitExporterViewModel.swift` — ObservableObject wrapper: `isAuthorized`, `authDenied`, `requestAuthorizationAndExport(whoopStore:deviceId:)` with lazy actor creation and `isHealthDataAvailable()` guard

### key-files.modified
- `ios/OpenWhoop/App/OpenWhoopApp.swift` — `AppRootCoordinator` now owns `hkExporter: HealthKitExporterViewModel`; `AppRoot.body` exposes it via `.environmentObject`
- `ios/OpenWhoop/Metrics/MetricsRepository.swift` — added `var whoopStore: WhoopStore? { store }` getter
- `ios/OpenWhoop/Tabs/TodayView.swift` — `@EnvironmentObject hkExporter`, `@AppStorage("hk.authDeniedShown")`, lazy auth in `.task`, `healthNotConnectedBanner` overlay, `ZStack(alignment: .top)` wrapping

## Deviations

- `MetricsRepository.whoopStore` getter added (not in original plan scope) — needed because the TodayView has no direct access to the WhoopStore; the repo opens it lazily and the getter exposes it after the first `refresh()` call. This is cleaner than having the ViewModel open its own SQLite connection.

## Self-Check

### Verification Results

1. `.environmentObject(coordinator.hkExporter)` in AppRoot.body → ✓
2. No `requestAuthorization` call in AppRoot.init() → ✓
3. `guard metrics.today != nil` before HK auth in TodayView.task → ✓
4. `@AppStorage("hk.authDeniedShown")` in TodayView → ✓
5. `x-apple-health://` deep link in healthNotConnectedBanner → ✓
6. `HKHealthStore.isHealthDataAvailable()` in both ViewModel and Exporter → ✓
7. `xcodebuild build -scheme OpenWhoop ...` → ✓ SUCCEEDED (via xcodebuildmcp)
8. Zero pre-existing warnings increased (BLEManager warnings pre-exist) → ✓

**Self-Check: PASSED**

## Notes

- Banner is a non-blocking `Capsule()` pill at top of ZStack, shown with animation, dismissible with ✕
- Banner tap opens `x-apple-health://` if available; falls back to `UIApplication.openSettingsURLString`
- `authDeniedShown` is `@AppStorage` — persists across app relaunches; banner shown exactly once
- Simulator: `isHealthDataAvailable()` returns false → entire export no-ops silently
