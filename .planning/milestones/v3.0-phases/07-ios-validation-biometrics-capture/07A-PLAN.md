---
phase: 7
plan: 07A
title: "IMU Capture Script + Biometrics Verification"
wave: 1
depends_on: []
files_modified:
  - re/re_harness.py
  - re/capture/evidence/07_imu_capture_session.jsonl
  - re/capture/evidence/07_spo2_evidence.txt
  - re/capture/evidence/07_skin_temp_evidence.txt
  - re/capture/evidence/07_respiration_evidence.txt
  - re/capture/evidence/07_imu_evidence.txt
  - protocol/whoop_protocol_5.json
  - server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json
  - FINDINGS_5.md
  - .planning/REQUIREMENTS.md
autonomous: true
requirements: [PROTO-11, PROTO-12, PROTO-13, PROTO-14]
---

<objective>
Run a dedicated TOGGLE_IMU_MODE capture session via the existing re_harness.py script, capture frames for all 4 biometric streams (SpO₂ PROTO-11, skin temp PROTO-12, respiration PROTO-13, IMU/gravity PROTO-14), validate SpO₂ against a reference oximeter, and commit all verification artefacts (schema update, FINDINGS_5.md entry, evidence excerpt, REQUIREMENTS.md tick).
</objective>

<context>
re_harness.py already implements `echo imu_on >> control.txt` → sends `CommandNumber.TOGGLE_IMU_MODE` with payload `b"\x01"`. The harness logs all notifications to `re_log.jsonl`. The goal is to run a capture session with IMU mode ON, confirm all 4 stream types appear in the log, extract evidence excerpts, validate SpO₂ numerically, and promote fields in `protocol/whoop_protocol_5.json` from `confidence: "HYPOTHESIS"` to `confidence: "VERIFIED"`.

FINDINGS_5.md table shows: PROTO-14 (type 43 IMU), PROTO-11 (type 53 SpO₂), PROTO-12 (event-17 temperature), PROTO-13 (respiration) are all HYPOTHESIS. TOGGLE_IMU_MODE is confirmed to exist in CommandNumber and re_harness.py.

SpO₂ validation threshold: ±2% vs consumer pulse oximeter (clinical standard for consumer-grade validation). Document the threshold and measurement method in the evidence file.

The capture session terminates when all 4 stream types have appeared in the log — not by fixed time. The executor must run the session, monitor `re_log.jsonl` for stream types, and terminate cleanly after confirmation.
</context>

<tasks>

<task id="07A-T1">
<type>execute</type>
<title>Run TOGGLE_IMU_MODE capture session and collect raw log</title>

<read_first>
- re/re_harness.py — understand control file dispatch, LOG_PATH (re_log.jsonl), CONTROL filename, imu_on command flow (lines ~17, 190–193)
- re/device_config.py or re/device_local.example.py — confirm DEVICE_UUID configuration needed
- FINDINGS_5.md — review stream type numbers: type 43 (IMU), type 53 (SpO₂), event 17 (temperature), and respiration frame patterns
</read_first>

<action>
Run the capture session:
1. Ensure WHOOP 5.0 is not connected to the official app (close WHOOP app on iPhone)
2. Start `re_harness.py` from the `re/` directory: `python re_harness.py`
3. After connection established (look for GET_HELLO_HARVARD response in logs), activate IMU mode: `echo imu_on >> control.txt`
4. Monitor `re_log.jsonl` for frame type 43 (IMU/gravity), type 53 (SpO₂), event 17 (TEMPERATURE_LEVEL), and any respiration field in notification payloads
5. Once all 4 stream types appear — or after 10 minutes with a note on which streams were observed — terminate: `echo quit >> control.txt`
6. Copy the completed log: `cp re_log.jsonl re/capture/evidence/07_imu_capture_session.jsonl`

If a stream type does NOT appear after full session, document that in the evidence file with the note "not observed in TOGGLE_IMU_MODE session — remains HYPOTHESIS" rather than fabricating a VERIFIED status.
</action>

<acceptance_criteria>
- `re/capture/evidence/07_imu_capture_session.jsonl` exists and is non-empty
- File contains at minimum the imu_on command dispatch event (grep "imu_on" or "TOGGLE_IMU_MODE" in the JSONL)
- Session log shows connection established before IMU mode toggle (HELLO or version frame visible)
</acceptance_criteria>
</task>

<task id="07A-T2">
<type>execute</type>
<title>Extract per-stream evidence excerpts from capture log</title>

<read_first>
- re/capture/evidence/07_imu_capture_session.jsonl — the completed capture log from T1
- FINDINGS_5.md lines ~289-292 — current HYPOTHESIS table to understand which frame types to match (type 43, type 53, event 17)
- re/analyze_imu.py or re/decode_raw.py — existing analysis patterns for frame extraction
</read_first>

