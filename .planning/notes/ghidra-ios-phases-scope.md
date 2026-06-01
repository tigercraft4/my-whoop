---
title: "Ghidra iOS — Utilidade por Fase"
date: "2026-06-01"
context: "gsd-explore — Android RE vs Ghidra iOS, o que serve para o resto das fases"
---

# Ghidra iOS IPA — O Que Serve Para Cada Fase

## Conclusão Rápida

O Ghidra iOS (IPA 5.37.0, 477k funções, ARM64 Swift) é útil para:
- ✅ **Validar algoritmos** que já implementamos (confirmação de Keytel)
- ✅ **Perceber o que é client-side vs server-side** (maioria é server)
- ❌ **Haptics payload** — padrões são dinâmicos (fetched do servidor WHOOP), não hardcoded
- ❌ **Algoritmos de recovery/sleep/strain** — server-side, não estão no IPA

---

## Por Fase

### Phase 13 — Backend Parity (actual)

| Algoritmo | Ghidra iOS | Resultado |
|-----------|------------|-----------|
| Calorias workout | ✅ `CalorieCalculations::calculateWorkoutCalories` @ `0x10025c264` | Keytel confirmado (÷251.04), sex-specific |
| Calorias resting | ✅ `calculateRestingCalories` @ `0x10025c248` | Harris-Benedict/Mifflin estrutura confirmada |
| Sleep Performance | ❌ Só UI labels | Server-side — fase 13 correcto |
| Sleep Needed | ❌ Só UI controller | Server-side — fase 13 correcto |
| Training State | ❌ Só UI labels | Client lookup table (já implementado Phase 12) |
| Recovery Score | ❌ Só thresholds de cor | Server-side |

**Veredicto:** Ghidra iOS validou o design da Phase 13. Android não necessário.

---

### Haptics — Phase 999.1 / debug buzz-nao-funciona.md

`StrapHapticsBLEManager::getAllAvailableHapticsPatternsWithCompletion` existe no IPA — mas busca padrões dinamicamente (provavelmente do servidor WHOOP). Os bytes DRV2605 waveform **não estão hardcoded** no binário.

**O que resolve o buzz:** btsnoop BLE capture (Android ou iOS PacketLogger) quando a app oficial faz buzz. O Ghidra não tem os bytes.

**Veredicto:** Para haptics, Android com btsnoop é o caminho. Ghidra iOS não ajuda.

---

### PROTO-11/12/13/14 — Biometrics HYPOTHESIS → VERIFIED

Ghidra timeouts nas pesquisas de SpO2/skinTemp (binário em análise). Mesmo que encontrasse, a verificação requer **captura de dados reais** do sensor — Ghidra só dá a lógica de decode, não os dados.

**Veredicto:** Requer hardware (Phase 999.2) — WHOOP + iPhone, sessão TOGGLE_IMU_MODE. Ghidra pode ajudar a confirmar o decode offset (pesquisa futura quando o binário terminar a análise).

---

### Phase 999.1 — Android btsnoop capture

O Ghidra iOS não substitui isto. A captura BLE live requer:
- Android com developer options + HCI snoop log
- App WHOOP oficial a correr e a comunicar com o WHOOP 5.0

**Veredicto:** Android device é necessário para este item específico (btsnoop live).

---

### Fases futuras (v4.0+)

Quando Ghidra terminar a análise do binário (477k funções é pesado), vale fazer:
1. **Decode dos coeficientes Keytel** em `0x1058a5a80` — confirmar os valores exactos sex-específicos
2. **Pesquisa de R20/R21/R22/R25/R26 packet parsing** — protocol constants para backfill
3. **Pesquisa de biometric decode offsets** (SpO2, skin temp) — confirmar PROTO-11/12

---

## Android — Quando Vale a Pena

| Caso | Vale? | Porquê |
|------|-------|--------|
| APK RE (algoritmos) | ❌ | Algoritmos são server-side; JADX Phase 8 já cobriu UI |
| APK RE (native .so Ghidra) | ⚠️ Incerto | Se houver .so nativas com lógica BLE/crypto — verificar após Phase 13 |
| btsnoop BLE capture | ✅ | Única forma de capturar haptics payload + PROTO-11/12/13/14 live |
| JADX-GUI live (Phase 999.1) | ✅ | Navegação interactiva melhor que APK estático |

**Decisão actual:** manter Android para sessão dedicada de btsnoop (haptics + biométricos), não para RE de algoritmos.
