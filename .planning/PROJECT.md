# Wearable — WHOOP 5.0

## What This Is

A clean fork of the existing WHOOP 4.0 reverse-engineering project, targeting the WHOOP 5.0 hardware. The goal is to document the 5.0 BLE protocol through systematic traffic capture and analysis, then build a fully functional local-first iOS app (collect → decode → store → sync) backed by an optional self-hosted server — the same architecture as the 4.0 project, rebuilt for the new device.

## Core Value

Own your WHOOP 5.0 biometric data: read it from your own device over BLE, store it locally, and analyse it without any dependency on WHOOP's cloud.

## Requirements

### Validated

- ✓ BLE protocol for WHOOP 4.0 fully documented — `protocol/whoop_protocol.json` + `FINDINGS.md`
- ✓ iOS app (collect → decode → store → sync) working for 4.0
- ✓ FastAPI + TimescaleDB server pipeline working for 4.0
- ✓ Schema-driven decode shared between Swift and Python
- ✓ RE tooling (harness, dashboard, golden fixtures) established

### Active

- [ ] WHOOP 5.0 BLE services and characteristics enumerated
- [ ] Raw BLE traffic captured from 5.0 → app session (PacketLogger on Mac)
- [ ] Android HCI snoop log captured as second reference source
- [ ] Frame framing format confirmed (same or different from 4.0)
- [ ] Packet types / command IDs identified and mapped
- [ ] Biometric decode layout reverse-engineered (HR, RR, SpO₂, skin temp, resp, gravity)
- [ ] `protocol/whoop_protocol_5.json` schema written and validated
- [ ] `FINDINGS_5.md` — protocol reference document
- [ ] Swift decoder updated / forked for 5.0 schema
- [ ] iOS app functional end-to-end with WHOOP 5.0
- [ ] Server ingest and analysis pipeline adapted for 5.0

### Out of Scope

- WHOOP 4.0 support in this fork — separate repo handles it; dual-support adds complexity before protocol is understood
- Older WHOOP generations (1.0, 2.0, 3.0) — different hardware entirely
- WHOOP cloud API integration — the whole point is local-first independence
- Android app — iOS first; Android is only used as a BLE capture tool
- Clinical validation of biometric computations — personal/educational use only

## Context

- **Hardware available:** WHOOP 5.0 (owned by user), iPhone (primary platform), Android (capture tool only)
- **Mac + Xcode available:** PacketLogger (Apple Bluetooth Frame Logger) is the primary BLE capture tool — no jailbreak needed, captures full HCI trace including WHOOP app ↔ device traffic
- **Android role:** Enable HCI snoop log via Developer Options → capture `btsnoop_hci.log` as secondary reference when app is running on Android
- **User skill level:** Medium RE experience — familiar with the domain from the 4.0 project, needs guidance on systematic capture and analysis workflow
- **Starting point:** The 4.0 codebase is the reference implementation. The 5.0 work is a clean fork — same architecture, new protocol
- **Key unknown:** How different is the 5.0 BLE protocol from 4.0? Same framing + new commands, or completely different service UUIDs and frame layout?
- **4.0 BLE custom service:** `61080001-8d6d-82b8-614a-1c8cb0f8dcc6` — first test is whether 5.0 advertises the same UUID

## Constraints

- **Hardware:** WHOOP 5.0 only — no simulator, physical device required for all BLE work
- **Capture platform:** Mac required for PacketLogger (Apple Bluetooth Framework Logger); iOS PacketLogger requires pairing device to Mac in Xcode
- **Legal:** Same RE framework as 4.0 — 17 U.S.C. §1201(f) interoperability, own device, own data, no proprietary material reproduced
- **No root/jailbreak:** Both iPhone and Android are stock — techniques limited to HCI logging and passive capture
- **iOS deployment:** Final app targets iOS 16+ on iPhone; same SwiftUI + CoreBluetooth + GRDB architecture

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Clean fork (not dual-support) | Protocol may be substantially different; don't pollute 4.0 codebase before understanding 5.0 | — Pending |
| Mac PacketLogger as primary capture tool | No jailbreak needed, captures full HCI including app traffic, Apple-native | — Pending |
| Android HCI log as secondary source | Second independent capture to cross-reference and fill gaps | — Pending |
| Same architecture as 4.0 | Proven design; reuse Swift packages, server pipeline, schema-driven decode | — Pending |

---
## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-30 after initialization*
