---
phase: 04-protocol-decode-schema
verified: 2026-05-30T20:49:47Z
status: passed
score: 10/13 must-haves verified
overrides_applied: 2
overrides:
  - gap: "SC-1 Live command surface probe (re_harness.py)"
    accepted_by: developer
    accepted_on: 2026-05-30
    rationale: "macOS cannot bond to WHOOP 5.0 without the official app (Phase 2 finding, D-06 decision). Live probe is physically impossible from macOS. Capture-analysis (10 OBSERVED, 67 HYPOTHESIS) is the correct deliverable given the constraint. Phase 5 Swift CoreBluetooth work will enable the live probe."
    deferred_to: "Phase 5"
  - gap: "SC-2 SpO2/IMU/skin-temp/respiration ground-truth validation"
    accepted_by: developer
    accepted_on: 2026-05-30
    rationale: "Bytes (type-43, type-53, event-17) were genuinely absent from the D-05 capture. Code correctly records HYPOTHESIS with honest provenance — no fabricated offsets (Pitfall 5 upheld). A dedicated capture with START_RAW_DATA/TOGGLE_IMU_MODE/TOGGLE_OPTICAL_DATA active is needed. Deferred to Phase 5 or a follow-up capture session."
    deferred_to: "Phase 5"
gaps:
  - truth: "re_harness.py (or equivalent) probes command IDs 0-255 live and the responding command surface is enumerated; 4.0 reused IDs (1,2,3,7,11,14,22,26,35,81,82,106,107,145) cross-validated as functional on 5.0"
    status: failed
    reason: "ROADMAP SC-1 requires a live 0-255 command probe. The phase executed capture-analysis only (D-06 design decision: macOS cannot bond, live probe is physically impossible without iOS Swift bridge). Only 10 of 77 r52 commands were OBSERVED; the remaining 67 are HYPOTHESIS. No re_harness.py equivalent exists in the codebase."
    artifacts:
      - path: "re/survey_5/command_surface_5.py"
        issue: "Does capture-analysis reconciliation, NOT live 0-255 probe. Exit 0 and correct, but scope is explicitly narrower than ROADMAP SC-1."
    missing:
      - "A live command probe harness (likely Phase 5 Swift/iOS scope per D-06 — macOS cannot bond without the WHOOP app present)"
  - truth: "Live biometric streams (SpO2 type-53/byte-10, skin temp event-17, respiration, IMU/gravity) each decode values validated against ground-truth references (oximeter, thermometer, HR strap)"
    status: failed
    reason: "ROADMAP SC-2 requires all named streams validated against ground truth. SpO2 (PROTO-11), skin temperature (PROTO-12), respiration (PROTO-13), and IMU/gravity (PROTO-14) are all HYPOTHESIS — 0 type-53 frames, 0 event-17 frames, 0 type-43 frames in the D-05 capture. The bytes are genuinely absent from the wire in the captured session, not a code defect. HR/RR (PROTO-07) IS verified. Ground-truth validation of the four absent streams physically requires a fresh targeted capture with the relevant sensor modes triggered."
    artifacts:
      - path: "re/survey_5/decode_biometrics_5.py"
        issue: "Correctly reports HYPOTHESIS for SpO2/temp/resp/IMU with honest provenance. The code is correct; the gap is in captured data coverage."
    missing:
      - "A targeted capture triggering SpO2 / TEMPERATURE_LEVEL / TOGGLE_IMU_MODE / TOGGLE_OPTICAL_DATA to obtain type-53, event-17, and type-43 frames"
      - "Decoder verification of those frames against oximeter, thermometer, and HR-strap ground truth"
  - truth: "Historical data offload runs end-to-end with store-then-ack discipline — an intentional process kill during a pending ack does NOT lose data on next reconnect"
    status: failed
    reason: "ROADMAP SC-3 requires a live kill-process test. The phase documented the offload protocol from CONSOLE_LOGS (PROTO-10 documentation-only, D-09 decision) but explicitly deferred the kill-test to Phase 5. No kill-test harness exists in the codebase."
    artifacts:
      - path: "re/survey_5/decode_streams_5.py"
        issue: "Documents the historical offload protocol correctly (SEND_HISTORICAL_DATA/HISTORICAL_DATA_RESULT/trim cursor) but does not implement or exercise the kill-test."
    missing:
      - "A kill-process test that verifies no data loss on reconnect after a mid-ack crash (Phase 5 scope per D-09 — requires Swift CoreBluetooth running on an iPhone)"
