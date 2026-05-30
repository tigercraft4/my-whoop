---
phase: 03-framing-confirmation-critical-gate
verified: 2026-05-30T00:00:00Z
status: gaps_found
score: 11/13 must-haves verified
overrides_applied: 0
gaps:
  - truth: "strip_maverick() removes the 4-byte header and 4-byte trailer and returns the flat body (PROTO-05) — AND the schema JSON correctly encodes the body offset as the single source of truth for Phase 5 loaders"
    status: failed
    reason: "validate_frames_5.py implements strip_maverick() correctly (frame[4:4+length]), but protocol/whoop_protocol_5.json declares body at off:5 instead of off:4. A Phase 5 Swift/Python loader reading off:5 literally would compute frame[5:5+length], overrunning one byte into the trailer on every frame. The schema is declared the single source of truth for Phase 5 loaders (schema_note). This is CR-02 from 03-REVIEW.md — not corrected before phase submission."
    artifacts:
      - path: "protocol/whoop_protocol_5.json"
        issue: "envelope body entry has off:5 (wrong); must be off:4. framing_notes layout string is also arithmetically inconsistent ([role 1B][body length bytes] sums to length+9, contradicting length+8 claim in the same sentence)."
    missing:
      - "Change envelope body entry from off:5 to off:4"
      - "Update body note to read 'flat body region; frame[4:4+length]. body[0]==role. length bytes total including role.'"
      - "Fix framing_notes layout string to eliminate the off-by-one: remove the separate [role 1B] segment so arithmetic is 4hdr + length + 4trailer = length+8"

  - truth: "Developer runs validate_frames_5.py against the two existing .pklg captures and sees a per-characteristic pass/fail report"
    status: partial
    reason: "The script produces the correct report, but build_report() calls extract_frames() twice per capture (lines 207-209). The first call result is dead code (frames variable never read). This launches two tshark subprocesses per file. The report is functionally correct today (both calls yield the same result on deterministic captures), but the double invocation is a latent correctness risk and wastes resources. This is CR-01 from 03-REVIEW.md — not corrected before phase submission."
    artifacts:
      - path: "re/survey_5/validate_frames_5.py"
        issue: "build_report() line 207: 'frames = list(reassemble(f for _, f in extract_frames(Path(cap))))' — result never used; extract_frames called again on line 209. Delete line 207 and its comment."
    missing:
      - "Remove dead first extract_frames() call from build_report() (lines 207-208)"
---

# Phase 03: Framing Confirmation Critical Gate — Verification Report

**Phase Goal:** Confirm whether the 4.0 inner framing is reused in WHOOP 5.0 or a new Maverick outer wrapper is present. Run the CRC gate, characterise the wrapper if found, and commit the go/no-go verdict that unblocks Phase 4.
**Verified:** 2026-05-30
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Developer runs validate_frames_5.py and sees a per-characteristic pass/fail report | PARTIAL | Script produces correct output. build_report() calls extract_frames() twice per capture (dead code on line 207 — CR-01, not fixed). |
| 2 | 4.0 CRC8 + CRC32-LE gate documents 0.0% pass rate (PROTO-04 negative result) | VERIFIED | Script prints "4.0 CRC gate pass rate: 0.0%" and "0/10056 CRC8+CRC32 checks over 5028 frames". Evidence sidecar records crc_4_0_pass_rate: "0%". |
| 3 | strip_maverick() removes the 4-byte header + 4-byte trailer and returns the flat body (PROTO-05) | VERIFIED (code) / FAILED (schema) | validate_frames_5.py strip_maverick() returns frame[4:4+length] correctly — verified with test vector (bytes.fromhex('aa0108000001e67123942200c0896bce') -> '0001e67123942200'). BUT protocol/whoop_protocol_5.json encodes body at off:5 — a concrete off-by-one that would cause Phase 5 Swift/Python loaders to read one byte into the trailer. Schema is declared single source of truth. |
| 4 | frames_5_golden.json contains >=20 wrapper-stripped frames spanning cmd-resp, events, and data across two sessions | VERIFIED | 46 entries confirmed. Characteristics: FD4B0002, FD4B0003, FD4B0004, FD4B0005. First key is "hex". Spans both capture sessions. |
| 5 | D-01b fallback present (prints "Fallback: no existing captures yielded >=20 frames" if <20 frames) | VERIFIED | grep confirms the exact string present in validate_frames_5.py line 251. |
| 6 | D-02b: Both CRC8 (poly 0x07) and CRC32-LE checks run on every frame candidate | VERIFIED | verify_4_0() runs both checks unconditionally. CRC8_TABLE generated with CRC8_POLY=0x07. CRC32 via zlib.crc32 & 0xFFFFFFFF. |
| 7 | D-02c: frames_5_golden.json mirrors frames.json format with hex as first key | VERIFIED | list(d[0].keys())[0] == "hex" confirmed. Fields: hex, type, seq, cmd, payload, characteristic, handle, role, length, body_hex, trailer_hex, crc8_4_0_ok, crc32_4_0_ok. |
| 8 | D-03: strip_maverick docstring documents field offsets and NO nested 0xAA frame | VERIFIED | Docstring present at line 113-120; contains "There is NO nested 0xAA frame to recover (RESEARCH Finding 5 / Assumption A2)". |
| 9 | protocol/whoop_protocol_5.json exists with Maverick wrapper envelope, not the 4.0 inner frame | VERIFIED (layout) / FAILED (body offset) | version:0 confirmed. Length at off:2 (correct — confirms wrapper, not 4.0). Role at off:4. SOF confidence:VERIFIED. Trailer confidence:HYPOTHESIS. But body at off:5 is wrong — see truth 3. |
| 10 | GATT constants carried as single source of truth (service UUID + 5 custom characteristics + legacy-ABSENT) | VERIFIED | service:"FD4B0001-CCE1-4033-93CE-002D5875F58A", 7 characteristics, legacy_61080001:"ABSENT". All VERIFIED confidence. |
| 11 | firmware_revision WG50_r52 recorded and tagged VERIFIED | VERIFIED | firmware_revision.value:"WG50_r52", source:"Device Information 0x2A27", confidence:"VERIFIED". |
| 12 | Evidence sidecar records 4.0 CRC gate 0% pass rate, 5028/5028 wrapper-overhead consistency, frame counts by characteristic | VERIFIED | re/capture/evidence/2026-05-30-framing-5.meta.yaml: crc_4_0_pass_rate:"0%", wrapper_overhead_consistent:"5028/5028", frames_by_characteristic with all four handles. |
| 13 | FINDINGS_5.md has Phase 3 framing section with exact go/no-go verdict, r52 enum-map note, and references whoop_protocol_5.json | VERIFIED | Section "## 7. Framing (Phase 3)" present. Verdict "wrapper characterised, decode work cleared with wrapper-strip step" present verbatim. "whoop_protocol_5.json" referenced. "r52" mentioned. |

