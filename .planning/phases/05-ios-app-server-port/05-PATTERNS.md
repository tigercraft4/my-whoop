# Phase 5: iOS App & Server Port - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 11 (ficheiros a criar ou modificar)
**Analogs found:** 11 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` | utility | request-response | — (is the analog itself) | self |
| `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` | utility | transform | — (is the analog itself) | self |
| `Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift` | model | transform | — (is the analog itself) | self |
| `Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` | utility | request-response | `Schema.swift` (loadSchema pattern) | role-match |
| `Packages/WhoopProtocolTests/Resources/frames_5.json` | config | batch | `Resources/frames.json` | exact |
| `Packages/WhoopProtocol/Tests/WhoopProtocolTests/SchemaSyncTests.swift` | test | request-response | `SchemaSyncTests.swift` (is the analog) | self |
| `Packages/WhoopStore/Sources/WhoopStore/Database.swift` | model | CRUD | — (is the analog itself) | self |
| `ios/OpenWhoop/BLE/BLEManager.swift` | service | event-driven | — (is the analog itself) | self |
| `ios/OpenWhoop/BLE/Commands.swift` | utility | request-response | — (is the analog itself) | self |
| `server/db/init.sql` | config | CRUD | — (is the analog itself) | self |
| `server/ingest/app/main.py` | service | request-response | — (is the analog itself) | self |
| `server/packages/whoop-protocol/whoop_protocol/schema.py` | utility | request-response | — (is the analog itself) | self |
| `scripts/gen_synthetic_fixtures.py` | utility | batch | — (is the analog itself) | self |

> Nota: todos os ficheiros desta fase SÃO os seus próprios analógicos — trata-se de modificações cirúrgicas, não de ficheiros novos do zero. O pattern mapper identifica o padrão existente DENTRO de cada ficheiro para que o planner saiba exactamente o que copiar/manter e o que mudar.

---

## Pattern Assignments

### `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` (utility, request-response)
**Decisão:** D-01 — `loadSchema()` aponta para `whoop_protocol_5.json` em vez de `whoop_protocol.json`.
**Analog:** o próprio ficheiro (modificação pontual)

**Padrão de carregamento de schema — linha única a alterar** (linha 178):
```swift
// ANTES (Schema.swift linha 178):
guard let url = Bundle.module.url(forResource: "whoop_protocol", withExtension: "json") else {
    fatalError("whoop_protocol.json missing from Bundle.module resources")
}

// DEPOIS (D-01):
guard let url = Bundle.module.url(forResource: "whoop_protocol_5", withExtension: "json") else {
    fatalError("whoop_protocol_5.json missing from Bundle.module resources")
}
```

**Padrão de cache singleton** (linhas 174-177 — MANTER INALTERADO):
```swift
private var _cachedSchema: Schema?

