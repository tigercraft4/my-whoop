---
phase: 05-ios-app-server-port
plan: 05
subsystem: iOS BLE (CoreBluetooth transport)
tags: [swift, corebluetooth, ble, uuid, whoop5, commands]

# Dependency graph
requires:
  - phase: 04-protocol-decode-schema
    provides: "FINDINGS_5.md §1 VERIFIED 5.0 GATT UUIDs (FD4B0001..5-CCE1-4033-93CE-002D5875F58A); §8 VERIFIED 10-command set"
  - plan: 05-01
    provides: "WhoopProtocol ported to 5.0 (Maverick strip + 5.0 schema)"
provides:
  - "BLEManager scans/connects/discovers via WHOOP 5.0 custom service+chars (FD4B0001..5)"
  - "WhoopCommand enum reviewed against the 10 Phase-4 VERIFIED codes; 4.0-inherited cases annotated HYPOTHESIS (5.0 unverified) and retained"
affects:
  - "05-06 (on-device bonding/reconnect/offload validation; resolves outbound-Maverick open question)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "In-place UUID swap (4.0 -> 5.0) — only the 5 custom CBUUID strings change; standard 180D/2A37/180F/2A19 and restoreID stay fixed"
    - "HYPOTHESIS-annotate-not-remove: unverified-on-5.0 command cases are documented inline rather than deleted, because every one is referenced by production or test code (deletion would break compilation, which D-05 forbids)"

key-files:
  created: []
  modified:
    - ios/OpenWhoop/BLE/BLEManager.swift
    - ios/OpenWhoop/BLE/Commands.swift

key-decisions:
  - "D-04: 5 custom GATT UUIDs swapped in-place 61080001..5 -> FD4B0001..5-CCE1-4033-93CE-002D5875F58A; no dual-UUID branch (legacy 4.0 service is ABSENT on this device — FINDINGS_5.md §2)"
  - "D-05: all 10 VERIFIED commands confirmed present; non-verified cases retained + annotated HYPOTHESIS instead of removed, per the plan's explicit 'NAO quebrar compilacao por remocao de um case usado' directive"
  - "frame() left as 4.0 CRC8+CRC32 — whether outbound writes need Maverick-wrapping is an OPEN QUESTION resolved on-device in 05-06"

requirements-completed: [IOS-01, IOS-07, IOS-08]

# Metrics
duration: ~8min
completed: 2026-05-30
---

# Phase 5 Plan 05: iOS BLE Wired to WHOOP 5.0 Summary

**BLEManager now scans/connects/discovers against the WHOOP 5.0 custom GATT service and characteristics (FD4B0001..5-CCE1-4033-93CE-002D5875F58A), and the WhoopCommand enum has been reviewed against the 10 Phase-4 VERIFIED command codes — with state restoration and offline mode left fully intact.**

## Performance

- **Duration:** ~8 min
- **Completed:** 2026-05-30
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- **Task 1 (D-04, IOS-01):** Replaced the 5 custom CBUUID strings (`61080001..5-8d6d-82b8-614a-1c8cb0f8dcc6`) with the VERIFIED 5.0 UUIDs (`FD4B0001..5-CCE1-4033-93CE-002D5875F58A`). Updated the doc-comment ("WHOOP 4.0" → "WHOOP 5.0"), the header comment (`from FINDINGS.md` → `from FINDINGS_5.md §1 — WHOOP 5.0`), the `upsertDevice(name:)` string, and the bond log (`61080002` → `FD4B0002`). The standard Bluetooth UUIDs (`180D`/`2A37` HR, `180F`/`2A19` battery) are untouched. `restoreID` and `CBCentralManagerOptionRestoreIdentifierKey`/`willRestoreState` are untouched (IOS-08). The confirmed-write bonding trick is unchanged. No dual-UUID branch added (legacy service absent).
- **Task 2 (D-05):** Confirmed all 10 VERIFIED command codes are present in `WhoopCommand` (3, 10, 11, 22, 23, 26, 34, 35, 97, 98). Annotated every 4.0-inherited / non-verified case with `HYPOTHESIS (5.0 unverified)` and a note on its referencing call site. Updated the `frame()` docstring (char `FD4B0002`; added a note that outbound Maverick-wrapping is an open question for 05-06). Left `frame()`'s body as the 4.0 CRC8+CRC32 framing.

## Task Commits

1. **Task 1: wire BLEManager to WHOOP 5.0 UUIDs (D-04, IOS-01)** — `b223438` (feat)
2. **Task 2: review WhoopCommand enum against 5.0 VERIFIED set (D-05)** — `7f4405b` (feat)

## Files Created/Modified

- `ios/OpenWhoop/BLE/BLEManager.swift` — 5 custom UUIDs → FD4B; doc/header/device-name/bond-log "4.0"→"5.0"; standard UUIDs + restoreID + state restoration untouched.
- `ios/OpenWhoop/BLE/Commands.swift` — enum doc-comment documents the 5.0 review; VERIFIED/HYPOTHESIS section markers added; 12 `HYPOTHESIS (5.0 unverified)` annotations on inherited cases; `frame()` docstring updated (FD4B0002 + outbound-Maverick open-question note); `frame()` body unchanged.

