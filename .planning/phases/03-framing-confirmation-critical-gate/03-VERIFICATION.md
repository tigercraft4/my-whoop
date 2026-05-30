---
phase: 03-framing-confirmation-critical-gate
verified: 2026-05-30T00:00:00Z
status: passed
score: 13/13 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 11/13
  gaps_closed:
    - "protocol/whoop_protocol_5.json body entry corrected from off:5 to off:4; framing_notes layout string arithmetic made consistent (no separate [role 1B] segment; 4 header + length body + 4 trailer = length+8)"
    - "Dead code removed from build_report() — the unused 'frames = list(reassemble(...))' first extract_frames() call is gone; each capture now invokes extract_frames() exactly once"
  gaps_remaining: []
  regressions: []
---

# Phase 03: Framing Confirmation Critical Gate — Verification Report

**Phase Goal:** Confirm whether the 4.0 inner framing is reused in WHOOP 5.0 or a new Maverick outer wrapper is present. Run the CRC gate, characterise the wrapper if found, and commit the go/no-go verdict that unblocks Phase 4.
**Verified:** 2026-05-30
**Status:** passed
**Re-verification:** Yes — after gap closure (2 gaps closed, 0 remaining)

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Developer runs validate_frames_5.py and sees a per-characteristic pass/fail report | VERIFIED | Script produces correct output. build_report() now calls extract_frames() exactly once per capture — dead code (former line 207) removed. |
| 2 | 4.0 CRC8 + CRC32-LE gate documents 0.0% pass rate (PROTO-04 negative result) | VERIFIED | Script prints "4.0 CRC gate pass rate: 0.0%" and "0/10056 CRC8+CRC32 checks over 5028 frames". Evidence sidecar records crc_4_0_pass_rate: "0%". |
| 3 | strip_maverick() removes the 4-byte header + 4-byte trailer and returns the flat body (PROTO-05) — AND the schema JSON correctly encodes the body offset as the single source of truth for Phase 5 loaders | VERIFIED | validate_frames_5.py strip_maverick() returns frame[4:4+length] correctly — test vector bytes.fromhex('aa0108000001e67123942200c0896bce') -> '0001e67123942200'. AND protocol/whoop_protocol_5.json now encodes body at off:4. framing_notes layout string is arithmetically consistent: 4 header bytes + length body bytes + 4 trailer bytes = length + 8. No separate [role 1B] segment. |
| 4 | frames_5_golden.json contains >=20 wrapper-stripped frames spanning cmd-resp, events, and data across two sessions | VERIFIED | 46 entries confirmed. Characteristics: FD4B0002, FD4B0003, FD4B0004, FD4B0005. First key is "hex". Spans both capture sessions. |
| 5 | D-01b fallback present (prints "Fallback: no existing captures yielded >=20 frames" if <20 frames) | VERIFIED | Exact string confirmed present in validate_frames_5.py line 249. |
| 6 | D-02b: Both CRC8 (poly 0x07) and CRC32-LE checks run on every frame candidate | VERIFIED | verify_4_0() runs both checks unconditionally. CRC8_TABLE generated with CRC8_POLY=0x07. CRC32 via zlib.crc32 & 0xFFFFFFFF. |
| 7 | D-02c: frames_5_golden.json mirrors frames.json format with hex as first key | VERIFIED | list(d[0].keys())[0] == "hex" confirmed. Fields: hex, type, seq, cmd, payload, characteristic, handle, role, length, body_hex, trailer_hex, crc8_4_0_ok, crc32_4_0_ok. |
| 8 | D-03: strip_maverick docstring documents field offsets and NO nested 0xAA frame | VERIFIED | Docstring present at line 113-120; contains "There is NO nested 0xAA frame to recover (RESEARCH Finding 5 / Assumption A2)". |
| 9 | protocol/whoop_protocol_5.json exists with Maverick wrapper envelope, not the 4.0 inner frame | VERIFIED | version:0 confirmed. Length at off:2 (correct — confirms wrapper, not 4.0). Role at off:4. Body at off:4 (CORRECTED from off:5). SOF confidence:VERIFIED. Trailer confidence:HYPOTHESIS. |
| 10 | GATT constants carried as single source of truth (service UUID + 5 custom characteristics + legacy-ABSENT) | VERIFIED | service:"FD4B0001-CCE1-4033-93CE-002D5875F58A", 7 characteristics, legacy_61080001:"ABSENT". All VERIFIED confidence. |
| 11 | firmware_revision WG50_r52 recorded and tagged VERIFIED | VERIFIED | firmware_revision.value:"WG50_r52", source:"Device Information 0x2A27", confidence:"VERIFIED". |
| 12 | Evidence sidecar records 4.0 CRC gate 0% pass rate, 5028/5028 wrapper-overhead consistency, frame counts by characteristic | VERIFIED | re/capture/evidence/2026-05-30-framing-5.meta.yaml: crc_4_0_pass_rate:"0%", wrapper_overhead_consistent:"5028/5028", frames_by_characteristic with all four handles. |
| 13 | FINDINGS_5.md has Phase 3 framing section with exact go/no-go verdict, r52 enum-map note, and references whoop_protocol_5.json | VERIFIED | Section "## 7. Framing (Phase 3)" present. Verdict "wrapper characterised, decode work cleared with wrapper-strip step" present verbatim. "whoop_protocol_5.json" referenced. "r52" mentioned. |

