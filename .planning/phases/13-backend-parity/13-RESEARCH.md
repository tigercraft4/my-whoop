# Phase 13: Backend Parity — Research

**Researched:** 2026-06-01
**Domain:** Python server-side algoritmos (sleep performance, training state, sleep needed, calorias totais) + iOS DailyMetric model
**Confidence:** HIGH

---

## Summary

A Phase 13 implementa quatro algoritmos novos no servidor (`server/ingest/app/analysis/`) que substituem proxies simplistas por métricas equivalentes ao WHOOP: Sleep Performance ponderado, Training State per-server, Sleep Needed, e Calorias totais diárias. O pipeline de dados já existe e está a funcionar — o trabalho desta fase é puramente **adicionar lógica dentro do pipeline existente** e propagar 4 colunas novas por toda a stack (PostgreSQL → Python → iOS GRDB → SwiftUI).

A stack está bem compreendida porque o código está inteiramente no repo. Não são necessárias bibliotecas externas novas — todos os algoritmos são matemática pura implementável com a `stdlib` Python (ou `statistics`). O padrão de extensão é claro e repetitivo: cada coluna nova segue exactamente o mesmo caminho que `spo2_pct` ou `skin_temp_dev_c` percorreram nas fases anteriores.

**Recomendação primária:** Implementar os quatro algoritmos em ondas separadas, cada uma com o seu próprio caminho servidor → iOS, em vez de os fazer todos ao mesmo tempo. Isto mantém os commits bisectáveis e o testing incremental.

---

## Architectural Responsibility Map

| Capability | Tier Primário | Tier Secundário | Racional |
|-----------|--------------|-----------------|---------|
| Sleep Performance score | API / Backend (`sleep.py`) | — | Requer dados históricos de staging; não pode ser calculado no client |
| Training State (server) | API / Backend (`daily.py`) | iOS (já existe client-side via lookup table) | Server tem acesso a recovery + strain em conjunto; iOS mantém o cálculo local como fallback |
| Sleep Needed baseline | API / Backend (`daily.py`) | — | Requer média rolling de 7d de histórico de sono; dados no PostgreSQL, não no client |
| Calorias totais diárias | API / Backend (`daily.py` orquestra `calories.py`) | — | RMR + exercício; perfil do utilizador está no servidor |
| Exposição via `/v1/today` | API / Backend (`read.py`, `main.py`) | — | Endpoint já existe; só precisa de ler as 4 colunas novas |
| Cache iOS (GRDB) | Frontend (WhoopStore `Database.swift`, `MetricsCache.swift`) | — | Migração v9: add 4 colunas ao `dailyMetric` GRDB |
| Display iOS | Frontend (`TodayView.swift`, `StrainCard.swift`) | — | Ler campos novos de `DailyMetric`, mostrar no Today tab |

---

## Requisitos ALG-10 a ALG-13 (definição proposta)

Estes IDs são referenciados no ROADMAP.md mas não existem ainda em REQUIREMENTS.md. A definição proposta é:

| ID | Descrição |
|----|-----------|
| **ALG-10** | `sleep.py`: Sleep Performance = score ponderado 0–100 (duração + eficiência TST/TIB + staging adequado REM+Deep ≥ 20% + consistência/fragmentação); substitui o raw `efficiency` na coluna `efficiency` do `daily_metrics`, **ou** persiste numa coluna separada `sleep_performance` |
| **ALG-11** | `daily.py`: Training State calculado server-side a partir de (Recovery, Strain) via a mesma tabela `recovery_to_strain.json` já bundled no iOS; persistido na coluna `training_state TEXT` do `daily_metrics`; exposto pelo `/v1/today` |
| **ALG-12** | `daily.py`: Sleep Needed = Baseline rolling 7d (média `total_sleep_min`) + Strain Debt (f(strain_ontem)) + Sleep Debt (défice acumulado 7d) − Nap Credit; persistido na coluna `sleep_needed_min REAL` do `daily_metrics`; exposto pelo `/v1/today` |
| **ALG-13** | `daily.py`/`calories.py`: Calorias totais diárias = RMR 24h (Mifflin–St Jeor) + calorias de exercício já computadas (Keytel); persistidas na coluna `total_calories_kcal REAL` do `daily_metrics`; expostas pelo `/v1/today`; iOS Today view mostra o valor |

---

## Standard Stack

