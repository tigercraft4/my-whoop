# iOS PacketLogger Runbook — TOOL-01

**Version:** 1.0 — 2026-05-30
**Requirement:** TOOL-01 (capture live BLE traffic from WHOOP 5.0 with PacketLogger on Mac)
**Policy:** D-02 (raw `.pklg` gitignored; only redacted hex + SHA256 + metadata committed) | D-03 (irreducible manual step)

---

## Overview

PacketLogger is Apple's Bluetooth HCI frame logger. Tethered to an iPhone with the iOS Bluetooth
Logging profile installed, it captures the complete post-decryption HCI stream — including all
BLE traffic between the WHOOP app and the 5.0 strap. This is the primary capture path: no
jailbreak needed, full ATT/GATT payload visibility.

**Irreducible manual steps (D-03):** PacketLogger installation and the mobileconfig profile
install require Apple UI. Everything else in this runbook can be scripted or automated.

The 4.0 WHOOP custom service uses UUID prefix `61080001-...`; the 5.0 prefix is expected to be
`fd4b0001-...` (Phase 2 confirms). Both will appear as GATT service UUIDs in the capture.

---

## Prerequisites

1. **Mac with Xcode installed** — verify at `/Applications/Xcode.app`.
   Run `xcodebuild -version` to confirm Xcode is functional.
2. **PacketLogger.app installed** (manual — see Step 1 below).
   `bash scripts/check-tools.sh` will WARN (not FAIL) if PacketLogger is missing.
3. **iOS Bluetooth Logging mobileconfig installed on the iPhone** (manual — see Step 2 below).
4. **Toolchain installed:**
   ```bash
   brew bundle --file=Brewfile   # installs wireshark, libimobiledevice, etc.
   bash scripts/check-tools.sh   # must print ok for tshark, ideviceinfo
   ```
5. **Physical WHOOP 5.0 strap** and the official WHOOP app installed on the iPhone.
6. **USB cable** to tether iPhone to Mac.

---

## Step 1: Install PacketLogger (manual — Apple UI required)

> **[ASSUMED] Confirm at execution:** PacketLogger ships inside the "Additional Tools for Xcode"
> DMG, available from Apple Developer Downloads. The exact filename and DMG location may change
> with Xcode releases — verify the current URL and DMG name against the Apple Developer portal
> when you perform this step, and record the source URL in this doc.

