# Phase 5: iOS App & Server Port - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the entire 4.0 iOS app + FastAPI/TimescaleDB server to support WHOOP 5.0 end-to-end: update the Swift decoder package, wire 5.0 BLE UUIDs, migrate WhoopStore, and extend the server ingest endpoint. The result is a functional app on a physical iPhone — live HR, historical backfill (14+ days), offline mode, and optional server ingest — using 5.0 data throughout.

**Entry condition:** Phase 4 complete — `protocol/whoop_protocol_5.json` canonical schema finalised and synced to `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json`.

**Deliverables:**
1. `Packages/WhoopProtocol/` — `loadSchema()` loads 5.0 schema; `parseFrame()` strips Maverick wrapper internally; `extractStreams()` decodes all v1 biometric streams; Swift unit tests pass with 5.0 golden fixtures
2. `Packages/WhoopStore/` — Migration v8: `gravitySample` extended with nullable gyro columns; no other schema changes needed for clean 5.0 fork
3. `ios/OpenWhoop/` — BLEManager + Commands wired to 5.0 UUIDs; all views (Live, Today, Sleep, Trends) functional with 5.0 data; CoreBluetooth state preservation working
4. `server/` — `init.sql` updated with `device_generation`; `POST /v1/ingest-decoded` accepts 5.0 streams; `compute_day()` runs after ingest; read endpoints return 5.0 data
5. Kill-process store-then-ack test (PROTO-10 live test deferred from Phase 4) executed in Swift/CoreBluetooth on iPhone

**Out of scope:** Full WHOOP app clone / UX redesign (milestone v2), dual 4.0/5.0 support, raw IMU capture (if type-43 not triggered — PROTO-14 HYPOTHESIS stays as-is).

</domain>

<decisions>
## Implementation Decisions

### Swift Decoder (WhoopProtocol)
- **D-01:** **`loadSchema()` substitui em-place para carregar `whoop_protocol_5.json`.** O JSON 4.0 permanece nos Resources mas não é carregado. Zero mudanças na assinatura das funções — todos os call sites funcionam sem alteração. Alinhado com o clean fork (sem dual-support).
- **D-02:** **Maverick wrapper encapsulado internamente em `parseFrame()`.** A função detecta e strip o wrapper antes de processar o inner frame. Call sites (BLEManager) não mudam. Segue o padrão de `strip_maverick()` do Python (`re/survey_5/validate_frames_5.py`).
- **D-03:** **Golden fixtures para XCTest: adaptar `frames_5_golden.json` via `scripts/gen_golden.py`.** Produz `Packages/WhoopProtocolTests/Resources/frames_5.json` no mesmo formato do `frames.json` 4.0. Garante paridade Python↔Swift byte-a-byte (SWIFT-05/SWIFT-06).

### UUID & Commands Wiring (iOS BLE)
- **D-04:** **UUIDs 5.0 substituídos em-place nos Constants do BLEManager e Commands.swift.** `FD4B0001ubstitui `61080001-…`. Abordagem mais simples para clean fork; zero overhead de configuração.
- **D-05:** **Commands enum revisto contra os 10 VERIFIED da Fase 4.** Critério de inclusão: apenas comandos observados nas captures + os já existentes no enum. Comandos HYPOTHESIS do r52 ficam excluídos do enum por segurança. Comandos destrutivos (DFU, REBOOT, POWER_CYCLE, FORCE_TRIM) excluídos independentemente.

### WhoopStore Migration v8
- **D-06:** **`gravitySample` estendida com colunas giroscópio nullable.** Migration v8 adiciona `gx DOUBLE nullable, gy DOUBLE nullable, gz DOUBLE nullable` à tabela `gravitySample`. Ficam null até uma frame tipo 43 (REALTIME_RAW_DATA) ser capturada via TOGGLE_IMU_MODE na Fase 5. Evita uma migration v9 se tipo 43 for confirmado.
- **D-07:** **`device_generation` desnecessário no WhoopStore iOS.** Fork limpo exclusivamente 5.0 — todo o dado é 5.0 por definição. A coluna vai no servidor (SRV-04) mas não na app.
- **D-08:** **SpO₂ e skinTemp mantêm formato existente.** `spo2Sample(red, ir)` e `skinTempSample(raw)` — mesmo formato ADC raw do 4.0. A conversão (SpO₂%, °C) é feita no servidor pelo `units.py`, não na app.

### Server Migration (FastAPI + TimescaleDB)
- **D-09:** **`device_generation` adicionado ao `init.sql` diretamente.** `ALTER TABLE … ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0'` adicionado para cada hypertable relevante. Docker fresh-start usa o SQL actualizado; instâncias existentes migram idempotentemente no startup do ingest service.
- **D-10:** **`POST /v1/ingest-decoded` aceita `device_generation` como campo opcional.** Pydantic model: `device_generation: Optional[str] = '5.0'`. Clientes sem o campo continuam a funcionar; novo default garante classificação correcta para o iOS 5.0.

