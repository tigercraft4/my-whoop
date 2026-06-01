---
phase: 09-swiftui-redesign-whoop-style
plan: "09-04"
subsystem: ui
tags: [swiftui, sleep-card, sleep-view, hypnogram, whoop-style]

requires:
  - phase: 09-02
    provides: ZoneRingView component (not used directly, but establishes card pattern)
provides:
  - SleepCard with HypnogramView + HOURS OF SLEEP + SLEEP PERFORMANCE
  - SleepView hero section replaced with SleepCard
affects:
  - verify-work (UI-04 testable after this plan)

tech-stack:
  added: []
  patterns:
    - "SleepCard(session: CachedSleepSession?, daily: DailyMetric?) — dual optional source of truth"
    - "Efficiency fallback chain: DailyMetric.efficiency → session.efficiency → '—'"

key-files:
  created:
    - ios/OpenWhoop/Design/Components/SleepCard.swift
  modified:
    - ios/OpenWhoop/Tabs/SleepView.swift

key-decisions:
  - "SleepCard prefers DailyMetric.efficiency (server-computed includes sleep need) over session.efficiency"
  - "HOURS OF SLEEP uses DailyMetric.totalSleepMin as primary; falls back to endTs-startTs (total time in bed) from session"
  - "headlineSection and standalone HypnogramView replaced by SleepCard — single hero component"
  - "Stage breakdown, in-sleep signals, 7-night chart, alarm card preserved below SleepCard"

patterns-established:
  - "Dual-source card: prefers DailyMetric, falls back to CachedSleepSession for missing fields"

requirements-completed:
  - UI-04

duration: 12min
completed: 2026-05-31
---

# Plan 09-04: SleepCard — SleepView WHOOP-Style Summary

**SleepCard criado com HypnogramView integrada e stats (HOURS OF SLEEP/SLEEP PERFORMANCE); SleepView hero section substituída — fundo preto, placeholder "No sleep data" quando session é nil**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-31T19:12:00Z
- **Completed:** 2026-05-31T19:24:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `SleepCard` criado: 2-column stats row (HOURS OF SLEEP | SLEEP PERFORMANCE) + HypnogramView
- Fallback chain correcta para efficiency e duração de sono
- Color.black background; HypnogramView inline quando session disponível
- `SleepView.scrollContent`: headlineSection e HypnogramView standalone substituídos por SleepCard
- Stage breakdown, in-sleep signals, 7-night chart, alarm card preservados abaixo
- Build: SUCCEEDED (0 errors)

## Task Commits

1. **Task 09-04-T1: Criar SleepCard.swift** - `fed6cf2` (feat)
2. **Task 09-04-T2: Integrar SleepCard na SleepView** - `3eafd80` (feat)

## Files Created/Modified
- `ios/OpenWhoop/Design/Components/SleepCard.swift` — novo card WHOOP-style com HypnogramView
- `ios/OpenWhoop/Tabs/SleepView.swift` — hero section simplificada com SleepCard

## Decisions Made
- `DailyMetric.efficiency` preferida sobre `session.efficiency` (mais precisa — inclui sleep need do servidor)
- HOURS OF SLEEP: `DailyMetric.totalSleepMin` é mais fiável que `endTs - startTs` (que inclui tempo acordado na cama)

## Deviations from Plan
None — plano executado exactamente como escrito.

## Issues Encountered
None.

## Self-Check: PASSED
- `SleepCard.swift` existe em `Design/Components/` ✓
- `SleepCard(session: CachedSleepSession?, daily: DailyMetric?)` ✓
- `HypnogramView` usado internamente ✓
- `.background(Color.black)` ✓
- `"—"` placeholder para nil ✓
- `SleepView` referencia `SleepCard` ✓
- Build: SUCCEEDED ✓

## Next Phase Readiness
- UI-04 coberto; verify-work pode testar SleepCard com dados reais

---
*Phase: 09-swiftui-redesign-whoop-style*
*Completed: 2026-05-31*
