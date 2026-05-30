---
phase: 04-protocol-decode-schema
plan: 02
subsystem: re
tags: [packetlogger, tshark, ble, biometric-capture, evidence-sidecar, realtime-hr, imu, decode]

# Dependency graph
requires:
  - phase: 04-01
    provides: "decode_5.parse_body_5 (offset-4 body decoder) + validate_frames_5.build_report (tshark extraction + Maverick wrapper parse)"
  - phase: 02
    provides: "Finding that macOS Bleak cannot bond the 5.0 strap — capture must be a human PacketLogger session"
provides:
  - "D-05 targeted biometric capture (capture_all-V3.pklg, local-only) inventoried for Wave 3"
  - "Redacted evidence sidecar with firmware_revision (PROTO-16) and per-characteristic frame inventory"
  - "Confirmation REALTIME_DATA (type 40 realtime HR/RR) + sleep-review backfill present; REALTIME_RAW_DATA (type 43 raw IMU) absent"
affects: [04-04, biometric-decode, wave-3, PROTO-07, PROTO-14]

# Tech tracking
tech-stack:
  added: [pyyaml]
  patterns: ["Evidence sidecar pattern: redacted YAML documenting a gitignored raw capture by frame inventory + firmware revision only"]

key-files:
  created: []
  modified:
    - re/capture/evidence/2026-05-30-biometric-5.meta.yaml

key-decisions:
  - "Retained firmware_revision WG50_r52 (capture had no Device Info 0x2A26/0x2A27 read; clean r52 enum resolution across all frames corroborates, zero schema drift)"
  - "Recorded raw_imu_present: false honestly — no REALTIME_RAW_DATA (type 43) nor TOGGLE_IMU_MODE (cmd 106) in this session; flagged as PROTO-14 Wave 3 risk"
  - "Installed PyYAML into re/survey_5/.venv to run the plan's sidecar-verify one-liner (Task 1 readiness note pre-authorised this)"

patterns-established:
  - "Biometric capture inventory: build_report (per-characteristic counts) + parse_body_5 (stream_type classification) + presence flags for type 40 / type 43 / METADATA backfill"

requirements-completed: [PROTO-16, PROTO-07, PROTO-11, PROTO-12, PROTO-13, PROTO-14]

# Metrics
duration: ~12min
completed: 2026-05-30
---

# Phase 4 Plan 02: D-05 Biometric Capture Inventory Summary

**Targeted PacketLogger biometric capture extracted and inventoried — REALTIME_DATA (type 40, realtime HR/RR) and sleep-review historical backfill confirmed present; raw IMU (type 43) confirmed absent — finalised into a redacted evidence sidecar with firmware revision (PROTO-16).**

## Performance

- **Duration:** ~12 min (Task 2 post-checkpoint; Task 1 completed in a prior session)
- **Completed:** 2026-05-30
- **Tasks:** 2 (Task 1 prior; Task 2 this session)
- **Files modified:** 1 (evidence sidecar)

## Accomplishments
- Extracted 1049 wrapper-ok custom-service frames from `capture_all-V3.pklg` across the four FD4B handles (cmd-in 94, cmd-resp 98, events 4, data 853).
- Confirmed **REALTIME_DATA (PacketType 40)** present — 159 frames on the data characteristic, corroborated by 60 TOGGLE_REALTIME_HR commands and 21/11 BLE_REALTIME_HR_ON/OFF events. This satisfies the PROTO-07 realtime HR/RR gate.
- Confirmed **sleep-review historical backfill** present — 300 HISTORICAL_DATA frames + 38 METADATA frames (HISTORY_START 15 / HISTORY_END 19 / HISTORY_COMPLETE 4).
- Recorded **REALTIME_RAW_DATA (PacketType 43, raw IMU) absent** — flagged as a PROTO-14 Wave 3 risk (needs a dedicated IMU-mode capture).
- Finalised the redacted evidence sidecar with the full results block, keeping device_identity `[REDACTED]` and the raw pklg local-only.

## Task Commits

1. **Task 1: Pre-capture readiness + sidecar draft** - `cc32bf2` (feat) — prior session
2. **Task 2: Extract + report biometric inventory, finalise sidecar** - `490419d` (feat)

## Files Created/Modified
- `re/capture/evidence/2026-05-30-biometric-5.meta.yaml` - Finalised results block (frames_by_characteristic, distinct_packet_types, realtime_hr_present, raw_imu_present, sleep_review_present, toggle_realtime_hr_commands, realtime_hr_events, metadata_subtypes); firmware_revision note updated; raw artifact path set to capture_all-V3.pklg.

## Decisions Made
- **firmware_revision kept as WG50_r52:** the capture contains no Device Information GATT read (the strap was already bonded for this session). Rather than fabricate a freshly-read value, the baseline is retained with an explicit note; the clean resolution of every decoded PacketType/CommandNumber/EventNumber/MetadataType against the r52 enum maps (zero unknown ptypes) corroborates WG50_r52 and shows no schema drift.
- **raw_imu_present: false recorded honestly** per the plan's instruction ("If type 40 / type 43 are absent, record that honestly"). Standard REALTIME_DATA (type 40) satisfies PROTO-07; raw IMU (PROTO-14) is not obtainable from this capture.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Installed PyYAML into re/survey_5/.venv**
- **Found during:** Task 2 (sidecar verification)
- **Issue:** The plan's `<verify>` one-liner imports `yaml`, but PyYAML was not installed in `re/survey_5/.venv` (anticipated in the Task 1 readiness note).
- **Fix:** `re/survey_5/.venv/bin/python -m pip install pyyaml` (pyyaml 6.0.3 — ubiquitous, legitimate package; Task 1 note pre-authorised adding it).
- **Files modified:** re/survey_5/.venv (not tracked)
- **Verification:** The plan verify one-liner now passes: `sidecar ok: [...]`.
- **Committed in:** N/A (venv is local-only / not tracked)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to run the plan's own verification step. No scope creep.

## Issues Encountered
- No Device Info (0x2A26/0x2A27) read in the capture, so firmware could not be freshly confirmed from this session — resolved by retaining the baseline value with an explicit corroboration note (clean r52 enum resolution). Documented in the sidecar's firmware_revision_source.

## Threat Surface
- T-04-02 / T-04-03 upheld: raw `capture_all-V3.pklg` confirmed gitignored (`git check-ignore` exit 0, not committed); sidecar carries `device_identity: "[REDACTED]"` and only protocol-structure facts (frame counts, PacketTypes, presence flags, firmware string). No BD_ADDR / serial / SMP key bytes committed.

## Next Phase Readiness
- **Wave 3 (Plan 04) inputs ready:** the capture provides REALTIME_DATA (type 40) for HR/RR decode and HISTORICAL_DATA + METADATA for sleep-review backfill decode.
- **PROTO-14 risk surfaced:** raw IMU (REALTIME_RAW_DATA type 43) is NOT in this capture; Wave 3 must either treat raw IMU as out-of-scope for now or schedule a dedicated TOGGLE_IMU_MODE capture.

---
*Phase: 04-protocol-decode-schema*
*Completed: 2026-05-30*
