# Technology Stack — BLE Capture & Analysis for WHOOP 5.0

**Project:** my-whoop (WHOOP 5.0 reverse engineering)
**Researched:** 2026-05-30
**Scope:** Tools and workflow for capturing and analysing BLE traffic between WHOOP 5.0 and the official app on stock iPhone + stock Android + Mac with Xcode.
**Overall confidence:** HIGH — Apple/Google/Nordic tooling is mature; an existing public WHOOP 5.0 RE project (`Sophonbot0/whoop-vault`) confirms the workflow end-to-end.

---

## TL;DR — The Prescriptive Stack

**Do this, in this order:**

1. **JADX-GUI on the official WHOOP Android APK** — this is your *primary* protocol source. The 5.0 protocol has already been mostly mapped this way; do not start from scratch with passive sniffing.
2. **Apple PacketLogger** (Additional Tools for Xcode) + **iOS Bluetooth Logging profile** — live HCI capture from your iPhone tethered to Mac. Primary *runtime* capture tool.
3. **Android HCI snoop log** on the stock Android phone running the official WHOOP app — secondary capture for cross-validation and to fill gaps where iOS strips data.
4. **Wireshark 4.4.x** (current LTS) — single analysis surface for both `.pklg` (iOS) and `.btsnoop` (Android) files.
5. **nRF Connect for Mobile** (iOS + Android) — fast GATT enumeration and ad-hoc characteristic writes/reads. No hardware purchase needed.
6. **Skip the nRF52840 sniffer for now.** Mac PacketLogger already gives you decrypted HCI traffic from the iPhone. A passive RF sniffer adds cost, setup time, and packet drops without unlocking new data — defer unless WHOOP 5.0 introduces a non-bonded encrypted channel that hides from HCI.

The headline finding: **a public project (Sophonbot0/whoop-vault) already documents the WHOOP 5.0 "Maverick" frame format, service UUIDs, command bytes, and historical sync handshake** based on JADX decompilation of firmware r52. The 4.0 frame format from this project (`0xAA` SOF, len-LE-u16, CRC8, type, seq, cmd, payload, CRC32-LE) is **structurally the same as 5.0's Maverick header**, but the header has additional version/role/CRC16 fields and the inner buffer is now 4-byte aligned. Treat APK decompilation as the source of truth and BLE capture as the verification mechanism.

---

## Recommended Stack

### Primary: Protocol Discovery from APK

| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **JADX-GUI** | 1.5.1 (Mar 2025, current) | Decompile official WHOOP Android APK to readable Java | Sophonbot0/whoop-vault already mapped 5.0 enums (`eo0/c.java` packet types, `eo0/e.java` commands, `xg0/a.java` packet builder, `ch0/b.java` ACK protocol) — same approach will validate and extend |
| **apktool** | 2.10.0 | Unpack APK resources (XML manifests, smali) | Complement to JADX for resource-level analysis (string tables, service UUIDs declared in manifests) |
| **Ghidra** | 11.2 | Decompile native `.so` libraries if firmware logic is in C/Rust | The WHOOP app may push protocol details into a native library; Ghidra needed if Java layer is just a thin wrapper |
| **frida-tools** | 16.x | Runtime hook on Android *if* you root a secondary device later | Optional. Only if static decompilation runs out of road — out of scope for stock device, deferred |

**APK acquisition:** Pull from a stock Android phone with `adb shell pm path com.whoop.android` then `adb pull` the APK paths. Use whichever version is currently installed and pinned to your firmware. Do **not** redistribute the APK — analyse locally only.

**Confidence:** HIGH. JADX is the standard Android RE tool; the existing whoop-vault project proves it works on the WHOOP APK.

### Primary: Live BLE Capture on iOS (Mac-tethered)

| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **PacketLogger** | Ships with Additional Tools for Xcode 16.x (Dec 2024+) | Live HCI capture from iPhone tethered to Mac via USB | Apple-native, no jailbreak, captures full HCI including ATT/GATT writes/notifications between WHOOP app and strap — Apple decrypts the LE Secure Connections traffic on-device so HCI logs are plaintext |
| **iOS Bluetooth Logging profile** (`iOSBluetoothLogging.mobileconfig`) | Current (Apple-signed) | Enables enhanced BLE logging on the iPhone | Required — without this profile, PacketLogger live trace will be empty / minimal |
| **Console.app** | Ships with macOS 14+ | Stream `bluetoothd` log messages from iPhone (alongside PacketLogger HCI) | Complements PacketLogger with bluetoothd-level messages (pairing state, LTK events, errors) |
| **Xcode** | 16.x (current) | Required to install Additional Tools; also provides device pairing/trust dialogs | Already installed by user |

**Confidence:** HIGH. Documented Apple workflow; Bluetooth SIG and multiple BLE practitioner blogs (Novel Bits, BeaconZone, billsnyder.me, Twocanoes) confirm the procedure.

### Primary: Live BLE Capture on Android (stock, no root)

| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **Android Developer Options → Enable Bluetooth HCI snoop log** | Android 14 / 15 (stock) | Capture HCI to `btsnoop_hci.log` | Built-in, no root, captures everything the Android Bluetooth stack sees — same level as PacketLogger on iOS |
| **adb (Android Platform Tools)** | 35.x (current) | Extract `btsnoop_hci.log` via bug report mechanism on stock (non-root) devices | Without root you cannot `adb pull /data/misc/bluetooth/logs/` directly; the supported path is `adb bugreport` → unzip → `FS/data/log/bt/btsnoop_hci.log` |
| **bugreport extraction**: `adb bugreport bug.zip` then unzip | n/a | Recover the snoop log on stock device | Confirmed working on Android 14/15 without root |

**Workflow caveat:** On Android 15+, some OEMs rotate filenames (e.g., `btsnoop_hci_2026_01_09.log`). Always verify with:
```
adb shell cat /etc/bluetooth/bt_stack.conf | grep BtSnoopFileName
```

**Confidence:** HIGH for the mechanism; MEDIUM that bug-report extraction works on every OEM build (Samsung One UI is known to sometimes restrict access — Pixel stock is the safe choice).

### Analysis Surface

| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **Wireshark** | 4.4.x (4.4.3 stable, Jan 2026) | Open `.pklg` (PacketLogger native) and `.btsnoop` files; dissect HCI / L2CAP / ATT / GATT layers | Single canonical analysis surface across both capture sources. Dissects every Bluetooth SIG protocol layer down to the bit, knows standard characteristics (e.g., `0x2A19` = Battery, `0x2A37` = HR Measurement) |
| **Wireshark filters** | n/a | `btatt`, `btl2cap.cid == 0x0004`, `btatt.handle`, `btatt.opcode` | Standard filters for isolating GATT traffic |
| **Custom Lua dissector** for WHOOP Maverick frame | DIY | Parse the `0xAA` framed payload inside ATT Write/Notify | Wireshark won't decode WHOOP-proprietary frames out of the box; a Lua dissector turns scrolls of hex into named fields. Build *after* you have the schema from JADX |

**Confidence:** HIGH. PacketLogger explicitly exports to BTSnoop; Wireshark explicitly supports both formats.

### GATT Exploration / Live Probing

| Tool | Version | Purpose | Why |
|------|---------|---------|-----|
| **nRF Connect for Mobile** | iOS 2.7.x / Android 4.27.x (current) | Connect directly to WHOOP 5.0 strap, enumerate services/characteristics, send arbitrary writes, subscribe to notifications | Faster than writing Swift/Python code for every probe; great for "what does writing 0x01 to fd4b0002 do?" experiments. Nordic-made, free |
| **Bleak** (Python) | 0.22.x | Cross-platform BLE client for scripted experiments on Mac/Linux | When you outgrow nRF Connect and need scripted, reproducible probes. Already used by the 4.0 codebase (`re/re_harness.py`) — same pattern carries to 5.0 |

