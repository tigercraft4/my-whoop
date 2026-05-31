# Phase 8: JADX APK Analysis + UI Design Document - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Usar JADX no APK oficial do WHOOP Android para documentar a arquitectura de informação da app — o que cada ecrã mostra, labels de campos, hierarquia de sub-ecrãs — e produzir `docs/whoop-ui-reference.md` como referência para o redesign SwiftUI da Phase 9.

**Entry condition:** Independente — corre em paralelo com Phase 6. Não depende de dados reais do WHOOP.

**Deliverables:**
1. APK descarregado via APKMirror (versão mais recente), ficheiros em `re/capture/samples/apk/` (gitignored)
2. `docs/whoop-ui-reference.md` — documento UI com:
   - Labels de campos visíveis (strings.xml)
   - Hierarquia de ecrãs (layout XMLs → Activity/Fragment tree por tab)
   - Tabela de mapping campo → modelo (`DailyMetric`/`CachedSleepSession`/`ALG-*`) — **obrigatório per ROADMAP success criterion 3**
3. Todas as 5 tabs documentadas em profundidade

**Out of scope:** Decompiled source code, imagens, assets, ícones WHOOP — absolutamente proibido (DISCLAIMER §2). Phase 9 implementa o SwiftUI a partir da referência; Phase 8 só documenta.

</domain>

<decisions>
## Implementation Decisions

### APK source

- **D-01:** **APKMirror fallback — sem dispositivo Android disponível.** Descarregar versão mais recente do WHOOP Android em APKMirror.com. As mesmas regras legais do TOOL-03 runbook aplicam-se: APK gitignored em `re/capture/samples/apk/`, nunca commitado.

- **D-02:** **Versão mais recente disponível no APKMirror.** Usar o `base.apk` da versão mais recente (compatível com WHOOP 5.0 hardware). Nota: registar a versão descarregada no `docs/whoop-ui-reference.md` para rastreabilidade.

### Documento UI

- **D-03:** **Um único ficheiro `docs/whoop-ui-reference.md`** com secções por tab. Fácil de referenciar em `<canonical_refs>` da Phase 9 CONTEXT.md.

- **D-04:** **Conteúdo obrigatório por secção de tab:**
  1. Labels de campos visíveis (texto exacto da UI, fonte: strings.xml)
  2. Hierarquia de sub-ecrãs (que screens/sheets existem por tab, fonte: layout XMLs)
  3. Tabela mapping campo UI → modelo de dados (DailyMetric/CachedSleepSession/ALG-* requirement) — **obrigatório per ROADMAP success criterion 3**
  - Unidades e formatos de valores: ao critério do planeador, incluir quando relevante para Phase 9

- **D-05:** **Scope: todas as 5 tabs do WHOOP** documentadas em profundidade (Overview/Today, Sleep, Strain/Workouts, Trends, e 5ª tab — Coach/Plus/Device conforme o que o APK mostrar). A 5ª tab ao critério do planeador: documentar o que for acessível sem features premium; não bloquear Phase 8 por acesso limitado.

### Método de extracção JADX

- **D-06:** **Três fontes JADX, por ordem de prioridade:**
  1. **`res/values/strings.xml`** — todos os labels de campos em texto (pesquisar "recovery", "hrv", "strain", "sleep", "spo2", "temperature", "respiration"); fonte primária para labels exactos
  2. **`res/layout/*.xml`** — hierarquia de componentes UI por Activity/Fragment; mapeamento ecrã → widget IDs → string resource refs
  3. **ViewModel/data source classes** (Kotlin/Java decompilado) — nomes de propriedades e tipos de dados para o mapping campo → modelo; **ler apenas para extrair nomes de campos, NÃO registar lógica ou algoritmos**

- **D-07:** **Regra legal estrita (D-04 do PROJECT.md / DISCLAIMER §2):**
  - ✅ Permitido: labels de campos (strings.xml — texto factual), nomes de Activities/Fragments, widget IDs (sem lógica), nomes de propriedades de ViewModel (names only)
  - ❌ Proibido: method bodies, constructor code, algoritmos, string literals de lógica de negócio, qualquer coisa além de nomes e valores enum