### Core (nenhuma biblioteca nova necessária)

| Componente | Já existe? | Notas |
|-----------|-----------|-------|
| Python `statistics` stdlib | Sim | Média, mediana — usada em `daily.py`, `baselines.py` |
| `baselines.fold_history` | Sim | Padrão para Sleep Needed rolling baseline de 7d |
| `calories.estimate_bout_calories` | Sim | Reutilizar para exercício; nova função `rmr_kcal_per_day` para RMR |
| `recovery_to_strain.json` | Sim, bundled iOS | Servidor deve ler o mesmo ficheiro JSON para Training State |
| `psycopg` + TimescaleDB PostgreSQL | Sim | Sem mudança |
| GRDB + WhoopStore | Sim, migração v8 | Nova migração v9 para as 4 colunas novas |

### Padrão de extensão (verificado no codebase)

O padrão exacto para adicionar uma coluna nova ao pipeline é: [VERIFIED: codebase]

1. `server/db/init.sql` — `ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS <col> <type>;`
2. `server/ingest/app/read.py` — adicionar `<col>` a `_DAILY_COLS`
3. `server/ingest/app/store.py` — adicionar `<col>` ao `INSERT INTO daily_metrics` + `DO UPDATE SET`
4. `server/ingest/app/analysis/daily.py` — calcular o valor e adicioná-lo ao dict `metrics`
5. `Packages/WhoopStore/Sources/WhoopStore/Database.swift` — migração v9: `ALTER TABLE dailyMetric ADD COLUMN`
6. `Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift` — `DailyMetric` struct + `upsertDailyMetrics` + `dailyMetrics` read
7. `ios/OpenWhoop/Upload/ServerSync.swift` — `getDaily` e `getTodayMetric`: parsear a nova chave JSON
8. `ios/OpenWhoop/Tabs/TodayView.swift` + componentes — mostrar o valor

Este padrão foi seguido para `spo2_pct`, `skin_temp_dev_c`, `resp_rate_bpm` (fases anteriores). [VERIFIED: codebase]

---

## Architecture Patterns

### Fluxo de dados — novas métricas

```
PostgreSQL daily_metrics
    ↓ (4 novas colunas: sleep_performance, training_state, sleep_needed_min, total_calories_kcal)
read.py _DAILY_COLS
    ↓
store.py upsert_daily_metrics
    ↑ (calculado em)
daily.py compute_day()
    ├── sleep.py → sleep_performance_score()   [ALG-10]
    ├── recovery_to_strain.json → training_state_from_lookup()  [ALG-11]
    ├── daily.py → sleep_needed()              [ALG-12]
    └── calories.py → rmr_kcal_per_day() + Σexercise_calories  [ALG-13]
    ↓
/v1/today (main.py — sem alteração ao endpoint)
    ↓
ServerSync.getDaily / getTodayMetric  (iOS parse)
    ↓
WhoopStore GRDB (migração v9)
    ↓
DailyMetric struct (Swift)
    ↓
TodayView — CALORIES card + Training State badge já em StrainCard
```

### Estrutura de ficheiros recomendada

```
server/ingest/app/
├── analysis/
│   ├── daily.py          # compute_day: adicionar 4 chamadas novas
│   ├── sleep.py          # adicionar sleep_performance_score()
│   └── calories.py       # adicionar rmr_kcal_per_day() + daily_total_calories()
├── db/
│   └── init.sql          # 4 × ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS
├── read.py               # _DAILY_COLS: + 4 chaves
└── store.py              # upsert_daily_metrics: + 4 campos

Packages/WhoopStore/Sources/WhoopStore/
├── Database.swift         # migração v9: 4 × alter(table: "dailyMetric")
└── MetricsCache.swift     # DailyMetric struct: 4 novos campos opcionais

ios/OpenWhoop/
├── Upload/ServerSync.swift          # getDaily / getTodayMetric: parsear 4 novas chaves
├── Tabs/TodayView.swift             # mostrar CALORIES + Training State (server)
└── Design/Components/StrainCard.swift  # Training State badge já existe (client-side)
```

---

## Algoritmos — Especificação Técnica

### ALG-10: Sleep Performance Score

**Input:** `sleep_summary` dict de `daily_sleep_summary()` — já contém `total_sleep_min`, `efficiency` (TST/TIB), `deep_min`, `rem_min`, `light_min`, `disturbances`. [VERIFIED: codebase]

