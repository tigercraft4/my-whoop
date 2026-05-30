# Requirements — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)
**Version:** v1
**Date:** 2026-05-30

---

## v1 Requirements

### RE Tooling & Capture Setup

- [ ] **TOOL-01**: Developer can capture live BLE traffic from WHOOP 5.0 using PacketLogger on Mac (iPhone tethered, iOS Bluetooth Logging mobileconfig installed)
- [ ] **TOOL-02**: Developer has a documented, reproducible workflow for Android HCI snoop log capture (Developer Options → btsnoop_hci.log → adb bugreport extraction)
- [ ] **TOOL-03**: Developer can decompile the official WHOOP Android APK using JADX-GUI to reference packet type / command enum definitions
- [ ] **TOOL-04**: Developer can load `.pklg` and `.btsnoop` captures in Wireshark and filter by ATT/GATT layer

### Protocol Discovery (RE Phase)

- [ ] **PROTO-01**: WHOOP 5.0 GATT service UUID(s) confirmed on user's specific device (fd4b0001-... and/or legacy 61080001-... presence documented)
- [ ] **PROTO-02**: BLE bonding replicated without the official WHOOP app (confirmed-write trick or equivalent on 5.0)
- [ ] **PROTO-03**: GATT characteristics enumerated and mapped (7 characteristics: cmd-in, cmd-resp, events, data, diagnostics + standard HR + battery)
- [ ] **PROTO-04**: 4.0 inner framing (0xAA SOF / CRC8 poly 0x07 / CRC32-zlib) validated against 20+ captured 5.0 frames (≥98% pass rate gate)
- [ ] **PROTO-05**: Maverick outer wrapper (version, length, role bytes, CRC16) characterised if 4.0 CRC validation fails — structure documented in whoop_protocol_5.json
- [ ] **PROTO-06**: Command surface probed (IDs 0–255 enumerated via probe harness; known commands from 4.0 cross-checked)
- [ ] **PROTO-07**: Live HR + RR intervals decoded from realtime stream
- [ ] **PROTO-08**: Battery level decoded
- [ ] **PROTO-09**: Events decoded (IDs 3, 7, 8, 9, 10, 17, 24, 33, 46, 63 — same as 4.0)
- [ ] **PROTO-10**: Historical data offload implemented with store-then-ack discipline (data not lost on crash)
- [ ] **PROTO-11**: SpO₂ decoded (type 53, byte 10 per Sivasai2207 — validate against oximeter)
- [ ] **PROTO-12**: Skin temperature decoded from event 17 (LE-int / 100000 → °C — validate against thermometer)
- [ ] **PROTO-13**: Respiration rate decoded
- [ ] **PROTO-14**: IMU / gravity (6-axis accelerometer) decoded; sample rate confirmed (52 Hz or 26 Hz)
- [ ] **PROTO-15**: Dual-epoch timestamp model implemented (device epoch vs Unix epoch tagged in schema)
- [ ] **PROTO-16**: Firmware version recorded in every capture session metadata

### Schema & Documentation

