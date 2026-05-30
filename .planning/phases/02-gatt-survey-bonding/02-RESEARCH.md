# Phase 2: GATT Survey & Bonding — Research

**Researched:** 2026-05-30
**Domain:** BLE GATT enumeration, Bleak Python scripting on macOS, BLE bonding via confirmed-write, SMP capture, standard HR/battery GATT profiles
**Confidence:** HIGH (core Bleak APIs), MEDIUM (5.0-specific UUID differences), HIGH (4.0 confirmed-write pattern from working production code)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** nRF Connect first — use nRF Connect on iPhone as primary visual GATT browser. Close official WHOOP app before connecting. Bleak uses confirmed UUIDs afterward.
- **D-01b:** Close official WHOOP app before connecting with nRF Connect (only one BLE central at a time).
- **D-01c:** Confirm presence or absence of legacy `61080001-…` alongside `fd4b0001-…` on this specific unit. Document both verdicts in `FINDINGS_5.md`.
- **D-02:** Map Phase 1 handles (0x099b, 0x099d, 0x09a3) to their characteristic UUIDs as an explicit step.
- **D-03:** Try 4.0 confirmed-write trick first on cmd-in handle. Fallback: PacketLogger SMP capture per `re/capture/ios-packetlogger.md`.
- **D-03b:** Fallback to PacketLogger SMP capture of official app handshake.
- **D-03c:** WHOOP is currently paired with official app on iPhone. Plan includes: Forget Device on iPhone → close official app → run Bleak bond script.
- **D-04:** All Phase 2 scripts go in `re/survey_5/` (new subdirectory, isolated from 4.0 `re/`).
- **D-04b:** Device identity: `re/survey_5/device_local_5.py` (gitignored); `re/survey_5/device_local_5.example.py` template committed.
- **D-05:** `FINDINGS_5.md` starts in Phase 2. Contents: confirmed UUIDs + handle map, legacy UUID verdict, bond outcome, HR/battery confirmation.
- **D-05b:** `protocol/whoop_protocol_5.json` starts in Phase 3 — premature before UUIDs confirmed.

### Claude's Discretion

None identified in CONTEXT.md.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROTO-01 | WHOOP 5.0 GATT service UUID(s) confirmed on user's specific device (fd4b0001-... and/or legacy 61080001-... presence documented) | §Standard Stack: nRF Connect + Bleak `client.services` enumeration; §Architecture Patterns: GATT discovery flow; §Code Examples: gatt_dump pattern |
| PROTO-02 | BLE bonding replicated without the official WHOOP app (confirmed-write trick or equivalent on 5.0) | §Architecture Patterns: Bonding flow; §Common Pitfalls: macOS bonding gotchas; §Code Examples: confirmed-write bond snippet |
| PROTO-03 | GATT characteristics enumerated and mapped (7 characteristics: cmd-in, cmd-resp, events, data, diagnostics + standard HR + battery) | §Standard Stack: Bleak GATT APIs; §Architecture Patterns: characteristic enumeration; §Standard GATT Profiles section |
</phase_requirements>

---

## Summary

Phase 2 is a BLE investigation phase with two sequential work streams: (1) visual GATT enumeration via nRF Connect on iPhone, followed by (2) Python scripting via Bleak on macOS to replicate bonding and confirm HR/battery streaming. Both streams are well-understood from the 4.0 production codebase — the primary uncertainty is whether the 5.0 cmd-in handle responds identically to a confirmed write for bonding, and which exact UUIDs map to the Phase 1 handles (0x099b, 0x099d, 0x09a3).

The 4.0 confirmed-write bonding mechanism (`write_gatt_char(..., response=True)` on the cmd-in characteristic) is verified working — it is the mechanism already in production in `re/bond_attempt.py` and `re/re_harness.py`. On macOS, `BleakClient.pair()` raises `NotImplementedError`; the confirmed-write approach is the documented and only reliable path for triggering CoreBluetooth's implicit "just-works" bonding. The WHOOP 5.0 strap uses the same inner framing (0xAA SOF confirmed in Phase 1), so the same command-write trigger is expected to work on the `fd4b0001-…0002` characteristic.

The standard HR characteristic (0x2A37) and battery characteristic (0x2A19) work unbonded on the 4.0 strap and are expected to work the same on 5.0. HR parsing is already implemented in `re/standard_ble.py` and `re/re_harness.py`. The Phase 2 Bleak scripts should be minimal ports of the existing 4.0 scripts, adapted to use the 5.0 UUID family and the `re/survey_5/device_local_5.py` identity pattern.

**Primary recommendation:** Use the existing `re/gatt_dump.py` and `re/bond_attempt.py` as templates for `re/survey_5/survey_gatt_5.py` and `re/survey_5/bond_5.py`. The only unknowns are the exact 5.0 UUIDs (Phase 1 captured handles, not UUIDs — confirmed via nRF Connect in task 1) and whether the confirmed-write bonding path works on 5.0.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| GATT enumeration (visual) | iPhone / nRF Connect | — | Only one BLE central at a time; nRF Connect runs on the same iPhone the WHOOP is paired to — close app, connect nRF Connect |
| GATT enumeration (programmatic) | macOS / Bleak script | — | After UUIDs confirmed by nRF Connect, Bleak script cross-checks handles and properties |
| BLE bonding | macOS / Bleak script | iPhone PacketLogger (fallback) | Bleak issues the confirmed write that triggers OS-level bonding; PacketLogger captures SMP if the trick fails |
| HR/battery streaming | macOS / Bleak script | — | Standard GATT profiles work over BLE; Bleak subscribes to notify |
| Evidence collection | macOS / tshark + manual | PacketLogger | redacted hex + SHA256 + meta.yaml per established D-02 policy |
| FINDINGS_5.md authoring | Developer (manual) | — | UUIDs transcribed from nRF Connect; bond outcome from script output |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bleak | 3.0.2 | Async BLE client for macOS/Windows/Linux via native backends (CoreBluetooth on macOS) | The only maintained pure-Python BLE library for macOS; already in use in all 4.0 RE scripts |
| asyncio | stdlib | Event loop for Bleak's async API | Required by Bleak; already used in all 4.0 scripts |
| pyobjc-core | ≥10.3 | Bleak macOS dependency (CoreBluetooth bridge) | Auto-installed as bleak dep |
| pyobjc-framework-CoreBluetooth | ≥10.3 | CoreBluetooth Python bindings | Auto-installed as bleak dep |

