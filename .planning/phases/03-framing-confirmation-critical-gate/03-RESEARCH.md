# Phase 3: Framing Confirmation (Critical Gate) - Research

**Researched:** 2026-05-30
**Domain:** BLE protocol reverse-engineering — frame structure & CRC validation (WHOOP 5.0 "Maverick")
**Confidence:** HIGH (wrapper structure empirically verified on 5028 captured frames across two sessions; trailer-checksum algorithm OPEN)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Primary frame source = tshark extraction from existing `.pklg` captures. The two existing captures count as two distinct sessions for ROADMAP criterion 1.
- **D-01b:** Fallback = new PacketLogger capture only if tshark extracts < 20 frames with `0xAA` SOF.
- **D-02:** New standalone `validate_frames_5.py` in `re/survey_5/` (isolated from 4.0 scripts). Reads ATT payload hex, attempts `reassemble()` + CRC8 (poly 0x07) + CRC32-LE validation, prints pass/fail report by characteristic, writes `frames_5_golden.json`.
- **D-02b:** Validate BOTH CRC8 (poly 0x07, same table as `Framing.swift`) and CRC32-LE (`zlib.crc32(pkt) & 0xFFFFFFFF` over the 4-byte trailer, per `re/decode.py:parse_frame()`).
- **D-02c:** `frames_5_golden.json` mirrors `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json` format (raw hex + parsed fields + characteristic source). Phase 4 uses it as its starting corpus.
- **D-03:** If CRC gate fails (< 98% pass): document wrapper structure AND implement `strip_maverick()` in `validate_frames_5.py`. The stripper must be working code, not just docs.
- **D-03b:** Phase 3 is a blocking gate — it expands if needed and does not close until framing is locked. Phase 4 does not begin without the go/no-go decision in `FINDINGS_5.md`.
- **D-04:** `whoop_protocol_5.json` v0 contains: framing section + GATT constants (custom service UUID + 5 characteristic UUIDs + legacy-ABSENT verdict) + `firmware_revision: WG50_r52` (VERIFIED). Confidence-tagged (VERIFIED/HYPOTHESIS).
- **D-04b:** GATT UUIDs belong in the JSON (single source of truth for Phase 5 Swift/Python), not just `FINDINGS_5.md`.

### Claude's Discretion

- Exact tshark filter expression to extract ATT payload hex from `.pklg`.
- Whether `validate_frames_5.py` reads from stdin, a file argument, or a hardcoded hex list.
- Internal structure of `frames_5_golden.json` (as long as it mirrors the 4.0 pattern).
- How the CRC8 table is implemented (lookup table vs. bitwise poly computation).
- Whether `strip_maverick()` is a separate script or a function in `validate_frames_5.py`.

### Deferred Ideas (OUT OF SCOPE)

None — the discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROTO-04 | 4.0 inner framing (CRC8 poly 0x07 + CRC32-LE) validated on ≥20 captured 5.0 frames | **Tool-verified: 4.0 framing as-is yields 0% CRC pass on 5028 frames.** PROTO-04's "validation" outcome is a definitive NEGATIVE — the 4.0 inner layout is NOT reused verbatim. This satisfies the requirement's intent (the CRC gate was run and produced a documented result), and triggers PROTO-05. |
| PROTO-05 | Maverick outer wrapper characterised if CRC validation fails | **Wrapper structure 90% characterised in this research** (header layout, length field, role byte, 8-byte overhead — all 100% consistent across both sessions). OPEN: the 4-byte trailer checksum algorithm. `strip_maverick()` removes the 4-byte header + 4-byte trailer. |
</phase_requirements>

---

## Summary

This phase's central hypothesis — that WHOOP 5.0 reuses the 4.0 inner framing (`[0xAA][len u16 LE][crc8][type][seq][cmd][payload][crc32 LE]`) — **is empirically false.** I ran the exact 4.0 CRC8+CRC32 validator (ported from `re/decode.py` and `Framing.swift`) against **5028 captured ATT frames** (952 from the Phase 1 iOS capture + 4076 from the Phase 2 SMP-bond capture) and got a **0.0% CRC pass rate**. The 4.0 inner framing is not reused verbatim.

