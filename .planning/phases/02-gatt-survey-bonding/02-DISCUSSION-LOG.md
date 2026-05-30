# Phase 2: GATT Survey & Bonding - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 02-gatt-survey-bonding
**Areas discussed:** Ferramentas de GATT scan, Bonding sem a app oficial, Localização dos scripts Bleak, Formato de evidência GATT

---

## Ferramentas de GATT scan

| Option | Description | Selected |
|--------|-------------|----------|
| nRF Connect instalado | Já disponível | |
| Não tem nRF Connect | Pode instalar | ✓ |

**User's choice:** Instalar nRF Connect no iPhone (ainda não instalado)

| Option | Description | Selected |
|--------|-------------|----------|
| nRF Connect primeiro | App visual, confirma UUIDs no dispositivo real antes de Bleak | ✓ |
| Bleak script direto | Mais reproduzível mas requer bond existente | |
| Ambos em paralelo | nRF Connect + Bleak juntos | |

**User's choice:** nRF Connect primeiro (recomendado)

| Option | Description | Selected |
|--------|-------------|----------|
| Fechar app oficial | Evita conflito BLE | |
| Não sei, vamos descobrir | O plano documenta ambos os cenários | ✓ |
| App oficial aberta é ok | Raro em WHOOP | |

**User's choice:** Não sabe — plano cobre ambos os cenários (app aberta = advertisements visíveis; app fechada = conexão livre)

| Option | Description | Selected |
|--------|-------------|----------|
| Confirmar ambos os UUIDs | Critério 2 do ROADMAP, implicações para Fase 5 | ✓ |
| Só o novo fd4b0001 | Ignora legado | |

**User's choice:** Confirmar ambos (aceitou recomendação de Claude)
**Notes:** Claude explicou que é um check de 10 segundos com implicações downstream para compatibilidade 4.0/5.0.

---

## Bonding sem a app oficial

| Option | Description | Selected |
|--------|-------------|----------|
| Tentar 4.0 trick primeiro | 0xAA SOF já confirmado, camada interna parece idêntica | ✓ |
| Investigar 5.0 primeiro | Ler a captura iOS com mais detalhe antes de tentar | |
| Usar bond da app oficial | Não cumpre critério 3 (requer bond sem app oficial) | |

**User's choice:** Tentar 4.0 confirmed-write trick primeiro

| Option | Description | Selected |
|--------|-------------|----------|
| Investigar via PacketLogger | Capturar SMP handshake da app oficial e reproduzi-lo | ✓ |
| Pesquisar whoop-vault r52 | Enums de comandos podem revelar o handshake | |
| Deixar para Fase 3 | Bloquearia toda a Fase 3 | |

**User's choice:** PacketLogger fallback (recomendado) — já tem o workflow da Fase 1

| Option | Description | Selected |
|--------|-------------|----------|
| Emparelhado com app oficial | Plano inclui Forget Device + rebond via Bleak | ✓ |
| Ainda não emparelhado | — | |
| Strap não disponível agora | — | |

**User's choice:** WHOOP 5.0 está actualmente emparelhado com a app oficial no iPhone
**Notes:** Plano deve incluir passo explícito "Forget Device no iPhone → fechar app → bond via Bleak"

---

## Localização dos scripts Bleak

| Option | Description | Selected |
|--------|-------------|----------|
| re/survey_5/ | Separação limpa do 4.0 | ✓ |
| re/ directamente | Mais simples, mas polui 4.0 | |
| re/5/ ou re/whoop5/ | Similar mas sem "survey" no nome | |

**User's choice:** `re/survey_5/` (recomendado)

| Option | Description | Selected |
|--------|-------------|----------|
| re/survey_5/device_local_5.py | Mesmo padrão que 4.0 | ✓ |
| Reutilizar re/device_local.py | Mistura 4.0 e 5.0 | |
| Variáveis de ambiente | Sem ficheiro local | |

**User's choice:** `re/survey_5/device_local_5.py` com `device_local_5.example.py` committed (recomendado)

---

## Formato de evidência GATT

| Option | Description | Selected |
|--------|-------------|----------|
| FINDINGS_5.md | Documento vivo, extensível pelas fases 2-4, espelha FINDINGS.md 4.0 | ✓ |
| protocol/whoop_protocol_5.json | Prematuro sem UUIDs confirmados | |
| Ambos FINDINGS_5.md + JSON | JSON começa na Fase 3 após framing confirmado | |

**User's choice:** `FINDINGS_5.md` (recomendado) — JSON em Fase 3

| Option | Description | Selected |
|--------|-------------|----------|
| Mapear handles → UUIDs (recomendado) | Fecha o loop da Fase 1 | ✓ |
| Não é necessário agora | nRF Connect enumera tudo de raiz | |

**User's choice:** Sim, mapear 0x099b/0x099d/0x09a3 → UUIDs reais
**Notes:** Close the loop: Fase 1 mostrou o que os handles fazem, Fase 2 confirma a qual UUID pertencem.

---

## Claude's Discretion

- Presença/ausência do UUID legado `61080001-…`: Claude recomendou confirmar ambos (user concordou sem preferência própria)

## Deferred Ideas

Nenhuma — discussão manteve-se dentro do escopo da Fase 2.
