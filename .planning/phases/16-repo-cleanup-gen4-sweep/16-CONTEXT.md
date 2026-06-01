# Phase 16: Repo Cleanup + Gen4 Sweep - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Reorganizar a estrutura do repositório e fazer sweep do código Gen4/WHOOP 4.0, sem mudanças de arquitectura. Gate obrigatório: `xcodegen generate` + `xcodebuild build` passa após cada move. Nenhum comportamento alterado — só organização e clareza.

</domain>

<decisions>
## Implementation Decisions

### CLEAN-01 — Reorganização de pastas

- **D-01:** Mover items da raiz para pastas lógicas:
  - `protocol/` → `docs/protocol/`
  - `dashboard/` → `server/dashboard/`
  - `FINDINGS_5.md` + `FINDINGS.md` → `docs/findings/`
  - `APPS IOS APK/` + `bridge_mcp_ghidra.py` → `re/ghidra/`
- **D-02:** `Packages/` (WhoopStore + WhoopProtocol) → `ios/Packages/`. Requer actualizar referências no `ios/project.yml` e `.xcodeproj`. Gate: `xcodegen generate` + `xcodebuild build` obrigatório após este move.
- **D-03:** Gate após cada move individual (não só no final) — se um move quebrar o build, parar e corrigir antes de avançar.
- **D-04:** `re/` permanece na raiz (já está no sítio certo). `docs/`, `ios/`, `server/` permanecem no sítio.

### CLEAN-02 — Gen4 sweep e separação de ficheiros

- **D-05:** O `gen4Service` (61080001) e `gen4DataNotifChar` (61080005) em `BLEManager.swift` **não são código morto** — são o canal de backfill que o WHOOP 5.0 usa para dados históricos. A nomenclatura "gen4" é enganosa.
- **D-06:** Extrair o código 61080005 para `BLEManager+BackfillChannel.swift` (extensão Swift). Renomear:
  - `gen4Service` → `backfillService`
  - `gen4DataNotifChar` → `backfillDataChar`
  - Todos os comentários "gen4/legacy" relativos a 61080005 actualizados para "backfill channel"
- **D-07:** Corrigir a docstring de `WhoopProtocol.swift` que diz "WHOOP 4.0 frame decoder" → "WHOOP frame decoder (4.0 and 5.0 historical frames)"
- **D-08:** Após o sweep de grep (4.0/gen4/Gen4), qualquer referência que sobrar e for genuinamente dead code (sem uso em runtime) pode ser removida. Referências ao protocolo 4.0 em testes (HistoricalV24Tests, etc.) são intencionais — não remover.

### CLEAN-03 — device_generation detection

- **D-09:** Adicionar `enum DeviceGeneration { case gen4, gen5 }` e campo `generation: DeviceGeneration` ao struct/model `Device` (WhoopStore ou BLEManager).
- **D-10:** Inferir geração no connect via hardware revision string: `WG50` → `.gen5`; qualquer outro → `.gen4`. Hardware revision lida de `0x2A27` (Device Information characteristic) no connect.
- **D-11:** O `BLEManager` usa `device.generation` para aplicar o path correcto:
  - `.gen5` → Maverick framing (FD4B0002/0003/0005) — path actual
  - `.gen4` → Gen4 framing (61080xxx) — path legacy; não precisa de implementação completa na Fase 16, apenas o detection + routing stub
- **D-12:** Gate: após implementação de CLEAN-03, o build passa e o comportamento com WHOOP 5.0 é idêntico ao actual (geração detectada como `.gen5`, paths Maverick usados).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Ficheiros a modificar
- `ios/OpenWhoop/BLE/BLEManager.swift` — gen4Service/gen4DataNotifChar a extrair; device_generation a implementar
- `ios/project.yml` — actualizar paths de Packages/ após move para ios/Packages/
- `Packages/WhoopStore/Sources/WhoopStore/WhoopStore.swift` — struct Device a estender com DeviceGeneration
- `Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` — docstring a corrigir

### Ficheiros a criar
- `ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift` — extensão com backfillService/backfillDataChar

### Pastas a mover (targets)
- `docs/protocol/`, `docs/findings/`, `server/dashboard/`, `re/ghidra/`, `ios/Packages/`

### Requirements
- `.planning/REQUIREMENTS.md` §Repo Cleanup — CLEAN-01, CLEAN-02, CLEAN-03

### Build gate
- `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ios/project.yml` — fonte de verdade para xcodegen; actualizar `packages:` path se Packages/ for movido
- `BLEManager.swift` linha 24–28: gen4Service + gen4DataNotifChar já bem comentados; base para extracção
- Hardware revision `WG50_r52` em `0x2A27` já confirmada em FINDINGS_5.md — usar para detecção de gen5

### Established Patterns
- Extensions Swift por responsabilidade já usadas no projecto (BLEManager já tem múltiplos ficheiros?)
- `git mv` preserva histórico ao mover ficheiros — preferir `git mv` sobre `rm + add`
- xcodegen regenera `.xcodeproj` a partir de `project.yml` — qualquer move de Swift files precisa de actualizar `project.yml` também

### Integration Points
- `Packages/` move para `ios/Packages/`: o `ios/project.yml` tem `packages:` que referencia os paths locais — actualizar para `ios/Packages/WhoopStore` e `ios/Packages/WhoopProtocol`
- `Device` struct em WhoopStore — verificar onde é definido e todos os initialisers a actualizar com `generation`

</code_context>

<specifics>
## Specific Ideas

- Usar `git mv` para todos os moves de ficheiros/pastas para preservar histórico
- Mover `Packages/` para `ios/Packages/` é o move mais arriscado — fazer por último, com gate dedicado
- O stub de CLEAN-03 (DeviceGeneration detection) não precisa de implementar o path Gen4 completo — apenas detectar e routing flag; a implementação Gen4 é backlog (999.1)

</specifics>

<deferred>
## Deferred Ideas

- Implementação completa do path Gen4 (61080xxx framing end-to-end) — backlog 999.1, requer Android device
- Limpeza de `re/` scripts Python (muitos scripts de análise ad-hoc) — pode ser feita em paralelo com Fase 17 se necessário

</deferred>

---

*Phase: 16-Repo Cleanup + Gen4 Sweep*
*Context gathered: 2026-06-01*
