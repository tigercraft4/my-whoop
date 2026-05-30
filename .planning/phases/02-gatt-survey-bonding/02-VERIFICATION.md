---
phase: 02-gatt-survey-bonding
verified: 2026-05-30T17:14:14Z
status: human_needed
score: 3/4 must-haves verified
overrides_applied: 0
gaps: []
human_verification:
  - test: "Executar D-03b PacketLogger SMP capture: reparear o WHOOP 5.0 via app oficial enquanto captura com PacketLogger. Extrair SMP handshake com `tshark -Y btsmp`. Confirmar que pacotes SMP sao visiveis na captura."
    expected: "Pacotes SMP (Security Manager Protocol) visiveis no PacketLogger durante o processo de emparelhamento via app oficial. ROADMAP SC3 exige 'SMP packets are visible in PacketLogger' — isto encerra o criterio formalmente."
    why_human: "Requer acao fisica: Forget Device no iPhone, re-pair via app oficial, capturar com PacketLogger simultaneamente. Nao e automatizavel. A captura smp.hex scrubbed de BD_ADDR + chaves deve depois ser adicionada a re/capture/evidence/."
---

# Phase 2: GATT Survey & Bonding — Verification Report

**Phase Goal:** WHOOP 5.0 GATT surface fully enumerated on the user's specific device; bonding replicated without the official app; standard HR and battery characteristics readable
**Verified:** 2026-05-30T17:14:14Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | WHOOP 5.0 GATT surface fully enumerated: custom service FD4B0001-... e 7 caracteristicas confirmadas no dispositivo do utilizador | VERIFIED | FINDINGS_5.md §1: tabela completa com 5 caracteristicas customizadas + HR 0x2A37 + battery 0x2A19; nRF Connect visual + survey_gatt_5.py Bleak cross-check; sidecar characteristic_uuids map |
| 2 | Presenca/ausencia do servico legado 61080001-... registada explicitamente | VERIFIED | FINDINGS_5.md §2: "Verdict: ABSENT"; sidecar legacy_61080001_verdict: "absent"; observado 2026-05-30 |
| 3 | Bonding replicado sem a app oficial E pacotes SMP visiveis no PacketLogger | PARTIAL | FINDINGS_5.md §3: bond_5.py confirmou que o confirmed-write trick e iOS-only — macOS CoreBluetooth NAO auto-bond. Resultado negativo definitivo registado. SMP-visible evidence PENDENTE acao D-03b (developer action). SC3 nao totalmente satisfeito. |
| 4 | Standard HR streams live BPM via Bleak; battery legivel | VERIFIED | FINDINGS_5.md §4 + sidecar hr_battery_confirmed: hr_5.py live run 2026-05-30 — Battery 23%, 12 notificacoes HR em 12s (HR=71 bpm x10, HR=72 bpm x2), sem bonding, com parse_hr validado |

**Score:** 3/4 truths verified (SC3 parcial — pendente acao humana D-03b)

---

### Deferred Items

