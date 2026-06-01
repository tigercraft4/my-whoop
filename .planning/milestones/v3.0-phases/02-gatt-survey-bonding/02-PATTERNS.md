# Phase 2: GATT Survey & Bonding — Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 7 new files + 1 gitignore entry
**Analogs found:** 6 / 7 (FINDINGS_5.md has exact analog; requirements.txt/venv has no analog — new)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `re/survey_5/survey_gatt_5.py` | utility / BLE probe | request-response | `re/gatt_dump.py` | exact |
| `re/survey_5/bond_5.py` | utility / BLE probe | request-response | `re/bond_attempt.py` | exact |
| `re/survey_5/hr_5.py` | utility / BLE probe | request-response + streaming | `re/standard_ble.py` | exact |
| `re/survey_5/device_local_5.example.py` | config template | — | `re/device_local.example.py` | exact |
| `re/survey_5/device_local_5.py` (gitignored) | config (real values) | — | `re/device_local.example.py` (+ `re/device_config.py` for env-var fallback pattern) | role-match |
| `re/survey_5/__init__.py` | package marker | — | none needed (empty file) | no analog needed |
| `FINDINGS_5.md` | documentation / findings | — | `FINDINGS.md` | exact |
| `re/survey_5/requirements.txt` + venv setup | config | — | none in codebase | no analog |

---

## Pattern Assignments

### `re/survey_5/survey_gatt_5.py` (utility, request-response)

**Analog:** `re/gatt_dump.py` (lines 1–28, entire file)

**Imports pattern** (`re/gatt_dump.py` lines 1–5):
```python
import asyncio
from bleak import BleakClient, BleakScanner

from device_config import DEVICE_UUID as ADDR
```

For the 5.0 version, `device_config` is replaced by a local `device_local_5` import (no env-var fallback layer needed for RE scripts):
```python
import asyncio
import json
from bleak import BleakClient, BleakScanner

from device_local_5 import DEVICE_UUID as ADDR
```

**Core GATT enumeration pattern** (`re/gatt_dump.py` lines 8–28):
```python
async def main():
    print("Scanning to get device handle...")
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("Device not found in scan. Is it awake/in range?")
        return
    print(f"Found: {dev.name} ({dev.address})")
    print("Connecting...")
    async with BleakClient(dev) as client:
        print(f"Connected: {client.is_connected}\n")
        print("=== GATT SERVICES & CHARACTERISTICS ===")
        for service in client.services:
            print(f"\n[Service] {service.uuid}  ({service.description})")
            for char in service.characteristics:
                props = ",".join(char.properties)
                print(f"  [Char] {char.uuid}  props=({props})  ({char.description})")
                for desc in char.descriptors:
                    print(f"    [Desc] {desc.uuid}")

asyncio.run(main())
```

**Additions required for Phase 2** (from RESEARCH.md Code Examples, full skeleton):
- Add `handle` field to service/char print lines: `f"[Service 0x{service.handle:04x}]"` and `f"[Char 0x{char.handle:04x}]"` — handle numbers are required for Phase 1 handle→UUID mapping (D-02).
- Add Phase 1 handle match annotation: flag characteristics with `char.handle in {0x099b, 0x099d, 0x09a3}`.
- Add JSON output to `re/survey_5/gatt_dump_5.json` (per RESEARCH.md Code Examples skeleton).
- `client.services` is used as a property (not `await get_services()`) — this is correct for bleak 3.x.

**Error handling pattern** (`re/gatt_dump.py` lines 11–13 — device-not-found guard):
```python
if dev is None:
    print("Device not found in scan. Is it awake/in range?")
    return
```

No try/except around GATT enumeration in the analog — `async with BleakClient(dev) as client:` lets exceptions propagate. Keep this minimal pattern for RE scripts.

---

### `re/survey_5/bond_5.py` (utility, request-response)

**Analog:** `re/bond_attempt.py` (lines 1–77, entire file)