**Confidence:** HIGH. Already proven in the 4.0 workflow; whoop-vault uses Bleak.

### Supporting Tools

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| **btmon** (BlueZ) | 5.x (Linux) | Alternative HCI monitor if you bring a Linux box online | Backup. Not needed unless you want a third independent capture |
| **hcitool / gatttool** | BlueZ 5.x | Low-level scripting on Linux | Same as btmon — backup. Bleak covers it cross-platform |
| **plistutil / `pklg2btsnoop`** | n/a (PacketLogger File → Export) | Convert `.pklg` → `.btsnoop` for Wireshark | PacketLogger itself does this via File → Export. No external converter needed |

---

## Step-by-Step Setup

### 1. Install JADX-GUI (one-time, Mac)

```bash
brew install jadx
# OR download the GitHub release: https://github.com/skylot/jadx/releases
```

Pull the WHOOP APK from a stock Android device that has the app installed:

```bash
adb shell pm path com.whoop.android
# Output looks like: package:/data/app/.../base.apk
adb pull /data/app/.../base.apk whoop.apk
jadx-gui whoop.apk
```

Once open, search for `fd4b0001` (the known 5.0 service UUID), navigate up from there to find the command/event enums (`eo0/c.java`, `eo0/e.java` pattern from whoop-vault).

### 2. Install Apple PacketLogger (one-time, Mac)

1. Sign into developer.apple.com → **More Downloads** → search "Additional Tools for Xcode".
2. Download the DMG matching your Xcode version (Xcode 16.x → Additional Tools for Xcode 16).
3. Open the DMG → `Hardware/` folder → drag **PacketLogger.app** to `/Applications`.

Verify:
```bash
ls /Applications/PacketLogger.app
```

### 3. Install iOS Bluetooth Logging Profile (one-time, iPhone)

1. On the iPhone, open Safari and navigate to:
   `https://developer.apple.com/services-account/download?path=/iOS/iOS_Logs/iOSBluetoothLogging.mobileconfig`
   (You must be signed into your Apple developer account; a free account works.)
2. iOS will offer to download the profile → tap **Allow**.
3. Settings → **General → VPN & Device Management → Bluetooth for iOS** → **Install** (passcode required).
4. Reboot the iPhone (recommended — ensures `bluetoothd` picks up the new logging level).

### 4. First iOS Capture

1. Connect iPhone to Mac via USB. Trust the computer if prompted.
2. Launch **PacketLogger.app**.
3. **File → New iOS Trace** → select your iPhone.
4. You should see a pulsing dot in the iPhone's status bar — that's the live trace indicator.
5. On the iPhone, open the official WHOOP app → connect to your strap → trigger sync.
6. Back in PacketLogger, watch ATT/GATT packets appear in real time.
7. **File → Save** → choose **BTSnoop** format → `whoop5-session-001.btsnoop`.
8. After the session: Settings → General → VPN & Device Management → **remove the Bluetooth profile** when you're done capturing for the day (it's verbose and drains battery).

### 5. First Android Capture

1. On stock Android (Pixel recommended), Settings → About Phone → tap **Build Number** seven times.
2. Settings → System → **Developer Options** → toggle **Enable Bluetooth HCI snoop log** → **Filtered** or **Enabled** (use **Enabled** for max data).
3. Toggle Bluetooth off and back on (forces the new logging level to take effect).
4. Open the WHOOP Android app → connect to strap → trigger sync.
5. Pull the snoop log:
   ```bash
   adb bugreport whoop-bug.zip
   unzip whoop-bug.zip "FS/data/log/bt/*"
   # The btsnoop_hci.log (or btsnoop_hci_YYYY_MM_DD.log on newer Android) is in FS/data/log/bt/
   ```
6. Disable the snoop log after capture (security hygiene — it logs *all* Bluetooth, including keyboards/AirPods).

