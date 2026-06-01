---
phase: 14
plan: 14-02
title: "Add GRDB migration v10 behaviour test"
status: complete
completed: 2026-06-01
subsystem: WhoopStore Tests
tags: [bugfix, migration, grdb, test]
key-files:
  created: []
  modified:
    - Packages/WhoopStore/Tests/WhoopStoreTests/MigrationTests.swift
metrics:
  tasks_completed: 1
  tasks_total: 1
  commits: 1
---

## Summary

Executado plano 14-02 com 1 tarefa. Todos os 6 testes de MigrationTests passam.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 14-02-T1 | fa4e611 | test(14-02): BUGFIX-03 — add migration v10 behaviour test |

## What Was Built

### BUGFIX-03 (D-08)

Adicionado `testMigrationV10PurgesInvalidRRAndClearsAvgHrv` a `MigrationTests.swift`.

**Estratégia**: Usa `WhoopStore.makeMigrator()` (internal, acessível via `@testable import WhoopStore`) com `DatabaseQueue` em memória. Aplica apenas até v9, insere dados de teste, depois aplica v10.

**Dados de teste inseridos**:
- `rrInterval` inválidos: rrMs=50 (abaixo de 200) e rrMs=65535 (acima de 2000)
- `rrInterval` válidos: rrMs=200 (fronteira inclusiva), rrMs=800, rrMs=2000 (fronteira inclusiva)
- `dailyMetric` com avgHrv=52.0

**Verificações após v10**:
- Linhas inválidas eliminadas (COUNT=0 para rrMs < 200 OR > 2000)
- Linhas válidas preservadas (COUNT=3 para rrMs IN (800, 200, 2000))
- avgHrv=NULL em todos os dailyMetric (COUNT=0 para avgHrv IS NOT NULL)

**Nota sobre D-09**: Database.swift não foi tocado — a migration v10 já estava implementada.

## Test Results

```
Test Suite 'MigrationTests' passed
  Executed 6 tests, with 0 failures (0 unexpected) in 0.060 seconds
```

Incluindo:
- testMigrationV10PurgesInvalidRRAndClearsAvgHrv ✓ (0.004s)
- Todos os 5 testes anteriores ✓

## Deviations

Nenhum. Todos os critérios de aceitação verificados.

## Self-Check: PASSED

- [x] testMigrationV10PurgesInvalidRRAndClearsAvgHrv existe e passa
- [x] Insere 2 rows inválidas (rrMs=50, rrMs=65535) e 3 válidas (200, 800, 2000)
- [x] Asserta rows inválidas eliminadas após v10
- [x] Asserta rows válidas preservadas após v10
- [x] Asserta avgHrv=NULL após v10
- [x] Todos os 6 MigrationTests passam
- [x] Database.swift não foi tocado (D-09)