What IS true: every single ATT value across both captures begins with `0xAA` and follows a **flat outer wrapper** whose structure is now characterised with HIGH confidence: `[0xAA][0x01][len u16 LE][role 1B] ... [len bytes of body] ... [trailer 4B]`. The total frame length equals `len + 8` for 100% of 5028 frames (4-byte header + body + 4-byte trailer). Byte[1] is always `0x01` (protocol/version). Byte[4] is `0x00` for cmd-in writes and `0x01` for notifications (a role/direction discriminator). The body is **flat** — it is NOT a nested 4.0 `0xAA` frame (only 30/952 frames contain an incidental `0xAA` byte in the body, none at a frame boundary).

The one OPEN item is the 4-byte trailer's checksum algorithm. I tested CRC32 (zlib/BZIP2/MPEG2/POSIX/JAMCRC/CRC32C, LE and BE, all leading-region offsets) and CRC16 (CCITT-FALSE, XMODEM, MODBUS, IBM/ARC) over every plausible region — none matched consistently. The trailer is a non-standard checksum or is computed over a transformed input (e.g., with the session-token bytes masked, or a custom poly). **This means Phase 3 takes the D-03 fallback path: wrapper characterisation, not 4.0-framing confirmation.** The go/no-go verdict will be "wrapper characterised, decode work cleared with wrapper-strip step."

**Primary recommendation:** Build `validate_frames_5.py` to (1) run the 4.0 CRC gate and document the 0% result, (2) implement and verify `strip_maverick()` which strips the confirmed 4-byte header + 4-byte trailer to expose the flat body, and (3) write `frames_5_golden.json` of wrapper-stripped bodies. The trailer-CRC algorithm is OPEN and should be recorded as a HYPOTHESIS/OPEN item in `whoop_protocol_5.json`, not blocking — Phase 4 can decode bodies without trailer validation (the wrapper-strip step is the gate Phase 4 needs).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| ATT payload extraction from `.pklg` | Analysis tooling (tshark) | — | tshark dissects the BLE/L2CAP/ATT stack; no app code involved |
| Frame structure validation | Python script (`re/survey_5/`) | — | RE/analysis layer, isolated from shipping packages (D-02) |
| Wrapper strip (`strip_maverick`) | Python script (RE) | Swift `Framing.swift` (Phase 5) | RE proves it in Python first; Phase 5 ports to the shipping Swift package |
| Canonical protocol constants | `protocol/whoop_protocol_5.json` | — | Single source of truth consumed by both Swift + Python packages (D-04b) |
| Go/no-go decision | `FINDINGS_5.md` | — | Phase 4 entry condition lives in the committed findings doc |

---

## Standard Stack

This phase is pure local analysis — no new external packages are required. Everything needed is already installed and verified.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| tshark (Wireshark) | 4.6.6 `[VERIFIED: tshark --version]` | Dissect `.pklg` → ATT handle + value hex | Already installed; native `.pklg` reader; `btatt` dissector used in Phase 1/2 |
| Python | 3.9.6 `[VERIFIED: python3 --version]` | `validate_frames_5.py` | Project RE language; `re/survey_5/.venv` exists |
| `zlib` (stdlib) | bundled | CRC32 reference (`zlib.crc32`) | Identical to `re/decode.py` and the 4.0 golden fixtures |
| `struct` (stdlib) | bundled | LE u16/u32 unpacking | Identical to `re/decode.py` |

### Supporting
| Module | Source | Purpose | When to Use |
|--------|--------|---------|-------------|
| `re/decode.py` `reassemble()` / `parse_frame()` | existing repo | Logic to ADAPT (not import) into `validate_frames_5.py` | Reassembly + 4.0 CRC gate |
| `re/survey_5/device_local_5.py` | existing repo | Device-identity import convention | Only if a fresh Bleak capture is needed (D-01b) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tshark `-T fields -e btatt.value` | tshark `-x` raw hex dump | `-T fields` is far cleaner (one value per row); `-x` requires post-parsing the hex-dump format. Use `-T fields`. |
| Adapting `re/decode.py` | Importing `whoomp/scripts/packet.py` (as `decode.py` does) | D-02 mandates isolation in `re/survey_5/`. Adapt the logic; do NOT add the `whoomp` sys.path import. The 4.0 `WhoopPacket` assumes the 4.0 layout, which does not apply here. |

