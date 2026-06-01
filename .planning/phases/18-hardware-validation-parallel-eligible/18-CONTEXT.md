# Phase 18: Hardware Validation (parallel-eligible) - Context

**Gathered:** 2026-06-01
**Status:** Hardware-deferred — runbook ready, hardware not available at v4.0 ship time
**Ship gate:** This phase does NOT gate v4.0 ship (by design — see ROADMAP)

<domain>
## Phase Boundary

Confirmar SpO₂, skin temperature e respiration rate contra ground-truth via TOGGLE_IMU_MODE capture e promover os 3 itens de HYPOTHESIS → VERIFIED. Paralela-elegível — pode correr em paralelo com qualquer fase desde que tenha hardware disponível.

**DEFERRED:** Executar quando iPhone + WHOOP 5.0 + PacketLogger estiverem disponíveis numa sessão dedicada.

</domain>

<decisions>
## Implementation Decisions

### Hardware required

- **D-01:** Requer: iPhone físico com PacketLogger activado, WHOOP 5.0 conectado via app OpenWhoop, e instrumentos de ground truth (oxímetro para SpO₂, termómetro para skin temp).
- **D-02:** Não executar parcialmente — fazer os 3 PROTOs (11/12/13) na mesma sessão de hardware para eficiência.

### GHIDRA-03 — Offsets V128 (pode ser feito sem hardware)

- **D-03:** GHIDRA-03 (confirmar offsets V128 para SpO₂/skin temp/respiration via Ghidra) pode ser executado a qualquer momento usando Ghidra MCP (já conectado ao binary Whoop 5.37.0). Não requer hardware.
- **D-04:** Endereços a pesquisar no Ghidra: funções de decode de type-47 V128 para SpO₂, skin temp e respiration. Comparar offsets encontrados com os offsets actuais no `Packages/WhoopProtocol`.

### PROTO-11 — SpO₂

- **D-05:** Sessão: abrir PacketLogger no iPhone, conectar WHOOP 5.0 via OpenWhoop, activar TOGGLE_IMU_MODE (cmd 0x07). Capturar frames type-47 com dados biométricos durante ~5 min.
- **D-06:** Ground truth: oxímetro de pulso comercial (ex: Fingertip Pulse Oximeter). Comparar valor decoded com leitura do oxímetro ao mesmo tempo.
- **D-07:** Critério VERIFIED: SpO₂ decoded dentro de ±2% do oxímetro durante 5 medições consecutivas. Actualizar schema de HYPOTHESIS → VERIFIED.

### PROTO-12 — Skin Temperature

- **D-08:** Mesmo setup que PROTO-11. Decoded value em graus C (skin temp deviation from baseline).
- **D-09:** Ground truth: termómetro de contacto / IR. Comparar temperatura decoded com leitura do termómetro.
- **D-10:** Critério VERIFIED: skin temp deviation plausível (±0.5°C do esperado para condições ambiente). Actualizar schema HYPOTHESIS → VERIFIED.

### PROTO-13 — Respiration Rate

- **D-11:** Mesmo setup. Decoded value em rpm.
- **D-12:** Ground truth: contar respirações manualmente durante 1 min (ou usar oxímetro com SpO₂/resp rate). Critério VERIFIED: 12–20 rpm com desvio ≤ 2 rpm.
- **D-13:** Actualizar schema HYPOTHESIS → VERIFIED.

</decisions>

<canonical_refs>
## Canonical References

- `Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` — schema decoder; offsets V128 actuais
- `ios/OpenWhoop/BLE/Commands.swift` — TOGGLE_IMU_MODE marcado HYPOTHESIS
- `FINDINGS_5.md` §8 — biometric stream findings
- `docs/specs/v4-ui-map.md` — não relevante para esta fase
- `.planning/REQUIREMENTS.md` §Hardware Validation — PROTO-11, PROTO-12, PROTO-13, GHIDRA-03

</canonical_refs>

<code_context>
## Existing Code Insights

- `TOGGLE_IMU_MODE` (cmd 0x07) em `Commands.swift` — marcado HYPOTHESIS; activar durante a sessão de captura
- `spo2Sample`, `skinTempSample`, `respSample` tables em GRDB — já existem para armazenar os valores
- `DailyMetric.spo2Pct`, `.skinTempDevC`, `.respRateBpm` — campos nullable já no schema v7

</code_context>

<deferred>
## Deferred — Hardware Not Available at v4.0 Ship

Esta fase foi explicitamente desenhada como não-gate do v4.0. Adicionada ao backlog 999.2 (Hardware validation). Executar quando houver:
- iPhone + WHOOP 5.0 com dados frescos
- PacketLogger disponível
- Sessão dedicada de ~30 min
- Oxímetro + termómetro disponíveis

</deferred>

---

*Phase: 18-Hardware Validation (parallel-eligible)*
*Context gathered: 2026-06-01 — hardware-deferred, not executed at v4.0 ship*
