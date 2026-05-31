---
phase: "10"
status: clean
depth: standard
files_reviewed: 4
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
reviewed_at: "2026-05-31"
---

# Code Review — Phase 10: Algorithms Display + Server Endpoint

**Files reviewed:**
- `server/ingest/app/read.py` (query_today)
- `server/ingest/app/main.py` (GET /v1/today route)
- `ios/OpenWhoop/Upload/ServerSync.swift` (getTodayMetric, pullDerivedWindow)
- `ios/OpenWhoop/Tabs/TodayView.swift` (heroSection staleness label)

---

## Findings

### WR-01 — TodayView: `Date()` called twice in staleness label expression

**File:** `ios/OpenWhoop/Tabs/TodayView.swift`, lines 103–105
**Severity:** Warning
**Category:** Code Quality / Potential Race

```swift
if let at = metrics.lastRefreshedAt,
   Date().timeIntervalSince(at) > StalenessPolicy.staleAfterSeconds {
    Text("Updated \(Int(Date().timeIntervalSince(at) / 3600))h ago")
```

`Date()` is instantiated twice in the same render pass. While the delta is negligible in practice (sub-millisecond), this is a code smell: if the view body is evaluated across a tick boundary (e.g., a very slow main-thread evaluation) the two `Date()` values could differ, causing the label's hour count to be computed from a slightly different timestamp than the guard condition. The canonical fix is to compute `elapsed` once:

```swift
if let at = metrics.lastRefreshedAt {
    let elapsed = Date().timeIntervalSince(at)
    if elapsed > StalenessPolicy.staleAfterSeconds {
        Text("Updated \(Int(elapsed / 3600))h ago")
            .font(WH.Font.caption)
            .foregroundStyle(WH.Color.textSecondary)
    }
}
```

---

### INFO-01 — ServerSync.getTodayMetric: duplicate field-mapping code vs. getDaily

**File:** `ios/OpenWhoop/Upload/ServerSync.swift`, lines 395–411
**Severity:** Info
**Category:** Maintainability / DRY

`getTodayMetric()` duplicates the 14-field `DailyMetric` construction block verbatim from `getDaily(from:to:)`. If a new column is added to `_DAILY_COLS` on the server and the iOS field mapping is updated in `getDaily`, `getTodayMetric` will silently lag behind.

**Suggestion:** Extract a private helper `buildDailyMetric(from row: [String: Any]) -> DailyMetric?` that both `getDaily` and `getTodayMetric` call. This is a refactor, not a bug — the duplication is currently self-consistent. No action required before shipping; consider for a cleanup phase.

---

### INFO-02 — server/read.py: f-string with JOIN on every call

**File:** `server/ingest/app/read.py`, line 248
**Severity:** Info
**Category:** Minor Performance / Consistency

```python
f"SELECT {', '.join(_DAILY_COLS)} FROM daily_metrics "
```

`query_today` uses an f-string with `_DAILY_COLS` join, identical to the existing `query_daily` pattern. This is consistent with the existing codebase style. Minor note: `_DAILY_COLS` is a module-level list so the join is O(n) on every call. The existing `query_daily` has the same pattern, so this is not a regression — just worth noting if the column list grows significantly. No action required.

---

## Summary

All critical and security checks pass. The new code is consistent with existing patterns:

- `query_today` uses parameterised query (`%s`) — no SQL injection surface
- `/v1/today` route requires `Depends(require_auth)` — no auth bypass
- `getTodayMetric()` handles JSON `null` and network errors with `nil` return — no crash path
- Staleness label is nil-guarded (`if let at`) and condition-guarded (`> staleAfterSeconds`) — no phantom display
- `StalenessPolicy.staleAfterSeconds` referenced as constant — no magic number

**Recommended action:** Fix WR-01 (minor, 3-line change). INFO findings are advisory.