**Version verification:** bleak 3.0.2 confirmed via PyPI JSON API (2026-05-02 release). [VERIFIED: pypi.org/pypi/bleak/json]

**Python requirement:** bleak 3.0.2 requires Python ≥ 3.10. The system Python (`/usr/bin/python3`) is 3.9.6 — a dedicated venv using a Homebrew or pyenv Python 3.11+ is required. [VERIFIED: pypi.org/project/bleak/]

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tshark | 4.6.6 | CLI Wireshark for SMP/ATT packet analysis | Bonding fallback: filter `btsmp` frames from PacketLogger capture |
| nRF Connect for iOS | current App Store | Visual GATT browser — primary UUID discovery tool | Primary tool before any Bleak code |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bleak | CoreBluetooth directly (Swift/ObjC) | bleak is already used in production 4.0 scripts; CoreBluetooth requires Xcode project setup and is 10× slower to iterate |
| nRF Connect (iPhone) | LightBlue (iPhone) or nRF Connect (Android) | nRF Connect is the BLE community standard for GATT browsing; free; shows handle numbers alongside UUIDs |

**Installation (survey_5 venv):**
```bash
# Requires Python 3.10+ — use homebrew python or pyenv
python3.11 -m venv re/survey_5/.venv
source re/survey_5/.venv/bin/activate
pip install "bleak==3.0.2"
```

---

## Package Legitimacy Audit

> slopcheck was run on `bleak`. It returned `[SUS]` citing "suspiciously close to 'black'" (typosquat warning). This is a **false positive**: `bleak` is the established Bluetooth Low Energy Async Kit for Python, first released April 2018 (8 years on PyPI), with 376,000+ weekly downloads and source at github.com/hbldh/bleak — a different domain from the Python formatter `black`. Registry existence, download volume, and official documentation all confirm legitimacy.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| bleak | PyPI | ~8 yrs (since 2018) | ~376K/week | github.com/hbldh/bleak | [SUS] — false positive (typosquat of "black"; unrelated domains) | Approved — false positive confirmed via download volume and official docs |

**Packages removed due to slopcheck [SLOP] verdict:** none

**Packages flagged [SUS] — false positive assessment:**
- `bleak`: slopcheck flagged as possible typosquat of `black`. Manually verified as the canonical Bluetooth LE library for Python — 8 years on PyPI, 376K+ weekly downloads, author is hbldh (Henrik Blidh), documented at bleak.readthedocs.io. No install checkpoint needed.

---

## Architecture Patterns

### System Architecture Diagram

```
iPhone (nRF Connect)             macOS (Bleak script)
        |                                |
  BLE scan + connect              BLE scan + connect
  GATT discovery                  GATT discovery (cross-check)
  [Services → Characteristics       [client.services iteration]
   → Handle + UUID table]                 |
        |                         confirmed write (response=True)
  Screenshot / manual               on cmd-in UUID (…0002)
  transcription                           |
        |                         OS-level bonding triggered
  FINDINGS_5.md ← UUID table       (CoreBluetooth "just-works")
        |                                 |
  Legacy UUID check           start_notify HR (0x2A37)
  (61080001-… present?)       start_notify battery (0x2A19)
                                          |
                                    Live BPM stream
                                    Battery % read
                                          |
                              FINDINGS_5.md ← bond + HR confirmation
                                          |
                              PacketLogger (fallback path only)
                              tshark -Y btsmp → SMP packet analysis
```

### Recommended Project Structure

```
re/survey_5/
├── device_local_5.example.py   # committed template (no real identifiers)
├── device_local_5.py           # gitignored (real BLE UUID/MAC/serial)
├── survey_gatt_5.py            # GATT enumeration script (port of re/gatt_dump.py)
├── bond_5.py                   # bonding script (port of re/bond_attempt.py)
├── hr_5.py                     # HR + battery streaming (port of re/standard_ble.py)
└── .venv/                      # gitignored Python 3.11+ venv with bleak 3.0.2
```

Evidence artifacts (per D-02 policy):
```
re/capture/evidence/
├── YYYY-MM-DD-gatt-survey-5.meta.yaml   # UUID list, handle map, legacy UUID verdict
├── YYYY-MM-DD-gatt-survey-5.hex         # tshark ATT decode excerpt (redacted)
└── YYYY-MM-DD-gatt-survey-5.sha256      # SHA256 of raw .pklg (if captured)
```

### Pattern 1: Bleak GATT Enumeration

**What:** Iterate `client.services` after connection; each service exposes `.characteristics`, each characteristic exposes `.uuid`, `.handle`, `.properties`, `.descriptors`.

**When to use:** After nRF Connect visually confirms UUIDs, use this to cross-check handles and capture the full GATT table programmatically.

