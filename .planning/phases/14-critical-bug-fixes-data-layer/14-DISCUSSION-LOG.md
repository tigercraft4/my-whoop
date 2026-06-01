# Phase 14: Critical Bug Fixes (Data Layer) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-01
**Phase:** 14-Critical Bug Fixes (Data Layer)
**Areas discussed:** sleepNeededMin display, sleepPerformance fallback, headlineSection dead code, BUGFIX-03 test coverage

---

## sleepNeededMin — Onde Mostrar

| Option | Description | Selected |
|--------|-------------|----------|
| Verificar no IPA primeiro | Confirmar no Ghidra (Fase 15) onde o WHOOP app coloca sleep needed | — |
| Placeholder pragmático agora | 3ª coluna "SLEEP NEEDED" no SleepCard; Fase 17 ajusta após Ghidra | ✓ |
| Adiar para Fase 17 | BUGFIX-01 fica parcialmente pendente; só display na Fase 17 | — |

**User's choice:** Placeholder pragmático — 3ª coluna no SleepCard. Fase 17 ajusta.
**Notes:** Utilizador quis inicialmente "verificar no IPA" mas aceitou o pragmático porque Ghidra (Fase 15) vem a seguir e BUGFIX-01 precisa de algo visível agora.

---

## sleepPerformance — Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| "—" quando nil | Sem fallback para efficiency — honesto, sem confusão | ✓ |
| Fallback para efficiency calculada | Manter número mas pode enganar (efficiency ≠ sleepPerformance) | — |

**User's choice:** "—" quando `sleepPerformance` é nil.
**Notes:** Decisão clara — efficiency raw não é equivalente ao score composto; melhor mostrar dash.

---

## headlineSection — Código Morto

| Option | Description | Selected |
|--------|-------------|----------|
| Remover completamente | Nunca renderizada; simplifica o ficheiro | ✓ |
| Manter como referência interna | Não tem valor; compilador não avisa | — |

**User's choice:** Remover completamente.
**Notes:** SleepCard substituiu headlineSection. Eliminar também o TODO stale.

---

## BUGFIX-03 — Cobertura de Testes

| Option | Description | Selected |
|--------|-------------|----------|
| Teste completo de comportamento | Inserir dados corrompidos, correr migração, verificar limpeza | ✓ |
| Só verificar estrutura | Verificar apenas que a migração corre sem erro | — |

**User's choice:** Teste de comportamento completo — RR inválidos apagados, avgHrv = NULL.
**Notes:** Migration v10 já existe em Database.swift (linhas 184–193). O teste cobre os dois lados: delete de rrInterval e update de dailyMetric.

---

## Claude's Discretion

- Formato exacto do `sleepNeededMin` no SleepCard: "7h 30m" usando `formatMinutes()` já existente no SleepView (a ser extraído ou duplicado no SleepCard)

## Deferred Ideas

- Confirmação da posição exacta do "sleep needed" no WHOOP IPA (para Fase 15/17)
- Possível exibição de sleepNeededMin também no SleepView fora do SleepCard — avaliar após Ghidra