<action>
For each stream type observed in `07_imu_capture_session.jsonl`, extract an evidence excerpt of 10–20 representative frames showing raw hex offsets and decoded values:

1. **IMU/gravity (PROTO-14, type 43):** Extract frames with `"type": 43` or equivalent field. Write 10–20 rows showing raw bytes and the gravity/accelerometer field values to `re/capture/evidence/07_imu_evidence.txt`. Include: frame count observed, sample rate estimate if derivable.

2. **SpO₂ (PROTO-11, type 53):** Extract frames with `"type": 53`. Write values and raw offsets to `re/capture/evidence/07_spo2_evidence.txt`. Include: minimum 3 SpO₂ readings with their decimal values, byte offsets in the payload.

3. **Skin temperature (PROTO-12, event 17 / TEMPERATURE_LEVEL):** Extract event-17 frames. Write to `re/capture/evidence/07_skin_temp_evidence.txt`. Include: raw temperature values, units if determinable.

4. **Respiration (PROTO-13):** Extract any respiration-rate field from notification payloads. Write to `re/capture/evidence/07_respiration_evidence.txt`. Note: if not present on the wire, document "not observed — likely cloud-derived" with evidence (absence confirmed over N minutes of capture).

For any stream NOT observed: write a brief `not_observed.txt` note confirming absence over the full session duration.
</action>

<acceptance_criteria>
- `re/capture/evidence/07_imu_evidence.txt` exists (may contain "not observed" with evidence)
- `re/capture/evidence/07_spo2_evidence.txt` exists with at least 1 SpO₂ numeric reading or "not observed" statement
- `re/capture/evidence/07_skin_temp_evidence.txt` exists
- `re/capture/evidence/07_respiration_evidence.txt` exists
- Each file contains either concrete frame data OR an explicit "not observed — [reason]" note — no empty files
</acceptance_criteria>
</task>

<task id="07A-T3">
<type>execute</type>
<title>Validate SpO₂ against reference oximeter and document method</title>

<read_first>
- re/capture/evidence/07_spo2_evidence.txt — SpO₂ decoded values from T2
- FINDINGS_5.md line ~290 — current PROTO-11 HYPOTHESIS note ("type 53 byte not observed")
</read_first>

<action>
Compare the decoded SpO₂ value(s) from `07_spo2_evidence.txt` against a consumer pulse oximeter reading taken simultaneously (or within the same capture session):

1. Record the reference oximeter reading (e.g., "Oxímetro de referência: 97%")
2. Record the decoded WHOOP value (e.g., "WHOOP decoded: 96%")
3. Compute difference: `|WHOOP - reference|`
4. Apply threshold: ±2% → VERIFIED; >2% → document as UNVERIFIED with raw values

Write the validation result to `re/capture/evidence/07_spo2_evidence.txt` (append):
```
--- SpO2 Validation ---
Reference oximeter: XX%
WHOOP decoded: XX%
Delta: ±X%
Threshold: ±2% (consumer-grade clinical standard)
Result: VERIFIED / UNVERIFIED
Date: 2026-XX-XX
Method: simultaneous reading during TOGGLE_IMU_MODE capture session
```

If type 53 frames were NOT observed in the capture, mark result as "NOT_OBSERVED — HYPOTHESIS maintained" and document the session duration.
</action>

<acceptance_criteria>
- `re/capture/evidence/07_spo2_evidence.txt` contains a "SpO2 Validation" section with Reference, WHOOP decoded, Delta, Threshold, Result, and Date fields
- Result field is exactly one of: VERIFIED, UNVERIFIED, or NOT_OBSERVED
- If VERIFIED: Delta ≤ 2%
</acceptance_criteria>
</task>

<task id="07A-T4">
<type>execute</type>
<title>Update whoop_protocol_5.json confidence fields for verified streams</title>

<read_first>
- protocol/whoop_protocol_5.json — current schema with `"confidence": "HYPOTHESIS"` fields for spo2, skinTemp, respiration, gravity/imu
- scripts/sync-schema.sh — sync command to run after update
- server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json — Python-side copy (must also be updated by sync-schema.sh)
</read_first>

<action>
For each stream that was VERIFIED in tasks T2–T3:
- Open `protocol/whoop_protocol_5.json`
- Find the field entry for the verified stream (spo2, skinTemp, respiration, imuGravity or equivalent)
- Change `"confidence": "HYPOTHESIS"` → `"confidence": "VERIFIED"` for that specific field
- Add a `"verified_date": "2026-XX-XX"` field next to the confidence update
- Add a `"evidence": "re/capture/evidence/07_XXX_evidence.txt"` reference

