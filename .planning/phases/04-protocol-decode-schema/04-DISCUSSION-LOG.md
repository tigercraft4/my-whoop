# Phase 4: Protocol Decode & Schema - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 04-protocol-decode-schema
**Areas discussed:** Body field layout, Corpus expansion vs. nova captura, Command probe sem bond, Ground-truth validation

---

## Body Field Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Hipótese 4.0, valida empiricamente | Assumir body[1:] == [type][seq][cmd][payload][CRC32] e validar contra os 46 frames existentes | ✓ |
| Bottom-up — derivar dos frames | Tratar body[1:] como opaco e derivar empiricamente. Mais rigoroso mas lento. | |
| whoop-vault r52 source primeiro | Consultar source do whoop-vault antes de codificar o decoder. | |

**User's choice:** Hipótese 4.0, valida empiricamente

---

| Option | Description | Selected |
|--------|-------------|----------|
| re/survey_5/decode_5.py | Seguindo o padrão de isolamento das Fases 2-3 | ✓ |
| re/decode_5.py (main re/) | Na raiz de re/, mais visível mas quebra o padrão de isolamento | |

**User's choice:** re/survey_5/decode_5.py

---

| Option | Description | Selected |
|--------|-------------|----------|
| Log e continua | Frames com CRC32 inválido logados mas não abortam o decode | ✓ |
| Falha hard em CRC32 inválido | Só frames válidos entram no corpus de análise | |

**User's choice:** Log e continua

---

## Corpus Expansion vs. Nova Captura

| Option | Description | Selected |
|--------|-------------|----------|
| Expandir corpus dos pklg existentes primeiro | Extrair todos os 5028 frames dos dois pklg via tshark. Custo zero de captura. | ✓ |
| Nova captura targeted primeiro | Capturar sessões novas com iPhone especificamente para triggers. | |
| Ambas em paralelo | Expandir corpus existente E agendar nova captura. | |

**User's choice:** Expandir corpus existente primeiro

---

| Option | Description | Selected |
|--------|-------------|----------|
| Nova captura quando o decode inicial bloquear | Just-in-time — só capturar se faltar dados para um stream específico. | |
| Uma sessão de captura grande no início da fase | Sessão abrangente na Wave 1 para minimizar interrupções. | |
| [Claude recommendation] | Expandir corpus existente E captura targeted na Wave 1 (HR/RR realtime, sleep review, workout history, historical backfill). | ✓ |

**User's choice:** Concordou com a recomendação: expandir corpus existente + captura targeted na Wave 1
**Notes:** Claude recomendou captura upfront para cobrir live stream types ausentes nas capturas existentes e evitar 3-4 interrupções mid-phase.

---

## Command Probe Sem Bond

| Option | Description | Selected |
|--------|-------------|----------|
| Análise de capturas + r52 enum maps | Extrair command IDs observados no tráfego iOS + cruzar com r52 maps. | ✓ |
| iOS Shortcuts / Pythonista no iPhone | Explorar bond direto do iPhone para live probing. Complexo e incerto. | |
| Defer live probe para Fase 5 | Live probe só quando Swift CoreBluetooth estiver implementado. | |

**User's choice:** Análise de capturas + r52 enum maps

---

| Option | Description | Selected |
|--------|-------------|----------|
| Documentar como 'não observado' com referência r52 | HYPOTHESIS + nota 'not observed in captures, expected from r52 map' | ✓ |
| Só documentar o que se vê nas capturas | Schema mais conservador, perde mapa r52 como referência | |

**User's choice:** Documentar como HYPOTHESIS com referência r52

---

## Ground-Truth Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Tenho oximeter e termómetro | Validação independente de SpO₂ e skin temp disponível | |
| Tenho só HR strap / não tenho todos | SpO₂ e/ou skin temp precisam de abordagem alternativa | ✓ |

**User's choice:** Sem oximeter/termómetro disponíveis
**Notes:** HR strap disponível para PROTO-07.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Comparar com o display da app oficial WHOOP | Decode side-by-side com app no ecrã | ✓ |
| Validar consistência interna — marcar VERIFIED sem ref externa | Aceitar valores fisiológicos plausíveis | |
| Deixar SpO₂ e skin temp como HYPOTHESIS | Aguardar hardware de referência | |

**User's choice:** Comparar com o display da app oficial WHOOP

---

| Option | Description | Selected |
|--------|-------------|----------|
| Decode do protocolo em Fase 4; kill-test em Fase 5 | Fase 4 documenta protocolo offload das capturas; live kill-test em Fase 5 | ✓ |
| Tentar simular kill-test com Python via iOS bond | Muito incerto | |

**User's choice:** Decode em Fase 4; kill-process test em Fase 5

---

## Claude's Discretion

- Tshark command exacto para extrair todos os frames dos dois pklg
- Se `decode_5.py` expõe CLI ou é pure library (library)
- Estrutura do `frames_5_golden.json` expandido (campo `stream_type` para frames classificados)
- Como estruturar `FINDINGS_5.md §Phase 4` (seguir padrão do §Phase 3)
- Implementação de `scripts/sync-schema-5.sh`
- Formato cross-source golden fixtures (padrão Phase 3: redacted hex + SHA256 + YAML sidecar)

## Deferred Ideas

- Live command probe 0–255 via re_harness: não possível macOS, diferir para Fase 5 se necessário
- Kill-process store-then-ack test (PROTO-10 live): Fase 5
- Android btsnoop cross-source fixtures: stretch goal se captura Android disponível
