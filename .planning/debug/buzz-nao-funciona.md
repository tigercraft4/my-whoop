---
status: root_cause_found
slug: buzz-nao-funciona
trigger: "o buzz nao funciona"
created: "2026-05-31"
updated: "2026-05-31"
---

# Debug Session: buzz-nao-funciona

## Symptoms

- **Expected:** WHOOP strap vibra quando se prime "Run" na secção Haptics da Device tab
- **Actual:** O comando BLE é enviado (`→ Run Haptics Pattern payload=0203000000`) mas o WHOOP NÃO vibra
- **Error messages:** Nenhum erro BLE — o comando foi aceite pela stack Bluetooth sem erro
- **Timeline:** Nunca verificado no WHOOP 5.0 — herdado do 4.0
- **Reproduction:** Conectar ao WHOOP 5.0 → Device tab → Haptics section → ajustar loops para 3 → Run

## Evidence

- timestamp: "2026-05-31T21:25:55"
  observation: "→ Run Haptics Pattern payload=0203000000 — enviado com sucesso sem erro BLE"
  file: "BLEManager.swift"
  line: 582

- timestamp: "2026-05-31"
  observation: "Commands.swift linha 70-74: runHapticsPattern = 79 marcado explicitamente como 'HYPOTHESIS (5.0 unverified) — inherited from 4.0'"
  file: "ios/OpenWhoop/BLE/Commands.swift"
  line: 74

- timestamp: "2026-05-31"
  observation: "Payload enviado: [0x02, 0x03, 0x00, 0x00, 0x00] = patternId=2, loops=3. Formato herdado do 4.0"
  file: "ios/OpenWhoop/BLE/BLEManager.swift"

- timestamp: "2026-05-31"
  observation: "DESCOBERTA CHAVE — protocol/whoop_protocol_5.json (r52 CommandNumber map) tem DOIS comandos de haptics: 19 = RUN_HAPTIC_PATTERN_MAVERICK (variante geração 5.0/Maverick) e 79 = RUN_HAPTICS_PATTERN (legacy 4.0). O WHOOP 5.0 é internamente 'Maverick' (todo o wrapper BLE 5.0 chama-se Maverick em FINDINGS_5.md §7). A app envia o 79 legacy; o firmware 5.0 ignora-o silenciosamente (aceita o write, sem erro, sem buzz)."
  file: "protocol/whoop_protocol_5.json"
  line: 37

- timestamp: "2026-05-31"
  observation: "FINDINGS_5.md §7/§8 estabelece que o firmware deste strap é WG50_r52 e que o mapa de enum r52 é directamente utilizável no 5.0 sem re-derivação. Logo o 19=RUN_HAPTIC_PATTERN_MAVERICK aplica-se a este strap."
  file: "FINDINGS_5.md"
  line: 208

- timestamp: "2026-05-31"
  observation: "Nem 79 nem 19 aparecem no corpus VERIFIED-observed (haptics nunca foram capturados — a app oficial não disparou buzz durante as capturas). A verdade-base é o mapa enum r52, não uma captura directa."
  file: "FINDINGS_5.md"
  line: 241

- timestamp: "2026-05-31"
  observation: "Mapa de EventNumber r52 inclui 60=HAPTICS_FIRED e 100=HAPTICS_TERMINATED — confirma que o strap 5.0 emite eventos quando os haptics disparam. Verificar a ausência destes eventos confirmaria que o 79 não dispara."
  file: "protocol/whoop_protocol_5.json"
  line: 31

## Current Focus

hypothesis: "RESOLVIDO — o comando legacy 4.0 (79=RUN_HAPTICS_PATTERN) é ignorado pelo firmware 5.0; o comando correcto é 19=RUN_HAPTIC_PATTERN_MAVERICK"
test: "Trocar o comando para 19 e premir Run; observar buzz e/ou evento 60=HAPTICS_FIRED na characteristic de eventos"
expecting: "O strap vibra com o comando 19"
next_action: "Aplicar fix: introduzir case runHapticPatternMaverick = 19 e redireccionar runHaptic/testAlarmBuzz para ele"

## Eliminated

- hypothesis: "Bug no código Swift (payload errado)"
  reason: "O payload 0203000000 segue a spec 4.0 correctamente. O problema é que a spec 4.0 pode não aplicar ao 5.0"

- hypothesis: "Loops = 0 (comando enviado sem repetições)"
  reason: "Corrigido — loops foi alterado de 0 para 3. O comando foi enviado com payload=0203000000 (loops=3)"

- hypothesis: "Wrapping errado do frame (4.0 frame vs Maverick)"
  reason: "send() já usa command.maverickFrame() para TODOS os writes (BLEManager.swift:266). O envelope está correcto; o problema é o ID de comando dentro do body."

## Specialist Review

reviewer: "swift-agent-team (specialist_hint: swift)"
verdict: "SUGGEST_CHANGE / LOOKS_GOOD direction"
notes: |
  - A direcção da correcção está correcta: o ID de comando dentro do body Maverick deve ser 19 (RUN_HAPTIC_PATTERN_MAVERICK), não o legacy 79.
  - Idiomático Swift: adicionar um novo case `runHapticPatternMaverick = 19` ao enum WhoopCommand em vez de mudar o rawValue de um case existente. Mudar o rawValue de `runHapticsPattern` quebraria a semântica (o nome diria 79 mas valeria 19) e poderia colidir com testes que asseguram raw values.
  - Manter `runHapticsPattern = 79` retido (referenciado por OpenWhoopTests) e adicionar o label correspondente no switch `label` (exhaustivo — o compilador obriga a tratar o novo case, o que é uma rede de segurança).
  - Redireccionar os 2 call-sites de produção: LiveViewModel.runHaptic (linha 53) e BLEManager.testAlarmBuzz (linha 582). stopHaptics (122) e runAlarm (68) ficam — não há variante Maverick conhecida para eles no mapa r52.
  - Pitfall: o payload do 19 pode diferir do 79 (Maverick pode esperar formato diferente). Sem captura, manter o mesmo formato [patternId, loops, 0,0,0] como primeira tentativa, mas instrumentar para observar evento 60=HAPTICS_FIRED na confirmação on-device. Se 19 também não disparar, próximo passo é capturar a app oficial a fazer buzz (PacketLogger) — único caminho para resolver o payload com certeza.
  - Confiança: ALTA na troca de comando (mapa enum r52 explícito + nomenclatura "Maverick" == 5.0); MÉDIA no payload (não capturado).

## Resolution

root_cause: "A app dispara o comando de haptics legacy do 4.0 (79=RUN_HAPTICS_PATTERN) que o firmware do WHOOP 5.0 (geração 'Maverick', WG50_r52) ignora silenciosamente; o 5.0 tem um comando dedicado 19=RUN_HAPTIC_PATTERN_MAVERICK no mapa enum r52."
fix: ""
verification: ""
files_changed: []