- [ ] **SCHEMA-01**: `protocol/whoop_protocol_5.json` — canonical decode schema for WHOOP 5.0, schema-driven (same pattern as 4.0's whoop_protocol.json)
- [ ] **SCHEMA-02**: All schema fields include `"epoch"` tag, provenance note, and confidence level (`VERIFIED` / `HYPOTHESIS`)
- [ ] **SCHEMA-03**: `FINDINGS_5.md` — protocol reference document covering framing, commands, events, data layout, timestamps, historical offload
- [ ] **SCHEMA-04**: Golden fixture files generated for each decoded packet type (cross-source validated: iOS + Android captures)
- [ ] **SCHEMA-05**: `scripts/sync-schema-5.sh` — syncs canonical 5.0 schema to Swift bundle resource

### Swift Decoder (WhoopProtocol 5.0)

- [ ] **SWIFT-01**: `Packages/WhoopProtocol/` forked / updated to support 5.0 schema (`whoop_protocol_5.json`)
- [ ] **SWIFT-02**: `parseFrame()` handles Maverick outer wrapper (if present) + existing 0xAA inner frame
- [ ] **SWIFT-03**: `extractStreams()` decodes all v1 biometric streams (HR, RR, SpO₂, skin temp, resp, IMU, events, battery)
- [ ] **SWIFT-04**: `extractHistoricalStreams()` decodes historical data backfill from 5.0
- [ ] **SWIFT-05**: Swift package unit tests pass with 5.0 golden fixtures (cross-language parity with Python decoder)
- [ ] **SWIFT-06**: Python `whoop_protocol` package updated to support 5.0 schema (shared canonical JSON)

### iOS App

- [ ] **IOS-01**: App connects and bonds to WHOOP 5.0 via CoreBluetooth (on physical iPhone — no Simulator)
- [ ] **IOS-02**: Live view shows real-time HR, battery level, and BLE connection status
- [ ] **IOS-03**: Today view shows daily recovery score, HRV, sleep summary
- [ ] **IOS-04**: Sleep view shows historical sleep sessions
- [ ] **IOS-05**: Trends view shows charts of HR, HRV, SpO₂, skin temp over time
- [ ] **IOS-06**: Historical backfill (14+ days) works end-to-end with safe-trim invariant
- [ ] **IOS-07**: App works fully offline (server is optional; `AppConfig.uploaderConfig()` returns nil on placeholder values)
- [ ] **IOS-08**: CoreBluetooth state preservation configured (`CBCentralManagerOptionRestoreIdentifierKey`, `willRestoreState`) — background reconnect works
- [ ] **IOS-09**: `WhoopStore` schema migrated for 5.0 data types (new migration version)

### Server (FastAPI + TimescaleDB)

- [ ] **SRV-01**: `POST /v1/ingest-decoded` accepts 5.0 decoded streams (device_generation field added)
- [ ] **SRV-02**: Daily analysis pipeline (`compute_day()`) runs after each 5.0 ingest
- [ ] **SRV-03**: `GET /v1/daily-metrics`, `GET /v1/sleep-sessions`, `GET /v1/workouts` return 5.0 data
- [ ] **SRV-04**: TimescaleDB schema migration adds `device_generation` column to hypertables
- [ ] **SRV-05**: Server runs via `docker compose up -d --build` (same as 4.0)

---

## v2 Requirements (Deferred)

- Dual 4.0 + 5.0 support in a single app (too complex before protocol is understood)
- WHOOP MG ECG pathway (virgin RE territory — separate milestone after v1 ships)
- macOS app
- watchOS complications
- Android app
- HealthKit integration
- Automated firmware version detection and schema selection

---

## Out of Scope

- WHOOP 4.0 support in this fork — separate repo handles it
- WHOOP generations 1.0 / 2.0 / 3.0 — different hardware entirely
- WHOOP cloud API — local-first by design
- AFib classification or clinical-grade metrics — not a medical device
- Reproducing any WHOOP proprietary algorithms (Healthspan, WHOOP Age, Hormonal Insights, BP Insights) — cloud-only, out of legal scope
- Firmware modification — RE only, no writes to the strap
- Jailbreak/root-based capture techniques — stock devices only

---

## Traceability

*To be filled by roadmapper — maps REQ-IDs to phases.*

| Requirement | Phase |
|-------------|-------|
| TOOL-01 to TOOL-04 | Phase 1 |
| PROTO-01 to PROTO-03 | Phase 2 |
| PROTO-04 to PROTO-05 | Phase 3 |
| PROTO-06 to PROTO-16, SCHEMA-01 to SCHEMA-05 | Phase 4–5 |
| SWIFT-01 to SWIFT-06 | Phase 6 |
| IOS-01 to IOS-09, SRV-01 to SRV-05 | Phase 6–7 |

---

## Definition of Done

A requirement is **Done** when:
1. The behaviour is observable (live capture shows the decoded value, or app shows the metric)
2. It is validated against a ground truth (thermometer for skin temp, oximeter for SpO₂, HR strap for HR)
3. It has a corresponding golden fixture file in the test suite
4. The schema field is tagged `VERIFIED` (not `HYPOTHESIS`)
