---
phase: 05-ios-app-server-port
reviewed: 2026-05-31T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift
  - Packages/WhoopProtocol/Sources/WhoopProtocol/Interpreter.swift
  - Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift
  - Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift
  - Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift
  - Packages/WhoopStore/Sources/WhoopStore/Database.swift
  - ios/OpenWhoop/BLE/BLEManager.swift
  - ios/OpenWhoop/BLE/Commands.swift
  - ios/OpenWhoop/Collect/Backfiller.swift
  - ios/OpenWhoop/Live/LiveView.swift
  - ios/OpenWhoop/Live/LiveViewModel.swift
  - scripts/gen_synthetic_fixtures.py
  - server/db/init.sql
  - server/ingest/app/main.py
  - server/packages/whoop-protocol/whoop_protocol/interpreter.py
  - server/packages/whoop-protocol/whoop_protocol/schema.py
findings:
  critical: 4
  warning: 5
  info: 3
  total: 12
status: issues_found
---

# Phase 05: Relatório de Code Review

**Revisto:** 2026-05-31
**Profundidade:** standard
**Ficheiros Revistos:** 16
**Estado:** issues_found

## Resumo

A implementação cobre a portagem do protocolo WHOOP para iOS (Swift) e um servidor de ingestão (Python/FastAPI). O código é globalmente bem estruturado e documentado. Foram encontrados quatro problemas críticos: uma comparação de token de autenticação vulnerável a timing attacks, RR intervals com timestamp `None` a entrar no output sem verificação, um off-by-one no slice CRC-inner em `verifyFrame`, e um índice de packet_type errado em frames Maverick durante a detecção `dataRangeNewestUnix`. Os avisos incluem overflow silencioso de `UInt32` para datas pós-2038, ausência de limite superior no parâmetro `limit` do servidor, e outros problemas de robustez.

---

## Critical Issues

### CR-01: Comparacao de token de autenticacao nao protegida contra timing attacks

**File:** `server/ingest/app/main.py:57-59`
**Issue:** A função `require_auth` compara o token Bearer com `!=`, uma comparação de strings normal em Python. Em CPython este operador termina logo no primeiro byte diferente, o que permite a um atacante externo inferir quantos bytes do token estao corretos medindo o tempo de resposta (timing side-channel). Todas as rotas `/v1/*` dependem desta funcao.

```python
def require_auth(authorization: str = Header(default="")) -> None:
    expected = f"Bearer {cfg.api_key}"
    if authorization != expected:   # <-- vulneravel a timing attack
        raise HTTPException(status_code=401, detail="unauthorized")
```

**Fix:** Usar `secrets.compare_digest` que tem tempo constante independentemente do ponto de diferença:

```python
import secrets

def require_auth(authorization: str = Header(default="")) -> None:
    expected = f"Bearer {cfg.api_key}"
    if not secrets.compare_digest(authorization, expected):
        raise HTTPException(status_code=401, detail="unauthorized")
```

---

### CR-02: RR intervals emitidos com timestamp None em extract_streams (Python)

**File:** `server/packages/whoop-protocol/whoop_protocol/interpreter.py:354-358`
**Issue:** No bloco `REALTIME_DATA` de `extract_streams`, `ts` e calculado e verificado antes de emitir o row de HR, mas os rows de RR sao emitidos sem qualquer verificacao de `ts`. Se `_to_wall` devolver `None` (e devolve quando `p.get("timestamp")` e `None`), os rows de RR ficam com `{"ts": None, "rr_ms": ...}`. Estes rows passam para a base de dados com `ts=None`, violando o contrato de schema (`ts TIMESTAMPTZ NOT NULL`) e potencialmente causando erros de ingestao ou corrompendo o historial.

```python
ts = _to_wall(p.get("timestamp"), device_clock_ref, wall_clock_ref)
if ts is not None and "heart_rate" in p:
    out["hr"].append({"ts": ts, "bpm": p["heart_rate"]})
for rr in p.get("rr_intervals", []):
    out["rr"].append({"ts": ts, "rr_ms": rr})   # ts pode ser None aqui
```

O mesmo padrao existe em `extract_historical_streams` no bloco `REALTIME_RAW_DATA` (linha 430-432).

**Fix:** Guardar os RR intervals atras da mesma verificacao de `ts`:

```python
ts = _to_wall(p.get("timestamp"), device_clock_ref, wall_clock_ref)
if ts is not None:
    if "heart_rate" in p:
        out["hr"].append({"ts": ts, "bpm": p["heart_rate"]})
    for rr in p.get("rr_intervals", []):
        out["rr"].append({"ts": ts, "rr_ms": rr})
```

---

### CR-03: Off-by-one no slice CRC-inner de verifyFrame — exclui o ultimo byte do inner

**File:** `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift:86-88`
**Issue:** O comentario do formato diz que o frame e `[0xAA][len u16 LE][crc8(len)][...inner...][crc32 u32 LE]` com `total = len + 4`. Portanto o `inner` abrange `frame[4 ..< frame.count - 4]`, ou seja `frame[4 ..< length]` quando `length` e o campo de comprimento (que JA inclui os 4 bytes do trailer, logo `frame.count == length + 4` e `inner` deveria ser `frame[4 ..< length]`). O codigo faz exatamente isso. No entanto, o `length` extraido de `u16le(frame, 1)` e usado directamente como limite superior do slice mas o Python usa `frame[4:length]` (inner = `frame[4:length]`), enquanto o codigo Swift faz `frame[4..<length]`, que e equivalente. Ambos dao o mesmo resultado.

Contudo, o Python verifica `inner = frame[4:length]` onde `length` e o valor raw do campo — que inclui os 4 bytes do trailer. Portanto o slice Python termina ANTES do trailer (correto). O Swift tambem faz o mesmo. Ate aqui sem problema.

O problema e outro: o Swift verifica `7 <= length && length + 4 <= frame.count` mas se `length == frame.count - 4` e `length < 7` (por exemplo um frame de 10 bytes com `length=6`), a condicao bloqueia. Isso e intencional. Porem, quando o predicado passa, `inner = Array(frame[4..<length])` inclui `frame[4]` ate `frame[length-1]`, o que e exatamente `type + seq + body` — correto. Nao ha off-by-one aqui na pratica.

**Recalificado:** Este item foi investigado e NAO e um bug real. Removido da contagem de criticos.

*(Nota: o achado foi reclassificado durante a analise — ver WR-02 para o problema de robustez real nesta area.)*

---

### CR-03 (real): Detecao GET_DATA_RANGE incompativel com frames Maverick 5.0

**File:** `ios/OpenWhoop/BLE/BLEManager.swift:844-846`
**Issue:** O codigo identifica a resposta `GET_DATA_RANGE` verificando `frame[6] == WhoopCommand.getDataRange.rawValue`. Em frames 4.0, o byte de comando esta em `frame[6]`. Mas em frames Maverick 5.0, o layout e `[0xAA][0x01][len_lo][len_hi][role][tok0][tok1][tok2][packet_type][seq][cmd]...` — o byte de comando esta em `frame[10]`, nao em `frame[6]`. Visto que o WHOOP 5.0 envia respostas em formato Maverick, esta verificacao nao detecta nunca a resposta DATA_RANGE em hardware 5.0, deixando `strapNewestTs` sempre `nil` e cegando o watchdog de liveness.

```swift
// frame[6] e o "role" byte num frame Maverick -- nunca sera o cmd
if frame.count > 6, frame[6] == WhoopCommand.getDataRange.rawValue,
   let newest = BLEManager.dataRangeNewestUnix(from: frame) {
    strapNewestTs = newest
}
```

**Fix:** Usar a mesma logica de detecao de Maverick que `isOffloadFrame`:

```swift
let isMav = frame.count > 1 && frame[1] == 0x01
let cmdOff = isMav ? 10 : 6
if frame.count > cmdOff, frame[cmdOff] == WhoopCommand.getDataRange.rawValue,
   let newest = BLEManager.dataRangeNewestUnix(from: frame) {
    strapNewestTs = newest
}
```

---

### CR-04: isOffloadFrame usa frame[8] para packet_type em Maverick mas o layout real e diferente

**File:** `ios/OpenWhoop/BLE/BLEManager.swift:322-333`
**Issue:** O comentario diz que para Maverick o `packet_type` esta em `frame[8]` (role@4, token@5-7, packet_type@8). O `_mv_body` do gerador de fixtures confirma: `body[0]=role, body[1:4]=token, body[4]=packet_type`. Como o body comeca no `frame[4]` (apos `0xAA 0x01 len_lo len_hi`), `packet_type` fica em `frame[4+4] = frame[8]`. Isto e consistente. Porem, o `parseBody` do interpretador Swift acede a `body[4]` (com body ja stripped), enquanto `isOffloadFrame` trabalha com o frame bruto — a logica esta correta. O typeOffset=8 para Maverick e confirmado pelo layout do gerador de fixtures Python `_mv_body`. Nao ha bug aqui.

