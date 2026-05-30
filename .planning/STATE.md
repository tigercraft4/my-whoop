---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: ready_to_plan
last_updated: "2026-05-30T20:18:15.346Z"
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 15
  completed_plans: 12
  percent: 50
---

# State — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)
**Last updated:** 2026-05-30 (initialization)

---

## Project Reference

**Core value**: Own your WHOOP 5.0 biometric data — read it from your own device over BLE, store it locally, analyse it without WHOOP cloud dependency.

**Current focus**: Roadmap created. Ready to begin Phase 1 (Capture Foundation).

**Architectural framing**: Port of the validated 4.0 codebase. Inner BLE framing is reused unchanged; only the GATT UUID prefix changes (`fd4b0001-…` replaces `61080001-…`), with a probable Maverick outer wrapper. The whole roadmap pivots on the Phase 3 CRC gate.

---

## Current Position

Phase: 04 (protocol-decode-schema) — EXECUTING
Plan: 2 of 5

- **Milestone**: v1 — WHOOP 5.0 protocol decoded and iOS app functional
- **Phase**: 04 (protocol-decode-schema) — executing
- **Plan**: 04-02 complete (D-05 biometric capture inventory); next is the remaining Phase 4 plans
- **Status**: Phase 4 in progress (2 of 5 plans summarised)
- **Progress**: `[######    ]` 3/5 phases complete

---

## Performance Metrics

- **Phases complete**: 0/5 (Phase 4 in progress: 2/5 plans summarised)
- **Requirements complete**: 12/45
- **Validated artifacts**: 1 (re/capture/evidence/2026-05-30-biometric-5.meta.yaml — D-05 biometric capture inventory)
- **Golden fixtures**: 0

| Phase-Plan | Duration | Tasks | Files | Completed |
|-----------|----------|-------|-------|-----------|
| 04-02 | ~12min | 2 | 1 | 2026-05-30 |

---

## Accumulated Context

### Key Decisions

| # | Decision | Rationale | When |
|---|----------|-----------|------|
| 1 | Coarse granularity (5 phases) | Technical RE project with hard dependency chain; over-decomposing hides the critical CRC gate | Init |
| 2 | Phase 3 as explicit critical gate | All decoder work is wasted if framing is wrong; isolating the validation step protects downstream phases | Init |
| 3 | Python discovery loop before Swift | Swift iteration is 10–100× slower for byte-level RE; CoreBluetooth requires physical device per build | Init |
| 4 | Clean fork (not dual 4.0/5.0 support) | Protocol may differ enough to pollute 4.0 codebase before understanding 5.0 | PROJECT.md |
| 5 | Mac PacketLogger as primary capture | No jailbreak needed; captures full HCI post-decryption; Apple-native | PROJECT.md |
| 6 | Skip RF sniffer (nRF52840) | HCI logs already give decrypted GATT; RF sniffers see ciphertext without LTK on bonded links | Research |

### Open Todos

- [ ] Run `/gsd:plan-phase 1` to decompose Capture Foundation into actionable plans

### Active Blockers

None.

### Known Risks

1. **Phase 3 CRC may fail** → Maverick wrapper is heavier than expected, Phase 3 expands significantly. Mitigation: research already identified whoop-vault as a Maverick reference; budget for wrapper RE in Phase 3 contingency.
2. **WHOOP firmware drift** → enums in whoop-vault (r52) may differ from user's installed firmware. Mitigation: PROTO-16 records firmware version in every capture; flag schema drift on every reconnect.
3. **Historical offload data loss** → ack-before-persist is the canonical RE pitfall. Mitigation: enforce store → fsync → ack in Phase 4 success criterion 3 with intentional kill test.
4. **CoreBluetooth state restoration edge cases** → background reconnect after force-quit is iOS's hardest BLE scenario. Mitigation: explicit IOS-08 success criterion in Phase 5.

---

## Session Continuity

**Last session ended**: 2026-05-30 — completed Plan 04-02 (D-05 biometric capture extracted + evidence sidecar finalised).

**Next session should**: Continue Phase 4 with the remaining plans (Wave 3 biometric decode consumes the 04-02 capture inventory). Note the PROTO-14 risk: raw IMU (REALTIME_RAW_DATA type 43) is NOT in capture_all-V3.pklg — schedule a dedicated TOGGLE_IMU_MODE capture if raw IMU is required.

**Files of interest for next session**:

- `.planning/phases/04-protocol-decode-schema/04-02-SUMMARY.md` — D-05 capture inventory + Wave 3 inputs/risks
- `re/capture/evidence/2026-05-30-biometric-5.meta.yaml` — finalised redacted evidence sidecar
- `re/survey_5/decode_5.py` / `validate_frames_5.py` — the decode primitives Wave 3 builds on
- `.planning/ROADMAP.md` — phase structure and success criteria

---

*State refreshes after every plan completion and phase transition.*

## Decisions

- [Phase ?]: 04-02: D-05 capture confirms REALTIME_DATA type40 HR/RR + sleep-review backfill present; raw IMU type43 absent (PROTO-14 Wave3 risk)
