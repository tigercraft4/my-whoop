---
phase: 13-backend-parity
plan: 03
subsystem: server-analysis-pipeline
tags: [algorithm, training-state, sleep-needed, alg-11, alg-12, daily-metrics, tdd]
requires:
  - daily_metrics.training_state column (TEXT)  # provided by 13-01
  - daily_metrics.sleep_needed_min column (REAL)  # provided by 13-01
  - sleep.sleep_performance_score() + compute_day integration  # provided by 13-02
provides:
  - daily.training_state_from_lookup() pure function (RESTORATIVE/OPTIMAL/OVERREACHING/None)
  - daily.sleep_needed() pure function (clamped 300..660 min, None when <3 nights)
  - daily.compute_day writes metrics['training_state'] and metrics['sleep_needed_min']
  - sleep_performance_score now fed the real ALG-12 sleep_needed (was None)
affects:
  - iOS Today/Recovery views (will read training_state and sleep_needed_min via /v1/today)
tech-stack:
  added: []
  patterns:
    - Bundled JSON lookup table cached at module level, read via os.path relative to __file__
    - Graceful degradation on file/JSON error (OSError/ValueError -> [] -> None) — never raises in ingest
    - Pure functions over a prior-7d daily_metrics window read with read.query_daily
key-files:
  created:
    - .planning/phases/13-backend-parity/13-03-SUMMARY.md
    - server/ingest/tests/test_daily_alg.py
  modified:
    - server/ingest/app/analysis/daily.py
decisions:
  - "recovery passed to training_state_from_lookup unchanged: recovery.py already returns [0,100], so NO *100 (plan note line 149 verified against recovery.py docstring)."
  - "New pure-function test file test_daily_alg.py (not test_daily.py) — test_daily.py requires_docker/psycopg; the two new functions are pure and must be testable without the DB stack."
  - "_load_ts_lookup catches ValueError too (bad JSON), not only OSError, to fully satisfy T-13-03-02 graceful-degradation."
metrics:
  duration: ~10m
  completed: 2026-06-01
  tasks: 2
  files: 2
---

# Phase 13 Plan 03: Training State (ALG-11) & Sleep Needed (ALG-12) Summary

Implementação server-side de ALG-11 (Training State via lookup recovery→strain) e ALG-12 (Sleep Needed com baseline rolling) em `daily.py`, ambos integrados em `compute_day()`. ALG-11 mapeia (recovery 0–100, strain) para RESTORATIVE/OPTIMAL/OVERREACHING (nunca IMPOSSIBLE); ALG-12 deriva o sono necessário do baseline das noites anteriores mais débito de strain/sono, clampado a [300, 660] min. A integração também liga o valor real de ALG-12 à chamada de `sleep_performance_score()` (que no Plano 13-02 recebia `None`).

## What Was Built

- **server/ingest/app/analysis/daily.py**
  - Novos imports `json` e `os` (não existiam; `statistics`/`logging`/`math` já presentes).
  - `_load_ts_lookup() -> list[dict]`: abre `recovery_to_strain.json` (caminho relativo a `__file__`), cacheado em `_LOOKUP_TABLE`. Falhas de I/O ou JSON inválido → `logging.warning` + `[]` (degradação graciosa, T-13-03-02).
  - `training_state_from_lookup(recovery_score, strain) -> str | None`: `None` se algum argumento é `None` ou a tabela está vazia; `idx = round(clamp(recovery, 0, 100))`; encontra a linha (fallback à última); `strain < lower_rec_strain → RESTORATIVE`, `strain > upper_rec_strain → OVERREACHING`, caso contrário `OPTIMAL`. Nunca retorna IMPOSSIBLE.
  - `sleep_needed(prior_sleep_min, strain_yesterday, sleep_yesterday) -> float | None`: filtra noites válidas (>0); `None` se <3; `baseline = mean(valid)`; `strain_debt = clamp((strain_yesterday-14)*3, 0, 60)`; `sleep_debt = min(max(0, baseline-sleep_yesterday), 120)*0.5`; `round(clamp(baseline+strain_debt+sleep_debt, 300, 660), 1)`.
  - `compute_day()`: lê `read.query_daily` para os 7 dias anteriores (ascendente; último elemento = ontem), extrai `_prior_sleep_min`, `_strain_yesterday`, `_sleep_yesterday`; calcula `_sleep_needed` (antes da chamada a `sleep_performance_score`, agora alimentada com `sleep_needed_min=_sleep_needed`); calcula `_training_state` após `recovery`/`strain_val`; adiciona `"training_state"` e `"sleep_needed_min"` ao dict `metrics`.
- **server/ingest/tests/test_daily_alg.py** — 17 testes puros (8 ALG-11 incl. varredura completa da grelha 0–100 a confirmar que nunca há IMPOSSIBLE; 9 ALG-12 incl. clamps superior/inferior, filtro de noites inválidas, débito por strain elevado).
- **server/ingest/app/analysis/recovery_to_strain.json** — já existia no repositório (101 linhas, recovery 0..100 com `lower/rec/upper_rec_strain`). Verificado, não recriado (critério do plano satisfeito por presença).

