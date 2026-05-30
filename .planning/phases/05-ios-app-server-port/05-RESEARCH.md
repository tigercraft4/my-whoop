# Phase 5: iOS App & Server Port — Research

**Researched:** 2026-05-30
**Domain:** Swift CoreBluetooth / GRDB / FastAPI / TimescaleDB port — WHOOP 5.0
**Confidence:** HIGH (codebase fully read; all locked decisions from CONTEXT.md verified against code)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Swift Decoder (WhoopProtocol)**
- D-01: `loadSchema()` substitui em-place para carregar `whoop_protocol_5.json`. O JSON 4.0 permanece nos Resources mas não é carregado. Zero mudanças na assinatura das funções.
- D-02: Maverick wrapper encapsulado internamente em `parseFrame()`. A função detecta e strip o wrapper antes de processar o inner frame. Call sites (BLEManager) não mudam.
- D-03: Golden fixtures para XCTest: adaptar `frames_5_golden.json` via `scripts/gen_golden.py`. Produz `Packages/WhoopProtocolTests/Resources/frames_5.json` no mesmo formato do `frames.json` 4.0.

**UUID & Commands Wiring (iOS BLE)**
- D-04: UUIDs 5.0 substituídos em-place nos Constants do BLEManager e Commands.swift. `FD4B0001-…` substitui `61080001-…`.
- D-05: Commands enum revisto contra os 10 VERIFIED da Fase 4. Apenas comandos observados nas captures. Comandos HYPOTHESIS excluídos. Comandos destrutivos excluídos independentemente.

**WhoopStore Migration v8**
- D-06: `gravitySample` estendida com colunas giroscópio nullable. Migration v8 adiciona `gx DOUBLE nullable, gy DOUBLE nullable, gz DOUBLE nullable`.
- D-07: `device_generation` desnecessário no WhoopStore iOS (fork 5.0-only).
- D-08: SpO₂ e skinTemp mantêm formato existente. `spo2Sample(red, ir)` e `skinTempSample(raw)` — mesmo formato ADC raw do 4.0.

**Server Migration (FastAPI + TimescaleDB)**
- D-09: `device_generation` adicionado ao `init.sql` diretamente. `ALTER TABLE … ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0'` para cada hypertable relevante.
- D-10: `POST /v1/ingest-decoded` aceita `device_generation` como campo opcional. Pydantic model: `device_generation: Optional[str] = '5.0'`.

**Fase 5 Scope**
- D-11: Fase 5 = port funcional. As vistas existentes (Live, Today, Sleep, Trends) são portadas para dados 5.0. Nenhum redesign UX.

### Claude's Discretion
- Estrutura exata das waves de planos (Swift decoder + tests → iOS BLE + Store → UI + offline → servidor)
- Como `gen_golden.py` é adaptado para produzir `frames_5.json` com campos 5.0
- Se `BackfillPolicy` precisa de ajustes para triggers 5.0 (presumivelmente o mesmo que 4.0)
- Formato exato dos gyro samples no `extractStreams()` quando tipo 43 não está disponível (omitir vs. zeros)
- Kill-process test: script de teste dedicado ou integrado num XCTest existente

### Deferred Ideas (OUT OF SCOPE)
- WHOOP clone / redesign UX completo (milestone v2)
- Raw IMU tipo 43 (PROTO-14 HYPOTHESIS) — colunas gx/gy/gz ficam null até confirmação
- Dual 4.0/5.0 support
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SWIFT-01 | `Packages/WhoopProtocol/` forked/updated para suportar 5.0 schema (`whoop_protocol_5.json`) | D-01: loadSchema() aponta para `whoop_protocol_5.json`; apenas 1 linha muda em Schema.swift |
| SWIFT-02 | `parseFrame()` trata Maverick outer wrapper + 4.0 inner frame | D-02: strip interno antes do SOF check; corpo plano sem CRC interno |
| SWIFT-03 | `extractStreams()` decodes todos v1 biometric streams | Streams.swift já suporta HR/RR/events/battery; body offset move de frame-relative para body-absolute |
| SWIFT-04 | `extractHistoricalStreams()` decodes historical data backfill 5.0 | HistoricalStreams.swift já existe; offsets V24 são body-absolute no schema 5.0 |
| SWIFT-05 | Swift unit tests passam com 5.0 golden fixtures (paridade Python↔Swift byte-a-byte) | frames_5_golden.json (123 fixtures curados) + adaptar gen_golden.py para produzir frames_5.json |
| SWIFT-06 | Python `whoop_protocol` package actualizado para suportar 5.0 schema | server/packages/whoop-protocol/whoop_protocol/schema/ — adicionar whoop_protocol_5.json e adaptar schema.py |
| IOS-01 | App liga e faz bond ao WHOOP 5.0 via CoreBluetooth (iPhone físico) | D-04: substituir UUIDs em BLEManager; confirmed-write trick funciona em iOS |
| IOS-02 | Live view mostra HR, battery, BLE status em tempo real | LiveView/LiveViewModel inalterados; dados fluem via FrameRouter → LiveState |
| IOS-03 | Today view mostra recovery, HRV, sleep summary diário | TodayView usa MetricsRepository/WhoopStore — sem mudanças se tipos de dados se mantêm |
| IOS-04 | Sleep view mostra sessões de sono históricas | SleepView usa sleepSession table — inalterada |
| IOS-05 | Trends view mostra gráficos HR, HRV, SpO₂, skin temp ao longo do tempo | TrendsView usa as mesmas tabelas decoded streams — inalterada estruturalmente |
| IOS-06 | Historical backfill (14+ days) end-to-end com safe-trim invariant | Backfiller.swift inalterado; PROTO-10 kill-process test agora em dispositivo físico |
| IOS-07 | App funciona offline (`AppConfig.uploaderConfig()` retorna nil em valores placeholder) | Mecanismo já implementado — validar apenas que funciona com 5.0 UUIDs |
| IOS-08 | CoreBluetooth state preservation (`CBCentralManagerOptionRestoreIdentifierKey`) | Já implementado — validar que funciona com 5.0 UUIDs após substituição D-04 |
| IOS-09 | `WhoopStore` schema migrado para 5.0 data types (nova migration v8) | D-06: `migrator.registerMigration("v8")` com gyro columns nullable em gravitySample |
| SRV-01 | `POST /v1/ingest-decoded` aceita 5.0 decoded streams com campo `device_generation` | D-10: adicionar `device_generation: Optional[str] = '5.0'` ao `DecodedBatch` Pydantic model |
| SRV-02 | Daily analysis pipeline (`compute_day()`) corre após cada ingest 5.0 | Já acontece automaticamente — sem mudanças à lógica |
| SRV-03 | `GET /v1/daily-metrics`, `/v1/sleep-sessions`, `/v1/workouts` retornam dados 5.0 | Read endpoints inalterados — servem de `daily_metrics`/`sleep_sessions`/`exercise_sessions` |
| SRV-04 | TimescaleDB schema migration adiciona `device_generation` às hypertables | D-09: `ALTER TABLE … ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0'` em init.sql |
| SRV-05 | Server corre via `docker compose up -d --build` | Sem mudanças ao Dockerfile/docker-compose; init.sql actualizado é re-aplicado idempotentemente |
</phase_requirements>