```python
# Source: bleak.readthedocs.io/en/latest/api/client.html + re/gatt_dump.py (project)
import asyncio
from bleak import BleakClient, BleakScanner
from device_local_5 import DEVICE_UUID as ADDR

async def main():
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("device not found — is it awake and in range?")
        return
    async with BleakClient(dev) as client:
        print(f"connected: {client.is_connected}")
        for service in client.services:
            print(f"\n[Service 0x{service.handle:04x}] {service.uuid}  ({service.description})")
            for char in service.characteristics:
                props = ",".join(char.properties)
                print(f"  [Char 0x{char.handle:04x}] {char.uuid}  props=({props})  ({char.description})")
                for desc in char.descriptors:
                    print(f"    [Desc 0x{desc.handle:04x}] {desc.uuid}")

asyncio.run(main())
```

**macOS note:** On macOS, `ADDR` must be the CoreBluetooth peripheral UUID (a UUID string like `243E23AE-4A99-406C-B317-18F1BD7B4CBE`), NOT a Bluetooth MAC address. CoreBluetooth does not expose MAC addresses. The UUID is machine-specific — it changes between Macs. [VERIFIED: bleak.readthedocs.io/en/latest/backends/macos.html]

### Pattern 2: Confirmed-Write Bonding

**What:** Issue `write_gatt_char(..., response=True)` on the cmd-in characteristic immediately after connection. This sends an ATT Write Request (not a Write Command), which — if the characteristic requires encryption — triggers CoreBluetooth to initiate "just-works" bonding automatically. No `client.pair()` call is needed or possible.

**When to use:** First bonding attempt on fresh state (after Forget Device on iPhone). This is the confirmed-working 4.0 mechanism.

```python
# Source: re/bond_attempt.py (project, 4.0 production) + bleak CoreBluetooth docs
import asyncio
from bleak import BleakClient, BleakScanner
from device_local_5 import DEVICE_UUID as ADDR

# 5.0 cmd-in UUID (replace …0002 fragment once confirmed via nRF Connect)
CMD_IN_5 = "fd4b0002-XXXX-XXXX-XXXX-XXXXXXXXXXXX"  # fill from nRF Connect survey

async def bond_and_test():
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    async with BleakClient(dev) as client:
        # Attempt 1: explicit pair (will raise NotImplementedError on macOS — expected)
        try:
            await client.pair()
        except NotImplementedError:
            pass  # expected on macOS — CoreBluetooth auto-bonds on first auth'd access

        # Subscribe to response channels first so we hear the bond event
        await client.start_notify(CMD_RESP_5, lambda _, d: print(f"cmd_resp: {d.hex()}"))
        await client.start_notify(EVENTS_5,   lambda _, d: print(f"events:   {d.hex()}"))

        # The bonding trigger: confirmed write (ATT Write Request) on cmd-in
        # If the characteristic requires encryption, CoreBluetooth initiates bonding here.
        # On success: 4.0 sends BLE_BONDED event on the events characteristic.
        try:
            await client.write_gatt_char(CMD_IN_5, b"\x00", response=True)
            print("confirmed write sent — watch for pairing dialog / BLE_BONDED event")
        except Exception as e:
            print(f"write failed: {e}")
        await asyncio.sleep(5)

asyncio.run(bond_and_test())
```

**Key gotchas:**
- `client.pair()` raises `NotImplementedError` on macOS CoreBluetooth — this is expected and documented. [VERIFIED: bleak.readthedocs.io/en/latest/backends/macos.html]
- The confirmed write must use `response=True` (ATT Write Request with acknowledgment). `response=False` is a Write Command and does NOT trigger encryption negotiation.
- If the strap is already bonded from a previous session, the write succeeds silently with no dialog — which is also a success state.
- After "Forget Device" on iPhone, the Mac's existing bond to the strap may also need to be removed via macOS System Settings → Bluetooth (hold Option key to see "Remove" for non-visible devices).

### Pattern 3: Standard HR Notification Subscription

**What:** Subscribe to 0x2A37 (Heart Rate Measurement) notification. Parsing already implemented in `re/standard_ble.py` and `re/re_harness.py` — reuse directly.

```python
# Source: re/standard_ble.py (project, 4.0 production)
HR_MEAS = "00002a37-0000-1000-8000-00805f9b34fb"
BATTERY = "00002a19-0000-1000-8000-00805f9b34fb"

def parse_hr(data: bytearray):
    """Standard GATT 0x2A37 Heart Rate Measurement parse."""
    flags = data[0]
    hr_16bit = flags & 0x01
    idx = 1
    hr = int.from_bytes(data[idx:idx+2], "little") if hr_16bit else data[idx]
    idx += 2 if hr_16bit else 1
    rrs = []
    if (flags >> 4) & 0x01:
        while idx + 2 <= len(data):
            rrs.append(round(int.from_bytes(data[idx:idx+2], "little") / 1024 * 1000, 1))
            idx += 2
    return hr, rrs

# Standard battery: single byte, 0–100%
async def read_battery(client):
    data = await client.read_gatt_char(BATTERY)
    return int(data[0])
```

**HR format (0x2A37):** Flags byte controls field presence. Bit 0: HR field size (0=uint8, 1=uint16). Bit 4: RR interval present. RR values are in units of 1/1024 second → multiply by 1000/1024 to get milliseconds. [ASSUMED — standard GATT spec; parsing already validated on WHOOP 4.0 in production]

**Battery format (0x2A19):** Single `uint8` byte, value is battery percentage 0–100. Read (not notify) is standard; some devices also support notification. [ASSUMED — standard GATT spec]

**Standard characteristics work unbonded on WHOOP 4.0** — HR reads 0 when off-wrist/charging but subscription still succeeds. Same behavior expected on 5.0. [VERIFIED: FINDINGS.md §1 + re/standard_ble.py]

### Pattern 4: Handle → UUID Resolution

**What:** Phase 1 captured handles 0x099b (cmd-in write), 0x099d and 0x09a3 (notifications) but did not capture the GATT Primary Service Discovery responses that would name the containing service and characteristic UUIDs. The nRF Connect enumeration in task 1 will expose the UUID table; the Bleak enumeration will show `char.handle == 0x099b` → `char.uuid`.