### Claude's Discretion

- Estrutura exacta das secções por tab no `whoop-ui-reference.md`
- Tratamento da 5ª tab se for Coach/Plus (feature paga) — documentar o que for visível sem subscription
- Unidades e formatos de valores (ex: Recovery = 0–100 int, Strain = 0.0–21.0 1dp)
- Versão exacta do APK a usar (mais recente disponível no APKMirror)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Legal e ferramentas

- `re/capture/jadx.md` — TOOL-03 runbook completo: setup JADX, adb pull, APKMirror fallback, regras de recording, JRE troubleshooting. **MUST READ antes de planear passos de execução.**
- `DISCLAIMER.md §2` — regra legal: sem source code, sem APKs commitados, sem assets. Enum names + field names são factual information.

### Requirements desta fase

- `.planning/REQUIREMENTS.md` — UI-01 (com critérios de aceitação exactos e regra D-04)
- `.planning/ROADMAP.md` §"Phase 8" — 3 success criteria, incluindo a tabela de mapping obrigatória

### Output desta fase (alimenta a Phase 9)

- `docs/whoop-ui-reference.md` — output a criar; Phase 9 vai referenciar este ficheiro em canonical_refs
- `docs/plans/2026-05-27-app-ux-plan.md` — plano UX anterior da app; verificar inconsistências com o que o JADX revelar

### Modelo de dados (para o mapping campo → modelo)

- `ios/OpenWhoop/Metrics/MetricsRepository.swift` — campos disponíveis em `DailyMetric` e `CachedSleepSession`; a tabela de mapping referencia estes nomes de propriedade exactos
- `.planning/REQUIREMENTS.md` §"Algoritmos" — ALG-01/02/03 requirement IDs para o mapping quando o campo depende de computação server-side

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `re/capture/jadx.md` runbook — APKMirror fallback completamente documentado; reutilizar os passos directamente
- `re/capture/samples/apk/` — directório gitignored já configurado para os APK files
- `docs/plans/` e `docs/specs/` — padrão de organização de documentação existente; `whoop-ui-reference.md` vai directamente para `docs/`

### Established Patterns

- **Gitignore para APK:** `re/capture/samples/` já é gitignored — APK files nunca expostos ao repo
- **Legal recording rule (D-04):** strings.xml e field names são factual; JADX GUI permite navegar a tree sem exportar source

### Integration Points

- `docs/whoop-ui-reference.md` → referenciado em CONTEXT.md da Phase 9 como canonical ref
- Tabela mapping campo → modelo → validada contra `MetricsRepository.swift` para confirmar que os campos existem

</code_context>

<specifics>
## Specific Ideas

- **strings.xml grep approach:** Após descomprimir o APK (`unzip base.apk -d whoop_extracted/`), pesquisar directamente: `grep -r "Recovery\|Strain\|HRV\|Sleep\|Respiratory\|SpO2\|Temperature" whoop_extracted/res/values/strings.xml`. Mais rápido que navegar o JADX GUI para labels.
- **Layout XML tree:** JADX GUI tem "Resources" panel que mostra `res/layout/` — navegar por Activity name (procurar "Overview", "Dashboard", "Sleep", "Strain") para mapear hierarchy.
- **Registar a versão:** Incluir no header do `whoop-ui-reference.md` a versão exacta do APK analisado (ex: `WHOOP 9.32.0.0` ou similar) para rastreabilidade futura.

</specifics>

<deferred>
## Deferred Ideas

- Análise de algoritmos ou lógica de negócio do APK — fora do âmbito legal e técnico desta fase
- Comparação entre WHOOP 4.0 e 5.0 UI — se o APK analisado suportar ambos, registar diferenças seria interessante mas não é um deliverable desta fase

</deferred>

---

*Phase: 08-jadx-apk-analysis-ui-design-document*
*Context gathered: 2026-05-31*
