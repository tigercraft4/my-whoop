---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: — WHOOP Parity
status: planning
last_updated: "2026-06-01T19:04:58.663Z"
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

**Current focus:** Phase 999.1 — follow up — phase 1 android device items (backlog)

---

## Current Position

Phase: 999.1 of 4 (follow up — phase 1 android device items (backlog))
Plan: Not started
Status: Ready to plan
Last activity: 2026-06-01

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
| 5 | Algorithm pipeline é local (offline-first) | Session 2026-06-01: ALG-10..13 + Recovery + Strain portados para LocalMetricsComputer Swift |
| 6 | Training State iOS side usa bundled lookup table | recovery_to_strain.json bundled; computado localmente |
| 7 | Haptics Gen5 VERIFICADO via PacketLogger 2026-06-01 | Payload real: [0x01, 0x2F, 0x98, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00] — confirmado por HAPTICS_FIRED evento 60 |
| 8 | Maverick CRC32 trailer obrigatório | WHOOP 5.0 descarta silenciosamente frames com trailer errado. CRC32(body[4:]) LE. |
| 9 | Maverick token determinístico por payload_len | lookup table: pl=1→01E671, pl=9→01E0D1, pl=65→01F3B1, etc. |
| 10 | endData offset é Maverick não Gen4 | frame[21:29] não frame[17:25] — bug corrigido em 2026-06-01 (trim sempre=60 → cursor nunca avançava) |
| 11 | Servidor é backup only | pullFromServer() e restoreFromServerIfNeeded() desactivados; LocalMetricsComputer é única fonte de verdade |

### Blockers / Concerns (actualizados 2026-06-01)

- **BF-P1:** RESOLVIDO — handshake movido para `didUpdateNotificationStateFor` (FD4B0003 confirmado antes dos comandos)
- **HK-P1:** HealthKit entitlement + plist keys must be added BEFORE importing HealthKit framework
- **HK-P2:** Unit conversions are not optional — SpO₂ must be 0.0–1.0 (not 0–100) for HealthKit
- **PROTO-11/12/14:** Backfill agora funciona (sync confirmado com 16000+ frames type=47). Validação de biométricos ainda pendente.
- **Haptics:** RESOLVIDO — payload verificado via PacketLogger 2026-06-01. Alarme às 9h disparou buzz, capturado evento 60+100.
- **Sync-Repeat:** RESOLVIDO — endData offset corrigido (frame[21:29]). Trim cursor agora avança corrrectamente.

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

Last session: 2026-06-01T19:04:58.654Z
Stopped at: Phase 999.1 context gathered
Resume file: .planning/phases/999.1-follow-up-phase-1-android-device-items-backlog/999.1-CONTEXT.md

## Decisions

- [Phase 13]: RMR usa Mifflin-St Jeor (_MIFFLIN_COEFFS) distinto do Harris-Benedict (_COEFFS, burn por bout)
- [Phase 13]: iOS display server-first com fallback client-side (trainingState, sleepPerformance) para linhas pre-Fase-13

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 13 P04 | 25 | 2 tasks | 9 files |
