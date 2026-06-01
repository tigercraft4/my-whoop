---
plan: "06-01"
phase: "06"
title: "FF Exchange Race Condition Fix"
status: complete
completed: "2026-05-31"
---

# Summary — 06-01: FF Exchange Race Condition Fix

## What Was Built

Corrigida a race condition no FF key exchange em `BLEManager.swift` que impedia o histórico do WHOOP 5.0 de fluir para o pipeline. A fix é composta por 4 mudanças cirúrgicas:

1. **asyncAfter(1.5s) removido** — O delay cego que disparava `requestSync(.connect)` antes do FF exchange completar foi eliminado completamente (incluindo o comentário que o justificava). Zero asyncAfters para o trigger de connect.

2. **guard !ffExchangePending em beginBackfill()** — Adicionado imediatamente após o guard `connectHandshakeDone` existente. Protege contra qualquer path de chamada (timer periódico, foreground, strap trigger) que dispare `beginBackfill()` antes do exchange completar.

3. **setFFValues() dispara requestSync(.connect)** — Após definir `ffExchangePending = false`, a função chama `requestSync(.connect)` directamente. Event-driven, sem callbacks ou closures novos. Log actualizado: "BF: FF exchange complete — requestSync(.connect) triggered".

4. **Watchdog ffExchangeTimeout (15s)** — `DispatchWorkItem` armado em `runConnectHandshake()` quando `ffExchangePending = true`. Cancelado em `setFFValues()` antes de limpar `ffExchangePending`. Se o strap não responde em 15s, o watchdog limpa o pending e chama `requestSync(.connect)` (graceful fallback). Segue o padrão do `backfillTimeout` existente.

## Files Modified

- `ios/OpenWhoop/BLE/BLEManager.swift` — 4 mudanças cirúrgicas (property `ffExchangeTimeout`, watchdog em `runConnectHandshake`, guard em `beginBackfill`, chain em `setFFValues`)

## Self-Check: PASSED

- asyncAfter(1.5s) removido: `grep -n "asyncAfter.*1\.5" BLEManager.swift` → 0 resultados ✓
- guard !ffExchangePending presente em beginBackfill(): linha 294 ✓
- requestSync(.connect) em setFFValues(): linha 890 ✓
- ffExchangeTimeout DispatchWorkItem armado/cancelado: linhas 839–846 (arm), 887–888 (cancel) ✓
- Log "BF: FF exchange timeout (15s)": linha 841 ✓
- Watchdog não envia comandos BLE directamente ✓
- BUILD SUCCEEDED (zero erros, 6 warnings pré-existentes) ✓

## Deviations

Nenhum. Implementação seguiu exactamente os must_haves D-01 a D-04 e o invariante BF-P1.

## Key Files

key-files.created:
  - (nenhum ficheiro novo criado)
key-files.modified:
  - ios/OpenWhoop/BLE/BLEManager.swift
