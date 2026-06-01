# Phase 8: JADX APK Analysis + UI Design Document - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-31
**Phase:** 08-jadx-apk-analysis-ui-design-document
**Areas discussed:** APK source, Formato do documento UI, Método JADX, Scope das tabs

---

## APK source

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, tenho Android com WHOOP | Usar adb pull (método preferido) | |
| Não, usar APKMirror | Fazer download em APKMirror.com | ✓ |

**User's choice:** APKMirror — sem dispositivo Android disponível

| Option | Description | Selected |
|--------|-------------|----------|
| Versão mais recente disponível | Usar a versão mais recente do WHOOP Android | ✓ |
| Versão que conhece o firmware WHOOP 5.0 | Matching com firmware do strap | |
| Claude decide | Planeador escolhe | |

**User's choice:** Versão mais recente disponível no APKMirror

---

## Formato do documento UI

| Option | Description | Selected |
|--------|-------------|----------|
| Um ficheiro docs/whoop-ui-reference.md | Único documento com secções por tab | ✓ |
| Um ficheiro por tab (docs/ui/today.md, ...) | Mais granular, mais ficheiros | |

**User's choice:** Um ficheiro `docs/whoop-ui-reference.md`

| Option | Description | Selected |
|--------|-------------|----------|
| Labels de campos visíveis | Textos exactos da UI (strings.xml) | ✓ |
| Hierarquia de ecrãs | Sub-ecrãs que existem por tab | ✓ |
| Mapping campo → modelo de dados | Campo UI → DailyMetric property | |
| Unidades e formato dos valores | strain = 0–21, recovery = 0–100 int | |

**User's choice:** Labels + hierarquia de ecrãs
**Notes:** Mapping campo → modelo incluído de qualquer forma pois é success criterion 3 obrigatório do ROADMAP. Unidades ao critério do planeador.

---

## Método JADX para UI

| Option | Description | Selected |
|--------|-------------|----------|
| strings.xml | Resource file com todos os textos visíveis | ✓ |
| Layout XMLs / res/layout/ | Hierarquia de componentes UI por ecrã | ✓ |
| ViewModel / data source classes | Campos de dados, nomes de propriedades | ✓ |

**User's choice:** Todas as 3 fontes

---

## Scope das tabs

| Option | Description | Selected |
|--------|-------------|----------|
| Todas as 5 tabs WHOOP que existem | Overview, Sleep, Strain, Trends, Coach/Device | ✓ |
| Apenas as 3 tabs principais com cards | Overview, Sleep, Strain | |
| Claude decide | Planeador decide com base no ROADMAP | |

**User's choice:** Todas as 5 tabs documentadas em profundidade

| Option | Description | Selected |
|--------|-------------|----------|
| Coach/Plus — documentar best-effort | Se paga, documentar o que for visível | |
| Device/Settings tab — é a 5ª tab | Equivalente WHOOP da nossa Device tab | |
| Claude decide | Planeador trata conforme o APK | ✓ |

**User's choice:** Claude decide — 5ª tab tratada pelo planeador conforme o que encontrar

---

## Claude's Discretion

- Estrutura exacta das secções por tab no `whoop-ui-reference.md`
- Tratamento da 5ª tab (Coach/Plus se feature paga)
- Unidades e formatos de valores
- Versão exacta do APK a usar

## Deferred Ideas

- Análise de algoritmos ou lógica de negócio do APK — fora do âmbito legal
- Comparação WHOOP 4.0 vs 5.0 UI — interessante mas não é deliverable desta fase
