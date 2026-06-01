---
phase: 13-backend-parity
plan: 04
subsystem: server-analysis-pipeline + ios-metrics-stack
tags: [algorithm, calories, mifflin-st-jeor, alg-13, alg-10, ios, grdb, serversync, tdd]
requires:
  - daily_metrics.total_calories_kcal column (REAL)  # provided by 13-01
  - daily.compute_day exercise calc + device_profile read  # provided by Phase 2 / 13-03
  - calories.estimate_bout_calories per-bout exercise kcal  # provided earlier
  - server sleep_performance/training_state/sleep_needed_min in metrics  # provided by 13-02/13-03
provides:
  - calories.rmr_kcal_per_day() pure function (Mifflin-St Jeor RMR, None for None profile)
  - daily.compute_day writes metrics['total_calories_kcal'] = RMR + sum(exercise_kcal)
  - DailyMetric Swift struct with 4 new optional fields (sleepPerformance, trainingState, sleepNeededMin, totalCaloriesKcal)
  - GRDB migration v9 (4 nullable dailyMetric columns)
  - ServerSync.getDaily()/getTodayMetric() parse the 4 new JSON fields
  - TodayView CALORIES MetricCard (conditional on totalCaloriesKcal)
  - StrainCard server-first trainingState with client-side lookup fallback
  - MetricKind.sleepPerformance reads real server field with efficiency fallback
affects:
  - iOS Today view (new CALORIES card)
  - iOS Strain card (training state now server-authoritative)
  - iOS sleep-performance chart (now real ALG-10 score, not efficiency proxy)
tech-stack:
  added: []
  patterns:
    - Sex-keyed coefficient dict (_MIFFLIN_COEFFS) distinct from Harris-Benedict _COEFFS
    - GRDB additive migration with all-nullable columns (never .notNull() without .defaults)
    - ServerSync dual-key parse (snake_case ?? camelCase) via ServerSync.dbl for numerics
    - Server-first display with client-side fallback for pre-Phase-13 cached rows
key-files:
  created:
    - .planning/phases/13-backend-parity/13-04-SUMMARY.md
    - server/ingest/tests/test_calories_rmr.py
  modified:
    - server/ingest/app/analysis/calories.py
    - server/ingest/app/analysis/daily.py
    - Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift
    - Packages/WhoopStore/Sources/WhoopStore/Database.swift
    - ios/OpenWhoop/Upload/ServerSync.swift
    - ios/OpenWhoop/Tabs/TodayView.swift
    - ios/OpenWhoop/Design/Components/StrainCard.swift
    - ios/OpenWhoop/Charts/MetricKind.swift
decisions:
  - "RMR usa Mifflin-St Jeor (_MIFFLIN_COEFFS novo) e NAO Harris-Benedict (_COEFFS existente, usado para burn por bout): ALG-13 spec exige Mifflin para RMR de dia inteiro."
  - "rmr_kcal_per_day aplica o coeficiente de altura a cm (6.25), nao a metros como o _resting_kcal_per_s de Harris-Benedict (479.9/m); intercept nonbinary = -78 = media de (5 + -161)/2."
  - "Ficheiro de teste dedicado test_calories_rmr.py (puro, sem psycopg) — test_profile_calories_workouts.py importa psycopg/DB; rmr_kcal_per_day e pura e deve correr offline."
  - "store.py ja tinha total_calories_kcal no upsert/SELECT (13-01); daily.py so precisou adicionar a chave ao dict metrics — sem alteracao em store.py."
metrics:
  duration: ~25m
  completed: 2026-06-01
  tasks: 2
  files: 9
---

# Phase 13 Plan 04: Calories (ALG-13) & iOS Field Propagation Summary

Implementa ALG-13 (calorias totais do dia via Mifflin–St Jeor + exercício) no servidor e propaga os 4 novos campos da Fase 13 por toda a stack iOS: `DailyMetric` struct → migração GRDB v9 → parse em `ServerSync` → display em `TodayView` (card CALORIES) + fallback server-first em `StrainCard`. Corrige também `MetricKind.sleepPerformance` para ler o score real persistido pelo servidor (ALG-10) em vez do proxy `efficiency * 100`, com fallback retrocompatível para linhas anteriores à Fase 13.

## What Was Built

- **server/ingest/app/analysis/calories.py**
  - `_MIFFLIN_COEFFS`: dict sex-keyed com `weight=10.0`, `height=6.25`, `age=5.0` para todos; intercept `male +5.0`, `female -161.0`, `nonbinary -78.0` (média dos dois). Distinto do `_COEFFS` Harris–Benedict existente (usado para burn por bout).
  - `rmr_kcal_per_day(profile: dict | None) -> float | None`: `None` para `profile=None`; lê `weight_kg` (default 70), `height_cm` (default 170), `age` (default 30), `sex` (lowercase, default/desconhecido → "nonbinary"); `rmr = kg*10 + cm*6.25 - age*5 + intercept`; `max(0.0, rmr)`.
