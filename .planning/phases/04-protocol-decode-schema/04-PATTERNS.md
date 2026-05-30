# Phase 4: Protocol Decode & Schema - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 7 (5 new, 2 modified/expanded)
**Analogs found:** 7 / 7 (all have strong codebase analogs — this is a confirm-and-complete phase, not a green-field one)

> Domain note: this is a Python BLE reverse-engineering / schema-authoring phase, not a web/CRUD app.
> "Role" and "data flow" are mapped to the RE domain: decoder library, fixture corpus, schema config,
> sync script, evidence sidecar, findings doc. All analogs are real files in this repo. No source is
> modified by this agent — PATTERNS.md is the only output.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `re/survey_5/decode_5.py` | decoder library (utility) | transform (bytes → dict) | `re/decode.py` (`parse_frame`) + `re/survey_5/validate_frames_5.py` (`strip_maverick`, `extract_frames`) | exact (role+flow) |
| `re/survey_5/frames_5_golden.json` (expand 46 → curated subset of 5028) | golden fixture (test corpus) | file-I/O (JSON) | existing `re/survey_5/frames_5_golden.json` schema + `validate_frames_5.py:build_report/main` writer | exact (same file, established writer) |
| `protocol/whoop_protocol_5.json` (complete enums+packets) | schema (config) | file-I/O (JSON) | `protocol/whoop_protocol.json` (4.0 complete: enums/envelope/packets) | exact (sibling schema) |
| `scripts/sync-schema-5.sh` | build script (config sync) | file-I/O (cp + validate) | `scripts/sync-schema.sh` (4.0) | exact (mirror) |
| `re/capture/evidence/*.meta.yaml` (D-05 capture sidecar + per-fixture sidecars) | evidence sidecar (test fixture metadata) | file-I/O (YAML) | `re/capture/evidence/2026-05-30-framing-5.meta.yaml` | exact (same dir, same policy) |
| `FINDINGS_5.md` (extend §Phase 4) | findings doc (documentation) | n/a | `FINDINGS_5.md` §7 (Phase 3 pattern) + `FINDINGS.md` §5 (4.0 per-stream subsections) | exact (same doc + 4.0 template) |
| corpus extractor (inline in `decode_5.py` or `validate_frames_5.extract_frames`) | extraction utility | transform (pklg → frames) | `re/survey_5/validate_frames_5.py:extract_frames()` (tshark subprocess) | exact (reuse, raise the cap) |

## Pattern Assignments

### `re/survey_5/decode_5.py` (decoder library, bytes→dict transform)

**Analogs:** `re/decode.py` (adapt `parse_frame`), `re/survey_5/validate_frames_5.py` (import `strip_maverick`, reuse `extract_frames`), `re/standard_ble.py` (reuse `parse_hr`).

**CRITICAL correction (RESEARCH §Summary, Pitfall 1):** the 4.0 `[type][seq][cmd]` triple lives at **body offset 4**, NOT offset 1 as the literal D-01 wording says. `body[0]`=role, `body[1:4]`=session token, `body[4]`=packet_type, `body[5]`=seq, `body[6]`=cmd, `body[7:]`=payload. There is **no inner CRC32** on the body. Do not carry over `parse_frame`'s `crc_ok` check.

**Import / isolation pattern** — follow `validate_frames_5.py` lines 12-16, 20-25 (stdlib + local import, NO 4.0 `WhoopPacket` sys.path hack):
```python
# DO (D-02): local import, stdlib only
import json
import struct
from pathlib import Path
from validate_frames_5 import strip_maverick   # Phase 3 entry point, import directly

# DO NOT (forbidden by D-02 — this is re/decode.py lines 7-8, wrong framing for 5.0):
#   sys.path.insert(0, "whoomp/scripts"); from packet import WhoopPacket, PacketType
```

**Core parser — adapt `re/decode.py:parse_frame` (lines 36-40) shifting offsets 1/2/3 → 4/5/6 and dropping CRC:**
```python
# 4.0 ORIGINAL (re/decode.py lines 36-40) — offsets 1,2,3 + CRC32 gate:
#   def parse_frame(frame):
#       length = struct.unpack("<H", frame[1:3])[0]
#       pkt = frame[4:length]
#       crc_ok = zlib.crc32(pkt) & 0xFFFFFFFF == struct.unpack("<L", frame[length:length+4])[0]
#       return pkt[0], pkt[1], pkt[2], pkt[3:], crc_ok   # type, seq, cmd, data, crc_ok

# 5.0 ADAPTED (RESEARCH Pattern 1, verified 46/46 golden frames) — offset 4, NO inner CRC:
def parse_body_5(body: bytes) -> dict:
    if len(body) < 7:                  # V5 length guard (ASVS V5 / D-03) — never index past end
        return {"error": "short", "body_hex": body.hex()}
    role  = body[0]                    # 0x00 cmd-in write / 0x01 notify
    token = body[1:4]                  # 3-byte per-session token (HYPOTHESIS, A5)
    ptype = body[4]                    # r52 PacketType: 36 CMD_RESP, 48 EVENT, 49 META, 50 LOGS, 40 RT, 43 RAW
    seq   = body[5]                    # monotonic sequence
    cmd   = body[6]                    # r52 CommandNumber / EventNumber / MetadataType (context = ptype)
    payload = body[7:]
    return {"role": role, "token": token.hex(), "type": ptype,
            "seq": seq, "cmd": cmd, "payload": payload.hex()}
```

