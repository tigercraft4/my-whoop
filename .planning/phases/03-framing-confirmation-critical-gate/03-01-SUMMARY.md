---
phase: 03-framing-confirmation-critical-gate
plan: 01
subsystem: re-tooling
tags: [ble, reverse-engineering, framing, crc, maverick-wrapper, tshark]
requires:
  - "re/capture/samples/*.pklg (Phase 1 + Phase 2 captures, gitignored)"
  - "tshark 4.6.6, python 3.11 (re/survey_5/.venv)"
provides:
  - "re/survey_5/validate_frames_5.py — 4.0 CRC gate + parse_maverick/strip_maverick + golden writer"
  - "re/survey_5/frames_5_golden.json — wrapper-stripped Phase 4 decode corpus (hex-first)"
  - "strip_maverick(frame) -> flat body (PROTO-05 working code)"
  - "Documented 0.0% 4.0-CRC pass rate (PROTO-04 negative result)"
affects:
  - "Phase 4 (decode) — consumes frames_5_golden.json + imports/inlines strip_maverick"
  - "Phase 5 (Swift) — Framing.swift ports the wrapper-strip step"
tech-stack:
  added: []
  patterns:
    - "tshark -T fields -e btatt.handle -e btatt.value extraction (RESEARCH Pattern 1)"
    - "Maverick wrapper [AA][01][len u16 LE][role]...body...[trailer 4B], total = len + 8"
    - "Pure bytes->bytes strip_maverick (no nested 0xAA frame — flat body)"
    - "hex-first golden fixture mirroring 4.0 frames.json (D-02c)"
key-files:
  created:
    - "re/survey_5/validate_frames_5.py"
    - "re/survey_5/frames_5_golden.json"
    - "re/survey_5/test_validate_frames_5.py"
  modified: []
decisions:
  - "Curated golden corpus to <=15 entries/handle (46 total) instead of dumping all 5028 frames — keeps the committed fixture small (21 KB vs 3.5 MB) and minimises committed protocol bytes (RESEARCH Pitfall 5), while exceeding the >=20 / multi-characteristic requirement"
  - "TDD test written as a plain assertion-based runnable script (no pytest) matching the re/ test_*.py convention — avoids adding a dependency"
metrics:
  duration: ~25m
  completed: 2026-05-30
  tasks: 2
  files: 3
---

# Phase 3 Plan 01: Framing Confirmation Critical Gate Summary

Built `validate_frames_5.py` — the critical-gate validator that documents the 4.0 CRC gate as a 0.0% negative on 5028 captured frames (PROTO-04), implements a working `strip_maverick()` that strips the confirmed 4-byte Maverick header + 4-byte trailer to the flat body (PROTO-05), and writes a curated 46-entry `frames_5_golden.json` corpus spanning all four custom characteristics for Phase 4.

## What Was Built

**Task 1 — pure framing functions (TDD):**
- `crc8()` — bitwise poly-0x07 table, cross-checked against `Framing.swift:crc8Table` (`crc8(b"\x08")==0x38`, `crc8(b"\x08\x00")==0xa8`).
- `verify_4_0(frame) -> (crc8_ok, crc32_ok)` — runs BOTH CRC8 (poly 0x07 over `frame[1:3]`) and CRC32-LE (`zlib.crc32 & 0xFFFFFFFF` over `frame[4:length]`) per D-02b. Uses the intentionally-wrong 4.0 `frame[1:3]` length offset to document the gate. Returns `(False, False)` on every 5.0 frame.
- `parse_maverick(frame)` — validates `len(frame) == length + 8`, `frame[0]==0xAA`, `frame[1]==0x01`; returns `{length, role, body, trailer}` or `None`.
- `strip_maverick(frame) -> bytes` — pure `frame[4:4+length]` (flat body) or `b""`. Docstring documents field offsets and that there is **NO nested 0xAA frame** (Finding 5 / A2).
- `reassemble()` — 0xAA SOF-filter pass-through adapted from `re/decode.py`.