### Fase 5 Scope
- **D-11:** **Fase 5 = port funcional.** As vistas existentes (Live, Today, Sleep, Trends) são portadas para dados 5.0. Nenhum redesign UX nesta fase. O app funciona end-to-end com WHOOP 5.0 no mesmo visual da app 4.0.

### Claude's Discretion
- Estrutura exata das waves de planos (Swift decoder + tests → iOS BLE + Store → UI + offline → servidor)
- Como `gen_golden.py` é adaptado para produzir `frames_5.json` com campos 5.0
- Se `BackfillPolicy` precisa de ajustes para triggers 5.0 (presumivelmente o mesmo que 4.0)
- Formato exato dos gyro samples no `extractStreams()` quando tipo 43 não está disponível (omitir vs. zeros)
- Kill-process test: script de teste dedicado ou integrado num XCTest existente

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 4 Deliverables (Phase 5 entry point)
- `protocol/whoop_protocol_5.json` — canonical 5.0 schema; já sincronizado em `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json` via `scripts/sync-schema-5.sh`. **Fonte única de verdade para UUIDs GATT, enums, e packet specs.**
- `FINDINGS_5.md` — protocolo de referência; secção §Phase 4 cobre command surface, decoded streams, timestamps, historical offload. Ler antes de qualquer mudança ao BLEManager ou FrameRouter.
- `re/survey_5/frames_5_golden.json` — 123 golden fixtures curados (corpus completo Phase 4). Base para gerar `frames_5.json` para XCTest (D-03).
- `re/survey_5/decode_5.py` / `decode_biometrics_5.py` — decoders Python de referência; SWIFT-03/04 deve produzir output byte-a-byte idêntico.

### 4.0 Reference Implementation (base do port)
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` — loader de schema; `loadSchema()` a ser modificado para apontar para `whoop_protocol_5.json` (D-01).
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` — `parseFrame()` + `verifyFrame()`; adicionar `strip_maverick()` aqui ou num ficheiro separado (D-02).
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift` — `extractStreams()` + structs (`GravitySample`, `SpO2Sample`, etc.); `GravitySample` precisará de `gx, gy, gz` (D-06).
- `Packages/WhoopStore/Sources/WhoopStore/Database.swift` — 7 migrações v1-v7; adicionar v8 com gyro columns (D-06).
- `ios/OpenWhoop/BLE/BLEManager.swift` — CoreBluetooth orchestrator; UUIDs a substituir (D-04), estado preservation já implementado.
- `ios/OpenWhoop/BLE/Commands.swift` — `WhoopCommand` enum; rever contra VERIFIED da Fase 4 (D-05).
- `ios/OpenWhoop/App/OpenWhoopApp.swift` — entry point, `MetricsRepository` + `LiveViewModel` injection.
- `server/db/init.sql` — schema TimescaleDB; adicionar `device_generation` (D-09).
- `server/ingest/app/main.py` — FastAPI routes; `POST /v1/ingest-decoded` a actualizar (D-10).

### Maverick Wrapper Reference
- `re/survey_5/validate_frames_5.py` — `strip_maverick()` Python (pure `bytes → bytes`). A implementação Swift em `Framing.swift` deve produzir output idêntico (D-02).

### Testing Infrastructure
- `Packages/WhoopProtocolTests/Resources/frames.json` — 4.0 golden fixture format; `frames_5.json` mirrors this structure.
- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/` — Swift test targets; adicionar testes 5.0 aqui.
- `scripts/gen_golden.py` — gerador de golden fixtures Python→Swift; adaptar para `frames_5_golden.json` → `frames_5.json` (D-03).
- `ios/maestro/*.yaml` — Maestro E2E tests no dispositivo físico.

### Build System
- `ios/project.yml` — XcodeGen config; pode precisar de referência ao novo `frames_5.json` se não auto-incluído.
- `ios/Secrets.xcconfig` — `SERVER_BASE_URL`, `WHOOP_API_KEY`, `WHOOP_DEVICE_ID`; confirmar que `WHOOP_DEVICE_ID` está correcto para o 5.0.
- `server/docker-compose.yml` — `docker compose up -d --build` deve funcionar após update do `init.sql`.

### Phase 5 Requirements
- `.planning/ROADMAP.md` §"Phase 5: iOS App & Server Port" — 5 success criteria.
- `.planning/REQUIREMENTS.md` — SWIFT-01 a SWIFT-06, IOS-01 a IOS-09, SRV-01 a SRV-05.

