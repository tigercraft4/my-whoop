# Phase 9: SwiftUI Redesign WHOOP-Style - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Redesenhar a UI iOS em WHOOP-style: nova tab bar com 5 tabs, Recovery card com anel de cor, Sleep card com stacked bar de fases, Strain card com anel 0–21 + lista de workouts. Todos os cards alimentados por dados reais de DailyMetric/CachedSleepSession da Phase 7.

**Entry condition:** Phase 7 (dados reais em store) + Phase 8 (docs/whoop-ui-reference.md disponível como referência de UI).

**Deliverables:**
1. `RootTabView` com 5 tabs em ordem ROADMAP: Today / Sleep / Strain / Trends / Device + `@SceneStorage` para persistência
2. `RecoveryCard` em TodayView — anel circular, score 0–100, zonas verde/amarelo/vermelho, HRV + RHR + sleep performance
3. `SleepCard` em SleepView — stacked bar HypnogramView, duração, eficiência — dados reais
4. `StrainCard` em StrainView — anel 0–21 (mesmo componente do RecoveryCard parametrizado), HR zones breakdown, lista de workouts abaixo
5. IOS-05: SpO₂ e skinTemp chart series adicionadas ao TrendsView (deferido de Phase 7)
6. `WH.Color` atualizado com cores de zonas WHOOP em `DesignTokens.swift`

**Out of scope:** Algoritmos de Recovery/Strain/Sleep (→ Phase 10), HealthKit (→ Phase 11), UI de Device/Settings tab.

</domain>

<decisions>
## Implementation Decisions

### Tab bar

- **D-01:** **Ordem das 5 tabs: Today / Sleep / Strain / Trends / Device** — segue o ROADMAP Phase 9 success criterion. Ícones sugeridos: `house`, `bed.double`, `bolt.heart`, `chart.xyaxis.line`, `wave.3.right` (planeador pode ajustar ícones com base no docs/whoop-ui-reference.md).

- **D-02:** **`@SceneStorage("selectedTab")` para persistência de tab** — adicionar ao `RootTabView`. `TabView(selection:)` com binding a `@SceneStorage`. String tag por tab (ex: `"today"`, `"sleep"`, `"strain"`, `"trends"`, `"device"`).

- **D-03:** **WorkoutsView existente: reutilizada dentro do StrainView** — ao critério do planeador. A tab "Workouts" é renomeada para "Strain"; o StrainCard fica no topo, e a lista de workouts existente pode ser mantida abaixo em ScrollView (ver D-08).

### Recovery card

- **D-04:** **Anel visual ao critério do planeador** — Canvas arc custom Shape OU SwiftUI Gauge. Planeador escolhe a implementação mais limpa que suporte o estilo WHOOP. Deve ser parametrizável para reutilização no StrainCard.

- **D-05:** **Thresholds de cor para Recovery (locked):**
  - `0–33` → `WH.Color.recoveryRed`
  - `34–66` → `WH.Color.recoveryYellow`
  - `67–100` → `WH.Color.recoveryGreen`

- **D-06:** **Campos do RecoveryCard (UI-03):** score 0–100, HRV RMSSD, RHR, sleep performance — todos de `DailyMetric`. Se `DailyMetric.recovery == nil`, mostrar placeholder `"—"` (não 0 nem texto de erro).

### Sleep card

- **D-07:** **HypnogramView existente é reutilizada** — `SleepCard` usa `HypnogramView` para a stacked bar de fases (REM/Deep/Light/Awake). A lógica de `stagesJSON` decode já existe. SleepView atualizada para mostrar os dados reais de `CachedSleepSession` (se disponíveis da Phase 7).

### Strain card e Strain tab

- **D-08:** **StrainView: StrainCard no topo + lista de workouts abaixo** — Tab "Strain" mostra:
  1. `StrainCard` no topo (score 0–21, gauge/anel, HR zones breakdown)
  2. `ScrollView` com lista de workout sessions (reutiliza lógica do WorkoutsView existente)

- **D-09:** **Gauge do StrainCard: anel circular** — mesmo componente parametrizado do RecoveryCard (cor única — azul ou cor distinta do Recovery, ao critério do planeador). Range 0–21 com 1 decimal.

### TrendsView — IOS-05 (deferido de Phase 7)

- **D-10:** **Adicionar SpO₂ e skinTemp ao TrendsView nesta fase** — IOS-05 foi deferido de Phase 7 para Phase 9. Adicionar casos `.spo2` e `.skinTemp` a `MetricKind` e incluí-los em `MetricKind.dailyCases`. Mostrar com placeholder `"—"` se os dados não existirem (streams HYPOTHESIS não verificados).

### Paleta WHOOP-style

- **D-11:** **Adicionar cores WHOOP ao `WH.Color` em `DesignTokens.swift`:**
  - `WH.Color.recoveryGreen` — `#34C759` (Apple green) ou cor do WHOOP reference doc
  - `WH.Color.recoveryYellow` — `#FFD60A` (Apple yellow) ou referência JADX
  - `WH.Color.recoveryRed` — `#FF3B30` (Apple red) ou referência JADX
  - `WH.Color.strainAccent` — azul ou cor distinta para o Strain gauge (ao critério do planeador com base no JADX reference)
  - Exact hex codes: ao critério do planeador após consultar `docs/whoop-ui-reference.md` da Phase 8

- **D-12:** **Fundo preto puro apenas nos novos cards WHOOP-style** — `RecoveryCard`, `SleepCard`, `StrainCard` usam `.background(Color.black)`. Settings/Device mantêm `.background` do sistema. Contraste explícito entre áreas redesenhadas e existentes.

