# Spike Manifest — WHOOP 5.0 Clone

**Overall idea:** Clone 1:1 da app WHOOP 5.37.0 — UI idêntica, algoritmos exactos, protocolo BLE completo, comunicação com servidores WHOOP adaptada para servidor Docker local.

**Source binary:** `APPS IOS APK/com.whoop.iphone_5.37.0_und3fined.ipa` (WHOOP iOS 5.37.0, ARM64)
**Analysis tool:** Ghidra MCP v5.12.0 (196 tools, 151,393 functions analyzed)

---

## Requirements

1. UI layout idêntica ao WHOOP — tabs, cards, campos, labels, ordem, unidades
2. Algoritmos de backend exactos — Recovery, Sleep Performance, Strain, Calorias, Training State
3. Protocolo BLE 1:1 — todos os comandos, payloads, sequências
4. Haptics correctos — WaveformEffect DRV2605 ou patternId correcto para WHOOP 5.0
5. API endpoints documentados — o que a app WHOOP envia para os servidores WHOOP
6. Adaptação do servidor Docker local para receber os mesmos payloads

---

## Spike Table

| # | Spike | Status | Verdict |
|---|-------|--------|---------|
| 1 | UI Layout completo via Ghidra | 🔄 In Progress | - |
| 2 | Algoritmos exactos via Ghidra | ✅ Partial | Recovery zones, RMR, Calories confirmados |
| 3 | API endpoints WHOOP servers | 🔄 In Progress | - |
| 4 | Haptics DRV2605 payload | 🔄 In Progress | - |
| 5 | BLE command surface completa | ✅ Partial | r52 enum map confirmado; cmd 19=Maverick haptic |

---

## Already Confirmed (from IPA analysis + Ghidra)

### Algoritmos
| Métrica | Fórmula | Fonte | Confiança |
|---------|---------|-------|-----------|
| Recovery zones | 0–33 red, 33–66 yellow, 66–100 green | `WHPColorMapper::recoveryColorForRecoveryScore_` @ 10004fb40 | HIGH |
| Male RMR | 13.397*kg + 479.9*m + (-5.677)*age + 88.362 kcal/day | `FUN_10025be58` @ 10025be58, constants @ 1058a5a80-a98 | HIGH |
| Female RMR | 9.247*kg + 309.8*m + (-4.330)*age + 447.593 kcal/day | Same function, constants @ 1058a5aa0-ab8 | HIGH |
| Male workout cal | (0.07*age + 0.40*HR - 0.13*weight - 15) / 4.184 kcal/min | `FUN_10025c264` @ 10025c264 | HIGH |
| Female workout cal | (0.20*age + 0.60*HR + 0.19*weight - 50) / 4.184 kcal/min | Same function | HIGH |
| Training State | Lookup table recovery_to_strain.json (101 entries) | Extracted from IPA bundle | HIGH |
| Sleep Performance | TST / sleep_needed * 100 | String literal in binary | HIGH |

### BLE Protocol
| Item | Valor | Fonte | Confiança |
|------|-------|-------|-----------|
| Haptic command (4.0) | cmd 79 = RUN_HAPTICS_PATTERN | r52 CommandNumber enum | HIGH |
| Haptic command (5.0 Maverick) | cmd 19 = RUN_HAPTIC_PATTERN_MAVERICK | r52 CommandNumber enum | HIGH |
| Gen5 haptics class | RunAppDrivenHapticsCommandPacket | Binary strings | MEDIUM |
| GET_BATTERY_LEVEL | cmd 26 | r52 enum | HIGH |
| TOGGLE_IMU_MODE | cmd 106 | r52 enum | HIGH |

### UI (parcial, da análise de strings)
| Campo | Label WHOOP | Nossa app | Fix needed |
|-------|-------------|-----------|-----------|
| Sleep metric | SLEEP PERFORMANCE | SLEEP EFFICIENCY | ✅ Phase 12 |
| Sleep duration | HOURS OF SLEEP | TIME ASLEEP | ✅ Phase 12 |
| Strain training | TRAINING STATE | (missing) | ✅ Phase 12 |

---

## Files

- `.planning/spikes/whoop-clone-analysis/01-ui-layout.md` — layout completo
- `.planning/spikes/whoop-clone-analysis/02-algorithms.md` — algoritmos exactos
- `.planning/spikes/whoop-clone-analysis/03-api-endpoints.md` — API WHOOP servers
- `.planning/spikes/whoop-clone-analysis/04-haptics.md` — haptic payload exacto
