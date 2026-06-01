---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: — WHOOP Parity
status: executing
last_updated: "2026-06-01T11:03:20.338Z"
last_activity: 2026-06-01
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 7
  completed_plans: 7
  percent: 50
---

# State — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)
**Last updated:** 2026-06-01 (Phase 12 complete — Phase 13 next)

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-31)

**Core value:** Own your WHOOP 5.0 biometric data — read it from your own device over BLE, store it locally, analyse it without WHOOP cloud dependency.

**Current focus:** Phase 13 — backend-parity

---

## Current Position

Phase: 13 (backend-parity) — COMPLETE (4 of 4 plans)
Plan: 4 of 4 (13-04 complete)
Status: Phase 13 complete — ready for verification
Last activity: 2026-06-01 -- 13-04 executed (ALG-13 calories + iOS field propagation)

Progress: [██████████] 100%

---

## Accumulated Context

### Key Decisions (v2.0 / v3.0)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Phase 6 (backfill fix) is a hard gate | Every other v2.0 feature needs real data in the store |
| 2 | Phase 8 (JADX) runs in parallel with Phase 6 | Independent — no data dependency |
| 3 | HealthKit goes last (Phase 11) | Needs real store data AND stable view architecture |
| 4 | SpO₂ HealthKit export gated on PROTO-11 VERIFIED | Cannot export unvalidated biometric offsets |
| 5 | Algorithm pipeline is server-side only | Recovery/strain/sleep require multi-night baselines |
| 6 | Training State iOS side uses bundled lookup table | Server computes recovery; iOS derives zone from recovery_to_strain.json |
| 7 | Haptics Gen5 deferred to hardware session | DRV2605 payload requires PacketLogger capture — buzz-nao-funciona.md has root cause |

### Blockers / Concerns

- **BF-P1:** `connectHandshakeDone` invariant — any new `.withResponse` command must not bypass guard at BLEManager.swift line 804
- **HK-P1:** HealthKit entitlement + plist keys must be added BEFORE importing HealthKit framework
- **HK-P2:** Unit conversions are not optional — SpO₂ must be 0.0–1.0 (not 0–100) for HealthKit
- **PROTO-11/12/14:** Biometric stream correctness cannot be confirmed without working backfill + calibrated reference device
- **Haptics:** Gen5 uses `RunAppDrivenHapticsCommandPacket` with DRV2605 waveform effects — command `0203000000` confirmed NOT working on WHOOP 5.0 (see .planning/debug/buzz-nao-funciona.md)

### Pending Todos

None.

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

Items deferred from Phase 12 (hardware-dependent):

| Category | Item | Status |
|----------|------|--------|
| criterion_gap | Phase 12 / Haptics Gen5 PacketLogger capture | hardware_needed |
| backlog | Phase 999.1 — Android device BLE capture | hardware_needed |
| backlog | Phase 999.2 — v1.0 hardware validation | hardware_needed |

Root cause: All gaps require physical hardware not available in sandbox.

---

## Session Continuity

Last session: 2026-06-01T11:03:20.333Z
Stopped at: Completed 13-04-PLAN.md
Resume file: None

## Decisions

- [Phase 13]: RMR usa Mifflin-St Jeor (_MIFFLIN_COEFFS) distinto do Harris-Benedict (_COEFFS, burn por bout)
- [Phase 13]: iOS display server-first com fallback client-side (trainingState, sleepPerformance) para linhas pre-Fase-13

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 13 P04 | 25 | 2 tasks | 9 files |