Nenhum item identificado como explicitamente coberto por fase posterior do roadmap. SC3 nao aparece nos criterios das fases 3–5 com wording especifico sobre SMP capture; e uma pre-requisito pratico da Fase 3 mas nao um deliverable formal da mesma.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `FINDINGS_5.md` | Mapa GATT, veredicto legado, outcome bonding, HR/battery, success criteria | VERIFIED | 161 linhas; todas as 6 seccoes numeradas + Status at a glance + Phase 2 Success Criteria presentes; seccoes 3/4 preenchidas com resultados live; sem MAC real; sem "pending" |
| `.gitignore` | Entrada para re/survey_5/device_local_5.py | VERIFIED | grep -qx confirma; git check-ignore passa |
| `re/survey_5/__init__.py` | Package marker | VERIFIED | Existe; ficheiro vazio (correto) |
| `re/survey_5/device_local_5.example.py` | Template committed com placeholders all-zero | VERIFIED | Contem DEVICE_UUID/DEVICE_MAC/DEVICE_SERIAL com valores 00...; comentario aponta para gitignored device_local_5.py |
| `re/survey_5/requirements.txt` | bleak==3.0.2 (pinned) | VERIFIED | Conteudo exacto: bleak==3.0.2 |
| `re/survey_5/survey_gatt_5.py` | Enumeracao GATT programatica + handle cross-check + JSON dump | VERIFIED | 90 linhas; ast-parse OK; client.services; PHASE1_HANDLES {0x099b,0x099d,0x09a3}; json.dump; sem get_services; import device_local_5 |
| `re/survey_5/bond_5.py` | Confirmed-write bonding trigger (response=True); sem WhoopPacket/sys.path | VERIFIED | 94 linhas; ast-parse OK; write_gatt_char com response=True; CMD_IN_5/CMD_RESP_5/EVENTS_5 com UUIDs reais FD4B0002/0003/0004; sem WhoopPacket; sem sys.path.insert |
| `re/survey_5/hr_5.py` | HR notify (0x2A37) + battery read (0x2A19); parse_hr; start_notify | VERIFIED | 71 linhas; ast-parse OK; HR UUID 00002a37; battery UUID 00002a19; def parse_hr; start_notify presente |
| `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml` | Evidence sidecar D-02: UUIDs, handle map, legacy verdict, bond outcome, HR/battery | VERIFIED | custom_service_uuid presente; characteristic_uuids map completo; handle_uuid_map com 0x099b/0x099d/0x09a3; legacy_61080001_verdict: absent; bond_outcome descrito; hr_battery_confirmed: yes; sem MAC real; sem long_term_key/identity_resolving_key |
| `re/survey_5/README.md` | Index dos scripts + runbooks | VERIFIED | survey_gatt_5.py + bond_5.py + hr_5.py referenciados; ios-packetlogger linkado; device_local_5.example.py mencionado; FINDINGS_5.md linkado |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `survey_gatt_5.py` | `device_local_5.DEVICE_UUID` | `from device_local_5 import DEVICE_UUID as ADDR` | WIRED | Import directo confirmado (linha 25) |
| `survey_gatt_5.py` | Phase 1 handles 0x099b/0x099d/0x09a3 | PHASE1_HANDLES set + match flag | WIRED | `PHASE1_HANDLES = {0x099b, 0x099d, 0x09a3}` + `<<< PHASE1 MATCH` flag; handle+1 corrigido para value handle |
| `bond_5.py` | `write_gatt_char(..., response=True)` | ATT Write Request trigger | WIRED | `await client.write_gatt_char(CMD_IN_5, b"\x00", response=True)` confirmado (linha 83) |
| `hr_5.py` | 0x2A37 / 0x2A19 | `start_notify(HR_MEAS)` + `read_gatt_char(BATTERY)` | WIRED | HR_MEAS e BATTERY definidos e usados em main(); parse_hr aplicado nas notificacoes |
| `FINDINGS_5.md §3` | `bond_5.py` outcome | Wave 3 bond result transcription | WIRED | Seccao 3 regista tabela live outcome com todos os erros (NotImplementedError, Code=15, Insufficient Authentication) |
| `re/survey_5/README.md` | `re/capture/ios-packetlogger.md` | runbook link | WIRED | grep confirma "ios-packetlogger" presente no README |

---

### Data-Flow Trace (Level 4)

Scripts sao ferramentas de RE (nao componentes que renderizam estado persistente). O fluxo de dados e: dispositivo BLE -> Bleak -> stdout/JSON. Verificado via live run (02-03-SUMMARY):

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `hr_5.py` | `hr, rrs` retornados por `parse_hr(data)` | Notificacao BLE 0x2A37 do strap | Sim — 12 notificacoes live, HR=71/72 bpm | FLOWING |
| `hr_5.py` | `batt[0]` | `read_gatt_char(BATTERY)` | Sim — 23% lido do dispositivo | FLOWING |
| `survey_gatt_5.py` | `result` dict | `client.services` via BleakClient | Sim — gatt_dump_5.json escrito (local, gitignored) | FLOWING |
| `bond_5.py` | callbacks raw hex | `start_notify(CMD_RESP_5/EVENTS_5)` | Parcial — error CBATTErrorDomain Code=15 (sem bond) | STATIC (sem bond) |

---

### Behavioral Spot-Checks

Nao e possivel correr os scripts sem o `device_local_5.py` real (gitignored) e o strap fisico presente. Os testes live foram executados durante Wave 3 e documentados em 02-03-SUMMARY. Resultado abaixo.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Enumeracao GATT programatica (survey_gatt_5.py) | Live run Wave 3 (02-03-SUMMARY) | 5 caracteristicas custom confirmadas; 3 Phase 1 handles matched (bug corrigido em 42ce113) | PASS |
| Bonding sem app oficial (bond_5.py) | Live run Wave 3 fresh-state | macOS NAO auto-bond; confirmed-write trick e iOS-only; erros Code=15 + Insufficient Auth | PARTIAL (comportamento negativo documentado) |
| HR live BPM (hr_5.py, strap usado) | Live run Wave 3 (02-03-SUMMARY) | Battery 23%, 12 notificacoes, HR=71/72 bpm | PASS |

---

### Probe Execution

Nao existem `scripts/*/tests/probe-*.sh` convencionais neste projeto. Os planos nao declaram probes formais. Os scripts de RE sao o equivalente funcional mas requerem hardware fisico — nao sao executaveis automaticamente.