---

## Summary

Esta fase é um **port cirúrgico**, não uma reescrita. Os ficheiros-alvo são exactamente identificados, as mudanças são aditivas ou substituições em-place, e o padrão de todas as outras fases prova que a arquitectura se mantém intacta com dados 5.0.

**Camada Swift decoder (WhoopProtocol):** Três mudanças pontuais — (1) `loadSchema()` em `Schema.swift` aponta para `whoop_protocol_5.json` (uma string alterada), (2) `parseFrame()` em `Interpreter.swift` recebe um `stripMaverick()` interno antes do SOF check existente, (3) `GravitySample` em `Streams.swift` ganha três campos nullable (`gx`, `gy`, `gz`) para giroscópio. O pipeline schema-driven (`loadSchema() → _cachedSchema → parseFrame() → extractStreams()`) mantém-se inalterado; só o ficheiro JSON alvo e os offsets body-absolute mudam.

**Camada iOS BLE:** Dois ficheiros mudam — (1) `BLEManager.swift` substitui os seis `61080001-…` UUIDs por `FD4B0001-…` (e o string "WHOOP 4.0" por "WHOOP 5.0"), (2) `Commands.swift` revê o enum contra os 10 VERIFIED da Fase 4. O fluxo de bonding, state restoration, backfill, upload, e offline ficam intactos. As views (Live, Today, Sleep, Trends) não requerem mudanças — consomem tipos de dados que se mantêm idênticos.

**Camada servidor:** Duas mudanças — (1) `init.sql` adiciona `ALTER TABLE … ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0'` a cada hypertable, (2) `main.py` adiciona o campo `device_generation` ao `DecodedBatch` Pydantic model. `compute_day()` já funciona sobre dados 5.0 raw (SpO₂/skin temp/resp mantêm formato ADC raw).

**Primary recommendation:** Sequenciar em quatro waves paralelas onde possível: (W1) Swift decoder + gen_golden.py + XCTest → (W2) iOS BLE UUIDs + WhoopStore v8 em paralelo com W1 → (W3) validação end-to-end no iPhone físico + kill-process test → (W4) servidor. W4 pode avançar em paralelo com W2/W3.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Maverick strip (D-02) | Swift Decoder (WhoopProtocol) | — | parseFrame() é o único ponto de entrada; strip interno mantém call sites limpos |
| Schema loading (D-01) | Swift Decoder (WhoopProtocol) | Python whoop_protocol | Schema.swift e schema.py são loaders em camadas distintas que partilham o mesmo JSON |
| GATT bonding / UUID wiring (D-04) | iOS BLE (BLEManager) | — | CoreBluetooth é a única camada que precisa de conhecer UUIDs físicos |
| Command surface (D-05) | iOS BLE (Commands.swift) | — | WhoopCommand enum é o único ponto de envio de comandos ao strap |
| Decoded stream persistence | WhoopStore (GRDB SQLite) | — | Collector/Backfiller escrevem; MetricsRepository lê — nenhum conhece o servidor |
| gravitySample gyro columns (D-06) | WhoopStore migration v8 | Server gravity_samples (sem mudança) | Colunas nullable — null até tipo 43 ser capturado |
| SpO₂/skinTemp raw ADC (D-08) | WhoopStore + Server | units.py (conversão) | Persistência(D-09/D-10) | Server (TimescaleDB + FastAPI) | — | iOS é 5.0-only por design (D-07); só o servidor precisa distinguir gerações |
| compute_day() após ingest | Server (FastAPI route) | — | Throttle + lock já implementados; sem mudanças à lógica |
| Offline mode (IOS-07) | iOS (AppConfig) | — | `uploaderConfig()` retorna nil em placeholders — mecanismo já existente |
| State restoration BLE (IOS-08) | iOS (BLEManager) | — | `CBCentralManagerOptionRestoreIdentifierKey` já configurado; só UUIDs mudam |
| Golden fixtures paridade Python↔Swift (D-03) | gen_golden.py / XCTest | — | gen_synthetic_fixtures.py gera frames 4.0; adaptar para 5.0 Maverick-wrapped |

---

## Standard Stack

Esta fase não instala dependências novas. Toda a stack já está no repo.

### Core (já presente)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GRDB.swift | existente | SQLite ORM para WhoopStore migrations | Padrão do repo — `migrator.registerMigration("v8")` |
| CoreBluetooth | sistema iOS | BLE — bonding, notificações, state restoration | Único framework para BLE em iOS |
| FastAPI | existente | Ingest server + read API | Padrão do repo |
| psycopg | existente | PostgreSQL driver para TimescaleDB | Padrão do repo |
| Pydantic | existente | Validation dos modelos de ingest | `DecodedBatch` já usa `BaseModel` |
| XCTest | sistema Xcode | Swift unit tests | Padrão Apple |

### Sem novas dependências

