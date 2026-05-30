---
phase: 03-framing-confirmation-critical-gate
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - re/survey_5/validate_frames_5.py
  - re/survey_5/test_validate_frames_5.py
  - protocol/whoop_protocol_5.json
  - re/capture/evidence/2026-05-30-framing-5.meta.yaml
  - FINDINGS_5.md
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-05-30
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

The core pure functions (`crc8`, `parse_maverick`, `strip_maverick`, `verify_4_0`) are correct and well-tested. The CRC8 table is arithmetically verified. The `strip_maverick` body slice `frame[4:4+length]` is correct, and the `trailer = frame[-4:]` math holds under all valid inputs. The subprocess invocation uses a list (no `shell=True`), so no shell injection is possible. Evidence sidecar and FINDINGS_5.md are properly redacted.

Two BLOCKER-class defects were found:

1. **`build_report` calls `extract_frames` twice per capture** (line 207 result is dead code), launching two tshark processes per file. The first result is discarded — wasted work and a source of silent divergence if tshark output is non-deterministic between runs.

2. **`whoop_protocol_5.json` envelope `body` offset is wrong** (`off: 5`) and the `framing_notes` layout string has an arithmetic contradiction with the `length + 8` invariant. A Phase 4 implementer reading `off: 5` and applying `length` bytes from that offset would read one byte past the body and into the trailer on every frame.

---

## Critical Issues

### CR-01: `build_report` invokes `extract_frames` twice per capture — first result is dead code

**File:** `re/survey_5/validate_frames_5.py:207-209`

**Issue:** Line 207 materialises the full generator into `frames` (a list), discarding the handle alongside each frame. The comment on line 208 acknowledges this and immediately re-invokes `extract_frames` on line 209 to recover the handle. The `frames` variable assigned on line 207 is never read again. This launches **two** tshark subprocesses per capture file. Beyond the wasted work, if tshark output is non-deterministic (e.g., packet ordering depends on pcap internal state), the `stats` dict (built from the second call) and the implicit frame count may diverge from what the first call would have produced. The `MIN_FRAMES` check (line 251) and the printed totals are all derived from the second call only, making the first call entirely useless.

**Fix:** Delete line 207 and its comment (lines 207–208). The second `extract_frames` call already provides the `(handle, frame)` pairs needed for all downstream logic:

```python
def build_report(captures):
    """Extract + validate frames from all captures. Returns (records, per_handle_stats)."""
    records = []
    stats = {}
    for cap in captures:
        print(f"\n--- {Path(cap).name} ---")
        for handle, frame in extract_frames(Path(cap)):
            frame = next(reassemble([frame]), None)
            if frame is None:
                continue
            # ... rest of loop unchanged
```

---

### CR-02: `whoop_protocol_5.json` envelope `body` offset is arithmetically inconsistent with the `length + 8` invariant

**File:** `protocol/whoop_protocol_5.json:11`

**Issue:** The `envelope` array declares `body` at `"off": 5` with `"note": "flat body region, length bytes"`. A Phase 4 parser that reads this literally computes `body = frame[5 : 5 + length]`, which is **one byte longer than the body** and **overruns into the trailer**:

```
Verified with FRAME = aa0108000001e67123942200c0896bce, length=8:
  frame[5 : 5+8] = 01e67123942200c0   ← last byte 0xc0 is trailer[0]
  frame[4 : 4+8] = 0001e67123942200   ← correct body (matches code)
```

The correct absolute offset for the body is **4**, not 5. The role byte (`frame[4]`) is `body[0]`; `length` counts the entire body region starting at offset 4 (this is what makes `total_len == length + 8` hold: `4hdr + length_body + 4trailer`). The separate `role` envelope entry at `off: 4` is fine as a named field, but the `body` entry must start at `off: 4` as well (with the understanding that `body[0] == role`).

The `framing_notes` string has the same error: it renders the layout as `[role 1B][... body (length bytes, FLAT) ...]`, which totals `4 + 1 + length + 4 = length + 9`, contradicting the `total_len == length + 8` claim in the same sentence.

**Fix — JSON envelope entry:**

```json
{"off": 4, "len": -1, "name": "body", "cat": "body", "confidence": "VERIFIED",
 "note": "flat body region; frame[4:4+length]. body[0] == role (same byte as the role field above). length bytes total including role. NOT a nested 0xAA frame (Finding 5). Phase 4 populates field maps."}
```

**Fix — `framing_notes` layout string:** replace

```
[role 1B][... body (length bytes, FLAT) ...]
```

with

```
[body (length bytes FLAT, body[0]==role) ...]
```

so the arithmetic is `4hdr + length + 4trailer = length + 8` consistently.

---

## Warnings

### WR-01: `json.dump` write is unguarded — silent failure on permission error or full disk

**File:** `re/survey_5/validate_frames_5.py:285-286`