### 6. Open Captures in Wireshark

```bash
brew install --cask wireshark
```

Wireshark opens both `.pklg` and `.btsnoop` natively:

```bash
wireshark whoop5-session-001.btsnoop
```

Useful filters:
| Filter | Shows |
|--------|-------|
| `btatt` | All ATT (GATT) packets |
| `btl2cap.cid == 0x0004` | GATT channel only |
| `btatt.handle == 0x000X` | Traffic to a specific characteristic handle |
| `btatt.opcode == 0x12` | Write Requests |
| `btatt.opcode == 0x1b` | Handle Value Notifications |
| `bthci_cmd.opcode == 0x2019` | LE Start Encryption (LTK location, if needed) |

### 7. (Later) Build a Wireshark Lua Dissector for Maverick Frames

Once you've confirmed the frame layout from JADX + raw captures, write a Lua dissector so every ATT Write/Notify auto-parses:
- SOF `0xAA`
- version u8, length u16 LE, role_a u8, role_b u8, crc16
- inner buffer: type u8, seq u8, cmd u8, payload, crc32

This pays for itself the first time you read a 100-packet sync session.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Live BLE capture (iOS) | **PacketLogger over USB** | sysdiagnose (`.pklg` inside `.tar.gz`) | sysdiagnose is offline-only and rate-limited; you can't iterate quickly. Useful as a backup for capturing *retrospectively* if you forgot to start PacketLogger, but not the primary tool |
| Live BLE capture (Android) | **HCI snoop log (built-in)** | nRF Sniffer with nRF52840 dongle (~€10–20) | Snoop log gives you decrypted GATT-level packets; nRF Sniffer is RF-level passive capture that loses bonded encrypted traffic, drops packets on one channel at a time, and adds setup friction. **Skip unless** you need over-the-air analysis of advertising/scan-response on the WHOOP charger or non-paired devices |
| Live BLE capture (Linux) | (Mac/Android primary) | `btmon` + BlueZ + a USB BT dongle | Adds another OS to maintain. Use only if you want a third independent reference |
| APK decompilation | **JADX-GUI** | apktool (smali) + manual reading | JADX produces Java; smali is assembly. Use JADX for protocol logic, apktool for resources/manifests |
| Native lib RE | **Ghidra (if needed)** | IDA Pro / radare2 | Ghidra is free, NSA-backed, has good ARM support. IDA is best-in-class but expensive. Defer until you confirm WHOOP uses native code for protocol |
| Encryption defeat | **LTK extraction from PacketLogger** if needed | Frida hook on Android | The HCI log from PacketLogger and Android snoop is already post-decryption. You only need LTK if you capture from an *external* RF sniffer (nRF). Since we're not using one, skip |
| GATT exploration | **nRF Connect for Mobile** | LightBlue (iOS), Bluetility (Mac) | nRF Connect is more powerful, cross-platform, free, well-maintained by Nordic |
| BLE scripting | **Bleak (Python)** | CoreBluetooth Swift snippets | Bleak is faster to iterate during RE. Reserve Swift for the production app code |
| Analysis surface | **Wireshark 4.4.x** | hcidump text dumps, custom Python | Wireshark dissects the SIG-defined layers for free; you only need to add a Lua dissector for the WHOOP-proprietary inner frame |

---

## Hardware Sniffer Decision: Skip nRF52840 (For Now)

**Why the nRF Sniffer is *not* recommended at this stage:**

