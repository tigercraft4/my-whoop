# Phase 9: SwiftUI Redesign WHOOP-Style - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.

**Date:** 2026-05-31
**Phase:** 09-swiftui-redesign-whoop-style
**Areas discussed:** Tab bar estrutura, Recovery score ring, Strain tab scope, Paleta WHOOP-style

---

## Tab bar estrutura

| Option | Description | Selected |
|--------|-------------|----------|
| Strain substitui Workouts completamente | Tab renomeada, WorkoutsView substituída | |
| Strain no topo, Workouts em baixo | StrainCard + WorkoutsView composta | |
| Claude decide | Estrutura ao critério do planeador | ✓ |

**User's choice:** Claude decide — WorkoutsView reutilizada dentro do StrainView (planeador decide estrutura)

| Option | Description | Selected |
|--------|-------------|----------|
| Today / Sleep / Strain / Trends / Device (ROADMAP order) | Segue ordem do ROADMAP | ✓ |
| Today / Strain / Sleep / Trends / Device | Strain mais prominente | |
| Claude decide | | |

**User's choice:** Today / Sleep / Strain / Trends / Device (ROADMAP order)

---

## Recovery score ring

| Option | Description | Selected |
|--------|-------------|----------|
| Canvas com Shape arc | Custom Shape SwiftUI Canvas | |
| Gauge SwiftUI (iOS 16+) | SwiftUI Gauge .accessoryCircularCapacity | |
| Claude decide | Implementação ao critério do planeador | ✓ |

**User's choice:** Claude decide

| Option | Description | Selected |
|--------|-------------|----------|
| WHOOP standard: 0–33 red, 34–66 yellow, 67–100 green | Standard WHOOP thresholds | ✓ |
| Claude decide (ajustar com JADX reference) | | |

**User's choice:** WHOOP standard: 0–33 red, 34–66 yellow, 67–100 green (locked)

---

## Strain tab scope

| Option | Description | Selected |
|--------|-------------|----------|
| Strain card do dia + lista de workouts abaixo | StrainCard no topo + WorkoutsView abaixo | ✓ |
| Apenas Strain card | Sem lista de workouts | |
| Claude decide | | |

**User's choice:** Strain card do dia + lista de workouts abaixo

| Option | Description | Selected |
|--------|-------------|----------|
| Anel circular tipo Recovery | Mesmo componente parametrizado | ✓ |
| Barra progress horizontal | Mais simples | |
| Claude decide | | |

**User's choice:** Anel circular tipo Recovery (Recomendado)

---

## Paleta WHOOP-style

| Option | Description | Selected |
|--------|-------------|----------|
| Adicionar ao WH.Color existente | WH.Color.recoveryGreen/Yellow/Red + strainAccent | ✓ |
| Hardcoded apenas nos novos cards | Color literals directos | |
| Claude decide | | |

**User's choice:** Adicionar ao WH.Color existente em DesignTokens.swift

| Option | Description | Selected |
|--------|-------------|----------|
| Preto puro (#000) nos novos cards WHOOP-style | Cards WHOOP = preto; resto mantém sistema | ✓ |
| Preto puro em toda a app | Dark mode forçado em tudo | |
| Claude decide | | |

**User's choice:** Preto puro apenas nos novos cards WHOOP-style

---

## Claude's Discretion

- Implementação exacta do anel (Canvas Shape vs SwiftUI Gauge)
- Cor exacta do WH.Color.strainAccent (consultar docs/whoop-ui-reference.md)
- Hex codes exactos das cores WHOOP
- Ícones exactos das tabs
- Estrutura interna do StrainView (WorkoutsView reutilizada vs wrappada)

## Deferred Ideas

- Algoritmos Recovery/Strain/Sleep nas views → Phase 10
- HealthKit export → Phase 11
- Redesign Device/Settings tab
- Animações de entrada dos cards
