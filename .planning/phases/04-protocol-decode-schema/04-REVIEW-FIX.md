---
phase: 04-protocol-decode-schema
fixed_at: 2026-05-30T00:00:00Z
review_path: .planning/phases/04-protocol-decode-schema/04-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-05-30T00:00:00Z
**Source review:** .planning/phases/04-protocol-decode-schema/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01 + WR-02: Dead `unresolved` variable and `all_cmds_known` always True

**Files modified:** `re/survey_5/decode_5.py`
**Commit:** 679b4d6
**Applied fix:**
- Added `import re` to the module imports.
- Replaced the fragile `lstrip("dmevnta")` character-set heuristic with
  `re.match(r"^(?:cmd|event|meta)\d+$")` to reliably detect fallback cmd
  names (e.g. `cmd5`, `event12`, `meta3`) without false positives or misses
  like `event_unknown`.
- Wired `all_cmds_known = False` when the `unresolved` list is non-empty,
  so the gate actually fires on unknown CommandNumbers/EventNumbers.
- Added a per-type `WARN:` print line listing the unresolved names.
- In `run_gate`, changed `_all_cmds_known` (discarded) to `all_cmds_known`
  and added a `"GATE WARN: some cmd names did not resolve..."` print when
  the flag is False.

Note: WR-01 and WR-02 affect the same function (`_gate_print`) and its
call site (`run_gate`). They were committed together as a single atomic fix.

**Commit status:** fixed: requires human verification
(Logic change — the gate condition is now active where it was previously
always-True. Recommend running `python decode_5.py frames_5_golden.json`
against the golden corpus to confirm no regressions and that the WARN/PASS
output is sensible for all 46 known-good frames.)

---

### WR-03: IMU axis offsets use different reference frames in JSON schema vs Python decoder

**Files modified:** `re/survey_5/decode_biometrics_5.py`, `protocol/whoop_protocol_5.json`
**Commit:** 863b4a1
**Applied fix:**
- `decode_biometrics_5.py`: expanded the `IMU_AXES` comment block to state
  the PAYLOAD-RELATIVE reference frame explicitly (`payload = body[7:]`),
  listed both offset sets side-by-side (Python payload-relative vs JSON
  body-absolute) for unambiguous cross-reference, and annotated the tuple
  header with `payload_relative_offset`.
- `protocol/whoop_protocol_5.json` (variants["1917"]): added
  `"offset_base": "body-absolute"` field and updated the `note` string to
  state the body-absolute convention and its relationship to the Python
  decoder's payload-relative offsets (body-absolute = payload-relative + 7).

The numeric offsets themselves were not changed — both artefacts described
correct bytes; only the reference frame was undocumented. This fix makes the
reference frame explicit in both places so a future implementer applying one
artefact without the other cannot silently decode wrong bytes.

---

### WR-04: `sync-schema-5.sh` misleading error when source file is missing; path-with-spaces quoting hazard

**Files modified:** `scripts/sync-schema-5.sh`
**Commit:** 9ce58ce
**Applied fix:**
- Added an explicit `[[ ! -f "$CANON" ]]` guard before the JSON validation
  block that prints `"ERROR: $CANON not found — cannot sync."` and exits 1.
  Previously, a missing file caused Python to raise `FileNotFoundError` but
  the script printed "is not valid JSON", obscuring the real failure.
- Changed the Python invocation from embedding `$CANON` directly in the
  `-c` string (`open('$CANON')`) to passing it as a positional argument
  (`python3 -c "... open(sys.argv[1])" "$CANON"`). This eliminates the
  `SyntaxError` that occurred when `$ROOT` contained spaces.

---

_Fixed: 2026-05-30T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