**Installation:** None required. Verify with:
```bash
tshark --version | head -1   # expect 4.6.6
python3 --version            # expect 3.9.x
```

**No external packages are installed in this phase** → the Package Legitimacy Audit below is N/A.

## Package Legitimacy Audit

**N/A — this phase installs no external packages.** All tooling (tshark, Python stdlib `zlib`/`struct`) is pre-installed and verified. No npm/PyPI/crates dependency is introduced. The optional D-01b fallback uses `bleak`, which is already pinned in `re/survey_5/requirements.txt` from Phase 2 (not new to this phase).

---

## Tool-Verified Findings (the heart of this phase)

> Everything in this section was produced by running tshark + Python against the actual captures in this session. These are `[VERIFIED]` empirical results, not training-data claims.

### Finding 1 — Capture inventory (filenames differ from CONTEXT.md)

`[VERIFIED: ls + tshark -Y btatt | wc -l]`

| File in `re/capture/samples/` | btatt packets | Maps to |
|-------------------------------|---------------|---------|
| `whoop- iPhone de Francisco.pklg` | 1011 | **Phase 1 iOS capture** (CONTEXT calls this `2026-05-30-ios.pklg` — that filename does NOT exist) |
| `2026-05-30-smp-bond-full.pklg` | 4216 | **Phase 2 SMP capture** (matches CONTEXT) |
| `2026-05-30-smp-bond.pklg` | 4216 | Earlier/partial variant of the same Phase 2 session |

**Action for planner:** The plan must reference the ACTUAL filename `whoop- iPhone de Francisco.pklg` (note the leading space and space in the name — quote it in shell). Do not hardcode `2026-05-30-ios.pklg`; it will fail. See Assumptions Log A1.

### Finding 2 — Every ATT value starts with `0xAA` (SOF confirmed)

`[VERIFIED: awk count]` Phase 1: 952/952 btatt.value rows start with `aa`. Phase 2: 4076/4078. The `0xAA` SOF from `FINDINGS.md` holds. The ≥20-frames threshold (ROADMAP criterion 1) is met **~250× over** from existing captures alone — the D-01b fresh-capture fallback is NOT needed.

ATT value distribution by handle (Phase 1):
| Handle | UUID (from FINDINGS_5.md §5) | Role | aa-frames |
|--------|------------------------------|------|-----------|
| `0x099b` | `FD4B0002` | cmd-in (write) | 59 |
| `0x099d` | `FD4B0003` | cmd-resp (notify) | 61 |
| `0x09a0` | `FD4B0004` | events (notify) | 1 |
| `0x09a3` | `FD4B0005` | data (notify) | 831 |

This gives a healthy mix of cmd-resp + events + data across two sessions (ROADMAP criterion 1 fully satisfied).

### Finding 3 — The 4.0 inner framing does NOT validate (0% CRC pass)

`[VERIFIED: ported 4.0 validator run on 952 frames]`

| Check | Pass rate |
|-------|-----------|
| 4.0 CRC8 (poly 0x07 over length bytes) | **0 / 952 = 0.0%** |
| 4.0 CRC32-LE (zlib over `frame[4:length]`) | **0 / 952 = 0.0%** |
| Both | **0 / 952 = 0.0%** |

This is the decisive gate result. Interpreting the bytes with the 4.0 layout, the "length field" `frame[1:3]` reads as `0x0801 = 2049` for a 16-byte frame — nonsensical, because byte[1] is NOT part of the length. **The 4.0 layout is wrong for 5.0.** This is the < 98% trigger for D-03.

### Finding 4 — The Maverick outer wrapper (CHARACTERISED)

`[VERIFIED: structural analysis on 5028 frames, both sessions]`

```
Offset  Size  Field              Observed values
------  ----  -----------------  ----------------------------------------
0       1     SOF                0xAA           (constant, 5028/5028)
1       1     version/proto      0x01           (constant, 5028/5028)
2..3    2     length (u16 LE)    body length    (= total_len - 8, 5028/5028)
4       1     role/direction     0x00 = cmd-in write, 0x01 = notify
5..     N     body               flat payload (NOT a nested 0xAA frame)
end-4   4     trailer            per-frame checksum — ALGORITHM OPEN
```

