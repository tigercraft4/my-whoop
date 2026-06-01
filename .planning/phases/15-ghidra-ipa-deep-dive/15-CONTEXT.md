# Phase 15: Ghidra IPA Deep-Dive - Context

**Gathered:** 2026-06-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Produzir dois artefactos committed que alimentam directamente a Fase 17 (UI Redesign 1:1):
1. `FINDINGS_5.md` — extendido com screen map de todos os ecrãs da WHOOP app 5.37.0
2. `docs/specs/v4-ui-map.md` — screen map completo com Hierarchy, Colors, Spacing, Labels por ecrã

Adicionalmente:
- Localizar e validar coeficientes Keytel workout no binário (GHIDRA-02)
- Documentar BUGFIX-04 (bugs encontrados passivamente durante análise)
- **Nenhum ficheiro Swift tocado nesta fase** — apenas markdown e Python se necessário

</domain>

<decisions>
## Implementation Decisions

### v4-ui-map.md — estrutura e conteúdo

- **D-01:** Formato markdown por ecrã: `## Screen: [Nome]` com 4 subsecções: `### Component Hierarchy`, `### Colors`, `### Spacing & Radii`, `### Labels`
- **D-02:** Conteúdo por ecrã:
  - **Colors**: hex colours (backgrounds, texto, accents) para validar/corrigir `WH.Color.*` em `DesignTokens.swift`
  - **Spacing & Radii**: medidas concretas de padding, margins, card corner radius para validar `WH.Spacing.*` e `WH.Radius.*`
  - **Component Hierarchy**: stack/layout order dos elementos no ecrã (ex: ring → label → stats row)
  - **Labels**: string keys e display text actuais (complementar ao `docs/whoop-ui-reference.md`)
- **D-03:** Commitar cada ecrã individualmente antes de avançar ao próximo (uma secção por commit) — padrão do ROADMAP

### Screens em scope — ordem de mapeamento

- **D-04:** Todos os ecrãs da WHOOP app (não só os que existem no OpenWhoop)
- **D-05:** Ordem por tab do WHOOP app:
  1. **Home/Overview** (RecoveryCard + gauges — hoje: TodayView)
  2. **Sleep** (SleepCard + stage breakdown — hoje: SleepView)
  3. **Strain** (StrainCard + workouts — hoje: StrainView)
  4. **Trends** (TrendsView + history)
  5. **Coaching** (CoachViewController — não existe no OpenWhoop)
  6. **Health** (HealthView — não existe no OpenWhoop)
  7. **Profile + Settings** (não existe no OpenWhoop)
- **D-06:** Os primeiros 4 (Home→Sleep→Strain→Trends) são o gate para a Fase 17 arrancar. Os restantes são mapeados a seguir sem bloquear.

### Keytel coefficients — GHIDRA-02

- **D-07:** `0x1058a5a80` contém **Harris-Benedict RESTING** coefficients (não Keytel workout) — finding desta discuss session via Ghidra MCP decode. `calories.py` matches perfeitamente — nenhuma correcção necessária nos coeficientes Harris-Benedict.
- **D-08:** Durante a Fase 15, localizar os coeficientes **Keytel workout** (-55.0969, 0.6309, 0.1988, 0.2017 men; -20.4022, 0.4472, -0.1263, 0.0740 women) em outro endereço do binário via Ghidra string/byte search. Comparar com `calories.py`. Se match → GHIDRA-02 complete. Se diferença → corrigir `calories.py`.
- **D-09:** Abordagem: `mcp__ghidra-mcp__search_byte_patterns` com os bytes LE dos coeficientes conhecidos, ou `mcp__ghidra-mcp__inspect_memory_content` na função `calculateWorkoutCalories` @ `0x10025c264`.

### BUGFIX-04 — scope

- **D-10:** Abordagem passiva — anotar discrepâncias de parsing, decode ou UI que surjam durante o mapeamento de ecrãs ou procura de coeficientes. Não é uma auditoria exaustiva. Documentar cada BUGFIX-04 item com: description, expected behavior (WHOOP app), actual behavior (OpenWhoop), reproduction notes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Inputs desta fase
- `FINDINGS_5.md` — ficheiro existente (316 linhas, BLE protocol findings); a secção de screen map vai aqui ou em ficheiro separado (preferir `docs/specs/v4-ui-map.md` para o UI map)
- `docs/whoop-ui-reference.md` — já tem tab structure, string keys, field labels da Fase 8; **não duplicar**, apenas complementar
- `.planning/notes/ghidra-ios-algorithm-findings.md` — findings da análise de algoritmos (calorias, sleep, etc.)
- `.planning/notes/ghidra-ios-phases-scope.md` — scope RE por fase

