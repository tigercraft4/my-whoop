---
phase: 04-protocol-decode-schema
plan: 04
subsystem: protocol-decode
tags: [ble, reverse-engineering, python, biometrics, realtime-hr, rr-intervals, imu, spo2, skin-temp, respiration, decode, verdicts]

# Dependency graph
requires:
  - phase: 04-01
    provides: "decode_5.parse_body_5 (offset-4 body decoder) + r52 enum resolution"
  - phase: 04-02
    provides: "D-05 biometric capture (capture_all-V3.pklg) inventory + evidence sidecar (realtime_hr_present=true, raw_imu_present=false, firmware WG50_r52)"
  - phase: 02
    provides: "standard 0x2A37 parse_hr (CONFIRMED unbonded); macOS-cannot-bond finding (capture is human PacketLogger session)"
provides:
  - "decode_biometrics_5.py: per-stream biometric decoders (HR/RR, IMU, SpO2/temp/respiration) over the D-05 capture with VERIFIED/HYPOTHESIS verdicts for Plan 05"
  - "EMPIRICALLY-reconciled 5.0 REALTIME_DATA (type 40) layout: HR @ payload[5], rr_count @ payload[6], RR uint16-LE ms @ payload[7:] (NOT the literal 4.0 offsets)"
  - "Confidence map: PROTO-07 VERIFIED; PROTO-11/12/13/14 HYPOTHESIS with honest provenance"
affects: [04-05 schema, 04-05 findings, PROTO-07, PROTO-11, PROTO-12, PROTO-13, PROTO-14, PROTO-16]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Observation-gated biometric decode: VERIFIED only with a referenced captured frame, else HYPOTHESIS with 4.0-cloud-computed provenance (Pitfall 5)"
    - "Empirical offset reconciliation when the literal 4.0 byte map fails on 5.0 (per-byte-position variance analysis to locate the HR time-series)"
    - "Internal ground-truth via RR<->HR self-consistency (60000/HR ~= RR ms) when a same-frame HR-strap log is unavailable (D-08 substitute)"
    - "Worktree-aware capture resolution (gitignored .pklg fallback to primary checkout)"
    - "parse_hr verbatim reuse with a stdlib-only fallback copy (bleak unavailable in worktree)"

key-files:
  created:
    - re/survey_5/decode_biometrics_5.py
  modified: []

key-decisions:
  - "5.0 REALTIME_DATA (type 40) layout reconciled EMPIRICALLY, NOT from the literal 4.0 schema offsets: HR @ body[12]==payload[5] (smooth 84-131 bpm series); 4.0's HR @ data[14] decodes to all-zero/0x01 on 5.0"
  - "body[6] in REALTIME_DATA is a per-frame SUB-SEQUENCE counter (41-243 monotonic), NOT a CommandNumber"
  - "HR/RR PROTO-07 graded VERIFIED via RR<->HR consistency (8/8 RR-bearing frames match 60000/HR) as the internal D-08 alignment in lieu of a same-frame HR-strap log"
  - "IMU PROTO-14 recorded HYPOTHESIS honestly: type 43 absent from the D-05 capture (raw_imu_present=false); 4.0 layout kept as a decode-ready template, NO offsets fabricated"
  - "SpO2/temp/respiration (PROTO-11/12/13) all HYPOTHESIS: type 53 absent, event 17 absent, no respiration field on the wire; 4.0 precedent = cloud-computed (off-wire)"

requirements-completed: [PROTO-07]
requirements-advanced: [PROTO-11, PROTO-12, PROTO-13, PROTO-14, PROTO-16]

# Metrics
duration: ~20min
completed: 2026-05-30
---

# Phase 4 Plan 04: D-05 Biometric Stream Decode Summary

**Realtime HR/RR (PROTO-07) is now VERIFIED — 159 REALTIME_DATA (type 40) frames decode to a smooth 84-131 bpm time-series with RR intervals self-consistent against 60000/HR — while IMU (PROTO-14) and SpO2/skin-temp/respiration (PROTO-11/12/13) are honestly HYPOTHESIS because their bytes are absent from the D-05 capture, with no offsets fabricated (Pitfall 5) and the firmware revision (PROTO-16, WG50_r52) carried into every verdict.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-05-30
- **Tasks:** 2 (both in `decode_biometrics_5.py`)
- **Files created:** 1

