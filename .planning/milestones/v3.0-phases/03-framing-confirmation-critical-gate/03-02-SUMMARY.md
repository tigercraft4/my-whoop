---
phase: 03-framing-confirmation-critical-gate
plan: 02
subsystem: protocol
tags: [json-schema, gatt, ble, maverick-wrapper, whoop-5.0, firmware]

# Dependency graph
requires:
  - phase: 03-framing-confirmation-critical-gate
    provides: "RESEARCH Findings 4/5/6 (Maverick wrapper layout, flat body, trailer OPEN) + gatt-survey-5 evidence YAML (verified GATT UUIDs)"
provides:
  - "protocol/whoop_protocol_5.json v0 — canonical 5.0 schema envelope (framing + GATT + firmware), confidence-tagged"
  - "Single source of truth for 5.0 GATT UUIDs (service + 7 characteristics + legacy-ABSENT verdict)"
  - "Maverick outer wrapper layout (SOF/version/length@off2/role@off4/body/trailer)"
affects: [phase-04-body-decode, phase-05-swift-python-loaders]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Confidence-tagging every schema field (VERIFIED vs HYPOTHESIS/OPEN)"
    - "JSON schema mirrors 4.0 whoop_protocol.json top-level skeleton (version/enums/envelope/packets) for loader compatibility"
    - "GATT constants as committed single source of truth (not just markdown) per D-04b"

key-files:
  created:
    - "protocol/whoop_protocol_5.json"
  modified: []

key-decisions:
  - "version set to 0 (v0 envelope); enums/packets left as empty objects for Phase 4 to populate — no invented body field maps"
  - "envelope describes the Maverick OUTER WRAPPER (length at off 2, role at off 4), explicitly NOT the 4.0 inner frame"
  - "trailer entry tagged HYPOTHESIS with note that standard CRC16/CRC32 variants are ruled out (RESEARCH Finding 6)"
  - "GATT UUIDs and firmware (WG50_r52) copied verbatim from gatt-survey-5 evidence, all VERIFIED"

patterns-established:
  - "Confidence tags (VERIFIED/HYPOTHESIS/OPEN) on each envelope entry and on the gatt/firmware blocks"
  - "framing_notes + schema_note top-level prose fields document the wrapper invariant (total_len == length + 8) and v0 scope"

requirements-completed: [PROTO-05]

# Metrics
duration: 4min
completed: 2026-05-30
---

# Phase 3 Plan 02: whoop_protocol_5.json v0 Summary

**Canonical WHOOP 5.0 schema envelope authored: Maverick outer wrapper (length@off2/role@off4/flat body/4-byte trailer) plus verbatim GATT UUIDs and WG50_r52 firmware, every field confidence-tagged (VERIFIED vs HYPOTHESIS for the OPEN trailer checksum).**

## Performance

- **Duration:** ~4 min
- **Completed:** 2026-05-30
- **Tasks:** 1
- **Files modified:** 1 (created)

## Accomplishments
- Created `protocol/whoop_protocol_5.json` v0 mirroring the 4.0 top-level skeleton (`version`, `enums`, `envelope`, `packets`) so the Phase 5 `Schema.swift` / Python loaders stay compatible.
- Envelope describes the Maverick OUTER WRAPPER verified on 5028 frames: SOF (0xAA), version (0x01), length (u16-LE at off 2), role (off 4, 0x00=cmd-in/0x01=notify), flat body, 4-byte trailer.
- GATT block carries the verified single source of truth: service `FD4B0001-...`, 7 characteristics (cmd_in/cmd_resp/events/data/diagnostics + standard heart_rate/battery_level), and `legacy_61080001: ABSENT`.
- `firmware_revision: WG50_r52` recorded (source: Device Information 0x2A27), tagged VERIFIED.
- Confidence tags applied: VERIFIED for SOF/version/length/role/gatt/firmware; HYPOTHESIS for the trailer checksum (algorithm OPEN, standard CRC variants ruled out).

## Task Commits

Each task was committed atomically:

1. **Task 1: Author whoop_protocol_5.json v0 (framing + GATT + firmware, confidence-tagged)** - `7099f1f` (feat)

## Files Created/Modified
- `protocol/whoop_protocol_5.json` - v0 canonical 5.0 schema: Maverick wrapper envelope + GATT constants + firmware_revision, confidence-tagged.

## Decisions Made
- None beyond plan — followed the plan as specified. `version: 0`, empty `enums`/`packets` for Phase 4, wrapper layout per RESEARCH Finding 4, trailer HYPOTHESIS per Finding 6.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## Verification

Plan automated verify command output:
- `schema OK` (all asserts passed: version==0, service UUID, legacy ABSENT, firmware WG50_r52, trailer HYPOTHESIS, SOF VERIFIED)
- `length off = 2` (confirms wrapper layout, not 4.0 inner frame)
- `grep -c '"version"'` returned 2 (>= 1; top-level key present for Schema.swift loader compatibility)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- v0 schema committed and parseable; ready for Phase 4 to populate `enums`/`packets` body field maps.
- Trailer checksum algorithm remains OPEN (HYPOTHESIS) — documented, non-blocking for body decode (wrapper-strip exposes the flat body directly).

## Self-Check: PASSED

- FOUND: protocol/whoop_protocol_5.json
- FOUND: .planning/phases/03-framing-confirmation-critical-gate/03-02-SUMMARY.md
- FOUND commit: 7099f1f (Task 1, feat)
- FOUND commit: d51841a (SUMMARY, docs)

---
*Phase: 03-framing-confirmation-critical-gate*
*Completed: 2026-05-30*
