# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

---

## Milestone: v1.0 — WHOOP 5.0 Protocol + iOS App

**Shipped:** 2026-05-31
**Phases:** 5 | **Plans:** 21 | **Timeline:** 4 days (2026-05-28 → 2026-05-31)

### What Was Built

- Full characterisation of the WHOOP 5.0 BLE protocol — Maverick outer wrapper discovered, documented, and decoded
- Canonical `whoop_protocol_5.json` schema: all fields confidence-tagged (VERIFIED/HYPOTHESIS), dual-epoch model, synced to Swift and Python
- Python decoder (`decode_5.py`, `parse_body_5`) — all decoded packet types, 123-frame golden corpus
- Swift decoder: `parseFrame()` strips Maverick wrapper, `extractStreams()` + `extractHistoricalStreams()` decode all v1 streams; 72 tests, byte-for-byte parity with Python
- iOS app on iPhone 16 Pro Max: bonds to WHOOP 5.0, live HR confirmed (~75 bpm 1x/s)
- FastAPI + TimescaleDB server ported to 5.0: `device_generation` field, `POST /v1/ingest-decoded`, 8 hypertables migrated

### What Worked

- **Phase 3 CRC gate as an explicit blocker** — forcing a go/no-go decision before any decode work meant that discovering 0% 4.0 CRC pass rate was a planned outcome, not a surprise. It immediately redirected effort to Maverick characterisation without any wasted decode work.
- **Python for byte-level RE, Swift only for the final port** — byte-level analysis in Python is dramatically faster than Swift iteration with Xcode compile cycles. All protocol discoveries happened in Python; Swift got a clean, tested port.
- **Evidence sidecars (`.meta.yaml`)** — the discipline of committing redacted metadata alongside every capture session made Phase 3/4 traceability effortless. Future sessions can reconstruct context without re-reading raw captures.
- **Confidence tagging in the schema** — marking fields as VERIFIED vs HYPOTHESIS in `whoop_protocol_5.json` made the uncertainty explicit and prevented fabricating offsets (Pitfall 5). HYPOTHESIS fields are clear targets for future capture sessions.
- **D-11 discovery approach** — instead of assuming write format, testing Maverick writes and observing that the WHOOP ignored them was the fastest path to confirming the asymmetric write/read framing.
- **GSD plan/execute cycle** — keeping phase plans tight (3–6 plans per phase, wave-based parallelism where possible) maintained momentum across a 4-day sprint.

### What Was Inefficient

- **D-05 capture scope** — the biometric capture session did not include TOGGLE_IMU_MODE, leaving IMU/SpO2/skin temp/respiration as HYPOTHESIS for the full milestone. A second targeted capture would have turned 4 HYPOTHESIS streams to VERIFIED. Time constraint was real but worth noting.
- **REQUIREMENTS.md not updated during execution** — the 45-requirement checklist was never updated in-flight, requiring a post-hoc reconciliation at milestone close. Future milestones: update checkboxes at each plan completion.
- **Server Docker not CI-tested** — the server E2E was confirmed manually on gonzaga but not in any automated pipeline. The Phase 5 verification had to defer SRV-05 to human validation.
- **IOS-03/04/05/06/08 blocked by WHOOP sync state** — the official WHOOP app had already synced the device data before the test session, leaving the iOS views without data to display. Planning a "dirty device" test session (don't use official app for 1 week) would unblock these in v2.0.

### Patterns Established

- **Maverick strip before parse** — all 5.0 frame paths must call `strip_maverick()` before attempting any decode. This is enforced in both the Python decoder and `Framing.swift`.
- **Asymmetric write/read framing** — phone → WHOOP uses 4.0 inner format; WHOOP → phone uses Maverick. This is a fundamental 5.0 protocol invariant, documented in FINDINGS_5.md §7.
- **Bond retry pattern** — `CBATTError.insufficientEncryption` on the first confirmed-write triggers iOS SMP pairing; retry after 2s. This is the reliable bonding sequence for 5.0.
- **toggleRealtimeHR handshake** — after bond and subscription, send `[0x01]` command to activate the FD4B custom channel. Without it, the device does not send Maverick frames.
- **Evidence sidecar policy (D-02)** — every capture session commits a `.meta.yaml` sidecar with session metadata. Raw captures are gitignored. BD_ADDR and SMP keys never committed.
- **willRestoreState guard** — do NOT call `discoverServices()` before `centralManagerDidUpdateState(.poweredOn)` in `willRestoreState`. This was a silent crash source fixed in commit dc3e5cf.

### Key Lessons

1. **The framing gate is worth the day it costs** — Phase 3 spent one day validating (and then refuting) the 4.0 CRC hypothesis. That day saved days of wasted decode work on the wrong framing model. Any future RE project with an unknown outer frame should have an explicit CRC gate as Phase 3.
2. **Hardware-dependent tests need a dedicated test session** — IOS-03/04/05/06/08 all require a WHOOP with unsynced data. This can't be arranged mid-sprint. Plan it as a prerequisite for the next milestone: "stop using the official app 7 days before the test session."
3. **Confidence tagging at schema creation time is free; retrofitting is expensive** — adding VERIFIED/HYPOTHESIS at field creation costs nothing. Deciding later which fields were observed vs inferred requires going back to raw captures.
4. **The Python↔Swift parity gate (`Parity5Tests`) is the right integration boundary** — if the Swift decoder produces the same bytes as Python on the same input, the port is correct. This is a cheap, automated, and reliable correctness check.
5. **D-11 (write/read asymmetry) is the single most important 5.0 protocol fact** — knowing that WHOOP 5.0 accepts 4.0-format commands but sends Maverick responses is the key that unlocks the full BLE pipeline. Any future 5.0 work must have this as a starting assumption.

### Cost Observations

- Sessions: ~6 Claude Code sessions across 4 days
- Notable: Phase 3 (1 day) was the highest-leverage phase — 0% CRC result redirected all subsequent decode work
- Phase 5 (1 day) was the densest execution — 6 plans, Swift decoder port, iOS e2e, and server port in one session

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 5 | 21 | First 5.0 milestone; established Maverick framing + evidence sidecar pattern |

### Cumulative Quality

| Milestone | Swift Tests | Parity Gate | VERIFIED streams |
|-----------|-------------|-------------|-----------------|
| v1.0 | 72/72 | ✅ byte-for-byte | HR/RR (+ IMU/SpO2/temp/resp as HYPOTHESIS) |

### Top Lessons (Verified Across Milestones)

1. Explicit CRC/framing gate before any decode work (verified: Phase 3 saved days of wasted effort)
2. Python for RE, Swift only for final port (verified: all protocol discoveries in Python)
3. Evidence sidecars at every capture session (verified: Phase 4/5 traceability was effortless)