public func loadSchema() -> Schema {
    if let cached = _cachedSchema { return cached }
    // ...
```

**Padrão de JSON decoding** (linhas 187-230 — MANTER INALTERADO):
```swift
let raw: RawSchema
do {
    raw = try JSONDecoder().decode(RawSchema.self, from: data)
} catch {
    fatalError("failed to decode whoop_protocol.json: \(error)")
}
```

---

### `Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` (utility, request-response)
**Decisão:** Actualizar `schemaResourceURL()` para apontar ao resource `"whoop_protocol_5"` (necessário para SchemaSyncTests).
**Analog:** o próprio ficheiro (WhoopProtocol.swift, 10 linhas)

**Padrão existente** (linhas 1-10 — linha 8 a alterar):
```swift
public enum WhoopProtocolInfo {
    /// URL of the bundled canonical decode schema (a resource of this package target).
    public static func schemaResourceURL() -> URL? {
        // ANTES:
        Bundle.module.url(forResource: "whoop_protocol", withExtension: "json")
        // DEPOIS (D-01 corollary):
        Bundle.module.url(forResource: "whoop_protocol_5", withExtension: "json")
    }
}
```

---

### `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` (utility, transform)
**Decisão:** D-02 — adicionar `stripMaverick()` aqui (ficheiro de funções puras de framing).
**Analog:** o próprio ficheiro — padrão de helper puro já estabelecido por `crc8()`, `crc32()`, `verifyFrame()`.

**Padrão de função pura de framing** (linhas 23-29 e 78-92 — REUTILIZAR ESTRUTURA):
```swift
// Padrão estabelecido por crc8() e verifyFrame() — função pura, sem dependências externas:
public func crc8(_ bytes: [UInt8]) -> UInt8 {
    var crc: UInt8 = 0
    for b in bytes { crc = crc8Table[Int(crc ^ b)] }
    return crc
}

public func verifyFrame(_ frame: [UInt8]) -> FrameCheck {
    if frame.count < 8 || frame[0] != 0xAA {
        return FrameCheck(ok: false)
    }
    // ...
}
```

**Nova função a adicionar** — copiar o padrão acima:
```swift
// Adicionar APÓS verifyFrame() em Framing.swift
// Source: re/survey_5/validate_frames_5.py strip_maverick() (linhas 108-122) — port Swift
/// Strip the 4-byte Maverick header + 4-byte trailer, returning the flat body.
/// Returns nil if the frame is not a valid Maverick wrapper.
/// Layout: [0xAA][0x01][len u16-LE][body (length bytes)][trailer 4B]
/// VERIFIED: 5028/5028 captured WHOOP 5.0 ATT notifications follow this layout.
public func stripMaverick(_ frame: [UInt8]) -> [UInt8]? {
    guard frame.count >= 9,
          frame[0] == 0xAA,
          frame[1] == 0x01 else { return nil }
    let length = Int(frame[2]) | (Int(frame[3]) << 8)   // u16-LE at offset 2-3
    guard frame.count == length + 8 else { return nil }
    return Array(frame[4..<4 + length])  // flat body: role + token(3) + ptype + seq + cmd + payload
}
```

**Helper u16le privado existente** (linhas 66-68 — REUTILIZAR):
```swift
@inline(__always)
private func u16le(_ bytes: [UInt8], _ off: Int) -> Int {
    Int(bytes[off]) | (Int(bytes[off + 1]) << 8)
}
```

---

### `Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift` (model, transform)
**Decisão:** D-06 — `GravitySample` ganha `gx?, gy?, gz?` nullable.
**Analog:** o próprio ficheiro — padrão de struct `Equatable, Codable` com campos nullable já presente em `BatterySample`.

**Padrão de nullable field** — copiar de `BatterySample` (linhas 29-36):
```swift
public struct BatterySample: Equatable, Codable {
    public let ts: Int
    public let soc: Double?     // <-- nullable (optional Double)
    public let mv: Int?         // <-- nullable
    public let charging: Bool?  // <-- nullable
    public init(ts: Int, soc: Double?, mv: Int?, charging: Bool? = nil) {
        self.ts = ts; self.soc = soc; self.mv = mv; self.charging = charging
    }
}
```

**GravitySample existente** (linhas 69-78 — BASE PARA MODIFICAR):
```swift
public struct GravitySample: Equatable, Codable {
    public let ts: Int
    public let x: Double
    public let y: Double
    public let z: Double
    public let unit: String     // "g"
    public init(ts: Int, x: Double, y: Double, z: Double, unit: String = "g") {
        self.ts = ts; self.x = x; self.y = y; self.z = z; self.unit = unit
    }
}
```

**GravitySample modificado** (D-06 — seguir padrão BatterySample para nullable):
```swift
public struct GravitySample: Equatable, Codable {
    public let ts: Int
    public let x: Double
    public let y: Double
    public let z: Double
    public let gx: Double?   // NOVO — gyroscópio; nil até REALTIME_RAW_DATA tipo 43 confirmado
    public let gy: Double?
    public let gz: Double?
    public let unit: String  // "g"
    public init(ts: Int, x: Double, y: Double, z: Double,
                gx: Double? = nil, gy: Double? = nil, gz: Double? = nil,
                unit: String = "g") {
        self.ts = ts; self.x = x; self.y = y; self.z = z
        self.gx = gx; self.gy = gy; self.gz = gz; self.unit = unit
    }
}
```

**Padrão Streams.init(from:) com decodeIfPresent** (linhas 104-114 — REUTILIZAR para campos novos):
```swift
public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    hr    = try c.decodeIfPresent([HRSample].self,       forKey: .hr)    ?? []
    // ... padrão para qualquer campo novo nullable/opcional: decodeIfPresent ... ?? default
}
```

---

### `Packages/WhoopStore/Sources/WhoopStore/Database.swift` (model, CRUD)
**Decisão:** D-06 — migration v8 adiciona colunas gyro nullable a `gravitySample`.
**Analog:** o próprio ficheiro — padrão `migrator.registerMigration("vN")` com `db.alter(table:)`.

**Padrão v6 — ADD COLUMN nullable** (linhas 137-143, análogo EXACTO para v8):
```swift
migrator.registerMigration("v6") { db in
    // Charging flag for the dense BATTERY_LEVEL-event battery series (nullable: the
    // command-response battery path doesn't report it).
    try db.alter(table: "battery") { t in
        t.add(column: "charging", .boolean)  // <-- sem .notNull() = nullable
    }
}
```

**Padrão v7 — múltiplas colunas nullable numa migração** (linhas 144-153):
```swift
migrator.registerMigration("v7") { db in
    try db.alter(table: "dailyMetric") { t in
        t.add(column: "spo2Pct",      .double)   // nullable (sem .notNull())
        t.add(column: "skinTempDevC", .double)
        t.add(column: "respRateBpm",  .double)
    }
}
```

**Migration v8 a adicionar** (seguir exactamente v7 — ANTES do `return migrator`):
```swift
migrator.registerMigration("v8") { db in
    // Gyroscope columns for gravitySample. Nullable: null until REALTIME_RAW_DATA type-43
    // (TOGGLE_IMU_MODE) is captured. PROTO-14 HYPOTHESIS — columns ready when confirmed.
    try db.alter(table: "gravitySample") { t in
        t.add(column: "gx", .double)   // nullable — sem .notNull()
        t.add(column: "gy", .double)
        t.add(column: "gz", .double)
    }
}
```

**Posição no ficheiro:** inserir entre a migration "v7" (linha 153) e o `return migrator` (linha 155).

---

### `ios/OpenWhoop/BLE/BLEManager.swift` (service, event-driven)
**Decisão:** D-04 — substituir 5 UUID strings `61080001-…` por `FD4B0001-…` + "WHOOP 4.0" → "WHOOP 5.0".
**Analog:** o próprio ficheiro (substituição em-place).

**Bloco de UUIDs existente** (linhas 13-17 — SUBSTITUIR IN-PLACE):
```swift
// ANTES (BLEManager.swift linhas 13-17):
static let customService   = CBUUID(string: "61080001-8d6d-82b8-614a-1c8cb0f8dcc6")
static let cmdWriteChar    = CBUUID(string: "61080002-8d6d-82b8-614a-1c8cb0f8dcc6")
static let cmdNotifyChar   = CBUUID(string: "61080003-8d6d-82b8-614a-1c8cb0f8dcc6")
static let eventNotifyChar = CBUUID(string: "61080004-8d6d-82b8-614a-1c8cb0f8dcc6")
static let dataNotifyChar  = CBUUID(string: "61080005-8d6d-82b8-614a-1c8cb0f8dcc6")

