---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Complete iOS + UI + Algorithms
status: planning
last_updated: "2026-05-31T17:10:01.952Z"
last_activity: 2026-05-31
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# State — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)
**Last updated:** 2026-05-31 (v1.0 milestone closed)

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-31)

**Core value:** Own your WHOOP 5.0 biometric data — read it from your own device over BLE, store it locally, analyse it without WHOOP cloud dependency.

**Current focus:** v1.0 shipped. Planning next milestone (v2.0).

---

## Deferred Items

Items acknowledged and deferred at milestone close on 2026-05-31:

| Category | Item | Status |
|----------|------|--------|
| uat_gap | Phase 05 / 05-HUMAN-UAT.md — 3 scenarios | partial |
| uat_gap | Phase 02 / 02-HUMAN-UAT.md | partial |
| verification_gap | Phase 01 / 01-VERIFICATION.md | gaps_found |
| verification_gap | Phase 02 / 02-VERIFICATION.md | human_needed |
| verification_gap | Phase 05 / 05-VERIFICATION.md | human_needed |

**Root cause:** All gaps require physical hardware (iPhone with unsynced WHOOP data, Docker on CI, Android device) not available in the sandbox environment.

---

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-31 — Milestone v2.0 started

## Key Decisions (v1.0)

| # | Decision | Rationale | Outcome |
|---|----------|-----------|---------|
| 1 | Clean fork (not dual 4.0/5.0 support) | Protocol may differ enough to pollute 4.0 | ✓ Correct — Maverick wrapper required new strip_maverick path |
| 2 | Phase 3 as explicit CRC gate | All decoder work wasted if framing wrong | ✓ Critical — 0% pass rate triggered Maverick RE |
| 3 | Python discovery before Swift | Swift 10–100× slower for byte-level RE | ✓ Correct |
| 4 | Mac PacketLogger as primary capture | No jailbreak; captures full HCI | ✓ Correct |
| 5 | Skip RF sniffer (nRF52840) | HCI logs give decrypted GATT | ✓ Correct |
| 6 | D-11: 4.0 writes / Maverick reads asymmetry | Discovered in Phase 5 — WHOOP 5.0 writes accepted in 4.0 format | ✓ Resolved — key protocol insight |

---

*State refreshes after every plan completion and phase transition.*