**Issue:** The file write at lines 285–286 has no exception handling. A permissions error, full disk, or interrupted write will propagate as an unhandled exception from inside `main()`. Because `main()` returns `int`, `sys.exit(main(...))` will receive an exception instead of an integer, producing a confusing traceback rather than the script's own error message and exit code 1. Additionally, a partial write could leave `frames_5_golden.json` in a corrupted state (truncated JSON), which Phase 4 would silently consume.

**Fix:** Wrap the write block and use a temporary file with atomic rename:

```python
import tempfile, os

tmp = OUT_PATH.with_suffix(".json.tmp")
try:
    with open(tmp, "w") as f:
        json.dump(golden, f, indent=2)
    tmp.replace(OUT_PATH)
except OSError as exc:
    print(f"ERROR: could not write {OUT_PATH}: {exc}")
    return 1
```

---

### WR-02: `MIN_FRAMES` check does not guard against an empty golden corpus

**File:** `re/survey_5/validate_frames_5.py:249-253`

**Issue:** The `MIN_FRAMES` threshold (line 251) tests `total` — the count of all `0xAA`-SOF ATT frames across the custom-service handles. If those frames are present but **none pass the Maverick wrapper check** (e.g., a capture from a different firmware build where the outer format changed), `records` will be empty. The script will then write an empty `[]` to `frames_5_golden.json` and print a misleading success message (`"0 of 0 wrapper-stripped frames curated"`). Phase 4, which imports this file as its starting corpus, would then proceed on an empty dataset without any error.

**Fix:** Add a check after the curation loop:

```python
if not golden:
    print("ERROR: golden corpus is empty — 0 wrapper-ok frames in all captures")
    return 1
```

---

### WR-03: `whoop_protocol_5.json` trailer uses `"off": -4` — a Python-slice convention, not a portable protocol offset

**File:** `protocol/whoop_protocol_5.json:12`

**Issue:** The trailer envelope entry uses `"off": -4`. Negative offsets are a Python-list/slice convention; they carry no standard meaning in binary protocol definitions. A Swift struct parser, a Wireshark Lua dissector, or any language that treats `off` as an absolute byte index will misinterpret `-4` as either an error or a wildly wrong offset (e.g., `0xFFFFFFFC` if treated as unsigned). Because the file is declared as the "single source of truth for the 5.0 GATT UUIDs" and the Phase 5 Swift loaders are explicitly mentioned in `schema_note`, this ambiguity is a real downstream hazard.

**Fix:** Replace the negative sentinel with an explicit note that the offset is relative to the end of the frame:

```json
{"off": -4, "off_note": "offset from end of frame (length+4 from start)", "len": 4, "name": "trailer", ...}
```

Or, preferably, document the absolute offset formula explicitly:

```json
{"off": "4 + length", "len": 4, "name": "trailer", ...}
```

and update the schema loader (Swift/Python) to handle the formula string.

---

## Info

### IN-01: Test suite has no coverage for `reassemble()`

**File:** `re/survey_5/test_validate_frames_5.py`

**Issue:** `reassemble()` is not exercised by any test. The five existing tests cover `crc8`, `verify_4_0`, `parse_maverick`, and `strip_maverick`. `reassemble()` is used in the production path inside `build_report` (line 210); its SOF-filtering semantics (drop frames where `f[0] != 0xAA`, pass the rest) are simple but untested. A regression to the filter condition would silently corrupt the golden corpus.

**Fix:** Add two assertions:

```python
def test_reassemble_filters_sof():
    import validate_frames_5 as v
    frames = [b"\xaa\x01\x00", b"\xbb\x01\x00", b"", b"\xaa\x02\x00"]
    result = list(v.reassemble(frames))
    assert result == [b"\xaa\x01\x00", b"\xaa\x02\x00"], result
```

---

### IN-02: `DEFAULT_CAPTURES` path commits owner's first name into version history

**File:** `re/survey_5/validate_frames_5.py:149`

**Issue:** The hardcoded path `"whoop- iPhone de Francisco.pklg"` encodes the device owner's first name into a committed source file. The `.pklg` captures are correctly gitignored, but the name is now in version history. This is low-severity (first name only, no identifiers) but is inconsistent with the redaction discipline applied to BD_ADDR, serial, and CoreBluetooth UUID elsewhere.

**Fix:** Replace with a path-only comment and a generic fallback name, or document the literal filename in the runbook only (not in the script):

```python
DEFAULT_CAPTURES = [
    # Phase 1 iOS ATT capture — filename contains device name; update to match local file.
    REPO_ROOT / "re/capture/samples/whoop-ios-phase1.pklg",
    REPO_ROOT / "re/capture/samples/2026-05-30-smp-bond-full.pklg",
]
```

with a note in `re/capture/ios-packetlogger.md` that the actual filename may include the paired iPhone's name.

---

_Reviewed: 2026-05-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