## Accomplishments

- Built `re/survey_5/decode_biometrics_5.py` — per-stream biometric decoders over the D-05 capture (`capture_all-V3.pklg`), importing `parse_body_5` from `decode_5` and reusing the standard `0x2A37` `parse_hr` verbatim (with a stdlib-only fallback copy so it runs in a worktree where `bleak` is absent).
- **PROTO-07 HR/RR → VERIFIED.** Decoded all 159 REALTIME_DATA (type 40) frames. The HR byte is a smooth, physiological time-series (84-131 bpm, mean 102). RR intervals decode to plausible ms values (e.g. HR=91 → RR 645-694 ms) and **8/8 RR-bearing frames are self-consistent with 60000/HR** — this RR↔HR cross-check is the internal D-08 ground-truth alignment in lieu of a same-frame HR-strap log, and it corroborates the standard `0x2A37` path.
- **Corrected the 5.0 REALTIME_DATA layout empirically.** The literal 4.0 schema offsets (HR @ `data[14]`) decode to all-zero/`0x01` on 5.0. Per-byte-position variance analysis located the real layout: device-epoch u32 @ `payload[1:5]`, **HR @ `payload[5]`**, **rr_count @ `payload[6]`**, **RR uint16-LE ms @ `payload[7:]`**. Also found that `body[6]` (the usual cmd slot) is a per-frame sub-sequence counter (41-243), not a CommandNumber.
- **PROTO-14 IMU → HYPOTHESIS (honest).** No REALTIME_RAW_DATA (type 43) frames in the capture (Plan 02 sidecar: `raw_imu_present=false`; no START_RAW_DATA cmd 81 / TOGGLE_IMU_MODE cmd 106 triggered). The 4.0 Gen4-VERIFIED layout (100 samples/axis int16-LE accel+gyro) is kept as a decode-ready template applied ONLY when a type-43 frame appears; **no offsets fabricated**.
- **PROTO-11/12/13 SpO2/skin-temp/respiration → HYPOTHESIS (honest).** Confirmed genuine absence (not a scan false-negative): 0 type-53 frames, 0 event-17 (TEMPERATURE_LEVEL) frames, no respiration field on the wire. Each verdict cites the 4.0 cloud-computed precedent (FINDINGS.md §6/§9b). No VERIFIED biometric field is emitted without a referenced captured frame.
- **PROTO-16:** every verdict carries `firmware=WG50_r52`.

## Task Commits

1. **Tasks 1 + 2: D-05 biometric stream decoders + verdicts** — `65f6bad` (feat)

_Note on file/task mapping:_ the plan's Task 1 (HR/IMU) and Task 2 (SpO2/temp/respiration) both author the single file `decode_biometrics_5.py` — Task 2 explicitly "extends the Task 1 file". The decoders are inseparable in one module, so they landed in one atomic commit (same precedent as Plan 01's `decode_5.py` file/task note). Both task scopes are individually verified below.

## Files Created

- `re/survey_5/decode_biometrics_5.py` — biometric stream decoders: `decode_realtime_data_payload` (5.0-reconciled HR/RR), `decode_standard_hr` (parse_hr verbatim), `verdict_hr`/`verdict_imu`/`verdict_spo2`/`verdict_temp`/`verdict_resp`, worktree-aware `_resolve_d05_capture`/`_load_capture_records`, CLI `--streams`. 14 functions, length-guarded throughout.

## Verification Evidence

| Check | Result |
|-------|--------|
| `cd re/survey_5 && python decode_biometrics_5.py --streams hr,imu` | exit 0 |
| `cd re/survey_5 && python decode_biometrics_5.py --streams spo2,temp,resp` | exit 0 |
| `grep -c "from decode_5 import"` | 1 |
| `grep -c "parse_hr"` | 16 (verbatim reuse wired) |
| `grep -c "len("` (length guards) | 23 (≥ 1) |
| `grep -c "def "` | 14 (≥ 60 lines: 561 lines total) |
| HR/RR verdict | **VERIFIED** with 159 type-40 frames + RR↔HR cross-check + HR strap (D-08) note |
| IMU verdict | **HYPOTHESIS** "raw IMU not observed" — 0 type-43 frames, no fabricated offsets |
| SpO2/temp/resp verdicts | **HYPOTHESIS** each, 4.0-cloud-computed provenance; 0 type-53 / 0 event-17 confirmed |
| firmware in every verdict (PROTO-16) | yes — `WG50_r52` |

