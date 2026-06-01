---
phase: "07"
phase_name: ios-validation-biometrics-capture
status: human_needed
verified_at: "2026-05-31"
requirements_checked:
  - IOS-03
  - IOS-04
  - IOS-05
  - IOS-08
  - PROTO-11
  - PROTO-12
  - PROTO-13
  - PROTO-14
must_haves_verified: 5
must_haves_total: 8
human_verification:
  - IOS-03: TodayView shows real recovery/HRV data (requires physical WHOOP 5.0 + Phase 6 backfill)
  - IOS-04: SleepView shows real sleep sessions with staging (requires physical WHOOP 5.0 + Phase 6 backfill)
  - IOS-08: Maestro background reconnect test execution (requires physical iPhone + WHOOP 5.0)
  - PROTO-11/12/13/14: TOGGLE_IMU_MODE capture session (requires physical WHOOP 5.0 BLE connection)
---

# Verification Report — Phase 07: iOS Validation + Biometrics Capture

**Verified:** 2026-05-31
**Status:** human_needed — 5/8 must-haves verified automatically; 3 require physical hardware

---

## Goal Verification

**Phase goal:** iOS Validation + Biometrics Capture — deliver TOGGLE_IMU_MODE capture infrastructure, iOS debug button, Maestro IOS-08 test, and biometric stream evidence.

---

## Must-Have Verification

### PASSED — 07B: TOGGLE_IMU_MODE iOS debug button (4/4 criteria)

- `WhoopCommand.toggleIMUMode = 106` — verified in Commands.swift (rawValue 106, label "Toggle IMU Mode") ✓
- `BLEManager.toggleIMUMode(on:)` — method exists, sends `[0x01]`/`[0x00]` via `send(.toggleIMUMode, payload:)` ✓
- `LiveViewModel.toggleIMUMode(on:)` — public passthrough to BLEManager ✓
- `SettingsView` debug section — `#if DEBUG` guard present, `imuModeOn` state + button with ON/OFF label ✓
- iOS Simulator build: SUCCEEDED (no compilation errors, no warnings from Phase 7 changes) ✓

### PASSED — 07A: Evidence artefacts committed (5/5 files)

All 5 evidence files exist in `re/capture/evidence/`:
- `07_imu_capture_session.jsonl` ✓
- `07_imu_evidence.txt` ✓
- `07_spo2_evidence.txt` ✓
- `07_skin_temp_evidence.txt` ✓
- `07_respiration_evidence.txt` ✓

Each file contains explicit NOT_OBSERVED documentation (per plan: "document as 'not observed' rather than fabricating a VERIFIED status").

### PASSED — 07A: No false VERIFIED in schema

`protocol/whoop_protocol_5.json` biometrics map checked — SpO₂, skin_temp, respiration, IMU all remain `"confidence": "HYPOTHESIS"`. No HYPOTHESIS stream was promoted to VERIFIED without evidence. ✓

### PASSED — 07C: Maestro test created and structurally correct

`ios/maestro/07_ios08_background_reconnect.yaml`:
- `appId: com.openwhoop.OpenWhoop` ✓
- `runFlow: utils/allow_notifications.yaml` (both launchApp contexts) ✓
- `stopApp` command present ✓
- Second `launchApp` after `stopApp` ✓
- `waitForAnimationToEnd` with `timeout: 30000` (≥ 30s, matches IOS-08 criterion) ✓
- 2 `assertVisible` with text `"Connected"` (actual UI string from LiveView.swift line 182) ✓
- 6 `takeScreenshot` calls ✓

### PASSED — IOS-05 not implemented (deferred to Phase 9)

`git diff` confirms TrendsView.swift and MetricKind.swift were NOT modified in Phase 7. `REQUIREMENTS.md` notes IOS-05 as "deferred to Phase 9 SwiftUI Redesign". ✓

---

## Human Verification Required

The following items require physical hardware and cannot be verified automatically:

### HV-01: IOS-03 — TodayView real data (WHOOP 5.0 + Phase 6 backfill)

**What to verify:**
1. Launch iOS app on physical iPhone with WHOOP 5.0 in range
2. Allow Phase 6 backfill to complete
3. Navigate to Today tab
4. Verify: recovery score shows numeric value (not "—"), HRV shows numeric ms value, sleep summary shows real session

**Expected:** Non-zero, non-placeholder values in all 3 fields after backfill completes
**Evidence needed:** Screenshot or observed values with firmware version from logs

### HV-02: IOS-04 — SleepView real sleep sessions (WHOOP 5.0 + Phase 6 backfill)

**What to verify:**
1. Navigate to Sleep tab on physical iPhone
2. Verify: at least 1 sleep session visible, staging fields (REM/Deep/Light/Awake) show non-zero values
3. Confirm SpO₂ HYPOTHESIS comment at SleepView.swift line 305 remains unchanged

**Expected:** Real historical sleep sessions with staging data visible

### HV-03: IOS-08 — Maestro background reconnect test execution

**What to run:**
```bash
maestro test ios/maestro/07_ios08_background_reconnect.yaml
```
**Requirement:** Physical iPhone + WHOOP 5.0 in BLE range
**Success criterion:** `maestro test` exits 0 — "Connected" visible within 30s after force-quit

### HV-04: PROTO-11/12/13/14 — TOGGLE_IMU_MODE physical capture session

**What to run:**
```bash
cd /Users/francisco/Documents/my-whoop/re
python re_harness.py
# After connection: echo imu_on >> control.txt
# Monitor re_log.jsonl for type 43, type 53, event 17, respiration
# After all streams observed (or 10 min): echo quit >> control.txt
cp re_log.jsonl re/capture/evidence/07_imu_capture_session.jsonl
```
**Then:** Update `07_*_evidence.txt` files with actual frame data, run `scripts/sync-schema-5.sh` if any stream is VERIFIED, update `FINDINGS_5.md` table, update `REQUIREMENTS.md` PROTO checkboxes.

---

## Requirement Traceability

| Requirement | Phase 7 Plan | Status | Notes |
|-------------|-------------|--------|-------|
| IOS-03 | 07C-T1 | Hardware pending | TodayView code verified; data requires physical device |
| IOS-04 | 07C-T2 | Hardware pending | SleepView code verified; data requires physical device |
| IOS-05 | — | Deferred | Phase 9 SwiftUI Redesign; TrendsView not modified |
| IOS-08 | 07C-T3/T4 | Test ready | Maestro test committed; hardware execution pending |
| PROTO-11 | 07A | NOT_OBSERVED | Evidence file committed; hardware capture pending |
| PROTO-12 | 07A | NOT_OBSERVED | Evidence file committed; hardware capture pending |
| PROTO-13 | 07A | NOT_OBSERVED | Evidence file committed; likely cloud-derived |
| PROTO-14 | 07A | NOT_OBSERVED | Evidence file committed; hardware capture pending |

---

## Automated Checks Summary

| Check | Result |
|-------|--------|
| iOS Simulator build | SUCCEEDED — 0 errors |
| toggleIMUMode in Commands.swift | PASS |
| toggleIMUMode in BLEManager.swift | PASS |
| toggleIMUMode in LiveViewModel.swift | PASS |
| #if DEBUG guard in SettingsView | PASS |
| 5 evidence files in re/capture/evidence/ | PASS |
| No false VERIFIED in protocol schema | PASS |
| Maestro test structure (7 criteria) | PASS |
| IOS-05 TrendsView/MetricKind unchanged | PASS |
| Code review: 0 Critical, 0 Warning | PASS |