### Ghidra / IPA
- Binary: `/tmp/whoop_ipa_deep/Payload/Whoop.app/Whoop` — AARCH64:LE:64, image base `0x100000000`, 477,055 funções
- IPA: `APPS IOS APK/com.whoop.iphone_5.37.0_und3fined.ipa`
- Ghidra project: `APPS IOS APK/whoop.gpr` (já analisado, MCP conectado)
- `calculateWorkoutCalories` @ `0x10025c264` — função calorie workout; coeficientes Keytel são referenciados aqui
- Harris-Benedict constants @ `0x1058a5a80` (64 bytes, 8 doubles LE) — CONFIRMADOS match `calories.py`

### Outputs desta fase (a criar)
- `docs/specs/v4-ui-map.md` — screen map completo (criar nesta fase)
- `FINDINGS_5.md` — pode ser extendido com findings adicionais de protocolo se encontrados
- `.planning/notes/bugfix-04-findings.md` — documentar BUGFIX-04 passivamente

### Algoritmos
- `server/ingest/app/analysis/calories.py` — `_COEFFS` Harris-Benedict + Keytel; `_MIFFLIN_COEFFS` para RMR ALG-AR** coeficientes Keytel workout contra Ghidra durante esta fase
- `ios/OpenWhoop/Metrics/LocalMetricsComputer.swift` — implementação iOS dos algoritmos; validar se coeficientes Keytel são iguais aos da binary

### Requirements
- `.planning/REQUIREMENTS.md` §Ghidra IPA Analysis — GHIDRA-01, GHIDRA-02, BUGFIX-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mcp__ghidra-mcp__*` tools disponíveis e conectados ao Whoop binary — usar directamente durante planning/execution
- `mcp__ghidra-mcp__search_strings` — para encontrar UI string constants por tab/screen name
- `mcp__ghidra-mcp__search_byte_patterns` — para localizar Keytel coefficients por byte pattern
- `mcp__ghidra-mcp__decompile_function` — para analisar funções de UI e parsing
- `mcp__ghidra-mcp__read_memory` — para ler constants/arrays de coeficientes

### Established Patterns
- `docs/whoop-ui-reference.md` estabeleceu o padrão de documentação: tabelas com `String Key | Display Label | Notes`
- `FINDINGS_5.md` usa formato markdown com headers, tabelas de status, e secções por domínio
- Clean-room obrigatório: extrair apenas estrutura e dados (nomes, valores, layouts) — nunca pseudocódigo ou assets

### Integration Points
- `docs/specs/v4-ui-map.md` feed directo para `DesignTokens.swift` (Fase 17 UI-01) e componentes Swift (UI-02)
- Harris-Benedict @ `0x1058a5a80` já confirmado → Keytel workout precisa de verificação separada
- `ios/OpenWhoop/Metrics/LocalMetricsComputer.swift` implementa Keytel localmente — comparar com Ghidra

</code_context>

<specifics>
## Specific Ideas

- **Harris-Benedict finding desta sessão**: `0x1058a5a80` contém [13.397, 479.9, -5.677, 88.362, 9.247, 309.8, -4.330, 447.593] — todos matches do `calories.py`. Este finding deve ser commitado em `FINDINGS_5.md` como "GHIDRA-HB-01 CONFIRMED".
- **Keytel procura**: começar por `0x10025c264` (endereço de `calculateWorkoutCalories`), decompile, e procurar referências a data constants com os valores conhecidos (−55.0969 → hex pattern na memória).
- O `docs/whoop-ui-reference.md` existente cobre bem os **labels de texto** — o `v4-ui-map.md` deve focar em **valores visuais** (cores, espaçamentos) que o `whoop-ui-reference.md` não tem.

</specifics>

<deferred>
## Deferred Ideas

- V128 offset verification (SpO₂, skin temp, respiration) — Fase 18 GHIDRA-03 (hardware-gated)
- Verificação de `.so` nativas no APK Android — Fase 999.1 (hardware-gated)
- Screens não implementados no OpenWhoop (Coaching, Health, Profile) — mapeados na Fase 15 mas implementação é backlog/futuro

</deferred>

---

*Phase: 15-Ghidra IPA Deep-Dive*
*Context gathered: 2026-06-01*
