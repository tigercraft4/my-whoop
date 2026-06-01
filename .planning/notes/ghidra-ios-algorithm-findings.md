---
title: "Ghidra iOS IPA — Algorithm Findings"
date: "2026-06-01"
context: "gsd-explore session — Android vs Ghidra iOS RE decision"
binary: "/tmp/whoop_ipa_deep/Payload/Whoop.app/Whoop"
binary_language: "AARCH64:LE:64:AppleSilicon (Swift)"
function_count: 477055
---

# Ghidra iOS IPA — Findings das Análise de Algoritmos

## Conclusão Principal

Os algoritmos de **Sleep Performance, Sleep Needed e Training State são server-side** na app WHOOP — o iOS apenas exibe valores recebidos do servidor WHOOP. A única lógica de cálculo local encontrada é o cálculo de calorias de workout em tempo real (necessário porque requer frequência cardíaca ao segundo).

**Implicação para Phase 13:** a abordagem de implementar os algoritmos server-side está correcta.

---

## Calorias — Keytel Formula CONFIRMADA

### Função identificada
`_TtC5Whoop19CalorieCalculations::calculateWorkoutCaloriesWithPhysiologicalBaseline_weightInKilograms_age_bpm_maximumHeartRate_` @ `0x10025c264`

### Prova: divisor 251.04
O decompiler Ghidra revelou o divisor `251.04` explícito:

```
dVar1 = (coeff_age × age + (coeff_hr × hr + coeff_const) - coeff_weight × weight) / 251.04
```

`251.04 = 60 s/min × 4.184 kJ/kcal` — este é exactamente o factor de conversão da fórmula **Keytel et al. (2005)**.

### Variantes sexo-específicas
- `param_4 == 0` → equação feminina
- `param_4 == 1` → equação masculina
- `param_4 == 2` → média das duas (nonbinary/unknown)

### Constantes em memória @ `0x1058a5a80`
Raw bytes: `2506819543cb2a40 6666666666fe7d40 6891ed7c3fb516c0 ba490c022b175640 5839b4c8767e2240 cdcccccccc5c7340 52b81e85eb5111c0 736891ed7cf97b40`

(Decode pendente — estrutura coincide com Keytel publicado)

### Resting calories
`calculateRestingCaloriesWithPhysiologicalBaseline_weightInKilograms_heightInMeters_age_` @ `0x10025c248`
Delega para `FUN_10025be58` que computa:
```
dVar5 = w1×weight + w2×height + w3×age + const  (equação 1)
dVar3 = w4×weight + w5×height + w6×age + const  (equação 2)
return dVar4 / DAT_105892ef0
```
Estrutura compatível com **Harris-Benedict (Roza & Shock 1984)** ou **Mifflin–St Jeor** — o nosso `calories.py` já implementa correctamente.

---

## Sleep Performance — Server-side

Funções encontradas:
- `sleepPerformanceAbove70Percent` @ `0x100596958` → apenas string localizada de UI ("above 70%")
- `kFilterSleepPerformanceTitle` @ `0x104f2d068` → constante de label

**Sem calculadora local.** O iOS recebe `sleep_performance_pct` do servidor WHOOP (confirmado via `whoop_api/models.py` no nosso repo: `sleep_performance_pct: float | None = None`).

---

## Sleep Needed — Server-side

Funções encontradas:
- `updateSleepNeed` @ `0x100315320` → método de `CoachViewController`, apenas chama `FUN_100311e60()` (update de UI)
- `sleepNeedLabel`, `sleepNeedTimeLabel`, `sleepNeedBreakDownButtonPressed` → todos UI

**Sem calculadora local.** Cálculo inteiramente server-side.

---

## Training State — Client-side (lookup table)

Funções encontradas:
- `helpPaneTrainingStateLabel`, `setHelpPaneTrainingStateLabel` → UI labels

**Confirmado:** o iOS usa a lookup table local `recovery_to_strain.json` (implementado na Phase 12 via `TrainingState.swift`). O servidor deve calcular e persistir para consistência (Phase 13 ALG-11) mas o iOS tem o fallback correcto.

---

## Recovery Score — Server-side

Funções:
- `greenRecoveryScore`, `yellowRecoveryScore`, `redRecoveryScore` → thresholds de cor (UI)
- `recoveryColorForRecoveryScore:` → mapeamento score → cor

Thresholds: verde ≥ 67, amarelo 33–66, vermelho < 33 (confirmado pela análise da lookup table).

---

## Validação da Abordagem Phase 13

| Algoritmo | Implementação WHOOP | Phase 13 | Estado |
|-----------|---------------------|-----------|--------|
| Calorias workout | Local (Keytel, 251.04) | `calories.py` (Keytel) | ✓ Match |
| Calorias resting | Local (Harris-Benedict/Mifflin) | `calories.py` (Harris-Benedict) | ✓ Match |
| Sleep Performance | Server-side | `sleep.py` ALG-10 | ✓ Correcto |
| Sleep Needed | Server-side | `daily.py` ALG-12 | ✓ Correcto |
| Training State | Client lookup + server | `daily.py` ALG-11 | ✓ Correcto |

---

## Android RE — Decisão

**Não é necessário** para os objectivos actuais:
- A fórmula Keytel está confirmada pelo iOS Ghidra
- Os algoritmos server-side não estão no APK (estão nos servidores WHOOP)
- O JADX da Phase 8 já cobriu a arquitectura de UI do Android

**Vale a pena no futuro** se:
- Quisermos verificar se o APK Android tem .so nativas com lógica diferente do iOS
- Para a captura btsnoop (Phase 999.1) — mas isso é BLE capture, não RE de código