**Imports pattern** (`re/bond_attempt.py` lines 1–16):
```python
import asyncio
import sys
import time

sys.path.insert(0, "whoomp/scripts")
from packet import WhoopPacket, PacketType, CommandNumber, EventNumber  # noqa: E402
from bleak import BleakClient, BleakScanner  # noqa: E402

from device_config import DEVICE_UUID as ADDR
CMD_TO = "61080002-8d6d-82b8-614a-1c8cb0f8dcc6"
CMD_FROM = "61080003-8d6d-82b8-614a-1c8cb0f8dcc6"
EVENTS = "61080004-8d6d-82b8-614a-1c8cb0f8dcc6"
DATA = "61080005-8d6d-82b8-614a-1c8cb0f8dcc6"
```

For the 5.0 version, the `sys.path` hack and `WhoopPacket` import are dropped (UUID constants not yet known); UUID placeholders are used instead:
```python
import asyncio
import time
from bleak import BleakClient, BleakScanner

from device_local_5 import DEVICE_UUID as ADDR

# Fill from nRF Connect survey (task 1):
CMD_IN_5   = "fd4b0002-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
CMD_RESP_5 = "fd4b0003-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
EVENTS_5   = "fd4b0004-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
```

**Bonding trigger pattern** (`re/bond_attempt.py` lines 40–63 — core pattern to copy):
```python
async def main():
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("not found"); return
    async with BleakClient(dev) as client:
        print(f"Connected: {client.is_connected}", flush=True)

        # 1. Explicit pair attempt (will raise NotImplementedError on macOS — expected)
        try:
            res = await client.pair()
            print(f"client.pair() returned: {res}", flush=True)
        except Exception as e:
            print(f"client.pair() raised: {type(e).__name__}: {e}", flush=True)

        await client.start_notify(CMD_FROM, mk("cmd_from"))
        await client.start_notify(EVENTS, mk("events"))

        # 2. Confirmed write (response=True) — forces ATT response; may trigger encryption/pairing
        print("\n--- confirmed write (may trigger pairing dialog) ---", flush=True)
        try:
            await send(client, CommandNumber.GET_BATTERY_LEVEL, resp=True)
        except Exception as e:
            print(f"confirmed write raised: {type(e).__name__}: {e}", flush=True)
        await asyncio.sleep(2)
```

**Key difference for 5.0:** The analog uses `WhoopPacket.framed_packet()` to build the confirmed write payload. For the initial 5.0 bonding attempt, use a bare `b"\x00"` payload (`await client.write_gatt_char(CMD_IN_5, b"\x00", response=True)`) since the 5.0 framing is not yet confirmed. The `response=True` keyword argument is mandatory (not positional — bleak 3.x deprecation).

**Notification callback pattern** (`re/bond_attempt.py` lines 22–30):
```python
t0 = time.time()
counts = {"cmd_from": 0, "events": 0, "data": 0}

def mk(name):
    def cb(_, data):
        counts[name] += 1
        try:
            pkt = WhoopPacket.from_data(bytes(data))
            print(f"[{time.time()-t0:5.1f}s] {name}: {pkt}", flush=True)
        except Exception as e:
            print(f"[{time.time()-t0:.1f}s] {name} raw={bytes(data).hex()[:40]} ({e})", flush=True)
    return cb
```

For 5.0, drop the `WhoopPacket` parse and print raw hex only — framing not yet confirmed:
```python
t0 = time.time()

def mk(name):
    def cb(_, data):
        print(f"[{time.time()-t0:.1f}s] {name}: {bytes(data).hex()}", flush=True)
    return cb
```

**asyncio entry point** (`re/bond_attempt.py` line 77):
```python
asyncio.run(main())
```

---

### `re/survey_5/hr_5.py` (utility, request-response + streaming)

**Analog:** `re/standard_ble.py` (lines 1–62, entire file)

**Imports and UUID constants** (`re/standard_ble.py` lines 1–8):
```python
import asyncio
from bleak import BleakClient, BleakScanner

from device_config import DEVICE_UUID as ADDR
BATTERY = "00002a19-0000-1000-8000-00805f9b34fb"
MANUF = "00002a29-0000-1000-8000-00805f9b34fb"
HR_MEAS = "00002a37-0000-1000-8000-00805f9b34fb"
```