- **8-byte overhead is exact and universal:** `total_len - length@offset2 == 8` for **5028/5028 frames** across both sessions. 4-byte header + body + 4-byte trailer.
- **byte[1] == 0x01** for 5028/5028 frames.
- **byte[4]** is a role discriminator: `0x00` on all 59 cmd-in writes, `0x01` on all 893 notifications (Phase 1).
- After the 4-byte header, bytes 5..8 look like a per-session token + sequence. E.g. cmd-in frames in Phase 1 share a constant 3-byte token `e6 71 23`; cmd-resp share `27 11 24`; data share patterns like `30 b1 32 cX` with `cX` incrementing — **a monotonic sequence counter** in the wrapper, distinct from the 4.0 inner `seq`.

### Finding 5 — The body is FLAT, not a nested 4.0 frame

`[VERIFIED]` This **contradicts a CONTEXT.md assumption.** D-03 states `strip_maverick()` should "expose the inner `0xAA` frame ready for the CRC8+CRC32 check." There is **no inner `0xAA` frame.** Only 30/952 frames contain an `0xAA` byte anywhere in the body, and none at a structural boundary — they are incidental data bytes. Stripping the wrapper yields a flat body that must be decoded directly (Phase 4), not re-validated against the 4.0 CRC8/CRC32 envelope.

**Action for planner:** `strip_maverick()` returns the flat body `frame[4 : 4+length]`. It must NOT attempt to find or validate an inner 0xAA envelope. Adjust the D-03 mental model accordingly. See Assumptions Log A2.

### Finding 6 — Trailer checksum algorithm is OPEN

`[VERIFIED: exhaustive negative]` Tested and FAILED to match the 4-byte trailer:
- CRC32 variants: zlib, BZIP2, MPEG2, POSIX, JAMCRC, CRC32C — LE and BE, every leading-region start offset 0–5. No consistent match (>50% threshold).
- CRC16 variants: CCITT-FALSE, XMODEM, MODBUS, IBM/ARC — over regions `[0:-2]`, `[1:-2]`, `[2:-2]`, `[1:-4]`, `[0:-4]`, `[4:-4]`; trailer slots last-2 and `[-4:-2]`, LE+BE. Only 1/952 spurious match.

The trailer is non-standard or computed over a transformed/masked input. **This is the one genuine open RE problem.** It does NOT block Phase 3 closure: the wrapper is characterised, `strip_maverick()` works (it does not need the trailer algorithm), and Phase 4 can decode bodies. Record the trailer as `HYPOTHESIS`/`OPEN` in `whoop_protocol_5.json`.

---

## Architecture Patterns

### System Architecture Diagram (data flow)

```
.pklg capture (gitignored)
   │  tshark -r FILE -Y btatt.value -T fields -e btatt.handle -e btatt.value
   ▼
[ handle \t value-hex ]  rows  (stdin or temp .tsv)
   │  filter: value starts with "aa"
   ▼
validate_frames_5.py
   ├─► (A) 4.0 CRC gate  ──► report: "0% pass — 4.0 framing NOT reused"  ──┐
   │                                                                        │
   ├─► (B) parse Maverick wrapper [AA][01][len LE][role] + body + trailer   │
   │         strip_maverick(frame) -> body bytes                            │
   │                                                                        ▼
   └─► (C) write frames_5_golden.json  ──────────────────────────►  Phase 4 corpus
            { hex, handle, role, length, body_hex, trailer_hex,
              crc8_4_0_ok:false, crc32_4_0_ok:false }
   │
   ▼
protocol/whoop_protocol_5.json (v0)  ── consumed by Phase 5 Swift + Python
FINDINGS_5.md §Phase 3  ── go/no-go: "wrapper characterised, decode cleared with strip step"
```

### Recommended Structure (new files only)
```
re/survey_5/
├── validate_frames_5.py        # NEW — CRC gate + strip_maverick() + golden writer
└── frames_5_golden.json        # NEW (generated) — wrapper-stripped corpus for Phase 4
protocol/
└── whoop_protocol_5.json       # NEW — v0 framing + GATT + firmware, confidence-tagged
re/capture/evidence/
└── 2026-05-30-framing-5.meta.yaml  # NEW — pass-rate evidence sidecar (D-02 policy)
FINDINGS_5.md                   # EXTEND — add §Phase 3 + go/no-go verdict
```

