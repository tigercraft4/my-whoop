---
date: "2026-06-01 19:00"
promoted: false
---

# Descobertas BLE sync 2026-06-01

## Bugs corrigidos (backfill não funcionava)

1. **CRC32 trailer zeros** — WHOOP 5.0 descarta silenciosamente frames com trailer `00 00 00 00`. Fix: CRC32(body[4:]) = CRC32([ptype][seq][cmd][payload]) guardado como u32 LE.

2. **Token errado** — token `00 00 00` vs lookup by payload_len da app oficial. Fix: mapeamento verificado na captura PacketLogger (228 frames). pl=1→01E671, pl=9→01E0D1, pl=65→01F3B1, etc.

3. **endData offset errado (Gen4 vs Maverick)** — Backfiller.endData() usava `frame[17:25]` (Gen4). Para Maverick: `frame[21:29]`. Resultado: trim=60 constante → cursor nunca avançava → mesmos dados em cada ligação.

4. **numFF offset errado** — payloadOff+2 dava 1 em vez de 15 features. Fix: payloadOff+3.

5. **SET_CLOCK 8 bytes em vez de 9** — captura mostra 9 bytes (4 timestamp + 5 zeros).

6. **FD4B0003 CCCD não confirmado antes dos comandos** — handshake movido para `didUpdateNotificationStateFor`.

7. **Write type .withoutResponse** — WHOOP 5.0 ignora silenciosamente ATT Write Commands. Fix: .withResponse.

## Protocolo Maverick verificado

- CRC32: `CRC32(body[4:])` = CRC32([ptype=0x23][seq][cmd][payload])
- Token: determinístico por payload_len (lookup table de 228 frames)
- FD4B0003: responses; FD4B0004: events; FD4B0005: data (type-47 histórico)
- type=47 = HISTORICAL_DATA; type=49 = METADATA (HISTORY_START/END/COMPLETE)

## Haptics VERIFIED

Payload cmd=0x13: `[0x01, 0x2F, 0x98, 0x00×8, 0x01, 0x00]` (13 bytes)
Confirmado por HAPTICS_FIRED (event 60) + HAPTICS_TERMINATED (event 100).

## Arquitectura offline-first

- Server: upload only (backup). pullFromServer() = no-op.
- LocalMetricsComputer: Recovery (HRV baseline 28 noites), Strain (TRIMP zones), Sleep Performance (ALG-10), Training State (ALG-11), Sleep Needed (ALG-12), Calories (ALG-13 Mifflin–St Jeor).
- Profile local: UserDefaults "com.openwhoop.profile.v1".