**Fórmula proposta (composite score 0–100):**

```python
def sleep_performance_score(
    total_sleep_min: float,
    efficiency: float,      # 0..1 (TST/TIB)
    deep_min: float,
    rem_min: float,
    disturbances: int,
    target_sleep_min: float = 480.0,   # 8h default, substituído por sleep_needed quando disponível
) -> float:
    """Score ponderado 0–100. APPROXIMATE — não é o algoritmo proprietário do WHOOP."""
    tst = total_sleep_min
    # 1. Duration score: saturates at target (8h default)
    duration_score = min(1.0, tst / target_sleep_min) * 100

    # 2. Efficiency score: raw TST/TIB (já normalizado 0..1)
    efficiency_score = efficiency * 100

    # 3. Staging score: REM + Deep should be >= 20% of TST
    if tst > 0:
        restorative_pct = (deep_min + rem_min) / tst
        staging_score = min(1.0, restorative_pct / 0.20) * 100
    else:
        staging_score = 0.0

    # 4. Fragmentation penalty: fewer disturbances = better
    # WHOOP penalises WASO; our proxy is disturbance count
    fragmentation_score = max(0.0, 100.0 - disturbances * 5)  # -5 pts per wakeup, floor 0

    # Weighted composite (weights somam 1.0)
    score = (
        0.30 * duration_score
        + 0.30 * efficiency_score
        + 0.25 * staging_score
        + 0.15 * fragmentation_score
    )
    return round(min(100.0, max(0.0, score)), 1)
```

**Integração em `daily.py`:** calcular depois de `sleep_summary`, antes do `recovery`. Passar ao `recovery_score` como `sleep_perf` melhorado (em vez do raw `efficiency`). [ASSUMED — pesos exactos; o WHOOP não publicou a fórmula]

**Questão crítica:** O ROADMAP diz que ALG-10 produz um score 0–100 separado do `efficiency`. Existem duas opções:
- A) Substituir a coluna `efficiency` pelo score ponderado (breaking change para views que exibem efficiency)
- B) Adicionar coluna `sleep_performance REAL` ao `daily_metrics` e manter `efficiency` como TST/TIB

A opção B é mais segura e honesta. O `MetricKind.sleepPerformance` no iOS já lê `efficiency` e multiplica por 100 — com B, seria atualizado para ler o novo campo. [ASSUMED — decisão de design, requer confirmação]

---

### ALG-11: Training State (server-side)

**Abordagem:** Ler o mesmo `recovery_to_strain.json` bundled no iOS. O servidor deve ter o ficheiro disponível. [VERIFIED: codebase — ficheiro existe em `server/ingest/app/analysis/recovery_to_strain.json`]

**Input:** `recovery` (0–100, float), `strain` (0–21, float) — ambos já computados em `compute_day()`.

**Fórmula:**

```python
import json, os

_LOOKUP: list[dict] | None = None

def _load_lookup() -> list[dict]:
    global _LOOKUP
    if _LOOKUP is None:
        path = os.path.join(os.path.dirname(__file__), "recovery_to_strain.json")
        with open(path) as f:
            _LOOKUP = json.load(f)
        _LOOKUP.sort(key=lambda r: r["recovery"])
    return _LOOKUP

def training_state(recovery_score: float | None, strain: float | None) -> str | None:
    """Retorna 'RESTORATIVE' | 'OPTIMAL' | 'OVERREACHING' ou None."""
    if recovery_score is None or strain is None:
        return None
    table = _load_lookup()
    idx = int(round(min(100, max(0, recovery_score))))
    # Encontrar row pelo índice (tabela é 0-indexed por recovery inteiro 0..100)
    row = next((r for r in table if r["recovery"] == idx), table[-1])
    if strain < row["lower_rec_strain"]:
        return "RESTORATIVE"
    elif strain > row["upper_rec_strain"]:
        return "OVERREACHING"
    else:
        return "OPTIMAL"
```

**Nota:** O iOS `TrainingState.swift` nunca emite "IMPOSSIBLE" (D-05). O servidor deve seguir a mesma convenção — omitir "IMPOSSIBLE". [VERIFIED: codebase — TrainingState.swift linha 9]

**Coluna no DB:** `training_state TEXT` (nullable) no `daily_metrics`. [ASSUMED — tipo TEXT, pois é um enum string]

