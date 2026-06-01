---
phase: 13-backend-parity
fixed_at: 2026-06-01T00:00:00Z
review_path: .planning/phases/13-backend-parity/13-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 13: Code Review Fix Report

**Fixed at:** 2026-06-01T00:00:00Z
**Source review:** .planning/phases/13-backend-parity/13-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (4 Critical, 3 Warning)
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01: sleep_performance_score called when total_sleep_min == 0.0

**Files modified:** `server/ingest/app/analysis/daily.py`
**Commit:** f8c79ed
**Applied fix:** Changed the guard at line 570 from `is not None` to `(sleep_summary.get("total_sleep_min") or 0.0) > 0`. Days with zero sleep now store `NULL` for `sleep_performance` instead of `0.0`, so the iOS layer hides the card rather than displaying "0%".

---

### CR-02: ALG-12 sleep-debt baseline double-counts yesterday

**Files modified:** `server/ingest/app/analysis/daily.py`
**Commit:** 27b03e9
**Applied fix:** Introduced `_baseline_rows = _prior_7d[:-1] if len(_prior_7d) > 1 else []` and built `_prior_sleep_min` from `_baseline_rows` rather than the full `_prior_7d`. Yesterday's row (`_last`) is now excluded from the baseline mean, eliminating the systematic underestimation of sleep debt.
**Note:** requires human verification — logic error correction.

---

### CR-03: relativeTime elapsed negative on clock skew

**Files modified:** `ios/OpenWhoop/Tabs/TodayView.swift`
**Commit:** ffab7e0
**Applied fix:** Changed `let elapsed = Int(-date.timeIntervalSinceNow)` to `let elapsed = max(0, Int(-date.timeIntervalSinceNow))`. Clamps elapsed to >= 0, making the intent explicit and future-proofing against branch reordering that could expose a "-3s ago" display.

---

### CR-04: _LOOKUP_TABLE module-level cache race under concurrent callers

**Files modified:** `server/ingest/app/analysis/daily.py`
**Commit:** 8448f8d
**Applied fix:** Removed the lazy `_load_ts_lookup()` function entirely. Replaced the `_LOOKUP_TABLE: list[dict] | None = None` declaration with an import-time try/except block that loads the JSON immediately. `training_state_from_lookup` now reads `_LOOKUP_TABLE` directly. Each worker process loads the file once on import; no check-then-set race is possible.

---

### WR-05: skin_temp and resp branches missing None guard on raw value

**Files modified:** `server/ingest/app/read.py`
**Commit:** 1b944fb
**Applied fix:** Added `raw = r.get("raw")` local variable and conditional guard `if raw is not None else None` to both the `skin_temp` and `resp` branches in `_augment_units`. Matches the existing pattern used by the `spo2` branch. Prevents `TypeError` when downsampled buckets produce `raw=None`.

---

### WR-03: duplicate /v1/today fetch when today is already in getDaily result

**Files modified:** `ios/OpenWhoop/Upload/ServerSync.swift`
**Commit:** 5fe5b47
**Applied fix:** Added `let todayStr = fmt.string(from: now)` and wrapped the `getTodayMetric()` call in `if !days.contains(where: { $0.day == todayStr })`. Uses `contains(where:)` rather than `days.last?.day` (which would be unsafe without guaranteed ordering) for a correct set-membership check. The fallback fetch still fires when today is absent from the window result (user hasn't synced in >60 days, etc.).

---

### WR-02: recovery normalization duplicated in getDaily and getTodayMetric

**Files modified:** `ios/OpenWhoop/Upload/ServerSync.swift`
**Commit:** e40b79e
**Applied fix:** Extracted a `private static func dailyMetricFrom(_ r: [String: Any]) -> DailyMetric?` helper that owns the single authoritative JSON-to-DailyMetric mapping, including the `recovery / 100.0` normalization. Both `getDaily` and `getTodayMetric` now delegate to this helper. No behaviour change — structural refactor only.

---

## Skipped Issues

None — all findings were fixed.

---

_Fixed: 2026-06-01T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
