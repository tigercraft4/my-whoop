# Research Summary — WHOOP 5.0 BLE Reverse Engineering

**Synthesized:** 2026-05-30
**Confidence:** HIGH on workflow · MEDIUM on 5.0 wire specifics (need live captures) · LOW on ECG pathway (virgin territory)

---

## The Headline Discovery

**This is a port, not a rewrite.** Three public RE projects already exist:
- [`Sophonbot0/whoop-vault`](https://github.com/Sophonbot0/whoop-vault) — decompiled the WHOOP Android APK at firmware r52, documented the "Maverick" frame format
- [`Sivasai2207/WHOOP-Reverse-Engineering-5.0`](https://github.com/Sivasai2207/WHOOP-Reverse-Engineering-5.0) — Kotlin/Android, 2026; confirms dual UUIDs and reused enums
- [`julienlhk/whoop`](https://github.com/julienlhk/whoop) — independently confirms the new service UUID on firmware 50.37.1.0

**The 4.0 inner framing is reused unchanged** — same `0xAA` SOF, len-LE-u16, CRC8, type/seq/cmd, payload, CRC32-LE. The 5.0 adds a Maverick outer wrapper (version, length, role bytes, CRC16 + 4-byte-aligned inner buffer). The 4.0 command and event ID enums carry forward. Making the GATT layer prefix-agnostic is the core porting task.

---

## Recommended Stack

| Tool | Role |
|------|------|
| **JADX-GUI 1.5.1** on official WHOOP Android APK | **Primary protocol source** — whoop-vault already mapped 5.0 this way |
| **Apple PacketLogger** (Xcode Additional Tools) + iOS Bluetooth Logging `.mobileconfig` | Primary live capture — iPhone tethered to Mac, post-decryption HCI |
| **Android HCI snoop log** via Developer Options → `adb bugreport` | Secondary live capture for cross-validation (Pixel preferred) |
| **Wireshark 4.4.x** | Analyse both `.pklg` and `.btsnoop`; build Lua dissector after schema stabilises |
| **nRF Connect for Mobile** + **Bleak 0.22 (Python)** | GATT enumeration and scripted probes |

**Skip:** nRF52840 hardware sniffer — HCI logs already give decrypted GATT, RF sniffers add friction and the LTK problem.

**Critical:** Install `iOSBluetoothLogging.mobileconfig` profile on iPhone *before* using PacketLogger, or the iOS trace is empty.

---

## Protocol: 4.0 → 5.0 Differences

**Hard-confirmed:**
- New GATT service prefix: `fd4b0001-cce1-4033-93ce-002d5875f58a` (7 chars: `…0002` cmd-in, `…0003` cmd-resp, `…0004` events, `…0005` data, `…0007` diagnostics)
- Legacy `61080001-…` may also be present (model-dependent — needs verification on user's device)
- **Same inner framing** — `0xAA` SOF, CRC8(poly 0x07), CRC32-zlib, same byte layout
- **Same command enums** — IDs 1, 2, 3, 7, 11, 14, 22, 26, 35, 81, 82, 106, 107, 145 reused
- **Same event enums** — IDs 3, 7, 8, 9, 10, 17, 24, 33, 46, 63 reused
- New Maverick outer wrapper around the `0xAA` inner frame

**Plausible, needs live capture to confirm:**
- Skin-temp in event 17 payload: 4-byte LE int / 100000 → °C
- SpO₂% in metadata type 53, byte 10
- Raw-data sample rate possibly 26 Hz (vs 4.0's 52 Hz)
- Longer historical buffer than 14 days

**Do not trust without validation:**
- Sivasai2207's claim that `REALTIME_DATA` type changed from `0x14` to `0x28` — conflicts with 4.0 established truth, likely transcription error

---

## Build Order

Python discovery loop first. iOS last. (Swift iteration is 10–100× slower for byte-level work; CoreBluetooth requires physical device.)

1. **Capture Foundation** — JADX-GUI setup, PacketLogger + mobileconfig, Android btsnoop, Wireshark, nRF Connect. Verify capture quality before any analysis.
2. **GATT Survey + Bonding** — confirm `fd4b0001-…` on user's device, replicate bonding, confirm `61080001-…` status, read standard HR/battery as quick win.
3. **Framing Confirmation (THE GATE)** — run 4.0 CRC8/CRC32 validator against 20+ captured 5.0 frames. CRC validates → Phase 4 fast. CRC fails → characterise Maverick wrapper. **Do not lock schema before this passes.**
4. **Command Surface + Standard Streams** — port `re_harness.py`, probe IDs 0–255, decode responses, lock dual-epoch timestamp model.
5. **Realtime + Historical Decode** — events + temp, historical offload with store-then-ack discipline, IMU decode, goldens.
6. **iOS Port + Product Pipeline** — only now fork Swift packages, spike CoreBluetooth end-to-end, re-skin product pipeline.
7. **Research Milestones** — validate raw PPG on new AFE, hunt MG ECG pathway (virgin territory — own milestone).

---

## Top 5 Pitfalls

1. **Assuming 5.0 inner framing == 4.0 without confirming.** Validate CRC8/CRC32 on 20 frames in Phase 3 before reusing any decoder code. Gate: >98% pass rate required.
2. **RF sniffer instead of HCI log.** HCI snoop sits above link-layer encryption. RF sniffers see ciphertext without the LTK — useless on bonded links.
3. **Missing the bond handshake in the capture.** Start logger 5s before app connects; force fresh bonding (Forget device first). Verify SMP packets + `ATT_EXCHANGE_MTU_REQ` are visible in capture.
4. **Conflating device epoch with Unix epoch.** `GET_CLOCK` returns device-relative seconds (~31.5M). `GET_DATA_RANGE` returns Unix. Tag every schema timestamp field `"epoch": "device"|"unix"`. Recompute `clockRef` on every reconnect.
5. **Historical offload trim/ack — data loss risk.** Store → fsync → ack. Never ack before durable persist. Idempotent ingest with `ON CONFLICT DO NOTHING`. Test by intentionally killing during pending ack.

---

## Open Questions (Only Live Captures Can Answer)

| Question | Phase to resolve |
|----------|-----------------|
| Is `fd4b0001-…` advertised by this specific 5.0 unit, or only by MG? | Phase 2 |
| Does 4.0 inner framing (CRC8/CRC32) validate on 5.0? | Phase 3 |
| Is skin-temp really in event 17 as LE-int / 100000? | Phase 5 |
| Is raw-data sample rate 52 Hz or 26 Hz on 5.0? | Phase 5 |
| What commands trigger MG ECG capture? | Phase 7 |
| Has firmware drift changed any whoop-vault enums between r52 and user's installed firmware? | Throughout |

---

## Scope Reduction Summary

Everything WHOOP markets as "new on 5.0" that isn't ECG/BP (Healthspan, Hormonal Insights, Pace of Aging, WHOOP Age) is **cloud-computed** on signals that already exist in the 4.0 wire. They require no new BLE decoding.

The three genuine additions vs 4.0:
- Maverick outer wrapper handling
- Skin-temperature decode (plausible, unvalidated)
- MG ECG pathway (virgin RE — separate milestone)