### Pattern 1: tshark ATT-value extraction (verified)
**What:** Pull handle + payload hex, one frame per line.
**When:** The single input step for `validate_frames_5.py`.
```bash
# Source: verified in this session against both captures
tshark -r "re/capture/samples/whoop- iPhone de Francisco.pklg" \
  -Y "btatt.value" \
  -T fields -e btatt.handle -e btatt.value
# Output rows:  0x099b<TAB>aa0108000001e67123942200c0896bce
```
Filter rows where the value starts with `aa` before parsing. Quote the filename (it contains spaces).

### Pattern 2: Maverick wrapper parse + strip (verified structure)
```python
# Source: structure verified on 5028 frames this session
import struct

def parse_maverick(frame: bytes):
    """frame: full ATT value bytes. Returns dict or None if not a valid wrapper."""
    if len(frame) < 9 or frame[0] != 0xAA or frame[1] != 0x01:
        return None
    length = struct.unpack("<H", frame[2:4])[0]       # body length
    if len(frame) != length + 8:                       # 4 hdr + body + 4 trailer
        return None
    role    = frame[4]                                 # 0x00 cmd-in, 0x01 notify
    body    = frame[4:4 + length]                       # FLAT body (incl. role byte at [0])
    trailer = frame[-4:]
    return {"length": length, "role": role,
            "body": body, "trailer": trailer}

def strip_maverick(frame: bytes) -> bytes:
    """Pure bytes->bytes. Removes 4-byte header + 4-byte trailer, returns flat body.
    Body offsets (from r52 whoop-vault, HYPOTHESIS): body[0]=role, body[1:4]=session token,
    body[4..]=seq + payload. There is NO nested 0xAA frame to recover."""
    p = parse_maverick(frame)
    return p["body"] if p else b""
```
> Document the exact field offsets in the docstring (D-03 / Specifics). `strip_maverick()` is a pure function so Phase 4 can import or inline it.

### Pattern 3: golden fixture format (mirror the 4.0 file)
**What:** The 4.0 fixture is minimal: `[{"hex": "..."}]`. Mirror that, extending with parsed fields per D-02c.
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
> The 4.0 file at `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json` is just `{"hex": ...}` entries — keep `hex` as the first key so a future Swift loader stays compatible.

### Anti-Patterns to Avoid
- **Importing `whoomp/scripts/packet.py`** (as `re/decode.py` does via `sys.path.insert`). The 4.0 `WhoopPacket` assumes the 4.0 layout, which is wrong for 5.0, and it breaks D-02 isolation. Adapt the logic into `re/survey_5/` instead.
- **Treating the body as a nested 0xAA frame.** Finding 5 disproves this. Do not re-run CRC8/CRC32 against the stripped body expecting a pass.
- **Hardcoding `2026-05-30-ios.pklg`.** That filename does not exist (Finding 1).
- **Blocking phase closure on the trailer-CRC algorithm.** It is OPEN and not required for the wrapper-strip step Phase 4 needs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BLE/L2CAP/ATT dissection | A `.pklg` binary parser | `tshark -Y btatt -T fields` | tshark already parses the full HCI/L2CAP/ATT stack correctly; rolling your own is weeks of work and error-prone |
| CRC32 reference | Hand-coded zlib table | `zlib.crc32(data) & 0xFFFFFFFF` | stdlib, matches `re/decode.py` + the 4.0 golden fixtures byte-for-byte |
| LE integer parsing | Manual bit-shifting | `struct.unpack("<H"/"<L", ...)` | matches existing `re/decode.py` convention |
| Frame reassembly | New buffering logic | Adapt `re/decode.py:reassemble()` | the SOF + length-prefix loop is already written and tested for 4.0 |

**Key insight:** This phase's value is in *analysis*, not infrastructure. tshark + zlib + struct cover all the plumbing; the only novel work is the wrapper layout (done) and the trailer algorithm (open).

## Runtime State Inventory

