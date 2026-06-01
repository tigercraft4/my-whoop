---
title: "iOS PacketLogger — Captura BLE haptics WHOOP 5.0"
date: "2026-06-01"
priority: high
blocks: "buzz-nao-funciona.md fix, PROTO-11/12/13/14 verification"
hardware_required: "iPhone (com WHOOP official app), WHOOP 5.0, Mac com Xcode"
estimated_time: "30–60 min"
---

# Runbook: Captura Manual BLE via iOS PacketLogger

## Objectivo

Capturar os bytes exactos que a app oficial WHOOP envia ao WHOOP 5.0 quando faz buzz.
O nosso payload actual `[2, 3, 0, 0, 0]` (cmd 19 Maverick) não funciona — precisamos do
payload real para corrigir `BLEManager.swift`.

**Secondary:** capturar sessão de `TOGGLE_IMU_MODE` para verificar PROTO-11/12/13/14
(SpO₂, skin temp, respiration, IMU).

---

## Pré-Requisitos

- [ ] iPhone com a app WHOOP oficial instalada e WHOOP 5.0 emparelhado
- [ ] Apple Developer account (free tier chega)
- [ ] Xcode instalado no Mac (para PacketLogger + Additional Tools)
- [ ] **NÃO usar a app OpenWhoop** durante a captura — desinstalar ou manter em background morto

---

## Passo 1 — Instalar perfil de logging BLE no iPhone

```
URL: https://developer.apple.com/services-account/download?path=/iOS/iOS_Logs/iOSBTPacketLogger.mobileconfig
```

1. No iPhone, abrir Safari e navegar para o URL acima (requer login Apple Developer)
2. Instalar o perfil: Definições → Perfil Transferido → Instalar
3. **Reiniciar o iPhone** (obrigatório — o logging só activa após reboot)

> O perfil habilita o HCI snoop log interno do iOS que o PacketLogger lê via USB.

---

## Passo 2 — Instalar PacketLogger no Mac

```bash
# Baixar Additional Tools for Xcode da Apple Developer:
# https://developer.apple.com/download/all/?q=Additional%20Tools
# → "Additional Tools for Xcode 15.x" → .dmg
# → Arrastar PacketLogger.app para /Applications
open /Applications/PacketLogger.app
```

Em alternativa, via Instruments: Xcode → Open Developer Tool → Instruments → Bluetooth Logging.

---

## Passo 3 — Iniciar captura

1. Ligar iPhone ao Mac via USB
2. Abrir PacketLogger.app
3. File → New iOS Trace (ou ⌘N)
4. Seleccionar o iPhone na lista de devices
5. Clicar **Start** — PacketLogger começa a gravar todos os pacotes BLE/BR-EDR

---

## Passo 4A — Capturar haptics (buzz)

Com PacketLogger a gravar:

1. Abrir a app WHOOP oficial no iPhone
2. Aguardar ligar ao WHOOP 5.0 (ícone de ligação verde)
3. Acionar haptics de uma destas formas:
   - **Opção A (mais simples):** Ir a Profile → Device → Test Haptics (se disponível na app)
   - **Opção B:** Definir um alarm para daqui a 1–2 min e aguardar o buzz
   - **Opção C:** Ativar/desativar o Sleep Mode — o WHOOP confirma com um buzz

4. Quando o WHOOP buzzer, **parar a gravação** no PacketLogger (Stop)
5. Guardar o ficheiro: File → Save → `whoop5_haptics_YYYYMMDD.pklg`

---

## Passo 4B — Capturar biométricos TOGGLE_IMU_MODE (PROTO-11/12/13/14)

Com PacketLogger a gravar:

1. Certificar que o WHOOP está em movimento activo (ou aguardar > 5 min conectado)
2. A app oficial activa automaticamente `TOGGLE_IMU_MODE` durante certas condições
3. Aguardar 10–15 min de dados antes de parar

---

## Passo 5 — Analisar em PacketLogger

### Filtrar pelo UUID do serviço WHOOP 5.0

```
Service UUID: FD4B0001-CCE1-4033-93CE-002D5875F58A
Command char: FD4B0002-CCE1-4033-93CE-002D5875F58A  ← onde vão os comandos haptics
Response char: FD4B0003-CCE1-4033-93CE-002D5875F58A
```

### Localizar o comando haptics

No PacketLogger, filtrar por:
- **Type:** `ATT Write Request` ou `ATT Write Command`
- **Handle:** o handle correspondente a `FD4B0002`

O pacote de haptics deve ter o formato:
```
ATT Write → FD4B0002
Payload: [CMD_LENGTH] [CMD_ID=19] [PAYLOAD_BYTES...]
```

O nosso payload actual:
```
02 03 00 00 00  (cmd 19, patternId=2, loops=3)
```

O payload real WHOOP pode ser diferente — comparar o que a app oficial envia.

### Alternativa: filtrar por handle

1. PacketLogger → Edit → Find (⌘F) → procurar `FD4B0002`
2. Identificar o ATT handle number (ex: `0x000D`)
3. Filtrar todas as ATT Writes para esse handle em torno do timestamp do buzz

---

## Passo 6 — Extrair bytes e actualizar o código

Depois de identificar o payload real:

```swift
// ios/OpenWhoop/BLE/BLEManager.swift
// Actualizar o payload em runTestBuzz() com os bytes capturados:
send(.runHapticPatternMaverick, payload: [XX, XX, XX, XX, XX])  // bytes reais
```

Documentar os bytes em:
```
ios/OpenWhoop/BLE/Commands.swift
// Adicionar comment: /// Verified payload from PacketLogger capture YYYYMMDD
```

---

## Passo 7 — Guardar evidências

```bash
# Criar directório de evidências
mkdir -p re/capture/evidence/haptics_ios_YYYYMMDD/

# Guardar o ficheiro .pklg
cp ~/Downloads/whoop5_haptics_YYYYMMDD.pklg re/capture/evidence/haptics_ios_YYYYMMDD/

# Exportar screenshot do PacketLogger com o pacote identificado
# PacketLogger → File → Export → CSV
```

---

## Notas

- O perfil de logging pode abrandar ligeiramente o BLE no iPhone — remover após a captura
  (Definições → Geral → VPN e Gestão de Dispositivos → Perfil → Remover)
- O log `.pklg` pode ser aberto no Wireshark com dissector BLE (File → Open, seleccionar BLE dissector)
- Se o WHOOP não buzzer com nenhum trigger da app oficial, tentar: conectar o WHOOP a um carregador
  enquanto a app está aberta — o WHOOP confirma o início de carga com um buzz
