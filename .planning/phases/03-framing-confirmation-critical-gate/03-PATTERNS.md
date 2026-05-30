# Phase 3: Framing Confirmation (Critical Gate) - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 5 (2 new scripts/data, 1 new JSON, 1 new evidence YAML, 1 extend)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `re/survey_5/validate_frames_5.py` | utility (RE analysis script) | transform (hex in -> CRC/parse -> report + JSON out) | `re/decode.py` + `re/survey_5/hr_5.py` | role-match (logic from decode.py; isolation/header conventions from survey_5 scripts) |
| `re/survey_5/frames_5_golden.json` | fixture (generated corpus) | batch (output artifact) | `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json` | exact (format mirror per D-02c) |
| `protocol/whoop_protocol_5.json` | config (canonical schema) | static data | `protocol/whoop_protocol.json` | exact (top-level layout mirror per D-04) |
| `re/capture/evidence/2026-05-30-framing-5.meta.yaml` | config (evidence sidecar) | static data | `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml` | exact (D-02 evidence policy) |
| `FINDINGS_5.md` (EXTEND §Phase 3) | doc (findings) | static data | `FINDINGS_5.md` existing sections (§1-§6) | exact (extend in place) |

> **Cross-cutting research correction (apply to every file below):** RESEARCH Finding 5 + Assumptions A1/A2 override two CONTEXT.md assumptions. (1) The Phase 1 capture filename is `whoop- iPhone de Francisco.pklg` (with spaces), NOT `2026-05-30-ios.pklg`. (2) `strip_maverick()` returns a FLAT body (`frame[4:4+length]`), there is NO nested `0xAA` frame to re-CRC. Planner must encode both as hard constraints.

---

## Pattern Assignments

### `re/survey_5/validate_frames_5.py` (utility, transform)

**Primary analog:** `re/decode.py` (reassembly + parse + CRC32 logic). **Convention analog:** `re/survey_5/hr_5.py` and `re/survey_5/survey_gatt_5.py` (module docstring style, `device_local_5` import, `Path(__file__).parent` output, `if not committed` isolation). **CRC8 analog:** `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` (poly 0x07 table cross-check).

**Module docstring pattern** (from `survey_gatt_5.py` lines 1-18 / `hr_5.py` lines 1-10):
- Triple-quoted module docstring: one-line purpose, then "Port of / adapted from <4.0 file>", then a run instruction. Reuse this exact shape. State the D-02 isolation (no `whoomp` sys.path import) and the run line `cd re/survey_5 && .venv/bin/python validate_frames_5.py`.

**Reassembly pattern to ADAPT, not import** (`re/decode.py` lines 11-33):
```python
def reassemble(fragments):
    """Yield complete frames from a list of raw notification byte-strings."""
    buf = b""
    need = 0
    for f in fragments:
        if need == 0:
            if not f or f[0] != 0xAA:
                continue  # stray, skip
            if len(f) < 3:
                continue
            length = struct.unpack("<H", f[1:3])[0]   # NOTE: 4.0 offset; 5.0 uses f[2:4]
            total = length + 4
            ...
```
> ADAPT: the 5.0 wrapper length is at `frame[2:4]` and total is `length + 8` (RESEARCH Finding 4, Pitfall 1), not `frame[1:3]` / `length + 4`. tshark already yields complete ATT values, so reassembly may be a no-op pass-through; keep the SOF-skip filter (`f[0] != 0xAA`).

**ANTI-PATTERN — do NOT copy this from `re/decode.py` (lines 7-8):**
```python
sys.path.insert(0, "whoomp/scripts")
from packet import WhoopPacket, PacketType  # noqa: E402
```
> D-02 mandates isolation in `re/survey_5/`. The `whoomp` `WhoopPacket` assumes the 4.0 layout which is wrong for 5.0. Adapt the logic inline; do NOT add this import.

**4.0 CRC gate pattern (run it, document the 0% result)** — port from `re/decode.py:parse_frame()` lines 36-40 + `Framing.swift:verifyFrame` lines 78-92:
```python
# re/decode.py parse_frame (4.0 interpretation):
length = struct.unpack("<H", frame[1:3])[0]
pkt = frame[4:length]
crc_ok = zlib.crc32(pkt) & 0xFFFFFFFF == struct.unpack("<L", frame[length:length+4])[0]
```
> RESEARCH Code Examples block gives the verified-0%-pass `verify_4_0()` and the bitwise `crc8()` table generator (poly 0x07). Use those directly. Cross-check `crc8(b"\x08\x00")` against `Framing.swift:crc8` (D-02b) — the Swift `crc8Table` is at `Framing.swift` lines 4-21.

