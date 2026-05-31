# Phase 12: UI Parity - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning
**Mode:** Auto-generated from spike analysis (discuss skipped — all decisions confirmed via Ghidra MCP + IPA analysis)

<domain>
## Phase Boundary

Corrigir todos os labels e métricas para paridade 1:1 com a app WHOOP 5.37.0, com base na análise do IPA (docs/whoop-ui-reference.md) e da análise Ghidra MCP. Sem novas funcionalidades — apenas correcções de labels, layout, e cálculos.

**Deliverables:**
1. SleepCard: "SLEEP EFFICIENCY" → "SLEEP PERFORMANCE", "TIME ASLEEP" → "HOURS OF SLEEP", AWAKE como 4ª fase
2. StrainCard/StrainView: Training State badge (RESTORATIVE/OPTIMAL/OVERREACHING) com recovery_to_strain.json
3. TrendsView: MetricKind.sleepDuration → sleepPerformance como métrica principal de sono (IOS-05 já tem spo2/skinTemp)
4. Labels gerais: corrigir capitalização e nomenclatura para match exacto com WHOOP
5. Sleep Latency label: "LATENCY" → "SLEEP LATENCY"

**Out of scope:** Novos algoritmos de backend (Phase 13), HealthKit (Phase 11 completa), novas views.

</domain>

<decisions>
## Implementation Decisions

### SleepCard — "SLEEP PERFORMANCE" e "HOURS OF SLEEP"

- **D-01:** Mudar label "SLEEP EFFICIENCY" → "SLEEP PERFORMANCE" em `SleepCard.swift` e qualquer outro ficheiro que use o label antigo
- **D-02:** Mudar label "TIME ASLEEP" → "HOURS OF SLEEP" (ou "HOURS OF SLEEP" conforme string key `SleepPerformance.HoursOfSleep`)
- **D-03:** O cálculo de Sleep Performance no servidor já usa `TST / sleep_needed × 100` (confirmado na análise). No iOS, o `SleepCard` mostra `efficiency` de `DailyMetric` — este campo é populado pelo servidor. NÃO mudar a lógica de cálculo no iOS, só o label.
- **D-04:** Adicionar AWAKE como 4ª fase no `HypnogramView` — actualmente só mostra REM/Deep/Light. Adicionar `awake` na stacked bar com cor distinta (cinzento claro, como o WHOOP). Se `CachedSleepSession.stagesJSON` já tem awake, usar; caso contrário calcular como `totalTime - (deep + rem + light)`.

### StrainCard — Training State

- **D-05:** Adicionar badge de **Training State** ao `StrainCard` com base em `recovery_to_strain.json`. Mostrar: "RESTORATIVE", "OPTIMAL", "OVERREACHING" (não mostrar "IMPOSSIBLE" a menos que a lookup table o indique claramente). A lookup usa o `DailyMetric.recovery` do servidor.
- **D-06:** Cores do badge: RESTORATIVE = recoveryBlue (descanso), OPTIMAL = recoveryGreen, OVERREACHING = recoveryRed.
- **D-07:** Training State só aparece quando `DailyMetric.recovery != nil`. Se nil, omitir o badge.
- **D-08:** Zona label: abaixo do gauge de strain, mostrar o texto da zona actual (RESTORATIVE/OPTIMAL/OVERREACHING) como o WHOOP faz — usando as strings `ActivityStrainView.StrainLevel.*`.

### TrendsView — Sleep Performance como métrica

- **D-09:** Em `MetricKind`, adicionar `.sleepPerformance` (label: "SLEEP PERFORMANCE", format: "%.0f%%") e remover ou manter `.sleepDuration` como secundário. A métrica principal de sono nas Trends é Sleep Performance (0-100%), não a duração.
- **D-10:** `MetricKind.sleepPerformance.value(from: DailyMetric)` → usar `metric.efficiency` (que no servidor representa sleep_performance). Tipo Double?, format "%.0f%%".
- **D-11:** `MetricKind.dailyCases` actualizar: substituir `.sleepDuration` por `.sleepPerformance`.

### Labels gerais a corrigir

