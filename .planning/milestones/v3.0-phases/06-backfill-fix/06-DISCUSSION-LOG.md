# Phase 6: Backfill Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-31
**Phase:** 06-backfill-fix
**Areas discussed:** Mecânica do gate FF, Fallback FF silencioso, Âmbito até DailyMetric, Verificação BF-02

---

## Mecânica do gate FF

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Remover o asyncAfter | Event-driven limpo: remover asyncAfter(1.5s) e chamar requestSync(.connect) de setFFValues() | ✓ |
| Manter asyncAfter + guard | Belt-and-suspenders: guard em beginBackfill absorve asyncAfter prematuro | |
| Tu decides | Ao critério do planner | |

**Escolha do utilizador:** Remover o asyncAfter (limpo e event-driven)

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Guard em beginBackfill() | Gate mais profundo — protege contra qualquer trigger | ✓ |
| Guard em requestSync() | Gate mais alto — mais visível mas pode mascarar ticks legítimos | |

**Escolha do utilizador:** Guard em `beginBackfill()` — mesmo nível que `connectHandshakeDone`

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Chamar requestSync(.connect) diretamente em setFFValues() | Direto, explícito, consistente com padrão existente | ✓ |
| Notificar via callback/closure | Mais testável mas adiciona indireção desnecessária | |

**Escolha do utilizador:** `setFFValues()` chama `requestSync(.connect)` diretamente

---

## Fallback FF silencioso

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Watchdog dedicado ao FF exchange | N segundos sem resposta → limpar pending + tentar backfill | ✓ |
| Deixar para o ciclo de reconnect | Mais simples; piora experiência em strap lento | |

**Escolha do utilizador:** Watchdog dedicado

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| 10 segundos | Curto, pode ser agressivo em link BLE lento | |
| 30 segundos | Equilibrado mas conservador | |
| Tu decides (15-30s) | Ao critério do planner | — |

**Escolha do utilizador:** 15 segundos (free-text — entre os dois extremos)

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Limpar pending + tentar backfill | Graceful fallback | ✓ |
| Limpar pending + não tentar | Conservador, aguarda próximo ciclo | |

**Escolha do utilizador:** Limpar + tentar backfill (graceful)

---

## Âmbito até DailyMetric

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Sim, full pipeline nesta fase | Backfill → upload → compute_day → pull → DailyMetric no GRDB | ✓ |
| Só frames recebidos | DailyMetric fica para Fase 7 | |

**Escolha do utilizador:** Full pipeline — Fase 6 valida o ciclo completo

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Verificar o código existente | exitBackfilling() já tem a chain; só validar | ✓ |
| Adicionar trigger explícito | Garantir que o Uploader corre após backfill | |

**Escolha do utilizador:** Verificar primeiro — não adicionar código se já funcionar

**Notas:** Confirmado no código: `exitBackfilling()` chama `uploadOpportunistically()` + `pullFromServer()` nas linhas 391–396. O pipeline já existe.

---

## Verificação BF-02

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| XCTest com SpyBackfillStore | Simular kill mid-ack; verificar safe-trim invariant | ✓ |
| Manual no iPhone | Force-quit durante backfill ativo | |
| Ambos | Unit test + UAT manual | |

**Escolha do utilizador:** XCTest com SpyBackfillStore

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| sqlite3 no Mac | Contar rows por dia após backfill | |
| Logs de debug na app | Log com range temporal dos chunks (primeiro/último unix) | ✓ |
| Tu decides | Ao critério do planner | |

**Escolha do utilizador:** Logs de debug — mais conveniente no dispositivo físico

---

| Opção | Descrição | Selecionada |
|-------|-----------|-------------|
| Manter BackfillPolicy sem mudança | lastBackfillAt nil → sempre passa | ✓ |
| Rever o floor para .connect | Verificar se 90s é demasiado curto | |

**Escolha do utilizador:** BackfillPolicy não muda — comportamento atual já correto

---

## Claude's Discretion

- Nomeação exata do DispatchWorkItem para o watchdog FF (sugestão: `ffExchangeTimeout`)
- Se o watchdog usa `asyncAfter` ou `DispatchSourceTimer`
- Ordem dos guards em `beginBackfill()` (sugestão: `connectHandshakeDone` antes de `!ffExchangePending`)
- Formato exato dos logs de range temporal nos chunks históricos

## Deferred Ideas

- UI views com dados reais (IOS-03/04/05) — Fase 7
- Verificação PROTO-11/12/13/14 — Fase 7
- Dual 4.0/5.0 support — fora de âmbito do fork