**Score:** 11/13 truths verified (2 gaps — 1 FAILED blocker on schema body offset, 1 PARTIAL on double tshark invocation)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `re/survey_5/validate_frames_5.py` | CRC gate + parse_maverick/strip_maverick + golden writer | VERIFIED | 294 lines. Contains def crc8, def verify_4_0, def parse_maverick, def strip_maverick, def reassemble, def extract_frames, def build_report, def main. No whoomp import. No 2026-05-30-ios.pklg string. |
| `re/survey_5/frames_5_golden.json` | >=20 hex-first entries spanning multiple characteristics | VERIFIED | 46 entries. hex is first key. FD4B0002/03/04/05 all represented. |
| `protocol/whoop_protocol_5.json` | Maverick wrapper envelope + GATT + firmware, confidence-tagged | PARTIAL/STUB | File exists and is substantively populated. Critical defect: body envelope entry at off:5 instead of off:4 — causes off-by-one in downstream schema loaders (CR-02). |
| `re/capture/evidence/2026-05-30-framing-5.meta.yaml` | Pass-rate + wrapper-overhead evidence sidecar, redacted | VERIFIED | Contains tshark, device_identity:[REDACTED], results block, verdict, raw_artifacts_local_only, no BD_ADDR pattern. Gitignore confirmed. |
| `FINDINGS_5.md` | Phase 3 framing section + go/no-go verdict | VERIFIED | Section 7 present. Exact verdict present. whoop_protocol_5.json referenced. r52 noted. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `re/survey_5/validate_frames_5.py` | `re/capture/samples/whoop- iPhone de Francisco.pklg` | tshark subprocess, btatt.value | VERIFIED | DEFAULT_CAPTURES hardcodes the correct filename with space. extract_frames() uses tshark -Y btatt.value -T fields. |
| `re/survey_5/validate_frames_5.py` | `re/survey_5/frames_5_golden.json` | json.dump to Path(__file__).parent | VERIFIED | OUT_PATH = Path(__file__).parent / "frames_5_golden.json". json.dump(golden, f, indent=2). |
| `FINDINGS_5.md` | `protocol/whoop_protocol_5.json` | Phase 3 section references committed schema v0 | VERIFIED | "whoop_protocol_5.json" appears in FINDINGS_5.md section 7. |
| `protocol/whoop_protocol_5.json` | Phase 5 Swift/Python schema loaders | top-level keys compatible with 4.0 layout | PARTIAL | Top-level keys version/enums/envelope/packets present (loader compatible). BUT body offset at off:5 is wrong — schema loader reading this will produce incorrect frame slices. |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| strip_maverick() returns correct flat body | `python3 -c "..."` with test vector | "0001e67123942200" — CORRECT | PASS |
| verify_4_0() returns (False, False) on 5.0 frame | `python3 -c "..."` with test vector | (False, False) — CONFIRMED | PASS |
| parse_maverick() returns None for short frame | `python3 -c "..."` with b'\xaa\x00' | None — CORRECT | PASS |
| frames_5_golden.json has >=20 entries, hex-first | `python3 -c "import json; ..."` | 46 entries, first key "hex" | PASS |
| whoop_protocol_5.json body offset | `python3 -c "..."` inspect envelope | off:5 (WRONG — should be 4) | FAIL |
| No whoomp import in validate_frames_5.py | `grep -c 'whoomp' ...` | 0 | PASS |
| Captures gitignored | `git check-ignore re/capture/samples/2026-05-30-smp-bond-full.pklg` | path returned (gitignored) | PASS |
| No BD_ADDR in sidecar | `grep -iE '([0-9a-f]{2}:){5}[0-9a-f]{2}'` | no match | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PROTO-04 | 03-01, 03-03 | 4.0 inner framing (0xAA SOF / CRC8 poly 0x07 / CRC32-zlib) validated against 20+ captured 5.0 frames (>=98% pass rate gate) | SATISFIED (documented negative) | 5028 frames validated. 0.0% pass rate documented. The requirement is satisfied by a documented negative — the gate was run and produced a 0% result, which is the correct outcome and is the Phase 3 deliverable. Evidence sidecar + FINDINGS_5.md section 7. |
| PROTO-05 | 03-01, 03-02, 03-03 | Maverick outer wrapper characterised if 4.0 CRC validation fails — structure documented in whoop_protocol_5.json | PARTIAL | strip_maverick() works correctly in code. FINDINGS_5.md documents the wrapper. BUT whoop_protocol_5.json has body at off:5 (wrong), which is the primary documentation artifact for PROTO-05. The structural defect in the schema means the wrapper is not fully correctly documented in the canonical source. |

