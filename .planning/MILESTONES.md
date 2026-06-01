# Milestones — WHOOP 5.0

## v3.0 WHOOP Parity (Shipped: 2026-06-01)

**Phases completed:** 3 phases, 7 plans, 2 tasks

**Key accomplishments:**

- Four WHOOP-parity label fixes in SleepView.swift: SLEEP PERFORMANCE, HOURS OF SLEEP, SLEEP LATENCY, SKIN TEMP with °C from baseline unit; D-04 (AWAKE 4th stage) confirmed already satisfied.
- One-liner:
- One-liner:

---

---

## v1.0 — WHOOP 5.0 Protocol + iOS App

**Shipped:** 2026-05-31
**Phases:** 5 (phases 1–5)
**Plans:** 21
**Timeline:** 2026-05-28 → 2026-05-31 (4 days)
**Commits:** 192

### Delivered

Fully reverse-engineered the WHOOP 5.0 BLE protocol (Maverick outer wrapper), built a canonical schema and Python decoder, and shipped a functional iOS app connecting to the WHOOP 5.0 end-to-end with optional self-hosted server ingest.

### Key Accomplishments

1. **iOS PacketLogger live capture confirmed** — 1011 btatt packets with 0xAA SOF on all ATT payloads; RE toolchain established (Phase 1)
2. **WHOOP 5.0 GATT service enumerated** — FD4B0001-CCE1-4033-93CE-002D5875F58A; legacy UUID ABSENT; bond + live HR confirmed (Phase 2)
3. **Maverick outer wrapper fully characterised** — 0% 4.0 CRC pass rate explained; 5028/5028 frames consistent; decode cleared with strip_maverick() (Phase 3)
4. **Protocol decode complete** — PROTO-07 VERIFIED (HR/RR 84–131 bpm); 10 command IDs enumerated; dual-epoch model; store-then-ack historical offload (Phase 4)
5. **whoop_protocol_5.json canonical schema** — all fields confidence-tagged; synced to Swift bundle; FINDINGS_5.md as canonical reference (Phase 4)
6. **iOS app on iPhone 16 Pro Max** — bonds to WHOOP 5.0; live HR confirmed; D-11 asymmetric framing (4.0 writes / Maverick reads) resolved (Phase 5)

### Stats

- ~17,500 LOC Swift | ~30,400 LOC Python
- Archive: `.planning/milestones/v1.0-ROADMAP.md`, `.planning/milestones/v1.0-REQUIREMENTS.md`

### Known Deferred Items at Close: 5 (see STATE.md Deferred Items)

- IOS-03/04/05/06: Today/Sleep/Trends/backfill views — hardware-dependent (WHOOP had no unsynced data)
- IOS-08: Background reconnect — physical test deferred

---