// DEPOIS (D-04, FINDINGS_5.md §1 — VERIFIED via nRF Connect + 5028 captured frames):
static let customService   = CBUUID(string: "FD4B0001-CCE1-4033-93CE-002D5875F58A")
static let cmdWriteChar    = CBUUID(string: "FD4B0002-CCE1-4033-93CE-002D5875F58A")
static let cmdNotifyChar   = CBUUID(string: "FD4B0003-CCE1-4033-93CE-002D5875F58A")
static let eventNotifyChar = CBUUID(string: "FD4B0004-CCE1-4033-93CE-002D5875F58A")
static let dataNotifyChar  = CBUUID(string: "FD4B0005-CCE1-4033-93CE-002D5875F58A")
// heartRateService/heartRateChar/batteryService/batteryChar: INALTERADOS (UUIDs standard BT)
```

**Padrão restoreID** (linha 23 — MANTER INALTERADO — não codifica UUIDs):
```swift
static let restoreID = "com.openwhoop.ble.central"
```

**Comentário a actualizar** (linha 13 — cabeçalho do bloco UUID):
```swift
// ANTES: "// MARK: GATT UUIDs (authoritative, from FINDINGS.md)"
// DEPOIS: "// MARK: GATT UUIDs (authoritative, from FINDINGS_5.md §1 — WHOOP 5.0)"
```

**String "WHOOP 4.0" a localizar com grep:**
```bash
grep -n "WHOOP 4.0\|WHOOP 5.0" ios/OpenWhoop/BLE/BLEManager.swift
# Substituir todas as ocorrências de "WHOOP 4.0" por "WHOOP 5.0"
# Tipicamente em bootstrapStore() → upsertDevice(name: "WHOOP 4.0")
```

---

### `ios/OpenWhoop/BLE/Commands.swift` (utility, request-response)
**Decisão:** D-05 — rever enum `WhoopCommand` contra os 10 VERIFIED da Fase 4; excluir HYPOTHESIS e destrutivos.
**Analog:** o próprio ficheiro.

**Padrão do enum** (linhas 10-58 — estrutura a MANTER):
```swift
public enum WhoopCommand: UInt8, CaseIterable {
    case toggleRealtimeHR      = 3    // cmd byte (on-wire)
    // ...
}
```

**Padrão frame()** (linhas 116-129 — MANTER INALTERADO — 4.0-format; testar no iPhone antes de alterar):
```swift
public func frame(seq: UInt8, payload: [UInt8] = [0x00]) -> [UInt8] {
    let inner: [UInt8] = [Self.commandType, seq, rawValue] + payload
    let length = UInt16(inner.count + 4)
    let lenBytes: [UInt8] = [UInt8(length & 0xFF), UInt8(length >> 8)]
    let headerCRC = crc8(lenBytes)
    let trailer = crc32(inner)
    // ...
    return [0xAA] + lenBytes + [headerCRC] + inner + trailerBytes
}
```

**10 comandos VERIFIED (FINDINGS_5.md §8) — confirmar presença no enum:**
| Cmd | Byte | Status actual no enum |
|-----|------|-----------------------|
| TOGGLE_REALTIME_HR | 3 | presente |
| SET_CLOCK | 10 | presente |
| GET_CLOCK | 11 | presente |
| SEND_HISTORICAL_DATA | 22 | presente |
| HISTORICAL_DATA_RESULT | 23 | presente |
| GET_BATTERY_LEVEL | 26 | presente |
| GET_DATA_RANGE | 34 | presente |
| GET_HELLO_HARVARD | 35 | presente |
| EXIT_HIGH_FREQ_SYNC | 97 | presente |
| GET_EXTENDED_BATTERY_INFO | 98 | presente |

**Verificar HYPOTHESIS a manter fora do enum:** `REPORT_VERSION_INFO(7)`, `START_RAW_DATA(81)`, `STOP_RAW_DATA(82)` — status HYPOTHESIS no r52, incluídos actualmente mas sem confirmação 5.0.

---

### `Packages/WhoopProtocol/Tests/WhoopProtocolTests/SchemaSyncTests.swift` (test, request-response)
**Decisão:** Pitfall 2 — actualizar os dois testes para comparar contra `whoop_protocol_5.json`.
**Analog:** o próprio ficheiro.

**Padrão testBundledSchemaMatchesCanonical()** (linhas 14-25 — MODIFICAR paths):
```swift
func testBundledSchemaMatchesCanonical() throws {
    let canonical = repoRoot()
        .appendingPathComponent("protocol")
        // ANTES: .appendingPathComponent("whoop_protocol.json")
        .appendingPathComponent("whoop_protocol_5.json")   // D-01
    let bundled = repoRoot()
        .appendingPathComponent("Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol.json")
        // ANTES: /whoop_protocol.json
        // DEPOIS: /whoop_protocol_5.json  — aponta para o bundled 5.0
    // XCTAssertEqual permanece inalterado
}
```

**Padrão testBundleModuleSchemaAlsoMatchesCanonical()** (linhas 27-42 — MODIFICAR canonical path):
```swift
func testBundleModuleSchemaAlsoMatchesCanonical() throws {
    let canonical = repoRoot()
        .appendingPathComponent("protocol")
        // ANTES: .appendingPathComponent("whoop_protocol.json")
        .appendingPathComponent("whoop_protocol_5.json")   // D-01
    // moduleURL via WhoopProtocolInfo.schemaResourceURL() — correcto após WhoopProtocol.swift update
    let moduleURL = try XCTUnwrap(
        WhoopProtocolInfo.schemaResourceURL(),
        "WhoopProtocolInfo.schemaResourceURL() returned nil — whoop_protocol_5.json missing")
    // XCTAssertEqual permanece inalterado
}
```

---

### `Packages/WhoopProtocolTests/Resources/frames_5.json` (config, batch) — NOVO FICHEIRO
**Decisão:** D-03 — gerado por `scripts/gen_golden.py` (adaptado para 5.0).
**Analog:** `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json` — formato exacto a replicar.

**Formato do ficheiro existente `frames.json`** (array de objectos com campo `hex`):
```json
[
  {"hex": "aa0c000038002800..."},
  {"hex": "aa0c000138002801..."},
  ...
]
```

**O `frames_5.json` deve ter o MESMO formato** — array de `{"hex": "<maverick-wrapped frame hex>"}`.
O gerador adaptado (ver `scripts/gen_synthetic_fixtures.py`) produz este output via `json.dump`.

---

### `server/db/init.sql` (config, CRUD)
**Decisão:** D-09 — adicionar `ALTER TABLE … ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0'` para cada hypertable.
**Analog:** o próprio ficheiro — padrão idempotente já estabelecido.