## Task Commits

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 (RED) | testes falhados ALG-11/ALG-12 | a53eb65 | server/ingest/tests/test_daily_alg.py |
| 1 (GREEN) | training_state_from_lookup() + sleep_needed() | 8f3d8c4 | server/ingest/app/analysis/daily.py |
| 2 | integração em compute_day() | ef6187e | server/ingest/app/analysis/daily.py |

## Verification Results

- Task 1 `<verify>` (plano): `training_state(75,14)∈{OPTIMAL,RESTORATIVE,OVERREACHING}`, `training_state(None,14)=None`, `training_state(50,None)=None`, `training_state(100,0)=RESTORATIVE`; `sleep_needed([],None,None)=None`, `sleep_needed([420,400],12,410)=None` (<3), `sleep_needed([420]*6,10,420)∈[300,660]`, `sleep_needed([420]*6,20,360)>420`. **PASS**
- Task 2 `<verify>`: `ast.parse(daily.py)` OK; `training_state_from_lookup`/`sleep_needed` presentes; chaves `"training_state"` e `"sleep_needed_min"` no dict; `query_daily` presente. **PASS**
- `<verification>` de topo: #1 `training_state(100,0)=RESTORATIVE`; #2 `sleep_needed([420]*6,10,420)=420.0` ∈[300,660]; #3 `sleep_needed([],None,None)=None`; #4 `grep training_state|sleep_needed_min daily.py` → 7 ocorrências. **PASS**
- Suite completa `test_daily_alg.py` (17 casos): **PASS** (varredura 0–100 × {0,5,14,21,30} de strain nunca produz IMPOSSIBLE; clamps 300/660 confirmados).

Nota de ambiente: este worktree isolado não tem `zstandard`/`numpy`/`psycopg`/`pytest` instalados (mesma limitação documentada em 13-01 e 13-02), pelo que `import app.analysis.daily` falha em `read.py` (`zstandard`) e `pytest` não corre aqui. As duas funções novas são **puras**, por isso foram verificadas extraindo-as por AST (com `from __future__ import annotations` prependido, dado o Python 3.9.6 local) e executando todos os casos do plano e da suite isoladamente. A validade de sintaxe do módulo completo foi confirmada por `ast.parse()`. A integração DB-touching em `compute_day()` é coberta logicamente (chaves no dict + ordem de cálculo verificada por leitura) e será exercida por `test_daily.py` (requires_docker) em ambiente com a stack completa.

## Deviations from Plan

### Auto-fixed / Adjustments

**1. [Rule 2 - Robustness] _load_ts_lookup captura também ValueError**
- **Found during:** Task 1 (GREEN).
- **Issue:** O plano especifica `try/except OSError`. JSON corrompido levanta `json.JSONDecodeError` (subclasse de `ValueError`, NÃO de `OSError`), pelo que um ficheiro malformado faria `compute_day` rebentar — contraria a mitigação T-13-03-02 ("retornar None graciosamente em vez de levantar excepção").
- **Fix:** `except (OSError, ValueError)` cobre I/O e JSON inválido; ambos → `logging.warning` + `[]`.
- **Files modified:** server/ingest/app/analysis/daily.py
- **Commit:** 8f3d8c4

**2. [Decisão] Ficheiro de testes dedicado `test_daily_alg.py`**
- O plano não especifica ficheiro de testes (Task 1 só pede as funções). `test_daily.py` importa `psycopg`/`fastapi` e usa `requires_docker`. Como as duas funções são puras, criou-se `test_daily_alg.py` (sem dependências de DB) para que sejam testáveis offline — coerente com o padrão de `test_sleep.py` (também puro) usado em 13-02.

## Threat Surface

- **T-13-03-02 (DoS / falha de leitura do lookup):** mitigado conforme planeado e reforçado — `_load_ts_lookup` usa `try/except (OSError, ValueError)` + `logging.warning`, retorna `[]`, e `training_state_from_lookup` retorna `None` quando a tabela está vazia; nunca propaga excepção para o pipeline de ingest.
- **T-13-03-01 / T-13-03-03 / T-13-03-04 (Tampering / Info Disclosure):** accept conforme o plano — `recovery_to_strain.json` é bundled no container; `training_state`/`sleep_needed_min` derivam de recovery+strain/histórico já na DB, sem PII adicional nem input externo de utilizador.
- **T-13-03-SC:** sem instalação de dependências externas neste plano.

Nenhuma nova superfície de segurança introduzida fora do `<threat_model>` do plano.

## TDD Gate Compliance

Sequência RED → GREEN respeitada:
- RED (`test`): a53eb65 — testes referenciam `training_state_from_lookup`/`sleep_needed` inexistentes (ImportError); estado de falha confirmado (funções ausentes de daily.py).
- GREEN (`feat`): 8f3d8c4 — implementação faz passar os 17 casos.
- REFACTOR: não necessário (funções limpas, constantes nomeadas extraídas já na implementação inicial).

## Self-Check: PASSED

- FOUND: server/ingest/app/analysis/daily.py (training_state_from_lookup, sleep_needed, integração em compute_day)
- FOUND: server/ingest/tests/test_daily_alg.py (17 testes)
- FOUND: server/ingest/app/analysis/recovery_to_strain.json (já existente, verificado)
- FOUND commit a53eb65, 8f3d8c4, ef6187e