**Implementation:** After connecting with Bleak, iterate `client.services` and for each characteristic check `char.handle`. The handle is an integer; compare to `0x099b`, `0x099d`, `0x09a3`.

```python
# Source: bleak.backends.service.py BleakGATTCharacteristic.handle property
for service in client.services:
    for char in service.characteristics:
        if char.handle in (0x099b, 0x099d, 0x09a3):
            print(f"Handle 0x{char.handle:04x} → UUID {char.uuid}  service {service.uuid}")
```

### Anti-Patterns to Avoid

- **Using `client.pair()` on macOS:** Raises `NotImplementedError`. Use confirmed write instead. [VERIFIED: bleak.readthedocs.io]
- **Passing MAC address to `find_device_by_address` on macOS:** CoreBluetooth does not use MAC addresses; only CoreBluetooth UUIDs work. The UUID is obtained from a prior scan. [VERIFIED: bleak.readthedocs.io/en/latest/backends/macos.html]
- **`response=False` as the bonding trigger:** Write-without-response (ATT Write Command) does not require acknowledgment and does NOT trigger encryption negotiation. Must use `response=True`.
- **Scanning with `scanning_mode="passive"` on macOS:** Not supported; raises `BleakError`. Active scanning is the only option on macOS. [VERIFIED: bleak.readthedocs.io/en/latest/backends/macos.html]
- **Committing `device_local_5.py`:** The real device identity file (BLE UUID, MAC, serial) must remain gitignored per the established project pattern.
- **Committing raw `.pklg` captures:** D-02 policy: only redacted hex + SHA256 + metadata YAML under `re/capture/evidence/`. Raw files stay under `re/capture/samples/` which is gitignored.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BLE notification subscription | Custom GATT notification loop | `client.start_notify()` | Handles ATT notification/indication protocol, CCCDs, and reconnection |
| HR byte parsing | Custom bitfield parser | `re/standard_ble.py parse_hr()` | Already implemented, validated on WHOOP 4.0 |
| GATT service collection | Custom UUID-to-handle mapping | `client.services` BleakGATTServiceCollection | Bleak handles service discovery and caches the full GATT table |
| SMP packet capture | Custom HCI tap | PacketLogger + `tshark -Y btsmp` | PacketLogger already set up in Phase 1; tshark `btsmp` dissector is verified working |
| WHOOP frame parsing | New parser | `whoomp/scripts/packet.py WhoopPacket` | Already validated on 4.0; 5.0 inner framing confirmed same (0xAA SOF) |

**Key insight:** Phase 2 is almost entirely a wiring exercise, not new code. The 4.0 scripts (`gatt_dump.py`, `bond_attempt.py`, `standard_ble.py`, `re_harness.py`) are the template — the only changes are UUID constants, the device_local import path, and the output file path.

---

## Standard GATT Profiles (0x2A37 and 0x2A19)

### Heart Rate Measurement (UUID 0x2A37, Service 0x180D)

Format (variable length, flags byte controls layout):
```
Byte 0:  Flags
         Bit 0: HR Value Format (0 = uint8, 1 = uint16)
         Bit 3: Sensor Contact (2 bits)
         Bit 4: Energy Expended present
         Bit 4: RR-Interval present (bit 4 is dual-purpose in spec — check carefully)
Bytes 1–N: Heart rate value (uint8 or uint16 LE per flag)
Bytes N–M: RR intervals (uint16 LE each, units: 1/1024 second)
```

RR unit conversion: `rr_ms = rr_raw * 1000 / 1024`

The parser in `re/standard_ble.py` is correct and handles both 8-bit and 16-bit HR values. Reuse it verbatim. [ASSUMED — standard GATT spec; validated on WHOOP 4.0]

### Battery Level (UUID 0x2A19, Service 0x180F)

Format: single `uint8`, value 0–100 (percentage). Read via `read_gatt_char`. Some devices also support notification — check characteristic properties during GATT enumeration. [ASSUMED — standard GATT spec]

### Device Information (UUID 0x180A)

Optional — manufacturer string at 0x2A29, model at 0x2A24. Useful for confirming "WHOOP Inc." as manufacturer in FINDINGS_5.md.

---

## SMP Capture and Filter Reference (Bonding Fallback)

If the confirmed-write trick does NOT trigger bonding on 5.0, the fallback is:
1. Re-pair WHOOP with official app (Forget Device → re-pair via official app)
2. Run PacketLogger per `re/capture/ios-packetlogger.md` during a fresh pairing session
3. Extract SMP frames from the capture

### tshark SMP filter (confirmed working on this machine — tshark 4.6.6 installed):

```bash
# Show all BT SMP (Security Manager Protocol) frames — the bonding handshake
tshark -r re/capture/samples/<session>.pklg -Y btsmp

# Show SMP opcodes (pairing request=0x01, response=0x02, confirm=0x03, random=0x04, etc.)
tshark -r re/capture/samples/<session>.pklg -Y btsmp \
  -T fields -e btsmp.opcode -e frame.time_relative

# Show full SMP decode with verbose
tshark -r re/capture/samples/<session>.pklg -Y btsmp -V | head -80
```

[VERIFIED: tshark -G protocols confirms `btsmp` = "Bluetooth Security Manager Protocol"; tshark -G fields confirms `btsmp.opcode`, `btsmp.sc_flag`, `btsmp.bonding_flags` fields]

### SMP LE Secure Connections handshake sequence (Just Works):

| Phase | SMP Opcode | Direction | What it contains |
|-------|-----------|-----------|-----------------|
| Pairing Request | 0x01 | Central → Peripheral | IO Capability, OOB flag, AuthReq (bonding + SC flags), key distribution |
| Pairing Response | 0x02 | Peripheral → Central | Same fields from peripheral |
| Public Key | 0x0C | Both directions | ECDH public keys (LE SC) |
| DHKey Check | 0x0D | Both directions | Confirmation of DHKey |
| (Key distribution) | 0x06–0x09 | Both | LTK, IRK, CSRK distribution |

