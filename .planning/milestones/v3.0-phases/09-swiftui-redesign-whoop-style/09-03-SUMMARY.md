---
phase: 09-swiftui-redesign-whoop-style
plan: "09-03"
subsystem: ui
tags: [swiftui, recovery-card, today-view, zone-ring, whoop-style]

requires:
  - phase: 09-02
    provides: ZoneRingView component
provides:
  - RecoveryCard with ZoneRingView + HRV/RHR/SLEEP stats row
  - TodayView hero section replaced with RecoveryCard
affects:
  - verify-work (UI-03 testable after this plan)

tech-stack:
  added: []
  patterns:
    - "RecoveryCard(daily: DailyMetric?) pattern — optional input with nil → placeholder"
    - "NavigationLink wrapping RecoveryCard for detail tap-through"

key-files:
  created:
    - ios/OpenWhoop/Design/Components/RecoveryCard.swift
  modified:
    - ios/OpenWhoop/Tabs/TodayView.swift

key-decisions:
  - "RecoveryCard replaces both RecoveryRing and pendingRecoveryRing in heroSection — single component handles both states"
  - "NavigationLink to MetricDetailView(kind: .recovery) preserved — tapping ring still navigates to history"
  - "Stats row uses 3 columns: HRV / RHR / SLEEP — matches WHOOP iOS Tab 1 field layout"

patterns-established:
  - "Card pattern: Color.black background + WH.Radius.card cornerRadius"
  - "Stat column: label (cardTitle) + value (metricMedium) stacked vertically"

requirements-completed:
  - UI-03

duration: 14min
completed: 2026-05-31
---

# Plan 09-03: RecoveryCard — TodayView WHOOP-Style Summary

**RecoveryCard criado com ZoneRingView zone-colored e stats row (HRV/RHR/SLEEP); TodayView hero section substituída — fundo preto, placeholder "—" quando dados são nil**

## Performance

- **Duration:** 14 min
- **Started:** 2026-05-31T19:12:00Z
- **Completed:** 2026-05-31T19:26:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `RecoveryCard` criado: ZoneRingView (size 160, lineWidth 20) com cor por zona de recovery
- Stats row horizontal: HRV (ms) | RHR (bpm) | SLEEP (%) com separadores e `"—"` para nil
- Color.black background conforme D-12; WH.Radius.card corner radius
- `TodayView.heroSection` simplificado: RecoveryCard substitui RecoveryRing + pendingRecoveryRing
- NavigationLink para MetricDetailView(kind: .recovery) preservado
- Build: SUCCEEDED (0 errors)

## Task Commits

1. **Task 09-03-T1: Criar RecoveryCard.swift** - `743ade3` (feat)
2. **Task 09-03-T2: Integrar RecoveryCard na TodayView** - `5d49a46` (feat)

## Files Created/Modified
- `ios/OpenWhoop/Design/Components/RecoveryCard.swift` — novo card WHOOP-style com ZoneRingView
- `ios/OpenWhoop/Tabs/TodayView.swift` — heroSection simplificada, RecoveryCard integrado

## Decisions Made
- RecoveryCard encapsula tanto o estado com dados como o estado placeholder — elimina a necessidade de `pendingRecoveryRing` separado em TodayView
- Stats row: 3 colunas com Divider separadores (padrão WHOOP: HRV | RHR | SLEEP visíveis em linha)

## Deviations from Plan
None — plano executado exactamente como escrito.

## Issues Encountered
None.

## Self-Check: PASSED
- `RecoveryCard.swift` existe em `Design/Components/` ✓
- `RecoveryCard(daily: DailyMetric?)` aceita optional ✓
- `WH.Color.recoveryColor(forPercent:)` determina cor do anel ✓
- Campos nil → `"—"` ✓
- `.background(Color.black)` ✓
- `TodayView` referencia `RecoveryCard` na heroSection ✓
- NavigationLink para MetricDetailView(kind: .recovery) preservado ✓
- Build: SUCCEEDED ✓

## Next Phase Readiness
- UI-03 coberto; verify-work pode testar o RecoveryCard com dados reais de Phase 7

---
*Phase: 09-swiftui-redesign-whoop-style*
*Completed: 2026-05-31*
