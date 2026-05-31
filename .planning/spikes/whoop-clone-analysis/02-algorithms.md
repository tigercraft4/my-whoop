# Algoritmos — WHOOP 5.37.0

**Extraído via:** Ghidra MCP (decompile directo) + IPA bundle JSON files
**Data:** 2026-06-01

---

## Arquitectura: Local vs Cloud

| Algoritmo | Onde computa | Evidência |
|-----------|-------------|-----------|
| **Day Strain (0-21)** | LOCAL (iOS) | `StrainAccumulator.swift`, `StrainCalculations.swift` no binário |
| **Calorias** | LOCAL (iOS) | `CalorieCalculations.swift` no binário |
| **Training State** | LOCAL (iOS) | `recovery_to_strain.json` bundled no IPA |
| **Recovery score** | CLOUD | Sem `RecoveryCalculations.swift` no binário; fetched do coaching-service |
| **Sleep staging** | CLOUD | `SleepDetailsService.swift` = fetch, não compute |
| **Sleep Needed** | CLOUD | `SleepNeedDetails` fetched de `/coaching-service/v2/sleepneed` |
| **HRV RMSSD** | HÍBRIDO | Calculado local dos RR intervals; baseline EWMA no servidor |

---

## 1. Strain (0–21) — LOCAL

### Raw TRIMP → Scaled

**Lookup table:** `strain_raw_scale_lookup.json` (211 entradas, resolução 0.1)
- raw=0 → scaled=0
- raw=0.003649 → scaled=10 (esforço moderado)
- raw=0.701958 → scaled=21 (esforço máximo absoluto)

**Conversão de TRIMP (Edwards) para raw WHOOP:**
```
raw = TRIMP_minutes * zone_weight / 32886
```

Verificação: 60min zona2 (weight=2.0):
```
raw = 60 * 2.0 / 32886 = 0.003649 → scaled=10.0 ✓
```

### Zonas de HR (%HRmax — confirmado via Ghidra)

| Zona | %HRmax | Edwards Weight |
|------|--------|----------------|
| 0 | < 50% | 0.0 (repouso) |
| 1 | 50–60% | 1.0 |
| 2 | 60–70% | 2.0 |
| 3 | 70–80% | 4.0 |
| 4 | 80–90% | 6.0 |
| 5 | > 90% | 10.0 |

**HRmax:** `max_heart_rate_upper_bound=220`, `lower_bound=120`, default=200
Estimativa: 220 - age

### Training State (Optimal Strain)

Lookup table `recovery_to_strain.json` (101 entradas por ponto de Recovery):

| Recovery | Lower (RESTORATIVE) | Optimal | Upper (OVERREACHING) |
|----------|--------------------|---------|--------------------|
| 0% | 0.0 | 5.0 | 10.0 |
| 33% | 6.0 | 10.0 | 14.0 |
| 50% | 7.0 | 11.0 | 15.0 |
| 67% | 8.0 | 12.0 | 16.0 |
| 100% | 13.0 | 17.0 | 21.0 |

---

## 2. Calorias — LOCAL

### RMR (kcal/dia) — Mifflin variant

**Fórmula exacta** extraída via Ghidra (leitura de memória em `FUN_10025be58`):

```
Male:   13.397 * kg + 479.9 * height_m + (-5.677) * age + 88.362
Female:  9.247 * kg + 309.8 * height_m + (-4.330) * age + 447.593
Nonbinary: (male + female) / 2
```

Output: kcal/dia (dividido por 86400 internamente para kcal/segundo)

### Calorias de Actividade (kcal/min)

**Fórmula exacta** extraída via Ghidra (`FUN_10025c264`):

```
Male:   (0.07 * age + 0.40 * HR - 0.13 * weight - 15) / 4.184
Female: (0.20 * age + 0.60 * HR + 0.19 * weight - 50) / 4.184
Nonbinary: (male + female) / 2
```

HR é capped em HRmax antes de aplicar a fórmula.
Divisor 4.184 = conversão kJ→kcal.

Teste: HR=150, weight=70kg, age=30 → male = 9.1 kcal/min ✓

---

## 3. Recovery Score — CLOUD

**Zonas de cor** (confirmadas via leitura de memória em `WHPColorMapper::recoveryColorForRecoveryScore_`):
- Vermelho: 0–33%
- Amarelo: 33–66%
- Verde: 66–100%

**Inputs confirmados** (string literals no binário):
- HRV (RMSSD durante último Slow Wave Sleep)
- RHR (durante sono)
- Respiratory rate (durante sono)
- Sleep Performance = TST / sleep_needed × 100

**Arquitectura:** iOS envia dados biométricos para servidor via `/metrics-service/v1/metrics/sensor`. O coaching-service computa o Recovery score e devolve via API.

Não existe RecoveryCalculations.swift no projecto iOS — é 100% servidor.

---

## 4. Sleep Performance — CLOUD

**Definição exacta** (string literal no binário):
> "reflects how much Sleep you achieved compared to how much Sleep you needed."

```
Sleep Performance = (total_sleep_time / sleep_needed) × 100
```

**NOT** efficiency = TST/TIB. É a razão contra sleep_needed.

---

## 5. Sleep Needed — CLOUD

**4 componentes** (string keys no binário):
```
SleepNeeded.Baseline     → rolling average historical sleep
SleepNeeded.RecentStrain → strain-based additional need
SleepNeeded.SleepDebt    → accumulated deficit
SleepNeeded.RecentNaps   → nap credit (negative)

sleep_needed = Baseline + RecentStrain + SleepDebt - RecentNaps
```

Endpoint: `GET /coaching-service/v2/sleepneed`

Coeficientes numéricos: **não extraídos** (requerem PacketLogger capture com conta WHOOP real).

---

## 6. HRV — HÍBRIDO

**Janela:** último episódio de Slow Wave Sleep (deep sleep) — confirmado por string literal:
> "is a measure of the inconsistency between your heart beats, and is taken during your last period of Slow Wave Sleep."

**Método:** RMSSD (Root Mean Square of Successive Differences) dos RR intervals.

Baseline EWMA personalizado computado no servidor (coaching-service).

---

## Confidence Summary

| Algoritmo | Confiança | Método de extracção |
|-----------|-----------|---------------------|
| Strain lookup table | HIGH | strain_raw_scale_lookup.json do bundle IPA |
| Zona boundaries (%HRmax) | HIGH | Ghidra binary analysis |
| Training State lookup | HIGH | recovery_to_strain.json do bundle IPA |
| RMR coeficientes | HIGH | Ghidra memory read em FUN_10025be58 |
| Calorie coeficientes | HIGH | Ghidra memory read em FUN_10025c264 |
| Recovery zones (33/66) | HIGH | Ghidra memory read em WHPColorMapper |
| Sleep Performance fórmula | HIGH | String literal no binário |
| Sleep Needed componentes | HIGH | String keys no binário |
| Sleep Needed coeficientes | LOW | Requerem intercepção de tráfego real |
| Recovery score weights | LOW | Não extraídos (servidor-side, obfuscados) |