Nenhum package novo. A fase é uma substituição em-place de constantes, adição de colunas nullable, e adaptação de gen_golden.py que já existe.

**Package Legitimacy Audit:** Não aplicável — zero packages novos instalados nesta fase.

---

## Architecture Patterns

### System Architecture Diagram

```
iPhone (CoreBluetooth)
    │
    ├─ BLEManager.swift ──[FD4B0001-... UUIDs]──► WHOOP 5.0 strap
    │      │
    │      │ Maverick-wrapped ATT notifications
    │      ▼
    │  parseFrame() ──[strip_maverick()]──► flat body ──► schema fields
    │      │                                               (body-absolute offsets)
    │      ▼
    │  Collector / Backfiller
    │      │
    │      ▼
    │  WhoopStore (GRDB SQLite)
    │  ├─ hrSample, rrInterval, events, battery
    │  ├─ spo2Sample, skinTempSample, respSample
    │  └─ gravitySample [+ gx/gy/gz nullable v8]
    │      │
    │      ▼
    │  MetricsRepository ──► Views (Live/Today/Sleep/Trends)
    │      │
    │      └─[optional]──► Uploader ──► POST /v1/ingest-decoded
    │                                        │ device_generation='5.0'
    │                                        ▼
    │                              FastAPI + TimescaleDB
    │                              ├─ store.upsert_streams()
    │                              ├─ compute_day() [throttled]
    │                              └─ GET /v1/daily|sleep|workouts
    │
    └─[parallel]── XCTest (WhoopProtocolTests)
           ├─ frames_5.json  [gen_golden.py → frames_5_golden.json]
           └─ ParityTests / StreamsTests / BiometricStreamsParityTests
```

### Recommended Project Structure (ficheiros afectados)

```
Packages/WhoopProtocol/Sources/WhoopProtocol/
├── Schema.swift                  # loadSchema() → "whoop_protocol_5.json" (D-01)
├── Framing.swift                 # + stripMaverick() interno (D-02)
├── Interpreter.swift             # parseFrame() chama strip antes do SOF check (D-02)
└── Streams.swift                 # GravitySample + gx/gy/gz? nullable (D-06)

Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/
└── whoop_protocol_5.json         # já presente (sync-schema-5.sh); loadSchema() aponta aqui

Packages/WhoopProtocolTests/Resources/
└── frames_5.json                 # NOVO — gerado por gen_golden.py adaptado (D-03)

Packages/WhoopStore/Sources/WhoopStore/
└── Database.swift                # + migrator.registerMigration("v8") (D-06)

ios/OpenWhoop/BLE/
├── BLEManager.swift              # 6 UUID strings 61080001→FD4B0001 + "WHOOP 5.0" (D-04)
└── Commands.swift                # rever enum vs 10 VERIFIED; comentário do char UUID (D-05)

server/db/
└── init.sql                      # ALTER TABLE ADD COLUMN IF NOT EXISTS device_generation (D-09)

server/ingest/app/
└── main.py                       # DecodedBatch + device_generation field (D-10)

server/packages/whoop-protocol/whoop_protocol/schema/
└── whoop_protocol_5.json         # NOVO — copiar de protocol/ (SWIFT-06)

scripts/
└── gen_golden.py                 # adaptar para 5.0 Maverick-wrapped frames (D-03)
```

### Pattern 1: Maverick strip em parseFrame() (D-02)

**O que é:** O WHOOP 5.0 envolve cada ATT value num wrapper Maverick de 8 bytes de overhead: `[0xAA][0x01][len u16-LE][body (length bytes)][trailer 4B]`. O corpo é PLANO — não é um frame 4.0 aninhado. `strip_maverick()` devolve `frame[4:4+length]`.

**Quando usar:** Dentro de `parseFrame()`, antes da verificação SOF existente. A detecção é: `frame.count >= 9 && frame[0] == 0xAA && frame[1] == 0x01 && frame.count == Int(u16le(frame, 2)) + 8`.

```swift
// Source: re/survey_5/validate_frames_5.py strip_maverick() + FINDINGS_5.md §7
// Adicionar em Framing.swift — puro, sem dependências externas
func stripMaverick(_ frame: [UInt8]) -> [UInt8]? {
    guard frame.count >= 9,
          frame[0] == 0xAA,
          frame[1] == 0x01 else { return nil }
    let length = Int(frame[2]) | (Int(frame[3]) << 8)   // u16-LE at offset 2-3
    guard frame.count == length + 8 else { return nil }
    return Array(frame[4..<4 + length])  // flat body: role byte + token + ptype + seq + cmd + payload
}

// Em parseFrame() (Interpreter.swift), adicionar ANTES do check existente:
public func parseFrame(_ rawFrame: [UInt8]) -> ParsedFrame {
    // D-02: strip Maverick wrapper se detectado; o inner body é o novo frame de trabalho
    let frame: [UInt8]
    if let body = stripMaverick(rawFrame) {
        frame = body   // flat body; body[4] = ptype, body[5] = seq, body[6] = cmd
    } else {
        frame = rawFrame  // 4.0-format ou já stripped (golden fixtures são bodies não-wrapped)
    }
    // ... lógica parseFrame existente usa `frame` normalmente ...
}
```

**NOTA CRÍTICA sobre offsets:** O corpo stripped tem os campos em offsets **body-absolute**: `body[4]=ptype`, `body[5]=seq`, `body[6]=cmd`, `body[7:]=payload`. O `parseFrame()` existente lê `frame[4]=type`, `frame[5]=seq` — os offsets coincidem. Os `PacketSpec.fields[].off` no `whoop_protocol_5.json` são já body-absolute. Não há colisão de offsets.

**NOTA sobre Commands.swift:** Os 10 comandos VERIFIED foram observados como Maverick-wrapped na captura (o app oficial envia Maverick-wrapped). Contudo, a função `WhoopCommand.frame()` em Commands.swift produz 4.0-format (CRC8+CRC32). O strap ACEITA comandos 4.0-format? Esta é a única incógnita genuína de interoperabilidade — ver Open Questions #1. O mais seguro é testar no iPhone antes de adoptar Maverick-wrapping para writes.

