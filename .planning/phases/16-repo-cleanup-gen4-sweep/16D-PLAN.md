---
id: 16D
wave: 3
title: "CLEAN-03 — Device generation detection: enum DeviceGeneration + routing stub"
objective: "Adicionar enum DeviceGeneration ao WhoopStore, campo generation: DeviceGeneration ao Device model, inferência via hardware revision WG50→.gen5, e stub de routing no BLEManager. Nenhum comportamento alterado para WHOOP 5.0."
depends_on: [16C]
requirements_addressed: [CLEAN-03]
files_modified:
  - "Packages/WhoopStore/Sources/WhoopStore/WhoopStore.swift"
  - "Packages/WhoopStore/Sources/WhoopStore/StreamStore.swift"
  - "ios/OpenWhoop/BLE/BLEManager.swift"
autonomous: true
---

# Plan 16D — CLEAN-03: Device generation detection

## Context

O BLEManager não distingue actualmente WHOOP 4.0 de 5.0 — apenas usa o path Maverick (5.0). Para suportar futuramente o path Gen4 (4.0), e para documentar a geração no store, precisamos de:

1. `enum DeviceGeneration { case gen4, gen5 }` — em WhoopStore (público, partilhado)
2. Campo `generation: DeviceGeneration` no model/struct de Device em WhoopStore
3. Inferência no connect via hardware revision: `WG50` → `.gen5`, outros → `.gen4`
4. Stub de routing no `BLEManager` que usa `device.generation` (agora sempre `.gen5` para o WHOOP 5.0 actual)

**D-10**: Hardware revision `WG50` já confirmada em `docs/findings/FINDINGS_5.md` (Device Information Service, characteristic 0x2A27 = `WG50_r52`). A leitura de 0x2A27 não está ainda implementada no BLEManager — o stub pode inferir via outro método ou simplesmente assumir `.gen5` para já (o BLE scanning por service UUID já filtra apenas WHOOP devices). Detalhe: a leitura de hardware revision é opcional na Fase 16 — o stub pode usar um placeholder (`generation = .gen5` por default) com um TODO para 0x2A27.

**D-12**: Gate — após implementação, o build passa e o comportamento com WHOOP 5.0 é idêntico ao actual.

## Tasks

<task id="16D-T1">
<title>Adicionar enum DeviceGeneration e campo generation ao WhoopStore</title>
<read_first>
- `Packages/WhoopStore/Sources/WhoopStore/WhoopStore.swift` — ler o ficheiro completo, identificar onde adicionar o enum
- `Packages/WhoopStore/Sources/WhoopStore/StreamStore.swift` — ler `upsertDevice(id:mac:name:)` para perceber o modelo de Device actual (é um upsert SQL, não um struct Swift)
- `Packages/WhoopStore/Sources/WhoopStore/Database.swift` — verificar o schema da tabela `device` (colunas: id, mac, name, firstSeen, lastSeen)
</read_first>
<action>
1. Adicionar ao início de `WhoopStore.swift` (após os imports, antes de `WhoopStoreInfo`):
   ```swift
   /// Hardware generation of the connected WHOOP device.
   /// Inferred from the hardware revision string (Device Information Service, 0x2A27).
   /// `.gen5` = WHOOP 5.0 (hardware revision contains "WG50").
   /// `.gen4` = WHOOP 4.0 or unknown (fallback).
   public enum DeviceGeneration: String, Codable, Sendable {
       case gen4
       case gen5
   }
   ```
2. Verificar que o enum é público (`public enum`) — será usado pelo `ios/OpenWhoop/` target
3. NÃO adicionar coluna à tabela `device` no DB — a geração é uma propriedade em memória do BLEManager, não persistida (a inferência re-corre em cada connect)
</action>
<acceptance_criteria>
- `WhoopStore.swift` contém `public enum DeviceGeneration` com cases `gen4` e `gen5`
- O enum é `public` (acessível de `ios/OpenWhoop/`)
- O enum conforma a `Codable` e `Sendable`
- A tabela `device` no Database.swift NÃO foi alterada (geração é in-memory)
</acceptance_criteria>
</task>