**Maverick wrapper parse + strip (verified structure)** — from RESEARCH Pattern 2:
```python
def parse_maverick(frame: bytes):
    if len(frame) < 9 or frame[0] != 0xAA or frame[1] != 0x01:
        return None
    length = struct.unpack("<H", frame[2:4])[0]   # 5.0: offset 2, not 1
    if len(frame) != length + 8:                   # 4 hdr + body + 4 trailer
        return None
    role    = frame[4]
    body    = frame[4:4 + length]                   # FLAT body (NO nested 0xAA)
    trailer = frame[-4:]
    return {"length": length, "role": role, "body": body, "trailer": trailer}

def strip_maverick(frame: bytes) -> bytes:
    """Pure bytes->bytes. Strips 4B header + 4B trailer -> flat body. NO inner frame."""
    p = parse_maverick(frame)
    return p["body"] if p else b""
```
> D-03 / Specifics: `strip_maverick()` is a pure function with field offsets in the docstring so Phase 4 can import or inline it.

**Output-path + writer convention** (from `survey_gatt_5.py` lines 33, 85-87):
```python
OUT_PATH = Path(__file__).parent / "frames_5_golden.json"
...
with open(OUT_PATH, "w") as f:
    json.dump(result, f, indent=2)
print(f"\n{OUT_PATH.name} written ...")
```

**Report-printing convention** (from `re/decode.py` lines 48-63 and `hr_5.py` lines 60-68): print a per-characteristic breakdown with frame counts and pass counts. Group by handle/role; print `pass/total` per CRC and an example head hex per group. The 4.0 `decode.py` `bytype` aggregation (lines 49-63) is the model.

**tshark input step** (RESEARCH Pattern 1, verified this session):
```bash
tshark -r "re/capture/samples/whoop- iPhone de Francisco.pklg" \
  -Y "btatt.value" -T fields -e btatt.handle -e btatt.value
# row:  0x099b<TAB>aa0108000001e67123942200c0896bce
```
> Quote the filename (spaces). Filter rows where value starts with `aa` AND handle in `{0x099b,0x099d,0x09a0,0x09a3}` (Pitfall 4). Input mode (stdin / file arg / hardcoded) is Claude's discretion (D-02 discretion).

---

### `re/survey_5/frames_5_golden.json` (fixture, batch)

**Analog:** `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json`

**4.0 fixture format** (analog, lines 1-6) — minimal, `hex`-first:
```json
[
  { "hex": "aa1800ff28000f3de10100003c01e8030000000000000000c64efbea" }
]
```

**5.0 extension** (D-02c + RESEARCH Pattern 3) — keep `hex` as the FIRST key so a future Swift loader stays compatible, then add parsed fields:
```json
[
  {
    "hex": "aa0108000001e67123942200c0896bce",
    "handle": "0x099b",
    "characteristic": "FD4B0002",
    "role": 0,
    "length": 8,
    "body_hex": "0001e671239422",
    "trailer_hex": "c0896bce",
    "crc8_4_0_ok": false,
    "crc32_4_0_ok": false
  }
]
```
> Generated by `validate_frames_5.py` (not hand-written). Internal field set beyond `hex` is Claude's discretion as long as `hex` leads and the 4.0 pattern is mirrored.

---

### `protocol/whoop_protocol_5.json` (config, static data)

**Analog:** `protocol/whoop_protocol.json` (4.0 canonical schema)

**Top-level layout to mirror** (analog lines 1-67): `{ "version": <int>, "enums": {...}, "envelope": [...], "packets": {...} }`. v0 reuses this skeleton and adds GATT + firmware sections per D-04.

**Envelope-entry shape to follow** (analog lines 61-67) — offset/len/name/cat records:
```json
"envelope": [
  {"off": 0, "len": 1, "name": "SOF", "cat": "frame"},
  {"off": 1, "len": 2, "name": "length", "cat": "frame"},
  {"off": 3, "len": 1, "name": "crc8", "cat": "frame"}
]
```
> For 5.0 the envelope is the WRAPPER, not the 4.0 inner frame: `{off:0 SOF 0xAA}`, `{off:1 version 0x01}`, `{off:2 len:2 length-LE}`, `{off:4 role}`, body, `{trailer 4B}` (RESEARCH Finding 4). Tag the trailer `confidence: HYPOTHESIS / OPEN` (Finding 6) — do not assert a CRC algorithm.

**Confidence tagging + GATT/firmware additions** (D-04): add `gatt` (service UUID `FD4B0001-...`, the 5 characteristic UUIDs, `legacy_61080001: ABSENT`) and `firmware_revision: WG50_r52`. Reuse the GATT UUID values verbatim from `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml` lines 9-19 (single source of truth, D-04b). Tag CRC-gate-passed/confirmed items `VERIFIED`, unvalidated items `HYPOTHESIS`. The 4.0 schema has no confidence field — this is a new key; keep existing keys (`version`/`enums`/`envelope`/`packets`) compatible with the 4.0 `Schema.swift` loader.

---

### `re/capture/evidence/2026-05-30-framing-5.meta.yaml` (config, static data)

**Analog:** `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml`

**Sidecar header pattern** (analog lines 1-6):
```yaml
source: "..."
tool: "tshark 4.6.6 + re/survey_5/validate_frames_5.py"
tool_version: "tshark 4.6.6 / Python 3.9.6"
captured: "2026-05-30"
device_identity: "[REDACTED]"   # real identifiers live only in gitignored files
```