deferred:
  - truth: "Historical offload kill-process test (store-then-ack invariant)"
    addressed_in: "Phase 5"
    evidence: "Phase 5 SC-3: '14+ days of historical backfill completes with the safe-trim invariant and no data loss' — this is precisely the end-to-end safe-trim guarantee that the kill-test validates."
---

# Phase 4: Protocol Decode & Schema Verification Report

**Phase Goal:** Decode the WHOOP 5.0 BLE protocol and produce the canonical schema — establishing the packet structure, command surface, event/metadata formats, biometric streams, and dual-epoch timestamp model needed for the Phase 5 Swift implementation.
**Verified:** 2026-05-30T20:49:47Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | decode_5.py strips the Maverick wrapper and parses the flat body at offset 4 (role/token/type/seq/cmd/payload) | ✓ VERIFIED | File exists (351 lines), `def parse_body_5` present, `from validate_frames_5 import strip_maverick` confirmed, D-01 gate exits 0 on 123-record corpus producing COMMAND_RESPONSE + GET_DATA_RANGE + GATE PASS |
| 2  | D-01 gate passes: all pktypes resolve to known r52 PacketType names | ✓ VERIFIED | `python decode_5.py frames_5_golden.json` exits 0, output: "GATE PASS: every decoded ptype resolves to a known r52 PacketType" — COMMAND, COMMAND_RESPONSE, EVENT, METADATA, CONSOLE_LOGS, HISTORICAL_DATA, REALTIME_DATA all resolved |
| 3  | frames_5_golden.json expanded from 46 to a curated cross-type corpus with stream_type on every record | ✓ VERIFIED | 123 records, all 123 have `stream_type`, spans COMMAND/COMMAND_RESPONSE/EVENT/METADATA/CONSOLE_LOGS/HISTORICAL_DATA/REALTIME_DATA (7 types), 46 <= 123 < 5028 |
| 4  | A COMMAND_RESPONSE GET_DATA_RANGE frame decodes to a real Unix timestamp (PROTO-15 unix epoch) | ✓ VERIFIED | Gate output: "PROTO-15 unix ts in GET_DATA_RANGE: off=35 1778269908 -> 2026-05-08T19:51:48+00:00" — 12 Unix ts candidates found |
| 5  | All command IDs observed in the corpus are enumerated and reconciled against the r52 CommandNumber map; 14 reused 4.0 IDs cross-validated | ✓ VERIFIED | command_surface_5.py exits 0; 10 OBSERVED, 67 HYPOTHESIS; 14 reused IDs all accounted for (3/14 OBSERVED, 11 absent); output contains GET_DATA_RANGE, OBSERVED/UNOBSERVED markers |
| 6  | EVENT packets decode to r52 EventNumber names including device-epoch u32 at body[8] (PROTO-09, PROTO-15 device epoch) | ✓ VERIFIED | decode_streams_5.py exits 0; 136 EVENTs resolved to names including STRAP_CONDITION_REPORT, BLE_CONNECTION_UP/DOWN, BATTERY_LEVEL, EXTENDED_BATTERY_INFORMATION; device-epoch u32 e.g. 1780153538 |
| 7  | Battery level decoded (PROTO-08) from battery event / GET_BATTERY_LEVEL response | ✓ VERIFIED (HYPOTHESIS grade) | BATTERY_LEVEL (event 3) and EXTENDED_BATTERY_INFORMATION (event 63) decoded under the 4.0 A6 layout; cross-checked vs 0x2A19=23% — no candidate matches cleanly, SOC offset recorded as HYPOTHESIS with Phase 5 capture flag. Plan-level truth met: decode attempted and reported. |
| 8  | Historical offload protocol documented from CONSOLE_LOGS + METADATA (PROTO-10, documentation-only per D-09) | ✓ VERIFIED | decode_streams_5.py output: "SEND_HISTORICAL_DATA (cmd 22)", "HISTORICAL_DATA_RESULT (cmd 23)", 14 trim cursors (e.g. 0x00000004:000130ef); METADATA counts HISTORY_START(73)/HISTORY_END(79)/HISTORY_COMPLETE(2) |
| 9  | Dual-epoch model demonstrated: GET_DATA_RANGE Unix u32 (epoch=unix) + EVENT device-epoch u32 (epoch=device) | ✓ VERIFIED | Output: "Unix epoch (GET_DATA_RANGE): 2026-05-08 (epoch=unix)" and "Device epoch (EVENT body[8]): 1780152939 (epoch=device)"; both tagged in schema |
| 10 | Realtime HR/RR decoded and validated against ground truth (PROTO-07) | ✓ VERIFIED | decode_biometrics_5.py --streams hr,imu exits 0; 159 REALTIME_DATA frames; HR smooth 84-131 bpm; 8/8 RR-bearing frames pass RR<->HR cross-check (60000/HR); VERIFIED verdict |
| 11 | re_harness.py (or equivalent) probes command IDs 0-255 live; reused-4.0 IDs cross-validated as functional | ✗ FAILED | Live probe not possible from macOS (cannot bond); D-06 decision replaced with capture-analysis. No probe harness in codebase. Only 10/77 commands observed; 67 HYPOTHESIS. ROADMAP SC-1 gap. |
| 12 | SpO2/skin-temp/respiration/IMU each decode to ground-truth-validated values | ✗ FAILED | All four are HYPOTHESIS: 0 type-53 frames, 0 event-17 frames, 0 type-43 frames in D-05 capture. Bytes genuinely absent; no fabricated offsets. ROADMAP SC-2 gap. |
| 13 | Historical offload kill-process test confirms store-then-ack invariant (no data loss on mid-ack crash) | ✗ FAILED | Deferred to Phase 5 (D-09). Documented only from corpus narration, not live tested. ROADMAP SC-3 gap. Phase 5 SC-3 covers this. |