<task id="16D-T2">
<title>Adicionar detecção de geração e campo generation ao BLEManager</title>
<read_first>
- `ios/OpenWhoop/BLE/BLEManager.swift` — ler as linhas de `bootstrapStore()` e `runConnectHandshake()` — onde o device é registado
- `Packages/WhoopStore/Sources/WhoopStore/StreamStore.swift` — ler `upsertDevice(id:mac:name:)` para perceber onde se adiciona a geração (pode ser na call site ou num método novo)
- `ios/OpenWhoop/BLE/BLEManager.swift` — ler `didConnect` e `peripheral(_:didDiscoverCharacteristicsFor:)` — onde seria possível ler 0x2A27
</read_first>
<action>
1. Adicionar propriedade privada ao `BLEManager`:
   ```swift
   /// Detected hardware generation of the connected WHOOP strap.
   /// Inferred from hardware revision (0x2A27). Defaults to .gen5 until 0x2A27 is read.
   /// TODO(CLEAN-03): read 0x2A27 (Device Information) characteristic at connect for accurate detection.
   private var detectedGeneration: DeviceGeneration = .gen5
   ```
2. Adicionar método de inferência (puro, testável):
   ```swift
   /// Infer WHOOP hardware generation from the Device Information 0x2A27 hardware revision string.
   /// "WG50" prefix → .gen5; anything else → .gen4.
   static func inferGeneration(hardwareRevision: String) -> DeviceGeneration {
       hardwareRevision.hasPrefix("WG50") ? .gen5 : .gen4
   }
   ```
3. Em `runConnectHandshake()` ou `bootstrapStore()`, adicionar log da geração detectada:
   ```swift
   log("Device generation: \(detectedGeneration) (hardware revision: TODO 0x2A27)")
   ```
4. Em `didUpdateValueFor` (no switch de characteristic.uuid), adicionar um case stub para ler 0x2A27 quando disponível:
   ```swift
   // TODO(CLEAN-03): parse Device Information 0x2A27 for hardware revision detection
   // case BLEManager.deviceInfoRevChar:
   //     if let revStr = String(bytes: bytes, encoding: .utf8) {
   //         detectedGeneration = BLEManager.inferGeneration(hardwareRevision: revStr)
   //         log("Hardware revision: \(revStr) → generation: \(detectedGeneration)")
   //     }
   ```
   (Comentado por enquanto — activar quando 0x2A27 for subscrição confirmada)
</action>
<acceptance_criteria>
- `BLEManager.swift` contém `private var detectedGeneration: DeviceGeneration = .gen5`
- `BLEManager.swift` contém `static func inferGeneration(hardwareRevision: String) -> DeviceGeneration`
- `inferGeneration("WG50_r52")` retorna `.gen5` (verificável com teste unitário ou lógica inline)
- `inferGeneration("WH10B1")` retorna `.gen4`
- O WHOOP 5.0 actual é detectado como `.gen5` (default .gen5 + o stub não altera o comportamento)
- O comentário TODO documenta onde activar a leitura real de 0x2A27
</acceptance_criteria>
</task>

<task id="16D-T3">
<title>Adicionar routing stub no BLEManager baseado em detectedGeneration</title>
<read_first>
- `ios/OpenWhoop/BLE/BLEManager.swift` — ler `beginBackfill()` e a secção de `didDiscoverServices` onde os services são descobertos — onde o routing está implícito
- `ios/OpenWhoop/BLE/BLEManager.swift` — ler `runConnectHandshake()` — onde o path Maverick 5.0 é seguido
</read_first>
<action>
1. Adicionar método de routing stub (não altera nenhum path existente):
   ```swift
   /// Apply generation-specific connection paths.
   /// Gen5 (WHOOP 5.0): Maverick framing (FD4B0002/0003/0005) — current active path.
   /// Gen4 (WHOOP 4.0): Gen4 framing (61080xxx) — stub only; full implementation in backlog 999.1.
   private func applyGenerationRouting() {
       switch detectedGeneration {
       case .gen5:
           log("Routing: gen5 path (Maverick FD4B0002/0003/0005)")
           // Current path — no changes needed.
       case .gen4:
           log("Routing: gen4 path (61080xxx) — stub only, not implemented in this phase")
           // TODO(backlog 999.1): implement Gen4 framing path
       }
   }
   ```
