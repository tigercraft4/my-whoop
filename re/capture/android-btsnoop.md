# Android HCI Snoop Runbook — TOOL-02

**Version:** 1.0 — 2026-05-30
**Requirement:** TOOL-02 (documented, reproducible Android HCI snoop capture + adb bugreport extraction)
**Policy:** D-02 (raw `.btsnoop` gitignored; only redacted hex + SHA256 + metadata committed)

---

## Overview

Android's "Bluetooth HCI snoop log" Developer Options setting enables on-device HCI logging —
recording all Bluetooth HCI traffic including the BLE sessions between the official WHOOP app
and the 5.0 strap. The log is extracted via `adb bugreport` (the reliable cross-OEM method) and
opened in Wireshark to verify non-empty WHOOP ATT-layer traffic.

This is the secondary capture path, complementing the primary iOS PacketLogger capture. It
provides an independent second reference that Phase 2 (GATT survey) and Phase 3 (framing
confirmation) can cross-reference.

> **Critical ordering constraint:** the HCI snoop log must be enabled **before** starting the
> WHOOP session. Toggling the Developer Options switch cycles the on-device ring buffer and
> discards any previously logged traffic. Enable it first, then run the session.

---

## Prerequisites

1. **Android device with Developer Options enabled** and the official WHOOP app installed.
2. **USB debugging enabled** on the Android device (Developer Options > USB debugging).
3. **`adb` installed on Mac:**
   ```bash
   brew bundle --file=Brewfile   # installs android-platform-tools (adb)
   bash scripts/check-tools.sh   # must show: ok   adb: <version> (>= 35.0.0)
   ```
4. **Mac trusts the Android device** over USB — accept the "Allow USB debugging?" dialog on the
   phone when first connecting.
5. **Physical WHOOP 5.0 strap** and the official WHOOP Android app installed.

---

## Step 1: Enable Bluetooth HCI Snoop Logging

> **Do this BEFORE starting any WHOOP session.** Toggling the switch cycles the buffer.

1. On the Android device, open **Settings > About Phone** and tap **Build Number** 7 times to
   unlock Developer Options (skip if already unlocked).
2. Go to **Settings > Developer Options** (location varies by OEM — on some devices it is under
   **Settings > System > Developer Options**).
3. Find **"Bluetooth HCI snoop log"** (also called "Enable Bluetooth HCI snoop log" or
   "Bluetooth packet log" on some OEM builds).
4. Toggle it **ON**.
5. If prompted, restart Bluetooth (toggle Bluetooth off and back on) — some devices require this
   to activate the new logging state.

> **[ASSUMED — A3] OEM path variation:** The exact path to the Developer Options setting and the
> label of the HCI snoop toggle vary by Android OEM and version. Confirm the exact location on
> your device. The setting and its effect (logging to `btsnoop_hci.log`) are standard Android
> AOSP features, but the menu path differs.

---

## Step 2: Run the WHOOP Session (Short Session)

> **Keep the session short — 3–5 minutes maximum.**

Android's HCI snoop buffer is size-capped on-device. A long session will roll over the buffer,
overwriting the earliest frames — including the initial connection and service discovery traffic
most useful for protocol analysis.

1. Open the official WHOOP Android app.
2. Let the app connect to the WHOOP 5.0 strap and begin streaming biometric data.
3. Run the session for **3–5 minutes** — enough to capture service discovery, characteristic
   reads/writes, and notification traffic, but short enough to avoid buffer rollover.
4. Close the WHOOP app (or disconnect) when done.

> **Warning signs of buffer rollover:** the extracted log starts mid-session with no connection
> setup frames, or `tshark -Y btatt` shows a sudden gap in packet sequence numbers.

---

## Step 3: Extract the HCI Snoop Log via `adb bugreport`

Connect the Android device to the Mac via USB and run:

```bash
# Confirm adb sees the device:
adb devices
# Expected: <serial>  device
# If "unauthorized": unlock the phone and accept the USB debugging dialog.

# Capture a bugreport (this takes 30–90 seconds):
adb bugreport re/capture/samples/bugreport-$(date +%Y-%m-%d).zip
```

> **Why `adb bugreport` and not a direct path pull?**
> On modern Android (9+), the HCI snoop log is not at a single accessible filesystem path due
> to scoped storage restrictions. `adb bugreport` packages the log into a zip archive at a known
> location inside the zip, regardless of OEM. This is the reliable, reproducible extraction
> method.

---

## Step 4: Locate and Extract the btsnoop Log from the Bugreport Zip

```bash
# List the zip contents and find the btsnoop log:
unzip -l re/capture/samples/bugreport-<date>.zip \
  | grep -i btsnoop

# Expected path inside the zip (AOSP default — OEM path may vary, see note below):
#   FS/data/misc/bluetooth/logs/btsnoop_hci.log

# Extract the log:
unzip re/capture/samples/bugreport-<date>.zip \
  "FS/data/misc/bluetooth/logs/btsnoop_hci.log" \
  -d re/capture/samples/bugreport-<date>-extracted/
```

> **[ASSUMED — A3] OEM path variation:** The path `FS/data/misc/bluetooth/logs/btsnoop_hci.log`
> is the AOSP default. On some OEM builds it may be at a different path within the zip (e.g.
> `FS/data/misc/bluetooth/logs/snoop_hci.log` or similar). If the `grep -i btsnoop` returns no
> results, try `grep -i snoop` or `grep -i bluetooth.*log` to locate the log file.

