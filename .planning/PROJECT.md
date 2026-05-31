# Wearable — WHOOP 5.0

## What This Is

A clean fork of the existing WHOOP 4.0 reverse-engineering project, targeting the WHOOP 5.0 hardware. v1.0 shipped a fully characterised 5.0 BLE protocol (Maverick outer wrapper documented), a canonical decode schema, a Swift + Python decoder stack, and a functional iOS app connecting to the WHOOP 5.0. v2.0 completes the product: fix the backfill pipeline, validate all biometric streams, redesign the UI to match the WHOOP app experience (via JADX APK analysis), integrate Recovery/Strain/Sleep algorithms, and add HealthKit export.

## Core Value

Own your WHOOP 5.0 biometric data: read it from your own device over BLE, store it locally, and analyse it without any dependency on WHOOP's cloud.

## Current Milestone: v2.0 — Complete iOS + WHOOP-Style UI + Algorithms

**Goal:** Transformar a app num cliente completo do WHOOP 5.0 — backfill funcional, UI WHOOP-style, todos os streams biométricos VERIFIED, algoritmos de Recovery/Strain/Sleep integrados e HealthKit export.

**Target features:**
- Fix backfill pipeline (Backfiller não puxa dados históricos do WHOOP 5.0)
- JADX APK analysis + UI redesign: WHOOP-style tab bar, recovery/sleep/strain cards em SwiftUI
- Validar IOS-03/04/05/06/08 com dados reais do WHOOP
- Captura TOGGLE_IMU_MODE → IMU/SpO₂/skin temp/respiration VERIFIED (PROTO-11/12/13/14)
- Recovery score, Sleep staging, Strain via openwhoop-algos integrados na app
- HealthKit: exportar HR, HRV, SpO₂, sono para a app Saúde do iPhone

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

**Pipeline fix:**
- [ ] BF-01: Backfiller funciona end-to-end — puxa dados históricos do WHOOP 5.0 sem ficar preso
- [ ] BF-02: Backfill 14+ dias com safe-trim invariant e sem perda de dados (IOS-06)

**iOS validation:**
- [ ] IOS-03: Today view com dados reais — recovery score, HRV, sono summary
- [ ] IOS-04: Sleep view com sessões de sono históricas reais
- [ ] IOS-05: Trends view com gráficos HR/HRV/SpO₂/skin temp reais
- [ ] IOS-08: Background reconnect após force-quit validado

**Biométricos:**
- [ ] PROTO-11: SpO₂ VERIFIED (captura dedicada + ground truth oxímetro)
- [ ] PROTO-12: Skin temperature VERIFIED (captura dedicada + termómetro)
- [ ] PROTO-13: Respiration rate VERIFIED
- [ ] PROTO-14: IMU/gravity VERIFIED (TOGGLE_IMU_MODE capture)

**UI:**
- [ ] UI-01: JADX APK analysis → estrutura dos ecrãs documentada (o que mostra onde)
- [ ] UI-02: Tab bar inferior WHOOP-style (Overview/Sleep/Strain/Coach + Device tab)
- [ ] UI-03: Recovery card — score, HRV, RHR, sleep performance
- [ ] UI-04: Sleep card — duração, eficiência, fases (REM/Deep/Light)
- [ ] UI-05: Strain card — daily strain score, HR zones

**Algoritmos:**
- [ ] ALG-01: Recovery score calculado no servidor (openwhoop-algos) e mostrado na app
- [ ] ALG-02: Sleep staging (REM/Deep/Light) via openwhoop-algos
- [ ] ALG-03: Strain score (TRIMP/HR zones) via openwhoop-algos

**HealthKit:**
- [ ] HK-01: Exportar HR amostras para HealthKit
- [ ] HK-02: Exportar HRV (SDNN/RMSSD) para HealthKit
- [ ] HK-03: Exportar SpO₂ para HealthKit (quando VERIFIED)
- [ ] HK-04: Exportar sessões de sono para HealthKit

### Out of Scope

- WHOOP 4.0 support in this fork — separate repo handles it
- WHOOP MG ECG pathway — virgin RE territory, separate milestone
- macOS app / watchOS complications / Android app
- WHOOP cloud API integration — local-first by design
- Clinical validation of biometric computations — personal/educational use only
- Firmware modification — RE only, no writes to the strap
- Copiar assets, artwork ou código proprietário do WHOOP — apenas referência para estrutura de dados/UI

## Context

- **Hardware available:** WHOOP 5.0, iPhone 16 Pro Max, Mac
- **v1.0 codebase state:** ~17,500 LOC Swift, ~30,400 LOC Python
- **Tech stack:** Swift + CoreBluetooth + GRDB + HealthKit (iOS), Python + bleak (RE), FastAPI + TimescaleDB + openwhoop-algos (server)
- **Key v1.0 insight:** WHOOP 5.0 asymmetric — 4.0 writes, Maverick reads (D-11)
- **Server:** Running on gonzaga via Dockge, image GHCR, docker compose stack
- **Known blocker:** Backfiller fica preso / não puxa dados históricos — must fix before iOS views can be validated

## Constraints

- **Hardware:** WHOOP 5.0 only — no simulator, physical device required for BLE work
- **Capture platform:** Mac required for PacketLogger; iOS PacketLogger requires Xcode pairing
- **Legal:** §1201(f) interoperability — JADX APK for protocol/structure reference only; no copyrighted material reproduced
- **No root/jailbreak:** Stock devices only
- **iOS deployment:** iOS 16+ on iPhone; SwiftUI + CoreBluetooth + GRDB + HealthKit

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Clean fork (not dual-support) | Protocol substantially different from 4.0 | ✓ Correct — Maverick wrapper required new path |
| Mac PacketLogger as primary capture | No jailbreak, full HCI decrypted | ✓ Correct |
| Phase 3 CRC gate | All decode wasted if framing wrong | ✓ Critical — 0% CRC triggered Maverick RE |
| Python before Swift for RE | 10–100× faster for byte-level work | ✓ Correct |
| D-11: 4.0 writes / Maverick reads | WHOOP 5.0 accepts 4.0 commands, sends Maverick responses | ✓ Resolved |
| JADX for UI structure reference | Understand data hierarchy; implement from scratch in SwiftUI — not copy | — Pending (v2.0) |
| openwhoop-algos for Recovery/Strain/Sleep | Existing open-source approximation, avoid trade-secret territory | — Pending (v2.0) |
| HealthKit export | Standard Apple framework; keeps data local while integrating with ecosystem | — Pending (v2.0) |

---

## Evolution

**After v1.0 (2026-05-31):**
- Framing characterised: Maverick wrapper asymmetric read/write
- iOS app validated on iPhone 16 Pro Max (IOS-01/02 VERIFIED)
- Server ported and running on gonzaga
- Open: backfill bug, 5 hardware-dependent items, 4 HYPOTHESIS biometric offsets

**v2.0 goals (2026-05-31):**
- Fix backfill pipeline
- Complete iOS validation with real data
- WHOOP-style UI via JADX reference
- All biometric streams VERIFIED
- Recovery/Strain/Sleep algorithms integrated
- HealthKit export

---
*Last updated: 2026-05-31 — Phase 11 complete: HealthKit export (HR, HRV, Sleep) implemented; HK-03 deferred per PROTO-11*