**Task 2 — extraction + report + corpus:**
- `extract_frames()` — `tshark -Y btatt.value -T fields` over both captures (D-01 two sessions), filtered to aa-SOF + the four custom handles (Pitfall 4).
- D-01b fallback present: prints `Fallback: no existing captures yielded >=20 frames` + runbook pointer + exits non-zero when `<20` frames.
- Per-characteristic breakdown (CRC8/CRC32/wrapper counts, example hex), aggregate `0.0%` CRC pass line, `Maverick wrapper: CONFIRMED` verdict.
- `frames_5_golden.json` — hex-first entries per D-02c (`hex, type, seq, cmd, payload, characteristic, handle, role, length, body_hex, trailer_hex, crc8_4_0_ok, crc32_4_0_ok`).

## Verified Results

| Check | Result |
|-------|--------|
| Frames extracted (2 sessions) | 5028 (155 cmd-in, 158 cmd-resp, 1 events, 4714 data) |
| 4.0 CRC gate pass rate | **0.0%** (0/10056 checks) — PROTO-04 documented negative |
| Wrapper len+8 invariant | **5028/5028 consistent** → `Maverick wrapper: CONFIRMED` |
| Golden corpus | 46 entries, hex-first, spans FD4B0002/03/04/05 |
| TDD self-test | 6/6 passed |

These reproduce the RESEARCH empirical findings exactly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed literal `whoomp` / `2026-05-30-ios.pklg` strings from explanatory comments**
- **Found during:** Task 1 / Task 2 acceptance grep checks.
- **Issue:** Initial docstring/comments mentioned the forbidden strings by name (to explain what NOT to do), which failed the acceptance greps requiring `grep -c` to return 0.
- **Fix:** Reworded the isolation/filename comments to describe the anti-patterns without the literal tokens.
- **Files modified:** `re/survey_5/validate_frames_5.py`
- **Commit:** 356b486 (Task 1), 537ad4e (Task 2)

**2. [Rule 2 - Curation] Capped golden corpus to 15 entries/handle (46 total) instead of all 5028**
- **Found during:** Task 2 (full dump produced a 3.5 MB JSON).
- **Issue:** Writing all 5028 wrapper-stripped frames produces an oversized committed artifact and over-commits raw protocol bytes (RESEARCH Pitfall 5). The plan's intent is a curated Phase-4 starting fixture (mirrors the small 4.0 `frames.json`), requiring only `>=20` entries across characteristics.
- **Fix:** `GOLDEN_PER_HANDLE_CAP = 15`; report stats still cover all 5028 frames. Result: 46 entries / 21 KB spanning all four characteristics.
- **Files modified:** `re/survey_5/validate_frames_5.py`, `re/survey_5/frames_5_golden.json`
- **Commit:** 537ad4e

## Environment Notes (not deviations)

- The `.pklg` captures and `re/survey_5/.venv` are gitignored, so they do not exist in the worktree. Verification ran against the main-repo captures via temporary symlinks (gitignored, removed after; never committed) using the main-repo venv python (3.11.15). The `frames_5_golden.json` output and the script itself are committable (not under `samples/`).

## TDD Gate Compliance

- RED: `331a1ab test(03-01)` — failing self-test (module absent).
- GREEN: `356b486 feat(03-01)` — implementation, 6/6 tests pass.
- REFACTOR: not needed.

## Commits

- `331a1ab` test(03-01): add failing self-test for validate_frames_5 functions
- `356b486` feat(03-01): implement validate_frames_5 CRC gate + Maverick wrapper parser
- `537ad4e` feat(03-01): wire tshark extraction + report + frames_5_golden.json corpus

## Self-Check

- `re/survey_5/validate_frames_5.py` — FOUND
- `re/survey_5/frames_5_golden.json` — FOUND
- `re/survey_5/test_validate_frames_5.py` — FOUND
- commit `331a1ab` — FOUND
- commit `356b486` — FOUND
- commit `537ad4e` — FOUND

## Self-Check: PASSED
