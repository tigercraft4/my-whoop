---
phase: 04-protocol-decode-schema
plan: 05
subsystem: protocol-schema
tags: [ble, reverse-engineering, schema, json, swift-bundle, findings, dual-epoch, confidence-tagging, integration]

# Dependency graph
requires:
  - phase: 04-protocol-decode-schema
    plan: 01
    provides: "decode_5.parse_body_5 (offset-4 body decoder), frames_5_golden.json (123-record cross-type corpus), r52 enum loader"
  - phase: 04-protocol-decode-schema
    plan: 03
    provides: "command surface (10 observed / 67 HYPOTHESIS), EVENT/battery/metadata/historical-offload decode, PROTO-15 dual-epoch model"
  - phase: 04-protocol-decode-schema
    plan: 04
    provides: "biometric verdicts — HR/RR VERIFIED (HR @ payload[5], RR @ payload[7:]), IMU/SpO2/temp/resp HYPOTHESIS"
provides:
  - "protocol/whoop_protocol_5.json: complete canonical 5.0 schema (4 r52 enum maps verbatim + 7 packet body field maps, every field epoch/provenance/confidence tagged, BODY-ABSOLUTE offset base, dual-epoch represented, biometric verdicts map)"
  - "scripts/sync-schema-5.sh: JSON-validating sync of the canonical schema into the Swift bundle Resources dir"
  - "FINDINGS_5.md section 8 (Decode & Schema, Phase 4): the canonical protocol reference Phase 5's planner reads"
  - "Swift bundle Resources/whoop_protocol_5.json (byte-identical synced copy)"