**Padrão ALTER TABLE idempotente existente** (linha 66 — EXACTO para replicar):
```sql
-- Idempotent migration for already-initialised databases
ALTER TABLE battery ADD COLUMN IF NOT EXISTS charging BOOLEAN;
```

**Bloco a adicionar** — seguir o mesmo padrão, agrupar após os CREATE TABLE + SELECT create_hypertable:
```sql
-- Idempotent migration: device_generation for 5.0 fork tracking (Phase 5, D-09).
-- DEFAULT '5.0' classifies all existing rows as 5.0 (this is a 5.0-only deployment).
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

### `server/ingest/app/main.py` (service, request-response)
**Decisão:** D-10 — adicionar `device_generation` ao `DecodedBatch` Pydantic model.
**Analog:** o próprio ficheiro — padrão `BaseModel` com campo optional já presente em `IngestBatch`.

**Padrão optional field no Pydantic** (linha 83 — `decode_streams: bool = True`):
```python
class IngestBatch(BaseModel):
    batch_id: str
    device: Device
    clock_ref: ClockRef
    frames: list[Frame]
    decode_streams: bool = True   # <-- campo opcional com default
```

**`DecodedBatch` existente** (linhas 107-109 — BASE PARA MODIFICAR):
```python
class DecodedBatch(BaseModel):
    device: DecodedDevice
    streams: DecodedStreams
