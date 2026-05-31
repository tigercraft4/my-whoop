# Phase 10: Algorithms Display + Server Endpoint - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Ligar os resultados dos algoritmos já computados no servidor (Recovery via `recovery.py`, Sleep staging via `sleep.py`, Strain via `strain.py`) às iOS views da Phase 9 (RecoveryCard, SleepCard, StrainCard). Adicionar endpoint `GET /v1/today?device=<id>` ao servidor. Wire indicador de staleness de 6h no RecoveryCard.

**Entry condition:** Phase 7 (dados reais em store) + Phase 9 (iOS views com cards implementados).

**Deliverables:**
1. Endpoint `GET /v1/today?device=<id>` no FastAPI server
2. `ServerSync.pullDerived()` actualizado para usar `/v1/today` (ou lógica equivalente)
3. RecoveryCard: staleness label "Updated Xh ago" quando `lastRefreshedAt > 6h`
4. iOS views lendo dados do servidor com precedência sobre `LocalMetricsComputer`
5. SleepCard mostrando staging de `sleep.py` (Cole-Kripke output)
6. StrainCard mostrando strain de `strain.py` (Edwards TRIMP)

**Out of scope:** Modificações ao pipeline de algoritmos no servidor (`compute_day()`, `sleep.py`, `strain.py` já existem e funcionam), HealthKit (→ Phase 11), novo UI (→ Phase 9).

</domain>

<decisions>
## Implementation Decisions

### `/v1/today` endpoint

- **D-01:** **Novo endpoint distinto de `/v1/daily`** — adicionar `GET /v1/today?device=<id>` ao `server/ingest/app/main.py`. O `/v1/daily` existente requer `from` e `to` (date range); o `/v1/today` é mais simples: retorna a row mais recente ou a row do dia UTC actual ao critério do planeador (ALG-04 diz "sem edge case de UTC no client" — o server resolve a lógica de data).

- **D-02:** **Semântica ao critério do planeador:** duas opções igualmente válidas:
  - `SELECT * FROM daily_metrics WHERE device_id=? ORDER BY day DESC LIMIT 1` — row mais recente (nunca null se tiver dados históricos)
  - `SELECT * FROM daily_metrics WHERE device_id=? AND day=current_date` — row do UTC actual (pode ser null se hoje não tiver sido computado)
  - Planeador escolhe a que melhor serve o caso de uso (Recovery card mostra o "hoje" — provavelmente a row mais recente é mais robusta)

- **D-03:** **Autenticação:** mesmo padrão `Depends(require_auth)` que todos os outros endpoints.

- **D-04:** **Response format:** single JSON object (ou `null`) — não array. Consistente com o que a iOS app espera para um único valor.

### Staleness indicator

- **D-05:** **`StalenessPolicy.staleAfterSeconds = 6 * 3600` já existe** — não mudar este valor. O threshold de 6h para o RecoveryCard é o mesmo.

- **D-06:** **Indicador visual: label de texto subtil "Updated Xh ago"** abaixo do anel/score no RecoveryCard. Texto pequeno, cor `WH.Color.textSecondary` (ou cinzento). Aparece quando `Date().timeIntervalSince(lastRefreshedAt) > 6 * 3600`. Formato: "Updated 8h ago" (horas inteiras).

- **D-07:** **Só no RecoveryCard** — staleness indicator não necessário no SleepCard ou StrainCard nesta fase. RecoveryCard é o ponto de entrada principal da app.

### Local vs server algorithm precedência

- **D-08:** **Servidor ganha quando disponível** — quando `DailyMetric.recovery` vem do `pullDerived()` (servidor), esse valor tem precedência. `LocalMetricsComputer` só é usado quando:
  - Servidor não está configurado (`AppConfig.uploaderConfig() == nil`)  
  - `pullDerived()` falha ou retorna nil para este campo
  - Offline / sem conectividade

- **D-09:** **Não mudar a interface de `MetricsRepository`** — `DailyMetric` struct já tem campos `recovery`, `strain`, `sleepDuration` etc. A precedência é implementada no `ServerSync.pullDerived()` / `LocalMetricsComputer` — o view layer não precisa de saber a origem.

- **D-10:** **`LocalMetricsComputer` não é removido** — permanece como fallback. Só a lógica de precedência muda (server > local quando server disponível).

### Claude's Discretion