For PacketLogger evidence, the SMP frames appear BEFORE ATT traffic can flow (encryption must be established first). **Scrub all LTK/IRK/CSRK bytes from committed `.hex` files** (DISCLAIMER §2 + evidence policy).

---

## Handle → UUID Resolution Strategy

Phase 1 evidence established:
- Handle `0x099b` → cmd-in write (ATT Write Request by WHOOP app)
- Handle `0x099d` → notification source (ATT Handle Value Notification)
- Handle `0x09a3` → notification source (ATT Handle Value Notification)

These handles are **sequential within a GATT service** — the service's primary service declaration will be at a handle below 0x099b, and the two notification handles (0x099d, 0x09a3) are likely cmd-resp and events (0x0002 and 0x0004 offsets).

Expected mapping (to confirm via nRF Connect, do NOT use these as facts):
```
0x0998 or nearby  — Primary Service Declaration (fd4b0001-…)
0x099b            — cmd-in  characteristic (fd4b0002-…)  [ASSUMED]
0x099d            — cmd-resp characteristic (fd4b0003-…)  [ASSUMED]
0x09a3            — events characteristic (fd4b0004-…)   [ASSUMED]
                    (gap likely for data 0005 and diagnostics 0007)
```

The nRF Connect GATT browser will show handles alongside UUIDs — this is the ground-truth mapping that closes the Phase 1 loop.

---

## FINDINGS_5.md Structure

`FINDINGS_5.md` is the primary committed artifact for Phases 2–4. It mirrors `FINDINGS.md` in structure. Recommended sections for the Phase 2 bootstrap:

```markdown
# WHOOP 5.0 BLE Protocol — Reverse-Engineering Findings

_Last updated: YYYY-MM-DD. Target: WHOOP 5.0 (serial XXXX, macOS BLE UUID XXXX)._

## Status at a glance
[table: capability → status]

## 1. GATT Map (confirmed Phase 2)
[service UUID, characteristic UUIDs, handle map, properties]

## 2. Legacy UUID Verdict
[present / absent — one-line verdict + nRF Connect observation date]

## 3. Bonding
[confirmed-write outcome, or SMP capture fallback result]

## 4. Standard Characteristics
[HR subscription: yes/no, sample BPM; battery read: yes/no, sample %]

## 5. Handle → UUID Map (closes Phase 1 loop)
[handle 0x099b → uuid, etc.]

## 6. Open Questions / Phase 3 inputs
[anything needed for framing confirmation]
```

Phases 3–4 extend with: framing confirmation, CRC gate result, command surface, decoded streams.

---

## Evidence Policy (D-02, Phase 2 application)

Phase 1 established the evidence pattern. Phase 2 applies it to GATT survey artifacts:

| Artifact type | Commit? | Location | Format |
|---------------|---------|----------|--------|
| Raw `.pklg` capture (if bonding fallback used) | NO | `re/capture/samples/` (gitignored) | .pklg |
| SHA256 of raw capture | YES | `re/capture/evidence/YYYY-MM-DD-gatt-5.sha256` | sha256sum output |
| tshark ATT/SMP excerpt (scrubbed) | YES | `re/capture/evidence/YYYY-MM-DD-gatt-5.hex` | tshark -x output, BD_ADDR + LTK scrubbed |
| Metadata sidecar | YES | `re/capture/evidence/YYYY-MM-DD-gatt-5.meta.yaml` | YAML with UUID list, handle map, verdict |
| nRF Connect screenshots | NO | Local only | Contains device identifiers |
| `FINDINGS_5.md` | YES | repo root | Markdown, no raw identifiers |
| `re/survey_5/device_local_5.py` | NO | gitignored | Real BLE UUID/MAC/serial |
| `re/survey_5/device_local_5.example.py` | YES | committed | Placeholder values only |

**Scrubbing before commit (DISCLAIMER §2):** Remove BD_ADDR (6-byte MAC), LTK, IRK, CSRK from any `.hex` files. Device serial embedded in ATT payloads (e.g., in a GET_HELLO_HARVARD response) must be replaced with `[REDACTED]`.

---

## Common Pitfalls

### Pitfall 1: Connecting While Official App Is Open

**What goes wrong:** Two BLE centrals cannot connect to the same peripheral simultaneously. If the official WHOOP app holds the connection, nRF Connect or Bleak will see the device advertising but fail to connect (connection request times out or is rejected).

**Why it happens:** The WHOOP strap accepts only one central at a time. The official app maintains a persistent connection.

**How to avoid:** Force-quit the official WHOOP app on iPhone before connecting with nRF Connect or running Bleak scripts. On iPhone: swipe up in App Switcher → swipe away the WHOOP app card.

**Warning signs:** nRF Connect sees the device in scan but "Connect" spinner never resolves; Bleak `find_device_by_address` finds the device but `BleakClient` context manager raises connection timeout.

### Pitfall 2: Bonding State Mismatch After "Forget Device"

