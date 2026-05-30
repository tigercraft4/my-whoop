# Wireshark / tshark Runbook — TOOL-04

**Version:** 1.0 — 2026-05-30
**Requirement:** TOOL-04 (open `.pklg`/`.btsnoop`, filter ATT/GATT, locate WHOOP custom service)
**Policy:** D-02 (raw captures gitignored; only redacted hex + SHA256 + metadata committed)

---

## Overview

This runbook describes how to open a raw BLE capture (`.pklg` from iOS PacketLogger or
`.btsnoop` from Android HCI logging), filter down to the ATT/GATT layer where WHOOP custom
service traffic lives, verify you have real non-empty WHOOP frames, and produce the committed
redacted evidence artifacts mandated by D-02.

The 4.0 WHOOP custom service uses UUID prefix `61080001-...`; the 5.0 prefix appears to be
`fd4b0001-...` (confirm in Phase 2). Both should be visible as GATT service UUIDs in the
capture — this runbook shows you how to find them.

---

## Prerequisites

1. **Wireshark + tshark installed** — run `brew bundle --file=Brewfile` from the repo root,
   then `bash scripts/check-tools.sh` (must print all `ok` lines, no `FAIL`).
   - Expected: Wireshark/tshark `>= 4.4.0` (brew delivers 4.6.6).

   > **Assumption A6:** The display filter names `btatt` and `btl2cap.cid == 0x0004` are
   > documented as valid in Wireshark 4.6.6. If you encounter a filter error in the GUI,
   > confirm the exact syntax under **Help > Supported Protocols** or via
   > `tshark -G fields | grep -i btatt`.

2. **A raw capture under `re/capture/samples/`** — see `ios-packetlogger.md` (produces `.pklg`)
   or `android-btsnoop.md` (produces `.btsnoop`). The file must contain a real WHOOP app session
   (not just device discovery).

3. **Evidence output directory exists** — `re/capture/evidence/` (tracked by git via
   `.gitkeep`; contents are committed).

---

## Steps

### Step 1 — Open the capture in Wireshark GUI

```
File > Open...
```

Navigate to `re/capture/samples/<session-name>.pklg` or
`re/capture/samples/<session-name>.btsnoop`.

Wireshark reads both formats natively. The packet list will show HCI events and ACL data
frames at this stage — you are looking at the full HCI stream before any display filter.

---

### Step 2 — Apply the ATT/GATT display filter

In the **Display Filter** bar at the top, enter either of the following filters and press Enter:

**All ATT operations (reads, writes, notifications):**
```
btatt
```

**ATT fixed channel only (more specific — isolates L2CAP ATT channel 0x0004):**
```
btl2cap.cid == 0x0004
```

The `btatt` filter is the recommended starting point. It shows all ATT PDUs: GATT Read/Write
requests, GATT Notification/Indication packets (where WHOOP custom service data arrives), and
ATT configuration (service/characteristic discovery).

If the packet list goes empty after applying the filter, see the **Troubleshooting** section.

---

### Step 3 — Headless verification with tshark (prove non-empty WHOOP traffic)

> **"Tool launches" is not enough.** Success requires seeing actual ATT-layer WHOOP frames.
> Run this command to prove the capture contains real data:

```bash
tshark -r re/capture/samples/<session>.pklg \
  -Y btatt \
  -T fields \
  -e btatt.handle \
  -e btatt.value \
  | head -40
```

Replace `.pklg` with `.btsnoop` for an Android capture. A **successful** run prints one line
per ATT frame with its handle and value hex — you should see multiple non-empty lines.

If the output is empty, see **Troubleshooting — Empty trace**.

Record the frame count as a sanity check:
```bash
tshark -r re/capture/samples/<session>.pklg -Y btatt | wc -l
```

---

### Step 4 — Locate the WHOOP custom service UUID

WHOOP custom service traffic rides on ATT characteristics under the custom service. The service
UUID will appear during the GATT service discovery exchange at the start of a session.

Run a verbose dissect and grep for the known UUID fragments:

```bash
# Look for 5.0 prefix (fd4b0001-...) or 4.0 prefix (61080001-...) or shared fragment (8d6d):
tshark -r re/capture/samples/<session>.btsnoop \
  -Y "btatt" \
  -V \
  | grep -i -E "fd4b0001|61080001|8d6d" \
  | head -20
```

> **Phase 2 will confirm the UUID definitively.** For now, note which prefix appears (if any).
> If neither matches, use `tshark -Y btatt -V | grep -i "uuid"` to see all UUIDs in the
> service discovery exchange.

---

### Step 5 — Produce committed evidence (D-02 policy)

> **Policy:** Raw `.pklg`/`.btsnoop` are gitignored and **never committed**. Committed evidence
> consists of: (1) a SHA256 checksum, (2) a small redacted hex excerpt, (3) a metadata sidecar.
> All three go under `re/capture/evidence/` with the session name as the common prefix.

**5a — SHA256 checksum:**

```bash
sha256sum re/capture/samples/<session>.pklg \
  > re/capture/evidence/<session>.sha256
```

On macOS, use `shasum -a 256` if `sha256sum` is not available:

