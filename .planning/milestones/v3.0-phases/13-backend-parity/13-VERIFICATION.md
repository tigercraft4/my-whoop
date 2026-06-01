---
phase: 13-backend-parity
verified: 2026-06-01T00:00:00Z
status: human_needed
score: 16/16 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Executar compute_day() contra uma DB real com dados de 7+ noites e confirmar que training_state e sleep_needed_min são persistidos com valores não-null"
    expected: "daily_metrics.training_state = 'OPTIMAL' | 'RESTORATIVE' | 'OVERREACHING'; daily_metrics.sleep_needed_min entre 300.0 e 660.0"
    why_human: "A integração DB-touching de compute_day() requer Docker + psycopg + dados reais — não exercitável offline. A lógica pura foi verificada por AST e execução isolada das funções."
  - test: "Sincronizar a app iOS com o servidor após upgrade da Fase 13 e confirmar que o CALORIES MetricCard aparece na TodayView quando o perfil de dispositivo está configurado"
    expected: "MetricCard 'CALORIES' visível com valor numérico não-nulo em kcal; ausente quando não há perfil"
    why_human: "Requer hardware físico (iPhone + servidor) para verificar a UI condicional renderizada a partir de dados reais do servidor."
  - test: "Confirmar que StrainCard mostra o Training State correto após sincronização do servidor (preferindo DailyMetric.trainingState sobre o cálculo client-side)"
    expected: "Badge RESTORATIVE/OPTIMAL/OVERREACHING corresponde ao valor calculado pelo servidor; fallback client-side ativo para rows pre-Fase-13 com trainingState nil"
    why_human: "Requer hardware físico + sync para verificar o comportamento server-first vs. client-side fallback em contexto real."
  - test: "Verificar que MetricKind.sleepPerformance no gráfico de tendências usa DailyMetric.sleepPerformance (ALG-10 score 0-100) para rows pós-Fase-13 e efficiency*100 para rows antigos"
    expected: "Gráfico exibe scores ALG-10 (scores compostos) para dados novos; scores legados (efficiency*100) para dados anteriores à Fase 13"
    why_human: "O comportamento de fallback retrocompatível requer dados históricos reais com e sem o campo sleepPerformance para validar a ramificação."
---

# Phase 13: Backend Parity Verification Report