These standard UUIDs are identical for 5.0. Only change `device_config` to `device_local_5`.

**HR parse function** (`re/standard_ble.py` lines 11–29) — copy verbatim:
```python
def parse_hr(data: bytearray):
    """Parse standard Heart Rate Measurement (0x2A37): flags, HR, optional RR intervals."""
    flags = data[0]
    hr_16bit = flags & 0x01
    idx = 1
    if hr_16bit:
        hr = int.from_bytes(data[idx:idx + 2], "little"); idx += 2
    else:
        hr = data[idx]; idx += 1
    rr_present = (flags >> 4) & 0x01
    rrs = []
    if rr_present:
        while idx + 1 < len(data) + 1 and idx + 1 <= len(data):
            if idx + 2 > len(data):
                break
            rr_raw = int.from_bytes(data[idx:idx + 2], "little")
            rrs.append(round(rr_raw / 1024 * 1000, 1))  # 1/1024s units -> ms
            idx += 2
    return hr, rrs, list(data)
```

**Battery read + HR notify pattern** (`re/standard_ble.py` lines 32–62):
```python
async def main():
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("Device not found."); return
    async with BleakClient(dev) as client:
        print(f"Connected: {client.is_connected}\n")
        batt = await client.read_gatt_char(BATTERY)
        print(f"Battery: {int(batt[0])}%")
        try:
            manuf = await client.read_gatt_char(MANUF)
            print(f"Manufacturer: {manuf.decode(errors='replace')}")
        except Exception as e:
            print(f"Manufacturer read failed: {e}")

        print("\nSubscribing to Heart Rate Measurement (0x2A37) for 12s...")
        count = 0

        def cb(_, data: bytearray):
            nonlocal count
            count += 1
            hr, rrs, raw = parse_hr(data)
            print(f"  HR={hr} bpm  RR={rrs}  raw={raw}")

        await client.start_notify(HR_MEAS, cb)
        await asyncio.sleep(12)
        await client.stop_notify(HR_MEAS)
        print(f"\nReceived {count} HR notifications.")

asyncio.run(main())
```

Copy this pattern verbatim for `hr_5.py`. Only change is `from device_local_5 import DEVICE_UUID as ADDR`.

---

### `re/survey_5/device_local_5.example.py` (config template)

**Analog:** `re/device_local.example.py` (lines 1–6, entire file — copy exactly):
```python
# Copy to re/device_local.example.py (gitignored) and fill in your strap's real values.
# These are personal identifiers — device_local.py must never be committed.
DEVICE_UUID = "00000000-0000-0000-0000-000000000000"  # macOS CoreBluetooth peripheral UUID
DEVICE_MAC = "00:00:00:00:00:00"                       # Bluetooth MAC
DEVICE_SERIAL = "0000000000"                            # strap serial
```

For `device_local_5.example.py`, adapt comment to reference the 5.0 file and `re/survey_5/`:
```python
# Copy to re/survey_5/device_local_5.py (gitignored) and fill in your WHOOP 5.0 strap's real values.
# These are personal identifiers — device_local_5.py must never be committed.
DEVICE_UUID = "00000000-0000-0000-0000-000000000000"  # macOS CoreBluetooth peripheral UUID (scan to find)
DEVICE_MAC = "00:00:00:00:00:00"                       # Bluetooth MAC (from nRF Connect)
DEVICE_SERIAL = "0000000000"                            # strap serial (from nRF Connect or device label)
```

**gitignore entry required:** `re/survey_5/device_local_5.py` must be added to `.gitignore` (currently only `re/device_local.py` is listed). The planner must include this step.

---

### `re/survey_5/device_local_5.py` (gitignored, real values)

**Analog:** `re/device_local.example.py` (interface) + `re/device_config.py` (env-var fallback pattern, lines 1–28)