**Score:** 13/13 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `re/survey_5/validate_frames_5.py` | CRC gate + parse_maverick/strip_maverick + golden writer | VERIFIED | 292 lines. Contains def crc8, def verify_4_0, def parse_maverick, def strip_maverick, def reassemble, def extract_frames, def build_report, def main. No whoomp import. No 2026-05-30-ios.pklg string. Dead code removed — build_report() calls extract_frames() once per capture. |
| `re/survey_5/frames_5_golden.json` | >=20 hex-first entries spanning multiple characteristics | VERIFIED | 46 entries. hex is first key. FD4B0002/03/04/05 all represented. |
| `protocol/whoop_protocol_5.json` | Maverick wrapper envelope + GATT + firmware, confidence-tagged, body at off:4 | VERIFIED | File exists and is substantively populated. body entry now at off:4 (corrected). framing_notes layout arithmetic consistent: 4hdr + length-body + 4trailer = length+8. Trailer tagged HYPOTHESIS. |
| `re/capture/evidence/2026-05-30-framing-5.meta.yaml` | Pass-rate + wrapper-overhead evidence sidecar, redacted | VERIFIED | Contains tshark, device_identity:[REDACTED], results block, verdict, raw_artifacts_local_only, no BD_ADDR pattern. Gitignore confirmed. |
| `FINDINGS_5.md` | Phase 3 framing section + go/no-go verdict | VERIFIED | Section 7 present. Exact verdict present. whoop_protocol_5.json referenced. r52 noted. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `re/survey_5/validate_frames_5.py` | `re/capture/samples/whoop- iPhone de Francisco.pklg` | tshark subprocess, btatt.value | VERIFIED | DEFAULT_CAPTURES hardcodes the correct filename with space. extract_frames() uses tshark -Y btatt.value -T fields. |
| `re/survey_5/validate_frames_5.py` | `re/survey_5/frames_5_golden.json` | json.dump to Path(__file__).parent | VERIFIED | OUT_PATH = Path(__file__).parent / "frames_5_golden.json". json.dump(golden, f, indent=2). |
| `FINDINGS_5.md` | `protocol/whoop_protocol_5.json` | Phase 3 section references committed schema v0 | VERIFIED | "whoop_protocol_5.json" appears in FINDINGS_5.md section 7. |
| `protocol/whoop_protocol_5.json` | Phase 5 Swift/Python schema loaders | top-level keys compatible with 4.0 layout, body at off:4 | VERIFIED | Top-level keys version/enums/envelope/packets present. body entry at off:4 — loader reading frame[4:4+length] will slice correctly. |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| strip_maverick() returns correct flat body | python3 test vector aa0108000001e67123942200c0896bce | "0001e67123942200" — CORRECT | PASS |
| verify_4_0() returns (False, False) on 5.0 frame | python3 test vector | (False, False) — CONFIRMED | PASS |
| parse_maverick() returns None for short frame | python3 with b'\xaa\x00' | None — CORRECT | PASS |
| frames_5_golden.json has >=20 entries, hex-first | python3 json check | 46 entries, first key "hex" | PASS |
| whoop_protocol_5.json body offset | python3 inspect envelope | off:4 (CORRECT — gap fixed) | PASS |
| framing_notes arithmetic consistent | python3 segment analysis | 4 header + length body + 4 trailer = length+8, no separate [role 1B] | PASS |
| build_report() single extract_frames() call per capture | grep -n "frames = list" | 0 matches (dead code removed — gap fixed) | PASS |
| No whoomp import in validate_frames_5.py | grep -c 'whoomp' | 0 | PASS |
| Captures gitignored | git check-ignore | re/capture/samples/ gitignored | PASS |
| No BD_ADDR in sidecar | grep -iE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | no match | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PROTO-04 | 03-01, 03-03 | 4.0 inner framing (0xAA SOF / CRC8 poly 0x07 / CRC32-zlib) validated against 20+ captured 5.0 frames (>=98% pass rate gate) | SATISFIED (documented negative) | 5028 frames validated. 0.0% pass rate documented. Gate was run and produced a documented 0% result — the correct Phase 3 outcome. Evidence sidecar + FINDINGS_5.md section 7. |
| PROTO-05 | 03-01, 03-02, 03-03 | Maverick outer wrapper characterised if 4.0 CRC validation fails — structure documented in whoop_protocol_5.json | SATISFIED | strip_maverick() works correctly. FINDINGS_5.md documents the wrapper. whoop_protocol_5.json body entry now at off:4 — the canonical schema is correct. The wrapper structure is fully and correctly documented. |