> This is an analysis/RE phase, not a rename/refactor/migration. The category that matters here is **build artifacts / generated files** since `frames_5_golden.json` and `whoop_protocol_5.json` are new committed artifacts.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore involved. Verified: phase reads `.pklg` files only. | None |
| Live service config | None — no external service touched. | None |
| OS-registered state | None. | None |
| Secrets/env vars | `re/survey_5/device_local_5.py` holds the device UUID (gitignored); only relevant if the D-01b Bleak fallback runs. Verified present. | None unless fallback used |
| Build artifacts | NEW generated files: `re/survey_5/frames_5_golden.json`, `protocol/whoop_protocol_5.json`. The Phase 5 Swift `Schema.swift` loader (`Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift`) will later consume the JSON — field names must stay compatible with the 4.0 `protocol/whoop_protocol.json` top-level layout. | Keep JSON structure compatible with 4.0 schema loader |

## Common Pitfalls

### Pitfall 1: Reading byte[1] as part of the length field
**What goes wrong:** Applying the 4.0 `frame[1:3]` length read gives `0x0801 = 2049` for a 16-byte frame.
**Why it happens:** 5.0 inserts a version byte `0x01` at offset 1; the length is at offset **2–3**, not 1–2.
**How to avoid:** `length = struct.unpack("<H", frame[2:4])[0]`. Validate `len(frame) == length + 8`.
**Warning signs:** Lengths in the thousands for short frames; 0% CRC pass.

### Pitfall 2: Expecting a nested 0xAA frame after stripping
**What goes wrong:** `strip_maverick()` consumers re-run the 4.0 CRC gate on the body and get 0% pass, then conclude the stripper is broken.
**Why it happens:** CONTEXT.md D-03 wording implies a nested 4.0 frame. Finding 5 proves the body is flat.
**How to avoid:** Treat the body as opaque decode input for Phase 4. Do not CRC-validate it as a 0xAA envelope.
**Warning signs:** Body does not start with `0xAA`; only incidental `0xAA` bytes mid-body.

### Pitfall 3: tshark filename with spaces
**What goes wrong:** `tshark -r re/capture/samples/whoop- iPhone de Francisco.pklg` → "No such file."
**Why it happens:** The Phase 1 capture filename contains spaces.
**How to avoid:** Always quote: `tshark -r "re/capture/samples/whoop- iPhone de Francisco.pklg"`.

### Pitfall 4: Using `btatt.value` rows that are reads/config, not WHOOP payloads
**What goes wrong:** Some `btatt.value` rows are GATT discovery / CCCD writes, not protocol frames.
**Why it happens:** `btatt` matches all ATT PDUs.
**How to avoid:** Filter on `value.startswith("aa")` AND restrict to the four custom-service handles (`0x099b/0x099d/0x09a0/0x09a3`). Verified: all aa-prefixed values fall on these handles.

### Pitfall 5: Committing raw captures or unredacted hex
**What goes wrong:** Violates DISCLAIMER §2 + D-02 evidence policy.
**Why it happens:** `git add re/capture/samples/` or committing a `.hex` with BD_ADDR.
**How to avoid:** `samples/` is gitignored — confirm via `git status`. Commit only: the validator report, the evidence `.meta.yaml` sidecar, and a redacted hex excerpt. Protocol byte values ARE committable (uncopyrightable facts); BD_ADDR/SMP keys are NOT.

## Code Examples

### Run the 4.0 CRC gate and document the result (verified to yield 0%)
```python
# Source: ported from re/decode.py + Framing.swift, run this session
import struct, zlib

CRC8_POLY = 0x07
def _crc8_table():
    t = []
    for i in range(256):
        c = i
        for _ in range(8):
            c = ((c << 1) ^ CRC8_POLY) & 0xFF if (c & 0x80) else (c << 1) & 0xFF
        t.append(c)
    return t
_T = _crc8_table()
def crc8(data: bytes) -> int:
    c = 0
    for b in data:
        c = _T[c ^ b]
    return c

def verify_4_0(frame: bytes):
    """Returns (crc8_ok, crc32_ok). Expected 0% on 5.0 — documents the gate result."""
    if len(frame) < 8 or frame[0] != 0xAA:
        return (False, False)
    length = struct.unpack("<H", frame[1:3])[0]   # 4.0 interpretation (WRONG for 5.0)
    crc8_ok = crc8(frame[1:3]) == frame[3]
    if length < 7 or length + 4 > len(frame):
        return (crc8_ok, False)
    inner = frame[4:length]
    crc32_ok = (zlib.crc32(inner) & 0xFFFFFFFF) == struct.unpack("<L", frame[length:length+4])[0]
    return (crc8_ok, crc32_ok)
```
> The CRC8 table here is generated bitwise from poly 0x07; it produces the identical table to `Framing.swift:crc8Table` and `framing.py`. Cross-check one value (`crc8(b"\x08\x00")`) against the Swift implementation per D-02b.