For RE scripts, the simple direct-import pattern from `device_local.example.py` is sufficient — no env-var fallback layer needed since these are single-user local scripts. The gitignored file holds the real values; the example holds placeholders.

The `device_config.py` env-var fallback pattern (lines 17–28) is useful if the planner decides to add a `device_config_5.py` wrapper, but CONTEXT.md D-04b specifies direct import from `device_local_5`, so keep it simple.

---

### `re/survey_5/__init__.py` (package marker)

**No analog needed.** Empty file (`touch re/survey_5/__init__.py`). Makes `re/survey_5/` importable as a Python package if needed. No content to extract.

---

### `FINDINGS_5.md` (documentation, primary committed artifact)

**Analog:** `FINDINGS.md` (lines 1–60+ — structure to mirror)

**Document header pattern** (`FINDINGS.md` lines 1–3):
```markdown
# WHOOP 4.0 BLE Protocol — Reverse-Engineering Findings

_Last updated: 2026-05-23. Working dir: `~/Developer/whoop`. Target: the user's own Whoop 4.0 ..._
```

Adapt for 5.0:
```markdown
# WHOOP 5.0 BLE Protocol — Reverse-Engineering Findings

_Last updated: YYYY-MM-DD. Target: WHOOP 5.0 (serial [REDACTED], macOS BLE UUID [REDACTED])._
```

**Status table pattern** (`FINDINGS.md` lines 9–22):
```markdown
## Status at a glance

| Capability | Status |
|---|---|
| Connect over BLE (unbonded) | ... |
| Bonding (unlocks custom data channels) | ... |
```

**Section structure** (`FINDINGS.md` sections 1–5) — mirror these headings for Phase 2 bootstrap:
```markdown
## 1. Connecting & Bonding
## 2. GATT Map (confirmed Phase 2)
## 3. Legacy UUID Verdict (61080001-... present or absent)
## 4. Standard Characteristics (HR / Battery)
## 5. Handle → UUID Map (closes Phase 1 loop)
## 6. Open Questions / Phase 3 Inputs
```

RESEARCH.md §FINDINGS_5.md Structure provides the full recommended section outline — use that directly as the template, mirroring `FINDINGS.md` style.

---

### `re/survey_5/requirements.txt` + venv setup (config)

**No analog in codebase.** No existing `requirements.txt` in `re/`. The 4.0 scripts appear to use a pre-existing environment without a committed requirements file.

**Pattern from RESEARCH.md** (install commands):
```bash
python3.11 -m venv re/survey_5/.venv
source re/survey_5/.venv/bin/activate
pip install "bleak==3.0.2"
```

The planner should include a `re/survey_5/requirements.txt` with pinned versions:
```
bleak==3.0.2
```

The `.venv/` directory is already gitignored via `.gitignore` `**/.venv/` glob — no additional gitignore entry needed for the venv.

---

## Shared Patterns

### BLE Device Discovery
**Source:** `re/gatt_dump.py` lines 10–13 and `re/bond_attempt.py` lines 40–42
**Apply to:** All three survey scripts (`survey_gatt_5.py`, `bond_5.py`, `hr_5.py`)
```python
dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
if dev is None:
    print("Device not found in scan. Is it awake/in range?")
    return
```
Note: On macOS, `ADDR` must be a CoreBluetooth UUID string, NOT a MAC address. This constraint is documented in `RESEARCH.md §Anti-Patterns`.

### BleakClient Context Manager
**Source:** `re/gatt_dump.py` line 16, `re/bond_attempt.py` line 43, `re/standard_ble.py` line 36
**Apply to:** All three survey scripts
```python
async with BleakClient(dev) as client:
    print(f"Connected: {client.is_connected}", flush=True)
```
Using `async with` (not explicit `connect()`/`disconnect()`) is the established project pattern. It handles cleanup on exception.

### asyncio Entry Point
**Source:** `re/gatt_dump.py` line 28, `re/bond_attempt.py` line 77, `re/standard_ble.py` line 62
**Apply to:** All three survey scripts
```python
asyncio.run(main())
```
No `if __name__ == "__main__":` guard used in the project's RE scripts — follow the same convention.

