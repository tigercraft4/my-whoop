# Wearable — WHOOP 5.0

## What This Is

A clean fork of the WHOOP 4.0 reverse-engineering project, targeting the WHOOP 5.0 hardware. Three milestones shipped: v1.0 characterised the Maverick BLE protocol and built the decode stack; v2.0 completed the iOS app with WHOOP-style UI, full algorithm pipeline, and HealthKit export; v3.0 achieved WHOOP parity — correct UI labels (IPA-verified), Sleep Performance scoring, Training State, Sleep Needed, and Calories algorithms equivalent to the official WHOOP app.

## Core Value

Own your WHOOP 5.0 biometric data: read it from your own device over BLE, store it locally, and analyse it without any dependency on WHOOP's cloud.

## Current Milestone: v4.0 — UI Redesign + Bug Fix

**Goal:** Análise completa do IPA WHOOP via Ghidra para redesign 1:1 da app iOS, correcção de bugs críticos, e reorganização da estrutura do repositório.

**Target features:**
- Ghidra IPA deep-dive — mapear TODOS os ecrãs, flows e componentes da app oficial (5.37.0)
- UI 1:1 redesign — replicar cada ecrã exactamente com base nos findings do Ghidra
- Bug fixes — HRV/RR offsets, backfill stuck, UI placeholders, + bugs identificados via Ghidra
- PROTO-11/12/13/14 — validação biométrica (hardware-dependente, quando disponível)
- Repo cleanup — reorganizar pastas/estrutura do repositório, sem mudanças de arquitectura

## Current State (post-v3.0)

All three milestones shipped. The app is functionally complete. Remaining items are hardware-validation backlog (999.1, 999.2) that require physical Android device or dedicated WHOOP capture sessions.

**Shipped:**
- iOS app with 5-tab WHOOP-style UI (Today, Sleep, Strain, Trends, Device)
- Full backfill pipeline (16000+ historical frames decoded)
- All v3.0 algorithms: Sleep Performance, Training State, Sleep Needed, Calories
- HealthKit export (HR, HRV, Sleep stages)
- Haptics Gen5 verified via PacketLogger (RunAppDrivenHapticsCommandPacket payload confirmed)

**Pending (hardware-dependent):**
- PROTO-11/12/13/14: SpO₂, skin temp, respiration, IMU — TOGGLE_IMU_MODE capture needed
- IOS-03/04/08: End-to-end views with real WHOOP data — requires dedicated session without official app
- Android btsnoop + JADX APK navigation (Phase 999.1)

## Requirements

### Validated

**v1.0 — Protocol + iOS App**
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

**v2.0 — Complete iOS + WHOOP-Style UI + Algorithms**
- ✓ BF-01/02: Backfill pipeline fixed end-to-end — 16000+ historical frames, safe-trim invariant — v2.0
- ✓ UI-01: JADX APK analysis — 5-tab structure documented, field-to-model mapping — v2.0
- ✓ UI-02: Tab bar WHOOP-style (Today/Sleep/Strain/Trends/Device), @SceneStorage — v2.0
- ✓ UI-03: Recovery card (score, HRV, RHR, sleep performance ring) — v2.0
- ✓ UI-04: Sleep card (duration, efficiency, HypnogramView with REM/Deep/Light/Awake) — v2.0
- ✓ UI-05: Strain card (gauge 0–21, HR zones breakdown) — v2.0
- ✓ ALG-01: Recovery score computed server-side, shown in Today view — v2.0
- ✓ ALG-02: Sleep staging (Cole-Kripke) in Sleep view — v2.0
- ✓ ALG-03: Strain score (Edwards TRIMP) in Strain view — v2.0
- ✓ ALG-04: GET /v1/today endpoint — v2.0
- ✓ HK-01: HR samples exported to HealthKit — v2.0
- ✓ HK-02: HRV RMSSD exported to HealthKit — v2.0
- ✓ HK-04: Sleep sessions exported to HealthKit with stage mapping — v2.0
- ✓ HK-05: HealthKit authorization lazy in Today view — v2.0
- ✓ IOS-05: Trends view with real HR/HRV/SpO₂/skin temp time series — v2.0

**v3.0 — WHOOP Parity**
- ✓ ALG-10: Sleep Performance score ponderado 0–100 (weighted: duração 45%, eficiência 25%, staging 20%, consistência 10%) — v3.0
- ✓ ALG-11: Training State (RESTORATIVE / OPTIMAL / OVERREACHING / null) via recovery_to_strain.json lookup — v3.0
- ✓ ALG-12: Sleep Needed = baseline 7d + strain_debt + sleep_debt, clamp [300–660 min] — v3.0
- ✓ ALG-13: Total Calories = RMR (Mifflin–St Jeor) + exercise_kcal; iOS MetricCard "CALORIES" — v3.0
- ✓ SleepView: "SLEEP PERFORMANCE" / "HOURS OF SLEEP" / SKIN TEMP from baseline labels — v3.0
- ✓ StrainCard: Training State badge from server (fallback client-side) — v3.0
- ✓ MetricKind.sleepPerformance as primary Trends metric — v3.0
- ✓ Haptics Gen5: RunAppDrivenHapticsCommandPacket payload VERIFIED via PacketLogger — v3.0
- ✓ GRDB migration v9 (4 new DailyMetric columns: sleepPerformance, trainingState, sleepNeededMin, totalCaloriesKcal) — v3.0

