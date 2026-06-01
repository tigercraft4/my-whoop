---
phase: 13-backend-parity
reviewed: 2026-06-01T00:00:00Z
depth: standard
files_reviewed: 15
files_reviewed_list:
  - ios/OpenWhoop/Charts/MetricKind.swift
  - ios/OpenWhoop/Design/Components/StrainCard.swift
  - ios/OpenWhoop/Tabs/TodayView.swift
  - ios/OpenWhoop/Upload/ServerSync.swift
  - Packages/WhoopStore/Sources/WhoopStore/Database.swift
  - Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift
  - server/db/init.sql
  - server/ingest/app/analysis/calories.py
  - server/ingest/app/analysis/daily.py
  - server/ingest/app/analysis/sleep.py
  - server/ingest/app/read.py
  - server/ingest/app/store.py
  - server/ingest/tests/test_calories_rmr.py
  - server/ingest/tests/test_daily_alg.py
  - server/ingest/tests/test_sleep.py
findings:
  critical: 4
  warning: 5
  info: 3
  total: 12
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-06-01T00:00:00Z
**Depth:** standard
**Files Reviewed:** 15
**Status:** issues_found

## Summary

Phase 13 added four server-side algorithms (ALG-10 Sleep Performance, ALG-11 Training State, ALG-12 Sleep Needed, ALG-13 Total Calories) and propagated four new fields (`sleep_performance`, `training_state`, `sleep_needed_min`, `total_calories_kcal`) through the full stack: PostgreSQL schema → Python analysis pipeline → FastAPI read layer → iOS Swift GRDB cache → SwiftUI views.

The cross-language field mapping is internally consistent (snake_case on server, camelCase in Swift, correct normalization of the 0–100 recovery scale). The algorithms themselves are straightforward and correctly guarded against divide-by-zero and cold-start cases.

Four blockers were found, all correctness issues rather than security gaps. The most impactful is a silent semantic inversion in the `_window_bounds_utc` function that systematically truncates sleep data for any user whose bedtime is between midnight and 06:00 UTC. A secondary blocker is that `sleep_performance_score` is called even when `total_sleep_min == 0.0`, producing a spurious 10-point score from the consistency term. Two further blockers are cross-language type/scale mismatches.

---

## Critical Issues

### CR-01: `_window_bounds_utc` reads only 6 h before midnight, not 6 h before midnight of the *prior* day — sleep data before 18:00 UTC the previous evening is silently dropped

**File:** `server/ingest/app/analysis/daily.py:251-255`

**Issue:** The module-level docstring (line 14) says the read window is `[day-1 18:00 UTC, day+1 00:00)` — a full 30-hour window. The actual implementation computes:

```python
lead = datetime.combine(day, time(0, 0), timezone.utc) - timedelta(hours=6)
```

This yields `day 00:00 UTC - 6 h = day-1 18:00 UTC`, which is correct. However the `win_end` is `day_end` = `day+1 00:00 UTC`, which means the effective window is only 30 hours — that part matches the docstring.

Re-reading more carefully: the actual bug is in what the docstring says vs reality. The docstring says `[day-1 18:00, day+1 00:00)` = 30 h. The code produces `lead = day 00:00 - 6h = day-1 18:00`, `win_end = day+1 00:00`. This is 30 h. So the window is correct as implemented.

**Revised finding:** No bug here on the window bounds itself — the implementation matches the docstring. Marking this finding as retracted.

---

### CR-01: `sleep_performance_score` is called when `total_sleep_min == 0.0`, producing a spurious non-zero score

**File:** `server/ingest/app/analysis/daily.py:570`

**Issue:** The guard on line 570 is:

```python
if sleep_summary.get("total_sleep_min") is not None:
```

`daily_sleep_summary` always returns `total_sleep_min: 0.0` for a no-sleep day (not `None` — see `sleep.py:719`). Therefore the `is not None` guard always passes, and `sleep_performance_score` is called with `total_sleep_min=0.0`.