### Device Identity Import
**Source:** `re/gatt_dump.py` line 5 (analog), `re/device_config.py` line 34 (harness)
**Apply to:** All three survey scripts + `device_local_5.example.py`
```python
from device_local_5 import DEVICE_UUID as ADDR
```
The 4.0 scripts use `from device_config import DEVICE_UUID as ADDR` (with env-var fallback). For `re/survey_5/`, the simpler direct import from `device_local_5` is specified by D-04b. The fallback chain in `device_config.py` is not replicated for Phase 2 scripts.

### `client.services` Property (bleak 3.x)
**Source:** `re/gatt_dump.py` line 19, `re/re_harness.py` line 227
**Apply to:** `survey_gatt_5.py`
```python
for service in client.services:
    for char in service.characteristics:
```
`client.services` is a property in bleak 3.x (NOT an async call). The old `await client.get_services()` is removed in bleak 3.x — do not use it.

### Notification Callback Signature
**Source:** `re/bond_attempt.py` lines 22–30, `re/standard_ble.py` lines 50–53, `re/re_harness.py` lines 87–117
**Apply to:** `bond_5.py` and `hr_5.py`
```python
def cb(_, data: bytearray):
    # _ is BleakGATTCharacteristic (sender), not an int handle (bleak 3.x)
    print(bytes(data).hex())
```
The first argument is a `BleakGATTCharacteristic` object in bleak 3.x (not an integer handle). The convention in all project scripts is to use `_` since the sender is not needed.

### `write_gatt_char` with `response=True`
**Source:** `re/bond_attempt.py` line 35 (via `send()` helper), confirmed in RESEARCH.md §Pattern 2
**Apply to:** `bond_5.py`
```python
await client.write_gatt_char(CMD_IN_5, b"\x00", response=True)
```
The `response=True` keyword argument is mandatory for the bonding trigger. `response=False` (Write Without Response / ATT Write Command) does NOT trigger encryption negotiation.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `re/survey_5/requirements.txt` | config | — | No requirements.txt exists in the codebase; 4.0 scripts use an implicit environment |
| `re/survey_5/__init__.py` | package marker | — | No `__init__.py` in `re/` (flat script directory); this is a new pattern for the survey subdirectory |

---

## Additional Notes for Planner

### gitignore Update Required
The planner must add `re/survey_5/device_local_5.py` to `.gitignore`. Currently only `re/device_local.py` is listed. Pattern:
```
re/survey_5/device_local_5.py
```

### `device_config.py` Not Reused in `re/survey_5/`
The existing `re/device_config.py` provides an env-var fallback pattern. For `re/survey_5/` scripts, the simpler direct import (`from device_local_5 import DEVICE_UUID as ADDR`) is used per D-04b. Do NOT create a `device_config_5.py` wrapper unless the planner explicitly decides to add env-var fallback.

### sys.path Hack in `bond_attempt.py` — Do NOT Copy
`re/bond_attempt.py` lines 8–9 use `sys.path.insert(0, "whoomp/scripts")` to import `WhoopPacket`. For `bond_5.py`, this import is dropped entirely — the 5.0 framing is unconfirmed and bond_5.py uses raw bytes only.

### Evidence Artifacts — Not Scripted
The `re/capture/evidence/YYYY-MM-DD-gatt-survey-5.meta.yaml` and `.hex` files are created manually (tshark + text editor) per D-02 policy. No script analog exists; the planner should document the evidence workflow as runbook steps, not code.

---

## Metadata

**Analog search scope:** `re/` directory (all `.py` files); `FINDINGS.md`; `.gitignore`
**Files scanned:** `re/gatt_dump.py`, `re/bond_attempt.py`, `re/standard_ble.py`, `re/device_local.example.py`, `re/device_config.py`, `re/re_harness.py`, `FINDINGS.md`
**Pattern extraction date:** 2026-05-30
