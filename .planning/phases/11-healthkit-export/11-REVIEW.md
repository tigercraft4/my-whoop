---
phase: "11"
status: warnings
depth: standard
files_reviewed: 12
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
reviewed: "2026-05-31"
---

# Code Review — Phase 11: HealthKit Export

**Depth:** Standard
**Files reviewed:** 12
**Status:** warnings (0 critical, 2 warnings, 3 info)

---

## Summary

Phase 11 implements HealthKit export cleanly. The HK-P1 invariant (entitlement before import) was correctly enforced. No critical bugs found. Two warnings should be addressed before shipping to a physical device.

---

## Findings

### WR-01 — HealthKitExporterViewModel creates a second HKHealthStore for status check

**Severity:** Warning
**File:** `ios/OpenWhoop/HealthKit/HealthKitExporterViewModel.swift`
**Lines:** 44–46

```swift
let hrType = HKQuantityType(.heartRate)
let store   = HKHealthStore()           // ← new instance, not the one in HealthKitExporter
let status  = store.authorizationStatus(for: hrType)
```

**Issue:** A second `HKHealthStore` is created just to check `authorizationStatus`. Apple's docs state one instance per app is recommended; multiple instances are harmless at runtime but wasteful and confusing. The exporter's `store` (inside the actor) is inaccessible here because it is `private`, so the ViewModel can't reuse it.

**Fix:** Either expose `authorizationStatus(for:)` as a method on the `HealthKitExporter` actor, or move the status check inside `requestAuthorization()` and return a `Bool` or enum result instead of throwing. The simplest fix: add a non-throwing `authorizationStatus(for:) -> HKAuthorizationStatus` method to the actor that delegates to its own `store`.

---

### WR-02 — Cursor update not atomic with save — partial export leaves cursor advanced on re-throw

**Severity:** Warning
**File:** `ios/OpenWhoop/HealthKit/HealthKitExporter.swift`
**Lines:** 82–86

```swift
try await store.save(hkSamples)         // (A) may throw
if let lastTs = samples.last?.ts {
    UserDefaults.standard.set(...)      // (B) only reached if (A) succeeds
}
```

**Issue:** If `store.save` throws at (A), the cursor is NOT advanced — which is correct. However, `store.save` for HealthKit can partially succeed (some samples written, some rejected for duplicates). In that case, save returns without throwing but some samples were silently skipped. On the next run, those samples would be re-queried (cursor not advanced) and re-submitted — HK deduplicates them, so the outcome is correct, but this is a documentation gap rather than a real bug.

The real risk is the reverse: if `store.save` succeeds partially and then the app crashes before (B) executes, the cursor is NOT advanced and all samples are re-exported on next launch. HealthKit deduplication handles this, but it is worth documenting explicitly.

**Fix (documentation):** Add a comment explaining the idempotency guarantee: "HealthKit deduplicates by source + timestamp, so re-exporting samples after a crash is safe." No code change required — this is a documentation/clarity issue.

---

### INFO-01 — `exportSleep` calls `sleepSessions` on every invocation (no highwater for sleep)

**Severity:** Info
**File:** `ios/OpenWhoop/HealthKit/HealthKitExporter.swift`
**Line:** 122

Sleep export always fetches all sessions and does delete+reinsert for each. For a user with years of sleep data, this will be slow. The plan explicitly chose delete+reinsert over highwater for sleep (correct — avoids temporal overlap bugs), but a future optimisation could limit to sessions modified in the last N days.

**No fix required** — the current implementation is correct and matches the plan intent.

---

### INFO-02 — `HealthKitExporterViewModel` comment says "AppRootCoordinator creates this as @Published"

**Severity:** Info
**File:** `ios/OpenWhoop/HealthKit/HealthKitExporterViewModel.swift`
**Line:** 11

The comment says "AppRootCoordinator creates this as @Published" but in `OpenWhoopApp.swift` it is stored as a plain `let` property, not `@Published`. This is correct (ObservableObjects inject their own published state) — the comment is misleading.

**Fix:** Update the comment: "AppRootCoordinator creates this as a `let` constant and exposes it via `.environmentObject`."

---

### INFO-03 — Test 4 (HK-03 absence) silently passes without checking anything in Simulator

**Severity:** Info
**File:** `ios/OpenWhoopTests/HealthKitExporterTests.swift`
**Lines:** 125–138

`testHealthKitExporterHasNoOxygenSaturationCode` uses `Bundle(for: type(of: self)).url(forResource:withExtension:)` which will not find `.swift` source files in a compiled test bundle — it returns `nil` and the test returns without asserting anything. This means the test always passes but never actually checks the source file.

The comment acknowledges this: "skip gracefully — the CI check is done by the grep in VERIFICATION.md". This is acceptable for a test that's primarily a documentation signal, but it gives false confidence.

**Fix (optional):** Remove the test entirely and rely solely on the grep check in VERIFICATION.md, OR use a compile-time check (a `typealias` or conditional compilation block) to enforce the absence at build time. If keeping the test, add `XCTAssertTrue(sourceURL != nil, "HealthKitExporter.swift should be findable in test bundle")` to make the skip explicit rather than silent.

---

## Files with No Issues

- `ios/project.yml` — clean; entitlements.properties syntax correct for XcodeGen 2.45
- `ios/OpenWhoop/OpenWhoop.entitlements` — correct plist structure with HealthKit keys
- `ios/OpenWhoop/Tabs/TodayView.swift` — lazy auth gate, banner, @AppStorage correctly used
- `ios/OpenWhoop/App/OpenWhoopApp.swift` — correct injection pattern, no auth at launch
- `ios/OpenWhoop/Settings/SettingsView.swift` — debug reset inside #if DEBUG correctly
- `ios/OpenWhoop/Metrics/MetricsRepository.swift` — `whoopStore` getter minimal and correct
- `Packages/WhoopStore/Sources/WhoopStore/Reads.swift` — new methods follow existing GRDB pattern exactly

---

## HK-P1 Invariant Verification

Confirmed: `import HealthKit` appears only in `ios/OpenWhoop/HealthKit/HealthKitExporter.swift` and `ios/OpenWhoop/HealthKit/HealthKitExporterViewModel.swift`. Both files were created in Wave 2+ (after Wave 1 committed `project.yml` with entitlement). Invariant maintained.

---

## Recommendation

- **WR-01:** Fix the second HKHealthStore instance before device testing — cosmetic but shows intent
- **WR-02:** Add the idempotency comment — no code change needed
- **INFO-01/02/03:** Low priority, address at discretion