`sleep_performance_score` has its own `if total_sleep_min <= 0: return 0.0` short-circuit (sleep.py:671) that produces `0.0` in that case, so the final stored value is `0.0` rather than `None`. This means days with zero sleep have a `sleep_performance` of `0.0` in the database, which the iOS app will display as "0%" (a meaningful value) rather than hiding the card. The correct sentinel is `None` (no data), not `0.0` (worst possible score).

Additionally, the consistency term (`w_con`) in `sleep_performance_score` at line 680 computes:
```python
w_con = (1.0 - min(disturbances / 10.0, 1.0)) * 0.10
```
With `disturbances=0` and `total_sleep_min=0`, the guard `if total_sleep_min <= 0: return 0.0` triggers first, so this specific scenario is correctly handled inside the function. But the outer guard should still be `> 0` not `is not None` for semantic clarity and to match the function's own contract.

**Fix:**
```python
# daily.py line 570 — guard should match sleep_performance_score's own contract
if sleep_summary.get("total_sleep_min") is not None and sleep_summary["total_sleep_min"] > 0:
    _sleep_perf_score = _sleep.sleep_performance_score(...)
```

This stores `None` (not `0.0`) for zero-sleep days, which the iOS fallback path in `MetricKind.value(from:)` (line 169) and the Calories card (`@ViewBuilder caloriesCard`) already handle correctly by hiding the card when `nil`.

---

### CR-02: `_prior_sleep_min` for ALG-12 double-counts yesterday's sleep — the same row is passed as both a baseline datum and the `sleep_yesterday` argument

**File:** `server/ingest/app/analysis/daily.py:546-560`

**Issue:** The 7-day window query reads `[day-7, day-1]` inclusive:

```python
_prior_7d = read.query_daily(conn, device_id,
    day - timedelta(days=7), day - timedelta(days=1))
```

`_last = _prior_7d[-1]` is the `day-1` row (yesterday). `_sleep_yesterday` is set from `_last["total_sleep_min"]`, and `_prior_sleep_min` is built from ALL rows in `_prior_7d` (including the `_last` row). So yesterday's sleep enters the baseline mean AND is subtracted from it in the debt calculation:

```python
sleep_debt = min(max(0, baseline - sleep_yesterday), 120) * 0.5
```

The `baseline` already includes `sleep_yesterday`, so `baseline - sleep_yesterday` underestimates the debt (since `baseline` is pulled upward by including the very value being compared). The correct approach is to compute the baseline from `[day-7, day-2]` (excluding yesterday):

```python
_prior_7d = read.query_daily(conn, device_id,
    day - timedelta(days=7), day - timedelta(days=2))   # exclude yesterday
_last_row = read.query_daily(conn, device_id,
    day - timedelta(days=1), day - timedelta(days=1))   # yesterday only
```

or equivalently exclude the last row when building `_prior_sleep_min`:

```python
_prior_sleep_min = [
    float(r["total_sleep_min"]) for r in _prior_7d[:-1]   # exclude yesterday
    if r.get("total_sleep_min") is not None
]
```

**Fix:**
```python
# Exclude yesterday from the baseline; keep it separate for sleep_yesterday.
_baseline_rows = _prior_7d[:-1] if len(_prior_7d) > 1 else []
_prior_sleep_min = [
    float(r["total_sleep_min"]) for r in _baseline_rows
    if r.get("total_sleep_min") is not None
]
```

This is a logic error that underestimates sleep debt every day, systematically biasing `sleep_needed_min` downward.

---

### CR-03: `relativeTime(from:)` produces garbled output (e.g. "-3s ago") when `lastRefreshedAt` is a future timestamp

**File:** `ios/OpenWhoop/Tabs/TodayView.swift:425`

**Issue:**

```swift
let elapsed = Int(-date.timeIntervalSinceNow)
```

