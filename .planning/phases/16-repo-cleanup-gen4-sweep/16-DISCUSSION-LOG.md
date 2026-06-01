# Phase 16: Repo Cleanup + Gen4 Sweep - Discussion Log

> **Audit trail only.** Decisions are in CONTEXT.md.

**Date:** 2026-06-01
**Phase:** 16-Repo Cleanup + Gen4 Sweep
**Areas discussed:** CLEAN-01 reorganização, CLEAN-02 Gen4 sweep, CLEAN-03 device_generation

---

## CLEAN-01 — Reorganização de Pastas

| Option | Selected |
|--------|----------|
| Mover para pastas lógicas | ✓ |
| Só anotar com README | — |
| Mover apenas o óbvio | — |

| Packages/ | Selected |
|-----------|----------|
| Manter na raiz | — |
| Mover para ios/Packages/ | ✓ |

**Notes:** Packages/ para ios/Packages/ é o move mais arriscado — fazer por último com gate dedicado.

---

## CLEAN-02 — Gen4 Sweep

| Option | Selected |
|--------|----------|
| Anotar claramente + sem remoção | — |
| Remover referências Gen4 | — |
| Ficheiros separados por função | ✓ |

| Separação | Selected |
|-----------|----------|
| BLEManager+BackfillChannel.swift | ✓ |
| BLEManager+Gen4 + BLEManager+Gen5 | — |

**User input:** "fazer partes específicas gen4 e outras gen5 o melhor penso que seja ficheiros separados"
**Notes:** gen4Service (61080001) é backfill do WHOOP 5.0 — não verdadeiramente "Gen4". Renomear para backfillService/backfillDataChar é mais preciso.

---

## CLEAN-03 — device_generation Detection

| Option | Selected |
|--------|----------|
| Campo device_generation no modelo Device | ✓ |
| Só annotation/comment | — |
| Detecção implícita já existe | — |

**Notes:** Inferir via hardware revision WG50 → gen5. Stub de routing — path Gen4 completo é backlog 999.1.

---

## Claude's Discretion

- Ordem exacta dos moves (mais simples primeiro, Packages/ por último)
- Quais testes de WhoopProtocol contam como "Gen4 dead code" vs "documentação legítima"

## Deferred Ideas

- Implementação completa do path Gen4 end-to-end — backlog 999.1
- Limpeza de re/ scripts ad-hoc — paralelo com Fase 17