```

**`DecodedBatch` modificado** (D-10 — seguir padrão `decode_streams` acima):
```python
class DecodedBatch(BaseModel):
    device: DecodedDevice
    streams: DecodedStreams
    device_generation: str | None = "5.0"  # Optional; default='5.0' for iOS 5.0 fork
```

**Padrão `require_auth`** (linhas 56-59 — MANTER INALTERADO):
```python
def require_auth(authorization: str = Header(default="")) -> None:
    expected = f"Bearer {cfg.api_key}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="unauthorized")
```

**Padrão `ingest_decoded`** (linhas 143-171 — MANTER INALTERADO exceto acesso ao novo campo):
```python
@app.post("/v1/ingest-decoded", dependencies=[Depends(require_auth)])
def ingest_decoded(batch: DecodedBatch):
    payload = batch.model_dump()
    # payload["device_generation"] estará disponível automaticamente via model_dump()
    # store.upsert_streams() pode receber device_generation se necessário
    # ...
```

---

### `server/packages/whoop-protocol/whoop_protocol/schema.py` (utility, request-response)
**Decisão:** SWIFT-06 — adicionar `load_schema_5()` (ou parâmetro de versão) para que `gen_golden.py` 5.0 use offsets 5.0.
**Analog:** o próprio ficheiro — padrão `@lru_cache(maxsize=1)` + `_SCHEMA_PATH`.

**Padrão existente** (linhas 1-42 — REUTILIZAR ESTRUTURA):
```python
_SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "schema", "whoop_protocol.json")

