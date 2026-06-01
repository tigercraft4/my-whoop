---
phase: 14
plan: 14-01
title: "Fix SleepCard & RecoveryCard — sleepNeededMin + sleepPerformance"
status: complete
completed: 2026-06-01
subsystem: iOS Views
tags: [bugfix, sleep-card, recovery-card, sleep-view, data-layer]
key-files:
  created: []
  modified:
    - ios/OpenWhoop/Design/Components/SleepCard.swift
    - ios/OpenWhoop/Design/Components/RecoveryCard.swift
    - ios/OpenWhoop/Tabs/SleepView.swift
metrics:
  tasks_completed: 3
  tasks_total: 3
  commits: 3
---

## Summary

Executado plano 14-01 com 3 tarefas. Build SUCCEEDED sem erros nem warnings.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 14-01-T1 | 8bf8001 | fix(14-01): BUGFIX-01+02 — SleepCard: add SLEEP NEEDED column, replace efficiency→sleepPerformance |
| 14-01-T2 | a70d33f | fix(14-01): BUGFIX-02 — RecoveryCard: replace efficiency→sleepPerformance in sleepLabel |
| 14-01-T3 | f64da42 | refactor(14-01): remove dead SleepView.headlineSection + stale TODO |

## What Was Built

### BUGFIX-01 (D-01, D-02)
`SleepCard` agora tem 3 colunas de estatística: "HOURS OF SLEEP" | "SLEEP PERFORMANCE" | "SLEEP NEEDED".
- A 3ª coluna lê `daily?.sleepNeededMin` (ALG-12) e formata com `formatMinutes()` → "7h 30m"
- Helper `formatMinutes()` adicionado como método privado a `SleepCard`
- Quando `sleepNeededMin` é nil, mostra "—"

### BUGFIX-02 (D-04, D-05, D-06)
- `SleepCard.sleepPerformanceLabel`: lê `daily?.sleepPerformance` (ALG-10, 0–100) em vez de `daily?.efficiency` (raw 0.0–1.0). Sem fallback para `efficiency`. "—" quando nil.
- `RecoveryCard.sleepLabel`: lê `daily?.sleepPerformance` em vez de `daily?.efficiency`. Formato: `Int($0.rounded())%`. Sem multiplicação por 100.

### Dead-code removal (D-07)
`SleepView.headlineSection` — computed property de ~70 linhas nunca referenciada em `scrollContent` — removida completamente. O TODO stale `// TODO: server-side sleep performance/need/debt` também foi eliminado.

## Deviations

Nenhum. Todos os critérios de aceitação verificados:
- `daily?.efficiency` não aparece nas computed properties de display de nenhum dos dois cards (a única referência restante em SleepCard.swift é no preview `DailyMetric(... efficiency: 0.87 ...)`, que é o parâmetro do init da struct — não uma leitura de display)
- `headlineSection` não existe em SleepView.swift
- Build SUCCEEDED (iOS Simulator iPhone 17 Pro, iOS 26.5)

## Self-Check: PASSED

- [x] BUGFIX-01: sleepNeededMin visível como "SLEEP NEEDED" no SleepCard
- [x] BUGFIX-02: SleepCard e RecoveryCard lêem sleepPerformance (não efficiency)
- [x] D-07: headlineSection removida, scrollContent intacto
- [x] Build SUCCEEDED sem erros