affects: [phase-05, SCHEMA-01, SCHEMA-02, SCHEMA-03, SCHEMA-04, SCHEMA-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "BODY-ABSOLUTE offset base reconciliation: 5.0 schema field offsets indexed against the flat body (payload[N] == body[7+N]), reconciled vs 4.0 frame-relative offsets and documented in schema_note"
    - "Confidence/epoch/provenance tag on EVERY schema field (VERIFIED only with ground-truth/observed backing; HYPOTHESIS with honest provenance otherwise)"
    - "JSON-validate-before-copy sync script (T-04-06): fail non-zero on invalid JSON before writing into the Swift bundle"
    - "No-fabricated-VERIFIED policy: absent biometric streams (IMU/SpO2/temp/resp) carried as HYPOTHESIS with 4.0-cloud-computed provenance, no invented offsets entering the canonical schema (Pitfall 5)"

key-files:
  created:
    - scripts/sync-schema-5.sh
    - Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json
  modified:
    - protocol/whoop_protocol_5.json
    - FINDINGS_5.md

key-decisions:
  - "Schema field offsets are BODY-ABSOLUTE (index into the flat strip_maverick() body), NOT frame-relative like 4.0; reconciled explicitly in schema_note (payload[N] == body[7+N])"
  - "7 packet types in the schema (COMMAND_RESPONSE, EVENT, EVENT_BATTERY_LEVEL, METADATA, CONSOLE_LOGS, REALTIME_DATA, REALTIME_RAW_DATA); REALTIME_RAW_DATA kept as a HYPOTHESIS template (type 43 never captured) so the IMU layout is decode-ready without fabricating VERIFIED 5.0 offsets"
  - "Golden fixtures needed NO change: Plan 01's 123-record corpus already spans every decoded type (COMMAND/COMMAND_RESPONSE/EVENT/METADATA/CONSOLE_LOGS/HISTORICAL_DATA/REALTIME_DATA) and round-trips 0-failure through parse_body_5; adding a fabricated REALTIME_RAW_DATA/SpO2/temp exemplar would violate Pitfall 5"
  - "sync-schema-5.sh OMITS the home-server branch (the 4.0 script has it) because the 5.0 home-server consumer does not exist yet — documented in a script comment, Phase 5 can add it"
  - "Battery SOC offset kept HYPOTHESIS in the schema (EVENT_BATTERY_LEVEL): the 4.0 A6 layout does not cleanly resolve the confirmed 0x2A19=23% read on 5.0 (Plan 03 verdict honoured, not overridden)"

requirements-completed: [SCHEMA-01, SCHEMA-02, SCHEMA-03, SCHEMA-04, SCHEMA-05]

# Metrics
duration: ~15min
completed: 2026-05-30
---

# Phase 4 Plan 05: Canonical Schema + Findings Integration Summary

**The single source of truth for WHOOP 5.0 is complete: `protocol/whoop_protocol_5.json` carries the four r52 enum maps verbatim plus body field maps for all 7 decoded packet types — every field tagged with epoch/provenance/confidence, the PROTO-15 dual-epoch model represented (unix GET_DATA_RANGE vs device EVENT body[8]), and biometrics honestly confidence-tagged (HR/RR VERIFIED, IMU/SpO2/temp/resp HYPOTHESIS, no fabricated offsets) — synced into the Swift bundle by a JSON-validating `sync-schema-5.sh`, with `FINDINGS_5.md` section 8 now the canonical protocol reference the Phase 5 planner reads.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-05-30
- **Tasks:** 3 completed
- **Files created:** 2 (sync-schema-5.sh, synced bundle copy)
- **Files modified:** 2 (whoop_protocol_5.json, FINDINGS_5.md)

## Accomplishments

- **SCHEMA-01/02 (Task 1):** Populated `protocol/whoop_protocol_5.json`. Copied the four r52 enum maps (`PacketType`, `MetadataType`, `EventNumber`, `CommandNumber`) **verbatim** from the 4.0 schema (WG50_r52 confirmed identical). Added body field maps for **7 packet types** — `COMMAND_RESPONSE`, `EVENT`, `EVENT_BATTERY_LEVEL`, `METADATA`, `CONSOLE_LOGS`, `REALTIME_DATA`, `REALTIME_RAW_DATA`. **Every field carries `epoch` + `note` + `confidence`** (45 confidence tags, 43 epoch tags). The PROTO-15 dual-epoch is represented: a `unix`-tagged field (GET_DATA_RANGE response) and 7 `device`-tagged fields (EVENT body[8], REALTIME_DATA payload). Offset base reconciled to **BODY-ABSOLUTE** in `schema_note` (the 4.0 offsets were frame-relative). Biometrics honestly tagged: HR/RR VERIFIED, IMU/SpO2/temp/resp HYPOTHESIS with provenance — no fabricated VERIFIED offsets.
- **SCHEMA-05/04 (Task 2):** Created `scripts/sync-schema-5.sh` (executable, mirrors the 4.0 template) with a **JSON-validation step before `cp`** (T-04-06: refuses to sync invalid JSON, exits non-zero), `mkdir -p` on the Resources dir, and the home-server branch omitted (documented — 5.0 consumer is Phase 5 scope). Running it exits 0 and produces a **byte-identical** `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json`. Confirmed the golden fixtures (`frames_5_golden.json`, 123 records) **span every decoded packet type** and **round-trip 0-failure** through `parse_body_5` — no fixture change needed.
- **SCHEMA-03 (Task 3):** Appended `## 8. Decode & Schema (Phase 4)` to `FINDINGS_5.md` — body layout (offset-4, no inner CRC), command surface (10 observed / 67 HYPOTHESIS, reused-14), events incl. battery, dual-epoch, historical offload (doc-only D-09), per-stream biometric verdicts, a **committed-artifacts list** (naming `whoop_protocol_5.json` + all decode scripts), a **confidence-per-stream table**, and a restated DISCLAIMER section 2.

## Task Commits

Each task committed atomically:

1. **Task 1: populate whoop_protocol_5.json enums + packets** — `7862574` (feat)
2. **Task 2: sync-schema-5.sh + sync to Swift bundle** — `817f222` (feat)
3. **Task 3: extend FINDINGS_5.md with section 8** — `2f84d8f` (docs)

## Files Created

- `scripts/sync-schema-5.sh` — JSON-validating schema sync into the Swift bundle. `set -euo pipefail`, validates `whoop_protocol_5.json` is well-formed JSON, `mkdir -p` the Resources dir, `cp`, echoes confirmation. Executable (`chmod +x`).
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json` — the synced bundle copy (byte-identical to the canonical schema).

## Files Modified

- `protocol/whoop_protocol_5.json` — from v0 (empty enums/packets) to complete: 4 r52 enum maps + 7 packet body field maps + biometric verdicts map; envelope/gatt/firmware_revision preserved unchanged.
- `FINDINGS_5.md` — added section 8 (Decode & Schema, Phase 4).

## Verification Evidence

| Check | Result |
|-------|--------|
| `python3 -c "json.load(...); enums>=4; packets>=4"` | PASS — enums: PacketType/MetadataType/EventNumber/CommandNumber; 7 packets |
| Every packet field has confidence + epoch + note | PASS — 0 missing tags |
| unix-epoch field + device-epoch field present (PROTO-15) | PASS — 1 unix, 7 device |
| envelope/gatt/firmware_revision preserved from v0 | PASS — unchanged |
| Swift FieldSpec key compatibility | PASS — off/len/dtype/name/cat/enum/note present; epoch/confidence/endian/value ignored by Codable (4.0 schema already uses endian/value) |
| `bash scripts/sync-schema-5.sh` exits 0 | PASS |
| synced bundle byte-identical to canonical (`diff -q`) | PASS |
| `test -x scripts/sync-schema-5.sh` + contains whoop_protocol_5.json + mkdir -p + json.load | PASS |
| fixtures span COMMAND_RESPONSE/EVENT/METADATA/CONSOLE_LOGS | PASS (+ COMMAND/HISTORICAL_DATA/REALTIME_DATA) |
| every fixture body len>=7 round-trips via parse_body_5 | PASS — 0 failures |
| FINDINGS_5.md "Phase 4" >= 1 | PASS — 11 |
| FINDINGS_5.md command surface\|historical offload\|dual-epoch >= 3 | PASS — 9 |
| FINDINGS_5.md names whoop_protocol_5.json + decode scripts | PASS — 5 + 8 |
| DISCLAIMER discipline (REDACTED / protocol-structure) restated | PASS — 6 |

## Deviations from Plan

None — plan executed exactly as written. Two plan expectations were satisfied by confirmation rather than new work, and are noted for transparency (not deviations):

- **Golden fixtures (SCHEMA-04):** the plan asked to "add one curated exemplar if any decoded type lacks one." Confirmed the existing 123-record corpus already spans every decoded type with 0 round-trip failures, so no exemplar was added. Adding a REALTIME_RAW_DATA/SpO2/temp exemplar was deliberately NOT done — those types were never captured (Plan 04 HYPOTHESIS), so a fabricated fixture would violate Pitfall 5 / T-04-05.
- **Resources dir already existed** (holding the 4.0 schema). The `mkdir -p` in sync-schema-5.sh remains (idempotent, load-bearing for fresh checkouts).

## Authentication Gates

None.

## Known Stubs

None. The schema contains zero placeholder/empty-value stubs. HYPOTHESIS-tagged entries (battery SOC offset, REALTIME_RAW_DATA/IMU template, SpO2/temp/respiration verdicts) are **honest provenance**, not stubs — each cites why the bytes are absent (never captured) and what Phase 5 capture would grade them VERIFIED. No fabricated VERIFIED biometric field exists (Pitfall 5 upheld).

## Threat Flags

None. No new network endpoints, auth paths, or trust boundaries beyond the plan's `<threat_model>`. Mitigations applied and verified:
- **T-04-05** (no fabricated VERIFIED / no fabricated biometric offset in the canonical schema): VERIFIED only where Plan 03/04 recorded ground-truth/observed backing; battery SOC + SpO2/temp/respiration + IMU all HYPOTHESIS with provenance.
- **T-04-02** (no device identity in schema/fixtures/FINDINGS): only protocol-structure facts committed; device identity `[REDACTED]`; console narration digit-run-scrubbed; raw `.pklg` gitignored.
- **T-04-06** (sync never copies invalid JSON): `sync-schema-5.sh` validates JSON before `cp`, exits non-zero on failure.
- **T-04-SC** (no package installs): stdlib `json` + bash + existing decoders only.

## Self-Check: PASSED

- FOUND: protocol/whoop_protocol_5.json
- FOUND: scripts/sync-schema-5.sh
- FOUND: Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json
- FOUND: FINDINGS_5.md (section 8 present)
- FOUND: commit 7862574 (Task 1)
- FOUND: commit 817f222 (Task 2)
- FOUND: commit 2f84d8f (Task 3)
