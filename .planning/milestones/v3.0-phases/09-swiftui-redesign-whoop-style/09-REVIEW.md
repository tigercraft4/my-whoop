---
phase: "09"
phase_name: "swiftui-redesign-whoop-style"
status: "warnings"
depth: "standard"
files_reviewed: 12
reviewed_at: "2026-05-31"
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
---

# Code Review — Phase 09: SwiftUI Redesign WHOOP-Style

**Depth:** standard | **Files reviewed:** 12 | **Status:** warnings (0 critical, 3 warning, 2 info)

---

## Files Reviewed

1. `ios/OpenWhoop/Design/DesignTokens.swift`
2. `ios/OpenWhoop/App/RootTabView.swift`
3. `ios/OpenWhoop/Design/Components/ZoneRingView.swift`
4. `ios/OpenWhoop/Design/DesignGallery.swift`
5. `ios/OpenWhoop/Design/Components/RecoveryCard.swift`
6. `ios/OpenWhoop/Tabs/TodayView.swift`
7. `ios/OpenWhoop/Design/Components/SleepCard.swift`
8. `ios/OpenWhoop/Tabs/SleepView.swift`
9. `ios/OpenWhoop/Design/Components/StrainCard.swift`
10. `ios/OpenWhoop/Tabs/StrainView.swift`
11. `ios/OpenWhoop/Charts/MetricKind.swift`
12. `ios/OpenWhoop/App/RootTabView.swift` (deduplicated)

---

## Findings

### WR-01 — `.cornerRadius(_:)` deprecated in favour of `.clipShape(RoundedRectangle(...))`

**Severity:** Warning
**Files:** `RecoveryCard.swift:83`, `SleepCard.swift:81`, `StrainCard.swift:71`

**Description:** Three new card components use `.cornerRadius(WH.Radius.card)` which is deprecated in iOS 17+ in favour of `.clipShape(RoundedRectangle(cornerRadius:style:))`. The deprecated modifier still works but produces Xcode warnings and may be removed in a future SDK.

**Occurrences:**
- `RecoveryCard.swift:83` — `.background(Color.black).cornerRadius(WH.Radius.card)`
- `SleepCard.swift:81` — `.background(Color.black).cornerRadius(WH.Radius.card)`
- `StrainCard.swift:71` — `.background(Color.black).cornerRadius(WH.Radius.card)`

**Fix:**
```swift
// Replace:
.background(Color.black)
.cornerRadius(WH.Radius.card)

// With:
.background(Color.black, in: RoundedRectangle(cornerRadius: WH.Radius.card, style: .continuous))
```
Note: Using `.continuous` style matches the `RoundedRectangle` style used throughout the existing codebase (e.g. `SleepView`, `TrendsView`).

---

### WR-02 — `SleepCard.hoursSleepLabel` computes total time in bed (not sleep time) when falling back to session timestamps

**Severity:** Warning
**File:** `SleepCard.swift:22-24`

**Description:** When `DailyMetric.totalSleepMin` is nil, `hoursSleepLabel` falls back to `(session.endTs - session.startTs) / 60 / 60` — which is total time in **bed**, not total time **asleep**. This contradicts the field label "HOURS OF SLEEP" shown to the user and can overstate sleep duration (e.g. 8.5 hr in bed may be only 7.2 hr asleep). The label comment correctly notes this is a known limitation, but there is no visual indicator to warn the user.

**Code:**
```swift
// SleepCard.swift lines 22-24
if let s = session {
    let totalMin = Double(s.endTs - s.startTs) / 60
    if totalMin > 0 { return String(format: "%.1f hr", totalMin / 60) }
```

**Fix options:**
1. (Minimal) Add a tilde prefix when using the fallback: `"~%.1f hr"` to indicate approximate value.
2. (Preferred) Show `"—"` when `totalSleepMin` is nil rather than displaying a misleading value, and let the field be empty until Phase 7 data is available.
3. (Future) Use `CachedSleepSession.avgHrv` as a proxy indicator that the session has real sleep data before showing the fallback.