### Pattern 2: loadSchema() aponta para 5.0 (D-01)

```swift
// Source: Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift linha 178
// ANTES:
guard let url = Bundle.module.url(forResource: "whoop_protocol", withExtension: "json") else {
// DEPOIS (D-01):
guard let url = Bundle.module.url(forResource: "whoop_protocol_5", withExtension: "json") else {
```

`whoop_protocol_5.json` já está em `Resources/` (sincronizado por `sync-schema-5.sh`). Zero outras mudanças. `_cachedSchema` garante que só carrega uma vez. `WhoopProtocolInfo.schemaResourceURL()` retorna o URL certo se também actualizado (mas só é usado nos testes de sync — ver SchemaSyncTests.swift).

**SchemaSyncTests.swift precisa de actualização:** o teste `testBundledSchemaMatchesCanonical()` e `testBundleModuleSchemaAlsoMatchesCanonical()` comparam contra `protocol/whoop_protocol.json` (4.0). Após D-01 devem comparar contra `protocol/whoop_protocol_5.json`. Actualizar as duas referências de path e o `schemaResourceURL()` em WhoopProtocol.swift.

### Pattern 3: Migration v8 — colunas gyro nullable (D-06)

```swift
// Source: Packages/WhoopStore/Sources/WhoopStore/Database.swift — padrão v5/v6/v7
migrator.registerMigration("v8") { db in
    // Gyroscope columns for gravitySample. Nullable: null until REALTIME_RAW_DATA type-43
    // (TOGGLE_IMU_MODE) is captured. PROTO-14 HYPOTHESIS — colunas prontas quando confirmado.
    try db.alter(table: "gravitySample") { t in
        t.add(column: "gx", .double)   // nullable — sem .notNull()
        t.add(column: "gy", .double)
        t.add(column: "gz", .double)
    }
}
```

`GravitySample` em Streams.swift ganha os três campos opcionais:

```swift
// Source: Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift
public struct GravitySample: Equatable, Codable {
    public let ts: Int
    public let x: Double
    public let y: Double
    public let z: Double
    public let gx: Double?   // NOVO — gyroscópio; nil até tipo 43 confirmado
    public let gy: Double?
    public let gz: Double?
    public let unit: String
    // ...
}
```

### Pattern 4: gen_golden.py para 5.0 (D-03)

O `gen_synthetic_fixtures.py` produz frames 4.0-format (CRC8+CRC32 envelope). Para 5.0, o gerador precisa de produzir frames **Maverick-wrapped**. Contudo, há uma subtileza: `parseFrame()` após D-02 faz strip interno — portanto os golden fixtures para XCTest podem ser QUALQUER dos dois formatos (wrapped ou stripped), desde que o Python decoder produza o mesmo output que o Swift decoder sobre os mesmos bytes.

**Opção A (mais simples):** Gerar frames 5.0 Maverick-wrapped. `parseFrame()` faz strip antes de processar. O ficheiro `frames_5.json` contém frames wrapped. Requer um `build_maverick_frame()` no gerador.

**Opção B (zero risco de wrapper-format):** Gerar frames com o body 5.0 (body-absolute offsets) mas embalados em 4.0-format envelope (sem Maverick). `parseFrame()` detecta ausência de wrapper (frame[1]!=0x01) e processa directamente. Os offsets body-absolute ainda funcionam? Não — o frame 4.0 tem `frame[4]=type`, mas o body 5.0 tem `body[4]=type` (onde body = frame[4:]). Os offsets coincidem numericamente quando lidos directamente do frame 4.0. Esta opção é tecnicamente possível mas confusa.

