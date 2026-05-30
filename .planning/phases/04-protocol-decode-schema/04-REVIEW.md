---
phase: 04-protocol-decode-schema
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json
  - protocol/whoop_protocol_5.json
  - re/capture/evidence/2026-05-30-biometric-5.meta.yaml
  - re/survey_5/command_surface_5.py
  - re/survey_5/decode_5.py
  - re/survey_5/decode_biometrics_5.py
  - re/survey_5/decode_streams_5.py
  - re/survey_5/frames_5_golden.json
  - scripts/sync-schema-5.sh
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-05-30T00:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Phase 4 protocol-decode and schema artefacts for the WHOOP 5.0 (Maverick) BLE
reverse-engineering project. The files cover: the canonical JSON schema (duplicated into the
Swift bundle), the Python offline analysis tools (decode_5, decode_biometrics_5,
decode_streams_5, command_surface_5), the curated golden frame fixture, and the sync shell
script.

Security posture is sound: no BD_ADDR, SMP pairing keys, serial numbers, or device UDIDs
were found in any committed file. The 14 distinct session tokens in frames_5_golden.json are
ephemeral per-session 3-byte values, not device identity, and fall within the project's
documented disclosure policy.

The defensive length-guard and log-and-continue patterns are intentional (D-03) and are not
flagged. No production code paths — all Python files are offline analysis tools.

Four warnings were found: a dead `unresolved` variable that silently renders the D-01 cmd-
resolution gate incomplete; a parallel `all_cmds_known` variable that is always returned as
`True`; an IMU axis offset inconsistency between the JSON schema and the Python decoder; and
a misleading error message in `sync-schema-5.sh` when the source file is absent. Four info
items cover minor quality defects.

---

## Warnings

### WR-01: Dead variable silently defeats the D-01 cmd-resolution gate

**File:** `re/survey_5/decode_5.py:207-209`

**Issue:** `_gate_print` computes `unresolved` (a list of frames whose `cmd_name` fell
through to a bare `cmd{N}` / `event{N}` / `meta{N}` fallback) but the variable is
**never read or printed**. The function always returns `all_cmds_known = True` regardless of
whether any command names went unresolved. The caller `run_gate` discards this value with
`_all_cmds_known`. The gate therefore never fires on unresolved command IDs — an unknown
PacketType correctly fails the gate (`all_ptypes_known`), but an unknown CommandNumber /
EventNumber silently passes.

```python
# Current (lines 207-213) — unresolved is computed but never used:
unresolved = [i for i in items
              if i["cmd_name"].startswith(("cmd", "event", "meta"))
              and i["cmd_name"][len("cmd"):].lstrip("dmevnta").isdigit()]
cmd_names = sorted({i["cmd_name"] for i in items})
ex = items[0]
print(f"  {tname}: {len(items)} frames | cmds: {', '.join(cmd_names)}")

# Fix — print the unresolved count and set all_cmds_known:
if unresolved:
    all_cmds_known = False
    print(f"    WARN: {len(unresolved)} frames with unresolved cmd names: "
          f"{sorted({i['cmd_name'] for i in unresolved})}")
```

Additionally, the `lstrip("dmevnta")` suffix-stripping heuristic is fragile: it was clearly
intended to strip the leading word from fallback names like `"event5"` (stripping `"vent"`)
or `"meta5"` (stripping `"ta"`), but the character set `"dmevnta"` strips any of those
individual characters, not the whole prefix. A `cmd_name` like `"cmd0"` works by accident;
`"event_unknown"` would not be recognised. The correct approach is `removeprefix` (Python
3.9+) or an explicit `re.match`.

### WR-02: all_cmds_known always returned as True — gate return value misleads callers

**File:** `re/survey_5/decode_5.py:195, 226`

**Issue:** `_gate_print` initialises `all_cmds_known = True` and never modifies it (the
`unresolved` list is computed but not wired to this flag — see WR-01). The function
signature claims to return `(all_ptypes_known, all_cmds_known, ts_candidates)` and the
docstring of `run_gate` promises "every decoded ptype resolves to a known r52 PacketType
name" — but the second return value conveys no information. Any downstream consumer that
inspects `all_cmds_known` (e.g. a future test harness) will receive a false positive.