### Active (hardware-dependent backlog)

- [ ] IOS-03: Today view com dados reais — recovery score, HRV, sono summary (requer WHOOP sem sync há 1+ semana)
- [ ] IOS-04: Sleep view com sessões de sono históricas reais
- [ ] IOS-08: Background reconnect após force-quit validado (30s test on physical iPhone)
- [ ] PROTO-11: SpO₂ VERIFIED (captura TOGGLE_IMU_MODE + oxímetro ground truth)
- [ ] PROTO-12: Skin temperature VERIFIED (termómetro ground truth)
- [ ] PROTO-13: Respiration rate VERIFIED (12–20 rpm)
- [ ] PROTO-14: IMU/gravity VERIFIED (6-axis accelerometer, sample rate documentado)
- [ ] HK-03: SpO₂ export HealthKit — gateado atrás de PROTO-11 VERIFIED
- [ ] BF-02 (end-to-end): 14+ day backfill with safe-trim invariant — requires dedicated session

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
- **Codebase state (v3.0):** ~15,364 LOC Swift, ~400k (server incl. deps)
- **Tech stack:** Swift + CoreBluetooth + GRDB + HealthKit (iOS), Python + FastAPI + TimescaleDB (server), openwhoop-algos (algoritmos base)
- **Server:** Running on gonzaga via Dockge, image GHCR, docker compose stack
- **Algorithm source of truth:** LocalMetricsComputer (iOS, offline-first); servidor como backup apenas
- **Known insight:** Maverick CRC32 trailer obrigatório — WHOOP 5.0 descarta silenciosamente frames com trailer errado. CRC32(body[4:]) LE.

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
| JADX for UI structure reference | Understand data hierarchy; implement from scratch in SwiftUI — not copy | ✓ v2.0 — 5 tabs documented |
| openwhoop-algos for Recovery/Strain/Sleep | Existing open-source approximation, avoid trade-secret territory | ✓ v2.0 — integrated |
| HealthKit export | Standard Apple framework; keeps data local | ✓ v2.0 — HR/HRV/Sleep exported |
| Algorithm pipeline local (offline-first) | Servidor backup only; LocalMetricsComputer fonte de verdade | ✓ v3.0 — decisão correcta |
| Training State lookup table bundled | recovery_to_strain.json bundled; computado localmente | ✓ v3.0 |
| Mifflin-St Jeor para RMR | Distinto de Harris-Benedict (_COEFFS) já usado para burn por bout | ✓ v3.0 |
| Haptics Gen5 via RunAppDrivenHapticsCommandPacket | Payload verificado via PacketLogger — 13 bytes, DRV2605 waveform effects | ✓ v3.0 |
| endData offset Maverick (frame[21:29]) | Bug corrigido — não frame[17:25] como Gen4; trim cursor agora avança | ✓ v3.0 |

---

## Evolution

**After v1.0 (2026-05-31):**
- Framing characterised: Maverick wrapper asymmetric read/write
- iOS app validated on iPhone 16 Pro Max (IOS-01/02 VERIFIED)
- Server ported and running on gonzaga
- Open: backfill bug, 5 hardware-dependent items, 4 HYPOTHESIS biometric offsets

**After v2.0 (2026-05-31):**
- Backfill pipeline fixed — 16000+ historical frames synced
- WHOOP-style UI shipped: 5 tabs, Recovery/Sleep/Strain cards
- HealthKit export functional
- Algorithms (Recovery, Sleep staging, Strain, Sleep Performance) server-computed
- Open: hardware-dependent PROTO-11/12/13/14 and IOS-03/04/08

**After v3.0 (2026-06-01):**
- WHOOP parity achieved: UI labels corrected via IPA analysis (WHOOP 5.37.0)
- ALG-10–13 implemented: Sleep Performance, Training State, Sleep Needed, Calories
- Haptics Gen5 payload VERIFIED (PacketLogger 2026-06-01)
- endData offset bug corrected; trim cursor advances correctly
- LocalMetricsComputer as sole source of truth; server is backup only
- Open: hardware-dependent backlog (999.1 Android, 999.2 hardware validation)

---
*Last updated: 2026-06-01 after v3.0 milestone*
