---
phase: 05-ios-app-server-port
fixed_at: 2026-05-31T00:00:00Z
review_path: .planning/phases/05-ios-app-server-port/05-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 05: Code Review Fix Report

**Fixed at:** 2026-05-31
**Source review:** `.planning/phases/05-ios-app-server-port/05-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: Comparacao de token de autenticacao nao protegida contra timing attacks

**Files modified:** `server/ingest/app/main.py`
**Commit:** c0b7d55
**Applied fix:** Added `import secrets` (stdlib) to the import block. Changed
`require_auth` to use `secrets.compare_digest(authorization, expected)` instead
of `authorization != expected`. The comparison now runs in constant time
regardless of where the strings first diffe.

---

### CR-02: RR intervals emitidos com timestamp None em extract_streams (Python)

**Files modified:** `server/packages/whoop-protocol/whoop_protocol/interpreter.py`
**Commit:** 13f10ce
**Applied fix:** In `extract_streams` (REALTIME_DATA block, ~line 354) and in
`extract_historical_streams` (REALTIME_RAW_DATA block, ~line 428), moved the
`for rr in p.get("rr_intervals", [])` loop inside the `if ts is not None` guard.
RR rows are now only emitted when a valid wall-clock timestamp is available,
preventing `{ts: None, rr_ms: ...}` rows from reaching the database and violating
the `ts TIMESTAMPTZ NOT NULL` schema constraint.

---

### CR-03: Detecao GET_DATA_RANGE incompativel com frames Maverick 5.0

**Files modified:** `ios/OpenWhoop/BLE/BLEManager.swift`
**Commit:** 2dc8c9c
**Applied fix:** In `didUpdateValueFor` (~line 844), replaced the hard-coded
`frame[6]` command-byte check with a Maverick-aware offset calculation that
mirrors the existing `isOffloadFrame` pattern. For Maverick frames
(`frame[1] == 0x01`) the command byte is at offset 10; for 4.0 frames it
remains at offset 6. This ensures GET_DATA_RANGE responses from WHOOP 5.0
straps are correctly detected and `strapNewestTs` is updated, keeping the
liveness watchdog functional on 5.0 hardware.

---

_Fixed: 2026-05-31_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
