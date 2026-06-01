---
status: partial
phase: 07-ios-validation-biometrics-capture
source: [07-VERIFICATION.md]
started: "2026-05-31T18:30:00Z"
updated: "2026-05-31T18:30:00Z"
---

## Current Test

[awaiting human testing — requires physical WHOOP 5.0 + iPhone]

## Tests

### 1. TodayView shows real WHOOP 5.0 data (IOS-03)

expected: Recovery score (non-zero, non "—"), HRV in ms (non-zero), sleep summary (real session title) — all visible after Phase 6 backfill completes on physical iPhone with WHOOP 5.0
result: [pending]

### 2. SleepView shows real sleep sessions with staging (IOS-04)

expected: At least 1 historical sleep session visible with non-zero staging fields (REM/Deep/Light/Awake minutes) — after Phase 6 backfill on physical iPhone with WHOOP 5.0
result: [pending]

### 3. IOS-08 background reconnect Maestro test (IOS-08)

expected: `maestro test ios/maestro/07_ios08_background_reconnect.yaml` exits 0 — "Connected" visible within 30s after force-quit, on physical iPhone with WHOOP 5.0 in BLE range
result: [pending]

### 4. TOGGLE_IMU_MODE physical capture session (PROTO-11/12/13/14)

expected: Run `python re/re_harness.py` + `echo imu_on >> control.txt` — observe type 43 (IMU), type 53 (SpO₂), event 17 (temp), or respiration frames in re_log.jsonl; update evidence files and schema confidence if streams are VERIFIED
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