| Concern | Detail |
|---------|--------|
| Redundant data source | PacketLogger HCI on iPhone + Android HCI snoop log already give you both endpoints' view of the GATT traffic, **post-decryption**. The nRF Sniffer gives you raw RF, **encrypted** unless you also extract the LTK. |
| Lossy on one channel | nRF52840 listens to one advertising channel at a time and "occasionally drops packets" (Nordic's own documentation). HCI logs are lossless. |
| Setup overhead | Requires Nordic firmware flash, Wireshark plugin install, channel hopping config. None of this is hard, but it's friction without payoff while HCI logs work. |
| Lags behind BLE spec | Nordic notes the sniffer "usually lags behind in terms of support for the latest Bluetooth Low Energy features." WHOOP 5.0 advertises BT 5.x — possible incompatibility |

**When to revisit:** if you discover that WHOOP 5.0 uses a non-GATT proprietary connection layer (unlikely), or if you need to study charger ↔ strap communication where no phone is involved. €15 is cheap insurance — buy one for the shelf, but don't make it your daily driver.

---

## iOS PacketLogger vs Android HCI: Which Is Richer?

**Verdict: capture both, primary = iOS PacketLogger.**

| Aspect | iOS PacketLogger | Android HCI snoop |
|--------|------------------|-------------------|
| Format | `.pklg` (native) or `.btsnoop` export | `.btsnoop` native |
| Live capture | **Yes** (USB tether, real time) | No (post-hoc extraction via bug report) |
| Decryption | **Decrypted** (post-LL) | Decrypted (post-LL) |
| GATT layer visibility | Full ATT/GATT including handles & UUIDs | Full ATT/GATT |
| `bluetoothd` correlation | **Yes** via Console.app side-by-side | adb logcat (separate stream) |
| Setup friction | Profile install + Xcode | Toggle in Dev Options |
| Iteration speed | **Fast** (live, filter as you go) | Slow (capture → bug report → unzip → open) |
| Risk of missing data | Low if profile is installed and trace is running | Higher — buffer can wrap on long sessions; no live confirmation |
| WHOOP app version differences | iOS app version may behave differently from Android | Android app gave whoop-vault its JADX source; some commands may be Android-only |

**Recommendation:** Use iOS PacketLogger for **iteration** (you'll capture dozens of sessions during RE). Use Android HCI snoop log for **cross-validation** (confirm packet structure is identical across both clients) and to ensure you're not missing Android-specific commands.

---

## Installation Cheat Sheet

```bash
# Mac (Homebrew)
brew install jadx
brew install --cask wireshark
brew install --cask android-platform-tools  # provides adb
# PacketLogger: manual download via developer.apple.com (Additional Tools for Xcode)

# Python tooling (already in 4.0 project; reuse the venv)
pip install bleak                 # cross-platform BLE client
pip install pyshark               # programmatic .btsnoop analysis if needed

# iOS profile (install via Safari on iPhone):
# https://developer.apple.com/services-account/download?path=/iOS/iOS_Logs/iOSBluetoothLogging.mobileconfig

# Android: Settings → About → tap Build Number 7x → Developer Options → "Enable Bluetooth HCI snoop log" = Enabled

# Mobile apps:
#   iOS: App Store → "nRF Connect for Mobile" (Nordic Semiconductor)
#   Android: Play Store → "nRF Connect for Mobile" (Nordic Semiconductor)
```

---

## Things to Avoid

1. **Don't start with passive RF sniffing.** You'll burn days flashing firmware and configuring channel hopping when PacketLogger gives you better data in 5 minutes.
2. **Don't ignore the existing whoop-vault project.** It already documents WHOOP 5.0 services, the Maverick frame, packet types, command bytes, and the historical sync handshake. Validate against it; don't redo it from zero.
3. **Don't forget to install the iOS Bluetooth Logging profile.** Without it, PacketLogger's iOS trace will be empty or contain only summary events. This is the #1 newbie mistake (per Apple Developer Forums).
4. **Don't leave the iOS profile installed long-term.** It increases logging verbosity and battery drain. Install for a capture session, remove after.
5. **Don't try to pull `/data/misc/bluetooth/logs/btsnoop_hci.log` directly via adb on a stock Android device.** That path requires root. Use `adb bugreport` and extract from `FS/data/log/bt/` instead.
6. **Don't redistribute the WHOOP APK.** Decompile locally for interoperability research (17 U.S.C. §1201(f), per the existing project's legal framing); don't publish decompiled code.
7. **Don't trust a single capture.** Always cross-reference iOS + Android logs for the same operation. Differences reveal undocumented per-platform behaviour.
8. **Don't capture without a session plan.** Each session should target one behaviour (boot, sync, real-time HR, sleep mode entry). Mixed captures are 10x harder to decode.
9. **Don't skip the Wireshark Lua dissector once you've nailed the frame format.** Hand-parsing 0xAA-framed payloads in hex view burns hours per session.
10. **Don't assume WHOOP 5.0 reuses the 4.0 custom service UUID** (`61080001-…`). It doesn't — 5.0 uses `fd4b0001-…` per the whoop-vault findings. **Confirm this is your first BLE scan result** before going deep.

---

## Confidence Assessment per Tool

| Tool | Confidence | Source |
|------|------------|--------|
| JADX-GUI for APK | HIGH | whoop-vault repo's documented findings; JADX is industry standard |
| PacketLogger workflow | HIGH | Apple developer docs + Bluetooth SIG official tutorial + Novel Bits guide |
| iOS Bluetooth Logging profile URL | HIGH | Apple Developer profiles & logs page |
| Android HCI snoop log path | MEDIUM | Documented for AOSP; OEM variations exist (Samsung known to differ). Pixel is safe |
| Bug-report extraction on stock Android | HIGH | Confirmed working in Android 14 & 15 per multiple recent sources |
| Wireshark .pklg + .btsnoop support | HIGH | Wireshark official format support list |
| nRF Connect for Mobile capabilities | HIGH | Nordic official |
| Skip nRF Sniffer | MEDIUM | Reasoned position; correct given current scope but reconsider if encryption hides traffic |
| WHOOP 5.0 `fd4b0001` service UUID | HIGH | Sophonbot0/whoop-vault firmware r52 documented; julienlhk/whoop independently confirms |
| Maverick frame format | HIGH | Sophonbot0/whoop-vault documented from JADX of official APK |

---

## Sources

- [Apple Developer — Profiles & Logs (iOS Bluetooth profile)](https://developer.apple.com/bug-reporting/profiles-and-logs/)
- [Bluetooth SIG — A new way to debug iOS Bluetooth applications](https://www.bluetooth.com/blog/a-new-way-to-debug-iosbluetooth-applications/)
- [Novel Bits — Debugging Bluetooth LE on iOS: HCI Capture & LTK Extraction Guide](https://novelbits.io/debugging-sniffing-secure-ble-ios/)
- [Twocanoes — Capture Bluetooth Packet Trace on iOS](https://twocanoes.com/knowledge-base/capture-bluetooth-packet-trace-on-ios/)
- [Apple Developer Forums — PacketLogger discussions](https://developer.apple.com/forums/thread/759461)
- [Sophonbot0/whoop-vault — WHOOP 5.0 RE project (Maverick frame, fd4b0001 service)](https://github.com/Sophonbot0/whoop-vault)
- [julienlhk/whoop — independent WHOOP 5.0 BLE work (firmware 50.37.1.0)](https://github.com/julienlhk/whoop)
- [bWanShiTong/openwhoop — WHOOP 4.0 reference RE project (Rust)](https://github.com/bWanShiTong/openwhoop)
- [JADX decompiler — GitHub](https://github.com/skylot/jadx)
- [Wireshark — official site (BTSnoop / .pklg support)](https://www.wireshark.org/)
- [Nordic Semiconductor — nRF Sniffer for Bluetooth LE](https://www.nordicsemi.com/Products/Development-tools/nrf-sniffer-for-bluetooth-le)
- [nRF Connect for Mobile](https://www.nordicsemi.com/Products/Development-tools/nrf-connect-for-mobile)
- [Bleak — Python BLE client](https://github.com/hbldh/bleak)
- [BeaconZone — Debugging Bluetooth on iOS](https://www.beaconzone.co.uk/blog/debugging-bluetooth-on-ios/)