@lru_cache(maxsize=1)
def load_schema() -> Schema:
    with open(_SCHEMA_PATH) as fh:
        return Schema(json.load(fh))
```

**Adição a fazer** — copiar o padrão exato, novo path e nova função:
```python
_SCHEMA_PATH_5 = os.path.join(os.path.dirname(__file__), "schema", "whoop_protocol_5.json")

@lru_cache(maxsize=1)
def load_schema_5() -> Schema:
    """Load the WHOOP 5.0 schema (body-absolute offsets, Maverick wrapper protocol)."""
    with open(_SCHEMA_PATH_5) as fh:
        return Schema(json.load(fh))
```

**Ficheiro de schema a copiar** — `protocol/whoop_protocol_5.json` → `server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json`.

---

### `scripts/gen_synthetic_fixtures.py` (utility, batch) — adaptar para 5.0
**Decisão:** D-03 — adaptar ou criar variante 5.0 que gera `frames_5.json` com frames Maverick-wrapped.
**Analog:** o próprio ficheiro — padrão `build_frame()` + `json.dump` para `frames.json`.

**Padrão `build_frame()` existente** (linhas 78-84 — BASE PARA NOVO `build_maverick_frame()`):
```python
def build_frame(type_byte: int, seq: int, body: bytes) -> bytes:
    """Assemble a complete, CRC-valid frame. `body` = frame bytes from offset 6 onward."""
    inner = bytes([type_byte & 0xFF, seq & 0xFF]) + body
    length = len(inner) + 4
    header = bytes([0xAA]) + struct.pack("<H", length) + bytes([_crc8(struct.pack("<H", length))])
    crc32_val = zlib.crc32(inner) & 0xFFFFFFFF
    return header + inner + struct.pack("<L", crc32_val)
```

**Novo `build_maverick_frame()`** — seguir mesmo estilo, baseado em `re/survey_5/validate_frames_5.py`:
```python
def build_maverick_frame(body: bytes, role: int = 0x01) -> bytes:
    """Wrap a flat body in the Maverick envelope.

    Layout (VERIFIED — 5028/5028 WHOOP 5.0 ATT notifications):
        [0xAA][0x01][len u16-LE][body (length bytes)][trailer 4B]
    total_len == length + 8.
    Role: 0x00 = cmd-in (strap→app writes), 0x01 = notify (app-bound notifications).
    body[0] = role, body[1:4] = token (zeros for synthetic), body[4] = ptype, body[5] = seq.
    """
    length = len(body)
    trailer = bytes(4)  # synthetic: zeros (HYPOTHESIS — trailer contents not verified)
    return bytes([0xAA, 0x01]) + struct.pack("<H", length) + body + trailer
```

**Padrão de output para `frames.json`** (a replicar para `frames_5.json`):
```python
# Padrão existente (gen_synthetic_fixtures.py) — replicar para 5.0:
frames = [{"hex": frame.hex()} for frame in frame_list]
with open(os.path.join(_OUT_DIR, "frames.json"), "w") as f:
    json.dump(frames, f, indent=2)
```

**Output dir para `frames_5.json`** — mesmo `_OUT_DIR`, novo filename:
```python
with open(os.path.join(_OUT_DIR, "frames_5.json"), "w") as f:
    json.dump(frames_5, f, indent=2)
```

---

## Shared Patterns

### Pattern A: Schema-driven decode pipeline
**Source:** `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` linhas 174-233
**Apply to:** `Schema.swift` (D-01), `WhoopProtocol.swift` (schemaResourceURL), `SchemaSyncTests.swift` (paths)

O pipeline completo (`loadSchema()` → `_cachedSchema` singleton → `parseFrame()` → `extractStreams()`) mantém-se inalterado. Apenas o nome do resource JSON muda: `"whoop_protocol"` → `"whoop_protocol_5"`. Todas as outras chamadas do schema-driven pipeline passam sem alteração porque os campos `PacketSpec`, `FieldSpec`, etc. são idênticos entre os dois schemas.

### Pattern B: GRDB nullable migration
**Source:** `Packages/WhoopStore/Sources/WhoopStore/Database.swift` linhas 137-153
**Apply to:** migration v8 em `Database.swift`

```swift
// PADRÃO EXACTO (v6 e v7):
migrator.registerMigration("vN") { db in
    try db.alter(table: "tableName") { t in
        t.add(column: "colName", .type)   // sem .notNull() = nullable
    }
}
// Registar antes de `return migrator`, após a última migration existente.
```

### Pattern C: Idempotent ALTER TABLE SQL
**Source:** `server/db/init.sql` linha 66
**Apply to:** D-09 em `init.sql`

```sql
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS <col> <type> DEFAULT <value>;
-- IF NOT EXISTS garante idempotência: re-runs no startup não falham se coluna já existe.
```

### Pattern D: Pydantic optional field com default
**Source:** `server/ingest/app/main.py` linha 83 (`decode_streams: bool = True`)
**Apply to:** D-10 em `DecodedBatch`

```python
class SomeModel(BaseModel):
    required_field: str
    optional_field: SomeType | None = default_value  # clientes sem o campo recebem o default