1. Open [developer.apple.com/download/all](https://developer.apple.com/download/all) in a browser
   (Apple Developer account required).
2. Search for **"Additional Tools for Xcode"** and download the version that matches your
   installed Xcode major version.
3. Mount the downloaded DMG.
4. Locate `PacketLogger.app` inside the disk image (typically under `Hardware/` or at the root).
5. Drag `PacketLogger.app` to `/Applications/` (or `~/Applications/`).
6. Eject the DMG. Verify: `ls /Applications/PacketLogger.app` should succeed.

> **Record here after install:**
> - PacketLogger version (from About box): ___
> - Source DMG filename: ___
> - Download URL: ___

---

## Step 2: Install the iOS Bluetooth Logging Profile (manual — Apple UI required)

> **[ASSUMED — A1] Confirm at execution:** The iOS Bluetooth logging profile (`iOSBluetoothLogging.mobileconfig`)
> is an Apple-provided configuration profile. The exact filename, source URL, and installation
> method may change across iOS versions. Verify against Apple's current Bluetooth logging
> instructions at execution time and record the source URL below.

The profile enables on-device HCI logging that PacketLogger streams over USB.

1. Obtain the `iOSBluetoothLogging.mobileconfig` profile from Apple (typically distributed via
   Apple Developer resources or the Feedback Assistant — confirm the current source at execution).
2. Transfer the profile to the iPhone (AirDrop, email, or direct download on the device).
3. On the iPhone, go to **Settings > General > VPN & Device Management** (or **Profiles** on
   older iOS), tap the downloaded profile, tap **Install**, and enter your passcode.
4. Verify the profile is listed under Settings > General > VPN & Device Management.

> **Record here after install:**
> - Profile source URL: ___
> - iPhone iOS version: ___
> - Profile installation date: ___

---

## Step 3: Pair and Trust the iPhone in Xcode

1. Connect the iPhone to the Mac via USB.
2. Open Xcode and navigate to **Window > Devices and Simulators** (or press `⇧⌘2`).
3. Select your iPhone from the left sidebar.
4. If the device shows "Trust this computer?", unlock the iPhone and tap **Trust**.
5. Confirm the device status shows as **connected** (not "unpaired" or "locked").

> **Why this is required:** PacketLogger streams the HCI log over the Xcode device pairing
> channel. Without a trusted pairing, the iPhone's HCI log is not accessible to the Mac.

---

## Step 4: Launch PacketLogger and Start Capture

1. Open `PacketLogger.app` from `/Applications/`.
2. In the menu, select **File > New iOS Bluetooth Log…** (or the equivalent — UI may vary by version).
3. From the device list, select your iPhone.
4. Click **Start** (or the record button) to begin streaming the HCI log.
5. Verify the PacketLogger window shows an active live feed — you should see HCI event/command
   lines appearing as Bluetooth activity occurs on the iPhone.

> **Troubleshooting — empty or frozen PacketLogger feed:**
> - Profile not installed: return to Step 2 and confirm the mobileconfig profile is listed under
>   Settings > General > VPN & Device Management. Without the profile, the iPhone does not
>   generate the HCI log stream PacketLogger expects.
> - iPhone not paired/trusted in Xcode: return to Step 3. The device must appear as connected in
>   Xcode's Devices and Simulators window.
> - Try toggling Bluetooth off and back on on the iPhone (Settings > Bluetooth). This restarts the
>   Bluetooth stack and may refresh the HCI stream.
> - Try disconnecting and reconnecting the USB cable.

---

## Step 5: Run the WHOOP App Session

1. With PacketLogger running, open the official WHOOP app on the iPhone.
2. Ensure the WHOOP 5.0 strap is nearby and powered on.
3. Allow the app to connect and sync — you should see the strap connect and begin streaming
   biometric data. A session of **at least 2–3 minutes** is recommended to accumulate sufficient
   ATT-layer traffic.
4. Watch PacketLogger — BLE HCI events and ACL data frames should appear as the WHOOP app
   communicates with the strap.

---

## Step 6: Save the Capture

1. In PacketLogger, click **Stop**.
2. Select **File > Save** and save the file into the gitignored samples directory:
   ```
   re/capture/samples/<date>-ios-session<N>.pklg
   ```
   Use the date format `YYYY-MM-DD`, e.g. `re/capture/samples/2026-05-30-ios-session1.pklg`.
3. Confirm the file is non-zero bytes:
   ```bash
   ls -lh re/capture/samples/*.pklg
   ```

> **Raw captures are gitignored (D-02).** The `.pklg` file must stay under `re/capture/samples/`
> and never be committed. See Step 8 for the evidence workflow.

---

## Step 7: Read Firmware Version and UDID for the Metadata Sidecar

Run the following after ensuring `ideviceinfo` is installed (included in Brewfile via `libimobiledevice`):

```bash
# Confirm iPhone is recognized:
idevice_id -l

# Read firmware version and UDID:
ideviceinfo -k ProductVersion    # iOS version, e.g. "17.5.1"
ideviceinfo -k UniqueDeviceID    # UDID (device identifier for sidecar)

# Optionally read model:
ideviceinfo -k ProductType       # e.g. "iPhone15,3"
```

> **Record these values** — you'll need them for the metadata sidecar in Step 9.

> **If `ideviceinfo` returns no device:** the phone must be unlocked, trusted, and connected via
> USB. Re-run after unlocking the screen and tapping "Trust This Computer" if prompted.

---

## Step 8: Verify — Non-Empty WHOOP ATT Traffic

Open the capture in Wireshark per `wireshark.md` and confirm non-empty ATT-layer traffic:

```bash
# Quick headless check — must show non-empty output for a successful capture:
tshark -r re/capture/samples/<your>.pklg -Y btatt | head

# Look for WHOOP custom service UUID in the trace:
tshark -r re/capture/samples/<your>.pklg -Y "btatt" -V \
  | grep -i -E "fd4b0001|61080001|8d6d" | head
```

- **Expected:** Lines of ATT PDUs (Read/Write/Notify). The `grep` for `fd4b0001` or `61080001`
  should return matches if WHOOP custom service traffic is present.
- **If `tshark` output is empty:** the profile was not active during the session, or the WHOOP
  app did not connect. Return to Steps 2–5 and retry.
- **For full Wireshark GUI analysis**, see `re/capture/wireshark.md`.

---

## Step 9: Produce Committed Evidence (D-02)

Raw captures stay local and gitignored. What you commit is a redacted evidence triplet:

```bash
# 1. SHA256 checksum of the raw capture:
sha256sum re/capture/samples/<date>-ios-session<N>.pklg \
  > re/capture/evidence/<date>-ios-session<N>.sha256

# 2. Redacted hex excerpt of WHOOP ATT-layer frames (first 40 lines):
#    IMPORTANT: review and scrub any BD_ADDR (device MAC) or SMP key material before commit.
tshark -r re/capture/samples/<date>-ios-session<N>.pklg \
  -Y "btatt" -x | sed -n '1,40p' \
  > re/capture/evidence/<date>-ios-session<N>.hex

# 3. Metadata sidecar (fill in your values):
cat > re/capture/evidence/<date>-ios-session<N>.meta.yaml << 'EOF'
source: ios
tool: PacketLogger
tool_version: "<from About box>"
firmware: "<from ideviceinfo -k ProductVersion>"
device_udid: "<from ideviceinfo -k UniqueDeviceID>"
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

- [ ] PacketLogger.app installed and version recorded
- [ ] iOS Bluetooth Logging mobileconfig installed and profile source URL recorded
- [ ] iPhone trusted in Xcode Devices and Simulators
- [ ] `.pklg` saved to `re/capture/samples/` (non-zero bytes)
- [ ] `tshark -Y btatt | head` shows non-empty ATT output
- [ ] Evidence triplet committed: `.sha256`, `.hex` (scrubbed), `.meta.yaml`
- [ ] `git status re/capture/samples/` shows nothing stage-able (raw ignored)

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| PacketLogger shows no iPhone in device list | iPhone not paired in Xcode | Open Xcode Devices window; trust the device |
| PacketLogger device list has iPhone but no HCI events stream | mobileconfig profile not installed | Return to Step 2; verify profile under Settings > General > VPN & Device Management |
| `.pklg` file is ~0 bytes or very small | Session too short or no BLE activity captured | Ensure WHOOP app connected; run a longer session (2–3 min minimum) |
| `tshark -Y btatt` returns no rows | WHOOP app did not connect over BLE during session | Retry: open WHOOP app before starting capture; confirm strap is awake and nearby |
| `ideviceinfo` returns "No device found" | iPhone locked or not trusted | Unlock iPhone; tap "Trust This Computer" if prompted |
| PacketLogger.app not in `/Applications/` | Not yet installed | Follow Step 1; check also `~/Applications/PacketLogger.app` |

---

## Related Runbooks

- `re/capture/wireshark.md` — open the `.pklg` in Wireshark/tshark, apply ATT/GATT filters,
  locate WHOOP service UUIDs, produce the committed evidence hex excerpt
- `re/capture/android-btsnoop.md` — secondary capture source (Android HCI snoop log)
- `re/capture/README.md` — index of all four runbooks and the Phase 1 success-criterion evidence
  checklist
