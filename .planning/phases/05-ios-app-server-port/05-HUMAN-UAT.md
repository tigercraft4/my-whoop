---
status: partial
phase: 05-ios-app-server-port
source: [05-VERIFICATION.md]
started: 2026-05-31T13:15:00Z
updated: 2026-05-31T13:15:00Z
---

## Current Test

[aguarda verificação humana]

## Tests

### 1. Today/Sleep/Trends populam com dados WHOOP 5.0 (IOS-03/04/05)
expected: As três vistas populam com dados biométricos reais do WHOOP 5.0 após backfill completar com tipo 47
result: [pending] — pipeline implementado; requer WHOOP com dados não sincronizados pela app oficial

### 2. Backfill histórico 14+ dias com safe-trim (IOS-06)
expected: Backfill arranca, recebe frames tipo 47, faz insert→ack sem perda de dados, store_then_ack confirmado
result: [pending] — pipeline implementado; bloqueado por WHOOP sem dados novos durante sessão de teste

### 3. Background reconnect após force-quit (IOS-08)
expected: Após force-quit, app reconecta ao WHOOP 5.0 em background sem intervenção manual (state restoration)
result: [pending] — código correto (bug willRestoreState corrigido); teste físico diferido

### 4. docker compose up --build (SRV-05)
expected: Stack servidor arranca limpo com dados 5.0; pipeline ingest→compute_day→read funcional
result: [pending] — Docker não disponível no sandbox; código validado estaticamente

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