### Legal
- `DISCLAIMER.md` — RE legal frame; aplicável a qualquer código que processe frames BLE.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` — `parseFrame()` existente; adicionar Maverick strip antes do SOF check (D-02). CRC8 poly 0x07 e CRC32-zlib já implementados — reutilizar.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift` — `extractStreams()` e todos os structs de streams; mudar apenas `GravitySample` para adicionar gyro (D-06).
- `ios/OpenWhoop/BLE/FrameRouter.swift` — router puro sem dependência de UUIDs; provavelmente zero mudanças.
- `ios/OpenWhoop/Collect/Backfiller.swift` — safe-trim invariant já implementado; kill-process test (D-11/PROTO-10) valida este comportamento.
- `ios/OpenWhoop/Metrics/MetricsRepository.swift` — facade sobre WhoopStore; provavelmente zero mudanças se os tipos de dados se mantêm.
- `server/ingest/app/analysis/units.py` — conversão ADC → SpO₂%, °C, breaths/min; já implementado para 4.0, deve funcionar com 5.0 raw ADC (mesma escala).

### Established Patterns
- **Schema-driven decode:** `loadSchema()` → `_cachedSchema` singleton → `parseFrame()` / `extractStreams()`. Substituir apenas o ficheiro JSON alvo (D-01) mantém todo o padrão inalterado.
- **Isolation em `re/survey_5/`:** scripts Python 5.0 ficam aqui. `gen_golden.py` adaptado para 5.0 segue o mesmo padrão.
- **Evidence policy:** redacted hex + SHA256 + YAML sidecar. Golden fixtures 5.0 para XCTest seguem o mesmo formato.
- **Migration pattern no WhoopStore:** `migrator.registerMigration("v8")` com `db.alter(table:)`. Padrão v5, v6, v7 já demonstra ADD COLUMN nullable.
- **Offline-first via AppConfig:** `AppConfig.uploaderConfig()` retorna nil → servidor ignorado. Não mudar este mecanismo.
- **CoreBluetooth state restoration:** `CBCentralManagerOptionRestoreIdentifierKey` + `willRestoreState` já implementados em BLEManager — não re-implementar, apenas validar que funcionam com 5.0 UUIDs.

### Integration Points
- `whoop_protocol_5.json` (já em Resources) → consumido por `Schema.swift` após D-01
- `gravitySample` com gyro columns (v8) → consumido por `StreamStore.swift` e `server/ingest/app/store.py`
- `frames_5.json` (novo) → consumido por `WhoopProtocolTests` para testes Swift
- `init.sql` atualizado → aplicado via `docker compose up -d --build`
- `POST /v1/ingest-decoded` com `device_generation` → chamado pelo `Uploader.swift` iOS

</code_context>

<specifics>
## Specific Ideas

- **Maverick strip antes do SOF check em `parseFrame()`:** A implementação mais limpa é verificar se os primeiros bytes correspondem à assinatura Maverick (`body[0] == 0x01` role byte) antes de tentar o SOF `0xAA`. Se Maverick detectado, `strip_maverick()` antes de prosseguir. Mesma lógica que `re/survey_5/validate_frames_5.py`.
- **Kill-process test (PROTO-10):** Abrir sessão histórica no iOS, forçar kill no meio de um ACK pendente, reconectar — verificar que nenhum dado foi perdido. Este é o único teste que requer interação manual no iPhone; documenta-se como passo de UAT no plano, não como XCTest automatizado.
- **WHOOP clone como milestone v2:** O utilizador quer eventualmente uma app com o visual completo da WHOOP oficial. Essa milestone começa após a Fase 5 validada — dados 5.0 corretos são a pré-condição. O escopo incluirá design system, vistas completas, onboarding.

</specifics>

<deferred>
## Deferred Ideas

- **WHOOP clone / redesign UX completo:** O utilizador quer uma app que seja visualmente equivalente à app oficial WHOOP. Esta é uma nova capability — milestone v2, após a Fase 5 estar validada. Não pertence ao port funcional da Fase 5.
- **Raw IMU tipo 43 (PROTO-14 HYPOTHESIS):** Se `TOGGLE_IMU_MODE` / `START_RAW_DATA` for triggado na Fase 5 e tipo 43 for observado, as colunas `gx, gy, gz` estarão prontas (D-06). O decoder IMU 6-axis está como template HYPOTHESIS no schema — se confirmado, promover a VERIFIED.
- **Dual 4.0/5.0 support:** Explicitamente fora de âmbito (PROJECT.md). Se necessário no futuro, é uma nova milestone.

</deferred>

---

*Phase: 05-ios-app-server-port*
*Context gathered: 2026-05-30*
