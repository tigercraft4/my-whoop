# Wearable — WHOOP 5.0

## What This Is

A clean fork of the existing WHOOP 4.0 reverse-engineering project, targeting the WHOOP 5.0 hardware. v1.0 shipped a fully characterised 5.0 BLE protocol (Maverick outer wrapper documented), a canonical decode schema (`whoop_protocol_5.json`), a Python decoder, and a functional iOS app connecting to the WHOOP 5.0 end-to-end — backed by an optional self-hosted FastAPI + TimescaleDB server.

## Core Value

Own your WHOOP 5.0 biometric data: read it from your own device over BLE, store it locally, and analyse it without any dependency on WHOOP's cloud.

## Requirements

### Validated (v1.0)

- ✓ WHOOP 5.0 BLE protocol fully characterised — Maverick outer wrapper (0xAA 0x01, len at buf[2..3], role, flat body) — v1.0
- ✓ `protocol/whoop_protocol_5.json` canonical decode schema — confidence-tagged, dual-epoch, synced to Swift bundle — v1.0
- ✓ `FINDINGS_5.md` canonical protocol reference — framing, commands, events, historical offload — v1.0
- ✓ Python decoder (`decode_5.py`, `parse_body_5`, `load_schema_5()`) — all decoded types — v1.0
- ✓ Swift decoder (`parseFrame()` + `stripMaverick()` + `extractStreams()`) — 72/72 tests, byte-for-byte parity with Python — v1.0
- ✓ iOS app bonds to WHOOP 5.0 on physical iPhone — live HR confirmed (~75 bpm) — v1.0
- ✓ WhoopStore migration v8 (gx/gy/gz nullable) — v1.0
- ✓ FastAPI + TimescaleDB server ported (device_generation, ingest-decoded, compute_day) — v1.0
- ✓ RE toolchain established (PacketLogger, Wireshark, bleak, nRF Connect runbooks) — v1.0
- ✓ Golden fixtures (19 Maverick-wrapped frames, cross-validated Python ↔ Swift) — v1.0

### Active (v2.0 targets)

- [ ] PROTO-02 D-03b: SMP PacketLogger capture during official-app bonding (physical action required)
- [ ] IOS-03/04/05: Today/Sleep/Trends views validated with real WHOOP 5.0 data (requires WHOOP with unsynced data)
- [ ] IOS-06: 14+ day historical backfill end-to-end with safe-trim invariant validated
- [ ] IOS-08: Background reconnect after force-quit validated (physical test)
- [ ] IMU/SpO2/skin temp/respiration decode VERIFIED (requires TOGGLE_IMU_MODE capture — PROTO-11/12/13/14)
- [ ] TOOL-02/03: Android btsnoop capture + JADX APK navigation (requires Android device)

### Out of Scope

- WHOOP 4.0 support in this fork — separate repo handles it
- Dual 4.0/5.0 in single fork — over-complex before protocol fully understood (revisit in v2.0+)
- WHOOP MG ECG pathway — virgin RE territory, separate milestone
- macOS app / watchOS complications / Android app
- WHOOP cloud API integration — local-first by design
- Clinical validation of biometric computations — personal/educational use only
- Firmware modification — RE only, no writes to the strap

## Context

- **Hardware available:** WHOOP 5.0, iPhone 16 Pro Max (validated end-to-end in v1.0), Mac
- **Android:** Not available during v1.0 — Android runbooks complete but untested live
- **v1.0 codebase state:** ~17,500 LOC Swift, ~30,400 LOC Python
- **Tech stack:** Swift + CoreBluetooth + GRDB (iOS), Python + bleak (RE), FastAPI + TimescaleDB (server), JSON schema (protocol canonical source)
- **Key insight from v1.0:** WHOOP 5.0 is asymmetric — accepts 4.0 format writes (commands from phone), sends Maverick format reads (responses from device). This was undocumented and required full RE to discover.
- **Server:** Running on gonzaga via Dockge, image GHCR, docker compose stack

## Constraints

- **Hardware:** WHOOP 5.0 only — no simulator, physical device required for all BLE work
- **Capture platform:** Mac required for PacketLogger; iOS PacketLogger requires Xcode pairing
- **Legal:** 17 U.S.C. §1201(f) interoperability, own device, own data, no proprietary material reproduced
- **No root/jailbreak:** iPhone and Android are stock — techniques limited to HCI logging and passive capture
- **iOS deployment:** iOS 16+ on iPhone; SwiftUI + CoreBluetooth + GRDB architecture

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Clean fork (not dual-support) | Protocol may be substantially different; don't pollute 4.0 codebase | ✓ Correct — Maverick wrapper required new strip_maverick path |
| Mac PacketLogger as primary capture | No jailbreak needed, captures full HCI including app traffic, Apple-native | ✓ Correct — all corpus captured this way |
| Android HCI log as secondary source | Second independent capture to cross-reference | — Deferred (no Android device) |
| Same architecture as 4.0 | Proven design; reuse Swift packages, server pipeline, schema-driven decode | ✓ Correct |
| Phase 3 as explicit CRC gate | All decode work wasted if framing wrong | ✓ Critical — 0% CRC triggered Maverick RE |
| Python discovery before Swift | Byte-level RE is 10–100× faster in Python | ✓ Correct — saved days |
| D-11: 4.0 writes / Maverick reads asymmetry | WHOOP 5.0 reads 4.0 commands, sends Maverick responses | ✓ Resolved — key v1.0 protocol discovery |

---

## Evolution

**After v1.0 (2026-05-31):**
- Framing characterised: Maverick wrapper asymmetric read/write
- iOS app validated on iPhone 16 Pro Max (IOS-01/02 VERIFIED)
- Server ported and running on gonzaga
- Open: 5 hardware-dependent items (IOS-03/04/05/06/08), 4 HYPOTHESIS biometric offsets, 1 partial PROTO-02

---
*Last updated: 2026-05-31 after v1.0 milestone*
