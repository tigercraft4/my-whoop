# Roadmap — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)
**Granularity:** coarse (5 phases)
**Mode:** standard
**Date:** 2026-05-30
**Coverage:** 45/45 v1 requirements mapped

---

## Strategy

This is a **port, not a rewrite**. The 4.0 inner BLE framing (`0xAA` SOF, CRC8 poly 0x07, CRC32-LE, command/event enums) is reused unchanged on 5.0. Only the GATT service UUID prefix changes (`fd4b0001-…` replaces `61080001-…`), with a probable Maverick outer wrapper around the inner frame.

The roadmap is built around the **critical CRC gate in Phase 3**: until ≥98% of captured 5.0 frames validate against the 4.0 CRC algorithms (or the Maverick wrapper is fully characterised), no decoder work begins. This gate is the hinge of the whole project — pass it and Phase 4–5 are largely a port; fail it and Phase 3 expands to a full framing RE.

Phases follow a hard dependency chain: tools → bonding → framing → decode → product.

---

## Phases

- [ ] **Phase 1: Capture Foundation** — All RE tools installed and verified; decrypted 5.0 BLE traffic visible end-to-end
- [ ] **Phase 2: GATT Survey & Bonding** — UUID confirmed on user's device, bonding replicated without official app, standard HR/battery readable
- [ ] **Phase 3: Framing Confirmation (Critical Gate)** — 4.0 inner framing CRC-validated on ≥20 frames OR Maverick wrapper characterised
- [ ] **Phase 4: Protocol Decode & Schema** — All v1 biometric streams decoded and validated; `whoop_protocol_5.json` and `FINDINGS_5.md` complete
- [ ] **Phase 5: iOS App & Server Port** — Functional iOS app connecting to WHOOP 5.0 end-to-end; optional server ingest working

---

## Phase Details

