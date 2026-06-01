# Phase 17: UI Redesign 1:1 - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Actualizar `DesignTokens.swift` com valores extraídos do IPA (UI-01, gate obrigatório), redesenhar cada ecrã para corresponder 1:1 ao WHOOP app por tab order (UI-02), configurar snapshot testing incremental por ecrã (UI-03), e validar no simulador via XcodeBuildMCP (UI-04). Clean-room: sem assets ou pseudocódigo Ghidra em Swift.

</domain>

<decisions>
## Implementation Decisions

### UI-01 — DesignTokens (gate antes de tudo)

- **D-01:** Extrair hex values das cores do IPA via `assetutil -I` no `Assets.car`. O IPA está em `re/ghidra/` (após move da Fase 16). Comando: `unzip -p "re/ghidra/com.whoop.iphone_5.37.0_und3fined.ipa" "Payload/Whoop.app/Assets.car" | assetutil -I /dev/stdin` ou extrair o .car primeiro.
- **D-02:** Actualizar `WH.Color.*` em `DesignTokens.swift` com os hex values extraídos. Os nomes dos tokens do v4-ui-map.md (`recoveryGreen`, `sleepPerformanceDarkBlue`, `lowStrainBlue`, etc.) são os nomes corretos do design system WHOOP.
- **D-03:** Commit UI-01 (DesignTokens actualizado) antes de qualquer componente — é o gate obrigatório para UI-02/03.

### Tipografia

- **D-04:** Manter SF Pro system fonts — não embeddar Proxima Nova nem DIN Pro (licenças). Aproximar:
  - Proxima Nova → SF Pro (`.system(size:weight:design:.default)`) — já é o default
  - DIN Pro (métricas numéricas) → `.monospacedDigit()` — já usado nos cards
- **D-05:** Não alterar a escala de tipo existente (WH.Font.*) a menos que os valores extraídos do IPA mostrem diferenças significativas.

### UI-02 — Componentes por ecrã

- **D-06:** Ordem de redesign por tab order WHOOP:
  1. **Home/Overview** → TodayView + RecoveryCard (4 gauges circulares)
  2. **Sleep** → SleepView + SleepCard (ring + stage breakdown)
  3. **Strain** → StrainView + StrainCard
  4. **Trends** → TrendsView
  5. **Coaching** → stub/placeholder (não existe no OpenWhoop)
  6. **Health** → stub/placeholder (não existe no OpenWhoop)
  7. **Profile+Settings** → stub/placeholder (não existe no OpenWhoop)
- **D-07:** Para ecrãs que não existem no OpenWhoop (Coaching, Health, Profile) — criar um stub view vazio com o título correcto. Não implementar a lógica — apenas o placeholder para futura implementação.
- **D-08:** Cada componente redesenhado deve usar exclusivamente tokens do `WH.*` — sem valores hardcoded.

### UI-03 — Snapshot Testing

- **D-09:** Adicionar `swift-snapshot-testing` 1.17.6 como dependência SPM em `ios/project.yml`:
  ```yaml
  packages:
    SnapshotTesting:
      url: https://github.com/pointfreeco/swift-snapshot-testing
      exactVersion: 1.17.6
  ```
- **D-10:** Usar o target `OpenWhoopTests` existente (não criar target dedicado).
- **D-11:** Gerar referência de snapshot **imediatamente após redesenhar cada ecrã** (incremental). Fluxo por ecrã: redesign component → build → `assertSnapshot(matching:as:.image(on:.iPhone17Pro))` → commit referência + componente juntos.
- **D-12:** Snapshots gerados em modo dark (`.preferredColorScheme(.dark)`) — app é dark-only.

### UI-04 — Validação no Simulador