**Implicação iOS:** `StrainCard.swift` actualmente calcula `trainingStateLabel` client-side via `TrainingState.trainingState(recovery:strain:)`. Com ALG-11, o servidor expõe o mesmo valor. O iOS pode:
- Continuar a usar o client-side (não mudar nada)
- Preferir o valor do servidor quando disponível (mais correcto, pois o servidor tem histórico completo para recovery)

A abordagem recomendada é: iOS usa `DailyMetric.trainingState` (novo campo) quando não nulo; fallback para o cálculo client-side. Isto preserva compatibilidade. [ASSUMED]

---

### ALG-12: Sleep Needed

**Fórmula:** `sleep_needed_min = baseline_7d + strain_debt + sleep_debt - nap_credit`

**Componentes:**

```python
def sleep_needed(
    baseline_sleep_7d: float | None,   # média de total_sleep_min dos últimos 7d
    strain_yesterday: float | None,    # strain do dia anterior
    sleep_debt_7d: float | None,       # défice acumulado: Σ(baseline - actual) nos últimos 7d
    nap_credit_min: float = 0.0,       # ainda não temos detecção de sestas
) -> float | None:
    """Retorna minutos de sono necessários, ou None se baseline insuficiente."""
    if baseline_sleep_7d is None:
        return None

    # Strain debt: WHOOP usa strain > 14 para começar a adicionar tempo.
    # Proxy: adicionar 0-60 min proporcionalmente ao strain acima de 10.
    strain_debt = 0.0
    if strain_yesterday is not None and strain_yesterday > 10:
        # +4 min por unidade de strain acima de 10, máximo 60 min (a strain=25)
        strain_debt = min(60.0, (strain_yesterday - 10) * 4.0)

    # Sleep debt: se dormiu menos que a baseline nos últimos 7d, adicionar défice
    sleep_debt = max(0.0, sleep_debt_7d or 0.0) * 0.20  # 20% do défice acumulado por dia

    needed = baseline_sleep_7d + strain_debt + sleep_debt - nap_credit_min
    return round(max(240.0, min(720.0, needed)), 1)  # floor 4h, ceiling 12h
```

**Como calcular os inputs em `daily.py`:**
- `baseline_sleep_7d`: ler os 7 `daily_metrics` anteriores via `read.query_daily(conn, device_id, day-7, day-1)`, fazer `statistics.mean([r["total_sleep_min"] for r in prior if r["total_sleep_min"]])`. [VERIFIED: padrão usado em `_build_baselines`]
- `strain_yesterday`: ler `daily_metrics` do dia `day-1`, campo `strain`.
- `sleep_debt_7d`: `sum(max(0, baseline - actual) for actual in last_7_nights)`. [ASSUMED — fórmula de sleep debt; WHOOP não publicou detalhes]
- `nap_credit_min`: 0.0 por agora (detecção de sestas não implementada).

**Coluna no DB:** `sleep_needed_min REAL` (nullable).

---

### ALG-13: Calorias Totais Diárias

**Fórmula:** `total_calories = rmr_kcal_per_day + exercise_calories`

A função `estimate_bout_calories` em `calories.py` já existe para exercício (Keytel 2005 + Harris-Benedict). O ROADMAP pede Mifflin–St Jeor para RMR — **isto é uma mudança em relação ao Harris-Benedict** que já está no `calories.py`. [ASSUMED — se o ROADMAP especifica Mifflin–St Jeor especificamente]

**Mifflin–St Jeor (RMR kcal/dia):** [CITED: múltiplas referências clínicas]
```
men:   RMR = 10·weight_kg + 6.25·height_cm - 5·age + 5
women: RMR = 10·weight_kg + 6.25·height_cm - 5·age - 161
```

**Nova função em `calories.py`:**

```python
_MIFFLIN_COEFFS: dict[str, dict[str, float]] = {
    "male":      {"weight": 10.0, "height": 6.25, "age": 5.0,  "intercept":   5.0},
    "female":    {"weight": 10.0, "height": 6.25, "age": 5.0,  "intercept": -161.0},
    "nonbinary": {"weight": 10.0, "height": 6.25, "age": 5.0,  "intercept":  -78.0},  # mean
}

def rmr_kcal_per_day(profile: dict) -> float:
    """Mifflin–St Jeor RMR (kcal/day). Requer weight_kg, height_cm, age, sex."""
    weight = float(profile.get("weight_kg") or 70.0)
    height = float(profile.get("height_cm") or 170.0)
    age    = float(profile.get("age") or 30.0)
    sex    = (profile.get("sex") or "").lower().strip()
    c = _MIFFLIN_COEFFS.get(sex, _MIFFLIN_COEFFS["nonbinary"])
    rmr = c["weight"] * weight + c["height"] * height - c["age"] * age + c["intercept"]
    return max(0.0, rmr)
```

