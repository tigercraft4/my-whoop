# Phase 10: Algorithms Display + Server Endpoint - Discussion Log

> **Audit trail only.**

**Date:** 2026-05-31
**Phase:** 10-algorithms-display-server-endpoint
**Areas discussed:** /v1/today endpoint, Staleness indicator (6h), Local vs server algorithm

---

## /v1/today endpoint

**Context:** /v1/daily já existe com from/to range. /v1/today é semanticamente diferente — row mais recente sem edge case de UTC no client (ALG-04).

| Option | Description | Selected |
|--------|-------------|----------|
| Row mais recente (ORDER BY day DESC LIMIT 1) | Nunca null se tiver dados | |
| Row do dia UTC actual (day=current_date) | Pode ser null se hoje não computado | |
| Claude decide | Planeador decide | ✓ |

**User's choice:** Claude decide — semântica ao critério do planeador

---

## Staleness indicator (6h)

**Context:** StalenessPolicy.staleAfterSeconds = 6*3600 já existe. TodayView linha 326 já usa lastRefreshedAt. O que falta é o label visual no RecoveryCard.

| Option | Description | Selected |
|--------|-------------|----------|
| Label de texto subtil "Updated Xh ago" | Abaixo do score, não intrusivo | ✓ |
| Badge/chip laranja no canto | Mais visível, mais agressivo | |
| Claude decide | | |

**User's choice:** Label de texto subtil abaixo do score

---

## Local vs server algorithm

| Option | Description | Selected |
|--------|-------------|----------|
| Servidor sempre ganha quando disponível | Server > LocalMetricsComputer | ✓ |
| Local como fallback temporário | Mostrar local, substituir pelo server | |
| Claude decide | | |

**User's choice:** Servidor ganha quando disponível; LocalMetricsComputer permanece como fallback offline

---

## Claude's Discretion

- Semântica exacta de /v1/today (row mais recente vs UTC actual)
- Formato do staleness label
- Localização exacta do label no RecoveryCard
- Enum DataSource ou condicional inline para precedência