- **D-12:** "LATENCY" → "SLEEP LATENCY" na SleepCard
- **D-13:** Skin temp: se mostrado como "Skin Temp Dev" mudar para "SKIN TEMP" com unidade "°C from baseline" separada. Se não há capacidade de mostrar valor absoluto (não disponível sem PROTO-12 VERIFIED), manter "FROM BASELINE" com o desvio.
- **D-14:** RHR label: se "Resting HR" → "RHR" (caps, mais compacto, match WHOOP)

### Claude's Discretion

- Implementação exacta do badge de Training State (SwiftUI Shape vs Text vs Chip)
- Cor exacta do badge RESTORATIVE (pode ser strainBlue ou uma cor nova)
- Se adicionar `.sleepDuration` como caso extra em dailyCases ou remover completamente
- Tratamento do awake time: usar `stagesJSON.awake` se disponível, senão calcular
- Ordem das métricas no TrendsView após a mudança

</decisions>

<canonical_refs>
## Canonical References

- `.planning/spikes/whoop-clone-analysis/01-ui-layout.md` — gaps identificados e labels correctos
- `.planning/spikes/whoop-clone-analysis/02-algorithms.md` — fórmulas (Sleep Performance = TST/sleep_needed)
- `docs/whoop-ui-reference.md` — referência UI completa da IPA 5.37.0 (429 linhas)
- `server/ingest/app/analysis/recovery_to_strain.json` — lookup table Training State
- `ios/OpenWhoop/Design/Components/SleepCard.swift` — a corrigir (labels + AWAKE)
- `ios/OpenWhoop/Design/Components/StrainCard.swift` — adicionar Training State badge  
- `ios/OpenWhoop/Tabs/StrainView.swift` — zona label
- `ios/OpenWhoop/Charts/MetricKind.swift` — adicionar sleepPerformance, actualizar dailyCases
- `ios/OpenWhoop/Tabs/TrendsView.swift` — verificar se sleepDuration é referenciado explicitamente
- `.planning/REQUIREMENTS.md` — IOS-05 (deferido de Phase 7), UI-02 a UI-05

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WH.Color.recoveryGreen/Yellow/Red` — já definidas para Recovery zones; usar para Training State
- `WH.Color.strainAccent` (azul) — cor para RESTORATIVE
- `HypnogramView` — já mostra staged bar; adicionar AWAKE como nova `SleepStage`
- `ZoneRingView` — já reutilizável para Recovery e Strain; não mudar

### Patterns
- `MetricKind` enum com `value(from:)`, `formatShort()`, `label`, `unit`, `color` — seguir o mesmo padrão para `.sleepPerformance`
- `DailyMetric.efficiency: Double?` — campo existente; no servidor representa sleep performance (não raw efficiency)
- `CachedSleepSession.stagesJSON` — JSON com REM/Deep/Light; verificar se tem `awake` field

### Integration Points
- `StrainCard(daily: DailyMetric?)` — adicionar param para Recovery quando disponível
- `recovery_to_strain.json` — carregar em bundle iOS (já copiado para `ios/OpenWhoop/Resources/`)
- Training State function: `trainingState(recovery: Double, strain: Double) -> String` usando a lookup table

</code_context>

<specifics>
## Specific Implementation Notes

- `strain_raw_scale_lookup.json` já está no bundle iOS (Resources/) — não duplicar para Training State
- `recovery_to_strain.json` NÃO está ainda no bundle iOS — copiar para Resources/ se necessário
- Training State lookup: dado `recovery` (0-100), encontrar a linha na tabela e comparar `strain` com `lower_rec_strain` e `upper_rec_strain`
- AWAKE cor: usar `WH.Color.textSecondary` ou cinzento claro (#555) — o WHOOP usa um cinzento neutro para awake

</specifics>

<deferred>
## Deferred Ideas

- CALORIES no Today view → Phase 13 (requer computação server-side de calorias totais)
- Sleep Needed breakdown display → Phase 13 (requer endpoint /coaching-service/v2/sleepneed)
- Blood Oxygen / Respiratory Rate no Health tab → Phase 13 (requer PROTO-11 VERIFIED)
- Haptics 1:1 (DRV2605 payload) → PacketLogger capture (hardware pendente)

</deferred>

---

*Phase: 12-ui-parity*
*Context gathered: 2026-06-01 (auto-generated from spike — no discussion needed)*