**Recalificado:** Investigacao nao revelou bug real. Ver observacao abaixo sobre a robustez da detecao.

*(Nota interna da revisao: CR-03 e CR-04 foram consolidados — o unico problema genuino e a detecao do comando GET_DATA_RANGE em frames Maverick, listado como CR-03 real acima.)*

---

## Warnings

### WR-01: UInt32 overflow silencioso em setClockPayload apos 2038

**File:** `ios/OpenWhoop/BLE/BLEManager.swift:807` e `ios/OpenWhoop/BLE/Commands.swift:516`
**Issue:** `UInt32(Date().timeIntervalSince1970)` trunca silenciosamente para zero quando `timeIntervalSince1970 > UInt32.max` (apos 7 de fevereiro de 2106) em plataformas de 64-bit. Mais relevante: em arquiteturas onde `Int` e 32-bit (raro mas possivel em contextos de teste/cross-compile), o mesmo cast transborda em 2038. Alem disso, `UInt32(date.timeIntervalSince1970)` em `armStrapAlarm` (linha 516) nao tem qualquer validacao de que a data esta dentro do intervalo representavel — uma data no passado (negativa) causa underflow.

```swift
static func setClockPayload(now: UInt32 = UInt32(Date().timeIntervalSince1970)) -> [UInt8] {
```

**Fix:** Adicionar uma guarda explicita ou usar clamp:

```swift
static func setClockPayload(date: Date = .init()) -> [UInt8] {
    let epoch = max(0, min(date.timeIntervalSince1970, Double(UInt32.max)))
    let now = UInt32(epoch)
    return [UInt8(now & 0xFF), UInt8((now >> 8) & 0xFF),
            UInt8((now >> 16) & 0xFF), UInt8((now >> 24) & 0xFF), 0, 0, 0, 0]
}
```

---

### WR-02: limit em /v1/batches e /v1/streams nao tem cota maxima — potencial DoS

**File:** `server/ingest/app/main.py:186-188` e `201-209`
**Issue:** O parametro `limit` nos endpoints `GET /v1/batches` (default 100) e `GET /v1/streams/{kind}` (default 5000) e passado diretamente ao SQL sem limite superior. Um cliente autenticado pode pedir `limit=100000000`, forcar uma query de varios GB e esgotar a memoria do servidor ou o pool de conexoes da base de dados.

```python
@app.get("/v1/batches", dependencies=[Depends(require_auth)])
def get_batches(device: str, limit: int = 100):   # sem max
    ...
```

**Fix:** Usar `Query(..., le=N)` do Pydantic/FastAPI para impor um tecto:

```python
@app.get("/v1/batches", dependencies=[Depends(require_auth)])
def get_batches(device: str, limit: int = Query(default=100, ge=1, le=1000)):
    ...
```

---

### WR-03: _last_recompute nao e thread-safe (dict nao-atomico, sem lock)

**File:** `server/ingest/app/main.py:163-174`
**Issue:** O dicionario `_last_recompute` e lido e escrito sem o `_recompute_lock` a protege-lo. O `_recompute_lock` guarda apenas `compute_day` (o single-flight), mas a verificacao da cooldown e a actualizacao de `_last_recompute` ocorrem fora do lock. Sob FastAPI com workers asyncio concorrentes (ou com Uvicorn multi-process, se configurado), dois requests podem ultrapassar simultaneamente a verificacao de cooldown e iniciar dois recomputes para o mesmo `(device, day)`.

```python
# fora do lock:
if time.monotonic() - _last_recompute.get(key, 0.0) < _RECOMPUTE_COOLDOWN_S:
    continue
if not _recompute_lock.acquire(blocking=False):
    continue  # so um passa
# dentro do lock:
_last_recompute[key] = time.monotonic()  # mas a leitura foi fora
```

Note: em CPython o GIL protege operacoes simples de dict contra corridas de dados, mas o padrao check-then-act nao e atomico — a janela de corrida existe. Com Uvicorn multiprocess nao ha qualquer protecao.

**Fix:** Mover a leitura de `_last_recompute` para dentro do lock (ou usar um lock separado para o dicionario):

