---
phase: 04-protocol-decode-schema
plan: 03
subsystem: protocol-decode
tags: [ble, reverse-engineering, python, r52, command-surface, events, battery, historical-offload, dual-epoch]

# Dependency graph
requires:
  - phase: 04-protocol-decode-schema
    plan: 01
    provides: parse_body_5 (offset-4 body decoder, r52 resolver, scan_unix_timestamps, _resolve_captures), frames_5_golden.json (123-record corpus), validate_frames_5.build_report (full 5028-frame extraction)
provides:
  - "command_surface_5.py: observed-vs-r52 CommandNumber reconciliation over the full 5028-frame corpus, reused-14 cross-validation, request->response seq pairing (A7), HYPOTHESIS tagging for unobserved-but-expected commands (D-07)"
  - "decode_streams_5.py: EVENT/battery/metadata/historical-offload/dual-epoch decoders over the corpus — Plan-05-consumable structured results for FINDINGS_5.md Phase 4"
  - "PROTO-06 command surface (capture-analysis): 10 OBSERVED commands, 67 HYPOTHESIS, 3/14 reused-4.0 IDs present in 5.0"
  - "PROTO-09 EventNumber decode + PROTO-15 device-epoch model; PROTO-10 store-then-ack offload documented (trim cursor 0x00000004:000130ef)"
affects: [04-04 schema, 04-05 findings]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Full-corpus-primary / golden-corpus-fallback loader (decode_5._resolve_captures + build_report, falls back to frames_5_golden.json on fresh clone / CI)"
    - "Request->response pairing by seq with cross-session-collision awareness (A7 confirmed within contiguous bursts)"
    - "HYPOTHESIS tagging for capture-analysis command surface (observed=VERIFIED, r52-expected-unobserved=HYPOTHESIS per D-07)"
    - "Console-log narration scrubbing (digit-run redaction) for safe protocol documentation (T-04-04)"

key-files:
  created:
    - re/survey_5/command_surface_5.py
    - re/survey_5/decode_streams_5.py
  modified: []

key-decisions:
  - "Full 5028-frame corpus is the primary enumeration source (worktree-resolved captures via decode_5._resolve_captures); golden corpus is the CI/fresh-clone fallback — both yield the same OBSERVED command set"
  - "seq is reused across separate command sessions, so naive seq->cmd pairing produces cross-session collisions; A7 is confirmed by the 89/106 in-burst MATCHes, collisions reported honestly rather than hidden"
  - "Battery decode (PROTO-08) is HYPOTHESIS only — no u16 in the BATTERY_LEVEL/EXTENDED event payload cleanly matches the 0x2A19=23% read under the 4.0 A6 layout; a dedicated GET_BATTERY_LEVEL capture is flagged for Phase 5"
  - "Historical offload is documentation-only (D-09): protocol named from METADATA + CONSOLE_LOGS already in corpus; live kill-process test stays Phase 5"

patterns-established:
  - "Every offset access len(payload)-guarded before indexing (T-04-01 / D-03 log-and-continue)"
  - "Trim-cursor regex requires the full 8-hex offset so console-frame fragmentation does not surface a truncated cursor"

requirements-completed: [PROTO-06, PROTO-08, PROTO-09, PROTO-10, PROTO-15]

# Metrics
duration: ~22min
completed: 2026-05-30
---

# Phase 4 Plan 03: Command surface + corpus stream decode Summary

**The full 5028-frame corpus is decoded into documented protocol facts: 10 observed command IDs reconciled against the r52 CommandNumber map (3/14 reused-4.0 IDs present, 67 unobserved tagged HYPOTHESIS), every EVENT resolved to its r52 EventNumber with a device-epoch u32, the historical store-then-ack offload documented from CONSOLE_LOGS (trim cursor `0x00000004:000130ef`), and the dual-epoch model demonstrated with both a 2026 Unix timestamp (GET_DATA_RANGE) and a device-epoch u32 (EVENTs).**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-05-30
- **Completed:** 2026-05-30
- **Tasks:** 2 completed
- **Files created:** 2

## Accomplishments