**Redaction + raw-artifact-list pattern** (analog lines 54-58): list local-only raw artifacts (the `.pklg` paths) under `raw_artifacts_local_only:` and add a `notes:` line affirming no BD_ADDR / SMP keys / device identifiers committed (DISCLAIMER §2, Pitfall 5). For Phase 3, record the pass-rate evidence: 4.0 CRC gate `0/952 = 0%`, wrapper 8-byte-overhead `5028/5028`, frame counts by characteristic (RESEARCH Findings 2-4).

---

### `FINDINGS_5.md` §Phase 3 (doc, EXTEND in place)

**Analog:** the file's own existing sections (`## 1. GATT Map` ... `## 6. Open Questions`, lines 28-150).

**Section pattern** (existing `## N. Title` + `### subsection` + evidence-cited prose): add a new `## 7. Framing (Phase 3)` (or `## Phase 3` per CONTEXT) section in the same style. MUST contain one of the two exact go/no-go verdicts (CONTEXT Specifics + ROADMAP criterion 4). RESEARCH directs the verdict to: **"wrapper characterised, decode work cleared with wrapper-strip step."** Mention the `WG50_r52` -> whoop-vault r52 enum-map reuse note (CONTEXT Specifics). Update the `## Status at a glance` block (lines 11-26) consistent with the existing per-phase status convention.

---

## Shared Patterns

### Script isolation (D-02)
**Source:** `re/survey_5/survey_gatt_5.py` line 25, `hr_5.py` line 14
**Apply to:** `validate_frames_5.py`
```python
from device_local_5 import DEVICE_UUID as ADDR   # only if D-01b Bleak fallback is needed
```
All survey_5 scripts run from inside `re/survey_5/` (`.venv/bin/python`) and import `device_local_5` locally. NO `sys.path.insert` into `whoomp/` (the 4.0 anti-pattern in `decode.py` lines 7-8). The D-01b fallback (fresh Bleak capture) is NOT needed — existing captures yield 5028 aa-frames (RESEARCH Env Availability).

### Output artifact convention
**Source:** `re/survey_5/survey_gatt_5.py` lines 33, 85-87
**Apply to:** `validate_frames_5.py` (writes `frames_5_golden.json`)
```python
OUT_PATH = Path(__file__).parent / "<name>.json"
with open(OUT_PATH, "w") as f:
    json.dump(result, f, indent=2)
```

### Evidence-redaction policy (D-02 / DISCLAIMER §2)
**Source:** `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml` lines 6, 54-58
**Apply to:** `2026-05-30-framing-5.meta.yaml` and any committed hex excerpt
- `device_identity: "[REDACTED]"`; raw `.pklg` listed under `raw_artifacts_local_only:` only.
- Commit: validator report + pass-rate sidecar + redacted hex excerpt. Never commit raw `.pklg`, BD_ADDR, or SMP keys. Confirm `samples/` gitignored via `git status` (Pitfall 5).

### CRC reference (don't hand-roll)
**Source:** `re/decode.py` line 39 (`zlib.crc32(pkt) & 0xFFFFFFFF`), `Framing.swift` lines 23-50
**Apply to:** `validate_frames_5.py`
Use stdlib `zlib.crc32` and `struct.unpack("<H"/"<L")` — matches `re/decode.py` and the 4.0 golden fixtures byte-for-byte. CRC8 poly-0x07 table: generate bitwise (RESEARCH Code Examples) and cross-check one value against `Framing.swift:crc8Table` (lines 4-29).

### Canonical-constants single source of truth (D-04b)
**Source:** `protocol/whoop_protocol.json` (4.0 layout)
**Apply to:** `protocol/whoop_protocol_5.json`
GATT UUIDs + firmware revision live in the JSON (Phase 5 Swift/Python import it), copied verbatim from the verified `2026-05-30-gatt-survey-5.meta.yaml`. Keep top-level keys compatible with the 4.0 `Schema.swift` loader.

---

## No Analog Found

None. Every new/modified file has a close in-repo analog. Two items carry research-driven adaptations rather than verbatim copies:

| File | Adaptation (vs. analog/CONTEXT) | Reason |
|------|-------------------------------|--------|
| `validate_frames_5.py` `strip_maverick()` | Returns FLAT body, NOT a nested `0xAA` frame | RESEARCH Finding 5 / Assumption A2 corrects CONTEXT D-03 wording |
| `validate_frames_5.py` length parse | `frame[2:4]`, total `length+8` (not 4.0 `frame[1:3]`, `+4`) | RESEARCH Finding 4 / Pitfall 1 — 5.0 inserts version byte at offset 1 |

---

## Metadata

**Analog search scope:** `re/` (decode.py, survey_5/, capture/evidence/), `protocol/`, `Packages/WhoopProtocol/` (Sources + Tests/Resources), repo-root `FINDINGS_5.md`.
**Files scanned:** 8 (decode.py, survey_gatt_5.py, hr_5.py, device_local_5.example.py, whoop_protocol.json, Framing.swift, frames.json, 2026-05-30-gatt-survey-5.meta.yaml) + FINDINGS_5.md header scan.
**Project skills:** none found (`.claude/skills/` and `.agents/skills/` absent).
**Pattern extraction date:** 2026-05-30