**Phase Goal:** Implementar algoritmos equivalentes ao WHOOP no servidor: Sleep Performance score ponderado, Training State, Sleep Needed, Calorias — substituindo ou complementando o openwhoop-algos actual
**Verified:** 2026-06-01
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | REQUIREMENTS.md contém ALG-10, ALG-11, ALG-12 e ALG-13 com definições e traceability | ✓ VERIFIED | REQUIREMENTS.md linhas 47-50 (definições) e 116-119 (traceability). ALG-13 marcado Complete, outros Pending conforme execução parcial real vs. hardware. |
| 2 | daily_metrics no PostgreSQL tem 4 novas colunas (sleep_performance, training_state, sleep_needed_min, total_calories_kcal) | ✓ VERIFIED | init.sql linhas 218-224: 4 × `ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS` com comentários Phase-13 e tipos corretos (REAL/TEXT). |
| 3 | _DAILY_COLS em read.py inclui as 4 novas chaves | ✓ VERIFIED | read.py linhas 229-234: `_DAILY_COLS` inclui `"sleep_performance"`, `"training_state"`, `"sleep_needed_min"`, `"total_calories_kcal"` — total 23 colunas. |
| 4 | upsert_daily_metrics em store.py escreve e faz DO UPDATE para as 4 novas colunas | ✓ VERIFIED | store.py linhas 109-148: INSERT lista as 4 colunas, VALUES tem os 4 `%s` correspondentes, DO UPDATE SET inclui as 4 cláusulas EXCLUDED.*, e os parâmetros `metrics.get(...)` estão presentes. |
| 5 | sleep.py expõe a função sleep_performance_score() que retorna float 0.0–100.0 | ✓ VERIFIED | sleep.py linhas 630-683: função pública e pura com short-circuit `TST<=0 → 0.0`, pesos W_dur=0.45/W_eff=0.25/W_stg=0.20/W_con=0.10, clamp final e round(.., 1). Docstring marca APPROXIMATE. |
| 6 | daily.py chama sleep_performance_score() e coloca resultado em metrics['sleep_performance'] | ✓ VERIFIED | daily.py linhas 560-568 (chamada com sleep_needed_min=_sleep_needed) e linha 653 (`"sleep_performance": _sleep_perf_score`). |
| 7 | Training State server-side retorna RESTORATIVE, OPTIMAL ou OVERREACHING (nunca IMPOSSIBLE) | ✓ VERIFIED | daily.py linhas 144-184: `training_state_from_lookup()` retorna apenas as 3 strings ou None. Lógica: `strain < lower → RESTORATIVE`, `strain > upper → OVERREACHING`, caso contrário `OPTIMAL`. IMPOSSIBLE ausente do código. |
| 8 | Training State retorna None quando recovery ou strain são None | ✓ VERIFIED | daily.py linha 163: `if recovery_score is None or strain is None: return None`. |
| 9 | Sleep Needed retorna None quando há menos de 3 noites de histórico válido | ✓ VERIFIED | daily.py linhas 212-213: `if len(valid) < _MIN_SLEEP_NIGHTS: return None` onde `_MIN_SLEEP_NIGHTS = 3`. |
| 10 | Sleep Needed é clampado entre 300 e 660 minutos | ✓ VERIFIED | daily.py linha 228: `return round(max(_SLEEP_NEED_MIN, min(_SLEEP_NEED_MAX, need)), 1)` com `_SLEEP_NEED_MIN=300.0`, `_SLEEP_NEED_MAX=660.0`. |
| 11 | daily.py persiste training_state e sleep_needed_min no dict metrics | ✓ VERIFIED | daily.py linhas 612, 654-655: `_training_state = training_state_from_lookup(recovery, strain_val)` e `"training_state": _training_state, "sleep_needed_min": _sleep_needed`. |
| 12 | calories.py tem rmr_kcal_per_day() que calcula RMR via Mifflin–St Jeor | ✓ VERIFIED | calories.py linhas 121-157: `_MIFFLIN_COEFFS` com os 3 perfis sexuais (male +5, female -161, nonbinary -78); `rmr_kcal_per_day()` usa peso=10.0, altura=6.25, idade=5.0 (coeficientes Mifflin). Retorna None para profile=None. |
| 13 | daily.py persiste total_calories_kcal = RMR + exercise_kcal em metrics | ✓ VERIFIED | daily.py linhas 632-656: `_rmr = _calories.rmr_kcal_per_day(device_profile)`, `_exercise_kcal = sum(...)`, `_total_calories = round(_rmr + _exercise_kcal, 1) if _rmr is not None else None`, `"total_calories_kcal": _total_calories`. |
| 14 | DailyMetric Swift struct tem 4 novos campos opcionais: sleepPerformance, trainingState, sleepNeededMin, totalCaloriesKcal | ✓ VERIFIED | MetricsCache.swift linhas 48-64: 4 campos `public let` todos `Double?` ou `String?`, init com defaults `= nil`. upsertDailyMetrics e dailyMetrics SELECT incluem os 4 campos. |
| 15 | Database.swift tem migração v9 com 4 × t.add(column:) | ✓ VERIFIED | Database.swift linhas 168-183: `migrator.registerMigration("v9")` com 4 `t.add(column:)` todos sem `.notNull()` (nullable conforme plano). |
| 16 | ServerSync.swift faz parse dos 4 novos campos JSON de /v1/daily e /v1/today | ✓ VERIFIED | ServerSync.swift linhas 378-381: `dailyMetricFrom()` centraliza o parse de `sleep_performance`/`sleepPerformance`, `training_state`/`trainingState`, `sleep_needed_min`/`sleepNeededMin`, `total_calories_kcal`/`totalCaloriesKcal`. Usado tanto em `getDaily()` como em `getTodayMetric()`. |

**Score:** 16/16 truths verified

### Requirements Coverage