**What goes wrong:** "Forget Device" on iPhone removes the iPhone's bond. But the Mac may still have an active bond to the strap (from prior `bond_5.py` runs), and the strap's own bond database still has the iPhone's LTK. This can cause the strap to reject the Mac's encrypted connection attempts (or the Mac's attempts to re-bond) because it still thinks it is bonded.

**Why it happens:** BLE bonding is per-device, per-central. Each central (iPhone, Mac) has a separate bond entry on the strap. Forgetting on one device does not forget on others.

**How to avoid:** After "Forget Device" on iPhone, also remove the strap from macOS System Settings → Bluetooth (may need to hold Option key to see the "Remove" option for a device not currently advertising in Apple's list). If the Mac shows the strap as "Not Connected" under Bluetooth → use the Option+click approach to fully remove the bond entry.

**Warning signs:** Bleak connects but confirmed write immediately raises an error ("Insufficient Encryption" or "Insufficient Authentication" in the error string), rather than triggering a bonding dialog.

### Pitfall 3: macOS Peripheral UUID Changes After System Events

**What goes wrong:** The CoreBluetooth peripheral UUID stored in `device_local_5.py` becomes invalid after macOS Bluetooth stack resets (e.g., after toggling Bluetooth off/on, or after OS update).

**Why it happens:** CoreBluetooth assigns UUIDs to peripherals per-session. The UUID is cached and usually stable, but can change.

**How to avoid:** If `BleakScanner.find_device_by_address(UUID)` returns `None` after previously working, scan without address filter and match by device name (`dev.name.startswith("WHOOP")`), then update `device_local_5.py` with the new UUID.

**Warning signs:** `find_device_by_address` consistently returns `None` even when the strap is on and advertising.

### Pitfall 4: GATT Discovery Returns No Custom Service (Bond Required)

**What goes wrong:** Bleak connects and `client.services` shows only the standard services (HR, Battery, Device Info) — no custom `fd4b0001-…` service.

**Why it happens:** On some BLE devices, the custom GATT service is only visible after the link is encrypted (bonded). Before bonding, the service may exist but return "Insufficient Authentication" on discovery, causing Bleak to silently exclude it from `client.services`.

**How to avoid:** If nRF Connect (after bonding via the official app or confirmed-write) shows the custom service but Bleak does not, run `bond_5.py` first, then run `survey_gatt_5.py` in the same session while still connected.

**Warning signs:** `client.services` iteration yields only 0x180D/0x180F/0x180A; no `fd4b0001-…` service appears.

### Pitfall 5: Forgetting to Scrub BD_ADDR from SMP Evidence

**What goes wrong:** A committed `.hex` file contains raw Bluetooth device MAC addresses (6-byte sequences) from SMP pairing frames, or LTK bytes from key distribution.

**Why it happens:** tshark's `-x` hex dump shows the full frame payload, which includes identifying material during bonding. The `btatt` filter already strips most identifying material, but `btsmp` frames contain BD_ADDR and key material explicitly.

**How to avoid:** Per D-02 policy: after running `tshark -x`, manually open the `.hex` file and replace any 6-byte BD_ADDR sequences with `XX:XX:XX:XX:XX:XX`, and remove any LTK/IRK/CSRK key distribution frames entirely.

**Warning signs:** `grep -i "bd_addr\|long_term_key\|identity_resolving_key" evidence/*.hex` returns matches.

### Pitfall 6: Python Version < 3.10 for Bleak 3.x

**What goes wrong:** `pip install bleak` in the system Python 3.9.6 (`/usr/bin/python3`) fails or installs an older version (bleak ≤ 0.22.x for Python 3.8/3.9 compat).

**Why it happens:** bleak 3.0.x requires Python ≥ 3.10. The system Python on macOS is 3.9.6 (Xcode-bundled).

**How to avoid:** Create the `re/survey_5/.venv` using a Homebrew Python 3.11+: `python3.11 -m venv re/survey_5/.venv` (after `brew install python@3.11` if needed).

**Warning signs:** `pip install "bleak==3.0.2"` raises "Requires-Python >=3.10" error; or bleak 0.x is silently installed.

---

## Code Examples

### Full GATT Dump (survey_gatt_5.py skeleton)

```python
# Source: re/gatt_dump.py (project, 4.0 production) adapted for 5.0
"""Enumerate the WHOOP 5.0 GATT table — run AFTER nRF Connect visual survey."""
import asyncio
import json
from bleak import BleakClient, BleakScanner
from device_local_5 import DEVICE_UUID as ADDR

PHASE1_HANDLES = {0x099b, 0x099d, 0x09a3}  # from Phase 1 evidence

async def main():
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("device not found — is it awake and in range?"); return
    print(f"found: {dev.name} ({dev.address})")

    result = {"device": dev.name, "address": str(dev.address), "services": []}

    async with BleakClient(dev) as client:
        for service in client.services:
            svc = {"uuid": service.uuid, "handle": service.handle,
                   "description": service.description, "characteristics": []}
            for char in service.characteristics:
                flag = "<<< PHASE1 MATCH" if char.handle in PHASE1_HANDLES else ""
                print(f"  [0x{char.handle:04x}] {char.uuid}  {','.join(char.properties)} {flag}")
                svc["characteristics"].append({
                    "uuid": char.uuid, "handle": char.handle,
                    "properties": list(char.properties),
                    "descriptors": [{"uuid": d.uuid, "handle": d.handle}
                                    for d in char.descriptors]
                })
            result["services"].append(svc)

    with open("re/survey_5/gatt_dump_5.json", "w") as f:
        json.dump(result, f, indent=2)
    print("\ngatt_dump_5.json written")

asyncio.run(main())
```

### Bond Script (bond_5.py skeleton)

```python
# Source: re/bond_attempt.py (project, 4.0 production) adapted for 5.0
"""Bond to WHOOP 5.0 via confirmed-write trick. Run after Forget Device on iPhone."""
import asyncio
import time
from bleak import BleakClient, BleakScanner
from device_local_5 import DEVICE_UUID as ADDR

# Fill these from nRF Connect survey (task 1)
CMD_IN_5   = "fd4b0002-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
CMD_RESP_5 = "fd4b0003-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
EVENTS_5   = "fd4b0004-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

t0 = time.time()

async def main():
    dev = await BleakScanner.find_device_by_address(ADDR, timeout=15.0)
    if dev is None:
        print("not found"); return

    async with BleakClient(dev) as client:
        print(f"connected: {client.is_connected}")

        await client.start_notify(CMD_RESP_5,
            lambda _, d: print(f"[{time.time()-t0:.1f}s] cmd_resp: {d.hex()}"))
        await client.start_notify(EVENTS_5,
            lambda _, d: print(f"[{time.time()-t0:.1f}s] events:   {d.hex()}"))

        # THE bonding trigger — confirmed write on cmd-in
        print("sending confirmed write (bonding trigger)...")
        try:
            await client.write_gatt_char(CMD_IN_5, b"\x00", response=True)
            print("write acknowledged — bonding may have occurred")
        except Exception as e:
            print(f"write error: {e}  (check if bond already existed)")

        await asyncio.sleep(5)
        print("done")

asyncio.run(main())
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `client.pair()` for bonding on macOS | Confirmed write (`response=True`) on auth'd characteristic | Always was this way on CoreBluetooth | `pair()` still raises `NotImplementedError` on macOS in bleak 3.x |
| bleak 0.x `get_services()` coroutine | `client.services` property (available after connect) | bleak 1.0+ | `get_services()` is removed in bleak 3.x; use `client.services` directly |
| `write_gatt_char(data, True)` (positional bool) | `write_gatt_char(data, response=True)` (keyword arg) | bleak 2.x → 3.x | Passing `response` positionally is deprecated; use keyword |
| `start_notify(char, callback)` where callback takes `(sender, data)` | Callback signature unchanged but `sender` is now `BleakGATTCharacteristic` not a handle int | bleak 1.0 | Update any code that uses `sender` as an int handle |

**Deprecated/outdated:**
- `get_services()` async method: Removed in bleak 3.x. Use `client.services` property.
- Passing `response=` as positional argument to `write_gatt_char`: Deprecated, keyword-only in 3.x.
- `client.pair(protection_level=...)`: Never existed on macOS; Windows-only kwarg deprecated in 3.x.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 5.0 cmd-in UUID follows the fd4b0002-… pattern (…0001 is service, …0002 is cmd-in, etc.) | Handle → UUID Resolution | Low — handle 0x099b confirmed as write target in Phase 1; UUID suffix will be confirmed by nRF Connect in task 1 |
| A2 | Legacy 61080001-… UUID is absent on this specific 5.0 unit (Phase 1 showed fd4b0001-… handles) | Architecture Patterns | Medium — if present, Phase 3 code needs to handle both UUID families; requires explicit nRF Connect check |
| A3 | HR characteristic (0x2A37) works unbonded on 5.0 (same as 4.0) | Standard GATT Profiles | Low — standard GATT profiles are not restricted by BLE spec; strong precedent from 4.0 |
| A4 | Battery characteristic (0x2A19) is readable via simple `read_gatt_char` (not notify-only) | Standard GATT Profiles | Low — standard GATT Battery Service mandates read property |
| A5 | HR/battery characteristics are readable in single uint8/HR-flags format per standard GATT spec | Standard GATT Profiles | Low — validated on 4.0; re/standard_ble.py parser works |
| A6 | The confirmed-write trick on cmd-in triggers bonding on 5.0 (same as 4.0) | Pattern 2 | Medium — 4.0 inner framing reuse suggests same auth model, but 5.0 could use different security level or IO capabilities; fallback (PacketLogger SMP capture) is documented |
| A7 | macOS CoreBluetooth UUID for the 5.0 strap has not changed since the Phase 1 capture was made | Standard Stack | Low — stable within a session; may change after Bluetooth toggle; handled in device_local_5.py update note |

**If table A2 or A6 assumptions are wrong**, the plan must include a fallback branch. A2 is resolved by nRF Connect scan (first task). A6 is resolved by running `bond_5.py` and observing the outcome.

---

## Open Questions

1. **Full 5.0 UUID suffix (after `fd4b0001-`)**
   - What we know: Phase 1 confirmed `fd4b0001-…` prefix (via WHOOP strap advertisement). The full 128-bit UUIDs are not captured.
   - What's unclear: Are the remaining 96 bits identical to the 4.0 service (`8d6d-82b8-614a-1c8cb0f8dcc6`)? Or different?
   - Recommendation: nRF Connect enumeration in task 1 is the definitive answer. Do not assume 4.0 suffix. Record full 128-bit UUIDs in FINDINGS_5.md.

2. **diagnostics / memfault characteristic (fd4b0007-…)**
   - What we know: 4.0 has `61080007-…` for memfault/diagnostics. Phase 1 handles do not show a write to 0x09a3 as cmd-in-type; it may be the second notification (events or diagnostics).
   - What's unclear: Is `…0007` present on 5.0? Phase 1 captured only three handles.
   - Recommendation: nRF Connect shows all characteristics — record presence/absence of all seven expected characteristics.

3. **Bond state after Forget Device — Mac-side cleanup**
   - What we know: Forgetting on iPhone removes iPhone bond. Mac may hold a separate bond.
   - What's unclear: Does the Mac's existing bond entry prevent fresh bonding via `bond_5.py`?
   - Recommendation: Include explicit Mac-side bond removal step (System Settings → Bluetooth → Option+click device → Remove) before running `bond_5.py`. Document outcome.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.10+ | bleak 3.0.2 venv | PARTIAL — system Python is 3.9.6; Homebrew python3.11 may be available | 3.9.6 (system) | `brew install python@3.11` then `python3.11 -m venv` |
| bleak 3.0.2 | survey_gatt_5.py, bond_5.py, hr_5.py | NOT YET — venv not created | — | `pip install bleak==3.0.2` into re/survey_5/.venv |
| tshark 4.6.6 | SMP capture analysis (bonding fallback) | YES | 4.6.6 | — |
| PacketLogger | SMP capture (bonding fallback) | YES (Phase 1 verified) | from Additional Tools for Xcode | — |
| nRF Connect iOS app | GATT enumeration | ASSUMED YES (free App Store) | current | LightBlue as alternative |
| WHOOP 5.0 strap (physical) | All tasks | YES (user's device) | — | — |
| iPhone with WHOOP paired | nRF Connect enumeration | YES | iOS 26.3.1 (from Phase 1 meta.yaml) | — |

**Missing dependencies requiring setup before execution:**
- Python 3.10+: `brew install python@3.11` (if not already installed via Homebrew)
- bleak 3.0.2 venv: `python3.11 -m venv re/survey_5/.venv && source re/survey_5/.venv/bin/activate && pip install bleak==3.0.2`

**Missing dependencies with fallback:**
- nRF Connect (if not installed): LightBlue Explorer (free on App Store) also shows UUIDs and handles, though nRF Connect is preferred for handle visibility.

---

## Validation Architecture

> `workflow.nyquist_validation` is `false` in `.planning/config.json` — test section OMITTED per config.

---

## Security Domain

> No security enforcement configuration found — standard security notes follow.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — (no user auth in RE scripts) |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | Partial | BLE notification data is untrusted input — validate lengths before indexing (parse_hr already does this) |
| V6 Cryptography | No | — (BLE bonding handled by OS) |

### Known Threat Patterns (BLE RE context)

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Device identifier in committed files | Information Disclosure | gitignore device_local_5.py; scrub BD_ADDR from hex evidence |
| LTK/IRK/CSRK in committed SMP evidence | Information Disclosure | Scrub key material from .hex before commit (DISCLAIMER §2 + D-02) |
| Out-of-bounds read in HR/battery parser | Tampering | Check `len(data)` before indexing; existing parse_hr already guards this |

---

## Sources

### Primary (HIGH confidence)
- [bleak.readthedocs.io/en/latest/api/client.html] — BleakClient.write_gatt_char, start_notify, pair() NotImplementedError on macOS
- [bleak.readthedocs.io/en/latest/backends/macos.html] — CoreBluetooth UUID vs MAC addressing, passive scan unsupported, auto-bonding behavior
- [pypi.org/pypi/bleak/json] — bleak 3.0.2, Python >=3.10 requirement, macOS dependencies (pyobjc-core/framework-corebluetooth >=10.3)
- [github.com/hbldh/bleak CHANGELOG.rst] — pair() history, CoreBluetooth memory leak fix in 3.0.0, BleakGATTProtocolError in 3.0.0
- [github.com/hbldh/bleak/blob/master/bleak/backends/corebluetooth/client.py] — write_gatt_char CBCharacteristicWriteWithResponse vs WriteWithoutResponse, pair() NotImplementedError
- `re/bond_attempt.py` (project) — confirmed-write bonding pattern, working on WHOOP 4.0
- `re/gatt_dump.py` (project) — GATT enumeration pattern with `client.services` iteration
- `re/standard_ble.py` (project) — parse_hr(), battery read pattern, validated on WHOOP 4.0
- `FINDINGS.md` (project) — 4.0 GATT map (61080001-…), confirmed-write bonding mechanism, standard GATT services work unbonded
- `re/capture/evidence/2026-05-30-ios.meta.yaml` (project) — Phase 1 evidence: handles 0x099b/0x099d/0x09a3, 0xAA SOF confirmed
- `tshark -G protocols` / `tshark -G fields` (local) — `btsmp` protocol confirmed, `btsmp.opcode`, `btsmp.sc_flag`, `btsmp.long_term_key` fields confirmed

### Secondary (MEDIUM confidence)
- [pypistats.org/packages/bleak] — 376K+ weekly downloads, confirming bleak legitimacy (slopcheck false positive explanation)
- [pypi.org/project/bleak] — bleak 3.0.2 release date (2026-05-02), source at github.com/hbldh/bleak
- [github.com/hbldh/bleak/blob/master/bleak/backends/service.py] — BleakGATTServiceCollection, BleakGATTService class structure
- [github.com/hbldh/bleak/blob/master/bleak/backends/characteristic.py] — BleakGATTCharacteristic properties list (notify, write, read, etc.)
- [codeberg.org/Freeyourgadget/Gadgetbridge/issues/5731] — tazjin on WHOOP 5.0: "standard bonding", 4 active characteristics (commands to/from, events, data), no specific UUIDs disclosed
- [github.com/hbldh/bleak WebFetch service_explorer.py example] — `pair=True` BleakClient arg behavior on macOS

### Tertiary (LOW confidence / ASSUMED)
- Standard GATT 0x2A37 HR Measurement format — re/standard_ble.py parser validated on WHOOP 4.0 but spec details marked [ASSUMED] (Bluetooth SIG spec PDF not successfully fetched)
- Standard GATT 0x2A19 Battery Level format — single uint8, well-known but not verified against spec document in this session

---

## Metadata

**Confidence breakdown:**
- Standard stack (Bleak 3.0.2, macOS behavior): HIGH — verified via official docs and PyPI
- Confirmed-write bonding mechanism: HIGH for 4.0 (production code); MEDIUM for 5.0 extension (same inner framing but auth model unverified)
- GATT enumeration patterns: HIGH — Bleak API verified, existing project code validated
- SMP filter syntax (btsmp): HIGH — verified via local tshark -G commands
- Standard GATT HR/battery parsing: HIGH for implementation (production code); ASSUMED for spec details
- 5.0 UUID specifics: LOW — Phase 1 only captured handles, not UUIDs; UUIDs are the primary unknown this phase resolves

**Research date:** 2026-05-30
**Valid until:** 2026-08-30 (bleak API is stable; check CHANGELOG if bleak is upgraded beyond 3.0.2)