```bash
shasum -a 256 re/capture/samples/<session>.pklg \
  > re/capture/evidence/<session>.sha256
```

**5b — Redacted hex excerpt:**

Export a small slice of ATT-layer frames showing WHOOP service activity:

```bash
tshark -r re/capture/samples/<session>.pklg \
  -Y "btatt" \
  -x \
  | sed -n '1,40p' \
  > re/capture/evidence/<session>.hex
```

**BEFORE `git add`:** Manually open `re/capture/evidence/<session>.hex` and scrub any of the
following if they appear (DISCLAIMER §2):

- **BD_ADDR** (device Bluetooth MAC address — 6 bytes, e.g. `aa:bb:cc:dd:ee:ff`). Replace with
  `XX:XX:XX:XX:XX:XX`.
- **SMP key material** (LTK, IRK, CSRK — appear in pairing/bonding exchanges). Remove those
  frames entirely or replace the key bytes with `[REDACTED]`.
- **Device serial numbers or identifying strings** embedded in ATT payloads. Replace with
  `[REDACTED]`.

The WHOOP custom service UUID (`fd4b0001-...` / `61080001-...`), frame structure, and protocol
byte values are **uncopyrightable factual information** and may remain in the committed hex
(DISCLAIMER §2 — "Protocol facts ... are uncopyrightable factual information about how bytes
appear on a wire").

**5c — Metadata sidecar:**

Create `re/capture/evidence/<session>.meta.yaml`:

```yaml
# re/capture/evidence/<session>.meta.yaml
# Capture provenance sidecar. Raw capture gitignored; only this + .sha256 + .hex committed.
source: ios              # ios | android
tool: Wireshark          # analysis tool used to produce this evidence
tool_version: "4.6.6"   # tshark --version | head -1
firmware: "<from ideviceinfo FirmwareVersion or WHOOP app About>"
captured: 2026-05-30
raw_sha256: <paste SHA256 from <session>.sha256>
custom_service_uuid_seen: "fd4b0001-... | 61080001-... | none-yet"
btatt_frame_count: <count from Step 3 wc -l>
notes: "ATT/GATT traffic present; N WHOOP-service writes/notifies observed"
```

**5d — Commit the evidence artifacts:**

```bash
git add re/capture/evidence/<session>.sha256
git add re/capture/evidence/<session>.hex
git add re/capture/evidence/<session>.meta.yaml
git commit -m "evidence(capture): add <session> Wireshark ATT/GATT evidence"
```

Do **not** run `git add re/capture/samples/` — the `samples/` directory is gitignored.
Confirm with `git status`: the `.pklg`/`.btsnoop` must appear as **ignored**, not staged.

---

## How to Verify It Worked

Run the headless tshark check from Step 3. A working capture shows:

```
btatt.handle  btatt.value
0x0012        0a01...
0x0014        aa05000000...
...
```

Multiple non-empty output lines (handle + value hex) confirm real ATT-layer WHOOP traffic. If
`wc -l` returns `0`, see Troubleshooting.

---

## Troubleshooting

### Empty trace (zero btatt packets after filter)

**Likely causes:**

1. **Capture does not contain ATT traffic** — the session may have only HCI command/event
   frames without ACL data. Verify that the WHOOP app was actually running during capture and
   that the device paired/connected successfully.

2. **Filter syntax mismatch** — confirm the `btatt` display filter is recognised under
   **Analyze > Display Filters** in your installed Wireshark (Assumption A6). Try the alternative
   `btl2cap.cid == 0x0004` filter.

3. **PacketLogger / HCI snoop not enabled before session** — toggling the iOS mobileconfig or
   Android HCI snoop log *during* a session may miss early bonding traffic. See
   `ios-packetlogger.md` or `android-btsnoop.md` for the correct enable-before-session sequence.

4. **`.pklg` file empty or corrupt** — `ls -lh re/capture/samples/<session>.pklg` should show
   a non-zero file size (expect several MB for a 60-second WHOOP session).

### Wireshark opens file but shows Bluetooth Link Manager frames, no ATT

The capture may be a full HCI trace at the link layer. The `btatt` filter selects only ATT PDUs
carried in L2CAP ACL frames. Try `btl2cap` (without `cid` qualifier) to see all L2CAP frames
and confirm ACL data is present; then narrow to `btl2cap.cid == 0x0004`.

---

## Key Links

- `re/capture/ios-packetlogger.md` — produces `.pklg` input for this runbook
- `re/capture/android-btsnoop.md` — produces `.btsnoop` input for this runbook
- `re/capture/jadx.md` — JADX enum reference (TOOL-03); cross-reference ATT command bytes here
- `re/capture/evidence/` — all committed evidence artifacts live here
- `re/capture/samples/` — all raw captures live here (gitignored, never committed)
- `FINDINGS.md` — 4.0 protocol reference: frame format
  `[0xAA][len u16 LE][crc8][type][seq][cmd][payload][crc32 LE]` and GATT map
- `DISCLAIMER.md §2` — governs what may be committed (protocol facts) and what may not
  (decompiled source, raw binaries, credentials)