- **D-13:** Após cada ecrã, executar `mcp__xcodebuildmcp__screenshot` e `mcp__xcodebuildmcp__snapshot_ui` para comparação visual com o v4-ui-map.md.
- **D-14:** Medições de spacing/radii obtidas via `snapshot_ui` (coordinates e sizes) — complementar o v4-ui-map.md que não encontrou estes valores no binário Ghidra.
- **D-15:** Um ecrã é marcado VERIFIED quando: snapshot gerado ✓, comparação visual satisfatória ✓, commit feito ✓.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Inputs principais
- `docs/specs/v4-ui-map.md` — screen map completo (7 ecrãs, color token names, component hierarchy)
- `docs/whoop-ui-reference.md` — string keys e field labels por tab (complementa v4-ui-map.md)
- `ios/OpenWhoop/Design/DesignTokens.swift` — ficheiro a actualizar em UI-01

### Assets
- `re/ghidra/com.whoop.iphone_5.37.0_und3fined.ipa` — extrair Assets.car para hex colors
- Comando extracção: `mkdir -p /tmp/whoop_assets && cd /tmp/whoop_assets && unzip -q "$(pwd)/re/ghidra/com.whoop.iphone_5.37.0_und3fined.ipa" && assetutil -I Payload/Whoop.app/Assets.car`

### Componentes a redesenhar
- `ios/OpenWhoop/Design/Components/RecoveryCard.swift`
- `ios/OpenWhoop/Design/Components/SleepCard.swift`
- `ios/OpenWhoop/Design/Components/StrainCard.swift`
- `ios/OpenWhoop/Tabs/TodayView.swift`
- `ios/OpenWhoop/Tabs/SleepView.swift`
- `ios/OpenWhoop/Tabs/TrendsView.swift`

### Build
- `ios/project.yml` — adicionar SnapshotTesting 1.17.6 SPM
- Gate: `cd ios && xcodegen generate && xcodebuild test -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

### Requirements
- `.planning/REQUIREMENTS.md` §UI Redesign — UI-01, UI-02, UI-03, UI-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WH.Color.*`, `WH.Spacing.*`, `WH.Radius.*`, `WH.Font.*` — já existem, apenas actualizar valores
- `Color(hex:)` extension já existe em DesignTokens.swift — reutilizar para novos hex values
- `ZoneRingView` — componente de ring gauge já implementado; base para os 4 gauges do Home
- `HypnogramView` — stage visualization já implementada
- `.monospacedDigit()` — já usado nos cards para métricas numéricas

### Established Patterns
- Todos os valores visuais passam por `WH.*` — sem hardcoded em componentes
- Cards usam `.background(Color.black, in: RoundedRectangle(...))` — actualizar para usar token
- Preview blocks (#Preview) em cada componente — usar para comparação visual rápida
- `statColumn()` helper em SleepCard/RecoveryCard — padrão reutilizável

### Integration Points
- `DesignTokens.swift` é importado por todos os componentes via `WH.*` — actualizar aqui propaga automaticamente
- `OpenWhoopTests` já tem tests Swift (MigrationTests, MetricsCacheTests, etc.) — snapshot tests adicionados aqui
- `MetricsRepository` + `LiveViewModel` como `@EnvironmentObject` em todos os tabs — manter inalterados

</code_context>

<specifics>
## Specific Ideas

- `assetutil` está disponível em macOS Xcode toolchain — não requer instalação adicional
- Para Coaching/Health/Profile stubs: view simples com `Text("Em breve")` + header correcto — não bloquear
- O v4-ui-map.md nota que spacing/radii "not found in binary" — medir via `snapshot_ui` coordinates durante UI-04 e actualizar `WH.Spacing.*`/`WH.Radius.*` se necessário
- `sleepNeedGreen` (token para sleep need indicator) é uma cor nova não existente em DesignTokens — adicionar

</specifics>

<deferred>
## Deferred Ideas

- Implementar Coaching, Health, Profile completos — futuro milestone pós-v4.0
- Custom fonts Proxima Nova + DIN Pro — requer licença, adiar pós-v4.0
- Animações e transitions 1:1 com WHOOP — fora do scope desta fase (layout first)

</deferred>

---

*Phase: 17-UI Redesign 1:1*
*Context gathered: 2026-06-01*