```

### Pattern E: Pure Swift function (framing utilities)
**Source:** `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` linhas 23-50
**Apply to:** `stripMaverick()` novo em `Framing.swift`

Funções puras sem estado, sem dependências externas, sem `import` adicional. Tipagem `[UInt8] → [UInt8]?` ou `[UInt8] → T`. Uso de `guard` para early return em vez de `if-else` aninhado.

### Pattern F: Python @lru_cache schema loader
**Source:** `server/packages/whoop-protocol/whoop_protocol/schema.py` linhas 39-42
**Apply to:** `load_schema_5()` novo em `schema.py`

```python
@lru_cache(maxsize=1)
def load_schema_5() -> Schema:
    with open(_SCHEMA_PATH_5) as fh:
        return Schema(json.load(fh))
```

### Pattern G: XCTest resource loading
**Source:** `Packages/WhoopProtocol/Tests/WhoopProtocolTests/ParityTests.swift` linhas 18-21
**Apply to:** Novos testes 5.0 (`Parity5Tests.swift` ou adição aos existentes)

```swift
private func resourceURL(_ name: String, _ ext: String) throws -> URL {
    let url = Bundle.module.url(forResource: name, withExtension: ext)
    return try XCTUnwrap(url, "missing test resource \(name).\(ext) — run scripts/gen_golden.py")
}
// Usar: resourceURL("frames_5", "json") para o novo fixture
```

---

## No Analog Found

Não há ficheiros desta fase sem analog no codebase. Todos os ficheiros são modificações de ficheiros existentes que servem como os seus próprios analógicos.

---

## Pitfalls Críticos para o Planner

| # | Ficheiro | Pitfall | Mitigation |
|---|---------|---------|------------|
| P1 | `Framing.swift` + `Interpreter.swift` | `verifyFrame()` NÃO deve ser chamado sobre o body stripped — o body 5.0 não tem inner CRC32 | `stripMaverick()` → skip `verifyFrame()` → processo schema-driven directo |
| P2 | `SchemaSyncTests.swift` | Após D-01, os dois testes comparam contra `whoop_protocol.json` (4.0) mas o bundled aponta para 5.0 | Actualizar os dois paths de `"whoop_protocol.json"` para `"whoop_protocol_5.json"` |
| P3 | `ParityTests.swift` | `testSwiftMatchesPythonGolden` usa `frames.json` (4.0-format) mas o decoder após D-02 usa schema 5.0 com offsets diferentes | Adicionar `Parity5Tests.swift` que carrega `frames_5.json` + `golden_5.json`; NÃO remover `frames.json` |
| P4 | `Commands.swift` | Se o WHOOP 5.0 rejeitar 4.0-format writes, os comandos nunca são reconhecidos | Testar no iPhone early (Wave 1); se necessário, adicionar `buildMaverickFrame()` a `WhoopCommand.frame()` |
| P5 | `Database.swift` | v8 deve estar registada ANTES de qualquer abertura de DB; a ordem v1..v8 é obrigatória | Registar `v8` após `v7`, antes do `return migrator` — nunca saltá-la |

---

## Metadata

**Analog search scope:** `Packages/`, `ios/OpenWhoop/BLE/`, `server/`, `scripts/`, `re/survey_5/`
**Files scanned:** 13 ficheiros lidos directamente
**Pattern extraction date:** 2026-05-30