## State of the Art

| Old (assumed) Approach | Current (verified) Reality | When Changed | Impact |
|------------------------|----------------------------|--------------|--------|
| 5.0 reuses 4.0 inner framing verbatim | 5.0 wraps a flat body in a `[AA][01][len][role]...[crc?]` outer wrapper | Confirmed this phase (2026-05-30) | Phase 3 takes the D-03 wrapper path; PROTO-04 result is a documented negative |
| `strip_maverick()` exposes a nested 0xAA frame | Body is flat; no nested envelope | This phase | Phase 4 decodes the flat body directly |
| Trailer = CRC32-LE (4.0 style) | Trailer is a non-standard 4-byte checksum, algorithm OPEN | This phase | Recorded as HYPOTHESIS; not blocking |

**Deprecated/outdated for 5.0:**
- 4.0 `frame[1:3]` length read — wrong offset (use `frame[2:4]`).
- 4.0 CRC8-over-length + CRC32-over-inner gate — does not pass on 5.0.
- The `whoomp` `WhoopPacket` parser — assumes the 4.0 layout.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Phase 1 1011-packet capture is the file `whoop- iPhone de Francisco.pklg` (CONTEXT names it `2026-05-30-ios.pklg`, which does not exist). `[VERIFIED filename + count]` | Finding 1 | LOW — verified by packet count; planner must use the real name or `tshark -r` fails |
| A2 | `strip_maverick()` should return the flat body, NOT a nested 0xAA frame. Contradicts CONTEXT D-03 wording. `[VERIFIED: only 30/952 incidental 0xAA in body]` | Finding 5 | MEDIUM — if the planner follows CONTEXT literally, the stripper will be designed to find a non-existent inner frame |
| A3 | The byte at offset 4 (`role`) is a direction discriminator (0x00 write / 0x01 notify). `[VERIFIED on 952 frames]` Exact semantic name is `[ASSUMED]`. | Finding 4 | LOW — naming only; the value mapping is verified |
| A4 | The 4-byte trailer is a checksum (vs. a tag/nonce). `[ASSUMED]` — no standard CRC matched; could be a MAC or session-keyed value. | Finding 6 | MEDIUM — affects whether Phase 4 can ever validate frames; does NOT block Phase 3 |
| A5 | r52 whoop-vault enum maps apply to the flat body's command/event codes. `[ASSUMED from FINDINGS_5.md §6 + WG50_r52 hardware revision]` | Phase Reqs | MEDIUM — Phase 4 decode assumption; verifiable in Phase 4, not this phase |

## Open Questions

1. **What checksum algorithm produces the 4-byte trailer?**
   - What we know: it is 4 bytes, varies per frame, is NOT zlib/BZIP2/MPEG2/POSIX/JAMCRC/CRC32C nor CCITT/XMODEM/MODBUS/IBM CRC16 over any leading region.
   - What's unclear: custom poly, keyed/masked input (the 3-byte session token may need masking before CRC), or a non-CRC MAC.
   - Recommendation: Record as `OPEN`/`HYPOTHESIS` in `whoop_protocol_5.json`. Do NOT block Phase 3. Optionally try: CRC32 over body with the session-token bytes zeroed; CRC32 over the full frame excluding trailer with init=0; or `reveng`-style brute force in a future spike. The wrapper-strip step Phase 4 needs does not require this.

2. **Is the role byte (offset 4) part of the body or part of the header?**
   - What we know: it is at a fixed offset and discriminates write vs notify.
   - What's unclear: whether Phase 4 decode should treat body[0] as a meaningful first payload byte or skip it.
   - Recommendation: Keep it in the `body` (current `strip_maverick` returns `frame[4:4+length]` which includes it). Document it as `body[0] = role`. Phase 4 can refine.