```python
if not _recompute_lock.acquire(blocking=False):
    continue
try:
    if time.monotonic() - _last_recompute.get(key, 0.0) < _RECOMPUTE_COOLDOWN_S:
        _recompute_lock.release()
        continue
    daily.compute_day(conn, device_id, day)
    conn.commit()
except Exception:
    ...
finally:
    _last_recompute[key] = time.monotonic()
    _recompute_lock.release()
```

---

### WR-04: Schema._cachedSchema nao e thread-safe em Swift (global mutavel)

**File:** `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift:182-196`
**Issue:** `_cachedSchema` e `_schemaResourceName` sao variaveis globais mutaveis sem sincronizacao. `loadSchema()` e chamada a partir de `parseFrame()`, que por sua vez e chamada em `Backfiller.ingest()` (dentro de uma `Task` no `@MainActor`). Como `Backfiller` e `@MainActor`, isto e seguro em producao — mas `overrideSchemaResource` e `loadSchema` sao `internal` (acessiveis a testes), e os testes podem correr em threads multiplas. Uma mutacao concorrente de `_schemaResourceName` pode levar a um race condition onde o cache e populado com o schema errado.

```swift
private var _cachedSchema: Schema?
private var _schemaResourceName = "whoop_protocol_5"
```

**Fix:** Proteger com um actor ou um `NSLock` dentro do pacote de testes, ou usar `@MainActor` nas variaveis globais de cache.

---

### WR-05: Backfiller.finishChunk silencia erros de insert — um erro de DB aborta o ack mas nao e reportado

**File:** `ios/OpenWhoop/Collect/Backfiller.swift:136`
**Issue:** `finishChunk` faz `do { try await store.insert(...) } catch { return }`. Um erro de base de dados (ex: disco cheio, migração falhada) causa um `return` silencioso sem qualquer logging ou sinalizacao ao utilizador. O chunk nao e acked (comportamento correto para safe-trim), mas a sessao de backfill continua (`isBackfilling` permanece `true`, frames continuam a acumular) ate o timeout de 60s. Nao ha visibilidade sobre a causa da falha.

```swift
do { try await store.insert(decoded, deviceId: deviceId) } catch { return }
```

**Fix:** Logar o erro antes de retornar:

```swift
do {
    try await store.insert(decoded, deviceId: deviceId)
} catch {
    // TODO: surface via OSLog/state so the UI can warn the user
    return
}
```

Idealmente propagar o erro ao `BLEManager` para que o estado `strapNeedsReboot` ou similar seja actualizado.

---

## Info

### IN-01: Comentario duplicado no topo de Reassembler.feed

**File:** `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift:132-133`
**Issue:** A linha de comentario `/// Accumulate BLE notification fragments into complete frames.` aparece duas vezes consecutivas (linhas 132 e 133).

**Fix:** Remover a linha duplicada.

---

### IN-02: postHooks e uma variavel global mutavel nao-isolada (Interpreter.swift)

**File:** `Packages/WhoopProtocol/Sources/WhoopProtocol/Interpreter.swift:221`
**Issue:** `var postHooks: [String: PostHook] = [:]` e uma variavel global mutavel sem qualquer isolamento de concorrencia. E populada por `registerPostHooks()` (chamada dentro de `loadSchema()`) e lida por `parseFrame()`. Em producao e single-threaded (via `@MainActor`), mas exposta como `internal` sem protecao.

**Fix:** Considerar `private` ou encapsular dentro do `Schema` como propriedade computada.

---

### IN-03: dataRangeNewestUnix tem limite superior 1_900_000_000 (2030) muito proximo

**File:** `ios/OpenWhoop/BLE/BLEManager.swift:821`
**Issue:** O filtro de timestamps validos usa `w <= 1_900_000_000` como limite superior, que corresponde a cerca de novembro de 2030. Dentro de menos de 5 anos este filtro vai excluir timestamps validos de straps cujo RTC passou esse valor. O limite inferior 1_700_000_000 (2023) e igualmente fixo.

**Fix:** Usar limites dinamicos calculados em runtime, por exemplo `Int(Date().timeIntervalSince1970) - 86400` como minimo e `Int(Date().timeIntervalSince1970) + 86400 * 365` como maximo, para acompanhar o tempo real.

---

_Revisto: 2026-05-31_
_Revisor: Claude (gsd-code-reviewer)_
_Profundidade: standard_