**Fix:** Wire the fix from WR-01 (`all_cmds_known = False` when `unresolved` is non-empty)
and update the `run_gate` call site to honour both flags:

```python
# run_gate (line 235) — currently ignores all_cmds_known:
all_ptypes_known, _all_cmds_known, ts_candidates = _gate_print(bytype)

# Fix:
all_ptypes_known, all_cmds_known, ts_candidates = _gate_print(bytype)
if not all_cmds_known:
    print("GATE WARN: some cmd names did not resolve to a known r52 enum entry")
```

### WR-03: IMU axis offsets are inconsistent between JSON schema and Python decoder

**File:** `re/survey_5/decode_biometrics_5.py:107-114` vs
`protocol/whoop_protocol_5.json` (packets.REALTIME_RAW_DATA.variants.1917.axes)

**Issue:** The six IMU axis start offsets differ by exactly 7 between the two artefacts:

| Axis   | decode_biometrics_5.py | whoop_protocol_5.json |
|--------|------------------------|-----------------------|
| accelX | 82                     | 89                    |
| accelY | 282                    | 289                   |
| accelZ | 482                    | 489                   |
| gyroX  | 685                    | 692                   |
| gyroY  | 885                    | 892                   |
| gyroZ  | 1085                   | 1092                  |

The delta of 7 equals the length of the body prefix before `payload` (role[1] + token[3] +
ptype[1] + seq[1] + subseq/cmd[1] = 7 bytes). The Python decoder treats its constants as
offsets into `payload` (= `body[7:]`), while the JSON schema `schema_note` declares all
`off` fields as BODY-ABSOLUTE. However the variant note in the JSON reads "(4.0 axis
offsets/scales are frame-relative within the 1917-byte payload)" — which contradicts the
body-absolute convention declared in `schema_note`.

The two artefacts are therefore using **different reference frames** for the same offsets.
Since type-43 frames are HYPOTHESIS / never observed in Phase 4, neither set has been
exercise-validated. When a live type-43 frame is eventually captured the caller that applies
the wrong reference frame will silently decode garbage.

**Fix:** Clarify the reference frame in the JSON schema and align one artefact to the other.
The simplest fix is to adopt body-absolute consistently (matching the rest of the schema)
and update `decode_biometrics_5.py` to add 7 to each offset, or to restate the JSON axes
offsets as payload-relative and add a `"offset_base": "payload"` annotation to the variant:

```python
# decode_biometrics_5.py: if using payload-relative offsets (current), add a comment:
IMU_AXES = [  # offsets are PAYLOAD-RELATIVE (= body[7:]), not body-absolute
    ("accelX", 82, 0.000244140625, "g"),
    ...
]
```

```json
// whoop_protocol_5.json: add offset_base annotation to the variant
"variants": {
  "1917": {
    "offset_base": "body-absolute",
    "axes": [["accelX", 89, "accel"], ...]
  }
}
```

### WR-04: sync-schema-5.sh gives a misleading error when the source file is missing

**File:** `scripts/sync-schema-5.sh:12-14`

**Issue:** The JSON-validation guard is:

```bash
if ! python3 -c "import json, sys; json.load(open('$CANON'))"; then
  echo "ERROR: $CANON is not valid JSON — refusing to sync." >&2
  exit 1
fi
```

If `$CANON` does not exist (e.g. a fresh checkout before `sync-schema-5.sh` has been run
once), Python raises `FileNotFoundError` and the script exits with the message
"is not valid JSON — refusing to sync." The real failure (file absent) is obscured. A CI
engineer debugging a fresh-clone failure will look for JSON syntax errors rather than a
missing file.

Additionally, if the `$ROOT` path contains spaces, the single-quoted `'$CANON'` expansion
inside the double-quoted `-c` string will produce a syntactically broken Python string
literal, causing a `SyntaxError` instead of a `json.JSONDecodeError`. Both are non-zero
exits that prevent the `cp`, so correctness is preserved under `set -e`, but the error
message is still misleading.

**Fix:** Add an explicit existence check before the JSON validation:

```bash
if [[ ! -f "$CANON" ]]; then
  echo "ERROR: $CANON not found — cannot sync." >&2
  exit 1
fi
if ! python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$CANON"; then
  echo "ERROR: $CANON is not valid JSON — refusing to sync." >&2
  exit 1
fi
```

Passing `$CANON` as an argument (rather than embedding it in the `-c` string) also
eliminates the quoting hazard for paths with spaces.

---

## Info

### IN-01: Redundant while-condition in parse_hr fallback copy

**File:** `re/survey_5/decode_biometrics_5.py:72`

**Issue:** The verbatim-copy fallback of `parse_hr` contains:

```python
while idx + 1 < len(data) + 1 and idx + 1 <= len(data):
```

The first sub-condition (`idx + 1 < len(data) + 1`) is mathematically implied by the
second (`idx + 1 <= len(data)`): if `idx+1 <= len(data)` then trivially `idx+1 < len(data)+1`.
The first condition is always `True` whenever the second is `True`, making it dead. This is
a copy-fidelity concern: if `standard_ble.parse_hr` is corrected upstream, a reviewer
comparing diffs may miss that the condition is still wrong.

**Fix:** Simplify to the single meaningful condition:

```python
while idx + 1 <= len(data):
```

Or, equivalently: `while idx + 2 <= len(data):` (requires 2 bytes for a u16 read), which
also removes the redundant `if idx + 2 > len(data): break` guard inside the loop.

### IN-02: `all_cmds_known` return value is undocumented dead weight

**File:** `re/survey_5/decode_5.py:193`

**Issue:** The `_gate_print` docstring states it returns `(all_ptypes_known,
all_cmds_known, timestamp_candidates)` but `all_cmds_known` is always `True` (see WR-01 /
WR-02). Until WR-01 is fixed, the return signature is misleading. This is a documentation
quality issue independent of WR-01's correctness impact.

**Fix:** Resolve WR-01 first. If the cmd-resolution gate is intentionally deferred, remove
`all_cmds_known` from the return tuple and update the docstring accordingly.

### IN-03: Schema field map for CONSOLE_LOGS omits body[6] (cmd byte)

**File:** `protocol/whoop_protocol_5.json` (packets.CONSOLE_LOGS.fields)

**Issue:** The `CONSOLE_LOGS` packet entry documents `packet_type` (off=4), `seq` (off=5),
and `log_text` (off=7), skipping body[6]. However, `parse_body_5` always parses body[6] as
`cmd`, and empirical inspection of the golden corpus shows `cmd=2` (EventNumber
`CONSOLE_OUTPUT`) consistently in CONSOLE_LOGS frames — body[6] carries semantically
meaningful data. A schema consumer generating a decoder from the field map will not know to
read or validate this byte.

**Fix:** Add a `subtype` or `console_type` field at off=6 to the CONSOLE_LOGS field map:

```json
{"off": 6, "len": 1, "dtype": "u8", "name": "console_type", "cat": "frame",
 "enum": "EventNumber", "epoch": "none", "confidence": "VERIFIED",
 "note": "body[6] == 2 (CONSOLE_OUTPUT) in all observed CONSOLE_LOGS frames"}
```

### IN-04: Module-level _load_enums() failure produces an opaque import error

**File:** `re/survey_5/decode_5.py:60`

**Issue:** `ENUMS = _load_enums()` runs at module import time with no error handling. If
`protocol/whoop_protocol.json` is absent (e.g. a worktree checkout where the sibling
`protocol/` tree was not populated), all three importing scripts (`command_surface_5.py`,
`decode_streams_5.py`, `decode_biometrics_5.py`) crash at import time with a raw
`FileNotFoundError` stack trace, giving the developer no actionable hint about which file
is missing or how to fix it.

**Fix:** Wrap with a clear message:

```python
try:
    ENUMS = _load_enums()
except FileNotFoundError as e:
    raise SystemExit(
        f"ERROR: cannot load r52 enum maps — {e}\n"
        "Ensure protocol/whoop_protocol.json exists in the repo root."
    ) from e
```

---

_Reviewed: 2026-05-30T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
