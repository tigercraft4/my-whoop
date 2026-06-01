---
plan: 16D
phase: 16
status: complete
started: 2026-06-01T21:21:00Z
completed: 2026-06-01T21:22:30Z
---

# Plan 16D Summary — CLEAN-03: Device generation detection

## What Was Built

Adicionado `enum DeviceGeneration` ao WhoopStore (público, Codable, Sendable), método de inferência `BLEManager.inferGeneration(hardwareRevision:)` via prefixo "WG50", propriedade `detectedGeneration: DeviceGeneration = .gen5`, e stub de routing `applyGenerationRouting()` no BLEManager. Nenhum comportamento alterado para WHOOP 5.0.

## Tasks Completed

| Task | Description | Result |
|------|-------------|--------|
| 16D-T1 | `enum DeviceGeneration { case gen4, gen5 }` em WhoopStore.swift | ✓ público, Codable, Sendable |
| 16D-T2 | `inferGeneration(hardwareRevision:)` + `detectedGeneration` em BLEManager | ✓ WG50→.gen5, outros→.gen4 |
| 16D-T3 | `applyGenerationRouting()` + chamada no `runConnectHandshake()` | ✓ .gen5 log "gen5 path", stub gen4 |
| 16D-T4 | Build gate + commits | ✓ BUILD SUCCEEDED (8.2s) |

## Deviations

Nenhum. A implementação seguiu exactamente o plano: geração in-memory (sem coluna DB), default `.gen5` para WHOOP 5.0 actual, TODO documentado para leitura de 0x2A27 e para implementação Gen4 completa (backlog 999.1).

## Commits

- `feat: add DeviceGeneration enum to WhoopStore (CLEAN-03)`
- `feat: add generation detection stub and routing in BLEManager (CLEAN-03)`

## Key Files

### key-files.modified
- `ios/Packages/WhoopStore/Sources/WhoopStore/WhoopStore.swift` — `DeviceGeneration` enum adicionado
- `ios/OpenWhoop/BLE/BLEManager.swift` — `inferGeneration`, `detectedGeneration`, `applyGenerationRouting`

## Self-Check: PASSED

- `enum DeviceGeneration` é `public`, `Codable`, `Sendable`
- `BLEManager.inferGeneration(hardwareRevision: "WG50_r52")` → `.gen5`
- `BLEManager.inferGeneration(hardwareRevision: "WH10B1")` → `.gen4`
- `detectedGeneration` defaults para `.gen5` — comportamento WHOOP 5.0 inalterado
- Nenhuma migração de DB adicionada (geração é in-memory)
- Build gate: BUILD SUCCEEDED