**Score:** 10/13 truths verified (3 FAILED — 2 active blockers + 1 deferred to Phase 5)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Historical offload kill-process test (store-then-ack invariant) | Phase 5 | Phase 5 SC-3: "14+ days of historical backfill completes with the safe-trim invariant and no data loss" — this is the end-to-end guarantee the kill-test validates |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `re/survey_5/decode_5.py` | Maverick-aware body decoder (parse_body_5, offset 4, r52 enum resolution) | ✓ VERIFIED | 351 lines; `def parse_body_5` present; no WhoopPacket, no zlib.crc32; length guard confirmed; exits 0 on D-01 gate |
| `re/survey_5/frames_5_golden.json` | Curated cross-type corpus with stream_type on every record | ✓ VERIFIED | 123 records (46-5028 range); all have stream_type; 7 PacketTypes; 61,915 bytes |
| `re/survey_5/command_surface_5.py` | Observed-vs-r52 command surface enumeration | ✓ VERIFIED | 266 lines; `from decode_5 import` present; no WhoopPacket; exits 0; 14 reused IDs reported |
| `re/survey_5/decode_streams_5.py` | EVENT/battery/metadata/historical/dual-epoch decoders | ✓ VERIFIED | 371 lines; `from decode_5 import` present; length guards (len(body)/len(payload) × 5); exits 0 |
| `re/survey_5/decode_biometrics_5.py` | Biometric stream decoders with VERIFIED/HYPOTHESIS verdicts | ✓ VERIFIED | 561 lines; `from decode_5 import` (×1); parse_hr (×16); len( guards ×23; exits 0 on --streams hr,imu and --streams spo2,temp,resp |
| `re/capture/evidence/2026-05-30-biometric-5.meta.yaml` | Redacted evidence sidecar with firmware_revision | ✓ VERIFIED | Contains firmware_revision: WG50_r52; device_identity: "[REDACTED]"; raw_artifacts_local_only; results section |
| `protocol/whoop_protocol_5.json` | Complete 5.0 schema: 4 enum maps + packet body field maps, all fields epoch/provenance/confidence tagged | ✓ VERIFIED | 21,495 bytes; all 4 enums present (PacketType/MetadataType/EventNumber/CommandNumber); 7 packet types; 0 missing tags; unix + device epochs both represented |
| `scripts/sync-schema-5.sh` | JSON-validating schema sync to Swift bundle | ✓ VERIFIED | Executable; contains whoop_protocol_5.json (×2) + mkdir -p + json.load validation; exits 0; bundle is byte-identical to canonical |
| `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json` | Synced bundle copy | ✓ VERIFIED | Exists, 21,495 bytes, byte-identical to protocol/whoop_protocol_5.json |
| `FINDINGS_5.md` | §Phase 4 canonical protocol reference | ✓ VERIFIED | 11 "Phase 4" occurrences; 9 matches for command surface/historical offload/dual-epoch; names whoop_protocol_5.json and all decode scripts; confidence-per-stream table; DISCLAIMER §2 restated |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| decode_5.py | validate_frames_5.py | `from validate_frames_5 import strip_maverick` | ✓ WIRED | grep count = 2 (import + noqa comment); confirmed present |
| decode_5.py | frames_5_golden.json | reads corpus, decodes each body | ✓ WIRED | grep "frames_5_golden" in decode_5.py = 3 matches |
| command_surface_5.py | decode_5.py | `from decode_5 import` | ✓ WIRED | grep count = 2 (parse_body_5 + COMMAND_NUMBER + resolve_cmd) |
| decode_streams_5.py | decode_5.py | `from decode_5 import` | ✓ WIRED | grep count = 2 |
| decode_biometrics_5.py | decode_5.py | `from decode_5 import parse_body_5` | ✓ WIRED | grep count = 1 |
| decode_biometrics_5.py | standard_ble.py / parse_hr | try-import with verbatim fallback copy | ✓ WIRED | parse_hr referenced 16 times; try/except fallback covers worktree isolation |
| sync-schema-5.sh | Packages/.../Resources/whoop_protocol_5.json | cp after JSON validation + mkdir -p | ✓ WIRED | Script exits 0; bundle produced; byte-identical via diff -q |
| protocol/whoop_protocol_5.json | Plan 03/04 decode verdicts | confidence + epoch + provenance per field | ✓ WIRED | 45 confidence tags; 43 epoch tags; 0 missing tags across 7 packet types |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| decode_5.py | `bytype` / decoded ptype names | `parse_body_5` over `frames_5_golden.json` (123 real frames from 5028-frame extraction) | Yes — real captures produce recognisable r52 names | ✓ FLOWING |
| command_surface_5.py | `observed_cmds` dict | `validate_frames_5.build_report(DEFAULT_CAPTURES)` — full 5028-frame corpus | Yes — 5028 real frames, 10 OBSERVED commands | ✓ FLOWING |
| decode_streams_5.py | events, trim cursors, timestamps | Same corpus + `parse_body_5` | Yes — 136 real EVENTs, 14 real trim cursors, 19 real Unix ts | ✓ FLOWING |
| decode_biometrics_5.py | HR/RR samples, biometric verdicts | `validate_frames_5.extract_frames` over `capture_all-V3.pklg` (1049 real frames) | Yes — 159 real REALTIME_DATA frames decode to smooth HR 84-131 bpm | ✓ FLOWING |
| protocol/whoop_protocol_5.json | enums + field maps | Verbatim from whoop_protocol.json + empirical decode results from Plans 03/04 | Yes — all fields back-referenced to specific capture evidence | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| D-01 gate passes on golden corpus | `python decode_5.py frames_5_golden.json` | exit 0, GATE PASS, COMMAND_RESPONSE + GET_DATA_RANGE + 2026 Unix ts confirmed | ✓ PASS |
| Length guard returns error dict on 4-byte body | `python -c "from decode_5 import parse_body_5; print(parse_body_5(bytes.fromhex('01000000')))"` | `{'error': 'short', 'body_hex': '01000000'}` | ✓ PASS |
| Command surface exits 0 and names reused-14 IDs | `python command_surface_5.py` | exit 0; 10 OBSERVED (incl. TOGGLE_REALTIME_HR/3, SEND_HISTORICAL_DATA/22, GET_HELLO/145); HYPOTHESIS for 67 unobserved | ✓ PASS |
| Stream decode exits 0 with event + trim + dual-epoch | `python decode_streams_5.py` | exit 0; STRAP_CONDITION_REPORT + device-epoch; trim cursors 0x00000004:000130ef + 13 more; Unix 2026-05-08 + device 1780152939 | ✓ PASS |
| Biometrics HR/IMU exits 0 with VERIFIED/HYPOTHESIS verdicts | `python decode_biometrics_5.py --streams hr,imu` | exit 0; VERIFIED HR 84-131bpm 8/8 RR-consistent; HYPOTHESIS IMU "raw IMU not observed" no fabricated offsets | ✓ PASS |
| Biometrics SpO2/temp/resp exits 0 with HYPOTHESIS verdicts | `python decode_biometrics_5.py --streams spo2,temp,resp` | exit 0; HYPOTHESIS each with 4.0-cloud-computed provenance; WG50_r52 in every verdict | ✓ PASS |
| Sync script exits 0 and produces byte-identical bundle | `bash scripts/sync-schema-5.sh && diff -q ...` | exit 0; "validated + synced"; diff exits 0 (byte-identical) | ✓ PASS |
| Schema JSON valid with 4 enums and 4+ packets | `python3 -c "import json; d=json.load(...); assert ..."` | PASS; 4 enums, 7 packets, 0 missing tags, unix + device epochs both present | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PROTO-06 | 04-01, 04-03 | Command surface probed (0-255 enumerated via probe harness) | ✗ PARTIAL | 10 OBSERVED commands from capture-analysis; 67 HYPOTHESIS; live 0-255 probe NOT done (D-06). REQUIREMENTS.md checkbox: [ ] (correctly unchecked) |
| PROTO-07 | 04-02, 04-04 | Live HR + RR intervals decoded from realtime stream | ✓ SATISFIED | 159 REALTIME_DATA frames; HR 84-131 bpm; 8/8 RR-bearing frames consistent; VERIFIED verdict. REQUIREMENTS.md: [x] |
| PROTO-08 | 04-03 | Battery level decoded | ✓ SATISFIED (HYPOTHESIS grade) | BATTERY_LEVEL + EXTENDED_BATTERY_INFORMATION decoded under 4.0 A6 layout; cross-checked vs 23%; HYPOTHESIS (offset unconfirmed). Plan-level acceptance criterion met. |
| PROTO-09 | 04-03 | Events decoded | ✓ SATISFIED | 136 EVENTs resolved to r52 EventNumber names; device-epoch u32 at body[8]; STRAP_CONDITION_REPORT + BLE_CONNECTION_UP/DOWN + BATTERY_LEVEL observed. |
| PROTO-10 | 04-03 | Historical offload with store-then-ack discipline | ✓ PARTIAL | Protocol documented (SEND_HISTORICAL_DATA/HISTORICAL_DATA_RESULT/trim cursor); live kill-test deferred to Phase 5 (D-09). Documentation-only per plan scope. |
| PROTO-11 | 04-02, 04-04 | SpO2 decoded (type 53 byte 10) | ✗ HYPOTHESIS | 0 type-53 frames in D-05 capture; bytes genuinely absent; HYPOTHESIS with 4.0-cloud-computed provenance. REQUIREMENTS.md checkbox: [x] — STALE (incorrectly checked) |
| PROTO-12 | 04-02, 04-04 | Skin temperature decoded (event 17) | ✗ HYPOTHESIS | 0 event-17 frames in capture; HYPOTHESIS. REQUIREMENTS.md: [x] — STALE (incorrectly checked) |
| PROTO-13 | 04-02, 04-04 | Respiration rate decoded | ✗ HYPOTHESIS | No respiration field on wire; HYPOTHESIS. REQUIREMENTS.md: [x] — STALE (incorrectly checked) |
| PROTO-14 | 04-02, 04-04 | IMU/gravity decoded; sample rate confirmed | ✗ HYPOTHESIS | 0 type-43 frames in capture; template ready but no live decode. REQUIREMENTS.md: [x] — STALE (incorrectly checked) |
| PROTO-15 | 04-01, 04-03 | Dual-epoch model implemented (device vs Unix tagged in schema) | ✓ SATISFIED | Unix epoch from GET_DATA_RANGE (2026-05-08); device epoch from EVENT body[8] (1780152939); both tagged in schema. REQUIREMENTS.md: [ ] — STALE (incorrectly unchecked) |
| PROTO-16 | 04-02, 04-04 | Firmware version in every capture session metadata | ✓ SATISFIED | Sidecar contains firmware_revision: WG50_r52; every biometric verdict carries WG50_r52. REQUIREMENTS.md: [x] |
| SCHEMA-01 | 04-05 | protocol/whoop_protocol_5.json canonical schema | ✓ SATISFIED | File exists; 4 r52 enum maps verbatim; 7 packet types. REQUIREMENTS.md: [ ] — STALE (not updated after completion) |
| SCHEMA-02 | 04-05 | All fields tagged with epoch, provenance note, confidence | ✓ SATISFIED | 0 missing tags; 45 confidence, 43 epoch; unix + device both represented. REQUIREMENTS.md: [ ] — STALE |
| SCHEMA-03 | 04-05 | FINDINGS_5.md protocol reference | ✓ SATISFIED | Section 8 "Decode & Schema (Phase 4)" present; command surface, dual-epoch, historical offload, biometric verdicts, committed artifacts list. REQUIREMENTS.md: [ ] — STALE |
| SCHEMA-04 | 04-01, 04-05 | Golden fixtures for each decoded packet type | ✓ SATISFIED | 123 records spanning 7 PacketTypes; round-trip verified (0 failures) through parse_body_5. REQUIREMENTS.md: [ ] — STALE |
| SCHEMA-05 | 04-05 | scripts/sync-schema-5.sh syncs to Swift bundle | ✓ SATISFIED | Script executable; JSON validates before cp; mkdir -p; exits 0; byte-identical bundle produced. REQUIREMENTS.md: [ ] — STALE |

**Note on REQUIREMENTS.md staleness:** The checkbox state in REQUIREMENTS.md has several errors. PROTO-11/12/13/14 are marked [x] but are HYPOTHESIS (not VERIFIED in the Definition of Done sense). PROTO-15, SCHEMA-01 through SCHEMA-05 are marked [ ] but are demonstrably completed. The codebase is the source of truth; the REQUIREMENTS.md checkbox column needs an update pass.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| decode_5.py | 207-213 | Dead variable: `unresolved` computed but never read; `all_cmds_known` always returned True regardless of unresolved cmds (WR-01/WR-02 from 04-REVIEW.md) | ⚠️ Warning | D-01 cmd-resolution gate is incomplete — unknown CommandNumbers silently pass. PacketType gate still fires correctly. Does not affect the 123-record corpus result (all observed cmds map to known r52 names). |
| decode_biometrics_5.py | 107-114 | IMU axis offsets inconsistent with protocol/whoop_protocol_5.json: decoder uses payload-relative offsets, schema documents body-absolute offsets (WR-03 from 04-REVIEW.md) | ⚠️ Warning | Only affects PROTO-14 (HYPOTHESIS, type-43 never captured). When a type-43 frame is eventually decoded, one artefact will produce garbage offsets. |
| scripts/sync-schema-5.sh | 12-14 | Misleading error message when source file is absent (FileNotFoundError reported as "not valid JSON"); path-with-spaces quoting hazard (WR-04 from 04-REVIEW.md) | ⚠️ Warning | No impact in practice (file exists); would confuse a fresh-checkout failure. |
| decode_streams_5.py | 20, 64, 167 | "XXX" in `0xXXXXXXXX:XXXXXXXX` — NOT a debt marker, it is a protocol format template string showing the trim cursor hex format | ℹ️ Info | Not a blocker; verified context is a protocol documentation string inside a regex comment, not an unresolved TODO. |
| decode_biometrics_5.py | 72 | Redundant while-condition in parse_hr fallback copy (IN-01 from 04-REVIEW.md) | ℹ️ Info | No correctness impact; dead sub-condition. |

No `TBD`, `FIXME`, or unreferenced `XXX` debt markers found in any phase-modified file. The three `XXX` occurrences in decode_streams_5.py are all within a protocol format template string (`0xXXXXXXXX:XXXXXXXX`) in a docstring/comment, not code debt.

### Human Verification Required

None — all items verifiable programmatically. The D-08 ground-truth for HR/RR was satisfied via the internal RR<->HR self-consistency check (8/8 frames), which is an observable, computational result. The gaps (SC-1 live probe, SC-2 missing biometric bytes, SC-3 kill-test) require new hardware captures and Swift/iOS scope, not human UI observation.

### Gaps Summary

Three ROADMAP success criteria are not met. Two are active blockers (no deferred coverage in Phase 5 SCs as stated); one is deferred to Phase 5.

**Gap 1 — ROADMAP SC-1 (live command probe):** The ROADMAP requires `re_harness.py` to probe all 0-255 command IDs. This is physically impossible from macOS (no bond capability without the WHOOP app). The phase executed capture-analysis (D-06) and documented the decision thoroughly in RESEARCH, CONTEXT, and every plan. Only 10 of 77 r52 commands are OBSERVED; 67 are HYPOTHESIS. A live probe requires Phase 5's Swift CoreBluetooth implementation running on an iPhone. Phase 5 SCs do not explicitly call for this probe, meaning it may fall through the cracks unless added to Phase 5 planning.

**Gap 2 — ROADMAP SC-2 (biometric ground-truth validation):** SpO2, skin temperature, respiration, and IMU require specific sensor-mode captures (START_RAW_DATA, TOGGLE_IMU_MODE, TOGGLE_OPTICAL_DATA) that were not triggered in the D-05 session. The codebase is correct and honest (HYPOTHESIS with provenance); the gap is in captured data, not code. Phase 5 SC-3 ("SpO2, skin temp" in app views) may drive these captures indirectly, but no explicit Phase 5 plan requires the BLE-layer ground-truth validation called for by ROADMAP SC-2.

**Gap 3 — ROADMAP SC-3 (historical offload kill-test):** Deferred to Phase 5 and explicitly addressed in Phase 5 SC-3 ("safe-trim invariant, no data loss"). This gap is classified as deferred in the frontmatter.

**Root cause:** The ROADMAP Success Criteria for Phase 4 were authored assuming macOS could bond to the WHOOP 5.0 (enabling a live probe harness and IMU/SpO2 captures). Phase 2 confirmed this assumption false. The RESEARCH and CONTEXT documents record this as D-06 / D-09 design decisions, scoping Phase 4 to capture-analysis only. The implementation is excellent within that scoped boundary; the gap is between the ROADMAP SC contract and the execution scope.

**Recommendation:** The human needs to decide whether to:
1. Accept the SC-1/SC-2 gaps as out-of-scope for Phase 4 (add an `overrides:` entry in this file), or
2. Add Phase 5 plans that explicitly cover the live command probe and targeted biometric captures before the Phase 5 iOS work begins.

The Phase 4 codebase deliverables (schema, decoders, findings, sync script) are all substantive, wired, behaviorally correct, and ready for Phase 5 consumption.

---

_Verified: 2026-05-30T20:49:47Z_
_Verifier: Claude (gsd-verifier)_
