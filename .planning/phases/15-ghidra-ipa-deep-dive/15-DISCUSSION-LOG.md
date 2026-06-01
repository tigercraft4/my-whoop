# Phase 15: Ghidra IPA Deep-Dive - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-01
**Phase:** 15-Ghidra IPA Deep-Dive
**Areas discussed:** v4-ui-map.md estrutura, screens em scope, Keytel decode, BUGFIX-04 scope

---

## v4-ui-map.md — Estrutura e Granularidade

| Option | Description | Selected |
|--------|-------------|----------|
| Cores hex | Extrair hex colours para validar DesignTokens.swift WH.Color.* | ✓ |
| Espaçamentos e corner radii | Medidas de padding, margins, radii para WH.Spacing.* e WH.Radius.* | ✓ |
| Hierarquia de componentes | Layout stack: ordem dos elementos em cada card | ✓ |
| Labels e copy exactos | Confirmar/actualizar string keys (menos crítico — coberto na Fase 8) | ✓ |

| Format | Description | Selected |
|--------|-------------|----------|
| Markdown por ecrã | Uma secção por ecrã com subsecções: Hierarchy, Colors, Spacing, Labels | ✓ |
| Tabela por token | Tabela global token → valor | — |
| YAML estruturado | Máquina-legível mas sem parser no contexto | — |

**User's choice:** Todos os 4 tipos de dados, formato markdown por ecrã.
**Notes:** Foco em valores visuais (cores, espaçamentos) que o docs/whoop-ui-reference.md existente não tem.

---

## Screens em Scope — Prioridade

| Option | Description | Selected |
|--------|-------------|----------|
| Apenas screens OpenWhoop actuais | RecoveryCard, SleepCard, StrainCard, TrendsView, LiveView | — |
| Todos os ecrãs WHOOP app | Inclui Coaching, Health, Profile, Settings, onboarding | ✓ |
| Só RecoveryCard + SleepCard | Gate mínimo para Fase 17 | — |

| Order | Description | Selected |
|-------|-------------|----------|
| OpenWhoop first, WHOOP-only depois | 5 screens OpenWhoop primeiro | — |
| By tab order (Home, Sleep, Strain, Trends, Profile, ...) | Fiel à app original | ✓ |
| Recovery/Sleep first (hero screens) | Impacto visual máximo | — |

**User's choice:** Todos os ecrãs, por tab order da WHOOP app.
**Notes:** Primeiros 4 (Home→Sleep→Strain→Trends) desbloqueiam Fase 17.

---

## Keytel Coefficients — Abordagem de Decode

| Option | Description | Selected |
|--------|-------------|----------|
| Ghidra MCP agora | Ler bytes directamente do Ghidra @ 0x1058a5a80 | ✓ |
| Python decode dos bytes capturados | struct.unpack dos bytes conhecidos | — |

**User's choice:** Ghidra MCP.
**Notes:** Descoberta durante a sessão — os 8 doubles @ 0x1058a5a80 são Harris-Benedict RESTING (não Keytel workout). `calories.py` match perfeito. Os coeficientes Keytel workout estão noutro endereço.

| GHIDRA-02 next step | Description | Selected |
|----|-------------|----------|
| Encontrar Keytel workout address na Fase 15 | Localizar -55.0969 etc. via byte search | ✓ |
| Considerar GHIDRA-02 validado | Harris-Benedict suficiente | — |

---

## BUGFIX-04 — Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Passivo — anota o que surgir | Discrepâncias encontradas durante mapeamento normal | ✓ |
| Activo — procura específica | V128 offsets, campos não mapeados | — |

**User's choice:** Passivo.
**Notes:** Não é auditoria exaustiva — documentar com description + expected + actual + reproduction notes.

---

## Claude's Discretion

- Ordem exacta de commits dos ecrãs dentro de cada tab
- Quando marcar BUGFIX-04 item como "reproduction notes completas" vs "parcial"

## Deferred Ideas

- V128 offset verification via Ghidra (SpO₂, skin temp, resp) — Fase 18 GHIDRA-03
- Screens não implementados no OpenWhoop (Coaching, Health, Profile) — mapeados mas implementação é backlog