For streams that were NOT observed (confidence remains HYPOTHESIS): leave unchanged.

After all updates, run: `bash scripts/sync-schema.sh`

Verify sync completed: confirm `server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json` shows the same confidence values as the updated `protocol/whoop_protocol_5.json`.
</action>

<acceptance_criteria>
- For each VERIFIED stream: `protocol/whoop_protocol_5.json` contains `"confidence": "VERIFIED"` for that field (grep-verifiable)
- `scripts/sync-schema.sh` runs without error (exit code 0)
- `server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json` contains identical confidence values as the primary schema (diff shows no confidence field discrepancy)
- No HYPOTHESIS stream was changed to VERIFIED without corresponding evidence file
</acceptance_criteria>
</task>

<task id="07A-T5">
<type>execute</type>
<title>Update FINDINGS_5.md verification table and REQUIREMENTS.md</title>

<read_first>
- FINDINGS_5.md lines ~289-292 — current HYPOTHESIS table rows for PROTO-11/12/13/14
- .planning/REQUIREMENTS.md — IOS-03, IOS-04, IOS-05, IOS-08, PROTO-11, PROTO-12, PROTO-13, PROTO-14 entries (lines ~23-29)
</read_first>

<action>
**FINDINGS_5.md:** For each verified stream, update the table row:
- Change `HYPOTHESIS` → `VERIFIED` in the status column
- Add measured value, ground truth method, and date to the notes column
- Example: `| SpO₂ | PROTO-11 | VERIFIED | type 53; decoded 96%; oxímetro ref 97%; delta 1%; 2026-XX-XX |`

For NOT_OBSERVED streams: change notes to "TOGGLE_IMU_MODE session ran; frame type not observed — remains HYPOTHESIS; see 07_XXX_evidence.txt"

**REQUIREMENTS.md:** For each VERIFIED requirement (PROTO-11, PROTO-12, PROTO-13, PROTO-14):
- Change `- [ ] **PROTO-NN**:` → `- [x] **PROTO-NN**:` only if VERIFIED
- Leave `- [ ]` for streams that remain HYPOTHESIS after the capture
</action>

<acceptance_criteria>
- `FINDINGS_5.md` table rows for PROTO-11/12/13/14 updated — no row shows HYPOTHESIS for a VERIFIED stream
- `.planning/REQUIREMENTS.md` PROTO-NN items: checked `[x]` only for VERIFIED streams; `[ ]` for any remaining HYPOTHESIS
- grep `"VERIFIED"` in `FINDINGS_5.md` returns at least 1 match for Phase 7 evidence (or 0 matches if all streams were not observed — in that case a note "TOGGLE_IMU_MODE capture ran; streams not observed on WHOOP 5.0" is acceptable)
</acceptance_criteria>
</task>

</tasks>

<verification>
1. `ls re/capture/evidence/07_*.txt re/capture/evidence/07_imu_capture_session.jsonl` — all 5 evidence files exist
2. `grep -c "TOGGLE_IMU_MODE\|imu_on" re/capture/evidence/07_imu_capture_session.jsonl` — returns ≥ 1
3. `grep "confidence.*VERIFIED" protocol/whoop_protocol_5.json` — returns matches for any verified stream (0 matches is acceptable only if all streams were not observed, with explicit documentation)
4. `diff <(grep confidence protocol/whoop_protocol_5.json) <(grep confidence server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json)` — no diff
5. `grep "\- \[x\].*PROTO" .planning/REQUIREMENTS.md` — checked items match VERIFIED streams in FINDINGS_5.md
</verification>

<must_haves>
truths:
  - All 5 evidence files committed to re/capture/evidence/ — capture session log + 4 stream excerpts
  - protocol/whoop_protocol_5.json VERIFIED fields match FINDINGS_5.md VERIFIED rows exactly
  - sync-schema.sh was run and both schema copies are in sync
  - SpO₂ validation used ±2% threshold and result is documented explicitly
  - NOT_OBSERVED streams are documented as such — no HYPOTHESIS silently promoted to VERIFIED without evidence
</must_haves>

<threat_model>
- **False VERIFIED:** A stream marked VERIFIED without actual observed frames. Mitigation: T3 requires explicit delta calculation; T4 requires evidence file reference in schema; T5 cross-references FINDINGS_5 against schema — if any discrepancy, executor must re-check.
- **Schema drift:** Python and Swift schema copies diverging after update. Mitigation: sync-schema.sh run enforced in T4 with diff verification step.
- **Capture noise:** IMU mode frames from a prior session (WHOOP 4.0 template) mistakenly attributed to WHOOP 5.0. Mitigation: FINDINGS_5 already documents `firmware = WG50_r52` requirement — evidence files must reference the WHOOP 5.0 firmware version observed in the session.
</threat_model>