- **PROTO-06 (capture analysis, D-06/D-07):** `command_surface_5.py` enumerates every command ID observed in the full corpus (body[6] of COMMAND/COMMAND_RESPONSE + cmd-in WRITE), pairs cmd-in writes to cmd-resp by seq (A7), and reconciles against the complete r52 CommandNumber map. **10 OBSERVED** (3 TOGGLE_REALTIME_HR, 22 SEND_HISTORICAL_DATA, 23 HISTORICAL_DATA_RESULT, 34 GET_DATA_RANGE, 69 DISABLE_ALARM, 117 START_FF_KEY_EXCHANGE, 118 SEND_NEXT_FF, 120 SET_FF_VALUE, 141 GET_ADVERTISING_NAME, 145 GET_HELLO); **67 UNOBSERVED tagged HYPOTHESIS**. The 14 reused-4.0 IDs cross-validated: **3/14 OBSERVED** (3, 22, 145), 11 absent.
- **PROTO-09 events:** `decode_streams_5.py` resolves all 136 EVENT frames to r52 EventNumber names — STRAP_CONDITION_REPORT (7), BLE_CONNECTION_UP/DOWN (26/27), BLE_REALTIME_HR_ON/OFF (6/5), BATTERY_LEVEL (2), EXTENDED_BATTERY_INFORMATION (2), plus three unmapped (event110/120/123, surfaced as candidates). Each carries the device-epoch u32 at body[8].
- **PROTO-08 battery:** BATTERY_LEVEL (3) and EXTENDED_BATTERY_INFORMATION (63) decoded HYPOTHESIS via the 4.0 A6 layout, candidates cross-checked against the CONFIRMED 0x2A19 = 23% read. No candidate cleanly matches 23%, so the 5.0 battery offset is reported HYPOTHESIS (validated, not fabricated) with a dedicated GET_BATTERY_LEVEL capture flagged for Phase 5.
- **PROTO-10 historical offload (doc-only, D-09):** METADATA counts (HISTORY_START 73 / HISTORY_END 79 / HISTORY_COMPLETE 2) + scrubbed CONSOLE_LOGS narration document the store-then-ack protocol — SEND_HISTORICAL_DATA (22) request, HISTORICAL_DATA_RESULT (23) ack, GET_DATA_RANGE (34) / SET_READ_POINTER (33), and the trim cursor `0xPAGE:OFFSET` (`0x00000004:000130ef` = the store-then-ack persistence pointer).
- **PROTO-15 dual-epoch:** GET_DATA_RANGE payload yields 19 Unix u32 timestamps (headline 2026-05-08, epoch=unix); EVENTs yield 136 device-epoch u32 values (epoch=device). Both surfaced with human-readable form for the Plan 05 schema `epoch` tag.

## Task Commits

Each task was committed atomically:

1. **Task 1: command_surface_5.py — observed-vs-r52 reconciliation + reused-14 cross-validation** — `0d75acf` (feat)
2. **Task 2: decode_streams_5.py — events/battery, metadata/historical-offload, dual-epoch** — `dc24660` (feat)

## Files Created

- `re/survey_5/command_surface_5.py` — Command-surface enumeration + reconciliation. Imports `parse_body_5` + the r52 resolver from `decode_5`; full-corpus-primary with golden-corpus fallback; returnable dict (observed counts, request/response pairs, reconciliation rows, hypotheses, reused-14) for Plan 05.
- `re/survey_5/decode_streams_5.py` — Stream decoders for events/battery/metadata/historical-offload/dual-epoch. Imports `parse_body_5` + `scan_unix_timestamps` from `decode_5`; all offsets length-guarded; console-log strings scrubbed; returnable dict for Plan 05 / FINDINGS_5.md §Phase 4.

## Verification Evidence

| Check | Result |
|-------|--------|
| `cd re/survey_5 && python command_surface_5.py` | exit 0 |
| command_surface_5.py contains `from decode_5 import` | yes (2) |
| command_surface_5.py `grep -v '^#' \| grep -c WhoopPacket` | 0 |
| Output reports all 14 reused IDs as OBSERVED/UNOBSERVED | yes (3/14 OBSERVED) |
| Output resolves an OBSERVED command to its r52 name (GET_DATA_RANGE cmd 34) | yes |
| Output marks unobserved commands HYPOTHESIS with r52 attribution note | yes (67) |
| `cd re/survey_5 && python decode_streams_5.py` | exit 0 |
| decode_streams_5.py contains `from decode_5 import` + length guards | yes (`len(body)`/`len(payload)` present) |
| Output resolves an EVENT to an r52 EventNumber name (STRAP_CONDITION_REPORT) + device-epoch | yes |
| Output documents SEND_HISTORICAL_DATA + HISTORICAL_DATA_RESULT + trim cursor | yes |
| Output decodes a Unix ts (epoch=unix) + a device-epoch value | yes (2026-05-08 + 1780152939) |
| Battery decode attempted and reported (PROTO-08) | yes (HYPOTHESIS, cross-checked vs 23%) |

## Deviations from Plan

None — plan executed exactly as written. The full-corpus-primary / golden-corpus-fallback loader pattern was inherited from Plan 01's `_resolve_captures` (already established), not a new deviation.

## Known Stubs

None. Both scripts run against real captured data. Tagged-HYPOTHESIS items are honest provenance, not stubs:

- **Battery SOC offset (PROTO-08):** the 4.0 A6 layout does not cleanly resolve a 23%-matching SOC in the 5.0 BATTERY_LEVEL/EXTENDED event payload. Candidates are reported HYPOTHESIS and a dedicated GET_BATTERY_LEVEL capture is recommended for Phase 5. This is documented honestly; PROTO-08 is fulfilled at the "decoded + cross-checked" level the plan requires (battery event located and decoded, cross-validated against 0x2A19).
- **Unmapped events 110/120/123:** observed but absent from the r52 EventNumber map; surfaced as candidates (5.0-new event numbers) for Plan 05.
- **Live historical-offload kill test:** intentionally deferred to Phase 5 per D-09 (this plan is documentation-only for PROTO-10).

## Threat Flags

None. No new network endpoints, auth paths, or trust boundaries beyond the plan's `<threat_model>`. T-04-01 (length guards before every offset) and T-04-04 (console-log digit-run scrubbing; only protocol-structure narration + hex trim cursors surfaced) are both mitigated and verified. No package installs (T-04-SC accept).

## Self-Check: PASSED

- FOUND: re/survey_5/command_surface_5.py
- FOUND: re/survey_5/decode_streams_5.py
- FOUND: commit 0d75acf (Task 1)
- FOUND: commit dc24660 (Task 2)