- Semântica exacta de `/v1/today` (row mais recente vs row do UTC actual)
- Formato exacto do staleness label ("Updated 8h ago" vs "8h ago" vs "Refreshed 8h ago")
- Onde no RecoveryCard o label aparece (abaixo do anel, abaixo dos sub-campos)
- Lógica de precedência local: usar um `enum DataSource { case server, local }` explícito ou simplesmente condicional inline

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Server

- `server/ingest/app/main.py` — localização dos endpoints; `/v1/daily` (linha 239) como referência para o novo `/v1/today`; padrão `Depends(require_auth)`, `psycopg.connect(cfg.db_dsn)`, `read.query_*()`
- `server/ingest/app/read.py` (ou equivalente) — funções de query a reutilizar/adaptar para `/v1/today`
- `server/ingest/app/analysis/daily.py` — `compute_day()` que popula `daily_metrics`

### Requirements desta fase

- `.planning/REQUIREMENTS.md` — ALG-01, ALG-02, ALG-03, ALG-04 (com critérios exactos)
- `.planning/ROADMAP.md` §"Phase 10" — 4 success criteria

### iOS — Staleness e sync

- `ios/OpenWhoop/Sync/StalenessPolicy.swift` — `staleAfterSeconds = 6 * 3600` já existente; NÃO mudar este valor
- `ios/OpenWhoop/Metrics/MetricsRepository.swift` — `lastRefreshedAt: Date?` @Published; `refresh()` → `pullDerived()` chain
- `ios/OpenWhoop/Upload/ServerSync.swift` — `pullDerived()` implementação; local de integração do `/v1/today`

### iOS — Views (Phase 9 output — podem não existir ainda)

- `ios/OpenWhoop/Tabs/TodayView.swift` — RecoveryCard a receber staleness indicator (linha 326 já usa `lastRefreshedAt`)
- `ios/OpenWhoop/Metrics/LocalMetricsComputer.swift` — fallback que permanece; lógica de precedência server > local

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `StalenessPolicy.staleAfterSeconds` — constante 6h já definida; usar directamente para calcular se o label deve aparecer
- `/v1/daily` endpoint — padrão de query a reutilizar para `/v1/today` (auth, psycopg, read.query_*)
- `MetricsRepository.lastRefreshedAt` — @Published property; RecoveryCard já pode observar esta via `@EnvironmentObject var metrics`
- `LocalMetricsComputer` — permanece como fallback; não remover

### Established Patterns

- **Auth nos endpoints:** `Depends(require_auth)` em todos os endpoints existentes — replicar em `/v1/today`
- **DB connection:** `with psycopg.connect(cfg.db_dsn) as conn:` — padrão de cada endpoint; replicar
- **Server wins when available:** precedência servidor > local é conceptualmente simples — basta ter o campo populado via `pullDerived()` e o view usar esse valor
- **Staleness display pattern:** `TodayView.swift` linha 326 já faz `if let at = metrics.lastRefreshedAt` — extensão directa para o staleness label

### Integration Points

- `main.py` → novo `@app.get("/v1/today", ...)` route
- `ServerSync.pullDerived()` → chamar `/v1/today` para obter o daily_metrics mais recente
- `RecoveryCard` (Phase 9) → staleness label condicionado a `lastRefreshedAt`
- `MetricsRepository` → lógica de precedência server > local em `refresh()`

</code_context>

<specifics>
## Specific Ideas

- **`/v1/today` response:** `{"day": "2026-05-31", "recovery": 78, "hrv_rmssd": 42.3, ...}` — mesmo schema que uma row de `/v1/daily`, single object em vez de array
- **Staleness label format:** `"Updated 8h ago"` — usar `Int((Date().timeIntervalSince(lastRefreshedAt)) / 3600)` para horas inteiras. Aparece só quando > 6h.
- **iOS integration:** `ServerSync.pullDerived()` faz `GET /v1/today?device=deviceId` → popula `DailyMetric` mais recente → `MetricsRepository.refresh()` → RecoveryCard re-renderiza

</specifics>

<deferred>
## Deferred Ideas

- Notificações push quando Recovery computation termina no servidor — pós v2.0
- Histórico de Recovery por semana (tendência) — já parcialmente no TrendsView
- HealthKit export dos resultados de algoritmos → Phase 11

</deferred>

---

*Phase: 10-algorithms-display-server-endpoint*
*Context gathered: 2026-05-31*