**Recomendação (Claude's Discretion):** Usar Opção A. Gerar frames Maverick-wrapped reais. O Python whoop_protocol package (SWIFT-06) também precisa de suportar Maverick-wrapped parse. A função `gen_golden_5.py` (novo script ou extensão de gen_golden.py) chama `build_maverick_frame()` + `parse_frame_5()` e escreve `frames_5.json` no mesmo formato `[{"hex": "..."}]`.

### Anti-Patterns a Evitar

- **Não adicionar dual-UUID branch:** A legacy `61080001-…` service está AUSENTE neste dispositivo (FINDINGS_5.md §2). Substituição em-place é correcta.
- **Não re-executar o 4.0 CRC gate no body stripped:** O corpo Maverick é PLANO, sem inner CRC32. `verifyFrame()` existente não deve ser chamado sobre o body stripped.
- **Não usar offset 1 para ptype no 5.0 body:** O body 5.0 tem `body[0]=role`, `body[1:4]=token`, `body[4]=ptype`. Não confundir com o 4.0 onde `frame[4]=type`.
- **Não alterar o mecanismo de bonding:** A confirmed-write trick funciona em iOS (FINDINGS_5.md §3) — o macOS não funciona, mas o iOS sim. Manter exactamente o mesmo código.
- **Não modificar BackfillPolicy:** O mesmo algoritmo de rate-limiting funciona para 5.0 (o trigger é temporal, não depende do protocolo).
- **Não persistir `device_generation` no WhoopStore iOS** (D-07): o fork é 5.0-only, seria redundante.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQLite schema migration | Migration manual SQL | GRDB `migrator.registerMigration("v8")` | Padrão já demonstrado em v5/v6/v7 em Database.swift |
| Frame CRC validation | CRC re-implementado | `crc8()` / `crc32()` já em Framing.swift | Já portado verbatim de framing.py; testado |
| BLE fragment reassembly | Reassembler custom | `Reassembler` já em Framing.swift | Já implementado e testado em ReassemblerTests.swift |
| Device epoch → wall clock | Conversão ad-hoc | `toWall()` já em Streams.swift | Idêntico à implementação Python `_to_wall()` |
| Maverick strip (Python) | strip ad-hoc | `strip_maverick()` em validate_frames_5.py | Já testado em 5028/5028 frames; importar directamente |
| TimescaleDB hypertable creation | DDL manual | `init.sql` com `CREATE TABLE IF NOT EXISTS` + `SELECT create_hypertable(if_not_exists)` | Padrão idempotente já estabelecido |
| Server auth | Auth custom | `require_auth` via Bearer header em main.py | Já implementado e testado |
| Offline mode | Lógica custom | `AppConfig.uploaderConfig()` retorna nil | Já implementado — não tocar |

**Key insight:** Todos os problemas difíceis desta fase já foram resolvidos na implementação 4.0. O risco é substituir incorrectamente (offsets errados, UUID errado) não re-implementar do zero.

---

## Runtime State Inventory

Esta fase é um port (não rename/refactor de strings arbitrárias), portanto a maioria das categorias não se aplica. Mas há estado runtime relevante:

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | WhoopStore SQLite (em ~/Library/Application Support/ no iPhone) — tabela `gravitySample` sem colunas gx/gy/gz | Migration v8 via GRDB — automático no próximo launch |
| Stored data | TimescaleDB `hr_samples`, `rr_intervals`, `events`, `battery`, `spo2_samples`, `skin_temp_samples`, `resp_samples`, `gravity_samples` — sem coluna `device_generation` | `ALTER TABLE ADD COLUMN IF NOT EXISTS` em init.sql — idempotente no startup |
| Live service config | Docker compose — `docker compose up -d --build` re-aplica init.sql | Nenhuma acção manual; SRV-05 |
| OS-registered state | `CBCentralManagerOptionRestoreIdentifierKey: "com.openwhoop.ble.central"` — o iOS tem este identifier registado com os UUIDs 4.0 actuais | Após substituição UUID, o iOS vai re-scan para o novo serviço FD4B0001; state restoration funciona com o mesmo restore ID |
| Secrets/env vars | `Secrets.xcconfig`: `SERVER_BASE_URL`, `WHOOP_API_KEY`, `WHOOP_DEVICE_ID` — não há referência a UUIDs BLE aqui | Nenhuma mudança necessária; `WHOOP_DEVICE_ID` continua "my-whoop" (D-07 confirma) |
| Build artifacts | `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json` — fixtures 4.0 existentes | NÃO remover; adicionar `frames_5.json` ao lado. Os testes 4.0 continuam a passar (schema 4.0 ainda em Resources) — mas loadSchema() já aponta para 5.0, por isso os testes 4.0 falharão se usarem o decoder. Ver Open Questions #2. |

**Nota sobre CBCentralManager restore:** O restore identifier `"com.openwhoop.ble.central"` não codifica os UUIDs — o iOS associa a identifier ao processo e aos peripherals bonded. Após substituição dos UUIDs em BLEManager, o app vai procurar o serviço `FD4B0001-…` em vez de `61080001-…`. Se o iPhone já tinha um bond com o WHOOP 5.0 via app anterior, esse bond persiste. Se era via 4.0 strap, precisa de novo bond com 5.0.

---

## Common Pitfalls

### Pitfall 1: Offset confusion body-absolute vs frame-absolute
**O que falha:** Usar offsets 4.0 frame-relative (e.g. `frame[6]` = cmd) sobre o body Maverick stripped (`body[6]` = cmd também, mas `body[4]` = ptype, não `frame[4]`). Em 4.0, `frame[4]` = type; no body 5.0 stripped, `body[4]` = type também — os primeiros offsets coincidem. MAS `frame[0]` seria 0xAA em 4.0, enquanto `body[0]` = role (0x00 ou 0x01) em 5.0. O parseFrame() existente verifica `frame[0] == 0xAA` — após strip, o body começa no role byte, não 0xAA.
**Por que acontece:** O Interpreter.swift existente assume que `frame[0]=0xAA`, `frame[4]=type`, `frame[5]=seq`. O corpo stripped tem `body[0]=role`, `body[4]=type`, `body[5]=seq`. Os offsets 4..N coincidem, mas o offset 0 e 1-3 são diferentes.
**Como evitar:** A implementação mais limpa: após strip, o "frame de trabalho" para o `parseFrame()` é o body completo. Mas o parseFrame() existente faz `frame[0] != 0xAA → return INVALID`. Portanto D-02 deve ou (a) fazer strip e remapear o body para que o parseFrame() trate como frame 4.0 sintético, ou (b) bifurcar o path internamente. Opção correcta: o body stripped é passado ao path schema-driven directamente, saltando o SOF check — o type está em `body[4]`.
**Warning signs:** Frames parsed como INVALID quando frame[0] = 0xAA mas frame[1] = 0x01 (Maverick version byte em vez de comprimento low byte).

### Pitfall 2: SchemaSyncTests falham após D-01
**O que falha:** `SchemaSyncTests.testBundledSchemaMatchesCanonical()` compara `protocol/whoop_protocol.json` (4.0) com o bundled. Após D-01, o bundled aponta para `whoop_protocol_5.json` mas o teste ainda compara com o 4.0.
**Por que acontece:** O teste foi escrito para 4.0 e não foi actualizado.
**Como evitar:** Actualizar ambos os testes em `SchemaSyncTests.swift` para comparar contra `protocol/whoop_protocol_5.json`. E actualizar `WhoopProtocolInfo.schemaResourceURL()` em `WhoopProtocol.swift` para apontar ao resource name correcto (`"whoop_protocol_5"`).

### Pitfall 3: ParityTests falham porque golden fixtures são 4.0-format
**O que falha:** `ParityTests.testSwiftMatchesPythonGolden()` carrega `frames.json` (4.0 synthetic frames) e o Swift decoder agora faz strip Maverick. Frames 4.0 não têm frame[1]=0x01, portanto `stripMaverick()` retorna nil e o frame é tratado normalmente. Mas os offsets no schema 5.0 são body-absolute (não frame-absolute). Resultado: os campos são lidos nos offsets errados.
**Por que acontece:** Os frames `frames.json` existentes são 4.0-format; o schema 5.0 tem offsets diferentes.
**Como evitar:** Os testes de paridade 5.0 devem usar `frames_5.json` (novo ficheiro gerado pelo gen_golden.py adaptado). Os testes existentes que usam `frames.json` + `golden.json` podem ser mantidos para verificar backward compat, OU renomeados como testes 4.0. Adicionar testes 5.0 separados (`Parity5Tests.swift` ou similar) que carregam `frames_5.json` + `golden_5.json`.

### Pitfall 4: Commands.swift envia frames 4.0-format para um strap que espera Maverick-wrapped
**O que falha:** Se o WHOOP 5.0 rejeitar comandos em formato 4.0 (o app oficial envia Maverick-wrapped nas 155 cmd-in frames capturadas), os comandos SEND_HISTORICAL_DATA, SET_CLOCK, etc. nunca são reconhecidos. A app liga mas não faz nada.
**Por que acontece:** O corpus Phase 4 mostra 155 cmd-in writes todos Maverick-wrapped (role=0x00 no body[0]). Mas não há evidência directa de que o strap *rejeita* 4.0-format. O token de 3 bytes (body[1:4] = HYPOTHESIS) pode ser necessário para o strap autenticar o write.
**Como evitar:** Testar no iPhone o mais cedo possível (Wave 1 inclui verificação end-to-end da bonding). Se os comandos 4.0-format forem rejeitados, upgradar `WhoopCommand.frame()` para produzir Maverick-wrapped writes com token=`[0x00,0x00,0x00]` (placeholder).
**Warning signs:** App liga e faz bond (BLE level OK) mas não recebe resposta a SEND_HISTORICAL_DATA ou GET_DATA_RANGE após a sequência de handshake.

### Pitfall 5: WhoopStore migration v8 não é registada antes de abertura de DB
**O que falha:** `WhoopStore(path:)` abre o DB e corre o migrator. Se v8 não estiver registada antes da abertura, a DB existente no iPhone não tem as colunas gx/gy/gz e os inserts de GravitySample falham.
**Por que acontece:** O migrator deve ter v8 registada no `makeMigrator()` antes de qualquer `try migrator.migrate(db)`.
**Como evitar:** Registar v8 em `Database.swift` (o único lugar onde o migrator é construído). Verificar que a ordem v1..v8 está correcta e que v8 usa `.double` sem `.notNull()`.

### Pitfall 6: gen_golden.py (5.0 variant) usa Python whoop_protocol package que ainda carrega schema 4.0
**O que falha:** `gen_golden.py` delega a `gen_synthetic_fixtures.py` que faz `from whoop_protocol.interpreter import parse_frame`. O package Python ainda tem `whoop_protocol.json` 4.0 na pasta `schema/`. Se não for actualizado (SWIFT-06), o `parse_frame` Python produz output baseado em offsets 4.0, enquanto o Swift decoder usa offsets 5.0 — paridade quebra.
**Por que acontece:** SWIFT-06 exige actualização do Python package para carregar `whoop_protocol_5.json`.
**Como evitar:** Adicionar `whoop_protocol_5.json` à pasta `server/packages/whoop-protocol/whoop_protocol/schema/` e actualizar `schema.py` para ter uma função `load_schema_5()` ou um parâmetro de versão. O `gen_golden.py` 5.0 variant usa explicitamente o schema 5.0.

---

## Code Examples

### Exemplo 1: stripMaverick() em Swift

```swift
// Source: re/survey_5/validate_frames_5.py strip_maverick() — port Swift
// Adicionar em Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift
/// Strip the 4-byte Maverick header + 4-byte trailer, returning the flat body.
/// Returns nil if the frame is not a valid Maverick wrapper.
/// Maverick layout: [0xAA][0x01][len u16-LE][body (length bytes)][trailer 4B]
/// total_len == length + 8 for all 5028/5028 captured frames (VERIFIED).
public func stripMaverick(_ frame: [UInt8]) -> [UInt8]? {
    guard frame.count >= 9,
          frame[0] == 0xAA,
          frame[1] == 0x01 else { return nil }
    let length = Int(frame[2]) | (Int(frame[3]) << 8)
    guard frame.count == length + 8 else { return nil }
    return Array(frame[4..<4 + length])
}
```

### Exemplo 2: Detecção Maverick em parseFrame()

```swift
// Source: CONTEXT.md D-02 + FINDINGS_5.md §7 body layout
// Em Packages/WhoopProtocol/Sources/WhoopProtocol/Interpreter.swift
public func parseFrame(_ rawFrame: [UInt8]) -> ParsedFrame {
    // D-02: strip Maverick wrapper if detected.
    // After strip: body[0]=role, body[1:4]=token, body[4]=ptype, body[5]=seq, body[6]=cmd
    // body[4] == frame[4] in the 4.0 layout, so the schema field offsets remain valid.
    let isMaverick = rawFrame.count >= 9 && rawFrame[0] == 0xAA && rawFrame[1] == 0x01
                     && rawFrame.count == (Int(rawFrame[2]) | (Int(rawFrame[3]) << 8)) + 8
    let frame: [UInt8]
    if isMaverick, let body = stripMaverick(rawFrame) {
        frame = body
    } else {
        frame = rawFrame
    }
    let rawHex = rawFrame.map { String(format: "%02x", $0) }.joined()
    // NOTA: após strip, frame[0]=role (não 0xAA). O check abaixo muda:
    if frame.count < 5 {  // mínimo: role + token(3) + ptype
        return ParsedFrame(ok: false, typeName: "INVALID/FRAGMENT", ...)
    }
    // ptype em body[4], seq em body[5]
    let t = Int(frame[4])
    let seq = frame.count > 5 ? Int(frame[5]) : 0
    // ... resto da lógica schema-driven inalterada, usando offsets body-absolute ...
}
```

### Exemplo 3: BLEManager UUID substitution (D-04)

```swift
// Source: ios/OpenWhoop/BLE/BLEManager.swift — substituição em-place
// ANTES:
static let customService   = CBUUID(string: "61080001-8d6d-82b8-614a-1c8cb0f8dcc6")
static let cmdWriteChar    = CBUUID(string: "61080002-8d6d-82b8-614a-1c8cb0f8dcc6")
static let cmdNotifyChar   = CBUUID(string: "61080003-8d6d-82b8-614a-1c8cb0f8dcc6")
static let eventNotifyChar = CBUUID(string: "61080004-8d6d-82b8-614a-1c8cb0f8dcc6")
static let dataNotifyChar  = CBUUID(string: "61080005-8d6d-82b8-614a-1c8cb0f8dcc6")

// DEPOIS (D-04, FINDINGS_5.md §1 — VERIFIED):
static let customService   = CBUUID(string: "FD4B0001-CCE1-4033-93CE-002D5875F58A")
static let cmdWriteChar    = CBUUID(string: "FD4B0002-CCE1-4033-93CE-002D5875F58A")
static let cmdNotifyChar   = CBUUID(string: "FD4B0003-CCE1-4033-93CE-002D5875F58A")
static let eventNotifyChar = CBUUID(string: "FD4B0004-CCE1-4033-93CE-002D5875F58A")
static let dataNotifyChar  = CBUUID(string: "FD4B0005-CCE1-4033-93CE-002D5875F58A")
// heartRateService/heartRateChar/batteryService/batteryChar: INALTERADOS (UUIDs standard)
```

### Exemplo 4: DecodedBatch com device_generation (D-10)

```python
# Source: server/ingest/app/main.py — adicionar campo ao DecodedBatch
# ANTES:
class DecodedBatch(BaseModel):
    device: DecodedDevice
    streams: DecodedStreams

# DEPOIS (D-10):
class DecodedBatch(BaseModel):
    device: DecodedDevice
    streams: DecodedStreams
    device_generation: str | None = "5.0"  # Optional; default='5.0' para iOS 5.0 fork
```

### Exemplo 5: init.sql — device_generation (D-09)

```sql
-- Source: server/db/init.sql — padrão ALTER TABLE IF NOT EXISTS já usado para charging, sleep_start, etc.
-- Adicionar APÓS as CREATE TABLE existentes para cada hypertable relevante:
ALTER TABLE hr_samples        ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
ALTER TABLE rr_intervals      ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
ALTER TABLE events            ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
ALTER TABLE battery           ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
ALTER TABLE spo2_samples      ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
ALTER TABLE skin_temp_samples ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
ALTER TABLE resp_samples      ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
ALTER TABLE gravity_samples   ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UUIDs `61080001-…` (WHOOP 4.0) | UUIDs `FD4B0001-CCE1-…` (WHOOP 5.0) | Phase 4 (VERIFIED 2026-05-30) | Substituição obrigatória; legacy absent neste device |
| 4.0 inner frame (CRC8+CRC32) | Maverick outer wrapper (flat body, sem inner CRC) | Phase 3 (VERIFIED 2026-05-30) | Body offset-4 em vez de offset-1; sem inner CRC gate |
| Offsets frame-absolute (4.0 schema) | Offsets body-absolute (5.0 schema) | Phase 4 | `body[4]=ptype` vs `frame[4]=ptype` — numericamente iguais mas conceptualmente diferentes |
| gravitySample sem gyro | gravitySample + gx/gy/gz nullable (v8) | Fase 5 (esta fase) | Null até PROTO-14 confirmado; colunas prontas |
| POST /v1/ingest-decoded sem device_generation | POST com `device_generation='5.0'` opcional | Fase 5 (esta fase) | Backward compat: clientes sem campo continuam a funcionar |

**Deprecated/outdated:**
- `schema_resources: "whoop_protocol"` em loadSchema(): substituído por `"whoop_protocol_5"`.
- Comentário "GATT UUIDs (authoritative, from FINDINGS.md)" em BLEManager.swift: actualizar para FINDINGS_5.md.
- String `"WHOOP 4.0"` no `upsertDevice()` em bootstrapStore(): actualizar para `"WHOOP 5.0"`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | O WHOOP 5.0 aceita comandos em formato 4.0 (CRC8+CRC32 envelope) sem Maverick wrapping | Pitfall 4 / Open Questions #1 | Comandos ignorados pelo strap; backfill nunca inicia; app parece ligar mas não sincroniza |
| A2 | Os offsets body-absolute do `whoop_protocol_5.json` em `frame[4]`=ptype coincidem com o path do parseFrame() existente após strip Maverick | Pattern 1 / Pitfall 1 | Campos lidos em posições erradas; HR=0, eventos incorrectos |
| A3 | SchemaSyncTests.swift deve ser actualizado para comparar contra `whoop_protocol_5.json` (e não apenas silenciado) | Pitfall 2 | Tests passam mas não validam o schema correcto |
| A4 | `BackfillPolicy` e todos os triggers de backfill são agnósticos ao protocolo (temporais) e funcionam sem mudanças para 5.0 | Architecture | Backfill periódico não dispara; dados históricos não chegam |
| A5 | O token de 3 bytes em `body[1:4]` é gerado pelo strap por sessão — não é necessário que o app o envie correctamente nos writes | Pitfall 4 | Sem impacto se o token nos writes for irrelevante; impacto se for um nonce de autenticação |

---

## Open Questions

1. **Formato dos writes de cmd-in: 4.0-format ou Maverick-wrapped?**
   - O que sabemos: os 155 cmd-in writes capturados do app oficial são todos Maverick-wrapped (FINDINGS_5.md §7). O `Commands.swift` existente gera frames 4.0-format.
   - O que não é claro: se o WHOOP 5.0 rejeita 4.0-format writes, ou se os aceita. Não há evidência directa de que o strap valida o wrapper no sentido entrada (só nas notificações de saída).
   - Recomendação: testar com 4.0-format primeiro (menos disruptivo). Se o handshake funcionar (SEND_HISTORICAL_DATA recebe resposta), 4.0-format funciona. Se não, adicionar Maverick wrapping aos writes com token `[0x00,0x00,0x00]`.

2. **Os testes existentes (ParityTests, SchemaSyncTests) devem ser mantidos para 4.0 ou convertidos para 5.0?**
   - O que sabemos: após D-01, o `loadSchema()` carrega o schema 5.0. Os testes existentes usam frames 4.0 e golden 4.0. O schema 5.0 tem offsets body-absolute diferentes dos frame-absolute 4.0.
   - O que não é claro: se os testes 4.0 continuam a ser valiosos (como regression para o encoder/decoder base) ou se são confusos (o decoder agora usa schema 5.0).
   - Recomendação: manter os testes 4.0 como estão (eles continuam a exercitar Framing.swift, CRCs, Reassembler) mas marcar claramente que usam schema 4.0. Adicionar testes 5.0 separados com `frames_5.json`.

3. **Battery SOC offset no 5.0 (PROTO-08 HYPOTHESIS)**
   - O que sabemos: `BATTERY_LEVEL` event e `EXTENDED_BATTERY_INFORMATION` estão presentes mas o offset SOC não foi validado contra ground truth (23% do 0x2A19). O schema 5.0 marca como HYPOTHESIS.
   - O que não é claro: se `state.setBattery()` vai receber valores correctos da implementação 5.0.
   - Recomendação: capturar um `GET_BATTERY_LEVEL`(cmd 26) no iPhone e comparar com a leitura 0x2A19 como primeira validação na Fase 5.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build iOS app | ✓ | via /Applications/Xcode.app | — |
| Swift | Build WhoopProtocol | ✓ | 6.3.2 | — |
| iOS deployment target | IOS-01 (iPhone físico) | ✓ | iOS 16.0 (project.yml) | — |
| iPhone físico WHOOP 5.0 | IOS-01, IOS-06, IOS-08 | [ASSUMED] | — | Nenhum fallback — Simulator não suporta CoreBluetooth real |
| Docker | SRV-05 | [ASSUMED] | — | `docker compose up -d --build` |
| Python 3.9+ | gen_golden.py / SWIFT-06 | ✓ | 3.9.6 | — |
| `whoop_protocol` Python package | gen_golden.py | ✓ | server/packages/whoop-protocol (editable install) | — |
| frames_5_golden.json | D-03 (gen_golden.py input) | ✓ | 123 fixtures confirmados | — |

**Missing dependencies with no fallback:**
- iPhone físico com WHOOP 5.0 — IOS-01/IOS-06/IOS-08 requerem hardware real. Simulator não serve.

**Missing dependencies with fallback:**
- Nenhum.

---

## Validation Architecture

> `workflow.nyquist_validation` está explicitamente `false` em `.planning/config.json`. Esta secção é omitida.

---

## Security Domain

> Esta fase não introduz novos vectores de segurança — sem novas rotas de API, sem novos inputs de rede, sem novos mecanismos de auth. A Bearer auth existente em main.py, a política de gitignore para raw captures, e o DISCLAIMER.md aplicam-se sem mudanças. Secção omitida por ausência de novos controlos ASVS necessários.

---

## Sources

### Primary (HIGH confidence)

- `FINDINGS_5.md` — protocolo de referência WHOOP 5.0; §7 Framing (Maverick wrapper, 5028/5028 VERIFIED), §8 Decode (body offsets, command surface, biometric streams VERIFIED/HYPOTHESIS)
- `protocol/whoop_protocol_5.json` — schema canónico 5.0; body-absolute offsets, enum maps r52, confidence tags
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` — loadSchema() lida directamente; linha 178 = target para D-01
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` — CRC8/CRC32 já implementados; Reassembler OK; verifyFrame() a não aplicar sobre body stripped
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift` — structs de streams; GravitySample para D-06
- `Packages/WhoopStore/Sources/WhoopStore/Database.swift` — padrão v5/v6/v7 para D-06; v8 segue exactamente o mesmo padrão
- `ios/OpenWhoop/BLE/BLEManager.swift` — 6 UUID strings identificadas; bootstrapStore() "WHOOP 4.0" string; UUID replace é única mudança
- `ios/OpenWhoop/BLE/Commands.swift` — enum WhoopCommand; Commands VERIFIED vs enum actual documentado
- `server/db/init.sql` — padrão `ALTER TABLE ADD COLUMN IF NOT EXISTS` confirmado (charging, exercise_sessions)
- `server/ingest/app/main.py` — `DecodedBatch` Pydantic model; `compute_day()` throttle já implementado
- `re/survey_5/validate_frames_5.py` — `strip_maverick()` reference implementation (Python)
- `scripts/gen_synthetic_fixtures.py` — gerador de golden fixtures 4.0; base para adaptar para 5.0

### Secondary (MEDIUM confidence)

- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/SchemaSyncTests.swift` — testes a actualizar para schema 5.0 (MEDIUM: implicação directa mas requer confirmação de scope)
- `.planning/phases/04-protocol-decode-schema/04-PATTERNS.md` — padrão `parse_body_5()` e offsets confirmados
- `.planning/phases/04-protocol-decode-schema/04-RESEARCH.md` — assumptions A7 sobre cmd-in format confirmadas no corpus

### Tertiary (LOW confidence)

- A1 (Assumption Log): WHOOP 5.0 aceita writes em 4.0-format — não verificado directamente; inferido de ausência de evidência de rejeição

---

## Metadata

**Confidence breakdown:**
- Swift decoder changes (D-01/D-02): HIGH — código lido directamente; offsets verificados no schema 5.0
- iOS BLE UUIDs (D-04): HIGH — UUIDs VERIFIED em FINDINGS_5.md §1 (5028 frames, nRF Connect)
- Commands enum (D-05): HIGH — 10 VERIFIED listados explicitamente em FINDINGS_5.md §8
- WhoopStore v8 migration (D-06): HIGH — padrão v5/v6/v7 lido directamente; nullable columns idênticas
- Server changes (D-09/D-10): HIGH — padrão idempotente já estabelecido em init.sql; Pydantic model simples
- Command format (4.0 vs Maverick para writes): LOW — open question crítica, não verificada
- gen_golden.py adaptação para 5.0: MEDIUM — arquitectura clara mas implementação não escrita ainda

**Research date:** 2026-05-30
**Valid until:** 2026-07-30 (schema 5.0 estável; firmware WG50_r52 fixo)
