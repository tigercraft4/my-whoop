# Phase 2: GATT Survey & Bonding - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Enumerate the WHOOP 5.0 GATT surface on the user's specific device, replicate bonding without the official app, and confirm standard HR and battery characteristics are readable via Bleak.

**Deliverables:**
1. All GATT services and custom characteristics (cmd-in, cmd-resp, events, data, diagnostics + standard HR + battery) enumerated via nRF Connect on device — UUIDs documented per-device in `FINDINGS_5.md`
2. Presence or absence of legacy `61080001-…` UUID confirmed alongside `fd4b0001-…` on this specific unit
3. Bleak script bonds to the strap from a fresh state (Forget Device on iPhone first) without the official WHOOP app running — SMP packets visible in PacketLogger
4. Standard heart-rate characteristic streams live BPM values via Bleak subscription

**Primary output artifact:** `FINDINGS_5.md` (started here, extended through Phases 3–4)

**Out of scope:** CRC/framing validation (Phase 3), full protocol decode (Phase 4), iOS app work (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### GATT Enumeration Tooling (D-01)
- **D-01:** **nRF Connect first** — install nRF Connect on iPhone (free, App Store), use it as the primary visual GATT browser to confirm UUIDs before writing any Bleak code. Bleak then uses those confirmed UUIDs.
- **D-01b:** **Close the official WHOOP app before connecting with nRF Connect** — only one BLE central can be connected at a time. The plan documents both scenarios (app open = advertisements visible but no connection; app closed = free to connect).
- **D-01c:** **Confirm both UUIDs** — document presence or absence of legacy `61080001-…` alongside `fd4b0001-…` on this unit. Required by ROADMAP criterion 2 and needed to know if 4.0 compatibility code is necessary in Phase 5.

### Handle-to-UUID Mapping (D-02)
- **D-02:** **Map Phase 1 handles → real UUIDs** as an explicit step. Phase 1 capture showed `0x099b` (cmd-in write), `0x099d` and `0x09a3` (notifications) — these handles need to be linked to their parent characteristic UUIDs via GATT Primary Service + Characteristic Discovery responses. Closes the loop from Phase 1 evidence.

### Bonding Strategy (D-03)
- **D-03:** **Try 4.0 confirmed-write trick first.** Phase 1 capture confirmed `0xAA` SOF on all ATT payloads — inner framing appears identical. Attempt the same confirmed-write on the equivalent 5.0 handle (cmd-in `0x099b` or its UUID equivalent). This is the fastest path.
- **D-03b:** **Fallback if trick fails: PacketLogger SMP capture.** Capture the official app's SMP pairing handshake via PacketLogger (Phase 1 toolchain already available), identify the exact write sequence, and reproduce it in Bleak. The Phase 1 `re/capture/ios-packetlogger.md` workflow covers this.
- **D-03c:** **WHOOP is currently paired with official app on iPhone.** Plan includes: Forget Device on iPhone → close official app → run Bleak bond script.

### Script Location (D-04)
- **D-04:** **`re/survey_5/` for all Phase 2 scripts** — new subdirectory, separate from the 4.0 `re/` scripts. Keeps 4.0 (active production scripts) isolated from 5.0 (in-discovery scripts). Phases 3–5 can add to or migrate from `re/survey_5/`.
- **D-04b:** **Device identity: `re/survey_5/device_local_5.py`** — same pattern as `re/device_local.py` for 4.0. A `device_local_5.example.py` template is committed; the real file with BLE UUID/MAC/serial is gitignored.

### Evidence Format (D-05)
- **D-05:** **`FINDINGS_5.md` as the primary committed artifact.** Mirrors the existing `FINDINGS.md` for 4.0. Start it in Phase 2 with: confirmed UUIDs + handle map, presence/absence of legacy UUID, bond outcome, HR/battery confirmation. Phases 3–4 extend it progressively.
- **D-05b:** `protocol/whoop_protocol_5.json` starts in Phase 3 (after framing is confirmed) — premature to write structured JSON before UUIDs are known.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Protocol Reference
- `FINDINGS.md` — 4.0 inner framing (`0xAA` SOF, CRC8 poly 0x07, CRC32-LE, command/event enums). The 5.0 is a port — this is the ground truth for what the inner frame looks like.
- `re/device_local.example.py` — canonical pattern for gitignored device identity file (BLE UUID/MAC/serial); `re/survey_5/device_local_5.py` must follow this pattern.

### Capture & Evidence
- `re/capture/ios-packetlogger.md` — Phase 1 runbook for PacketLogger capture (needed for bonding fallback: SMP handshake capture).
- `re/capture/evidence/2026-05-30-ios.meta.yaml` — Phase 1 evidence: handles `0x099b`/`0x099d`/`0x09a3`, `0xAA` SOF confirmed, 1011 btatt packets. Phase 2 must close the handle→UUID mapping loop.
- `re/capture/wireshark.md` — tshark commands for SMP/ATT analysis if needed for bonding investigation.

### Project Context
- `.planning/ROADMAP.md` §Phase 2 — success criteria (4 items) and requirement IDs PROTO-01/02/03.
- `.planning/REQUIREMENTS.md` — PROTO-01 (UUID enumeration), PROTO-02 (legacy UUID check), PROTO-03 (bonding + HR/battery).
- `DISCLAIMER.md §2` — decompiled/proprietary material policy (applies to any APK-derived UUID cross-refs).

### 4.0 Active RE Scripts (reference only — do not modify)
- `re/re_harness.py` — 4.0 Bleak harness; survey_5 scripts should follow the same structure (device_local import, asyncio pattern, logging to jsonl).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `re/re_harness.py` — asyncio + Bleak pattern already established; `re/survey_5/survey_gatt_5.py` should follow the same import/async structure.
- `re/device_local.example.py` — template for gitignored device identity; copy pattern for `re/survey_5/device_local_5.example.py`.
- `re/capture/ios-packetlogger.md` — already documents how to capture SMP packets; reuse directly as the bonding-fallback reference.

### Established Patterns
- **device_local pattern:** real device IDs (BLE UUID, MAC, serial) go in a gitignored `device_local*.py`; a `*.example.py` template is committed. Phase 2 must not commit real identifiers.
- **Evidence policy (D-02 Phase 1):** redacted hex + SHA256 + metadata YAML committed under `re/capture/evidence/`; raw captures gitignored. Phase 2 GATT evidence follows the same pattern (nRF Connect screenshots or tshark GATT decode excerpts as evidence, not raw `.pklg` of the survey session).
- **`0xAA` SOF confirmed:** all Phase 1 ATT payloads start with `0xAA` — downstream scripts can use this as a quick sanity check on any new frame.

### Integration Points
- `FINDINGS_5.md` (new file, starts in Phase 2) → consumed by Phase 3 (framing confirmation uses the confirmed UUIDs and characteristic handles) and Phase 4 (protocol decode uses the full service map).
- `re/survey_5/device_local_5.py` → imported by all survey scripts in Phase 2+; follows `re/device_local.py` interface.

</code_context>

<specifics>
## Specific Ideas

- Phase 1 already identified handles `0x099b` (cmd-in), `0x099d`, `0x09a3` (notifications). The Phase 2 GATT survey must explicitly resolve these to their characteristic UUIDs and service UUID — this is the "close the loop" step.
- nRF Connect for iOS is the primary enumeration tool (free, no code, runs on the user's existing iPhone).
- The legacy `61080001-…` UUID check is a one-line nRF Connect observation but has significant downstream implications — document it explicitly in `FINDINGS_5.md` with "present" or "absent" verdict.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-GATT Survey & Bonding*
*Context gathered: 2026-05-30*
