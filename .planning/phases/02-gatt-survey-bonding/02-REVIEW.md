---
phase: 02-gatt-survey-bonding
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml
  - re/survey_5/__init__.py
  - re/survey_5/bond_5.py
  - re/survey_5/device_local_5.example.py
  - re/survey_5/hr_5.py
  - re/survey_5/README.md
  - re/survey_5/requirements.txt
  - re/survey_5/survey_gatt_5.py
findings:
  critical: 2
  warning: 3
  info: 1
  total: 6
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-30T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

This review covers the WHOOP 5.0 GATT survey and bonding scripts (`re/survey_5/`) together
with the associated evidence sidecar. The code is research-quality Python 3.11 + bleak 3.0.2
running on macOS/CoreBluetooth.

Two critical issues were found:

1. `parse_hr()` in `hr_5.py` crashes with `IndexError` on any malformed notification payload
   from an untrusted BLE peripheral — including a zero-byte or one-byte frame, both of which
   a rogue device could trivially send. This is a correctness-and-security defect because BLE
   peripheral data is untrusted by definition.

2. `survey_gatt_5.py` writes `gatt_dump_5.json` using a relative path. When the script is run
   from any directory other than `re/survey_5/`, the dump file lands outside the gitignored
   path and can be accidentally committed, leaking the real CoreBluetooth device UUID and
   device name — the exact identifiers the project policy forbids committing.

Three warnings cover: a wrong handle annotation in `bond_5.py` that misattributes `0x09a3` to
the events characteristic (it belongs to data), a grouped `try/except` in `bond_5.py` that
silently drops the second `start_notify` when the first raises, and an obfuscated RR-interval
loop condition in `parse_hr` that is correct but maintains a misleading inner guard.

---

## Critical Issues

### CR-01: `parse_hr` crashes on malformed BLE notification payload (untrusted peripheral data)

**File:** `re/survey_5/hr_5.py:20-38`

**Issue:** `parse_hr(data)` performs no length validation before indexing into `data`. A BLE
peripheral (including a rogue device advertising the standard HR service UUID
`0x2A37`) can send:

- An empty bytearray → `IndexError` at `data[0]` (line 22).
- A one-byte payload (flags byte only, no HR field) → `IndexError` at `data[idx]` (line 28)
  when the 8-bit HR branch executes.

Both crash the callback `cb()` defined at line 59. In bleak 3.x the exception propagates
to bleak's internal notification dispatcher, which logs a warning but does not re-raise —
so the script stays running but silently stops collecting HR data. More critically, this is
unvalidated consumption of untrusted BLE data, which is the explicit security concern
documented in the project review brief.

**Fix:**

```python
def parse_hr(data: bytearray):
    """Parse standard Heart Rate Measurement (0x2A37): flags, HR, optional RR intervals."""
    if len(data) < 2:
        raise ValueError(f"HR payload too short: {len(data)} byte(s), need >=2")
    flags = data[0]
    hr_16bit = flags & 0x01
    idx = 1
    if hr_16bit:
        if idx + 2 > len(data):
            raise ValueError(f"HR payload truncated for 16-bit HR: {len(data)} bytes")
        hr = int.from_bytes(data[idx:idx + 2], "little"); idx += 2
    else:
        hr = data[idx]; idx += 1
    rr_present = (flags >> 4) & 0x01
    rrs = []
    if rr_present:
        while idx + 2 <= len(data):
            rr_raw = int.from_bytes(data[idx:idx + 2], "little")
            rrs.append(round(rr_raw / 1024 * 1000, 1))
            idx += 2
    return hr, rrs, list(data)
```

Wrap the call site in `cb()` too:

```python
def cb(_, data: bytearray):
    nonlocal count
    count += 1
    try:
        hr, rrs, raw = parse_hr(data)
    except (ValueError, IndexError) as exc:
        print(f"  parse_hr error (malformed notification?): {exc}  raw={list(data)}")
        return
    print(f"  HR={hr} bpm  RR={rrs}  raw={raw}")
```

---

### CR-02: `gatt_dump_5.json` path is relative — device identity leaks if script run from wrong directory

**File:** `re/survey_5/survey_gatt_5.py:33`

**Issue:** `OUT_PATH = "gatt_dump_5.json"` is a bare relative path. The `.gitignore` rule
that prevents committing the file is:

```
re/survey_5/gatt_dump_5.json
```

This rule is anchored to `re/survey_5/`. When the script is run from any other directory
(e.g. `python re/survey_5/survey_gatt_5.py` from the project root, which is a natural
invocation), `json.dump` at line 84 writes the dump to `./gatt_dump_5.json` — i.e. the
project root — which is **not covered by the gitignore rule**. The dump contains the real
CoreBluetooth peripheral UUID (`dev.address`) and device name (`dev.name`), exactly the
device identity the project policy forbids committing.

This is a latent device-identity leak that will not be caught by `git status` until it is
staged, and even then only an attentive developer will notice.

**Fix:** Use `__file__`-relative path anchoring so the output always lands in the gitignored
location regardless of the working directory:

```python
import pathlib

_HERE = pathlib.Path(__file__).parent
OUT_PATH = _HERE / "gatt_dump_5.json"
```

Update the final `open()` call accordingly:

```python
with open(OUT_PATH, "w") as f:
    json.dump(result, f, indent=2)
print(f"\n{OUT_PATH.name} written ({len(result['services'])} services)")
```

---

## Warnings

### WR-01: Wrong ATT handle annotation on `EVENTS_5` in `bond_5.py`

**File:** `re/survey_5/bond_5.py:33`

**Issue:** The inline comment on the `EVENTS_5` constant reads:

```python
EVENTS_5 = "FD4B0004-CCE1-4033-93CE-002D5875F58A"    # events,   notify, handle 0x09a3
```

According to the canonical evidence sidecar
(`re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml`, `bleak_declaration_handles`),
`0x09a3` is the **value** handle of `FD4B0005` (the **data** characteristic). The events
characteristic `FD4B0004` has declaration handle `0x099f` and value handle `0x09a0`. The
annotation is wrong, which contradicts the Phase 1 handle-to-UUID closure that is one of the
phase's stated deliverables and will mislead future readers correlating handles to UUIDs.

**Fix:**

```python
EVENTS_5 = "FD4B0004-CCE1-4033-93CE-002D5875F58A"    # events,   notify, handle 0x09a0 (decl 0x099f)
```

---

### WR-02: Single `try/except` silently drops second `start_notify` when first raises

**File:** `re/survey_5/bond_5.py:71-75`

**Issue:**

```python
try:
    await client.start_notify(CMD_RESP_5, mk("cmd_resp"))
    await client.start_notify(EVENTS_5, mk("events"))
except Exception as e:
    print(f"start_notify raised: {type(e).__name__}: {e}", flush=True)
```

If `start_notify(CMD_RESP_5, ...)` raises (which the meta.yaml confirms it does —
`CBATTErrorDomain Code=15 Encryption is insufficient`), the second `start_notify` on
`EVENTS_5` is never attempted. The printed error message does not identify which channel
failed. Both behaviours reduce observability during the bonding experiment: the operator
cannot distinguish "cmd_resp failed" from "both channels failed", and `EVENTS_5` might
have succeeded (unauthenticated notify) if tried independently.

**Fix:** Use separate `try/except` blocks per channel, or at minimum log which UUID failed:

```python
for uuid, label in ((CMD_RESP_5, "cmd_resp"), (EVENTS_5, "events")):
    try:
        await client.start_notify(uuid, mk(label))
        print(f"start_notify OK: {label}", flush=True)
    except Exception as e:
        print(f"start_notify({label}) raised: {type(e).__name__}: {e}", flush=True)
```

---

### WR-03: Redundant and misleading while-condition in `parse_hr` RR-interval loop

**File:** `re/survey_5/hr_5.py:32-37`

**Issue:**

```python
while idx + 1 < len(data) + 1 and idx + 1 <= len(data):
    if idx + 2 > len(data):
        break
    ...
```

The two sub-expressions of the `while` condition are mathematically identical:
`idx + 1 < len(data) + 1` simplifies to `idx < len(data)`, and `idx + 1 <= len(data)`
simplifies to `idx < len(data)`. The `and` of two identical expressions is the expression
itself — the conjunction adds no safety and makes a reader question whether a subtle
boundary is being guarded. The inner `if idx + 2 > len(data): break` then adds a
third inconsistent guard for the same boundary. The code is correct as-is only because the
inner `break` handles the one-byte residue correctly, but this is not apparent from reading
the outer condition.

This is a maintainability defect: a future engineer adding RR-parsing logic may misread the
outer condition as providing a real two-level guard (it does not) and remove the inner
`break`, creating an actual bug.

**Fix:** Replace with the single, self-documenting form (already shown in CR-01 fix):

```python
while idx + 2 <= len(data):
    rr_raw = int.from_bytes(data[idx:idx + 2], "little")
    rrs.append(round(rr_raw / 1024 * 1000, 1))
    idx += 2
```

---

## Info

### IN-01: `__init__.py` is an empty 1-line file (namespace-only package marker)

**File:** `re/survey_5/__init__.py:1`

**Issue:** The file contains only a newline — effectively empty. This is fine as a Python
package marker, but none of the scripts in `re/survey_5/` use relative imports; they all
use bare `import device_local_5` that depends on CWD being `re/survey_5/`. The presence of
`__init__.py` implies package semantics that the scripts do not actually leverage and could
confuse a user who tries to run them as `python -m re.survey_5.survey_gatt_5` (which would
fail because the CWD-relative `device_local_5` import would not resolve).

**Fix:** Either remove `__init__.py` (the scripts are standalone tools, not a package) or
convert the `device_local_5` import to a `__file__`-relative import using `importlib` or
`sys.path.insert`, and document the package invocation pattern. Given the scope of these
scripts the simplest fix is removal of `__init__.py`.

---

_Reviewed: 2026-05-30T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