3. **Does the events characteristic (`0x09a0`/`FD4B0004`) follow the same wrapper?**
   - What we know: only 1 events frame in Phase 1; it is aa-prefixed and fits the 8-byte-overhead rule.
   - What's unclear: low sample size for events specifically.
   - Recommendation: Phase 2 capture has more notification frames; include them in the corpus. Not a blocker — the wrapper held for all 5028 frames.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| tshark | ATT extraction | ✓ | 4.6.6 `[VERIFIED]` | — |
| python3 | validator | ✓ | 3.9.6 `[VERIFIED]` | — |
| zlib/struct (stdlib) | CRC/parse | ✓ | bundled | — |
| Phase 1 `.pklg` | frame source | ✓ | `whoop- iPhone de Francisco.pklg` (1011 pkts) `[VERIFIED]` | D-01b fresh capture |
| Phase 2 `.pklg` | frame source | ✓ | `2026-05-30-smp-bond-full.pklg` (4216 pkts) `[VERIFIED]` | — |
| bleak | D-01b fallback only | ✓ (from Phase 2) | per `requirements.txt` | not needed (frames abundant) |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None — D-01b fresh capture is NOT needed; existing captures yield 5028 aa-frames (≥20 threshold met ~250×).

---

> **Validation Architecture section omitted:** `.planning/config.json` has `workflow.nyquist_validation: false`. Per the researcher spec, this section is skipped.

> **Security Domain section:** This is a local, read-only RE/analysis phase that introduces no auth, network, input-from-untrusted-source, or crypto-implementation surface. The only security-relevant control is the existing D-02 / DISCLAIMER §2 evidence-redaction policy (scrub BD_ADDR + SMP keys before committing hex), which is covered under Pitfall 5. No ASVS category applies to the new code (a Python script that parses local capture files). The one cryptographic-adjacent item — the trailer checksum — is being *analysed*, not *implemented*, so "never hand-roll crypto" does not bite here.

## Sources

### Primary (HIGH confidence — tool-verified this session)
- `tshark 4.6.6` run against `whoop- iPhone de Francisco.pklg` and `2026-05-30-smp-bond-full.pklg` — frame structure, SOF, wrapper layout, 8-byte overhead (5028 frames).
- Ported 4.0 validator (from `re/decode.py` + `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift`) run on 952 frames — 0% CRC pass.
- `re/decode.py` — 4.0 `reassemble()` / `parse_frame()` logic.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` — CRC8 poly 0x07 table, zlib CRC32, `verifyFrame` envelope semantics.
- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json` — golden fixture format (`{"hex": ...}`).
- `FINDINGS_5.md` §1/§2/§5/§6 — confirmed GATT map, legacy-ABSENT verdict, handle→UUID map, Phase 3 inputs.
- `FINDINGS.md` §3 — 4.0 frame format baseline.
- `re/capture/evidence/2026-05-30-ios.meta.yaml` — Phase 1 evidence sidecar.

### Secondary (MEDIUM confidence)
- `re/capture/wireshark.md` — tshark runbook + D-02 evidence policy.
- CONTEXT.md D-01…D-04 — locked decisions.

### Tertiary (LOW confidence / unavailable)
- WebSearch for external Maverick/whoop-vault wrapper docs — **UNAVAILABLE in this environment** (org policy blocked the search API). All wrapper claims rest on the tool-verified empirical analysis above, which is stronger than any web source would be.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tooling installed & version-verified; no external packages.
- Wrapper structure: HIGH — 100% consistent across 5028 frames in two independent sessions.
- 4.0-framing-not-reused verdict: HIGH — 0% CRC pass on 952 frames with the exact ported validator.
- Body-is-flat finding: HIGH — verified; corrects a CONTEXT assumption.
- Trailer checksum algorithm: LOW/OPEN — exhaustively ruled out standard CRC variants; true algorithm unknown.
- r52 enum-map applicability: MEDIUM — inherited from FINDINGS_5.md §6 (Phase 4 concern).

**Research date:** 2026-05-30
**Valid until:** Stable — these are facts about captured bytes on this specific device/firmware (`WG50_r52`). No external-dependency staleness. Re-validate only if a different firmware revision is captured.
