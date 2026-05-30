---
phase: 01-capture-foundation
plan: "03"
subsystem: re-tooling
tags: [bluetooth, ble, hci, packetlogger, btsnoop, wireshark, jadx, evidence, gitignore]

# Dependency graph
requires:
  - phase: 01-capture-foundation/01-01
    provides: toolchain (Brewfile, check-tools.sh, gitignore/dir scaffolding, evidence/ dir)
  - phase: 01-capture-foundation/01-02
    provides: host analysis runbooks (wireshark.md, jadx.md)
provides:
  - ios-packetlogger.md (TOOL-01): PacketLogger + mobileconfig + Xcode pairing runbook
  - android-btsnoop.md (TOOL-02): HCI snoop + adb bugreport runbook
  - re/capture/README.md: four-runbook index + success-criterion -> evidence checklist
  - re/capture/evidence/2026-05-30-ios.*: committed iOS evidence triplet (1011 btatt packets, 0xAA SOF confirmed)
affects:
  - phase: 02-gatt-survey — consumes meta.yaml sidecar (firmware, service UUID, characteristic handles)
  - phase: 03-framing-confirmation — consumes inner_frame_sof + att_packet_count from sidecar

# Tech tracking
tech-stack:
  added:
    - PacketLogger (Apple "Additional Tools for Xcode" DMG — manual install, TOOL-01)
    - iOSBluetoothLogging.mobileconfig (Apple iPhone BT logging profile — manual install)
    - ideviceinfo (libimobiledevice — firmware/UDID metadata from iPhone)
    - adb bugreport (btsnoop_hci.log extraction, TOOL-02)
  patterns:
    - D-02 evidence triplet: redacted .hex + .sha256 + .meta.yaml committed; raw capture gitignored in samples/
    - Capture metadata sidecar schema: source/tool/firmware/raw_sha256/custom_service_uuid_seen/inner_frame_sof/att_packet_count/notes
    - gitignore policy: raw local + gitignored, committed counterpart (placeholder/redacted) annotated with WHY

key-files:
  created:
    - re/capture/ios-packetlogger.md (TOOL-01 runbook)
    - re/capture/android-btsnoop.md (TOOL-02 runbook)
    - re/capture/README.md (four-runbook index + evidence checklist)
    - re/capture/evidence/2026-05-30-ios.hex
    - re/capture/evidence/2026-05-30-ios.sha256
    - re/capture/evidence/2026-05-30-ios.meta.yaml
  modified: []

key-decisions:
  - "iOS-only capture accepted: no Android device available; android-btsnoop.md runbook is complete and the evidence triplet placeholder will be added when a device is available"
  - "0xAA SOF confirmed on all 1011 ATT payloads — 4.0 inner framing reuse on 5.0 strap validated by live capture"
  - "fd4b0001-... service family confirmed active (Phase 2 will enumerate UUIDs; handles 0x099b/0x099d/0x09a3 documented in meta.yaml)"
  - "Metadata sidecar schema established as Phase 2-3 contract: firmware, inner_frame_sof, att_packet_count pre-stages PROTO-16 and Phase 3 CRC gate"

patterns-established:
  - "Evidence triplet (D-02): every committed capture session gets .hex (redacted) + .sha256 + .meta.yaml; raw stays gitignored in samples/"
  - "Capture metadata sidecar: machine-readable YAML contract consumed by subsequent phases for firmware-per-session and framing analysis"
  - "Runbook doc style: dated header, Prerequisites table, numbered reproducible steps, 'How to verify it worked' non-empty-trace check, evidence workflow"
  - "Irreducible manual step tagging (D-03): Apple-UI steps tagged confirm-at-execution; checkpoint gate used for physical-device captures Claude cannot perform"

requirements-completed: [TOOL-01, TOOL-02]

# Metrics
duration: ~35min (execution) + human checkpoint (iOS capture)
completed: 2026-05-30
---

# Phase 1 Plan 03: Capture Runbooks + Live Capture + Evidence Summary

**iOS PacketLogger capture of live WHOOP 5.0 session confirmed 1011 btatt packets with 0xAA SOF on all ATT payloads; evidence triplet committed; four-runbook capture index with success-criterion checklist written**

## Performance

- **Duration:** ~35 min (automated tasks) + human checkpoint (iOS capture)
- **Started:** 2026-05-30
- **Completed:** 2026-05-30
- **Tasks:** 3 (Task 1: runbooks, Task 2: human checkpoint — approved, Task 3: README index)
- **Files modified:** 6 (2 runbooks, 3 evidence files, 1 README)

## Accomplishments

- Authored `ios-packetlogger.md` (TOOL-01) and `android-btsnoop.md` (TOOL-02) with precise, reproducible steps covering the irreducible Apple-UI manual steps (D-03 locked), D-02 evidence workflow, and non-empty-trace verification pointing to `wireshark.md`
- Human checkpoint delivered a live iOS `.pklg` of a WHOOP app to 5.0 strap session: 1011 btatt packets captured, 0xAA SOF present on all ATT payloads, `fd4b0001-...` characteristic family active on handles 0x099b / 0x099d / 0x09a3 — evidence triplet committed under `re/capture/evidence/`
- Wrote `re/capture/README.md` tying all four runbooks together (ios-packetlogger, android-btsnoop, wireshark, jadx) with the Phase 1 success-criterion to committed-evidence checklist, D-02 commit policy, and metadata sidecar schema as Phase 2–3 contract

