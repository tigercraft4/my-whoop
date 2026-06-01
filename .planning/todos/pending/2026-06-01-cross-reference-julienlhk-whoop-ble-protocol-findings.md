---
created: "2026-06-01T20:38:01.042Z"
title: "Cross-reference julienlhk/whoop BLE protocol findings"
area: general
files:
  - FINDINGS_5.md
  - re/
---

## Problem

Existe um repo Python independente (`https://github.com/julienlhk/whoop`) que fez RE do WHOOP 5.0 BLE e confirmou de forma independente:
- CRC como `zlib.crc32` LE (confirma a nossa decisão 8 — Maverick CRC32)
- RMSSD/HRV calculation e packet hex capturados com testes unitários
- Acesso ao serviço custom `fd4b` e características standard

Pode haver offsets, packet structures ou edge cases no código deles que não temos documentados, especialmente para o decode de R-R intervals e RMSSD.

## Solution

1. Ler o código Python em https://github.com/julienlhk/whoop (especialmente `decode` / RR parsing)
2. Comparar com `FINDINGS_5.md` e o nosso `re/` — verificar se há offsets ou protocol details que divergem
3. Actualizar `FINDINGS_5.md` com qualquer finding novo (cross-ref: "independently confirmed by julienlhk/whoop")
4. Verificar os seus testes unitários com packet hex — são uma fonte de ground truth adicional

**Relevância:** Alta — validação independente do nosso protocolo decode é valiosa para PROTO-11/12/13.
**Timing:** Após Fase 15 (Ghidra) ou em paralelo com Fase 18 (hardware validation).
**Nota:** `shashankswe2020-ux/whoop-mcp` (WHOOP cloud API MCP) — não relevante agora (offline-first). Reconsiderar se quisermos cloud sync no futuro.