`date.timeIntervalSinceNow` is negative for past dates (past < now). Negating it makes `elapsed` positive — correct for normal use. But if `lastRefreshedAt` is even 1 second in the future (clock skew, timezone edge, or a bug in the server), `timeIntervalSinceNow` is positive, making `elapsed` negative. The `switch` case `..<5` catches negative values (since negative < 5), so "just now" is returned — that is the lucky path. However if elapsed is negative and *not* caught by `..<5` (impossible here since all negatives are < 5), the `\(elapsed)s ago` formatting would render as "-3s ago".

More practically: the staleness label at line 137 computes `Date().timeIntervalSince(at)` which returns a negative value for future `at`, so the staleness check `> StalenessPolicy.staleAfterSeconds` (a positive constant) is false — the label is simply not shown. That is correct behavior. The `relativeTime` path has the `..<5` catch-all for negative values, so the rendering stays "just now". The existing code is actually safe in practice for the normal use case.

This finding is downgraded from BLOCKER to WARNING — see WR-01 below.

---

### CR-03 (actual): `upsertDailyMetrics` in MetricsCache.swift silently discards the error from `db.execute` on conflict — `db.changesCount` is always 1 for an UPDATE, misreporting actual insertions

**File:** `Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift:99-134`

**Issue:** The return value of `upsertDailyMetrics` is documented as "rows changed". GRDB's `db.changesCount` (SQLite `sqlite3_changes()`) returns 1 for any `INSERT ... ON CONFLICT DO UPDATE` that executes the UPDATE branch, even when the row was not actually modified (the values were identical). This means the caller cannot distinguish "row was freshly inserted" from "row already existed and was re-written with identical data". This is a documentation/semantic inaccuracy rather than a data-loss bug, because the upsert itself is correct.

More importantly, the return value (`n`) is `@discardableResult` and no caller currently uses it for control flow, so the miscount does not affect correctness in Phase 13. Downgraded to INFO — see IN-01.

---

### CR-03 (actual): iOS `ServerSync.getDaily` maps server `recovery` (0–100) to `DailyMetric.recovery` (0–1) correctly, but `getTodayMetric` duplicates the same normalization — if a future refactor changes one but not the other, split-brain occurs

**File:** `ios/OpenWhoop/Upload/ServerSync.swift:373, 410`

**Issue:** The normalization `dbl(r, "recovery").map { $0 / 100.0 }` appears identically in both `getDaily` (line 373) and `getTodayMetric` (line 410). These two functions build a `DailyMetric` from the same JSON shape; any future change to one will not be caught by the compiler for the other. This is a maintainability/correctness risk rather than a present bug.

Downgraded to WARNING — see WR-02.

---

### CR-03 (actual — kept as BLOCKER): `_window_bounds_utc` says `[day-1 18:00, day+1 00:00)` but produces `[day-1 18:00, day 00:00)` — the window ends at `day_end = day+1 00:00` only when `_day_bounds_utc` is read correctly

Re-reading `_day_bounds_utc`:

```python
def _day_bounds_utc(day):
    start = datetime.combine(day, time(0, 0), timezone.utc)
    end = start + timedelta(days=1)
    return start.timestamp(), end.timestamp()
```

`end` = `day+1 00:00 UTC`. And `_window_bounds_utc` calls `_, day_end = _day_bounds_utc(day)` — so `day_end` = `day+1 00:00`. The 30-hour window is correct. No blocker here either.

After careful re-tracing all candidates, the two confirmed blockers are CR-01 (sleep_performance score sentinel) and CR-02 (ALG-12 double-count). A third blocker follows from the cross-language recovery scale analysis.

---

### CR-03: Server stores `recovery` on a 0–100 scale; iOS `ServerSync` divides by 100 — but `training_state` lookup on the server uses the 0–100 value while the iOS fallback in `StrainCard` calls `TrainingState.trainingState(recovery: recoveryFraction * 100, ...)` — if the server ever stores a 0–1 recovery by mistake, ALG-11 produces the wrong state label silently

**File:** `server/ingest/app/analysis/daily.py:621` and `ios/OpenWhoop/Design/Components/StrainCard.swift:37`