### Claude's Discretion

- Implementação exacta do anel (Canvas Shape vs SwiftUI Gauge)
- Cor exacta do `WH.Color.strainAccent` (azul? laranja? baseado no JADX reference)
- Hex codes exactos das cores WHOOP (confirmar com docs/whoop-ui-reference.md)
- Ícones exactos das tabs (confirmar com JADX reference)
- Se WorkoutsView é reutilizada como-está ou wrappada numa composição nova

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Referência UI WHOOP (output da Phase 8 — ler antes de definir cores/labels/estrutura)

- `docs/whoop-ui-reference.md` — documento UI da Phase 8 com labels, hierarquia, e mapping campo → modelo. **MUST READ antes de implementar qualquer card. Pode não existir ainda — se não existir, usar os valores decididos neste CONTEXT.md como fallback.**

### Requirements desta fase

- `.planning/REQUIREMENTS.md` — UI-02, UI-03, UI-04, UI-05 (com critérios exactos)
- `.planning/ROADMAP.md` §"Phase 9" — 4 success criteria (tab bar, Recovery card, Sleep card, Strain card)

### Código iOS relevante

- `ios/OpenWhoop/App/RootTabView.swift` — ponto de entrada; adicionar `@SceneStorage` e mudar tab order
- `ios/OpenWhoop/Tabs/TodayView.swift` — adicionar RecoveryCard
- `ios/OpenWhoop/Tabs/SleepView.swift` — atualizar para SleepCard com dados reais
- `ios/OpenWhoop/Tabs/WorkoutsView.swift` — reutilizar/renomear para StrainView
- `ios/OpenWhoop/Tabs/TrendsView.swift` — adicionar SpO₂ e skinTemp (IOS-05 deferido de Phase 7)
- `ios/OpenWhoop/Charts/MetricKind.swift` — adicionar `.spo2` e `.skinTemp` cases + atualizar `dailyCases`
- `ios/OpenWhoop/Design/DesignTokens.swift` — adicionar `WH.Color.recoveryGreen/Yellow/Red` e `WH.Color.strainAccent`
- `ios/OpenWhoop/Tabs/HypnogramView.swift` — reutilizar para Sleep card stacked bar

### Context das phases anteriores

- `.planning/phases/07-ios-validation-biometrics-capture/07-CONTEXT.md` — decisão IOS-05 deferida (D-07)
- `.planning/phases/08-jadx-apk-analysis-ui-design-document/08-CONTEXT.md` — estrutura JADX e output

### Anti-pattern a evitar (regra do universal-anti-patterns.md #28)

- **NÃO usar SPM executable targets para iOS** — XcodeGen + project.yml é o build system correcto
- **SwiftUI API availability:** `@SceneStorage` é iOS 14+ (OK); verificar se outros APIs usados são iOS 16+

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `HypnogramView` — stacked bar de fases de sono já implementada; reutilizar directamente em SleepCard
- `WorkoutsView` / `WorkoutDetailView` — lógica de lista de workout sessions; reutilizar abaixo do StrainCard
- `MetricKind` + `TrendChartCard` — padrão de chart por métrica; adicionar `.spo2` e `.skinTemp` seguindo o mesmo padrão
- `WH.Color` / `WH.Font` / `WH.Spacing` namespace em `DesignTokens.swift` — extensão directa sem refactor

### Established Patterns

- **TabView sem `@SceneStorage`:** actualmente `RootTabView` não tem selection state — adicionar `@SceneStorage("selectedTab") private var selectedTab = "today"` + `TabView(selection: $selectedTab)`
- **`@EnvironmentObject var metrics: MetricsRepository`:** todos os views observam `metrics` — RecoveryCard/SleepCard/StrainCard seguem este padrão
- **Placeholder `"—"` para nil:** padrão estabelecido em DayDetailView e SleepView para dados ausentes — continuar o mesmo
- **`#if DEBUG` wrapper:** padrão a usar para o botão IMU na SettingsView (Phase 7); aplicar o mesmo para qualquer element debug na Phase 9

### Integration Points

- `RootTabView` → novo tab order + `@SceneStorage`
- `TodayView` → incorporar `RecoveryCard` (componente novo)
- `SleepView` → incorporar `SleepCard` com `HypnogramView`
- `WorkoutsView` → renomear/wrappar como `StrainView` com `StrainCard` no topo
- `MetricKind.dailyCases` → adicionar `.spo2`, `.skinTemp` (IOS-05)
- `DesignTokens.swift` → adicionar cores de zonas WHOOP

</code_context>

<specifics>
## Specific Ideas

- **Ring component parametrizado:** `ZoneRingView(value: Double, maxValue: Double, color: Color)` — usado por RecoveryCard (0–100, color by zone) e StrainCard (0–21, strainAccent). Evita duplicação de código.
- **Tab tags como enum ou constantes:** `TabTag.today`, `.sleep`, `.strain`, `.trends`, `.device` — evita magic strings no `@SceneStorage` binding.
- **docs/whoop-ui-reference.md dependência:** se a Phase 8 não estiver completa quando a Phase 9 começar, usar os valores deste CONTEXT.md como fallback. Não bloquear Phase 9 por Phase 8.

</specifics>

<deferred>
## Deferred Ideas

- Algoritmos Recovery/Strain/Sleep server-side integrados nas views → Phase 10
- HealthKit export → Phase 11
- Redesign de Device/Settings tab em WHOOP-style → fora do âmbito do v2.0
- Animações de entrada dos cards (ex: anel animado ao carregar) → pós v2.0

</deferred>

---

*Phase: 09-swiftui-redesign-whoop-style*
*Context gathered: 2026-05-31*
