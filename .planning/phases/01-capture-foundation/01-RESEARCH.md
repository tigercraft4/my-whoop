# Phase 1: Capture Foundation - Research

**Researched:** 2026-05-30
**Domain:** Passive BLE/HCI traffic capture toolchain (macOS + Android), Wireshark analysis, JADX APK inspection — tooling + documentation + evidence (not software-building)
**Confidence:** MEDIUM-HIGH (codebase context HIGH; external tool versions verified locally via Homebrew; capture-procedure specifics ASSUMED — web research tools were unavailable this session)

> **Web research unavailable this session.** `WebSearch` returned an org-policy 400; Brave/Exa/Firecrawl are not configured (`BRAVE_API_KEY not set`). External procedural claims (mobileconfig URL, btsnoop paths, JADX UI navigation) are tagged `[ASSUMED]` from training knowledge and listed in the Assumptions Log for user/planner confirmation. Tool *versions* were verified live against the local Homebrew install and are `[VERIFIED]`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 — Repo layout:** Capture docs + artifacts live under a new `re/capture/` tree, co-located with existing `re/`. Per-source workflow docs:
  - `re/capture/ios-packetlogger.md`
  - `re/capture/android-btsnoop.md`
  - `re/capture/wireshark.md`
  - `re/capture/jadx.md`
  - `re/capture/README.md` (index tying the four together)
  - Raw capture binaries live in `re/capture/samples/` and are **gitignored** (see D-02).
- **D-02 — Capture privacy / commit policy:** Gitignore raw captures; commit redacted evidence only. Raw `.pklg`/`.btsnoop` stay local under `re/capture/samples/`. Committed evidence = (1) redacted hex excerpts of WHOOP custom-service ATT/GATT traffic, (2) SHA256 checksums of each raw capture, (3) capture metadata (firmware version, capture date, tool + version, source iOS/Android).
- **D-03 — Toolchain setup automation (maximal):** Provide a `Brewfile` + `scripts/check-tools.sh` version-asserter. Installs/verifies: `wireshark` (pin 4.4.x), `jadx` (pin 1.5.1), `android-platform-tools` (adb), `libimobiledevice`, plus tshark/CLI helpers. `check-tools.sh` asserts pinned versions and exits non-zero on mismatch. **Irreducible manual step (known constraint):** the iOS `iOSBluetoothLogging.mobileconfig` install + Xcode iPhone pairing require Apple UI interaction — automate everything automatable, script-verify the rest, document the manual iOS steps precisely in `re/capture/ios-packetlogger.md`.
- **D-04 — APK sourcing + JADX output:** Source the WHOOP Android APK via `adb pull` from the user's own installed copy. Document the `adb pull` procedure in `re/capture/jadx.md`. **Legal recording rule (locked):** record only packet-type/command **enum names and numeric values** (cross-referencing whoop-vault r52). Never commit decompiled source or proprietary material. Decompiled APK + JADX project output are gitignored. APKMirror documented as fallback only if `adb pull` is blocked, same recording rule.

### Claude's Discretion

- Exact filenames/structure within each `re/capture/*.md` doc (as long as the four sources are each covered).
- Precise format of redacted hex excerpts and the metadata schema (e.g., small YAML/JSON sidecar per capture).
- How `check-tools.sh` reports results (table, checklist, etc.) and whether it's bash or python.
- Capture-session naming convention and where firmware version is read from.
- Whether `.gitignore` rules are added globally or scoped to `re/capture/samples/`.
- How each success criterion is mapped to its committed evidence (a checklist doc is fine).

### Deferred Ideas (OUT OF SCOPE)

- GATT service/characteristic enumeration & UUID confirmation → Phase 2 (PROTO-01, PROTO-03).
- Bonding without the official app → Phase 2 (PROTO-02).
- Frame/CRC validation against captured 5.0 frames → Phase 3 (PROTO-04, PROTO-05).
- Decoding biometrics + schema authoring → Phase 4.
- Automating the iOS mobileconfig install — impossible (Apple UI requirement); documented manual step only.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOOL-01 | Capture live BLE traffic from WHOOP 5.0 with PacketLogger on Mac (iPhone tethered, iOS Bluetooth Logging mobileconfig installed) | iOS capture path: PacketLogger (from "Additional Tools for Xcode", NOT brew) + `iOSBluetoothLogging.mobileconfig` profile + Xcode device pairing → `.pklg`. See *iOS PacketLogger Path*, *Don't Hand-Roll*, *Common Pitfalls #1/#2*. |
| TOOL-02 | Documented, reproducible Android HCI snoop capture (Developer Options → btsnoop_hci.log → adb bugreport extraction) | Android path: enable "Bluetooth HCI snoop log" in Developer Options, reproduce session, `adb bugreport` → extract `btsnoop_hci.log` from the zip's `FS/data/misc/bluetooth/logs/` tree. See *Android btsnoop Path*, *Common Pitfalls #3*. |
| TOOL-03 | Decompile official WHOOP Android APK with JADX-GUI to reference packet-type/command enum definitions | `adb pull` the user's installed APK (split-APK aware), open in JADX-GUI, navigate to Maverick/packet-type enums, cross-ref whoop-vault r52. Legal recording rule applies. See *JADX Path*, *Common Pitfalls #4*. |
| TOOL-04 | Load `.pklg` and `.btsnoop` in Wireshark and filter by ATT/GATT layer | Wireshark opens both formats natively; filter `btatt`/`btl2cap`; identify WHOOP custom service UUID. See *Wireshark Path*, *Code Examples*. |
</phase_requirements>