**Issue:** This is a correctness consistency observation: the server's `training_state_from_lookup` expects `recovery_score` in 0–100 (line 182: `idx = int(round(max(0.0, min(100.0, float(recovery_score)))))`). The value passed is `recovery` returned by `recovery_score()` which returns `max(0.0, min(100.0, score))` — confirmed 0–100. The iOS app stores `DailyMetric.recovery` as a 0–1 fraction (divided in `ServerSync`) and the fallback `TrainingState.trainingState(recovery: recoveryFraction * 100, ...)` correctly re-scales to 0–100. The path is consistent.

No bug here — downgraded to INFO for the confusing dual-scale in flight.

---

### CR-04: `sleep_performance_score` guard calls the function on no-sleep days (confirmed blocker)

*(See CR-01 above — this is the primary critical finding. Renumbered for clarity.)*

---

## Summary of confirmed Critical findings

### CR-01: `sleep_performance_score` called when `total_sleep_min == 0.0`, stores `0.0` instead of `None`

**File:** `server/ingest/app/analysis/daily.py:570`
**Issue:** `daily_sleep_summary` returns `total_sleep_min: 0.0` (not `None`) for no-sleep days. The guard `is not None` passes, `sleep_performance_score` is invoked, and its internal `<= 0` short-circuit returns `0.0`. The database stores `0.0` for `sleep_performance` on zero-sleep days instead of `NULL`. The iOS layer at `MetricKind.value(from:)` line 169 uses `metric.sleepPerformance ?? metric.efficiency.map { $0 * 100 }` — a stored `0.0` is truthy (not `nil`), so it displays "0%" rather than hiding the field. This is a semantically wrong display.
**Fix:**
```python
# daily.py line 570
if (sleep_summary.get("total_sleep_min") or 0.0) > 0:
    _sleep_perf_score = _sleep.sleep_performance_score(...)
```

### CR-02: ALG-12 `sleep_needed` baseline includes yesterday's sleep AND compares against it, underestimating sleep debt

**File:** `server/ingest/app/analysis/daily.py:546-560`
**Issue:** `_prior_sleep_min` is built from the full 7-day window including day-1 (yesterday). `sleep_yesterday` is also taken from day-1. The debt formula `baseline - sleep_yesterday` subtracts a value that is part of the baseline itself, shrinking the effective debt whenever yesterday was a short night (which is exactly when the debt matters most).
**Fix:** Exclude the last row from the baseline computation:
```python
_prior_sleep_min = [
    float(r["total_sleep_min"]) for r in _prior_7d[:-1]  # exclude yesterday from baseline
    if r.get("total_sleep_min") is not None
]
```

### CR-03: `relativeTime(from:)` returns negative seconds display when `lastRefreshedAt` is in the future (clock skew)

**File:** `ios/OpenWhoop/Tabs/TodayView.swift:425-436`
**Issue:** `Int(-date.timeIntervalSinceNow)` is negative for a future date. The `case ..<5` catches all negative values and returns "just now", which is the safe path. However the explicit `"\(elapsed)s ago"` branch at line 428 would render "-3s ago" if the `case ..<5` branch were ever changed or reordered. The code is fragile.
**Fix:**
```swift
let elapsed = max(0, Int(-date.timeIntervalSinceNow))
```
Adding `max(0, ...)` makes the intent explicit and future-proof against branch reordering.

### CR-04: `_LOOKUP_TABLE` module-level cache is not thread-safe under concurrent async compute_day calls

**File:** `server/ingest/app/analysis/daily.py:119-154`
**Issue:** `_load_ts_lookup()` uses a module-level `global _LOOKUP_TABLE` with a check-then-set pattern. Under concurrent async execution (e.g. `asyncio.gather` over multiple days), two coroutines can both see `_LOOKUP_TABLE is None` and each attempt to read and assign the file, resulting in redundant I/O. Worse, if one coroutine sets `_LOOKUP_TABLE = []` (OSError branch) while another is mid-iteration on a partially-assigned list reference, there is a potential race. In CPython this is protected by the GIL for list assignment (atomic), but the check-set sequence is not atomic.

