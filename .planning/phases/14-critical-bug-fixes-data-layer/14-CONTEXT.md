# Phase 14: Critical Bug Fixes (Data Layer) - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Corrigir 3 bugs de data layer na app iOS:
1. **BUGFIX-01** — `sleepNeededMin` (ALG-12) calculado pelo `LocalMetricsComputer` mas não exibido em nenhuma view
2. **BUGFIX-02** — `SleepCard` e `RecoveryCard` lêem `efficiency` (0.0–1.0 raw) em vez de `sleepPerformance` (0–100 composto)
3. **BUGFIX-03** — Migration GRDB v10 já implementada em `Database.swift`; falta cobertura de teste para verificar o comportamento de limpeza

Sem mudanças de arquitectura. Sem novas features. Sem tocar em ficheiros Ghidra/RE.

</domain>

<decisions>
## Implementation Decisions

### BUGFIX-01 — sleepNeededMin display

- **D-01:** Adicionar 3ª coluna "SLEEP NEEDED" ao `SleepCard`, ao lado de "HOURS OF SLEEP" e "SLEEP PERFORMANCE". Usar a infra `statColumn()` já existente. Formato: `"7h 30m"` (mesmo `formatMinutes()` que existe no `SleepView`).
- **D-02:** A Fase 17 (UI Redesign 1:1) ajusta a posição exacta com base nos findings do Ghidra. O requisito BUGFIX-01 ("mostrar em vez de nada") fica satisfeito nesta fase com a 3ª coluna.
- **D-03:** `SleepView` não precisa de exibir `sleepNeededMin` separadamente — o `SleepCard` já o mostra. Não duplicar.

### BUGFIX-02 — sleepPerformance vs efficiency

- **D-04:** `SleepCard.sleepPerformanceLabel` deve ler `daily?.sleepPerformance` (0–100 Int) em vez de `daily?.efficiency`. Remover o fallback para `session?.efficiency`.
- **D-05:** `RecoveryCard.sleepLabel` deve ler `daily?.sleepPerformance` em vez de `daily?.efficiency`. Formato: `"\(Int(score.rounded()))%"`.
- **D-06:** Quando `sleepPerformance` é `nil`, mostrar `"—"`. Sem fallback para `efficiency` — seria enganoso (efficiency != sleepPerformance).

### headlineSection — código morto

- **D-07:** Remover `SleepView.headlineSection` completamente. É uma computed property nunca referenciada em `scrollContent` (o `SleepCard` substituiu-a). Elimina também o TODO stale na linha 132.

### BUGFIX-03 — cobertura de testes

- **D-08:** Adicionar teste de comportamento completo para migration v10 em `MigrationTests.swift`:
  1. Inserir `rrInterval` rows com `rrMs` fora de [200, 2000] (ex: rrMs=50 e rrMs=65535)
  2. Inserir `dailyMetric` com `avgHrv != nil`
  3. Correr o migrator até v10
  4. Verificar: rows inválidas apagadas, rows válidas intactas, `avgHrv` = NULL em todos os dailyMetric
- **D-09:** A migration v10 já está implementada em `Database.swift` (linhas 184–193) — não tocar.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Schema e Migração
- `Packages/WhoopStore/Sources/WhoopStore/Database.swift` — migrator completo; v9 adiciona sleepPerformance/sleepNeededMin; v10 purga RR inválidos e limpa avgHrv
- `Packages/WhoopStore/Sources/WhoopStore/MetricsCache.swift` — struct `DailyMetric` com campos `sleepPerformance: Double?` e `sleepNeededMin: Double?`

### Views a modificar
- `ios/OpenWhoop/Design/Components/SleepCard.swift` — BUGFIX-01 (add 3ª coluna) + BUGFIX-02 (efficiency→sleepPerformance)
- `ios/OpenWhoop/Design/Components/RecoveryCard.swift` — BUGFIX-02 (efficiency→sleepPerformance)
- `ios/OpenWhoop/Tabs/SleepView.swift` — remover `headlineSection` morta

### Métricas computadas
- `ios/OpenWhoop/Metrics/LocalMetricsComputer.swift` — calcula sleepPerformance (linha 183), sleepNeededMin (linha 185), avgHrv (linha 176); fonte de verdade offline

### Testes
- `Packages/WhoopStore/Tests/WhoopStoreTests/MigrationTests.swift` — adicionar teste v10

### Requirements
- `.planning/REQUIREMENTS.md` §Bug Fixes (Data Layer) — BUGFIX-01, BUGFIX-02, BUGFIX-03 com acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SleepCard.statColumn(label:value:)` — helper reutilizável para colunas de estatística; usar directamente para a 3ª coluna sleepNeededMin
- `SleepView.formatMinutes(_:)` — formata minutos como "7h 30m"; lógica idêntica para exibir sleepNeededMin (ex: 450 → "7h 30m")
- `WhoopStore.makeMigrator()` — pattern estabelecido para migrations GRDB; v10 já existe como modelo

### Established Patterns
- `daily?.sleepPerformance` — `Double?` entre 0–100; converter com `Int(score.rounded())`
- `daily?.sleepNeededMin` — `Double?` em minutos; formatar com `formatMinutes()`
- Views usam `"—"` para nil em todos os campos — padrão consistente a manter
- MigrationTests segue padrão: criar DB em memória, inserir dados, correr migrator, verificar estado final

### Integration Points
- `SleepCard` recebe `daily: DailyMetric?` — já tem acesso a `sleepNeededMin` e `sleepPerformance`; não precisa de mudanças de interface
- `RecoveryCard` recebe `daily: DailyMetric?` — mesma situação; só muda a leitura do campo

</code_context>

<specifics>
## Specific Ideas

- A placement exacta do `sleepNeededMin` (3ª coluna no SleepCard) é provisional; a Fase 17 ajusta para corresponder ao Ghidra screen map
- O formato "SLEEP NEEDED" é o label provisório; Fase 17 pode renomear com base no Ghidra
- Migration v10: o `UPDATE dailyMetric SET avgHrv = NULL` é intencional — limpa tudo para o LocalMetricsComputer recomputar de RR limpos

</specifics>

<deferred>
## Deferred Ideas

- Confirmar no IPA (Ghidra, Fase 15) a posição exacta e label do "sleep needed" no WHOOP app antes de finalizar layout na Fase 17
- Exibição de `sleepNeededMin` no `SleepView` fora do `SleepCard` — avaliar após Ghidra (Fase 17)

</deferred>

---

*Phase: 14-Critical Bug Fixes (Data Layer)*
*Context gathered: 2026-06-01*