---

### WR-03 — `StrainCard.zoneLabel` switch does not cover `exactly 10` or `exactly 17` consistently

**Severity:** Warning
**File:** `StrainCard.swift:25-29`

**Description:** The strain zone switch uses `case 10...17` (closed range, inclusive on both ends) which is correct. However, the boundary case `strain == 10.0` is classified as OPTIMAL (correct per WHOOP), but floating-point values very slightly below 10 (e.g. 9.9999...) triggered by the sensor rounding could appear as RESTORATIVE when they are visually ≈10. This is a minor precision concern, not a crash, but worth documenting.

More substantively: the switch covers `case ..<10`, `case 10...17`, `default`. The `default` arm is correct for > 17. No gap or overlap exists for whole number boundaries.

**Assessment:** The logic is functionally correct as written. The floating-point concern exists but is inherent to all such threshold switches; the existing `recoveryColor(forPercent:)` helper in DesignTokens uses the same pattern. This finding is a code quality observation, not a bug.

**No fix required.** Consider adding a comment explaining the threshold choices match WHOOP zones for future readers.

---

### IN-01 — `MetricKind.color` for `.spo2` duplicates `WH.Color.teal` (same as `.hrv`)

**Severity:** Info
**File:** `MetricKind.swift:69`

**Description:** Both `.hrv` and `.spo2` return `WH.Color.teal`. While the comment says "distinct from other metrics", they share the same colour. On a Trends chart where both HRV and SpO₂ lines are visible simultaneously, they will be visually indistinguishable. This is acceptable for now given SpO₂ data is PROTO-11 gated (typically nil), but should be differentiated before both metrics display data simultaneously.

**No fix required for this phase.** Consider adding a distinct colour for SpO₂ (e.g. `WH.Color.sleepPurple` or a new light-blue) when PROTO-11 data becomes available.

---

### IN-02 — `StrainView.dateRange()` and `WorkoutsView.dateRange()` are exact code duplicates

**Severity:** Info
**Files:** `StrainView.swift:52-60`, `WorkoutsView.swift:224-233`

**Description:** The `dateRange()` private method is copy-pasted verbatim between `StrainView` and `WorkoutsView`. If the range (currently 30 days) or the date formatting logic changes in the future, both files must be updated in sync.

**Fix (future refactor, not blocking):** Extract to a shared utility extension on `MetricsRepository` or to a free function in a `DateHelpers.swift` file:
```swift
// In a shared utilities file:
func workoutDateRange(days: Int = 30) -> (from: String, to: String) { ... }
```

**No fix required for this phase.** Log as a future refactor opportunity.

---

## Summary

| Finding | Severity | File | Fix Required |
|---------|----------|------|--------------|
| WR-01: `.cornerRadius` deprecated | Warning | RecoveryCard, SleepCard, StrainCard | Yes — cosmetic |
| WR-02: SleepCard fallback shows time-in-bed | Warning | SleepCard.swift | Recommended |
| WR-03: StrainCard zone switch boundary | Warning | StrainCard.swift | No — accepted |
| IN-01: spo2 and hrv share teal color | Info | MetricKind.swift | No — future work |
| IN-02: dateRange() duplicated | Info | StrainView, WorkoutsView | No — future refactor |

**Critical issues: 0** — Phase is safe to ship as-is.

**Recommended fixes before next phase:**
- WR-01: Replace `.cornerRadius` with `.clipShape(RoundedRectangle(...))` in 3 card files
- WR-02: Use `"~"` prefix or `"—"` when falling back to time-in-bed in SleepCard

---

## Security Assessment

No security issues found. All changes are pure SwiftUI view layer:
- No network requests added
- No user data written to disk
- No new permissions
- `@SceneStorage` uses iOS system storage (safe)
- All metric values from existing `MetricsRepository` / `DailyMetric` model

---
*Phase: 09-swiftui-redesign-whoop-style*
*Reviewed: 2026-05-31*
