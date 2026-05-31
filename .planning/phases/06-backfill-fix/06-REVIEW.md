---
phase: "06"
status: warning
depth: standard
files_reviewed: 3
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
reviewed_at: "2026-05-31"
---

# Code Review — Phase 06: Backfill Fix

**Depth:** standard  
**Files reviewed:** 3  
**Findings:** 0 Critical, 2 Warning, 3 Info

---

## Files Reviewed

- `ios/OpenWhoop/BLE/BLEManager.swift`
- `ios/OpenWhoop/Collect/Backfiller.swift`
- `ios/OpenWhoopTests/BackfillerTests.swift`

---

## Findings

### WR-01 — ffExchangeTimeout not cancelled on disconnect

**File:** `ios/OpenWhoop/BLE/BLEManager.swift`  
**Severity:** Warning  
**Category:** Resource Leak / Correctness

The 15s `ffExchangeTimeout` watchdog is armed in `runConnectHandshake()` and cancelled in `setFFValues()`. However, if the strap disconnects before `setFFValues()` is called (i.e., the FF exchange never completes), the watchdog DispatchWorkItem remains in-flight. When it fires after disconnect, `self.requestSync(.connect)` will be called on a disconnected BLEManager — this may be a no-op in practice (BackfillPolicy guards will reject it), but it is a potential dangling-reference hazard and wastes a timer slot.

The existing `backfillTimeout` is explicitly cancelled in `exitBackfilling()` on disconnect. `ffExchangeTimeout` should receive the same treatment at the disconnect/cleanup callsite (wherever `backfillTimeout?.cancel()` is already called, e.g. `exitBackfilling()` or the CBCentralManagerDelegate disconnect handler).

**Suggested fix:** Add `ffExchangeTimeout?.cancel(); ffExchangeTimeout = nil` alongside the existing `backfillTimeout?.cancel()` calls at all disconnect paths.

---

### WR-02 — testKillMidAckPreservesDataOnReconnect: acks1 assertion is fragile

**File:** `ios/OpenWhoopTests/BackfillerTests.swift`  
**Severity:** Warning  
**Category:** Test Correctness

In `testKillMidAckPreservesDataOnReconnect`, Session 1 sets `store.setCursorShouldThrow = true`. The test then asserts `XCTAssertEqual(acks1, [])` — but `ackTrim` is only called after `setCursor` succeeds. When `setCursor` throws, the early-return in `finishChunk` correctly prevents `ackTrim` from being called, so the assertion passes. However, this works because `ackTrim` is called _after_ `setCursor` — if the order were ever swapped (e.g. to confirm ack-before-persist), this test would silently pass regardless and not catch the regression.

The test intent is "cursor must not advance when setCursor throws". The cursor assertion `XCTAssertNil(store.cursors["strap_trim"])` correctly captures this. The `acks1 == []` assertion is correct but incidental — add a comment making this explicit so reviewers understand it tests the ack-after-setCursor ordering contract, not just the empty-array outcome.

**Suggested fix:** Add a comment: `// ackTrim is not called because setCursor threw first — verifies ackTrim is downstream of setCursor in finishChunk`

---

### INFO-01 — firstChunkUnix/lastChunkUnix not reset on `.start` in ingest()

**File:** `ios/OpenWhoop/Collect/Backfiller.swift`  
**Severity:** Info  
**Category:** State Management

`begin()` resets `firstChunkUnix` and `lastChunkUnix`, and `timeoutFired()` resets them too. However, the `.start` case in `ingest()` does not reset them. The `begin()` contract says the chunk is already "open" from the start, so a START frame mid-session re-opens the chunk but does not reset the range tracking. This is intentional for multi-START sessions (high-freq-sync), but means the range accumulates across all chunks in a session, which is the correct semantic. No bug — but worth documenting.

**Note:** The current behavior is actually correct: `firstChunkUnix` tracks the first chunk ever seen in a session (set once across all chunks), and `lastChunkUnix` tracks the most recent. The `.start` case should NOT reset these because the range spans the entire session, not individual chunks. Consider adding a comment to `.start` case: `// Range tracking NOT reset here — firstChunkUnix/lastChunkUnix span the entire session across multiple STARTs`

---

### INFO-02 — backfillerLogger uses file-scope let (minor stylistic note)

**File:** `ios/OpenWhoop/Collect/Backfiller.swift`  
**Severity:** Info  
**Category:** Code Style

`private let backfillerLogger = Logger(...)` is a file-scope constant rather than a static property on `Backfiller`. Both are correct; a `private static let logger` inside the class would be more idiomatic Swift (aligning with `BLEManager.logger` pattern) and would make the ownership clear. This is purely stylistic — no correctness impact.

---

### INFO-03 — ffExchangeTimeout deadline uses integer literal (minor)

**File:** `ios/OpenWhoop/BLE/BLEManager.swift`  
**Severity:** Info  
**Category:** Code Quality

`DispatchQueue.main.asyncAfter(deadline: .now() + 15, ...)` uses a bare integer `15` where `15.0` (Double) would be more explicit. Swift infers Double here correctly, so there is no bug. The PLAN.md specified `15.0` for clarity — the code uses `15` which is equivalent but slightly less readable alongside other timeout values that may use `Double` literals. Minor nit only.

---

## Summary

The core changes are **correct and well-structured**. The FF exchange race condition fix follows the established `backfillTimeout` pattern closely. The new guard in `beginBackfill()`, the event-driven chain in `setFFValues()`, and the watchdog all work together correctly.

The primary actionable finding (WR-01) is that the `ffExchangeTimeout` watchdog should be cancelled on disconnect alongside `backfillTimeout`. This is a low-risk but real resource leak that could cause a spurious `requestSync(.connect)` call after disconnect.

The test suite additions are solid — they correctly model the safe-trim invariant scenarios and use the existing SpyBackfillStore without modifications.

**Recommendation:** Fix WR-01 before the next phase. WR-02 and the Info findings are optional cleanup.
