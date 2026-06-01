# Phase 17: UI Redesign 1:1 - Discussion Log

> **Audit trail only.** Decisions are in CONTEXT.md.

**Date:** 2026-06-01
**Phase:** 17-UI Redesign 1:1
**Areas discussed:** Tipografia, Cores hex, Snapshot testing, Ordem dos ecrãs

---

## Tipografia — Proxima Nova + DIN Pro vs SF Pro

| Option | Selected |
|--------|----------|
| Embeddar Proxima Nova + DIN Pro | — |
| System fonts que aproximam | ✓ |

**Notes:** Licenças de fontes pagas evitadas. SF Pro ≈ Proxima Nova; `.monospacedDigit()` ≈ DIN Pro.

---

## Cores hex — Como Obter Valores Reais

| Option | Selected |
|--------|----------|
| Extrair do IPA Assets.car (assetutil) | ✓ |
| Screenshots da app oficial | — |
| Usar DesignTokens.swift atual | — |

**Notes:** IPA está em re/ghidra/ após reorganização da Fase 16. assetutil disponível no Xcode toolchain.

---

## Snapshot Testing — Setup

| Option | Selected |
|--------|----------|
| SPM via project.yml + OpenWhoopTests | ✓ |
| Target dedicado SnapshotTests | — |

| Timing | Selected |
|--------|----------|
| Incremental (após cada ecrã) | ✓ |
| No final de todos | — |

**Notes:** Versão 1.17.6 exacta conforme ROADMAP requirement UI-03.

---

## Ordem dos Ecrãs

| Option | Selected |
|--------|----------|
| Recovery → Sleep → Strain → Trends → Live | — |
| Todos por tab order WHOOP | ✓ |

**Notes:** Home → Sleep → Strain → Trends → Coaching (stub) → Health (stub) → Profile (stub).

---

## Claude's Discretion

- Quais tokens de DesignTokens.swift actualizar vs. manter (baseado em diff do assetutil)
- Dimensões exatas de spacing medidas via snapshot_ui para actualizar WH.Spacing.*

## Deferred Ideas

- Custom fonts (Proxima Nova + DIN Pro) — pós-v4.0, requer licença
- Coaching, Health, Profile implementação completa — futuro milestone
- Animações e transitions 1:1 — layout first nesta fase
