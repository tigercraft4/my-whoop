---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: — Complete iOS + WHOOP-Style UI + Algorithms
status: planning
last_updated: "2026-05-31T23:29:02.406Z"
last_activity: 2026-05-31
progress:
  total_phases: 10
  completed_phases: 6
  total_plans: 23
  completed_plans: 21
  percent: 60
---

# State — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)
**Last updated:** 2026-05-31 (v2.0 roadmap created)

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-31)

**Core value:** Own your WHOOP 5.0 biometric data — read it from your own device over BLE, store it locally, analyse it without WHOOP cloud dependency.

**Current focus:** Phase 999.1 — follow up — phase 1 android device items (backlog)

---

## Current Position

Phase: 999.1
Plan: Not started
Status: Ready to plan
Last activity: 2026-05-31

Progress: [█████████░] 91%

---

## Accumulated Context

### Key Decisions (v2.0)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Phase 6 (backfill fix) is a hard gate | Every other v2.0 feature needs real data in the store |
| 2 | Phase 8 (JADX) runs in parallel with Phase 6 | Independent — no data dependency |
| 3 | HealthKit goes last (Phase 11) | Needs real store data AND stable view architecture |
| 4 | SpO₂ HealthKit export gated on PROTO-11 VERIFIED | Cannot export unvalidated biometric offsets |
| 5 | Algorithm pipeline is server-side only | Recovery/strain/sleep require multi-night baselines |

### Blockers / Concerns

- **BF-P1:** `connectHandshakeDone` invariant — any new `.withResponse` command must not bypass guard at BLEManager.swift line 804
- **HK-P1:** HealthKit entitlement + plist keys must be added BEFORE importing HealthKit framework
- **HK-P2:** Unit conversions are not optional — SpO₂ must be 0.0–1.0 (not 0–100) for HealthKit
- **PROTO-11/12/14:** Biometric stream correctness cannot be confirmed without working backfill + calibrated reference device

### Pending Todos

None yet.

---

## Deferred Items

Items acknowledged and deferred at v1.0 milestone close on 2026-05-31:

| Category | Item | Status |
|----------|------|--------|
| uat_gap | Phase 05 / 05-HUMAN-UAT.md — 3 scenarios | partial |
| uat_gap | Phase 02 / 02-HUMAN-UAT.md | partial |
| verification_gap | Phase 01 / 01-VERIFICATION.md | gaps_found |
| verification_gap | Phase 02 / 02-VERIFICATION.md | human_needed |
| verification_gap | Phase 05 / 05-VERIFICATION.md | human_needed |

Root cause: All gaps require physical hardware not available in sandbox.

---

## Session Continuity

Last session: 2026-05-31T23:29:02.398Z
Stopped at: Phase 11 context gathered — all phases discussed
Resume file: None