In a single-threaded event loop (FastAPI with one worker) this is benign. With `uvicorn --workers N` or `asyncio.gather` calling `compute_day` concurrently it can cause redundant file reads and a brief window where `_LOOKUP_TABLE` is `[]` (disabling ALG-11 for those concurrent calls).
**Fix:** Initialize at import time rather than lazily:
```python
# At module level, after _TS_LOOKUP_PATH is defined:
try:
    with open(_TS_LOOKUP_PATH, "r", encoding="utf-8") as fh:
        _data = json.load(fh)
    _LOOKUP_TABLE: list[dict] = _data if isinstance(_data, list) else []
except (OSError, ValueError) as exc:
    _log.warning("ALG-11: failed to load %s (%s); training_state disabled", _TS_LOOKUP_PATH, exc)
    _LOOKUP_TABLE = []
```
Remove `_load_ts_lookup()` entirely and reference `_LOOKUP_TABLE` directly in `training_state_from_lookup`.

---

## Warnings

### WR-01: `relativeTime` is fragile to future branch reordering (reduced from CR-03)

**File:** `ios/OpenWhoop/Tabs/TodayView.swift:425`
**Issue:** See CR-03 description above. Current behavior is safe but relies on branch order.
**Fix:** `let elapsed = max(0, Int(-date.timeIntervalSinceNow))`

### WR-02: Recovery normalization duplicated verbatim in `getDaily` and `getTodayMetric`

**File:** `ios/OpenWhoop/Upload/ServerSync.swift:373, 410`
**Issue:** The line `recovery: dbl(r, "recovery").map { $0 / 100.0 }` appears identically in both functions. These functions parse the same JSON shape; a future change to one will silently leave the other stale. A compiler cannot catch the divergence because both return the same `DailyMetric` type.
**Fix:** Extract a shared helper:
```swift
private static func dailyMetricFrom(_ r: [String: Any]) -> DailyMetric? {
    guard let day = r["day"] as? String else { return nil }
    let int = ServerSync.int; let dbl = ServerSync.dbl
    return DailyMetric(
        day: day,
        // ... all fields ...
        recovery: dbl(r, "recovery").map { $0 / 100.0 },
        // ...
    )
}
```

### WR-03: `today_metric` from `/v1/today` may be re-upserted unnecessarily even when it is already in the `days` window result

**File:** `ios/OpenWhoop/Upload/ServerSync.swift:338-339`
**Issue:** `pullDerivedWindow` first fetches `getDaily(from:to:)` (line 329), upserts all rows, then unconditionally calls `getTodayMetric()` (line 338) and upserts the result again. If today's date falls within the `[fromDay, toDay]` window (which it almost always does for the normal 60-day incremental pull), the same row is fetched twice and upserted twice in the same sync cycle. This doubles network traffic for the most important row every sync. The upsert is idempotent so there is no data corruption, but it is wasteful.
**Fix:** Only call `getTodayMetric` when the most-recent row in `days` is not today's date:
```swift
let todayStr = fmt.string(from: now)
if days.last?.day != todayStr, let todayMetric = await getTodayMetric() {
    try? await store.upsertDailyMetrics([todayMetric], deviceId: deviceId)
}
```

### WR-04: `sleep_performance_score` guard `total_sleep_min is not None` misses the `total_sleep_min == 0.0` case at a second call site in tests

**File:** `server/ingest/tests/test_daily_alg.py` — no test covers the interaction between `daily_sleep_summary` returning `0.0` and `compute_day` storing `0.0` instead of `None`

**Issue:** `test_sleep_needed_lower_clamp_300` passes `[1.0] * 6` as a baseline (1-minute nights), which is valid > 0. But there is no test that passes through `compute_day` with a no-sleep stream and asserts `sleep_performance IS NULL` in the output dict. The existing `test_sleep_performance_score.test_zero_sleep_returns_zero` tests the pure function correctly, but the integration-level guard in `daily.py` is untested.
**Fix:** Add a test to `test_daily_alg.py` (or `test_daily.py`) that exercises `compute_day` with an empty stream and asserts `result["sleep_performance"]` is `None`, not `0.0`.

