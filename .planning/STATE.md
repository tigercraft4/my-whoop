---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
last_updated: "2026-05-30T13:05:06.598Z"
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
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

- **Milestone**: v1 — WHOOP 5.0 protocol decoded and iOS app functional
- **Phase**: Pre-Phase 1 (roadmap just initialized)
- **Plan**: None yet
- **Status**: Awaiting `/gsd:plan-phase 1`
- **Progress**: `[          ]` 0/5 phases complete

---

## Performance Metrics

- **Phases complete**: 0/5
- **Requirements complete**: 0/45
- **Validated artifacts**: 0
- **Golden fixtures**: 0

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

**Last session ended**: 2026-05-30 — roadmap initialized via `/gsd:new-project`.

**Next session should**: Run `/gsd:plan-phase 1` to plan the Capture Foundation phase (tools setup: PacketLogger + mobileconfig, Android HCI snoop, JADX-GUI, Wireshark).

**Files of interest for next session**:

- `.planning/ROADMAP.md` — phase structure and success criteria
- `.planning/REQUIREMENTS.md` — v1 requirements (TOOL-01..04 for Phase 1)
- `.planning/research/SUMMARY.md` — research context, especially "Recommended Stack" table

---

*State refreshes after every plan completion and phase transition.*
