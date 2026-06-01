---
status: partial
phase: 13-backend-parity
source: [13-VERIFICATION.md]
started: 2026-06-01T00:00:00Z
updated: 2026-06-01T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Pipeline server com DB real (ALG-11 + ALG-12)
expected: Após executar compute_day() com dados de 7+ noites reais, daily_metrics.training_state = 'OPTIMAL'/'RESTORATIVE'/'OVERREACHING' e daily_metrics.sleep_needed_min entre 300 e 660 min.
result: [pending]

### 2. iOS — CALORIES MetricCard
expected: TodayView exibe card CALORIES quando totalCaloriesKcal é não-nil (perfil com peso/altura/idade); esconde quando nil (sem perfil).
result: [pending]

### 3. iOS — StrainCard server-first Training State
expected: StrainCard mostra o trainingState vindo do servidor quando não-nil; cai para cálculo client-side quando nil.
result: [pending]

### 4. iOS — MetricKind.sleepPerformance gráfico retrocompatível
expected: Gráfico de Sleep Performance mostra sleepPerformance do servidor quando disponível, e fallback para efficiency*100 em dados históricos que não têm o campo.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