## Task Commits

Each task was committed atomically:

1. **Task 1: Write ios-packetlogger.md and android-btsnoop.md** — `5b0debb` (docs) — on prior agent's branch; cherry-picked as `13f3cdc` into this worktree
2. **Task 2: Human checkpoint — iOS live capture** — `fc276d7` (evidence) — committed by user on `main` (1011 btatt packets, 0xAA SOF confirmed)
3. **Task 3: Write re/capture/README.md index** — `097a16f` (docs)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `re/capture/ios-packetlogger.md` — TOOL-01 runbook: PacketLogger + mobileconfig install, Xcode pairing, live HCI stream, ideviceinfo metadata, D-02 evidence workflow
- `re/capture/android-btsnoop.md` — TOOL-02 runbook: Developer Options HCI snoop (enable BEFORE session), adb bugreport extraction, btsnoop path (OEM-varying), evidence workflow
- `re/capture/README.md` — four-runbook index, success-criterion to evidence checklist, D-02/D-04 commit policy, sidecar schema
- `re/capture/evidence/2026-05-30-ios.hex` — redacted ATT payload hex excerpt (BD_ADDR scrubbed)
- `re/capture/evidence/2026-05-30-ios.sha256` — SHA256 of gitignored raw `.pklg`
- `re/capture/evidence/2026-05-30-ios.meta.yaml` — session sidecar: source, tool, firmware iOS 26.3.1, att_packet_count 1011, inner_frame_sof 0xAA confirmed

## Decisions Made

- **iOS-only capture accepted:** No Android device was available. The android-btsnoop.md runbook is complete and the evidence triplet will be added when a device is available. The iOS evidence alone satisfies the Phase 1 gate (0xAA SOF confirmed, non-empty ATT traffic).
- **0xAA SOF on all 1011 ATT payloads:** 4.0 inner framing reuse on the 5.0 strap confirmed. This is the key early finding that Phase 3 (CRC gate) will validate formally across ≥20 frames.
- **fd4b0001-... service family documented via characteristic handles:** The full service UUID was not captured in this session (GATT discovery phase = Phase 2). Handles 0x099b / 0x099d / 0x09a3 documented in the meta.yaml sidecar.
- **Sidecar schema as Phase 2–3 contract:** `inner_frame_sof` and `att_packet_count` pre-stage the Phase 3 CRC gate; `firmware` pre-stages PROTO-16 firmware-per-session.

## Deviations from Plan

### Deviation 1 — iOS-only capture (human checkpoint scope reduction)

- **Found during:** Task 2 (human checkpoint)
- **Situation:** No Android device was available for an Android btsnoop capture.
- **Action:** iOS capture proceeded and was approved (1011 btatt packets, 0xAA SOF). The android-btsnoop.md runbook is complete and the evidence placeholder in README.md is marked unchecked with a note explaining when it will be satisfied.
- **Impact:** Criterion 2 and 4 (Android btsnoop + JADX APK) remain open. Criterion 1 (iOS ATT traffic) and Criterion 3 (Wireshark filter confirmed) are complete. Phase 1 is considered satisfactorily closed for the iOS-primary path; Android evidence is a deferred item.

No auto-fix rules (1-3) were triggered. The iOS-only outcome is an explicit D-03 locked constraint (irreducible physical-device step), not an executor deviation.

---

**Total deviations:** 1 (human-checkpoint scope: iOS-only, no Android available)
**Impact on plan:** iOS path fully validated. Android runbook ready; evidence to be added when device available.

## Issues Encountered

- The Task 1 commit (`5b0debb`) landed on prior agent's worktree branch (`worktree-agent-adbcd537b62eb6100`) and was not yet merged to `main`. The new agent's worktree was fast-forward-merged from `main` and the runbook commit was cherry-picked (`13f3cdc`) before Task 3 executed. No content was lost.

## User Setup Required

**PacketLogger and mobileconfig were installed by the user as part of the human checkpoint.** Documented in `re/capture/ios-packetlogger.md`:

- PacketLogger.app installed from "Additional Tools for Xcode" DMG (Apple Developer Downloads)
- `iOSBluetoothLogging.mobileconfig` installed on iPhone via Settings
- iPhone paired and trusted in Xcode Devices window

No further external configuration required.

## Next Phase Readiness

- Phase 2 (GATT Survey & Bonding) can begin: `fd4b0001-...` service family active on 5.0 strap confirmed; Bleak bonding harness in `re/` ready; characteristic handles from evidence sidecar provide a starting point for GATT enumeration
- Phase 3 framing gate inputs pre-staged: `inner_frame_sof: 0xAA confirmed` and `att_packet_count: 1011` in the iOS sidecar; ≥20 distinct frames required for formal CRC validation
- Android evidence (Criterion 2, 4) remains open; can be completed in parallel with or before Phase 2 if a device becomes available

---
*Phase: 01-capture-foundation*
*Completed: 2026-05-30*