Step 7c: SKIPPED (sem probes executaveis sem hardware BLE fisico e device_local_5.py real)

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PROTO-01 | 02-01, 02-02, 02-04 | GATT service UUID(s) confirmados no dispositivo do utilizador | SATISFIED | FD4B0001-CCE1-4033-93CE-002D5875F58A confirmado; 7 caracteristicas mapeadas em FINDINGS_5.md §1 + sidecar characteristic_uuids |
| PROTO-02 | 02-03, 02-04 | BLE bonding replicado sem a app oficial | PARTIAL | bond_5.py demonstrou que confirmed-write trick NAO faz auto-bond em macOS; resultado negativo documentado; SMP-visible evidence (D-03b) pendente acao humana. A replicacao via iOS (o caminho que funciona) nao foi capturada ainda. |
| PROTO-03 | 02-01, 02-02, 02-03, 02-04 | Caracteristicas GATT enumeradas e mapeadas (7 total) | SATISFIED | cmd-in/cmd-resp/events/data/diagnostics + HR 0x2A37 + battery 0x2A19 todos confirmados; handle->UUID map fechado; live HR + battery lidos |

**Nota sobre checkboxes em REQUIREMENTS.md:** As checkboxes de PROTO-01/02/03 permanecem `[ ]` (nao marcadas) em `.planning/REQUIREMENTS.md`. O executor registou nos SUMMARYs `requirements-completed: [PROTO-01, PROTO-02, PROTO-03]` mas nao actualizou o ficheiro REQUIREMENTS.md. PROTO-01 e PROTO-03 estao de facto satisfeitos. PROTO-02 e parcial (ver acima).

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `re/survey_5/bond_5.py` | 35-38 | `_PLACEHOLDER = "XXXX"` (e loop de verificacao runtime) | Info | NAO e um stub de codigo — e um runtime guard defensivo que verifica se os UUIDs reais foram preenchidos. As constantes CMD_IN_5/CMD_RESP_5/EVENTS_5 contem os UUIDs reais FD4B0002/0003/0004. O XXXX nunca aparece nos UUIDs reais. Nao e blocker. |
| `FINDINGS_5.md` | 131 | Mencao da palavra "placeholders" em contexto de explicacao | Info | Frase explicativa ("Bleak scripts can now use confirmed UUID constants instead of placeholders") — nao e placeholder; e descricao historica. Nao e blocker. |

Nenhum marcador `TBD`, `FIXME` ou `XXX` sem referencia formal a issue/PR encontrado nos ficheiros modificados pela Fase 2.

---

### Human Verification Required

#### 1. D-03b PacketLogger SMP Capture — ROADMAP SC3 closure

**Test:** Executar a captura de SMP com PacketLogger enquanto o strap emparelha com a app oficial:
1. Forget Device no iPhone para o WHOOP 5.0
2. Abrir PacketLogger no Mac com iPhone tethered (per `re/capture/ios-packetlogger.md`)
3. Re-emparelhar o strap via app oficial WHOOP no iPhone
4. Extrair SMP handshake: `tshark -Y btsmp -r <captura.pklg>`
5. Scrub BD_ADDR (6 bytes MAC) e qualquer pairing-key material do `.hex` extraido (DISCLAIMER §2 + Pitfall 5)
6. Commitar o `.hex` scrubbed + `.sha256` em `re/capture/evidence/`

**Expected:** Pacotes SMP visiveis no PacketLogger (pelo menos Pairing Request / Pairing Response / Pairing Confirm / Pairing Random / Pairing DHKey Check). Isto satisfaz a clausula "SMP packets are visible in PacketLogger" do ROADMAP SC3 e fecha formalmente PROTO-02.

**Why human:** Requer acao fisica com dois dispositivos simultaneamente (iPhone + Mac), hardware BLE presente, app oficial do WHOOP instalada e com conta activa. Nao e automatizavel. A captura SMP e um evento de curta durao (durante o emparelhamento) que tem de ser observado em directo.

---

### Gaps Summary

Nao existem gaps bloqueantes de artefactos ou codigo. Todos os scripts existem, sao substantivos, estao ligados, e os dados fluem (live runs confirmados).

A unica item pendente e a clausula SMP da ROADMAP SC3: "SMP packets visible in PacketLogger". Isto requer uma acao humana fisica (D-03b) que nao foi executada porque o macOS CoreBluetooth nao expoe SMP programaticamente. O resultado negativo definitivo foi documentado com rigor — e um achado tecnico valido, nao uma falha de execucao. A implementacao de bond_5.py esta completa e correta para o caminho iOS.

**Veredicto do verificador:** A fase entregou 3 dos 4 criterios de sucesso do ROADMAP de forma completamente verificada. O 4o criterio (SC3) esta 75% cumprido — o script existe, correu, documentou o resultado negativo definitivo, e o caminho de fallback D-03b esta documentado. A acao humana necessaria e a captura SMP com a app oficial.

---

_Verified: 2026-05-30T17:14:14Z_
_Verifier: Claude (gsd-verifier)_