- **server/ingest/app/analysis/daily.py**
  - Novo import `from . import calories as _calories`.
  - Após `ex_dicts`: `_rmr = _calories.rmr_kcal_per_day(device_profile)`; `_exercise_kcal = sum((e.get("calories_kcal") or 0.0) for e in ex_dicts)`; `_total_calories = round(_rmr + _exercise_kcal, 1)` quando `_rmr` não é None, else `None`.
  - `metrics["total_calories_kcal"] = _total_calories`. (store.py já persistia esta chave desde 13-01.)
- **Packages/WhoopStore/.../MetricsCache.swift**
  - `DailyMetric` +4 campos opcionais: `sleepPerformance: Double?`, `trainingState: String?`, `sleepNeededMin: Double?`, `totalCaloriesKcal: Double?`; `init` com defaults `= nil`.
  - `upsertDailyMetrics`: +4 colunas no INSERT, +4 `?` no VALUES (16→20), +4 entradas no DO UPDATE SET, +4 valores em `arguments`.
  - `dailyMetrics`: +4 colunas no SELECT, +4 no mapeamento `DailyMetric(...)`.
- **Packages/WhoopStore/.../Database.swift** — migração `v9`: `db.alter(table: "dailyMetric")` com `sleepPerformance .double`, `trainingState .text`, `sleepNeededMin .double`, `totalCaloriesKcal .double` (todas nullable — nunca `.notNull()` sem `.defaults`).
- **ios/OpenWhoop/Upload/ServerSync.swift** — `getDaily()` e `getTodayMetric()`: parse dos 4 campos (`dbl(r,"sleep_performance") ?? dbl(r,"sleepPerformance")`, `r["training_state"] as? String ?? r["trainingState"] as? String`, `sleep_needed_min`, `total_calories_kcal`) usando `ServerSync.dbl` para numéricos.
- **ios/OpenWhoop/Tabs/TodayView.swift** — `@ViewBuilder caloriesCard`: mostra `MetricCard(title:"CALORIES", value:%.0f, unit:"kcal", accentColor:.strainAccent)` só quando `metrics.today?.totalCaloriesKcal` é não nil; inserido após `hrvAndRhrRow`.
- **ios/OpenWhoop/Design/Components/StrainCard.swift** — `trainingStateLabel` server-first: retorna `daily?.trainingState` quando presente/não vazio; fallback ao `TrainingState.trainingState(recovery: recoveryFraction*100, strain:)` client-side para linhas pré-Fase-13.
- **ios/OpenWhoop/Charts/MetricKind.swift** — case `.sleepPerformance`: `return metric.sleepPerformance ?? metric.efficiency.map { $0 * 100 }`.

## Task Commits

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 (RED) | teste falhado rmr_kcal_per_day (ALG-13) | d15dfa8 | server/ingest/tests/test_calories_rmr.py, .gitignore |
| 1 (GREEN) | rmr_kcal_per_day() + total_calories em daily.py | 3084ccc | calories.py, daily.py |
| 2 | propagação 4 campos iOS + fix MetricKind | 8bc29f1 | MetricsCache.swift, Database.swift, ServerSync.swift, TodayView.swift, StrainCard.swift, MetricKind.swift |

## Verification Results

- **Task 1 `<verify>`:** `rmr(male,70,175,30)=1648.75` (±1.0), `rmr(female,60,165,25)=1345.25` (±1.0), `rmr(None)=None`, `rmr({})>0` → **ALL OK**.
- **test_calories_rmr.py** (7 casos: male/female valores conhecidos, None→None, defaults positivos, intercept nonbinary 1534.5, fallback sexo desconhecido, nunca negativo): **7 passed**.
- **Task 2 `<verify>`:** 5 ficheiros de propagação contêm os 4 campos (5/5); `metric.sleepPerformance` em MetricKind = 1 ocorrência. **PASS**
- **`<verification>` de topo (7 checks):** #1 v9 presente (2 hits); #2 totalCaloriesKcal em MetricsCache (8 hits: struct/init/insert/update/args/select/map); #3 sleep_performance em ServerSync (2 hits: getDaily+getTodayMetric); #4 CALORIES/totalCaloriesKcal em TodayView (3 hits); #5 trainingState em StrainCard (9 hits); #6 expressão fallback exacta em MetricKind; #7 RMR=1648.75. **ALL PASS**
- **`swift build` do package WhoopStore:** `Build complete!` (MetricsCache.swift + Database.swift compilam limpos).