## Verification

- `grep -c 'FD4B000[1-5]-CCE1-4033-93CE-002D5875F58A' BLEManager.swift` → **5**
- `grep -c '61080001' BLEManager.swift` → **0**; `grep -c 'WHOOP 4.0'` → **0**; `grep -c '6108'` → **0**
- `grep -q 'WHOOP 5.0'` → present
- `restoreID = "com.openwhoop.ble.central"` and `CBCentralManagerOptionRestoreIdentifierKey` → present (IOS-08 intact)
- Standard HR/battery UUIDs (180D/2A37/180F/2A19) → present (unchanged)
- All 10 VERIFIED cases present in `Commands.swift`; `frame()` body retains `crc8(lenBytes)` + `crc32(inner)` (4.0-format preserved)
- `AppConfig.swift` not modified by this plan (IOS-07 offline mode preserved — `uploaderConfig()` untouched)
- `git diff --name-only` per task confirms only the 2 planned files changed

## Decisions Made

- **D-04:** In-place swap of the 5 custom UUIDs; no legacy dual-UUID branch (4.0 service is ABSENT on this device per FINDINGS_5.md §2, so a fallback would only slow scanning).
- **D-05:** The 10 VERIFIED codes are all present. For the non-verified cases, the plan offered two acceptable paths (remove, or retain-with-HYPOTHESIS-annotation when referenced). **Every** non-verified case turned out to be referenced — by production code (`BLEManager` handshake/raw-capture/alarm API, `SmartAlarmController`, `LiveViewModel`, `LiveView`) and/or by `OpenWhoopTests`. Per the plan's hard constraint "NAO quebrar compilacao por remocao de um case usado", they were retained and annotated rather than removed. No case was orphaned.
- `frame()` body left as 4.0 framing — outbound Maverick-wrapping is an OPEN QUESTION (Pitfall 4 / Open Question #1) deferred to on-device validation in 05-06.

## Deviations from Plan

### Auto-fixed Issues

None requiring a code fix.

### Notable execution choice (within plan-sanctioned options)

The plan's primary action wording for Task 2 listed many cases "to remove". A grep of the iOS source/test targets showed **all** of those cases are referenced (production or `OpenWhoopTests`), including the two with only test references (`reportVersionInfo`=7, `enableOpticalData`=107, both in `CommandsTests.swift`). Removing any would break compilation of the app or test target — explicitly forbidden by the task body and covered by the acceptance criterion that allows retaining-with-HYPOTHESIS-comment when referenced. Accordingly, no cases were removed; all non-verified cases were annotated. This is the documented, plan-sanctioned path, not an unrequested deviation.

## Reference Map (cases retained + reason)

| Case | Byte | Referenced by (outside Commands.swift) |
|------|------|----------------------------------------|
| reportVersionInfo | 7 | CommandsTests only |
| getAdvertisingNameHarvard | 76 | BLEManager handshake + tests |
| startRawData | 81 | BLEManager.captureRawAccel + tests |
| stopRawData | 82 | BLEManager.captureRawAccel + tests |
| enterHighFreqSync | 96 | SmartAlarmController + tests |
| toggleIMUMode | 106 | BLEManager.captureRawAccel + tests |
| enableOpticalData | 107 | CommandsTests only |
| runHapticsPattern | 79 | BLEManager.testAlarmBuzz, LiveViewModel |
| stopHaptics | 122 | LiveViewModel, LiveView |
| sendR10R11Realtime | 63 | BLEManager handshake |
| setAlarmTime/getAlarmTime/runAlarm/disableAlarm | 66/67/68/69 | BLEManager alarm API + tests |

## Known Stubs

None introduced by this plan. (Existing `frame()` 4.0-format is a deliberate pending-validation choice, not a stub — documented above and in the source.)

## Threat Surface

No new trust-boundary surface beyond the plan's `<threat_model>`. T-05-05-01 (BLE MITM) accepted — bonding mechanism unchanged. T-05-05-02 (destructive commands) — the enum continues to exclude DFU/REBOOT/POWER_CYCLE/FORCE_TRIM and all destructive codes; only non-destructive/reversible commands remain (the retained HYPOTHESIS cases are all safe/reversible). T-05-05-03 (hardcoded UUIDs) accepted — UUIDs are VERIFIED protocol constants with no external input. T-05-SC — zero new packages (CoreBluetooth is a system framework).

## Self-Check: PASSED

- FOUND: ios/OpenWhoop/BLE/BLEManager.swift (modified, contains FD4B0001, no 61080001/WHOOP 4.0)
- FOUND: ios/OpenWhoop/BLE/Commands.swift (modified, 10 VERIFIED present, frame() 4.0-format intact)
- FOUND: commit b223438 (Task 1)
- FOUND: commit 7f4405b (Task 2)
- FOUND: .planning/phases/05-ios-app-server-port/05-05-SUMMARY.md
