# Haptics — WHOOP 5.37.0

**Extraído via:** Ghidra MCP + IPA binary analysis
**Data:** 2026-05-31

---

## Sistema de Haptics WHOOP

O WHOOP 5.0 tem **dois sistemas de haptics** distintos:

### Gen4 Legacy (HapticPlayer)
Comandos simples com patternId (0–7, reportado pelo strap via `GET_ALL_HAPTICS_PATTERN`).

```swift
// HapticPlayer class (WhoopCore)
playLightHaptic()   → patternId=0
playMediumHaptic()  → patternId=1
playHeavyHaptic()   → patternId=2
playSuccessHaptic() → complex (calls _objc_msgSend chain)
```

**Comando BLE:** `cmd 79 = RUN_HAPTICS_PATTERN` (4.0) ou `cmd 19 = RUN_HAPTIC_PATTERN_MAVERICK` (5.0)
**Payload:** `[patternId, numLoops, 0, 0, 0]` (5 bytes)

### Gen5 App-Driven (HapticStrapServices)
Sistema avançado com **WaveformEffect sequences** — até 8 efeitos DRV2605 por comando.

**Comando BLE:** `RunAppDrivenHaptics` (comando específico Gen5)
**Response packet:** `RunAppDrivenHapticsResponsePacket`

Campos da response:
- `revision` (byte de versão)
- `statusMessage` (resultado da operação)
- `paddingBytes` (padding, deve ser todos zeros)
- `WaveformEffect1` até `WaveformEffect8` (até 8 efeitos)

---

## WaveformEffect Sequences

O `RunAppDrivenHapticsCommandPacket` aceita até **8 WaveformEffect** por chamada.
Cada WaveformEffect é um ID DRV2605 (Texas Instruments haptic driver IC).

**String confirmada no binário:** `WAVEFORM` @ 105e1b3e5

**WaveformEffect fields:** WaveformEffect1...WaveformEffect8 (confirmado pelos error strings no binário)

---

## Haptic Patterns Conhecidos

| Pattern | Sistema | Comando | Payload | Uso |
|---------|---------|---------|---------|-----|
| Light | Gen4 | cmd 19 | `[0, N, 0, 0, 0]` | Feedback suave |
| Medium | Gen4 | cmd 19 | `[1, N, 0, 0, 0]` | Feedback médio |
| Heavy | Gen4 | cmd 19 | `[2, N, 0, 0, 0]` | Feedback forte (alarm) |
| App-Driven | Gen5 | RunAppDrivenHaptics | WaveformEffect sequence | Padrões complexos |

---

## Alarm Haptics (confirmado via log strings)

```
→ successfully triggered alarm via HapticStrapServices.
→ failed to trigger alarm via HapticStrapServices: [error]
→ successfully saved alarm settings via HapticStrapServices.
→ successfully disabled alarm via HapticStrapServices.
```

O alarme usa **HapticStrapServices** (Gen5) — não o patternId legacy.
Quando `HapticStrapServices` está disabled: `[ActivityHapticsManager] Failed to execute haptic feedback on Gen 5 device: HapticStrapServices disabled`

---

## Battery Haptic Threshold

**Valor confirmado do binário:**
```
gBatteryThresholdHaptics = 10.9%
```
O WHOOP dispara um haptic quando a bateria desce para **10.9%**.

---

## Estado Actual da Nossa App

| Comando | Status | Notas |
|---------|--------|-------|
| `cmd 79` (legacy) | ❌ Ignorado pelo WHOOP 5.0 | Firmware 5.0 silently ignores |
| `cmd 19` (Maverick) | ⏳ Não verificado | Mudança feita mas sem confirmação de buzz |
| `RunAppDrivenHaptics` | ❌ Não implementado | Requer estrutura de WaveformEffect |

---

## Próximos Passos para Fix de Haptics

1. **Verificar cmd 19:** Após rebuild, testar Developer → Run Haptic com pattern 0, 1, 2
2. **PacketLogger capture:** Capturar app oficial a fazer buzz (alarme, pairing) para ver o payload exacto
3. **RunAppDrivenHapticsCommandPacket:** Implementar se cmd 19 não funcionar — requer WaveformEffect IDs válidos do DRV2605

### Para obter WaveformEffect IDs:
- DRV2605 library tem 123 efeitos pré-definidos (1-123)
- Efeitos comuns: 47=Sharp Click, 14=Strong Click, 1=Strong Click 100%
- PacketLogger capture é o caminho mais seguro

---

## Confidence

| Item | Confiança |
|------|-----------|
| patternId 0=light, 1=medium, 2=heavy | HIGH (decompile directo) |
| cmd 19 = Maverick haptic | HIGH (r52 enum) |
| WaveformEffect1-8 existem | HIGH (error strings no binário) |
| WaveformEffect IDs específicos | LOW (não capturados) |
| Battery haptic threshold 10.9% | HIGH (leitura directa de memória) |