## Summary

Phase 1 is an **operations + evidence** phase: install a version-pinned passive-capture toolchain, write four reproducible runbooks under `re/capture/`, and commit redacted evidence proving each of the four success criteria produces *real, non-empty* WHOOP 5.0 traffic. No application code changes — only new files (`re/capture/**`, `Brewfile`, `scripts/check-tools.sh`, `.gitignore` additions).

The single most important planning finding is a **version-pinning conflict**: CONTEXT D-03 pins **Wireshark 4.4.x** and **JADX 1.5.1**, but the live Homebrew formulae verified this session deliver **Wireshark 4.6.6** and **JADX 1.5.5** — both newer. Homebrew does not reliably install arbitrary historical formula/cask versions (`homebrew/versions` is deprecated; `brew extract` is fragile and won't pin a cask). The plan must resolve this explicitly: either (a) relax the pin to "≥4.4.x" / "≥1.5.1" with a documented floor, or (b) install pinned versions from each project's official release artifacts (Wireshark.org DMG, JADX GitHub release zip) outside brew and have `check-tools.sh` assert the exact version. Wireshark 4.6.x reads `.pklg` and `.btsnoop` identically to 4.4.x for ATT/GATT work, so a floor-based pin carries negligible risk for this phase's goals.

Second finding: **two real dependency gaps on this machine.** `java` resolves but reports "Unable to locate a Java Runtime" — JADX needs a JRE 11+, so a JDK (`openjdk` 26.0.1 via brew, or Temurin) must be in the Brewfile/check. And **PacketLogger is not installed and is not a Homebrew package** — it ships inside Apple's "Additional Tools for Xcode" disk image (manual download from Apple Developer Downloads). `check-tools.sh` can verify its *presence* (`/Applications/PacketLogger.app` or `~/Applications/...`) but cannot install it; this is part of the "irreducible manual step" family alongside the mobileconfig.

**Primary recommendation:** Build `Brewfile` + `scripts/check-tools.sh` for the brew-installable tools (wireshark CLI + GUI cask, jadx, android-platform-tools, libimobiledevice, a JDK), assert **version floors** matching the D-03 intent with a one-line rationale for relaxing the exact pin, presence-check the two non-brew manual tools (PacketLogger, mobileconfig profile), and write the four runbooks with a committed evidence checklist mapping each success criterion to its redacted artifact.

## Architectural Responsibility Map

This phase has no application runtime tiers; the "tiers" are tool roles in the capture pipeline.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| iOS live HCI capture (TOOL-01) | macOS host (PacketLogger) + tethered iPhone (mobileconfig) | — | PacketLogger streams the iPhone's post-decryption HCI; the profile enables on-device logging |
| Android HCI capture (TOOL-02) | Android device (btsnoop log) | macOS host (adb extraction) | Device writes the log; host pulls it via `adb bugreport` |
| Capture analysis (TOOL-04) | macOS host (Wireshark) | — | Reads `.pklg` + `.btsnoop`, dissects ATT/GATT |
| APK enum inspection (TOOL-03) | macOS host (JADX + JRE) | Android device (adb pull source) | Decompile + navigate enums on host; APK sourced from device |
| Toolchain install/verify (D-03) | macOS host (Homebrew + check script) | — | Reproducible, version-asserted setup |
| Evidence commit policy (D-02) | git repo (redacted only) | local FS (`samples/` gitignored) | Raw stays local; redacted hex + SHA256 + metadata committed |

## Standard Stack

> **All versions VERIFIED against the local Homebrew install on 2026-05-30** unless noted. Package *names* are standard well-known tools (not registry-discovered), so they are safe; versions reflect what `brew install` delivers *today*.

### Core
| Tool | Version (live brew) | D-03 Pin | Purpose | Why Standard |
|------|--------------------|----------|---------|--------------|
| Wireshark (GUI cask) | `wireshark-app` 4.6.6 [VERIFIED: brew] | 4.4.x | Open `.pklg`/`.btsnoop`, dissect ATT/GATT | De-facto BLE capture analyzer; native pklg + btsnoop readers |
| Wireshark (CLI formula) | `wireshark` 4.6.6 [VERIFIED: brew] | (implies tshark) | `tshark`/`editcap` for scripted filtering, redaction, checks | Lets `check-tools.sh` assert version headlessly |
| JADX | `jadx` 1.5.5 [VERIFIED: brew] | 1.5.1 | Decompile WHOOP APK; navigate enums (GUI `jadx-gui`) | Best free Dalvik→Java decompiler; the `jadx` formula ships **both** `jadx` and `jadx-gui` |
| Android Platform Tools | `android-platform-tools` (cask) 37.0.0 [VERIFIED: brew] | (adb) | `adb bugreport`, `adb pull`, enable/verify HCI logging | Official Google `adb`/`fastboot` bundle |
| libimobiledevice | `libimobiledevice` 1.4.0 [VERIFIED: brew] | (iOS interaction) | `ideviceinfo`/`idevice_id` — read iPhone firmware/UDID for metadata | Scriptable iOS device introspection (no jailbreak) |
| JDK (JRE 11+) | `openjdk` 26.0.1 [VERIFIED: brew] | — (implicit) | Runtime JADX requires | **Local `java` reports "Unable to locate a Java Runtime"** — hard gap, must install |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| PacketLogger | ships in "Additional Tools for Xcode" DMG (Apple Developer Downloads) [ASSUMED] | iOS HCI live capture → `.pklg` | TOOL-01. **NOT brew-installable** — manual download; presence-check only |
| `iOSBluetoothLogging.mobileconfig` | Apple-provided config profile [ASSUMED] | Enables iPhone-side Bluetooth HCI logging that PacketLogger streams | TOOL-01. Manual install via iPhone Settings (Apple UI requirement) |
| blueutil | 2.13.0 [VERIFIED: brew] | Toggle/inspect Mac Bluetooth from CLI | Optional convenience for repeatable capture setup |
| Xcode | present (`/Applications/Xcode.app`) [VERIFIED: local] | iPhone↔Mac pairing for device logging; Devices window | TOOL-01 — already installed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Exact pin Wireshark 4.4.x | Floor pin "≥4.4.0" accepting 4.6.6 | brew can't deliver 4.4.x today; 4.6.x dissects ATT/GATT identically — recommended |
| Exact pin JADX 1.5.1 | Floor pin "≥1.5.1" accepting 1.5.5, OR pull the 1.5.1 release zip from JADX GitHub | brew gives 1.5.5; if r52 cross-ref needs byte-identical decompiler output, fetch the 1.5.1 release jar manually |
| PacketLogger (.pklg) | `tcpdump`/RF sniffer on the link | RF sniffers see ciphertext on bonded links (STATE decision #6 already rejected nRF52840); PacketLogger captures *post-decryption* HCI — keep it primary |
| `adb pull` APK | APKMirror download | D-04 fallback only; `adb pull` matches the device's actual firmware (cleanest legal footing) |

**Installation (Brewfile sketch — names VERIFIED, see version-pin note):**
```ruby
# Brewfile
cask "wireshark-app"          # GUI 4.6.6 (was 'wireshark' cask pre-rename)
brew "wireshark"              # CLI: tshark/editcap, 4.6.6
brew "jadx"                   # provides jadx + jadx-gui, 1.5.5
cask "android-platform-tools" # adb/fastboot 37.0.0
brew "libimobiledevice"       # ideviceinfo/idevice_id 1.4.0
brew "openjdk"                # JRE for jadx (or: cask "temurin")
brew "blueutil"               # optional Mac BT CLI
# NOT brew-installable (presence-check in check-tools.sh, document in ios-packetlogger.md):
#   PacketLogger.app  -> "Additional Tools for Xcode" DMG from Apple Developer Downloads
#   iOSBluetoothLogging.mobileconfig -> Apple-provided profile, installed via iPhone Settings
```

> **Cask rename gotcha [VERIFIED: brew]:** the Wireshark GUI cask token is now **`wireshark-app`** (4.6.6); the bare `wireshark` token is the CLI-only *formula*. A Brewfile line `cask "wireshark"` will fail or install the wrong thing. Use `cask "wireshark-app"` for the GUI and `brew "wireshark"` for tshark.

## Package Legitimacy Audit

These are GUI/CLI developer tools from Homebrew core taps and Apple, not application-language packages (no npm/PyPI/crates dependency is added by this phase). slopcheck (a package-registry hallucination checker) is not applicable to brew formulae/casks; instead each tool was verified to exist in the live Homebrew index this session.

| Tool | Source | Verified This Session | Disposition |
|------|--------|----------------------|-------------|
| `wireshark` (formula) | homebrew-core | `brew info` → 4.6.6 | Approved [VERIFIED: brew] |
| `wireshark-app` (cask) | homebrew-cask | `brew info --cask` → 4.6.6 | Approved [VERIFIED: brew] |
| `jadx` (formula) | homebrew-core | `brew info` → 1.5.5 | Approved [VERIFIED: brew] |
| `android-platform-tools` (cask) | homebrew-cask (Google) | `brew info --cask` → 37.0.0 | Approved [VERIFIED: brew] |
| `libimobiledevice` (formula) | homebrew-core | `brew info` → 1.4.0 | Approved [VERIFIED: brew] |
| `openjdk` (formula) | homebrew-core | `brew info` → 26.0.1 | Approved [VERIFIED: brew] |
| `blueutil` (formula) | homebrew-core | `brew info` → 2.13.0 | Approved [VERIFIED: brew] |
| PacketLogger.app | Apple Developer Downloads (Additional Tools for Xcode) | Not on this machine; not brew-installable | Manual install — presence-check only [ASSUMED source] |

**Packages removed (SLOP):** none.
**Flagged suspicious (SUS):** none.

## Architecture Patterns

### System Architecture Diagram

```
                    WHOOP 5.0 strap
                    /            \
           (BLE)  /                \  (BLE)
                 v                  v
        ┌──────────────┐    ┌──────────────────┐
        │   iPhone     │    │  Android phone   │
        │ official app │    │  official app    │
        │ + mobileconfig│   │ + HCI snoop ON   │
        │  HCI logging  │   │ (Dev Options)    │
        └──────┬───────┘    └────────┬─────────┘
        USB tether            USB (adb)
               │                      │
        (PacketLogger          (adb bugreport)
         live stream)                 │
               v                      v
        ┌────────────┐        btsnoop_hci.log inside
        │ .pklg file │        bugreport zip → extract
        └─────┬──────┘               │ → .btsnoop
              │                       │
              └──────────┬───────────┘
                         v
                 ┌───────────────┐        ┌──────────────────┐
                 │  Wireshark    │        │   JADX-GUI       │
                 │ open + filter │        │  (adb pull APK)  │
                 │ btatt/btl2cap │        │ navigate enums   │
                 │ find WHOOP svc│        │ cross-ref r52    │
                 └──────┬────────┘        └────────┬─────────┘
                        │                          │
                        v                          v
              redacted hex excerpt          enum names+values only
              + SHA256 + metadata            (no source committed)
                        │                          │
                        └────────► git (committed evidence) ◄──── D-02/D-04
                  raw .pklg/.btsnoop + APK → re/capture/samples/ (GITIGNORED)
```

### Recommended Project Structure
```
re/capture/
├── README.md                 # index: the four sources, evidence checklist, success-criteria map
├── ios-packetlogger.md       # TOOL-01 runbook (incl. manual mobileconfig + Xcode pairing steps)
├── android-btsnoop.md        # TOOL-02 runbook (Dev Options + adb bugreport extraction)
├── wireshark.md              # TOOL-04 runbook (open pklg/btsnoop, filter ATT/GATT, find WHOOP svc)
├── jadx.md                   # TOOL-03 runbook (adb pull APK, JADX-GUI enum navigation, r52 xref)
├── samples/                  # GITIGNORED raw captures + decompiled APK (D-02/D-04)
│   └── .gitkeep              # commit the dir, ignore contents
└── evidence/                 # COMMITTED redacted hex excerpts + SHA256 + metadata sidecars
    └── <session>.{hex,sha256,meta.yaml}
Brewfile                      # repo root (mirrors scripts/ convention)
scripts/check-tools.sh        # version-asserter (set -euo pipefail, like sync-schema.sh)
```
*(`samples/` vs `evidence/` split is Claude's discretion per D-02; shown as a concrete recommendation.)*

### Pattern 1: Version-asserting tool check (mirror `scripts/sync-schema.sh`)
**What:** A bash script that, for each tool, resolves the binary, extracts its version, and asserts a floor (or exact pin), exiting non-zero on any failure. Presence-checks the non-brew manual tools separately.
**When to use:** `scripts/check-tools.sh` (D-03). Run after `brew bundle`.
**Example:**
```bash
#!/usr/bin/env bash
# Source: pattern mirrors repo's scripts/sync-schema.sh (set -euo pipefail) [VERIFIED: codebase]
set -euo pipefail
fail=0
assert_min() { # name actual min
  if [ "$(printf '%s\n%s' "$3" "$2" | sort -V | head -1)" != "$3" ]; then
    echo "FAIL $1: $2 < required $3"; fail=1
  else echo "ok   $1: $2 (>= $3)"; fi
}
assert_min wireshark "$(tshark --version | sed -n '1s/.* \([0-9.]*\).*/\1/p')" 4.4.0
assert_min jadx      "$(jadx --version 2>/dev/null)" 1.5.1
assert_min adb       "$(adb --version | sed -n '1s/.* version \([0-9.]*\).*/\1/p')" 35.0.0
command -v ideviceinfo >/dev/null && echo "ok   libimobiledevice present" || { echo "FAIL libimobiledevice"; fail=1; }
java -version >/dev/null 2>&1 && echo "ok   java JRE present" || { echo "FAIL java (jadx needs JRE 11+)"; fail=1; }
[ -d "/Applications/PacketLogger.app" ] || [ -d "$HOME/Applications/PacketLogger.app" ] \
  && echo "ok   PacketLogger present" || echo "WARN PacketLogger missing (manual: Additional Tools for Xcode)"
exit $fail
```
> The PacketLogger + mobileconfig checks are **WARN, not FAIL** — they're the irreducible manual steps; the script verifies them but cannot install them.

### Pattern 2: Capture metadata sidecar (D-02 discretion)
**What:** A small YAML/JSON file per capture recording firmware version, date, tool+version, source.
**When to use:** Every committed evidence artifact; satisfies the "no empty trace" + provenance requirement and pre-stages PROTO-16 (firmware in every session) for later phases.
**Example:**
```yaml
# re/capture/evidence/2026-05-30-ios-session1.meta.yaml
source: ios            # ios | android
tool: PacketLogger
tool_version: "x.y"    # from About box
firmware: "<from ideviceinfo / app About / GET REPORT_VERSION_INFO later>"
captured: 2026-05-30
raw_sha256: <sha256 of the gitignored .pklg in samples/>
custom_service_uuid_seen: "fd4b0001-... | 61080001-... | none-yet"  # Phase-2 confirms; note what's visible
notes: "ATT/GATT traffic present; N WHOOP-service writes/notifies observed"
```

### Anti-Patterns to Avoid
- **Committing raw `.pklg`/`.btsnoop`:** violates D-02 (may contain SMP/bonding material + device IDs). Gitignore `re/capture/samples/`.
- **Committing decompiled APK source / JADX project:** violates D-04 and DISCLAIMER §2. Only enum names + numeric values in notes.
- **`cask "wireshark"` in Brewfile:** wrong token post-rename — use `cask "wireshark-app"`.
- **Pinning to exact 4.4.x/1.5.1 via brew and expecting success:** brew can't deliver those today — see version-pin pitfall.
- **"Tool launches" as success:** all four criteria require *non-empty* WHOOP traffic / reachable enums — evidence must show real bytes, not a splash screen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| iOS HCI capture | Custom CoreBluetooth sniffer / RF sniffer | PacketLogger + mobileconfig | Captures post-decryption HCI natively, no jailbreak (STATE #5/#6) |
| `.pklg`/`.btsnoop` parsing | Custom binary parser | Wireshark / tshark | Native dissectors for both formats + full BTATT/GATT decode |
| Android HCI extraction | Custom log scraper | `adb bugreport` + unzip | Standard, reproducible; log lives in a known path inside the zip |
| APK decompile | Manual smali reading | JADX-GUI | Produces navigable Java with enum constants resolved |
| Version assertion | ad-hoc `grep` per tool | `sort -V` floor compare (Pattern 1) | Correct semver ordering, mirrors repo bash style |
| iPhone firmware/UDID read | Manual Settings transcription | `ideviceinfo` (libimobiledevice) | Scriptable into metadata sidecar |

**Key insight:** Every capability in this phase already has a mature, purpose-built tool. The work is *installing + pinning + documenting + proving*, not building.

## Common Pitfalls

### Pitfall 1: Pinned versions are not brew-installable
**What goes wrong:** D-03 pins Wireshark 4.4.x / JADX 1.5.1; `brew install` delivers 4.6.6 / 1.5.5. `check-tools.sh` with an *exact-equals* assertion would fail on a clean `brew bundle`.
**Why it happens:** Homebrew tracks latest stable; `homebrew/versions` is deprecated and `brew extract`/cask-version pinning is fragile/unsupported for these.
**How to avoid:** Plan a decision task — relax to **version floor** (`>= 4.4.0`, `>= 1.5.1`) with a one-line rationale in `wireshark.md`/`jadx.md`, OR fetch the exact pinned release artifacts (Wireshark.org 4.4.x DMG, JADX 1.5.1 GitHub release zip) and have `check-tools.sh` assert exact. For ATT/GATT capture analysis, 4.6.x is behaviorally equivalent → floor is recommended.
**Warning signs:** `check-tools.sh` exits non-zero immediately after a successful `brew bundle`.

### Pitfall 2: PacketLogger and the mobileconfig are not installable by script
**What goes wrong:** Treating the whole toolchain as brew-installable; PacketLogger absent at capture time.
**Why it happens:** PacketLogger ships only in Apple's "Additional Tools for Xcode" DMG; the mobileconfig install + Xcode device pairing need Apple UI.
**How to avoid:** Document precisely in `ios-packetlogger.md` (this is the locked "irreducible manual step", D-03). `check-tools.sh` presence-checks `PacketLogger.app` as **WARN**, never auto-installs. **Verified this session: PacketLogger.app is NOT present on this machine** — the runbook must include the download/install step.
**Warning signs:** Empty `.pklg`, or PacketLogger shows no iPhone device — usually means the profile isn't installed or the iPhone isn't paired/trusted in Xcode Devices.

### Pitfall 3: btsnoop log path / size limits / extraction
**What goes wrong:** The `btsnoop_hci.log` is empty, truncated, or not found after pulling.
**Why it happens:** HCI logging must be toggled **before** the session (off→on cycles the buffer), the on-device buffer is size-capped (long sessions roll over), and on modern Android the log isn't at a single fixed path — it's reliably captured via `adb bugreport` and lives inside the zip under `FS/data/misc/bluetooth/logs/btsnoop_hci.log` (path varies by OEM/version). [ASSUMED — confirm on user's device]
**How to avoid:** Runbook: enable HCI snoop → reproduce the WHOOP session → `adb bugreport bugreport.zip` → unzip → locate `btsnoop*` under the FS tree → rename to `.btsnoop`. Keep sessions short to avoid buffer rollover. Verify non-empty by opening in Wireshark and confirming BTATT frames.
**Warning signs:** Wireshark opens the file but shows zero `btatt` packets, or only HCI command/event noise with no ACL data.

### Pitfall 4: WHOOP ships as split APKs
**What goes wrong:** `adb pull` of "the APK" yields only `base.apk`; JADX is missing classes from split config APKs (or the install is an `.apks`/AAB split set).
**Why it happens:** Modern Play installs are split by ABI/density/language; `pm path <pkg>` returns multiple paths.
**How to avoid:** Runbook: `adb shell pm path com.whoop.android` (confirm exact package id on device) → pull **all** returned paths → load `base.apk` in JADX (enums typically live in base) and note if split merging is needed. APKMirror fallback (D-04) provides a bundle if `adb pull` is blocked.
**Warning signs:** JADX shows unresolved references where the packet-type enum should be; classes present but enum bodies empty.

### Pitfall 5: JADX needs a JRE that isn't there
**What goes wrong:** `jadx`/`jadx-gui` fails to launch with a Java error.
**Why it happens:** **Verified this session:** `/usr/bin/java` exists as a stub but reports "Unable to locate a Java Runtime" — no JDK installed.
**How to avoid:** Add a JDK to the Brewfile (`brew "openjdk"` 26.0.1, or `cask "temurin"`) and `check-tools.sh` asserts `java -version` succeeds. Note `openjdk` is keg-only — the runbook may need the `sudo ln -sfn ...` symlink or `PATH`/`JAVA_HOME` export brew prints in caveats.
**Warning signs:** `check-tools.sh` java check fails; JADX-GUI bounces on launch.

## Code Examples

### Open a capture and filter to ATT/GATT (TOOL-04, GUI + headless)
```bash
# Source: standard Wireshark/tshark usage [ASSUMED — verify display-filter names against installed 4.6.6]
# GUI: File > Open the .pklg or .btsnoop, then display filter:
#   btatt                       # all ATT operations (reads/writes/notifications)
#   btl2cap.cid == 0x0004       # the ATT fixed channel
# Headless count (proves non-empty WHOOP traffic for evidence):
tshark -r samples/2026-05-30-ios-session1.pklg -Y btatt -T fields -e btatt.handle -e btatt.value | head
# Find the custom service UUID in handles (look for fd4b0001-... or legacy 61080001-...):
tshark -r samples/session.btsnoop -Y "btatt" -V | grep -i -E "fd4b0001|61080001|8d6d" | head
```

### Redact + excerpt for committed evidence (D-02)
```bash
# Source: standard CLI; redaction approach is project policy [ASSUMED format — discretion]
sha256sum samples/2026-05-30-ios-session1.pklg > evidence/2026-05-30-ios-session1.sha256
# Export a small redacted hex slice of WHOOP-service frames (strip device addrs/SMP before commit):
tshark -r samples/2026-05-30-ios-session1.pklg -Y "btatt" -x | sed -n '1,40p' > evidence/2026-05-30-ios-session1.hex
# (Manually scrub any BD_ADDR / SMP key material from the .hex before git add.)
```

### Source the APK from the user's device (TOOL-03, D-04)
```bash
# Source: standard adb usage [ASSUMED — confirm package id on user's device]
adb shell pm list packages | grep -i whoop          # find the exact package id
adb shell pm path com.whoop.android                 # may return MULTIPLE split paths
for p in $(adb shell pm path com.whoop.android | sed 's/package://'); do adb pull "$p" samples/apk/; done
jadx-gui samples/apk/base.apk                        # navigate to packet-type / Maverick enums
# Record ONLY enum names + numeric values in jadx.md; never commit decompiled source (D-04 / DISCLAIMER §2).
```

### Verify toolchain in one shot (D-03)
```bash
brew bundle --file=Brewfile      # installs everything brew-installable
bash scripts/check-tools.sh      # asserts versions/presence; non-zero on mismatch
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `wireshark` cask = GUI | `wireshark-app` cask = GUI; `wireshark` = CLI formula | Homebrew cask rename [VERIFIED: brew, 2026-05-30] | Brewfile must use `wireshark-app` for GUI |
| Fixed `/sdcard/.../btsnoop_hci.log` path | `adb bugreport` zip extraction (path varies) | Android 9+ scoped storage [ASSUMED] | Runbook uses bugreport, not a hardcoded pull path |
| Single `base.apk` | Split APKs / AAB on Play installs | Android App Bundles default [ASSUMED] | `adb pull` must grab all `pm path` outputs |
| RF sniffer (nRF52840) for BLE | HCI logs (PacketLogger/btsnoop) post-decryption | STATE decision #6 [VERIFIED: STATE.md] | No ciphertext problem on bonded links; RF sniffer skipped |

**Deprecated/outdated:**
- `homebrew/versions` tap — gone; don't plan around it for pinning.
- Hardcoded btsnoop filesystem path — unreliable on modern Android; use bugreport.

## Runtime State Inventory

This is a greenfield additive phase (new files only — `re/capture/**`, `Brewfile`, `scripts/check-tools.sh`, `.gitignore` additions; no rename/refactor/migration). The Runtime State Inventory categories do not apply. Confirmed: CONTEXT §code_context states "No code is modified in existing packages — this phase adds new files only." The only "state" introduced is local gitignored capture artifacts under `re/capture/samples/`, which mirror the existing `re/device_local.py` / `Secrets.xcconfig` gitignore convention [VERIFIED: .gitignore].

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Homebrew | All brew installs | ✓ [VERIFIED] | 5.1.8 | — |
| Xcode | iPhone pairing (TOOL-01) | ✓ [VERIFIED] | at `/Applications/Xcode.app` | — |
| Wireshark (GUI+CLI) | TOOL-04 | ✗ (not installed) | brew offers 4.6.6 | `brew bundle` installs |
| JADX | TOOL-03 | ✗ (not installed) | brew offers 1.5.5 | `brew bundle` installs |
| adb (android-platform-tools) | TOOL-02/03 | ✗ (not installed) | brew offers 37.0.0 | `brew bundle` installs |
| libimobiledevice | metadata/firmware read | ✗ (not installed) | brew offers 1.4.0 | `brew bundle` installs |
| Java JRE 11+ | JADX runtime | ✗ **(java stub present but no runtime)** | brew openjdk 26.0.1 | `brew "openjdk"` or `cask "temurin"` |
| PacketLogger.app | TOOL-01 | ✗ **(not installed, NOT brew)** | from Additional Tools for Xcode DMG | Manual download from Apple Developer Downloads |
| `iOSBluetoothLogging.mobileconfig` | TOOL-01 | ✗ (manual) | Apple-provided | Manual iPhone Settings install |

**Missing dependencies with no fallback:**
- **PacketLogger.app** + **mobileconfig** — must be obtained from Apple manually (irreducible manual step, D-03). Plan must include a `checkpoint:human` for these.

**Missing dependencies with fallback (brew installs them):**
- Wireshark, JADX, adb, libimobiledevice, Java JDK — all delivered by `brew bundle`. The plan's first task is the Brewfile + `brew bundle` + `check-tools.sh`.

## Project Constraints (from CLAUDE.md)

No `CLAUDE.md` exists in the working directory (verified). No `.claude/skills/` or `.agents/skills/` directory exists (verified; `.claude/` is gitignored). Governing constraints come instead from:
- **DISCLAIMER.md §2** — repo must contain no WHOOP binaries/APKs/firmware/decompiled source/branded assets. Directly governs D-02 (gitignore raw captures) and D-04 (no decompiled source committed; enum names+values only). The plan's verification MUST confirm `.gitignore` covers `re/capture/samples/` and any APK/JADX output, and that committed evidence is redacted.
- **Existing `.gitignore` conventions** [VERIFIED] — `apk/` already gitignored; `device_local.py`, `Secrets.xcconfig` gitignored as local/secret. New capture rules extend the same pattern.
- **`scripts/` bash convention** [VERIFIED] — `set -euo pipefail`, run-from-anywhere `ROOT="$(cd "$(dirname "$0")/.." && pwd)"`. `check-tools.sh` should match.
- **`commit_docs: true`** (config.json) — RESEARCH.md and phase docs are committed.
- **`nyquist_validation: false`** (config.json) — Validation Architecture section intentionally omitted.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `iOSBluetoothLogging.mobileconfig` is the correct Apple-provided profile name and is installed via iPhone Settings | Stack / Pitfall 2 | Wrong profile name in runbook → no iOS HCI logging; verify against Apple's current Bluetooth logging instructions |
| A2 | PacketLogger ships in "Additional Tools for Xcode" DMG from Apple Developer Downloads | Stack / Pitfall 2 | If relocated, runbook download step is wrong; verify on Apple Developer site |
| A3 | btsnoop log is reliably extracted via `adb bugreport` zip under `FS/data/misc/bluetooth/logs/` | Pitfall 3 / Code Examples | OEM path differs → extraction step fails; confirm on user's actual Android device |
| A4 | WHOOP Android package id is `com.whoop.android` | Code Examples / Pitfall 4 | `adb pull` targets wrong package; confirm via `pm list packages | grep whoop` on device |
| A5 | WHOOP installs as split APKs on modern Android | Pitfall 4 / State of the Art | If single APK, the multi-pull step is unnecessary (harmless) |
| A6 | Wireshark display filters `btatt` / `btl2cap.cid==0x0004` are valid in 4.6.6 | Code Examples | Filter syntax drift → wrong filter; verify in installed Wireshark |
| A7 | Relaxing Wireshark/JADX exact pins to floors is acceptable for ATT/GATT capture goals | Summary / Pitfall 1 | If r52 cross-ref needs byte-identical JADX 1.5.1 output, must fetch exact release — **user decision needed** |
| A8 | Android btsnoop buffer is size-capped (long sessions roll over) | Pitfall 3 | If false, short-session advice is merely conservative (harmless) |

> A1–A4, A6, A7 are the assumptions that materially affect whether the runbooks work. **A7 should be confirmed with the user** (or surfaced in discuss-phase) because it touches a locked decision (D-03 pin). The rest are device-specific facts the developer confirms live during the first capture.

## Open Questions

1. **Exact version pin vs floor (D-03 conflict)**
   - What we know: brew delivers Wireshark 4.6.6 / JADX 1.5.5; D-03 pins 4.4.x / 1.5.1. [VERIFIED: brew]
   - What's unclear: whether the user wants byte-exact pins (requires non-brew release artifacts) or accepts a documented floor.
   - Recommendation: default to **floor pin** with rationale committed in the runbooks; add a `checkpoint:human` only if the user insists on exact 1.5.1 for r52 parity.

2. **mobileconfig provenance**
   - What we know: Apple provides Bluetooth-logging config profiles; the exact filename/source URL is [ASSUMED].
   - What's unclear: current canonical download location and filename.
   - Recommendation: the iOS runbook task should fetch/confirm Apple's current Bluetooth logging profile at execution time and record the source URL in the doc.

3. **WHOOP package id + split layout on the user's device**
   - What we know: standard `pm path` flow handles both.
   - What's unclear: exact id and whether splits matter for the enum classes.
   - Recommendation: jadx.md runbook starts with `pm list packages | grep whoop` and pulls all `pm path` outputs.

## Sources

### Primary (HIGH confidence)
- **Local Homebrew index** (`brew info --json=v2`, 2026-05-30) — wireshark 4.6.6, wireshark-app cask 4.6.6, jadx 1.5.5, android-platform-tools 37.0.0, libimobiledevice 1.4.0, openjdk 26.0.1, blueutil 2.13.0.
- **Local environment probes** — PacketLogger.app absent; Xcode present; `java` runtime missing; no CLAUDE.md / skills dir.
- **Repo files** — `FINDINGS.md`, `.planning/PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `.planning/codebase/STRUCTURE.md` + `STACK.md`, `DISCLAIMER.md`, `.gitignore`, `scripts/sync-schema.sh`, `re/README.md`, `re/device_local.example.py`, `01-CONTEXT.md`.

### Secondary (MEDIUM confidence)
- None — web verification tools were unavailable this session.

### Tertiary (LOW confidence — flagged for validation)
- Training-knowledge procedural claims about PacketLogger/mobileconfig install, Android btsnoop extraction paths, JADX UI navigation, and Wireshark filter syntax — all tagged `[ASSUMED]` and enumerated in the Assumptions Log. **Confirm at execution time against current official docs.**

## Metadata

**Confidence breakdown:**
- Standard stack (tool names + versions): HIGH — verified live against Homebrew.
- Version-pin conflict + dependency gaps (Java, PacketLogger): HIGH — verified on this machine.
- Capture procedures (mobileconfig, btsnoop extraction, JADX nav): LOW-MEDIUM — training knowledge, web verification unavailable; tagged ASSUMED.
- Architecture/repo layout: HIGH — driven by locked CONTEXT decisions + repo conventions.
- Pitfalls: MEDIUM-HIGH — version/dependency pitfalls verified; procedural pitfalls reasoned from established Android/iOS behavior.

**Research date:** 2026-05-30
**Valid until:** 2026-06-29 (30 days) — but re-verify brew versions before pinning, as Wireshark/JADX move; re-confirm Apple's mobileconfig/PacketLogger locations when web access is available.