```bash
# Rename to .btsnoop and place in samples/:
cp re/capture/samples/bugreport-<date>-extracted/FS/data/misc/bluetooth/logs/btsnoop_hci.log \
   re/capture/samples/<date>-android-session<N>.btsnoop

# Confirm non-zero:
ls -lh re/capture/samples/<date>-android-session<N>.btsnoop
```

> **Raw captures are gitignored (D-02).** The `.btsnoop` file must stay under `re/capture/samples/`
> and never be committed. The bugreport zip and extracted directory are also gitignored.

---

## Step 5: Verify — Non-Empty WHOOP ATT Traffic

Open the capture in Wireshark per `wireshark.md` and confirm non-empty ATT-layer traffic:

```bash
# Quick headless check — must show non-empty output for a successful capture:
tshark -r re/capture/samples/<date>-android-session<N>.btsnoop -Y btatt | head

# Look for WHOOP custom service UUID:
tshark -r re/capture/samples/<date>-android-session<N>.btsnoop -Y "btatt" -V \
  | grep -i -E "fd4b0001|61080001|8d6d" | head
```

- **Expected:** Lines of ATT PDUs (Read/Write/Notify). The `grep` for `fd4b0001` or `61080001`
  should return matches if WHOOP custom service traffic is present.
- **If `tshark -Y btatt` is empty:** see Troubleshooting below.
- **For full Wireshark GUI analysis**, see `re/capture/wireshark.md`.

---

## Step 6: Produce Committed Evidence (D-02)

Raw captures stay local and gitignored. What you commit is a redacted evidence triplet:

```bash
# 1. SHA256 checksum of the raw capture:
sha256sum re/capture/samples/<date>-android-session<N>.btsnoop \
  > re/capture/evidence/<date>-android-session<N>.sha256

# 2. Redacted hex excerpt of WHOOP ATT-layer frames (first 40 lines):
#    IMPORTANT: review and scrub any BD_ADDR (device MAC) or SMP key material before commit.
tshark -r re/capture/samples/<date>-android-session<N>.btsnoop \
  -Y "btatt" -x | sed -n '1,40p' \
  > re/capture/evidence/<date>-android-session<N>.hex

# 3. Metadata sidecar (fill in your values):
cat > re/capture/evidence/<date>-android-session<N>.meta.yaml << 'EOF'
source: android
tool: android-hci-snoop
tool_version: "android-platform-tools adb <version>"
firmware: "<Android OS version from Settings > About Phone>"
device_model: "<device make and model>"
captured: <YYYY-MM-DD>
raw_sha256: <paste sha256 from the .sha256 file above>
custom_service_uuid_seen: "fd4b0001-... | 61080001-... | none-yet"
notes: "ATT/GATT traffic present; N WHOOP-service writes/notifies observed"
EOF
```

**Before `git add`:** Open the `.hex` file and manually verify it contains no raw BD_ADDR
octets or SMP pairing material. Scrub any such lines before committing.

```bash
# Confirm no raw capture is stage-able:
git status re/capture/samples/   # must show NOTHING (all gitignored)
git status re/capture/evidence/  # must show the three new evidence files
```

---

## Checklist

- [ ] HCI snoop log enabled in Developer Options BEFORE the session
- [ ] Session kept to 3–5 minutes (avoid buffer rollover)
- [ ] `adb bugreport` produced and saved to `re/capture/samples/` (gitignored)
- [ ] `btsnoop_hci.log` located in bugreport zip and renamed to `.btsnoop` in `samples/`
- [ ] `tshark -Y btatt | head` shows non-empty ATT output
- [ ] Evidence triplet committed: `.sha256`, `.hex` (scrubbed), `.meta.yaml`
- [ ] `git status re/capture/samples/` shows nothing stage-able (raw ignored)

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `tshark -Y btatt` returns zero rows | HCI snoop was toggled AFTER the session started | Re-enable HCI snoop (Step 1), reconnect WHOOP, run a new short session |
| `tshark -Y btatt` returns only HCI events, no ACL data | WHOOP app never connected over BLE during the session | Retry: ensure strap is nearby and awake; open WHOOP app and wait for connection indicator |
| btsnoop log missing from bugreport zip (`grep -i btsnoop` returns nothing) | OEM path differs; or HCI snoop was never enabled | Try `grep -i snoop`; confirm HCI snoop is ON in Developer Options |
| `btsnoop_hci.log` is very small (< 5 KB) | Session too short; or buffer was flushed before extraction | Run a longer WHOOP session; extract via `adb bugreport` immediately after session |
| `adb devices` shows "unauthorized" | USB debugging dialog not accepted on phone | Unlock phone; accept "Allow USB debugging?" dialog |
| `adb bugreport` fails or times out | adb not installed; or device not recognized | Run `bash scripts/check-tools.sh`; confirm adb >= 35.0.0 |
| Buffer rollover — log starts mid-session | Session was too long | Keep sessions to 3–5 minutes; extract immediately after (Step 3) |

---

## Related Runbooks

- `re/capture/wireshark.md` — open the `.btsnoop` in Wireshark/tshark, apply ATT/GATT filters,
  locate WHOOP service UUIDs, produce the committed evidence hex excerpt
- `re/capture/ios-packetlogger.md` — primary capture source (iOS PacketLogger with mobileconfig)
- `re/capture/README.md` — index of all four runbooks and the Phase 1 success-criterion evidence
  checklist