**Dispatch-by-type + per-type counting** — copy the `bytype` aggregation idiom from `re/decode.py` lines 49-63 (groups frames by `PacketType(t).name`, counts per type, shows an exemplar head). Reuse this shape for the command-surface enumeration (PROTO-06) and per-stream classification (`stream_type` tag).

**Length-guard error handling (D-03, ASVS V5)** — frames too short or with an unrecognised ptype are logged-and-continued, never crash. Mirror the guard style already in `strip_maverick` (`validate_frames_5.py` lines 97-98, 121-122: parse returns `None`/`b""` on malformed input) and `parse_hr` (`standard_ble.py` lines 22-28: `idx + 2 > len(data): break`).

**HR/RR ground-truth (PROTO-07, D-08)** — reuse `re/standard_ble.py:parse_hr()` (lines 11-29) **verbatim** for the standard 0x2A37 path. Custom REALTIME_DATA (type 40) decode adapts the 4.0 schema field map in `protocol/whoop_protocol.json` `packets.REALTIME_DATA` (offsets 6/10/12/13: timestamp/subseconds/heart_rate/rr_count) — but at the **5.0 payload offset** (body[7:] base, not frame[6]).

---

### `re/survey_5/frames_5_golden.json` (golden fixture, expand 46 → curated)

**Analog:** the existing file's own record schema + its writer in `validate_frames_5.py:build_report()` (lines 221-235) and `main()` (lines 271-287).

**Record shape to preserve** (existing `frames_5_golden.json[0]`):
```json
{
  "hex": "aa0108000001e67123942200c0896bce",
  "type": null, "seq": null, "cmd": null, "payload": null,
  "characteristic": "FD4B0002", "handle": "0x099b",
  "role": 0, "length": 8,
  "body_hex": "0001e67123942200",
  "trailer_hex": "c0896bce",
  "crc8_4_0_ok": false, "crc32_4_0_ok": false
}
```

