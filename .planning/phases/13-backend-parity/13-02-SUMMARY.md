---
phase: 13-backend-parity
plan: 02
subsystem: server-analysis-pipeline
tags: [algorithm, sleep, alg-10, daily-metrics, tdd]
requires:
  - daily_metrics.sleep_performance column (REAL)  # provided by 13-01
provides:
  - sleep.sleep_performance_score() pure function (0..100)
  - daily.compute_day writes metrics['sleep_performance']
affects:
  - 13-03 (ALG-12 Sleep Needed — substituirá sleep_needed_min=None nesta chamada)
  - iOS Today view (lerá sleep_performance via /v1/today em vez de efficiency*100)
tech-stack:
  added: []
  patterns:
    - Função pura sem DB para algoritmo derivado, chamada a partir de compute_day
    - No-sleep short-circuit (TST<=0 -> 0.0) + divide-by-zero guards via max(..,1.0)
key-files:
  created:
    - .planning/phases/13-backend-parity/13-02-SUMMARY.md
  modified:
    - server/ingest/app/analysis/sleep.py
    - server/ingest/app/analysis/daily.py
    - server/ingest/tests/test_sleep.py
decisions:
  - "No-sleep short-circuit (TST<=0 -> 0.0): a fórmula literal do plano dava 10.0 para TST=0 (W_con premeia '0 perturbações' mesmo sem sono). O must-have 'retorna 0 para TST=0' é autoritativo — Rule 1."
  - "sleep_needed_min=None por agora (fallback 420 min); ALG-12 do Plano 13-03 fornecerá o valor personalizado."
  - "sleep_perf (efficiency 0..1) para recovery_score mantida intacta — sleep_performance é coluna separada."
metrics:
  duration: ~12m
  completed: 2026-06-01
  tasks: 2
  files: 3
---

# Phase 13 Plan 02: Sleep Performance (ALG-10) Summary

Implementação do algoritmo ALG-10 Sleep Performance: nova função pura `sleep_performance_score()` em `sleep.py` (score composto 0–100 com pesos W_dur=0.45 / W_eff=0.25 / W_stg=0.20 / W_con=0.10) e integração em `compute_day()` de `daily.py`, preenchendo a coluna `daily_metrics.sleep_performance` criada no Plano 13-01.

## What Was Built

- **server/ingest/app/analysis/sleep.py** — nova função pública e pura `sleep_performance_score(total_sleep_min, efficiency, deep_min, rem_min, disturbances, sleep_needed_min=None) -> float`, inserida imediatamente antes de `daily_sleep_summary`. Score composto de quatro dimensões normalizadas a [0,1] e combinadas com pesos fixos; clamp final a [0.0, 100.0] com `round(.., 1)`. Docstring marca APPROXIMATE (fórmula proprietária WHOOP não publicada) e documenta os pesos. `daily_sleep_summary` e restantes funções intocadas.
- **server/ingest/app/analysis/daily.py** — em `compute_day()`, após `sleep_perf = sleep_summary.get("efficiency")`, cálculo de `_sleep_perf_score` via `_sleep.sleep_performance_score(...)` (import `from . import sleep as _sleep` já existia). Nova chave `"sleep_performance": _sleep_perf_score` adicionada ao dict `metrics` logo após `resp_rate_bpm`. A variável `sleep_perf` (0..1 para `recovery_score`) não foi alterada.
- **server/ingest/tests/test_sleep.py** — classe `TestSleepPerformanceScore` (7 casos: saturação→100, zero→0, noite típica em [70,95], clamp >100, fallback de sleep_needed, clamp não-negativo, tipo float) + import de `sleep_performance_score`.

## Task Commits

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 (RED) | testes falhados ALG-10 | 4e92a96 | server/ingest/tests/test_sleep.py |
| 1 (GREEN) | sleep_performance_score() | 289fe13 | server/ingest/app/analysis/sleep.py |
| 2 | integração em compute_day() | 7dea953 | server/ingest/app/analysis/daily.py |

## Verification Results

- Verificação 1 do plano — `sleep_performance_score(480, 1.0, 96, 96, 0, 420)` → **100.0**. PASS
- Verificação 2 do plano — `sleep_performance_score(0, 0.0, 0, 0, 0)` → **0.0**. PASS
- Verificação 3 do plano — `ast.parse(daily.py)` → **OK** (sem SyntaxError). PASS
- Verificação 4 do plano — `grep "sleep_performance" daily.py` → 2 linhas (chamada + chave no dict metrics). PASS
- Task 1 `<verify>` (4 casos): perfect→100, zero→0, típico (89.9) em [70,95], clamp(1000,..)→100. PASS
- Task 2 `<verify>`: `sleep_performance_score` presente, chave `"sleep_performance"` presente, AST válido. PASS
- Suite de testes adicionais: 7/7 casos lógicos passam (executados via loader isolado da função pura).

Nota de ambiente: este worktree isolado não tem `numpy`/`scipy`/`pytest` instalados nem `__init__.py` em `server`/`server.ingest`, por isso o caminho de import do plano (`from server.ingest.app.analysis.sleep import ...`) e `pytest` não correm aqui — mesma limitação documentada no 13-01-SUMMARY. `sleep_performance_score` é uma função **pura sem dependências**, pelo que foi verificada extraindo o seu source via AST e executando-a isoladamente (com `from __future__ import annotations` para o default `float | None` em Python 3.9), correndo todos os casos de verificação do plano e da suite. A validade de sintaxe de ambos os módulos completos foi confirmada por `ast.parse()`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] No-sleep short-circuit (TST=0 → 0.0)**
- **Found during:** Task 1 (GREEN), ao correr o caso 2 da verificação.
- **Issue:** A fórmula literal do plano dá **10.0** para `total_sleep_min=0`, porque o termo de consistência `W_con = (1 - min(disturbances/10, 1)) * 0.10` premeia "0 perturbações" mesmo numa noite sem qualquer sono. Isto contradiz directamente o must-have do plano "retorna 0 para TST=0" e a verificação `assert s2 == 0.0`.
- **Fix:** Adicionado `if total_sleep_min <= 0: return 0.0` no início da função, antes do cálculo dos termos. Satisfaz o requisito explícito e reforça a mitigação de divisão por zero (T-13-02-03).
- **Files modified:** server/ingest/app/analysis/sleep.py
- **Commit:** 289fe13

## TDD Gate Compliance

Sequência RED → GREEN respeitada:
- RED (`test`): 4e92a96 — testes a falhar (NameError no import de `sleep_performance_score`).
- GREEN (`feat`): 289fe13 — implementação faz passar todos os casos.
- REFACTOR: não necessário (função limpa).

## Threat Surface

- T-13-02-03 (DoS / divisão por zero): mitigado conforme planeado — `max(total_sleep_min, 1.0)` e `max(target, 1.0)` nos denominadores, reforçado pelo short-circuit `TST<=0 -> 0.0`.
- T-13-02-01 / T-13-02-02 (Tampering / Info Disclosure): accept — função pura sobre dados já validados pelo pipeline de sono, sem input externo nem PII adicional.

Nenhuma nova superfície de segurança introduzida fora do `<threat_model>` do plano.

## Self-Check: PASSED

- FOUND: server/ingest/app/analysis/sleep.py (sleep_performance_score definida)
- FOUND: server/ingest/app/analysis/daily.py (chamada + metrics['sleep_performance'])
- FOUND: server/ingest/tests/test_sleep.py (TestSleepPerformanceScore)
- FOUND commit 4e92a96, 289fe13, 7dea953