## Per-stream verdict table (for Plan 05 schema)

| stream | requirement | verdict | provenance |
|--------|-------------|---------|------------|
| HR/RR | PROTO-07 | **VERIFIED** | standard 0x2A37 (parse_hr verbatim) + custom type-40 reconciled (HR @ payload[5], RR @ payload[7:]); RR↔HR self-consistent (8/8) |
| IMU/gravity | PROTO-14 | HYPOTHESIS | type 43 absent (raw_imu_present=false); 4.0 layout template ready; needs TOGGLE_IMU_MODE capture |
| SpO2 | PROTO-11 | HYPOTHESIS | type 53 byte 10 (Sivasai2207) not observed; 4.0 = cloud-computed off-wire |
| skin_temp | PROTO-12 | HYPOTHESIS | event 17 TEMPERATURE_LEVEL not observed; 4.0 never captured it |
| respiration | PROTO-13 | HYPOTHESIS | no respiration field on the wire; likely derived/sleep metric, may be cloud-only |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Correctness] Corrected the 5.0 REALTIME_DATA (type 40) field offsets**
- **Found during:** Task 1
- **Issue:** The plan instructed adapting the 4.0 REALTIME_DATA field map (HR @ data[14], rr_count @ data[15], RR @ data[16:24]) to the 5.0 body base. Applied literally, this yielded HR=0x01/all-zero across all 159 frames — a wrong (non-physiological) decode that would have left PROTO-07 at HYPOTHESIS.
- **Fix:** Reconciled the layout empirically via per-byte-position variance analysis on the 159 type-40 frames: the real 5.0 layout is device-epoch u32 @ payload[1:5], HR @ payload[5], rr_count @ payload[6], RR uint16-LE ms @ payload[7:]. The HR series is smooth/physiological (84-131 bpm) and the RR intervals are self-consistent with 60000/HR — confirming the correct offsets. Also documented that body[6] is a sub-sequence counter, not a cmd.
- **Files modified:** re/survey_5/decode_biometrics_5.py
- **Commit:** 65f6bad

**2. [Rule 3 - Blocking] Stdlib-only fallback for parse_hr (bleak unavailable in worktree)**
- **Found during:** Task 1
- **Issue:** `standard_ble.parse_hr` is reused verbatim per the plan, but `standard_ble` imports `bleak` and `device_config` at module load, which are not importable inside the git worktree checkout (and `re/survey_5/.venv` is local-only, absent from the worktree).
- **Fix:** `try: from standard_ble import parse_hr` with a fallback that defines a byte-for-byte copy of `parse_hr` (same algorithm — the "verbatim reuse" the plan requires; the `parse_hr` key_link pattern still matches). The decoder runs from either the worktree (fallback) or the primary checkout (import).
- **Files modified:** re/survey_5/decode_biometrics_5.py
- **Commit:** 65f6bad

---

**Total deviations:** 2 auto-fixed (1 correctness, 1 blocking)
**Impact on plan:** Strengthened PROTO-07 from would-be-HYPOTHESIS to VERIFIED via empirical offset reconciliation; no scope creep.

## Authentication Gates

None.

## Known Stubs

None. The IMU/SpO2/temp/respiration HYPOTHESIS verdicts are honest provenance (capture-gated, bytes genuinely absent — verified: 0 type-43, 0 type-53, 0 event-17), not stubs. No fabricated offsets or placeholder VERIFIED fields exist (Pitfall 5 upheld).

## Threat Flags

None. No new network endpoints, auth paths, or trust boundaries beyond the plan's `<threat_model>`. T-04-01 (length guards before every slice — 23 `len()` guards; absent streams take the HYPOTHESIS path, never crash) and T-04-05 (strict observation-gating: VERIFIED only with a referenced captured frame) are both mitigated and verified above. T-04-SC upheld: no package installs (parse_hr fallback is a stdlib-only copy; reuses decode_5 / validate_frames_5).

## Self-Check: PASSED

- FOUND: re/survey_5/decode_biometrics_5.py
- FOUND: commit 65f6bad
