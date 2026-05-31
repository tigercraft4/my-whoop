---
plan: "06-02"
phase: "06"
title: "Backfill Validation: Tests, Logs & Pipeline E2E"
status: complete
completed: "2026-05-31"
---

# Summary — 06-02: Backfill Validation: Tests, Logs & Pipeline E2E

## What Was Built

Validação completa do pipeline de backfill após a correção do FF exchange (Plan 06-01):

1. **3 novos XCTests para safe-trim invariant** em `BackfillerTests.swift`:
   - `testKillMidAckPreservesDataOnReconnect`: setCursor throw não avança o cursor; reconexão consegue avançar após recovery.
   - `testInsertThrowOnChunk2DoesNotSkipTrim`: falha em insert no chunk 2 mantém o trim em 10 (não salta para 20).
   - `testHappyPathOrderIsInsertThenSetCursorThenAck`: ordem explicitamente confirmada — insert antes de setCursor antes de ackTrim.

2. **Log de range temporal dos chunks** em `Backfiller.swift`:
   - Propriedades `firstChunkUnix: UInt32?` e `lastChunkUnix: UInt32` adicionadas.
   - `finishChunk()` actualiza os timestamps em cada chunk recebido.
   - HISTORY_COMPLETE emite: `"BF: session ended — range=XXXXXX...YYYYYY (~N days)"`.
   - Reset em `begin()` e `timeoutFired()`.
   - Logger local com mesmo subsystem/category do BLEManager.

3. **Pipeline chain exitBackfilling() verificado** — todos os 4 elementos confirmados presentes sem modificações:
   - `uploadOpportunistically()` (L391)
   - `restoreFromServerIfNeeded()` (L395)
   - `pullFromServer()` (L396)
   - `onBackfillComplete?()` (L402)

4. **Suite de testes completa**: BackfillerTests 21/21 passam (18 existentes + 3 novos). CollectorTests tem 7 falhas pré-existentes não relacionadas com Fase 6 (confirmado por git stash antes das mudanças).

## Files Modified

- `ios/OpenWhoopTests/BackfillerTests.swift` — 3 novos testes na secção "MARK: - safe-trim invariant"
- `ios/OpenWhoop/Collect/Backfiller.swift` — range temporal tracking + log de sessão

## Self-Check: PASSED

- 3 novos testes em BackfillerTests: `testKillMidAckPreservesDataOnReconnect`, `testInsertThrowOnChunk2DoesNotSkipTrim`, `testHappyPathOrderIsInsertThenSetCursorThenAck` ✓
- BackfillerTests 21/21 passam ✓
- `grep -n "session ended.*range=" Backfiller.swift` → resultado positivo ✓
- exitBackfilling() pipeline chain completa: upload → restore → pull → onBackfillComplete ✓
- BackfillPolicy.swift não modificado (D-09) ✓
- BUILD SUCCEEDED ✓

## Deviations

- CollectorTests tem 7 falhas pré-existentes (não relacionadas com Fase 6; confirmado antes de qualquer mudança desta fase).
- Logger no Backfiller usa variável local `backfillerLogger` (mesmo subsystem/category) em vez de `BLEManager.logger` (que é `private static`).

## Key Files

key-files.created:
  - (nenhum ficheiro novo)
key-files.modified:
  - ios/OpenWhoopTests/BackfillerTests.swift
  - ios/OpenWhoop/Collect/Backfiller.swift
