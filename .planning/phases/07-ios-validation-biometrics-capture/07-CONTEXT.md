# Phase 7: iOS Validation + Biometrics Capture - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Dois tracks em paralelo após Phase 6 (backfill fix):

**Track A — Biometrics Capture (independente):** Enviar TOGGLE_IMU_MODE ao WHOOP 5.0 via script bleak + botão debug iOS e capturar sessão dedicada até todos os 4 streams aparecerem nos logs (PROTO-11 SpO₂, PROTO-12 skin temp, PROTO-13 respiration, PROTO-14 IMU/gravity). Validar SpO₂ contra oxímetro de referência.

**Track B — iOS View Validation (depende do Phase 6):** Confirmar que TodayView, SleepView e TrendsView mostram dados reais do WHOOP 5.0 (não placeholders) após backfill funcional. Criar Maestro test para IOS-08 background reconnect.

**Deliverables:**
1. Script bleak (ou extensão re_harness.py) para enviar TOGGLE_IMU_MODE e capturar session
2. Botão debug "TOGGLE_IMU_MODE" em Settings tab do iOS app (implementation at Claude's discretion)
3. Artefactos VERIFIED para cada stream validado: schema JSON + FINDINGS_5.md + PacketLogger evidence + REQUIREMENTS.md tick
4. Maestro test `07_ios08_background_reconnect.yaml` para IOS-08
5. iOS views (Today, Sleep, Trends) a mostrar dados reais confirmados

**Out of scope:** SpO₂/skinTemp chart series em TrendsView (→ Phase 9 redesign), novas iOS views, mudanças ao backfill pipeline (→ Phase 6).

</domain>

<decisions>
## Implementation Decisions

### TOGGLE_IMU_MODE trigger

- **D-01:** **Dois mecanismos para enviar TOGGLE_IMU_MODE:** (a) script Python (bleak ou re_harness.py) do Mac para a sessão de captura desta fase; (b) botão debug na Settings tab do iOS app para uso futuro. Ambos necessários.

- **D-02:** **Captura termina quando as 4 streams aparecem nos logs** — não por tempo fixo. O planeador decide a estrutura exacta do script Python e do botão iOS.

- **D-03:** **Implementação do botão iOS ao critério do planeador** — toggle com estado visível (IMU Mode: ON/OFF) ou botão de acção única. Deve ser visível apenas em modo debug/dev.

### Biometric Verification artifacts

- **D-04:** **Quando um stream é VERIFIED, commitar todos os 4 artefactos:**
  1. `protocol/whoop_protocol_5.json` — actualizar `confidence: "HYPOTHESIS"` → `"VERIFIED"` nos campos relevantes; correr `scripts/sync-schema.sh` para sincronizar com Swift bundle
  2. `FINDINGS_5.md` — adicionar linha VERIFIED na tabela com valor medido, método de ground truth, e data
  3. `re/capture/evidence/` — commitar excerpt do log PacketLogger ou raw dump filtrado como prova
  4. `.planning/REQUIREMENTS.md` — marcar PROTO-11/12/13/14 como done quando VERIFIED

- **D-05:** **Threshold de aceitação SpO₂ ao critério do planeador** — ±2% vs oxímetro consumer é o standard clínico típico; planeador documenta o critério no runbook de validação.

### IOS-08 Background Reconnect

- **D-06:** **Maestro automation para IOS-08** — novo ficheiro `ios/maestro/07_ios08_background_reconnect.yaml`. Segue padrão dos 6 Maestro tests existentes. Critério de sucesso (Connected indicator vs HR ao vivo) ao critério do planeador com base nos Maestro patterns existentes.

### TrendsView (IOS-05)

- **D-07:** **IOS-05 (SpO₂/skinTemp chart series no TrendsView) deferido para Phase 9.** Rationale: success criteria da Phase 7 não incluem IOS-05 explicitamente; Phase 9 vai redesenhar TrendsView de raiz em WHOOP-style — implementar agora seria retrabalho. A Phase 7 valida apenas que TodayView e SleepView mostram dados reais.

### Claude's Discretion

- Estrutura exacta do script Python (standalone vs modo no re_harness.py)
- UI exacta do botão TOGGLE_IMU_MODE (toggle vs action button)
- Threshold exacto de aceitação SpO₂ vs oxímetro (documentar no runbook)
- Critério do Maestro test IOS-08 (Connected indicator vs HR ao vivo)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Protocolo e streams biométricos

- `FINDINGS_5.md` — tabela HYPOTHESIS/VERIFIED; TOGGLE_IMU_MODE documentado; streams PROTO-11/12/13/14 com notas de offset
- `protocol/whoop_protocol_5.json` — campos confidence: "HYPOTHESIS" que serão actualizados para "VERIFIED"; campo spo2, skinTemp, respiration, gravity
- `server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json` — cópia Python do schema (sincronizar após update)

### Requirements desta fase

- `.planning/REQUIREMENTS.md` — IOS-03, IOS-04, IOS-05, IOS-08, PROTO-11, PROTO-12, PROTO-13, PROTO-14 (com critérios exactos)
- `.planning/ROADMAP.md` §"Phase 7: iOS Validation + Biometrics Capture" — 4 success criteria

### Código iOS relevante

- `ios/OpenWhoop/BLE/BLEManager.swift` — `willRestoreState`, Commands enum (adicionar TOGGLE_IMU_MODE)
- `ios/OpenWhoop/Tabs/TodayView.swift` — view a validar com dados reais (MetricsRepository binding)
- `ios/OpenWhoop/Tabs/SleepView.swift` — view a validar; nota SpO₂ HYPOTHESIS comment na linha existente
- `ios/OpenWhoop/Tabs/TrendsView.swift` — `MetricKind.dailyCases` (NÃO adicionar SpO₂/skinTemp aqui — deferido para Phase 9)
- `ios/OpenWhoop/Charts/MetricKind.swift` — `dailyCases` array; NOT to be modified in Phase 7

### RE e captura

- `re/re_harness.py` — harness existente; possível base para script TOGGLE_IMU_MODE
- `re/capture/evidence/` — directório de evidências de captura a actualizar após VERIFIED
- `re/capture/android-btsnoop.md`, `ios-packetlogger.md` — runbooks de captura existentes

### Maestro E2E tests

- `ios/maestro/` — 6 tests existentes (padrão a seguir para o novo 07_ios08_background_reconnect.yaml)
- `ios/maestro/utils/` — utilities partilhados entre tests

### Sync de schema

- `scripts/sync-schema.sh` — correr após actualizar whoop_protocol_5.json para sincronizar com Swift bundle resource

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `BLEManager.Commands` enum — adicionar caso `toggleImuMode` (ou equivalente) aqui; segue padrão dos comandos existentes com rawValue BLE payload
- `BLEManager.backfillTimeout` DispatchWorkItem pattern — referência para qualquer watchdog IMU mode
- `SpyBackfillStore` — padrão de mock para testes; não necessário para Phase 7 mas documenta a test infrastructure
- Maestro test files `01_today_hrv_detail.yaml`..`06_device_settings.yaml` — seguir mesmo padrão para `07_ios08_background_reconnect.yaml`
- `StubURLProtocol` — HTTP mocking para tests se necessário

### Established Patterns

- **MetricsRepository observation:** TodayView, SleepView observam `@EnvironmentObject var metrics: MetricsRepository` — os dados aparecem automaticamente quando o store tem dados; não é necessário mudar a lógica de binding se o backfill estiver a funcionar
- **Log level `.notice`:** Todos os eventos significativos de BLE usam `BLEManager.logger.notice("...")`. IMU mode logs devem seguir este padrão
- **Schema confidence field:** `protocol/whoop_protocol_5.json` usa `"confidence": "HYPOTHESIS"/"VERIFIED"` por campo — actualizar campo a campo quando stream é validado
- **`scripts/sync-schema.sh`:** Deve ser corrido após qualquer update ao whoop_protocol_5.json para sincronizar com o Swift bundle

### Integration Points

- `BLEManager.swift` → novo comando TOGGLE_IMU_MODE wired à Settings tab debug button
- `re/re_harness.py` ou novo script → envia TOGGLE_IMU_MODE via bleak; captura logs
- `re/capture/evidence/` → destino dos artefactos de verificação commitados
- `ios/maestro/` → novo test `07_ios08_background_reconnect.yaml` para IOS-08

</code_context>

<specifics>
## Specific Ideas

- **TOGGLE_IMU_MODE debug button:** Deve ser visível apenas em modo debug — considerar `#if DEBUG` wrapper ou uma secção "Developer" em Settings tab separada das opções normais
- **Captura termina por confirmação nos logs**, não por timer — o script deve mostrar as streams à medida que chegam e confirmar quando as 4 estão presentes
- **PacketLogger evidence:** Um excerpt filtrado (não o .pklg completo se for grande) é suficiente — os offsets e valores brutos de 10–20 frames por tipo de stream são evidência adequada

</specifics>

<deferred>
## Deferred Ideas

- **IOS-05 (SpO₂/skinTemp chart series no TrendsView)** — deferido para Phase 9 (SwiftUI Redesign WHOOP-Style). `MetricKind.dailyCases` NOT to be modified in Phase 7. Phase 9 vai redesenhar TrendsView e incluirá estes charts no design WHOOP-style correcto.

</deferred>

---

*Phase: 07-ios-validation-biometrics-capture*
*Context gathered: 2026-05-31*