**Phase 4 expansion (Claude's Discretion in CONTEXT):** populate the now-`null` `type`/`seq`/`cmd`/`payload` from `parse_body_5`, and ADD a `"stream_type"` field (the PacketType name, e.g. `"COMMAND_RESPONSE"`, `"EVENT"`, `"CONSOLE_LOGS"`). Keep it CURATED — do NOT commit all 5028 (Pitfall 4). The existing per-handle cap mechanism is the pattern:
```python
# validate_frames_5.py lines 167, 271-282 — raise/replace the cap for full-corpus extraction,
# then re-curate by keeping >=1 exemplar per (PacketType, cmd) pair instead of a flat per-handle cap:
GOLDEN_PER_HANDLE_CAP = 15        # 4.0-style flat cap → Phase 4: switch to per-(type,cmd) exemplar cap
per_handle = {}
golden = []
for rec in records:
    h = rec["handle"]
    if per_handle.get(h, 0) >= GOLDEN_PER_HANDLE_CAP:
        continue
    per_handle[h] = per_handle.get(h, 0) + 1
    golden.append(rec)
json.dump(golden, f, indent=2)
```

**Full-corpus extraction (D-04):** `extract_frames()` already runs the exact tshark command. To get all 5028 instead of the curated 46, consume `build_report().records` (all wrapper-ok frames) rather than the capped `golden` list — see RESEARCH Code Examples "Full-corpus extraction".

---

### `protocol/whoop_protocol_5.json` (schema, complete enums+packets)

**Analog:** `protocol/whoop_protocol.json` (4.0) top-level layout + field shape. The 5.0 v0 already mirrors `version/enums/envelope/packets` and adds `gatt`/`firmware_revision`.

**Enums — copy r52 maps VERBATIM from 4.0** (`whoop_protocol.json` lines 2-43: `PacketType`, `MetadataType`, `EventNumber`, `CommandNumber`). WG50_r52 is confirmed identical (RESEARCH "Don't Hand-Roll"). Paste these four enum objects into the currently-empty `"enums": {}` of the 5.0 schema.

**Packet field-map shape — follow 4.0 `packets.REALTIME_DATA`** (`whoop_protocol.json` lines ~46-58):
```json
"REALTIME_DATA": {
  "type": 40, "post": "realtime_data",
  "fields": [
    {"off": 6, "len": 4, "dtype": "u32", "name": "timestamp", "cat": "time"},
    {"off": 10, "len": 2, "dtype": "u16", "name": "subseconds", "cat": "time"},
    {"off": 12, "len": 1, "dtype": "u8", "name": "heart_rate", "cat": "hr", "note": "bpm"},
    {"off": 13, "len": 1, "dtype": "u8", "name": "rr_count", "cat": "rr"}
  ]
}
```
**5.0 difference (SCHEMA-02):** add `"epoch"` (`"unix"` vs `"device"`), `"note"` (provenance), and `"confidence"` (`VERIFIED`/`HYPOTHESIS`) to EVERY field — see the confidence-tagging already used in the 5.0 v0 `envelope` entries (each has `confidence` + `note`). Offsets are body-relative; for body decode the field `off` should be expressed against the body (4.0 used frame-relative offset 6 = body[7] after the 5.0 role+token+type+seq+cmd prefix — reconcile the offset base explicitly in a `schema_note`).

**Confidence-tag policy (D-07):** unobserved-but-r52-expected commands → `"confidence": "HYPOTHESIS"`, `"note": "not observed in captures, expected from r52 enum map"`. Observed-and-decoded → `VERIFIED`. SpO₂/temp/respiration stay HYPOTHESIS unless the D-05 capture proves the bytes (Pitfall 5, A1-A3).

**Loader compatibility (canonical_ref):** must stay loadable by `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` — keep the 4.0 field key names (`off`/`len`/`dtype`/`name`/`cat`/`enum`).

---

### `scripts/sync-schema-5.sh` (build script, cp + validate)

**Analog:** `scripts/sync-schema.sh` (4.0) — mirror it exactly, retargeting paths to the `_5` variant.

**Pattern to copy** (`scripts/sync-schema.sh` lines 1-11):
```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANON="$ROOT/protocol/whoop_protocol_5.json"
PKG="$ROOT/Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json"
mkdir -p "$(dirname "$PKG")"
cp "$CANON" "$PKG"
echo "synced → $PKG"
```

**Add JSON validation before cp** (RESEARCH Code Examples / SCHEMA-05) — the 4.0 script does not validate; the 5.0 script should, since it is authored fresh this phase:
```bash
python3 -c "import json,sys; json.load(open('$CANON'))" || { echo "invalid JSON"; exit 1; }
```

**Note on the home-server branch:** the 4.0 script also syncs to `$HOME_SERVER_REPO` (lines 7, 12-17). For 5.0, decide whether the home-server consumer exists yet — if not, omit that branch (Phase 5 can add it). The `mkdir -p "$(dirname "$PKG")"` is load-bearing: per RESEARCH Runtime State Inventory, the 5.0 Resources file does not yet exist.

---

### `re/capture/evidence/*.meta.yaml` (evidence sidecar, YAML)

**Analog:** `re/capture/evidence/2026-05-30-framing-5.meta.yaml` (Phase 3) — the established sidecar shape and redaction policy.

**Structure to copy** (top keys: `source`, `tool`, `tool_version`, `captured`, `device_identity: "[REDACTED]"`, `results:`, `verdict`, `raw_artifacts_local_only:`, `notes:`). For the D-05 capture sidecar:
- `device_identity: "[REDACTED]"` (BD_ADDR / serial / CoreBluetooth UUID live only in gitignored pklg + `device_local_5.py`).
- ADD `firmware_revision: "WG50_r52"` (PROTO-16 — read Device Info `0x2A26`/`0x2A27`; the framing-5 sidecar already names the 0x2A27 source).
- `raw_artifacts_local_only:` lists the new `.pklg` under `re/capture/samples/` (gitignored).
- `notes:` must restate DISCLAIMER §2: only protocol-structure facts committed, no key material.

**Per-fixture cross-source sidecars (SCHEMA-04, D):** redacted hex + SHA256 + YAML. The SHA256 sidecar pattern is the sibling `.sha256` files (`2026-05-30-ios.sha256`, `2026-05-30-smp-bond.sha256`) and the `.hex` redacted-hex files in the same dir.

---

### `FINDINGS_5.md` (findings doc, extend §Phase 4)

**Analogs:** `FINDINGS_5.md §7` (Phase 3 section shape: subsection per finding + "Committed artifacts" + verdict) and `FINDINGS.md §5` (4.0 "Decoded data streams" — the per-stream-subsection template to mirror).

**4.0 per-stream subsection template to follow** (`FINDINGS.md` §5 headers, lines 80-101):
```
## 5. Decoded data streams
### Heart rate (realtime, REALTIME_DATA type 40, 24-byte packet)
### R-R intervals
### Historical offload (the device-side store-and-forward)
### Events (type 48, char 04) — all decode via whoomp's EventNumber
```

**Phase 4 §extension (Claude's Discretion, mirror §Phase 3 / §5):** subsections for command surface (PROTO-06, observed-vs-r52), decoded streams (HR/RR, events incl. battery, IMU, SpO₂/temp HYPOTHESIS), dual-epoch timestamps (PROTO-15), historical offload protocol (PROTO-10, documentation-only). End with a "Committed artifacts" list and confidence-per-stream table, matching the §7 style (`FINDINGS_5.md` lines 195-206).

## Shared Patterns

### Length-guard / log-and-continue (D-03, ASVS V5)
**Source:** `re/survey_5/validate_frames_5.py` lines 97-98, 121-122 (parse returns `None`/`b""` on malformed input); `re/standard_ble.py` lines 22-28 (`if idx + 2 > len(data): break`).
**Apply to:** every offset access in `decode_5.py`. Guard `len(body)` before indexing body[4]/[5]/[6]/[7+]. Never crash on truncated/fragmented BLE frames — log hex + characteristic, continue.
```python
if len(body) < 7:
    return {"error": "short", "body_hex": body.hex()}   # D-03 log-and-continue
```

### Isolation in `re/survey_5/` + no-4.0-import (D-02)
**Source:** `re/survey_5/validate_frames_5.py` lines 12-25 (standalone, stdlib + local import only).
**Apply to:** `decode_5.py` and any new Phase 4 analysis script. Import `strip_maverick` from `validate_frames_5`; do NOT do the `sys.path.insert(...); from packet import WhoopPacket` hack that `re/decode.py` lines 7-8 use.

### tshark extraction pipeline
**Source:** `re/survey_5/validate_frames_5.py:extract_frames()` lines 170-198 (subprocess tshark, `-Y btatt.value -T fields -e btatt.handle -e btatt.value`, filter `aa`-prefix + 4 custom handles in `HANDLE_UUID` lines 153-158).
**Apply to:** full-corpus extraction (D-04) and any new-capture extraction (D-05). Reuse the function; the filenames are hardcoded in `DEFAULT_CAPTURES` (lines 147-150) including the Phase 1 file with a literal space in its name.

### Confidence + provenance tagging (SCHEMA-02)
**Source:** `protocol/whoop_protocol_5.json` v0 `envelope` entries (each carries `"confidence"` + `"note"`); `protocol/whoop_protocol.json` field shape.
**Apply to:** every field in `whoop_protocol_5.json` packets/enums AND every stream verdict in `FINDINGS_5.md §Phase 4`. VERIFIED only when ground-truth-matched (HR strap / app display, D-08); else HYPOTHESIS with honest provenance.

### Evidence / redaction policy (DISCLAIMER §2)
**Source:** `re/capture/evidence/2026-05-30-framing-5.meta.yaml` `notes:` block + `device_identity: "[REDACTED]"`.
**Apply to:** all Phase 4 committed artifacts (golden JSON, sidecars, FINDINGS). Raw `.pklg` gitignored; committed = redacted hex + SHA256 + YAML; scrub BD_ADDR/serial/SMP keys.

## No Analog Found

None. Every Phase 4 file has a strong in-repo analog. The only items without a *codebase* precedent are the biometric stream field-layouts themselves (SpO₂ type-53, skin-temp event-17, IMU type-43 for 5.0), and those are intentionally capture-gated (D-05) and must follow RESEARCH `Code Examples` + 4.0 `FINDINGS.md §6` layout — NOT fabricated (Pitfall 5).

| Item (not a file) | Why no analog | Planner guidance |
|------|---------------|------------------|
| 5.0 SpO₂ / skin-temp / respiration field offsets | not observed in existing corpus; 4.0 precedent = cloud-computed (off-wire) | HYPOTHESIS only until D-05 capture proves bytes; use RESEARCH A1-A3 |
| 5.0 IMU (type 43) stride/scale | 4.0 layout known (`FINDINGS.md §6`), 5.0 stride unverified | adapt 4.0; validate sample rate against capture (A4) |

## Metadata

**Analog search scope:** `re/`, `re/survey_5/`, `scripts/`, `protocol/`, `re/capture/evidence/`, `Packages/WhoopProtocol/`, `FINDINGS.md`, `FINDINGS_5.md`.
**Files scanned:** 12 read in full or targeted (`re/decode.py`, `re/survey_5/validate_frames_5.py`, `re/standard_ble.py`, `scripts/sync-schema.sh`, `scripts/gen_golden.py`, `protocol/whoop_protocol.json`, `protocol/whoop_protocol_5.json`, `re/survey_5/frames_5_golden.json`, `Packages/.../frames.json`, `re/capture/evidence/2026-05-30-framing-5.meta.yaml`, FINDINGS section indexes ×2).
**Pattern extraction date:** 2026-05-30