| Requirement | Plano Fonte | Descrição | Status | Evidência |
|-------------|-------------|-----------|--------|-----------|
| ALG-10 | 13-01, 13-02 | Sleep Performance score ponderado 0–100 via sleep.sleep_performance_score() | ✓ SATISFIED | sleep.py:630-683 + daily.py:560-568,653 + MetricsCache+ServerSync+MetricKind |
| ALG-11 | 13-01, 13-03 | Training State server-side via recovery_to_strain.json | ✓ SATISFIED | daily.py:144-184 (função) + 612,654 (integração) + StrainCard server-first fallback |
| ALG-12 | 13-01, 13-03 | Sleep Needed rolling 7d baseline + strain/sleep debt, clamp [300,660] | ✓ SATISFIED | daily.py:187-228 (função) + 533-551,655 (integração + rolling window) |
| ALG-13 | 13-01, 13-04 | Calorias totais = RMR Mifflin–St Jeor + exercise_kcal | ✓ SATISFIED | calories.py:121-157 (rmr_kcal_per_day) + daily.py:632-634,656 + TodayView caloriesCard + MetricsCache |

Todos os 4 requisitos da Fase 13 estão cobertos por evidência de código real.

### Required Artifacts

| Artefacto | Esperado | Status | Detalhe |
|-----------|----------|--------|---------|
| `server/db/init.sql` | 4 × ALTER TABLE com colunas sleep_performance/training_state/sleep_needed_min/total_calories_kcal | ✓ VERIFIED | Linhas 213-224: comentários ALG-10..13, tipos REAL/TEXT, idempotente (IF NOT EXISTS) |
| `server/ingest/app/read.py` | _DAILY_COLS com 23 colunas incluindo os 4 novos campos | ✓ VERIFIED | Linhas 229-234: lista completa de 23 colunas |
| `server/ingest/app/store.py` | upsert_daily_metrics actualizado para os 4 novos campos | ✓ VERIFIED | Linhas 109-148: INSERT, VALUES (%s), DO UPDATE SET e parâmetros completos |
| `server/ingest/app/analysis/sleep.py` | função sleep_performance_score() pura | ✓ VERIFIED | Linhas 630-683: função pública, pura, com fórmula composta e docstring APPROXIMATE |
| `server/ingest/app/analysis/daily.py` | training_state_from_lookup(), sleep_needed(), integração em compute_day() | ✓ VERIFIED | Funções em linhas 144-228; integração em linhas 530-656 |
| `server/ingest/app/analysis/calories.py` | rmr_kcal_per_day() Mifflin–St Jeor | ✓ VERIFIED | Linhas 121-157: _MIFFLIN_COEFFS novo + rmr_kcal_per_day() distinto dos _COEFFS Harris-Benedict |
| `Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift` | DailyMetric com 4 novos campos + upsert + select | ✓ VERIFIED | Struct linhas 48-64; upsert linhas 102-138; select linhas 161-184 |
| `Packages/WhoopStore/Sources/WhoopStore/Database.swift` | migração v9 com 4 colunas nullable | ✓ VERIFIED | Linhas 168-183: v9 com 4 `t.add(column:)` sem .notNull() |
| `ios/OpenWhoop/Upload/ServerSync.swift` | parse dos 4 campos em getDaily()/getTodayMetric() | ✓ VERIFIED | Linhas 356-382: `dailyMetricFrom()` centralizado, dual-key parse snake_case/camelCase via ServerSync.dbl |
| `ios/OpenWhoop/Tabs/TodayView.swift` | CALORIES MetricCard condicional | ✓ VERIFIED | Linhas 240-247: `@ViewBuilder caloriesCard` exibe MetricCard só quando `totalCaloriesKcal` não é nil |
| `ios/OpenWhoop/Design/Components/StrainCard.swift` | trainingState server-first com fallback client-side | ✓ VERIFIED | Linhas 28-38: `if let serverState = daily?.trainingState, !serverState.isEmpty { return serverState }` + fallback TrainingState.trainingState() |
| `ios/OpenWhoop/Charts/MetricKind.swift` | sleepPerformance.value(from:) usa campo real do servidor com fallback | ✓ VERIFIED | Linha 169: `return metric.sleepPerformance ?? metric.efficiency.map { $0 * 100 }` |

### Key Link Verification

