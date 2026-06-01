# Phase 7: iOS Validation + Biometrics Capture - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-31
**Phase:** 07-ios-validation-biometrics-capture
**Areas discussed:** TOGGLE_IMU_MODE trigger, TrendsView SpO₂/skinTemp, Artefactos VERIFIED, IOS-08 reconnect validation

---

## TOGGLE_IMU_MODE trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Script bleak do Mac | Usar RE harness Python — já existe, sem alterações ao código iOS | ✓ |
| Botão debug na app iOS | Adicionar botão em Settings tab em BLEManager | ✓ |
| Gesto long-press em LiveView | Long-press no card de HR activa TOGGLE_IMU_MODE | |

**User's choice:** Ambos — script bleak + botão debug iOS

| Option | Description | Selected |
|--------|-------------|----------|
| Toggle simples (on/off state visível) | Mostra estado actual — 'IMU Mode: OFF' / 'ON' | |
| Botão de acesso único | Sem estado persistente — 'Send TOGGLE_IMU_MODE' | |
| Claude decide | Implementação exacta ao critério do agente de planeamento | ✓ |

**User's choice:** Claude decide — implementação do botão iOS ao critério do planeador

| Option | Description | Selected |
|--------|-------------|----------|
| 20–30 minutos estabilizado | Tempo suficiente para todas as streams aparecerem | |
| Até ver as 4 streams confirmadas nos logs | Terminar quando logs mostram spo2, skinTemp, respiration e gravity | ✓ |

**User's choice:** Até ver as 4 streams confirmadas nos logs (não tempo fixo)

| Option | Description | Selected |
|--------|-------------|----------|
| Script novo dedicado (re/capture/toggle_imu.py) | Isola a captura IMU | |
| Flag/modo no re_harness.py existente | Reusa infra já existente | |
| Claude decide | Estrutura exacta ao critério do planeador | ✓ |

**User's choice:** Claude decide

---

## TrendsView SpO₂/skinTemp

| Option | Description | Selected |
|--------|-------------|----------|
| Adicionar na Fase 7 (IOS-05 done agora) | Adicionar SpO₂ e skinTemp a MetricKind.dailyCases nesta fase | |
| Diferir para Fase 9 (menos retrabalho) | Fase 9 redesenha TrendsView de raiz em WHOOP-style | ✓ |
| Mínimo na Fase 7, completo na Fase 9 | Adicionar apenas series que já estão wired | |

**User's choice:** "o que achares melhor" → Claude recomendou diferir para Phase 9
**Notes:** Success criteria da Phase 7 não incluem IOS-05 explicitamente; Phase 9 vai redesenhar TrendsView de raiz — implementar agora seria retrabalho desnecessário.

---

## Artefactos VERIFIED

| Option | Description | Selected |
|--------|-------------|----------|
| Schema JSON atualizado | confidence: 'HYPOTHESIS' → 'VERIFIED' em whoop_protocol_5.json | ✓ |
| FINDINGS_5.md atualizado | Linha VERIFIED com valor medido e método de ground truth | ✓ |
| Evidência PacketLogger em re/capture/evidence/ | Commit do .pklg ou excerpt filtrado | ✓ |
| Nota no REQUIREMENTS.md (tick style) | Marcar PROTO-11/12/13/14 como done quando VERIFIED | ✓ |

**User's choice:** Tudo — todos os 4 artefactos obrigatórios quando stream é VERIFIED

| Option | Description | Selected |
|--------|-------------|----------|
| ±2% (clínico standard) | ±2 pontos percentuais vs oximétro de pulso consumer | |
| Plausível (96–100%) | Não comparar contra oxímetro — verificar range fisiológico | |
| Claude decide | Threshold exacto ao critério do planeador | ✓ |

**User's choice:** Claude decide — planeador documenta threshold no runbook de validação

---

## IOS-08 reconnect validation

| Option | Description | Selected |
|--------|-------------|----------|
| Teste manual com runbook documentado | Documento passo-a-passo + screenshot da reconexão | |
| Maestro automation | Maestro testa background reconnect — assertável em CI | ✓ |
| Manual + screenshot de logs como evidência | Teste manual mas capturar logs Xcode | |

**User's choice:** Maestro automation

| Option | Description | Selected |
|--------|-------------|----------|
| Assert 'Connected' em LiveView (≤ 30s) | Verificar indicador de conexão | |
| Assert HR com valor válido (≤ 30s) | Exige HR > 0 após reconexão | |
| Claude decide | Critério exacto ao critério do planeador | ✓ |

**User's choice:** Claude decide

---

## Claude's Discretion

- Estrutura exacta do script Python (standalone vs modo no re_harness.py)
- UI exacta do botão TOGGLE_IMU_MODE (toggle vs action button)
- Threshold exacto de aceitação SpO₂ vs oxímetro (documentar no runbook)
- Critério do Maestro test IOS-08 (Connected indicator vs HR ao vivo)

## Deferred Ideas

- **IOS-05 (SpO₂/skinTemp chart series no TrendsView)** — deferido para Phase 9 (SwiftUI Redesign WHOOP-Style). MetricKind.dailyCases NOT to be modified in Phase 7.