2. Chamar `applyGenerationRouting()` no início de `runConnectHandshake()`:
   ```swift
   private func runConnectHandshake() {
       guard !connectHandshakeDone else { return }
       connectHandshakeDone = true
       backfillStarted = true
       applyGenerationRouting()  // CLEAN-03: routing based on detected generation
       // ... rest of handshake unchanged
   ```
3. Verificar: o comportamento com WHOOP 5.0 é exactamente o mesmo (`.gen5` → log "gen5 path", continua como antes)
</action>
<acceptance_criteria>
- `BLEManager.swift` contém `private func applyGenerationRouting()`
- `runConnectHandshake()` chama `applyGenerationRouting()` no início
- Para `.gen5`: o comportamento após `applyGenerationRouting()` é exactamente o mesmo de antes (sem alteração de lógica)
- Para `.gen4`: apenas log + TODO (não altera nenhum comportamento)
- O switch em `applyGenerationRouting()` cobre ambos os cases do enum (sem warning de "switch is not exhaustive")
</acceptance_criteria>
</task>

<task id="16D-T4">
<title>Build gate final, testes e commit CLEAN-03</title>
<read_first>
- `ios/OpenWhoop/BLE/BLEManager.swift` — estado final após todas as edições
- `Packages/WhoopStore/Sources/WhoopStore/WhoopStore.swift` — estado final com enum DeviceGeneration
- `ios/OpenWhoopTests/` — verificar se há testes de BLEManager que precisam de ser actualizados
</read_first>
<action>
1. Correr testes: `cd ios && xcodebuild test -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "PASS|FAIL|error:"` (se disponíveis)
2. Build gate: `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15`
3. Gate deve terminar com `** BUILD SUCCEEDED **`
4. Verificar que a função `inferGeneration` se comporta correctamente:
   - `BLEManager.inferGeneration(hardwareRevision: "WG50_r52")` → `.gen5`
   - `BLEManager.inferGeneration(hardwareRevision: "WH10B1")` → `.gen4`
5. Commit WhoopStore: `git add Packages/WhoopStore/Sources/WhoopStore/WhoopStore.swift && git commit -m "feat: add DeviceGeneration enum to WhoopStore (CLEAN-03)"`
   (Ou `ios/Packages/...` se Packages/ foi movido)
6. Commit BLEManager: `git add ios/OpenWhoop/BLE/BLEManager.swift && git commit -m "feat: add generation detection stub and routing in BLEManager (CLEAN-03)"`
</action>
<acceptance_criteria>
- Build gate: `** BUILD SUCCEEDED **`
- `DeviceGeneration.gen5` acessível no BLEManager (importando WhoopStore)
- `BLEManager.inferGeneration(hardwareRevision: "WG50_r52")` == `.gen5`
- `BLEManager.inferGeneration(hardwareRevision: "anything_else")` == `.gen4`
- `detectedGeneration` é `.gen5` em runtime com o WHOOP 5.0 actual (confirmar pelo log "Routing: gen5 path")
- Comportamento BLE com WHOOP 5.0 idêntico ao anterior — nenhuma lógica de connect/backfill alterada
</acceptance_criteria>
</task>

## Verification

<must_haves>
<truths>
- `enum DeviceGeneration { case gen4, gen5 }` existe em WhoopStore, é público
- `BLEManager.inferGeneration(hardwareRevision:)` infere correctamente via prefixo "WG50"
- O path WHOOP 5.0 (Maverick) é inalterado — `.gen5` aplica exatamente o mesmo comportamento de antes
- Build gate: `** BUILD SUCCEEDED **`
- Nenhuma migração de DB adicionada (geração é in-memory, não persistida)
- O stub para Gen4 tem TODO documentado apuntando para backlog 999.1
</truths>
</must_haves>

**Gate final**: `cd ios && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5` → `** BUILD SUCCEEDED **`