**Integração em `daily.py`:**
- RMR já existe implicitamente em `calories.py` (Harris-Benedict), mas é calculado per-sample dentro de `estimate_bout_calories`.
- Para calorias totais diárias: `total_kcal = rmr_kcal_per_day(profile) + sum(e["calories_kcal"] or 0 for e in ex_dicts)`.
- O profile já é lido em `compute_day`: `device_profile = read.query_profile(conn, device_id)`. [VERIFIED: codebase — linha 454 de `daily.py`]
- Se `device_profile` é None: `total_calories_kcal = None` (não estimar sem perfil).

**Coluna no DB:** `total_calories_kcal REAL` (nullable).

**Nota:** `exercise_sessions.calories_kcal` já existe por sessão de exercício. A nova coluna `daily_metrics.total_calories_kcal` é o agregado diário = RMR + exercício.

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Porquê |
|---------|---------------|------------------|-------|
| Rolling 7d baseline de sono | Loop manual | `read.query_daily` + `statistics.mean` | O padrão `_build_baselines` em `daily.py` já faz exactamente isto para HRV/RHR |
| Training State lookup | Reimplementar a lógica do lookup | Ler `recovery_to_strain.json` (já existe no iOS e no servidor) | O ficheiro já foi engenharia reversa e está validado no iOS |
| Migração GRDB iOS | Alterar schema manualmente | Migração `v9` no DatabaseMigrator existente (`Database.swift`) | O padrão v1–v8 já existe; uma v9 é trivial e segura |
| Parsing JSON em ServerSync | Código de deserialização custom | Reutilizar `ServerSync.dbl(r, "campo")` + `ServerSync.int(r, "campo")` | Funções utilitárias já existem e tratam NSNumber vs Double |
| Cálculo de RMR | Implementar de raiz num módulo novo | Adicionar `rmr_kcal_per_day` ao `calories.py` existente | O ficheiro já tem os coeficientes e o padrão (Harris-Benedict está lá) |

---

## Common Pitfalls

### Pitfall 1: Coluna `efficiency` vs `sleep_performance` no iOS

**O que corre mal:** O `MetricKind.sleepPerformance` em `MetricKind.swift` lê `metric.efficiency * 100` (linha 167). Se ALG-10 substituir `efficiency` pelo score ponderado, todos os views continuam a funcionar mas o valor muda silenciosamente. Se for adicionada uma coluna separada `sleep_performance`, o `MetricKind.sleepPerformance` precisa de ser atualizado para ler o novo campo.

**Como evitar:** Decidir explicitamente (CONTEXT.md ou planner) qual a abordagem (A ou B) antes de escrever código. Se B (coluna separada), actualizar `MetricKind.sleepPerformance.value(from:)` para ler `metric.sleepPerformance ?? metric.efficiency.map { $0 * 100 }` como fallback.

**Sinal de aviso:** `MetricKind.sleepPerformance` continua a retornar o raw `efficiency` depois de ALG-10 estar deployado.

### Pitfall 2: `recovery_to_strain.json` no servidor

**O que corre mal:** O ficheiro está em `server/ingest/app/analysis/recovery_to_strain.json` [VERIFIED: codebase]. A função `training_state()` usa `os.path.dirname(__file__)` para localizar o JSON. Se o servidor for deployado sem incluir o ficheiro no container, a função falha silenciosamente.

**Como evitar:** Verificar que o `Dockerfile`/`docker-compose` inclui o ficheiro. Adicionar guard + log de aviso quando o ficheiro não está disponível (retornar `None` em vez de excepção).

### Pitfall 3: `store.py` e `read.py` devem ser actualizados em conjunto

**O que corre mal:** Se `_DAILY_COLS` em `read.py` não incluir as novas colunas, o `/v1/today` retorna os campos novos como ausentes mesmo que estejam na DB. O iOS não recebe os valores.

