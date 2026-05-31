# Phase 6: Backfill Fix - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Corrigir a race condition no FF key exchange em `BLEManager.swift` para que os dados históricos fluam corretamente do WHOOP 5.0 — e validar que o pipeline completo (frames → GRDB → upload → compute_day → DailyMetric) funciona end-to-end. Este é o pré-requisito duro para todas as fases v2.0 seguintes (iOS validation, UI redesign, algoritmos).

**Entry condition:** Phase 5 complete — iOS app funcional com WHOOP 5.0 (IOS-01/IOS-02 VERIFIED).

**Deliverables:**
1. `BLEManager.swift` — race condition corrigida: asyncAfter(1.5s) removido; `beginBackfill()` gated em `!ffExchangePending`; `setFFValues()` dispara `requestSync(.connect)` quando o exchange completa; watchdog de 15s para FF exchange silencioso
2. Safe-trim invariant validado via XCTest com SpyBackfillStore (kill mid-ack não perde dados)
3. 14+ dias de backfill histórico confirmado via logs de debug (range temporal dos chunks)
4. `DailyMetric` rows no GRDB após backfill completo (pipeline: upload → compute_day → pull)

**Out of scope:** UI views com dados reais (Fase 7), DailyMetric computation local, qualquer mudança ao BackfillPolicy rate-limiter.

</domain>

<decisions>
## Implementation Decisions

### Mecânica do gate FF (BF-01)

- **D-01:** **Remover o `asyncAfter(1.5s)` que dispara `requestSync(.connect)`.** O delay cego é a raiz da race condition — SEND_HISTORICAL_DATA era enviado antes do FF exchange completar, e o WHOOP 5.0 ignora-o nesse caso. Zero asyncAfter para o trigger de connect.

- **D-02:** **Adicionar `guard !ffExchangePending else { return }` em `beginBackfill()`.** O guard fica no mesmo nível que o `guard connectHandshakeDone` existente (linha 287). Protege contra qualquer via de chamada (timer periódico, foreground, strap trigger) que possa disparar antes do exchange completar.

- **D-03:** **`setFFValues()` chama `requestSync(.connect)` diretamente após definir `ffExchangePending = false`.** Event-driven e explícito — `setFFValues()` já é o ponto natural de fim do exchange. Não introduzir callbacks ou closures novos.

### Fallback para FF exchange silencioso

- **D-04:** **Watchdog de 15 segundos para o FF exchange.** Se o strap não responder ao `startFFKeyExchange` em 15s, o watchdog limpa `ffExchangePending` e chama `requestSync(.connect)` (graceful fallback — o WHOOP 5.0 pode ainda servir histórico sem flags FF completos). Similar ao `backfillTimeout` DispatchWorkItem existente; armado quando `ffExchangePending` é definido `true`, cancelado quando `setFFValues()` corre. Registar o timeout nos logs com nível `.notice`.

### Âmbito DailyMetric (BF-02 critério 3)

- **D-05:** **Full pipeline nesta fase: backfill → upload → compute_day → DailyMetric no GRDB.** O mecanismo já existe: `exitBackfilling()` chama `uploadOpportunistically()` (drain para servidor) + `pullFromServer()` (pull de DailyMetrics). A validação de Fase 6 é confirmar que este ciclo funciona end-to-end quando o backfill funciona. Nenhuma mudança de código ao pipeline de upload/pull — só verificar que corre.

- **D-06:** **Verificar o código existente antes de adicionar qualquer trigger.** `exitBackfilling()` já tem a chain completa (linhas 391–396). Só adicionar código se a validação mostrar que algo está partido.

### Verificação BF-02

- **D-07:** **XCTest com SpyBackfillStore para validar o safe-trim invariant.** `SpyBackfillStore` já existe. Cenário: simular HISTORY_END, lançar erro em `store.insert()`, verificar que `ackTrim` NÃO é chamado e que os dados não estão parcialmente commitados. Testar também o caminho happy path (insert → setCursor → ackTrim em ordem).

- **D-08:** **Logs de debug para validar 14+ dias.** Adicionar (ou confirmar que existem) logs que mostram o range temporal dos chunks históricos recebidos — primeiro e último unix timestamp. Permite verificar cobertura de 14+ dias sem sqlite3 no Mac. Nível `.notice` para visibilidade nos testes no dispositivo.

- **D-09:** **`BackfillPolicy.shouldRun()` não muda.** O comportamento `guard let last = lastBackfillAt else { return true }` já garante que a primeira ligação (sem lastBackfillAt) passa sempre. O floor de 90s para `.connect` mantém-se — cobre reconnect-flaps sem double-backfill.

### Claude's Discretion

- Nomeação exata do DispatchWorkItem para o watchdog FF (e.g., `ffExchangeTimeout`)
- Se o watchdog usa `DispatchQueue.main.asyncAfter` (padrão do `backfillTimeout`) ou `DispatchSourceTimer`
- Ordem dos guards em `beginBackfill()` — sugestão: `connectHandshakeDone` antes de `!ffExchangePending` (mais geral antes de mais específico)
- Formato exato dos logs de range temporal nos chunks

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Ficheiros a modificar (Fase 6)