| De | Para | Via | Status | Detalhe |
|----|------|-----|--------|---------|
| `server/db/init.sql` | `daily_metrics` | ALTER TABLE ADD COLUMN IF NOT EXISTS sleep_performance | ✓ WIRED | Linha 218: `ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS sleep_performance REAL` |
| `server/ingest/app/store.py` | `daily_metrics` | INSERT ... DO UPDATE SET sleep_performance = EXCLUDED.sleep_performance | ✓ WIRED | Linhas 135-138: 4 cláusulas EXCLUDED.* |
| `server/ingest/app/analysis/daily.py` | `server/ingest/app/analysis/sleep.py` | `_sleep.sleep_performance_score(...)` | ✓ WIRED | `from . import sleep as _sleep` (linha 79) + chamada linha 562 |
| `server/ingest/app/analysis/daily.py` | `server/ingest/app/analysis/recovery_to_strain.json` | `os.path.join(os.path.dirname(__file__), "recovery_to_strain.json")` | ✓ WIRED | Linha 116: `_TS_LOOKUP_PATH` + carregamento em módulo linhas 120-128 |
| `training_state_from_lookup` | `daily_metrics.training_state` | `metrics["training_state"] = _training_state` | ✓ WIRED | daily.py linhas 612 + 654 |
| `sleep_needed` | `daily_metrics.sleep_needed_min` | `metrics["sleep_needed_min"] = _sleep_needed` | ✓ WIRED | daily.py linhas 551 + 655 |
| `calories.py rmr_kcal_per_day` | `daily.py total_calories_kcal` | `from . import calories as _calories` + `_calories.rmr_kcal_per_day(device_profile)` | ✓ WIRED | daily.py linha 83 (import) + linhas 632-634,656 |
| `ios/OpenWhoop/Upload/ServerSync.swift` | `Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift` | `DailyMetric(..., sleepPerformance:, trainingState:, sleepNeededMin:, totalCaloriesKcal:)` via `dailyMetricFrom()` | ✓ WIRED | ServerSync.swift linhas 360-381 passam os 4 campos ao DailyMetric init |
| `ios/OpenWhoop/Design/Components/StrainCard.swift` | fallback `TrainingState.trainingState()` | `daily?.trainingState` → server-first; `TrainingState.trainingState(recovery:strain:)` → fallback | ✓ WIRED | StrainCard.swift linhas 28-38 |
| `ios/OpenWhoop/Charts/MetricKind.swift` | `DailyMetric.sleepPerformance` | `metric.sleepPerformance ?? metric.efficiency.map { $0 * 100 }` | ✓ WIRED | MetricKind.swift linha 169 |

### Data-Flow Trace (Level 4)

| Artefacto | Variável de dados | Fonte | Produz dados reais | Status |
|-----------|------------------|-------|--------------------|--------|
| `daily.py compute_day()` | `_sleep_perf_score` | `_sleep.sleep_performance_score()` com dados de `sleep_summary` (do DB via streams) | Sim — função pura sobre dados reais de sono | ✓ FLOWING |
| `daily.py compute_day()` | `_training_state` | `training_state_from_lookup(recovery, strain_val)` — recovery calculado, strain calculado | Sim — usa dados de recovery e strain calculados no mesmo dia | ✓ FLOWING |
| `daily.py compute_day()` | `_sleep_needed` | `sleep_needed(_prior_sleep_min, _strain_yesterday, _sleep_yesterday)` — lidos de `read.query_daily(prior 7d)` | Sim — baseline real a partir de DB; retorna None com histórico insuficiente | ✓ FLOWING |
| `daily.py compute_day()` | `_total_calories` | `_calories.rmr_kcal_per_day(device_profile)` + `sum(exercise_kcal)` | Sim — `device_profile` lido de `read.query_profile()`; None se sem perfil | ✓ FLOWING |
| `TodayView.caloriesCard` | `metrics.today?.totalCaloriesKcal` | `MetricsRepository.today` ← GRDB `dailyMetric` ← `ServerSync.getDaily()/getTodayMetric()` ← `/v1/today` | Sim — cadeia completa servidor→GRDB→ViewModel→View | ✓ FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED para os módulos que requerem a stack completa (psycopg/Docker). As funções puras foram verificadas pelos executores (documentado nos SUMMARYs) com os seguintes resultados:

| Comportamento | Resultado Documentado | Status |
|---------------|-----------------------|--------|
| `sleep_performance_score(480, 1.0, 96, 96, 0, 420)` | 100.0 | ✓ PASS (SUMMARY 13-02) |
| `sleep_performance_score(0, 0.0, 0, 0, 0)` | 0.0 | ✓ PASS (SUMMARY 13-02) |
| `training_state_from_lookup(None, 14.0)` | None | ✓ PASS (SUMMARY 13-03) |
| `sleep_needed([], None, None)` | None | ✓ PASS (SUMMARY 13-03) |
| `sleep_needed([420.0]*6, 10.0, 420.0)` | 420.0 ∈ [300, 660] | ✓ PASS (SUMMARY 13-03) |
| `rmr_kcal_per_day({'sex':'male','weight_kg':70,'height_cm':175,'age':30})` | ~1648.75 | ✓ PASS (SUMMARY 13-04) |
| `rmr_kcal_per_day(None)` | None | ✓ PASS (SUMMARY 13-04) |

