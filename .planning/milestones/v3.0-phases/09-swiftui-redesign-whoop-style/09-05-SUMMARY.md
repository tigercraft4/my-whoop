---
phase: 09-swiftui-redesign-whoop-style
plan: "09-05"
subsystem: ui
tags: [swiftui, strain-card, strain-view, root-tab-view, whoop-style]

requires:
  - phase: 09-02
    provides: ZoneRingView component
  - phase: 09-01
    provides: RootTabView @SceneStorage + tab structure
provides:
  - StrainCard with ZoneRingView (0-21, strainAccent) + RESTORATIVE/OPTIMAL/OVERREACHING label
  - StrainView = StrainCard hero + workouts list
  - RootTabView Strain tab uses StrainView (not WorkoutsView placeholder)
affects:
  - verify-work (UI-05 testable after this plan)

tech-stack:
  added: []
  patterns:
    - "Strain zone classification: <10 RESTORATIVE / 10-17 OPTIMAL / >17 OVERREACHING"
    - "StrainView reuses MetricsRepository.workouts() from WorkoutsView — no code duplication of logic"

key-files:
  created:
    - ios/OpenWhoop/Design/Components/StrainCard.swift
    - ios/OpenWhoop/Tabs/StrainView.swift
  modified:
    - ios/OpenWhoop/App/RootTabView.swift

key-decisions:
  - "StrainCard uses WH.Color.strainAccent (not strainBlue) — alias from plan 09-01 is now in use"
  - "DailyMetric has no HR zone breakdown — zone label derived from strain score thresholds (WHOOP canonical zones)"
  - "StrainView copies workout list UI from WorkoutsView — avoids tight coupling while maintaining parity"
  - "WorkoutsView.swift is NOT deleted — still available if needed; Strain tab now uses StrainView"

patterns-established:
  - "Strain zone label: switch on Double range with <10 / 10...17 / default (>17)"

requirements-completed:
  - UI-05

duration: 18min
completed: 2026-05-31
---

# Plan 09-05: StrainCard + StrainView — Tab Strain WHOOP-Style Summary

**StrainCard com ZoneRingView 0-21 (strainAccent) e zona RESTORATIVE/OPTIMAL/OVERREACHING criado; StrainView = StrainCard + lista de workouts; RootTabView tab Strain usa StrainView**

## Performance

- **Duration:** 18 min
- **Started:** 2026-05-31T19:12:00Z
- **Completed:** 2026-05-31T19:30:00Z
- **Tasks:** 3
- **Files modified:** 1 (RootTabView.swift)
- **Files created:** 2 (StrainCard.swift, StrainView.swift)

## Accomplishments
- `StrainCard` criado: ZoneRingView com strainAccent, maxValue 21, zona label dinâmico
- `StrainView` criado: StrainCard hero + workouts section + NavigationStack, dark mode, refresh
- `RootTabView` actualizado: WorkoutsView placeholder → StrainView() na tab "strain"
- `strainBadge` em StrainView usa `WH.Color.strainAccent` (consistente com StrainCard)
- DailyMetric sem HR zones → zona label derivada de thresholds WHOOP canónicos
- Build: SUCCEEDED (0 errors)

## Task Commits

1. **Task 09-05-T1: Criar StrainCard.swift** - `ca3fe03` (feat)
2. **Task 09-05-T2: Criar StrainView.swift** - `e0fcf23` (feat)
3. **Task 09-05-T3: Actualizar RootTabView para StrainView** - `c16e53c` (feat)

## Files Created/Modified
- `ios/OpenWhoop/Design/Components/StrainCard.swift` — novo card com ZoneRingView 0-21
- `ios/OpenWhoop/Tabs/StrainView.swift` — novo view: StrainCard + lista de workouts
- `ios/OpenWhoop/App/RootTabView.swift` — WorkoutsView → StrainView no tab "strain"

## Decisions Made
- `DailyMetric` não tem HR zone breakdown → zona RESTORATIVE/OPTIMAL/OVERREACHING derivada dos thresholds WHOOP (< 10, 10-17, > 17) — suficiente para UI-05
- StrainView copia a lógica de workout list de WorkoutsView (não usa herança ou composição) — mais simples e mantém independência das duas views
- `WH.Color.strainAccent` usado no strainBadge da StrainView para consistência com StrainCard

## Deviations from Plan
None — plano executado exactamente como escrito. A ausência de HR zones em DailyMetric foi antecipada no plano; apenas zona label por threshold (confirmado).

## Issues Encountered
None.

## Self-Check: PASSED
- `StrainCard.swift` existe em `Design/Components/` ✓
- `ZoneRingView` com maxValue 21 e `WH.Color.strainAccent` ✓
- Zona labels: RESTORATIVE / OPTIMAL / OVERREACHING ✓
- `.background(Color.black)` ✓
- `StrainView.swift` existe em `Tabs/` ✓
- `StrainCard(daily: metrics.today)` no topo do scrollContent ✓
- `RootTabView` usa `StrainView()` na tab "strain" ✓
- `WorkoutsView.swift` não eliminado ✓
- Build: SUCCEEDED ✓

## Next Phase Readiness
- UI-05 coberto; Strain tab totalmente funcional
- Wave 3 completa — todas as 3 cards WHOOP-style implementadas
- Phase 9 pronta para verificação

---
*Phase: 09-swiftui-redesign-whoop-style*
*Completed: 2026-05-31*