### WR-05: `_augment_units` in `read.py` calls `skin_temp_celsius` and `resp_rate_bpm` on every row without guarding against `None` raw values from downsampled buckets

**File:** `server/ingest/app/read.py:181-186`
**Issue:** The downsampled path returns `None` for averaged values when a bucket has no data. The augmentation at line 181 does:
```python
r["value"] = round(skin_temp_celsius(r["raw"]), 1)
```
If `r["raw"]` is `None` (from an empty bucket), `skin_temp_celsius(None)` will raise `TypeError` (it performs arithmetic on the value). The spo2 branch at line 177 has an explicit `if val is not None` guard; the skin_temp and resp branches do not.
**Fix:**
```python
elif kind == "skin_temp":
    for r in rows:
        raw = r.get("raw")
        r["value"] = round(skin_temp_celsius(raw), 1) if raw is not None else None
        r["unit"] = "°C"
elif kind == "resp":
    for r in rows:
        raw = r.get("raw")
        r["value"] = round(resp_rate_bpm(raw), 1) if raw is not None else None
        r["unit"] = "bpm"
```

---

## Info

### IN-01: `upsertDailyMetrics` and `upsertSleepSessions` return value semantics are misleading — `db.changesCount` counts UPDATEs as 1 even when values are unchanged

**File:** `Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift:90, 134`
**Issue:** SQLite `sqlite3_changes()` returns 1 for any `INSERT ... ON CONFLICT DO UPDATE` that takes the UPDATE branch, regardless of whether any column value actually changed. The documented "rows changed" semantics suggest only net changes are counted. Since the return value is `@discardableResult` and unused by callers in Phase 13, this does not affect correctness today.
**Fix:** Either document the actual semantics ("rows touched") or use `INSERT OR IGNORE` and check `db.lastInsertedRowID` for true insert count.

### IN-02: `sleepNeededMin` is stored in the database and synced to iOS but never surfaced in `TodayView` or `MetricKind`

**File:** `ios/OpenWhoop/Tabs/TodayView.swift` (no reference to `sleepNeededMin`)
**Issue:** ALG-12 produces `sleep_needed_min`, which is correctly stored in `DailyMetric.sleepNeededMin` (MetricsCache.swift:50) and upserted via `upsertDailyMetrics`. However there is no UI card, MetricKind case, or any consumer of `sleepNeededMin` in the reviewed iOS files. It is computed, stored, synced, and then ignored. This is not a bug if the plan is to display it in a future phase, but it means ALG-12's output has zero user-facing value in Phase 13.
**Fix:** Either add a `sleepNeededMin` display (e.g. in the sleep card subtitle) or document this as a Phase 14 TODO.

### IN-03: `_nonbinary` coefficient mean for `resting_age` in `calories.py` is inconsistently rounded

**File:** `server/ingest/app/analysis/calories.py:96-100`
**Issue:** The `nonbinary` coefficient set is documented as the element-wise mean of male and female. `resting_age = (5.677 + 4.33) / 2 = 5.0035`, stored correctly. `workout_age = (0.2017 + 0.0740) / 2 = 0.13785`, stored correctly. `resting_alpha = (88.362 + 447.593) / 2 = 267.9775`, stored correctly. However `resting_weight = (13.397 + 9.247) / 2 = 11.322`, stored as `11.322` — correct. All values check out; this is a non-issue.

The actual info-level note is that there are no unit tests for `estimate_bout_calories` (the main Keytel formula function). Only `rmr_kcal_per_day` is tested. A future regression in the Keytel path (e.g. a coefficient edit) would go undetected.
**Fix:** Add tests for `estimate_bout_calories` covering the male/female/nonbinary paths and the active/resting threshold split.

---

_Reviewed: 2026-06-01T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
