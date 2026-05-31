# Phase 11: HealthKit Export - Discussion Log

> **Audit trail only.**

**Date:** 2026-05-31
**Phase:** 11-healthkit-export
**Areas discussed:** SpO₂ gate (PROTO-11), Auth request timing (HK-05), Highwater cursor para HR, Sleep stage mapping

---

## SpO₂ gate (PROTO-11 não VERIFIED)

| Option | Description | Selected |
|--------|-------------|----------|
| Omitir completamente na Phase 11 | Zero código SpO₂ HK; deferred no VERIFICATION.md | |
| Implementar mas desactivado (flag) | Guard removível quando PROTO-11 VERIFIED | |
| Claude decide | Abordagem ao critério do planeador | ✓ |

**User's choice:** Claude decide → planeador escolheu omitir completamente (dead code é pior que ausência)

---

## Auth request timing (HK-05)

| Option | Description | Selected |
|--------|-------------|----------|
| .task em TodayView quando dados existem | Lazy e contextual — só quando metrics.today != nil | ✓ |
| Primeiro app launch após backfill | Flag UserDefaults 'hkAuthRequested' | |

**User's choice:** .task em TodayView quando dados existem

| Option | Description | Selected |
|--------|-------------|----------|
| App continua normalmente, sem retry | HK-05 "degrada graciosamente" | |
| Banner subtil "Health not connected" | Banner não bloqueante, deep link para Settings | ✓ |

**User's choice:** Banner subtil "Health not connected" uma única vez

---

## Highwater cursor para HR export

| Option | Description | Selected |
|--------|-------------|----------|
| UserDefaults com keys "hk." | hk.hrHighwater, hk.hrvHighwater — simples e debugável | ✓ |
| WhoopStore GRDB cursors table | Reutiliza tabela existente | |

**User's choice:** UserDefaults com keys prefixadas "hk."

---

## Sleep stage mapping

| Option | Description | Selected |
|--------|-------------|----------|
| Light→asleepCore, Deep→asleepDeep, REM→asleepREM, Awake→awake | iOS 16+ directo | |
| Light→asleepUnspecified (iOS 14/15 compat) | Fallback para versões antigas | |
| Claude decide | Planeador decide com base no deployment target iOS 16+ | ✓ |

**User's choice:** Claude decide (iOS 16+ deployment target → planeador usa .asleepCore/.asleepDeep/.asleepREM)

| Option | Description | Selected |
|--------|-------------|----------|
| Delete + reinsert por sessão | HKHealthStore.deleteObjects antes de reexportar — idempotente | ✓ |
| Highwater por data de sessão | UserDefaults por sleep start date | |

**User's choice:** Delete + reinsert por sessão (idempotente)

---

## Claude's Discretion

- SpO₂ gate: omitir completamente vs placeholder (escolha: omitir)
- Stage mapping WHOOP → HealthKit (iOS 16+ → .asleepCore/.asleepDeep/.asleepREM)
- HealthKitExporter como actor vs class @MainActor
- Formato do banner "Health not connected"
- Trigger exacto do export (após pullDerived? Após backfill?)
- HRV: por sessão vs daily RMSSD

## Deferred Ideas

- HK-03 SpO₂ export → quando PROTO-11 VERIFIED
- HealthKit read
- Background sync
