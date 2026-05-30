# Phase 3: Framing Confirmation (Critical Gate) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 03-framing-confirmation-critical-gate
**Areas discussed:** Fonte dos frames para o CRC gate, Implementação do validador CRC, Profundidade do fallback Maverick, Scope do whoop_protocol_5.json v0

---

## Fonte dos frames para o CRC gate

### De onde vêm os frames para a validação CRC?

| Option | Description | Selected |
|--------|-------------|----------|
| Extrair dos .pklg existentes via tshark | Usar tshark nas capturas já comprometidas (4216 + 1011 ATT packets). Rápido, sem precisar de hardware, já têm custom channel frames do app oficial bondado. | ✓ |
| Nova captura Bleak live do strap bondado | Ligar o Bleak ao strap já bondado pelo iPhone e subscrever cmd-resp/events/data diretamente. | |
| Ambos (extrair existentes + nova captura) | Usar os .pklg para uma validação inicial rápida, depois capturar nova sessão Bleak. | |

**User's choice:** Extrair dos .pklg existentes via tshark
**Notes:** As duas capturas existentes satisfazem o critério de "duas sessões" do ROADMAP. Fallback para nova captura PacketLogger se < 20 frames com `0xAA` SOF forem encontrados.

### As duas capturas existentes contam como "duas sessões"?

| Option | Description | Selected |
|--------|-------------|----------|
| Sim — são capturas distintas, satisfazem o critério | 2026-05-30-ios.pklg + 2026-05-30-smp-bond-full.pklg são dois momentos distintos de tráfego BLE. | ✓ |
| Não — quero uma terceira captura nova como segunda sessão | Para garantir frames gerados em condições independentes. | |

**User's choice:** Sim — são capturas distintas

### Se < 20 frames forem extraídos, o que fazemos?

| Option | Description | Selected |
|--------|-------------|----------|
| Fazer nova captura PacketLogger | Abrir o app oficial + PacketLogger por 2-3 minutos. | ✓ |
| Ajustar o threshold para os frames disponíveis | Validar com o que existe e documentar o número real. | |

**User's choice:** Fazer nova captura PacketLogger

---

## Implementação do validador CRC

### Como implementar o validador CRC?

| Option | Description | Selected |
|--------|-------------|----------|
| Novo validate_frames_5.py standalone | Script dedicado em re/survey_5/ que lê hex de ATT payloads, valida CRC8+CRC32, imprime pass rate, e escreve frames_5_golden.json. | ✓ |
| Adaptar re/decode.py diretamente | Modificar o decode.py existente. Mais simples, mas mistura 5.0 com 4.0 no mesmo script. | |

**User's choice:** Novo validate_frames_5.py standalone em re/survey_5/

### Validar CRC8 + CRC32, ou apenas CRC32?

| Option | Description | Selected |
|--------|-------------|----------|
| Ambos: CRC8 + CRC32 | Validar os dois dá confiança total de que o framing é idêntico. CRC8 usa poly 0x07. | ✓ |
| Só CRC32 | A CRC32 é o gate crítico; CRC8 é só o header length check. | |

**User's choice:** Ambos: CRC8 + CRC32

### Guardar frames válidos como golden fixtures para Phase 4?

| Option | Description | Selected |
|--------|-------------|----------|
| Sim — escrever frames_5_golden.json | Guardar frames CRC-válidos com hex bruto, type/seq/cmd, payload, e characteristic source. Phase 4 usa-os como corpus. | ✓ |
| Não — só o relatório de pass rate | Phase 4 captura os seus próprios frames. | |

**User's choice:** Sim — escrever frames_5_golden.json (formato espelha o 4.0 golden fixture)

---

## Profundidade do fallback Maverick

### Se o CRC gate falhar, até onde vai a Phase 3 com o Maverick wrapper?

| Option | Description | Selected |
|--------|-------------|----------|
| Documentar estrutura + implementar wrapper stripper | Phase 3 entrega strip_maverick() que remove o outer wrapper e expõe o inner frame. Cumpre ROADMAP criterion 4 "decode work cleared with wrapper-strip step". | ✓ |
| Só documentar a estrutura | Phase 3 caracteriza e regista em FINDINGS_5.md. Phase 4 implementa o stripper. | |

**User's choice:** Documentar estrutura + implementar wrapper stripper (strip_maverick() em validate_frames_5.py)

### A Phase 3 tem um limite de escopo se o Maverick RE for complexo?

| Option | Description | Selected |
|--------|-------------|----------|
| Pode expandir — Phase 3 não termina até ter o framing locked | Consistente com o conceito de "critical gate". Phase 4 não começa sem go/no-go. | ✓ |
| Limite de escopo: 1-2 planos extra, depois Phase 4 ajusta-se | Evita bloquear o projeto se o RE for muito complexo. | |

**User's choice:** Pode expandir — Phase 3 não termina até ter o framing locked

---

## Scope do whoop_protocol_5.json v0

### O que entra no whoop_protocol_5.json v0?

| Option | Description | Selected |
|--------|-------------|----------|
| Framing + GATT constants | SOF, CRC8/CRC32 algos, frame struct, service UUID FD4B0001-..., 5 characteristic UUIDs, legacy UUID verdict (absent). Cria único source of truth para Phase 5. | ✓ |
| Só framing (minimalista) | Só parâmetros de framing. Phase 4 adiciona o resto. | |
| Espelhar estrutura do 4.0 (com campos vazios) | Copiar top-level do whoop_protocol.json com arrays vazios. Phase 4 preenche. | |

**User's choice:** Framing + GATT constants (single source of truth para Phase 5 Swift/Python code)

### Incluir firmware_revision: WG50_r52, VERIFIED?

| Option | Description | Selected |
|--------|-------------|----------|
| Sim — firmware_revision: WG50_r52, VERIFIED | Lido de Device Information 0x2A27. Facto confirmado. PROTO-16 requer firmware version em cada capture. | ✓ |
| Não — firmware vai para FINDINGS_5.md, não para o schema | O schema é para o protocolo, não para metadados de dispositivo específico. | |

**User's choice:** Sim — incluir firmware_revision no JSON

---

## Claude's Discretion

- Exact tshark filter expression para extrair ATT payload hex de `.pklg`
- Se `validate_frames_5.py` lê de stdin, file argument, ou lista hardcoded
- Estrutura interna de `frames_5_golden.json`
- Implementação da CRC8 table (lookup table vs. bitwise poly computation)
- Se `strip_maverick()` é função em `validate_frames_5.py` ou script separado

## Deferred Ideas

Nenhuma — discussão manteve-se dentro do scope da fase.