**Como evitar:** O planner deve criar uma tarefa que actualiza `_DAILY_COLS`, `upsert_daily_metrics` INSERT, e `upsert_daily_metrics` DO UPDATE SET ao mesmo tempo, num único commit atómico.

### Pitfall 4: Migração GRDB v9 — adicionar colunas nullable

**O que corre mal:** Se a v9 não for registada correctamente no `DatabaseMigrator`, o app pode correr com o schema antigo e crashar ao tentar escrever/ler as colunas novas.

**Como evitar:** Seguir exactamente o padrão da v7 (que também adicionou colunas nullable): `try db.alter(table: "dailyMetric") { t in t.add(column: "xxx", .double) }`. Não usar `.notNull()` sem `.defaults(to:)` em colunas novas.

### Pitfall 5: Sleep Needed com dados históricos insuficientes

**O que corre mal:** Nos primeiros dias de dados, `sleep_needed` não tem 7 noites de baseline. Retornar `None` é correcto (igual ao que `recovery` faz no cold-start). Retornar um valor hardcoded (ex: 480) é enganador.

**Como evitar:** `sleep_needed()` deve retornar `None` se houver menos de 3 noites de histórico válidas. O display iOS deve mostrar "—" quando o campo é nil.

### Pitfall 6: Training State no iOS — server vs client-side

**O que corre mal:** `StrainCard.swift` calcula `trainingStateLabel` client-side a partir de `daily?.recovery` (0–1 fraction × 100) e `daily?.strain`. Com ALG-11, o servidor também computa e persiste o valor. Se o iOS ignorar o valor do servidor e continuar a usar apenas o client-side, os valores podem divergir (o servidor tem acesso a recovery mais preciso com baseline completa).

**Como evitar:** Decidir qual fonte tem prioridade. Recomendação: adicionar `trainingState: String?` ao `DailyMetric` Swift struct; `StrainCard` usa `daily?.trainingState ?? TrainingState.trainingState(...)` como fallback. Desta forma, o servidor tem prioridade quando disponível.

---

## Análise do Estado Actual do Código

### O que JÁ EXISTE (não precisa de ser construído)

| Item | Localização | Estado |
|------|------------|--------|
| Pipeline `compute_day()` com módulos separados | `daily.py` | Completo |
| `sleep_summary` com `efficiency`, `deep_min`, `rem_min`, `disturbances` | `sleep.py daily_sleep_summary()` | Completo |
| Leitura de `daily_metrics` históricos | `read.query_daily()` | Completo |
| Leitura de perfil do utilizador (peso, altura, idade, sexo) | `read.query_profile()` | Completo |
| Calorias por sessão de exercício (Keytel + Harris-Benedict) | `calories.estimate_bout_calories()` | Completo |
| Training State lookup table (iOS) | `TrainingState.swift`, `recovery_to_strain.json` | Completo |
| Badge Training State em `StrainCard` | `StrainCard.swift` | Completo |
| `MetricKind.sleepPerformance` (lê `efficiency * 100`) | `MetricKind.swift` | Completo (mas lê proxy, não score real) |
| Padrão de migração GRDB (v1–v8) | `Database.swift` | Completo |
| Padrão `_DAILY_COLS` + upsert | `read.py`, `store.py` | Completo |
| Endpoint `/v1/today` | `main.py` | Completo (só precisa das novas colunas) |
| Parsing de `DailyMetric` em `ServerSync.getDaily/getTodayMetric` | `ServerSync.swift` | Completo (padrão a seguir) |

### O que FALTA (trabalho desta fase)

| Item | Ficheiro | Tipo de mudança |
|------|---------|----------------|
| `sleep_performance_score()` | `sleep.py` | Nova função pura |
| `training_state()` via JSON | `daily.py` ou novo módulo | Nova função pura |
| `sleep_needed()` | `daily.py` | Nova função pura |
| `rmr_kcal_per_day()` (Mifflin–St Jeor) | `calories.py` | Nova função pura |
| `daily_total_calories()` | `calories.py` ou `daily.py` | Nova função pura |
| 4 × `ALTER TABLE daily_metrics` | `init.sql` | Migração idempotente |
| `_DAILY_COLS` + upsert update | `read.py`, `store.py` | Adicionar 4 campos |
| Chamadas em `compute_day()` | `daily.py` | Integrar 4 algoritmos |
| GRDB migração v9 | `Database.swift` | 4 × `t.add(column:)` |
| `DailyMetric` struct + `upsertDailyMetrics` + `dailyMetrics` | `MetricsCache.swift` | 4 campos opcionais |
| Parse 4 novos campos JSON | `ServerSync.swift` | `getDaily`, `getTodayMetric` |
| CALORIES card no Today | `TodayView.swift` | Novo `MetricCard` |
| `trainingState` field preference (server > client) | `StrainCard.swift` + `DailyMetric` | Fallback logic |
| `MetricKind.sleepPerformance` → novo campo | `MetricKind.swift` | Actualizar `value(from:)` |

