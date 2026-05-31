# UI Layout — WHOOP 5.37.0

**Extraído via:** IPA strings analysis + Ghidra MCP
**Data:** 2026-06-01

> **Nota:** Documento completo em `docs/whoop-ui-reference.md` (429 linhas, extraído na Phase 8).
> Este ficheiro resume os gaps vs a nossa implementação actual.

---

## Tab Bar Structure

### WHOOP oficial (5.37.0)
| Tab | Label | Nota |
|-----|-------|------|
| 1 | **Home** | Overview com Recovery/Sleep/Strain gauges |
| 2 | **Coaching** | Sleep coaching, Smart Alarm, strain targets |
| 3 | **Health** | Blood Oxygen, Respiratory Rate, HRV, Skin Temp |
| 4 | **Community** | Social features |
| + | **Profile / Shop / Plan** | Via "More" |

Sleep não é tab primária no WHOOP — é acedida via Coaching calendar.

### Nossa app (OpenWhoop)
| Tab | Label | Diferença |
|-----|-------|-----------|
| 1 | Today | = Home WHOOP ✓ |
| 2 | Sleep | Tab dedicada (melhor UX) |
| 3 | Strain | = Workouts renomeado |
| 4 | Trends | = Trends WHOOP |
| 5 | Device | Não existe no WHOOP |

---

## Gaps Identificados (vs WHOOP 5.37.0)

### Críticos (afectam dados reais)

| Campo | WHOOP label | Nossa app | Fix |
|-------|-------------|-----------|-----|
| Sleep metric | **SLEEP PERFORMANCE** | SLEEP EFFICIENCY | Phase 12 |
| Sleep duration | **HOURS OF SLEEP** | TIME ASLEEP | Phase 12 |
| Sleep needed | **SLEEP NEEDED** | Não existe | Phase 12 |
| Strain zones | **TRAINING STATE** (OPTIMAL/RESTORATIVE/OVERREACHING) | Não existe | Phase 12 |

### Importantes

| Campo | WHOOP | Nossa app | Fix |
|-------|-------|-----------|-----|
| AWAKE time | Mostrado nas fases de sono | Não mostrado | Phase 12 |
| CALORIES | No overview diário | Não existe | Phase 12/13 |
| Sleep Latency | SLEEP LATENCY | LATENCY (nome diferente) | Phase 12 |
| Skin temp | Valor absoluto + "FROM BASELINE" separados | Só desvio | Phase 12 |

### Menores

| Campo | WHOOP | Nossa app |
|-------|-------|-----------|
| RHR label | RHR | Resting HR |
| Strain label | DAY STRAIN | Day Strain |
| Recovery label | RECOVERY | Recovery |

---

## Strain Zones (WHOOP labels confirmados)

```
ActivityStrainView.StrainLevel.Restorative  → RESTORATIVE (0–9)
ActivityStrainView.StrainLevel.LightActivity → LIGHT ACTIVITY (9–14)  
ActivityStrainView.StrainLevel.Moderate      → MODERATE (14–18)
ActivityStrainView.StrainLevel.High          → HIGH (18+)
```

E via Training State (coaching):
```
OPTIMAL / RESTORATIVE / OVERREACHING / IMPOSSIBLE
```

---

## WhoopLiveView Overlay Labels (para Device tab)

Strings confirmadas no binário:
```
WhoopLiveView.Overlay.Recovery.Title     → "RECOVERY"
WhoopLiveView.Overlay.Sleep.Title        → "SLEEP"  
WhoopLiveView.Overlay.Strain.Title       → "STRAIN"
WhoopLiveView.Overlay.DayStrain.Title    → "DAY STRAIN"
WhoopLiveView.Overlay.HoursOfSleep.Title → "HOURS OF SLEEP"
WhoopLiveView.Overlay.ActivityStrain.Title → "ACTIVITY STRAIN"
```

---

## Referências

- `docs/whoop-ui-reference.md` — documento completo com todos os campos, hierarquias e mapeamentos (Phase 8)
- `APPS IOS APK/com.whoop.iphone_5.37.0_und3fined.ipa` — fonte primária (strings extraídas via unzip + plutil)