Nota de ambiente: o Python do sistema é 3.9.6 sem pytest; o código usa sintaxe `dict | None` (3.10+). Criou-se um venv local `server/ingest/.venv-test` (Python 3.11 + pytest, gitignored) para correr os testes puros. `test_profile_calories_workouts.py` e `test_daily_alg.py` falham na colecção apenas por `psycopg` ausente neste venv mínimo (importam módulos DB) — limitação de ambiente pré-existente, fora de escopo; a integração DB-touching de `compute_day()` será exercida por `test_daily.py` (requires_docker) na stack completa. O alvo Xcode `ios/OpenWhoop` não foi compilado (requer simulador); o package WhoopStore (onde vivem DailyMetric/migração) compila e os 4 ficheiros do app target foram validados por grep + revisão.

## Deviations from Plan

### Auto-fixed / Adjustments

**1. [Decisão] Ficheiro de teste dedicado test_calories_rmr.py + venv local**
- O plano não especifica ficheiro de testes. `test_profile_calories_workouts.py` importa `psycopg` (DB). Como `rmr_kcal_per_day` é pura, criou-se `test_calories_rmr.py` (sem dependências DB), coerente com o padrão de `test_daily_alg.py` (13-03). O Python do sistema (3.9) não suporta a sintaxe `dict | None` nem tem pytest, por isso criou-se um venv 3.11 local (`.venv-test`, adicionado ao `.gitignore`).

**2. [Nota] store.py já preparado — sem alteração**
- O plano (Task 2, passo store) não era necessário: `store.upsert_daily_metrics` e o SELECT já incluíam `total_calories_kcal` (e os outros 3) desde 13-01. `daily.py` só precisou adicionar a chave ao dict `metrics`. Nenhuma deviation de código — confirmação de que a coluna DB e o store layer estavam prontos.

Sem alterações arquiteturais (Rule 4). Nenhuma instalação de dependência de runtime/produção (o venv de teste é local e gitignored).

## Threat Surface

- **T-13-04-03 (DoS / migração v9 falha):** mitigado — as 4 colunas são todas nullable; nunca `.notNull()` sem `.defaults(to:)`. Migração aditiva segura.
- **T-13-04-04 (Tampering / parse NSNumber):** mitigado — todos os campos numéricos novos usam `ServerSync.dbl(r, ...)` (trata NSNumber vs Double); nenhum cast directo `as? Double`. Apenas `trainingState` (String) usa `as? String`, conforme planeado.
- **T-13-04-01/02/05/06 (Tampering/Info Disclosure/Repudiation):** accept conforme o plano — `trainingState` desconhecido cai no `default` do switch de cor sem crash; calorias derivadas de perfil já no servidor; `total_calories_kcal=None` sem perfil → iOS esconde o card; `sleepPerformance` fora de 0–100 é clipado pelo domínio fixo do chart.
- **T-13-04-SC:** sem instalação de dependências externas de produção.

Nenhuma nova superfície de segurança introduzida fora do `<threat_model>` do plano.

## TDD Gate Compliance

Sequência RED → GREEN respeitada para a Task 1 (`tdd="true"`):
- RED (`test`): d15dfa8 — `test_calories_rmr.py` referencia `rmr_kcal_per_day` inexistente → `ImportError` confirmado (falha real, função ausente de calories.py).
- GREEN (`feat`): 3084ccc — implementação faz passar os 7 casos.
- REFACTOR: não necessário (função limpa, `_MIFFLIN_COEFFS` extraído já na implementação inicial).

Task 2 não é TDD (propagação iOS / display — verificada por build do package + grep).

## Self-Check: PASSED

- FOUND: server/ingest/app/analysis/calories.py (rmr_kcal_per_day, _MIFFLIN_COEFFS)
- FOUND: server/ingest/app/analysis/daily.py (import calories, total_calories_kcal no dict)
- FOUND: server/ingest/tests/test_calories_rmr.py (7 testes)
- FOUND: Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift (4 campos, upsert, select)
- FOUND: Packages/WhoopStore/Sources/WhoopStore/Database.swift (migração v9)
- FOUND: ios/OpenWhoop/Upload/ServerSync.swift (parse 4 campos × 2 métodos)
- FOUND: ios/OpenWhoop/Tabs/TodayView.swift (caloriesCard)
- FOUND: ios/OpenWhoop/Design/Components/StrainCard.swift (trainingState server-first)
- FOUND: ios/OpenWhoop/Charts/MetricKind.swift (metric.sleepPerformance ?? efficiency)
- FOUND commit d15dfa8, 3084ccc, 8bc29f1