---

## Validation Architecture

### Framework de Testes Existente

| Propriedade | Valor |
|------------|-------|
| Framework | pytest (servidor Python) + XCTest (iOS Swift) |
| Config servidor | `server/ingest/` — verificar `pyproject.toml`/`setup.cfg` |
| Framework iOS | XCTest — `ios/OpenWhoopTests/` |
| Comando rápido (servidor) | `python -m pytest server/ingest/tests/ -x -q` (path a confirmar) |
| Comando rápido (iOS) | Build + test via XcodeBuildMCP |

### Mapa Requisitos → Testes

| Req ID | Comportamento | Tipo de Teste | Testável Automaticamente |
|--------|-------------|--------------|--------------------------|
| ALG-10 | `sleep_performance_score()` retorna 0–100, satura correctamente | Unit (Python) | Sim |
| ALG-11 | `training_state()` retorna RESTORATIVE/OPTIMAL/OVERREACHING | Unit (Python) | Sim |
| ALG-12 | `sleep_needed()` retorna None sem histórico, valor plausível com histórico | Unit (Python) | Sim |
| ALG-13 | `rmr_kcal_per_day()` correctness vs valores de referência Mifflin | Unit (Python) | Sim |
| ALG-13 | `total_calories_kcal = rmr + exercise` em `compute_day` | Integration (Python) | Sim (mock DB) |
| ALG-10–13 | Novas colunas aparecem em `/v1/today` | Integration (API) | Sim |
| ALG-10–13 | `DailyMetric` iOS parse e GRDB round-trip | Unit (Swift) | Sim |
| ALG-13 | CALORIES card visível no Today view com valor não nulo | Manual/UI | Manual (requer device) |

---

## Assumptions Log

| # | Afirmação | Secção | Risco se errada |
|---|----------|--------|-----------------|
| A1 | Pesos do Sleep Performance score (0.30/0.30/0.25/0.15) são razoáveis como proxy | ALG-10 | Score pode não corresponder ao comportamento esperado; ajustável sem mudança de API |
| A2 | Adicionar coluna separada `sleep_performance` é preferível a substituir `efficiency` (opção B) | ALG-10 | Se opção A for escolhida, MetricKind.sleepPerformance não precisa de mudança |
| A3 | Strain debt formula: +4min por unidade acima de strain=10, máx 60min | ALG-12 | Sleep Needed pode estar sobre/subestimado; ajustável |
| A4 | Sleep debt = 20% do défice acumulado 7d adicionado por dia | ALG-12 | Mesma — ajustável |
| A5 | Mifflin–St Jeor é o método pretendido para RMR (ROADMAP menciona "Mifflin–St Jeor") | ALG-13 | Se Harris-Benedict (já em calories.py) for preferido, não é necessária nova fórmula |
| A6 | `training_state` TEXT nullable é o tipo correcto para a coluna PostgreSQL | ALG-11 | Poderia ser um enum PostgreSQL; TEXT é mais simples e compatível com ALTER TABLE IF NOT EXISTS |
| A7 | iOS `StrainCard` deve preferir o valor do servidor sobre o client-side | ALG-11 | Se client-side for preferido, não é necessária mudança em StrainCard |
| A8 | `sleep_performance_score` deve ser passado ao `recovery_score` como `sleep_perf` melhorado | ALG-10 | Recovery score pode mudar subtilmente quando o proxy melhora; requer avaliação |

---

## Open Questions (RESOLVED)

1. **Sleep Performance: substituir `efficiency` ou adicionar nova coluna?**
   - RESOLVED: opção B — nova coluna separada `sleep_performance REAL`; `efficiency` mantém-se como TST/TIB bruto. `MetricKind.sleepPerformance.value(from:)` actualizado em 13-04 para ler o campo real com fallback a `efficiency * 100`.