**Note on PROTO-04 definition:** REQUIREMENTS.md defines PROTO-04 as ">=98% pass rate gate". The actual result is 0% — a documented negative. The plans and CONTEXT.md explicitly define this as the correct Phase 3 outcome (running the gate and documenting the result, even if it fails). PROTO-04 is satisfied as "gate run, result documented".

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `re/survey_5/validate_frames_5.py` | 283 | Unguarded json.dump write — no exception handling, no atomic rename | WARNING | Partial write could corrupt frames_5_golden.json silently. Non-blocking for Phase 4. |
| `re/survey_5/validate_frames_5.py` | 247 | MIN_FRAMES check does not guard empty golden corpus | WARNING | Could write empty [] to frames_5_golden.json and print success if all frames fail parse_maverick. Non-blocking in practice — 5028/5028 pass. |
| `protocol/whoop_protocol_5.json` | 12 | trailer uses "off": -4 — Python slice convention, not portable protocol offset | WARNING | Swift/Lua parsers treating off as absolute byte index will misinterpret -4. Documented as HYPOTHESIS — non-blocking. |

No BLOCKERs found. The two previously blocking items (body off:5, dead code double-invocation) are confirmed resolved.

---

### Human Verification Required

None — all checks were automatable. The go/no-go verdict and all numerical claims were verifiable from committed artifacts.

---

### Gaps Summary

No gaps. Both gaps from the initial verification are confirmed closed:

**Gap 1 (CLOSED) — Schema body offset corrected:** `protocol/whoop_protocol_5.json` body entry changed from `off:5` to `off:4`. The `framing_notes` layout string no longer has a separate `[role 1B]` segment — header arithmetic is now 4 bytes (SOF 1B + version 1B + length 2B) + body (length bytes) + trailer 4B = length + 8. Consistent throughout.

**Gap 2 (CLOSED) — Dead code removed from build_report():** The unused `frames = list(reassemble(f for _, f in extract_frames(Path(cap))))` first call is gone. `build_report()` now iterates `extract_frames()` directly in the inner loop — one tshark subprocess per capture, no dead variable.

---

_Verified: 2026-05-30_
_Verifier: Claude (gsd-verifier)_