### Anti-Patterns Found

Nenhum anti-pattern bloqueante detectado nos 9 ficheiros modificados nesta fase.

| Ficheiro | Contagem TBD/FIXME/XXX | Contagem TODO/PLACEHOLDER | Resultado |
|----------|-----------------------|--------------------------|-----------|
| `server/ingest/app/analysis/sleep.py` | 0 | 0 | CLEAN |
| `server/ingest/app/analysis/daily.py` | 0 | 0 | CLEAN |
| `server/ingest/app/analysis/calories.py` | 0 | 0 | CLEAN |
| `MetricsCache.swift` | 0 | 0 | CLEAN |
| `Database.swift` | 0 | 0 | CLEAN |
| `ServerSync.swift` | 0 | 0 | CLEAN |
| `TodayView.swift` | 0 | 0 | CLEAN |
| `StrainCard.swift` | 0 | 0 | CLEAN |
| `MetricKind.swift` | 0 | 0 | CLEAN |

Nota observacional: O campo `sleep_needed_min` em `daily.py` usa um rolling window de 7 dias onde o `_baseline_rows` exclui o dia de ontem (`_prior_7d[:-1]`) para evitar double-counting bias. Esta é uma decisão de design correcta não documentada no PLAN mas alinhada com a semântica do ALG-12.

### Human Verification Required

#### 1. Pipeline completo compute_day() com DB real (ALG-11 + ALG-12)

**Test:** Correr `compute_day(conn, device_id, today)` num servidor com Docker + 7+ noites de dados reais
**Expected:** `daily_metrics.training_state` é RESTORATIVE/OPTIMAL/OVERREACHING (não null); `daily_metrics.sleep_needed_min` está entre 300.0 e 660.0; `daily_metrics.sleep_performance` está entre 0.0 e 100.0
**Why human:** Requer stack completa: PostgreSQL (Docker), psycopg, dados de sono reais. A verificação offline cobre apenas as funções puras.

#### 2. iOS: CALORIES MetricCard no TodayView (ALG-13)

**Test:** Com perfil de dispositivo configurado no servidor, fazer sync iOS → verificar TodayView
**Expected:** Card "CALORIES" visível com valor numérico (ex: "2150 kcal"); ausente quando não há perfil
**Why human:** Renderização condicional SwiftUI baseada em `totalCaloriesKcal` real do servidor — requer iPhone + servidor.

#### 3. iOS: StrainCard Training State server-first (ALG-11)

**Test:** Verificar StrainCard após sync com dados pós-Fase-13 (trainingState não null no servidor) e com dados pré-Fase-13 (trainingState null)
**Expected:** Badge mostra valor do servidor para dados novos; badge calculado client-side para dados antigos; cores corretas (RESTORATIVE=azul, OPTIMAL=verde, OVERREACHING=vermelho)
**Why human:** Comportamento de fallback server-first requer hardware + dados reais com e sem campo trainingState.

#### 4. iOS: MetricKind.sleepPerformance gráfico de tendências (ALG-10)

**Test:** Verificar gráfico Sleep Performance em TrendsView/MetricDetailView após sync com dados pós-Fase-13
**Expected:** Valores do gráfico refletem o score composto ALG-10 (0–100) para rows com sleepPerformance; fallback a efficiency*100 para rows antigos
**Why human:** Necessita dados históricos reais com e sem o campo para validar a ramificação `metric.sleepPerformance ?? metric.efficiency.map { $0 * 100 }`.

### Gaps Summary

Nenhum gap bloqueante identificado. Todos os must-haves passam verificação de código.

A verificação está bloqueada apenas em validação humana porque os 4 itens acima são comportamentos de runtime que requerem hardware + DB real — impossível verificar programaticamente sem a stack completa.

---

_Verified: 2026-06-01_
_Verifier: Claude (gsd-verifier)_