### Phase 1: Capture Foundation
**Goal**: All RE tools installed and verified; developer can capture, extract, and view decrypted WHOOP 5.0 BLE traffic from both iOS and Android sources
**Depends on**: Nothing (first phase)
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TOOL-04
**Success Criteria** (what must be TRUE):
  1. Developer launches PacketLogger on Mac with iPhone tethered and sees ATT-layer traffic during a live WHOOP app ↔ 5.0 strap session (`iOSBluetoothLogging.mobileconfig` installed; no empty trace)
  2. Developer captures an Android `btsnoop_hci.log` via Developer Options + `adb bugreport` extraction, with reproducible written steps in the repo
  3. Developer opens a captured `.pklg` and a captured `.btsnoop` in Wireshark 4.4.x, filters to the ATT/GATT layer, and sees the WHOOP custom service traffic
  4. Developer loads the official WHOOP Android APK in JADX-GUI 1.5.1 and can navigate to the Maverick/packet-type enum definitions (referencing whoop-vault's r52 map)
**Plans**: TBD

### Phase 2: GATT Survey & Bonding
**Goal**: WHOOP 5.0 GATT surface fully enumerated on the user's specific device; bonding replicated without the official app; standard HR and battery characteristics readable
**Depends on**: Phase 1
**Requirements**: PROTO-01, PROTO-02, PROTO-03
**Success Criteria** (what must be TRUE):
  1. GATT services and all 7 custom characteristics (cmd-in `…0002`, cmd-resp `…0003`, events `…0004`, data `…0005`, diagnostics `…0007`, plus standard HR and battery) enumerated via nRF Connect and Bleak, with UUIDs documented per device
  2. Presence (or absence) of legacy `61080001-…` alongside `fd4b0001-…` confirmed on the user's specific 5.0 unit and recorded in `FINDINGS_5.md`
  3. Bleak script bonds to the strap from a fresh state (Forget Device first) without the official WHOOP app running, using the confirmed-write trick or 5.0 equivalent, and SMP packets are visible in PacketLogger
  4. Standard heart-rate characteristic streams live BPM values via Bleak subscription, confirming bond + notifications work end-to-end
**Plans**: TBD

### Phase 3: Framing Confirmation (Critical Gate)
**Goal**: 4.0 inner framing (`0xAA` SOF, len-LE-u16, CRC8 poly 0x07, type/seq/cmd, payload, CRC32-LE) validated against captured 5.0 frames OR the Maverick outer wrapper (version, length, role bytes, CRC16, 4-byte aligned inner buffer) fully characterised. Schema v0 envelope committed.
**Depends on**: Phase 2
**Requirements**: PROTO-04, PROTO-05
**Success Criteria** (what must be TRUE):
  1. ≥20 distinct frames captured from custom characteristics across at least two sessions (mix of cmd-resp, events, data) and replayed through the 4.0 CRC8 + CRC32 validator
  2. Either (a) ≥98% CRC pass rate documented, confirming 4.0 inner framing reuse, OR (b) Maverick outer wrapper structure (version offset, length encoding, role bytes, CRC16 polynomial, inner-buffer alignment) fully reverse-engineered and documented
  3. `protocol/whoop_protocol_5.json` v0 envelope committed with framing section, confidence level explicitly tagged (`VERIFIED` for confirmed parts, `HYPOTHESIS` for unconfirmed), and rationale captured in `FINDINGS_5.md`
  4. Go/no-go decision for Phase 4 recorded in `FINDINGS_5.md` — either "framing locked, decode work cleared" or "wrapper characterised, decode work cleared with wrapper-strip step"
**Plans**: TBD

### Phase 4: Protocol Decode & Schema
**Goal**: All v1 biometric streams decoded and validated against ground truth; `protocol/whoop_protocol_5.json` is complete and schema-driven; `FINDINGS_5.md` is the canonical protocol reference; golden fixtures exist for each packet type.
**Depends on**: Phase 3 (framing gate passed)
**Requirements**: PROTO-06, PROTO-07, PROTO-08, PROTO-09, PROTO-10, PROTO-11, PROTO-12, PROTO-13, PROTO-14, PROTO-15, PROTO-16, SCHEMA-01, SCHEMA-02, SCHEMA-03, SCHEMA-04, SCHEMA-05
**Success Criteria** (what must be TRUE):
  1. `re_harness.py` probes command IDs 0–255, the responding command surface is enumerated, and the 4.0 reused IDs (1, 2, 3, 7, 11, 14, 22, 26, 35, 81, 82, 106, 107, 145) are cross-validated as still functional on 5.0
  2. Live HR + RR intervals, battery level, events (IDs 3, 7, 8, 9, 10, 17, 24, 33, 46, 63), SpO₂ (type 53 byte 10), skin temperature (event 17 LE-int / 100000), respiration rate, and IMU/gravity each stream decoded values that match ground-truth references (oximeter for SpO₂, thermometer for skin temp, HR strap for HR)
  3. Historical data offload runs end-to-end with store-then-ack discipline — an intentional process kill during a pending ack does NOT lose data on the next reconnect (idempotent ingest verified)
  4. `protocol/whoop_protocol_5.json` is complete, every field tagged with `"epoch": "device"|"unix"`, provenance note, and confidence level (`VERIFIED` for ground-truth-matched, `HYPOTHESIS` otherwise); firmware version recorded in every capture session's metadata
  5. Cross-source golden fixtures (iOS PacketLogger + Android btsnoop) exist for every decoded packet type and round-trip through both the Python decoder and the schema validator; `scripts/sync-schema-5.sh` syncs the canonical schema to the Swift bundle resource
**Plans**: TBD

### Phase 5: iOS App & Server Port
**Goal**: Functional iOS app on physical iPhone connecting to WHOOP 5.0 end-to-end (live + historical + offline), with optional FastAPI + TimescaleDB server ingest accepting 5.0 streams.
**Depends on**: Phase 4 (schema + decoder complete)
**Requirements**: SWIFT-01, SWIFT-02, SWIFT-03, SWIFT-04, SWIFT-05, SWIFT-06, IOS-01, IOS-02, IOS-03, IOS-04, IOS-05, IOS-06, IOS-07, IOS-08, IOS-09, SRV-01, SRV-02, SRV-03, SRV-04, SRV-05
**Success Criteria** (what must be TRUE):
  1. `Packages/WhoopProtocol/` parses 5.0 frames via `parseFrame()` (handling Maverick wrapper if present) and `extractStreams()` decodes all v1 streams; Swift unit tests pass with 5.0 golden fixtures and match Python decoder output byte-for-byte
  2. iOS app on physical iPhone bonds to the WHOOP 5.0 via CoreBluetooth and the Live view shows real-time HR, battery level, and BLE connection status
  3. Today, Sleep, and Trends views populate with daily recovery/HRV/sleep summary and historical charts (HR, HRV, SpO₂, skin temp); 14+ days of historical backfill completes with the safe-trim invariant and no data loss
  4. App functions fully offline (`AppConfig.uploaderConfig()` returns nil on placeholder values) AND CoreBluetooth state preservation (`CBCentralManagerOptionRestoreIdentifierKey`, `willRestoreState`) reconnects in background after force-quit
  5. Server runs via `docker compose up -d --build`; `POST /v1/ingest-decoded` accepts 5.0 decoded streams with `device_generation` field; `compute_day()` analysis runs after ingest; `GET /v1/daily-metrics`, `/v1/sleep-sessions`, `/v1/workouts` return 5.0 data from the migrated TimescaleDB hypertables
**Plans**: TBD
**UI hint**: yes

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Capture Foundation | 0/0 | Not started | - |
| 2. GATT Survey & Bonding | 0/0 | Not started | - |
| 3. Framing Confirmation (Critical Gate) | 0/0 | Not started | - |
| 4. Protocol Decode & Schema | 0/0 | Not started | - |
| 5. iOS App & Server Port | 0/0 | Not started | - |

---

## Coverage Map

| Requirement | Phase |
|-------------|-------|
| TOOL-01 | Phase 1 |
| TOOL-02 | Phase 1 |
| TOOL-03 | Phase 1 |
| TOOL-04 | Phase 1 |
| PROTO-01 | Phase 2 |
| PROTO-02 | Phase 2 |
| PROTO-03 | Phase 2 |
| PROTO-04 | Phase 3 |
| PROTO-05 | Phase 3 |
| PROTO-06 | Phase 4 |
| PROTO-07 | Phase 4 |
| PROTO-08 | Phase 4 |
| PROTO-09 | Phase 4 |
| PROTO-10 | Phase 4 |
| PROTO-11 | Phase 4 |
| PROTO-12 | Phase 4 |
| PROTO-13 | Phase 4 |
| PROTO-14 | Phase 4 |
| PROTO-15 | Phase 4 |
| PROTO-16 | Phase 4 |
| SCHEMA-01 | Phase 4 |
| SCHEMA-02 | Phase 4 |
| SCHEMA-03 | Phase 4 |
| SCHEMA-04 | Phase 4 |
| SCHEMA-05 | Phase 4 |
| SWIFT-01 | Phase 5 |
| SWIFT-02 | Phase 5 |
| SWIFT-03 | Phase 5 |
| SWIFT-04 | Phase 5 |
| SWIFT-05 | Phase 5 |
| SWIFT-06 | Phase 5 |
| IOS-01 | Phase 5 |
| IOS-02 | Phase 5 |
| IOS-03 | Phase 5 |
| IOS-04 | Phase 5 |
| IOS-05 | Phase 5 |
| IOS-06 | Phase 5 |
| IOS-07 | Phase 5 |
| IOS-08 | Phase 5 |
| IOS-09 | Phase 5 |
| SRV-01 | Phase 5 |
| SRV-02 | Phase 5 |
| SRV-03 | Phase 5 |
| SRV-04 | Phase 5 |
| SRV-05 | Phase 5 |

**Total mapped:** 45/45 ✓ (no orphans, no duplicates)

---

*Last updated: 2026-05-30 (initial roadmap)*