2. **Training State no iOS: server vs client-side fallback?**
   - RESOLVED: server tem prioridade — `StrainCard` usa `daily?.trainingState` (campo do servidor) quando não nil; fallback para `TrainingState.trainingState(recovery:strain:)` client-side quando nil. Implementado em 13-04.

3. **CALORIES card no TodayView: como e onde mostrar?**
   - RESOLVED: novo `caloriesCard` ViewBuilder condicional em `TodayView`, só visível quando `totalCaloriesKcal != nil`. Adicionado como linha extra abaixo da grelha HRV/RHR. Implementado em 13-04.

4. **`sleep_performance` deve alimentar o `recovery_score` como `sleep_perf` melhorado?**
   - RESOLVED: não — o `sleep_perf` que entra no `recovery_score` continua a ler `efficiency` (raw 0..1) para não perturbar o pipeline de recovery calibrado. O novo `sleep_performance` é uma coluna independente. A normalização de escala é desnecessária porque os dois campos co-existem.

---

## Environment Availability

| Dependência | Necessária por | Disponível | Notas |
|------------|---------------|-----------|-------|
| PostgreSQL + TimescaleDB | Escrita de novas colunas | Sim (servidor gonzaga) | `ALTER TABLE IF NOT EXISTS` é idempotente |
| Python 3.11+ stdlib `statistics`, `json`, `os` | Algoritmos novos | Sim | Sem instalação nova |
| `recovery_to_strain.json` no servidor | ALG-11 | Sim — ficheiro existe em `server/ingest/app/analysis/` | [VERIFIED: codebase] |
| Xcode / iOS simulator | Testes iOS | Sim | XcodeBuildMCP disponível |

---

## Metadata de Confiança

| Área | Nível | Razão |
|------|-------|-------|
| Stack técnica existente | HIGH | Verificado directamente no codebase |
| Algoritmos propostos (fórmulas) | MEDIUM | Baseados em literatura publicada + análise de IPA; fórmulas exactas do WHOOP são proprietárias |
| Caminho de integração | HIGH | Padrão idêntico ao de `spo2_pct`/`skin_temp_dev_c` — verificado no código |
| Pesos do sleep performance score | LOW | Hipótese razoável, mas não validada contra dados reais |
| Sleep Needed coefficients | LOW | Hipótese baseada em comportamento publicado do WHOOP; valores exactos são ASSUMED |

**Data de pesquisa:** 2026-06-01
**Válido até:** 2026-07-01 (código base estável)

---

## Sources

### Primárias (HIGH confidence — verificadas no codebase)
- `server/ingest/app/analysis/daily.py` — orchestrador e ponto de integração
- `server/ingest/app/analysis/sleep.py` — `daily_sleep_summary()`, `hypnogram_metrics()`
- `server/ingest/app/analysis/calories.py` — `estimate_bout_calories()`, padrão de coeficientes
- `server/ingest/app/analysis/baselines.py` — `fold_history()`, `BaselineState`
- `server/ingest/app/analysis/recovery.py` — `recovery_score()`, `SLEEP_PERF_CENTER`
- `server/ingest/app/read.py` — `_DAILY_COLS`, `query_daily()`, `query_profile()`
- `server/ingest/app/store.py` — `upsert_daily_metrics()`
- `server/db/init.sql` — schema PostgreSQL actual
- `ios/OpenWhoop/Upload/ServerSync.swift` — `getDaily()`, `getTodayMetric()`
- `Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift` — `DailyMetric` struct
- `Packages/WhoopStore/Sources/WhoopStore/Database.swift` — migrações v1–v8
- `ios/OpenWhoop/BLE/TrainingState.swift` — lookup table client-side
- `ios/OpenWhoop/Design/Components/StrainCard.swift` — badge Training State
- `ios/OpenWhoop/Charts/MetricKind.swift` — `MetricKind.sleepPerformance`
- `server/ingest/app/analysis/recovery_to_strain.json` — tabela de lookup

### Secundárias (MEDIUM confidence — literatura publicada)
- Mifflin, St Jeor et al. (1990). "A new predictive equation for resting energy expenditure." *Am. J. Clin. Nutr.* — fórmula RMR
- IPA class names de `com.whoop.iphone_5.37.0`: `SleepPerformanceCalculator`, `SleepNeededCalculator`, `TrainingStateCalculator` — confirmam que estes algoritmos existem no WHOOP