**Note on PROTO-04 definition:** REQUIREMENTS.md defines PROTO-04 as ">=98% pass rate gate". The actual result is 0% — a documented negative. The plans and CONTEXT.md explicitly define this as the correct Phase 3 outcome (running the gate and documenting the result, even if it fails). PROTO-04 is satisfied as "gate run, result documented".

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `protocol/whoop_protocol_5.json` | 11 | body at off:5 instead of off:4 | BLOCKER | Phase 5 Swift/Python loaders using this as single source of truth will read one byte past the body into the trailer on every frame |
| `protocol/whoop_protocol_5.json` | 4 | framing_notes layout string: [role 1B][body length bytes] sums to length+9, contradicts length+8 invariant in same sentence | BLOCKER | Arithmetic inconsistency in the canonical schema — same root cause as body offset error |
| `re/survey_5/validate_frames_5.py` | 207 | Dead code: `frames = list(reassemble(...))` — result never used; extract_frames called twice | WARNING | Doubles tshark subprocess count; latent correctness risk if capture is non-deterministic |
| `re/survey_5/validate_frames_5.py` | 285 | Unguarded json.dump write — no exception handling, no atomic rename | WARNING | Partial write could corrupt frames_5_golden.json silently |
| `re/survey_5/validate_frames_5.py` | 249 | MIN_FRAMES check does not guard empty golden corpus | WARNING | Could write empty [] to frames_5_golden.json and print success |
| `protocol/whoop_protocol_5.json` | 12 | trailer uses "off": -4 — Python slice convention, not portable protocol offset | WARNING | Swift/Lua parsers treating off as absolute byte index will misinterpret -4 |

---

### Gaps Summary

Two gaps block goal achievement:

**Gap 1 (BLOCKER) — Schema body offset wrong in protocol/whoop_protocol_5.json:**

The envelope entry for `body` is at `"off": 5` but the correct value is `"off": 4`. The code (`strip_maverick`) uses `frame[4:4+length]` correctly, but the JSON schema — declared as the single source of truth for Phase 5 loaders — will instruct any loader reading it literally to compute `frame[5:5+length]`, which overruns one byte into the trailer. Demonstrated with the canonical test vector: `frame[5:5+8]` = `01e67123942200c0` (includes `0xc0`, trailer byte 0), vs correct `frame[4:4+8]` = `0001e67123942200`. The `framing_notes` field has the same arithmetic inconsistency.

This was identified as CR-02 in `03-REVIEW.md` and was not corrected before phase submission.

**Gap 2 (WARNING) — Dead code double-invocation of extract_frames() in build_report():**

`build_report()` calls `extract_frames()` twice per capture. The first call result (stored in `frames`, line 207) is never read. The second call (line 209) is what actually drives the report. This causes two tshark processes per capture file. The report output is correct today (both calls yield the same result on the deterministic local captures), but the double invocation is a latent correctness bug and a resource waste. Identified as CR-01 in `03-REVIEW.md` and not corrected.

---

### Human Verification Required

None — all checks were automatable. The go/no-go verdict and all numerical claims were verifiable from committed artifacts.

---

_Verified: 2026-05-30_
_Verifier: Claude (gsd-verifier)_
