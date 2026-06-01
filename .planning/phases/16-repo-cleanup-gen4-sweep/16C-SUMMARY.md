---
plan: 16C
phase: 16
status: complete
started: 2026-06-01T21:19:30Z
completed: 2026-06-01T21:21:00Z
---

# Plan 16C Summary — CLEAN-02: Gen4 sweep e extracção do backfill channel

## What Was Built

Extracção das constantes GATT do canal de backfill para ficheiro separado, rename de `gen4Service`→`backfillService` e `gen4DataNotifChar`→`backfillDataChar`, e correcção da docstring em WhoopProtocol.swift. Sem alteração de comportamento BLE.

## Tasks Completed

| Task | Description | Result |
|------|-------------|--------|
| 16C-T1 | Corrigir docstring WhoopProtocol.swift | ✓ "WHOOP frame decoder (4.0 and 5.0 historical frames)" |
| 16C-T2 | Criar BLEManager+BackfillChannel.swift | ✓ backfillService + backfillDataChar definidos |
| 16C-T3 | Rename em BLEManager.swift (5 ocorrências) | ✓ Zero referências gen4Service/gen4DataNotifChar restantes |
| 16C-T4 | Gen4 sweep — verificar referências restantes | ✓ Só comentários históricos legítimos e testes intencionais |
| 16C-T5 | xcodegen + build gate + commits | ✓ BUILD SUCCEEDED (8.1s) |

## Deviations

Nenhum. As referências "Gen4" restantes em `Backfiller.swift`, `Commands.swift`, e `BLEManager.swift` são comentários de contexto de protocolo (documentam o formato Gen4 por oposição ao Maverick 5.0) — correctamente deixados intactos.

## Commits

- `refactor: rename gen4Service→backfillService, gen4DataNotifChar→backfillDataChar (CLEAN-02)`
- `docs: fix WhoopProtocol docstring — 4.0+5.0 historical frames (CLEAN-02)`

## Key Files

### key-files.created
- `ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift` — backfillService + backfillDataChar

### key-files.modified
- `ios/OpenWhoop/BLE/BLEManager.swift` — renames + comentário actualizado
- `ios/Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` — docstring corrigida

## Self-Check: PASSED

- `grep -rn "gen4Service\|gen4DataNotifChar" ios/ --include="*.swift"` → 0 resultados
- `backfillService` e `backfillDataChar` apontam para os mesmos UUIDs (61080001, 61080005)
- Testes HistoricalV24 e outros testes de protocolo 4.0 não foram tocados
- Build gate: BUILD SUCCEEDED
- Nenhuma alteração de comportamento BLE