- `ios/OpenWhoop/BLE/BLEManager.swift` — ficheiro principal da correção; o asyncAfter(1.5s) está na linha 836; `ffExchangePending` lógica nas linhas 827–876; `beginBackfill()` nas linhas 284–308; `setFFValues()` nas linhas 862–878; `exitBackfilling()` nas linhas 383–403.
- `ios/OpenWhoop/Collect/Backfiller.swift` — safe-trim invariant implementado; `finishChunk()` é o método crítico (linhas 120–155). **Não mudar a lógica do invariante** — já está correto.
- `ios/OpenWhoop/BLE/BackfillPolicy.swift` — rate-limiter puro; NÃO mudar nesta fase.

### Testes a adicionar/validar

- `Packages/WhoopProtocolTests/` ou equivalente iOS — localizar `SpyBackfillStore` existente para testes do invariante BF-02.
- `ios/OpenWhoop/Collect/Backfiller.swift` — `BackfillStoreWriting` protocol; `SpyBackfillStore` deve conformar com este protocol.

### Contexto de protocolo (para perceber o FF exchange)

- `FINDINGS_5.md` — secção sobre comandos VERIFIED; `startFFKeyExchange` (cmd 117) e sequência `SEND_NEXT_FF × N → SET_FF_VALUE × N` documentados.
- `protocol/whoop_protocol_5.json` — spec canónico do protocolo; confirmar rawValues dos comandos FF.

### Requirements desta fase

- `.planning/REQUIREMENTS.md` — BF-01, BF-02 (com critérios de aceitação exatos).
- `.planning/ROADMAP.md` §"Phase 6: Backfill Fix" — 3 success criteria.

### Invariante de segurança (não violar)

- **BF-P1 do STATE.md:** Qualquer comando `.withResponse` novo DEVE respeitar o guard `connectHandshakeDone` em `BLEManager.swift:804`. O watchdog FF usa apenas `asyncAfter`/DispatchWorkItem — não envia comandos BLE diretamente.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `BLEManager.backfillTimeout` (DispatchWorkItem) — padrão existente para watchdogs baseados em asyncAfter; reutilizar o mesmo padrão para o watchdog FF exchange (`ffExchangeTimeout`).
- `SpyBackfillStore` — mock do store já existente para testes do Backfiller; usar para BF-02 XCTest.
- `beginBackfill()` guards pattern — `connectHandshakeDone` guard demonstra o padrão; adicionar `ffExchangePending` como guard do mesmo estilo.
- `uploadOpportunistically()` + `pullFromServer()` — chain de upload/pull já em `exitBackfilling()`; não duplicar.

### Established Patterns

- **Guard-early em beginBackfill:** Múltiplos guards no início de `beginBackfill()` são o padrão estabelecido. O novo guard `!ffExchangePending` segue exatamente este padrão.
- **DispatchWorkItem para timeouts:** `backfillTimeout` usa `DispatchWorkItem` + `DispatchQueue.main.asyncAfter`. Replicar para `ffExchangeTimeout`.
- **Logs com nível `.notice`:** Todos os eventos significativos do backfill usam `BLEManager.logger.notice("BF: ...")`. O watchdog FF deve seguir o mesmo prefixo.
- **Event-driven via método direto:** A chain de handshake já chama métodos diretamente (e.g., `sendNextFFRound()` → `setFFValues()`). Chamar `requestSync(.connect)` de `setFFValues()` é consistente com este padrão.

### Integration Points

- `setFFValues()` → `requestSync(.connect)` → `beginBackfill()` — nova chain event-driven após a correção
- `ffExchangeTimeout` DispatchWorkItem armado em `runConnectHandshake()` quando `ffExchangePending = true`; cancelado em `setFFValues()` quando `ffExchangePending = false`
- `beginBackfill()` guard `!ffExchangePending` — bloqueia qualquer trigger (connect, periodic, foreground, strap) até FF exchange completo

</code_context>

<specifics>
## Specific Ideas

- **Remoção cirúrgica do asyncAfter(1.5s):** A linha 836 (`DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.requestSync(.connect) }`) é removida integralmente. Não substituir por outro asyncAfter.

- **Watchdog FF como DispatchWorkItem:** Seguir o mesmo padrão de `backfillTimeout`:
  ```swift
  ffExchangeTimeout?.cancel()
  let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      BLEManager.logger.notice("BF: FF exchange timeout — clearing pending, attempting backfill")
      self.ffExchangePending = false
      self.requestSync(.connect)
  }
  ffExchangeTimeout = item
  DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
  ```

- **Log de range temporal dos chunks:** No `finishChunk()` ou em `exitBackfilling()`, adicionar log com o primeiro e último timestamp unix dos dados recebidos. Exemplo: `"BF: session ended — range=\(firstTs)...\(lastTs) (\(dayCount) days)"`.

</specifics>

<deferred>
## Deferred Ideas

- **UI views com dados reais (IOS-03, IOS-04, IOS-05):** Dependem de backfill funcional; são o foco da Fase 7.
- **Verificação PROTO-11/12/13/14 (streams biométricos HYPOTHESIS):** Também Fase 7 — requerem TOGGLE_IMU_MODE e ground truth hardware.
- **Dual 4.0/5.0 support:** Fora de âmbito do fork — PROJECT.md explicita isto.

</deferred>

---

*Phase: 06-backfill-fix*
*Context gathered: 2026-05-31*
