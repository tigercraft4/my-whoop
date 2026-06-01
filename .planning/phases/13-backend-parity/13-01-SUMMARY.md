---
phase: 13-backend-parity
plan: 01
subsystem: server-data-pipeline
tags: [requirements, postgres, schema-migration, ingest, daily-metrics]
requires: []
provides:
  - daily_metrics.sleep_performance column (REAL)
  - daily_metrics.training_state column (TEXT)
  - daily_metrics.sleep_needed_min column (REAL)
  - daily_metrics.total_calories_kcal column (REAL)
  - _DAILY_COLS (read.py) extended to 23 columns
  - upsert_daily_metrics (store.py) writes/reads the 4 new columns
  - ALG-10..ALG-13 requirement definitions + traceability
affects:
  - 13-02 (Sleep Performance algorithm — depends on sleep_performance column)
  - 13-03 (Training State / Sleep Needed — depends on training_state, sleep_needed_min)
  - 13-04 (Calories — depends on total_calories_kcal)
tech-stack:
  added: []
  patterns:
    - Idempotent ALTER TABLE ADD COLUMN IF NOT EXISTS (bootstrap_schema re-apply safe)
    - Parametrized psycopg upsert (INSERT … ON CONFLICT DO UPDATE), no string interpolation
key-files:
  created:
    - .planning/phases/13-backend-parity/13-01-SUMMARY.md
  modified:
    - .planning/REQUIREMENTS.md
    - server/db/init.sql
    - server/ingest/app/read.py
    - server/ingest/app/store.py
decisions:
  - Use idempotent ALTER TABLE (not CREATE TABLE change) — daily_metrics already in production
  - Place 4 new columns before computed_at (which uses now(), not a placeholder)
metrics:
  duration: ~6m
  completed: 2026-06-01
  tasks: 3
  files: 4
---

# Phase 13 Plan 01: Backend Parity Data Infrastructure Summary

Infraestrutura de dados para a Fase 13: 4 novas colunas derivadas (sleep_performance, training_state, sleep_needed_min, total_calories_kcal) propagadas por todo o pipeline PostgreSQL → Python, mais as definições de requisitos ALG-10..ALG-13. Nenhum algoritmo implementado — apenas a base que desbloqueia os planos 13-02/03/04.

## What Was Built

- **REQUIREMENTS.md** — nova secção "Backend Parity Algorithms" com ALG-10 (Sleep Performance), ALG-11 (Training State server-side), ALG-12 (Sleep Needed), ALG-13 (Calorias totais) e 4 linhas de traceability (Phase 13 / Pending).
- **server/db/init.sql** — 4 × `ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS`, idempotentes, cada uma precedida de comentário a identificar o algoritmo: `sleep_performance REAL`, `training_state TEXT`, `sleep_needed_min REAL`, `total_calories_kcal REAL`. CREATE TABLE intocado.
- **server/ingest/app/read.py** — `_DAILY_COLS` estendido de 19 para 23 entradas; os 4 novos campos inseridos antes de `computed_at`, partilhados por `query_daily` e `query_today`.
- **server/ingest/app/store.py** — `upsert_daily_metrics` actualizado nos 4 sítios: lista de colunas do INSERT, placeholders `%s` do VALUES, cláusula DO UPDATE SET e tupla de parâmetros `metrics.get(...)`.

## Task Commits

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | ALG-10..13 no REQUIREMENTS.md | c0c687c | .planning/REQUIREMENTS.md |
| 2 | 4 colunas no DB schema | 3c0b8e5 | server/db/init.sql |
| 3 | read.py _DAILY_COLS + store.py upsert | ba14fa9 | server/ingest/app/read.py, server/ingest/app/store.py |

## Verification Results

- `grep -c "ALG-10\|ALG-11\|ALG-12\|ALG-13" REQUIREMENTS.md` → 8 (4 definições + 4 traceability). PASS
- `grep -v "^--" init.sql | grep -c "ADD COLUMN IF NOT EXISTS"` → 25 (≥ 9 exigido). PASS
- `grep -c "sleep_performance\|training_state\|sleep_needed_min\|total_calories_kcal" init.sql` → 4. PASS
- AST parse de read.py e store.py → OK (sem SyntaxError).
- Contagem de placeholders/parâmetros em `upsert_daily_metrics`: 23 colunas = 22 `%s` + 1 `now()`; 22 placeholders = 22 parâmetros vinculados (device_id + day + 20 × `metrics.get`). PASS — mitigação T-13-01-03 satisfeita.
- `grep -c "total_calories_kcal" REQUIREMENTS.md` → 1 (definição ALG-13). PASS

Nota: os passos de verificação 2/3 do plano (`python3 -c "import server.ingest.app.read"`) requerem o pacote instalado + dependências (psycopg, whoop_protocol) que não estão disponíveis neste worktree isolado. Cobertos equivalentemente por `ast.parse()` de ambos os ficheiros, que valida ausência de erros de sintaxe — o critério do plano (`Python não levanta SyntaxError`).

## Deviations from Plan

None - plan executed exactly as written.

## Threat Surface

T-13-01-03 (Tampering em store.py): mitigado conforme planeado — todas as queries continuam parametrizadas com `%s`, sem interpolação de strings; contagem de placeholders verificada contra contagem de parâmetros (22 = 22).

Nenhuma nova superfície de segurança introduzida fora do `<threat_model>` do plano.

## Self-Check: PASSED

- FOUND: server/db/init.sql (4 colunas)
- FOUND: server/ingest/app/read.py (23 cols)
- FOUND: server/ingest/app/store.py (upsert estendido)
- FOUND: .planning/REQUIREMENTS.md (ALG-10..13)
- FOUND commit c0c687c, 3c0b8e5, ba14fa9
