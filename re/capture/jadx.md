# JADX-GUI Runbook — TOOL-03

**Version:** 1.0 — 2026-05-30
**Requirement:** TOOL-03 (adb pull WHOOP APK, navigate packet-type/command enums in JADX-GUI)
**Legal recording rule (locked, D-04):** Record ONLY enum names and their numeric values.
**Never commit decompiled source or any proprietary material (DISCLAIMER §2).**

---

## Overview

This runbook describes how to pull the official WHOOP Android APK from your own installed copy
using `adb`, open it in JADX-GUI on the Mac, navigate to the Maverick / packet-type / command
enum definitions, and cross-reference those values against the external whoop-vault r52 map.

The pulled APK and any JADX project output are gitignored under `re/capture/samples/apk/` and
**never committed**. Only your notes — enum names and their numeric values — may be recorded.

---

## Prerequisites

1. **JADX + adb + Java JRE installed** — run `brew bundle --file=Brewfile` from the repo root,
   then `bash scripts/check-tools.sh` (must print all `ok` lines, no `FAIL`).
   - JADX `>= 1.5.1` (brew delivers 1.5.5); provides both `jadx` (CLI) and `jadx-gui`.
   - `adb` from `android-platform-tools` `>= 35.0.0` (brew delivers 37.0.0).
   - Java JRE 11+ (brew `openjdk` delivers 26.0.1 — see JRE troubleshooting below).

2. **Your Android device connected via USB** with Developer Options and USB Debugging enabled.
   Confirm with `adb devices` — your device UDID must appear in the list (not "unauthorized").

3. **WHOOP Android app installed on the device** — this procedure pulls your own installed copy
   (D-04). Do **not** sideload or download a third-party APK before verifying the official route
   is blocked.

4. **Output directory exists** — `re/capture/samples/apk/` (gitignored; tracked by git via
   `samples/.gitkeep` but its contents are ignored). Confirm:

   ```bash
   mkdir -p re/capture/samples/apk/
   ```

---

## Steps

### Step 1 — Confirm the WHOOP package ID on your device

> **Do NOT hardcode `com.whoop.android`.** The exact package name must be confirmed on your
> device (Assumption A4). Run:

```bash
adb shell pm list packages | grep -i whoop
```

Expected output (one or more lines):

```
package:com.whoop.android
```

Note the exact package name. If you see a different identifier (e.g. `com.whoop.android.beta`),
use that name in all subsequent commands.

---

### Step 2 — List all split APK paths for the package

Modern Android installs from the Play Store are often **split APKs** (split by ABI, screen
density, or language — Pitfall 4). `pm path` may return multiple paths:

```bash
adb shell pm path com.whoop.android
```

> **Substitute your confirmed package name from Step 1.**

Example output (split install):

```
package:/data/app/com.whoop.android-xxxxx/base.apk
package:/data/app/com.whoop.android-xxxxx/split_config.arm64_v8a.apk
package:/data/app/com.whoop.android-xxxxx/split_config.xxhdpi.apk
```

If only one path is returned, it is a single-APK install — the loop in Step 3 still works.

---

### Step 3 — Pull all APK splits to `re/capture/samples/apk/`

```bash
for p in $(adb shell pm path com.whoop.android | sed 's/package://'); do
  adb pull "$p" re/capture/samples/apk/
done
```

> **Substitute your confirmed package name.** The `sed 's/package://'` strips the prefix `pm path`
> prints before each path.

After the pull, confirm the files landed:

```bash
ls -lh re/capture/samples/apk/
```

Expected: `base.apk` and optionally one or more `split_config.*.apk` files. Verify
`git status` shows them as **ignored** (not staged):

```bash
git status re/capture/samples/apk/
# Should print nothing or "nothing to commit" — if the APKs appear as untracked, the gitignore
# rule is not covering them. Check .gitignore for the re/capture/samples/ rule.
```

---

### Step 4 — Open `base.apk` in JADX-GUI

```bash
jadx-gui re/capture/samples/apk/base.apk
```

JADX-GUI will decompile the APK and present a tree of packages. This takes 20–60 seconds for a
large app. When the project loads, you will see a package tree in the left panel.

**Navigate to the packet-type / command enum definitions:**

The WHOOP protocol uses a "Maverick" outer wrapper with packet-type and command identifiers
similar to the 4.0 enums. In the package tree, look for packages related to:

- `maverick` — the protocol layer name
- `packet` or `command` — enum definitions for packet types and command IDs
- `protocol` or `ble` — BLE communication layer

Use **Search > Text search** (`Ctrl+F`) or **Navigation > Search class** (`Ctrl+N`) to search
for class names containing `PacketType`, `CommandType`, `MaverickPacket`, or `Command`.

Once you locate an enum class, you will see entries like:

```java
public enum PacketType {
    DATA(0x01),
    COMMAND(0x02),
    ...
}
```

---

### Step 5 — Cross-reference with whoop-vault r52

The external community reference **whoop-vault** (commit r52 in the vault's git history) contains
a mapped enum table for Maverick packet types and command IDs derived from a prior firmware
version. Use it as a cross-reference to:

1. Confirm your enum names and values match or diverge from r52.
2. Identify any new packet types or command IDs introduced in the WHOOP 5.0 firmware.
3. Understand the expected field layout for command payloads.

> **Cite/link only — never vendor.** Do not copy the r52 content into this repository.
> Reference: [whoop-vault](https://github.com/skyleronken/whoop-vault) commit r52 (community
> project — confirm URL at time of use; this is an external, non-affiliated reference).

---

### Step 6 — Record findings under the locked legal recording rule

**LOCKED RULE (D-04 / DISCLAIMER §2):**

You MAY record:
- Enum class names (e.g. `PacketType`, `CommandId`)
- Enum member names (e.g. `HEART_RATE_NOTIFICATION`)
- The numeric values bound to each member (e.g. `0x20`)
- Whether they match or differ from whoop-vault r52

You MUST NOT record or commit:
- Decompiled method bodies, constructor code, or any logic beyond the enum declarations
- JADX project output files (`.jadx/` or similar output directories)
- The pulled APK files (`base.apk`, `split_config.*.apk`)
- Any proprietary class structure, field names from non-enum classes, or string literals from
  application logic

Record your findings in a local notes file (e.g. `re/capture/samples/apk/notes-draft.md`) that
lives under `samples/apk/` and is gitignored. Transfer only the enum names + values to a
committed notes file under `docs/` or `FINDINGS_5.md` in a later phase.

---

## APKMirror Fallback (D-04)

If `adb pull` is blocked (device not debuggable, USB restrictions, or app not installed),
APKMirror (`https://www.apkmirror.com`) provides a community-uploaded archive of WHOOP APKs.

**Use this fallback ONLY if `adb pull` is unavailable.** The same locked recording rule applies:
enum names + numeric values only; no decompiled source committed. Download `base.apk` for the
version matching your WHOOP strap's firmware (note the firmware version from the WHOOP app's
**About** screen before you start).

---

## JRE Troubleshooting (Pitfall 5)

If `jadx-gui` bounces on launch or shows a Java error similar to:

```
No Java runtime present, requesting install.
```
or
```
Unable to locate a Java Runtime
```

The `openjdk` keg-only symlink or `JAVA_HOME` is not configured. Brew installs `openjdk` as
keg-only and prints a caveat at install time:

```
For the system Java wrappers to find this JDK, symlink it with
  sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk \
    /Library/Java/JavaVirtualMachines/openjdk.jdk
```

Run that symlink command, or set `JAVA_HOME` and `PATH` in your shell profile:

```bash
export JAVA_HOME="$(brew --prefix openjdk)"
export PATH="$JAVA_HOME/bin:$PATH"
```

Verify with:

```bash
java -version
# Should print: openjdk version "26..." (or similar)
```

Then re-run `bash scripts/check-tools.sh` to confirm the java check passes. If `check-tools.sh`
still fails the java check after the symlink, re-read the `brew install openjdk` caveats:

```bash
brew info openjdk | grep -A 5 "Caveats"
```

---

## How to Verify It Worked

After completing the steps, confirm:

1. `ls re/capture/samples/apk/` shows `base.apk` (and any splits).
2. `git status` shows the APK files as **ignored** (not untracked, not staged).
3. JADX-GUI has loaded the APK and you can navigate the package tree to a class containing
   `PacketType` or `CommandId` enum entries with numeric values.
4. You have notes of at least some enum names + values to compare against whoop-vault r52.

---

## Key Links

- `re/capture/wireshark.md` — TOOL-04 runbook; use this to correlate ATT command bytes with
  the enum values you locate here
- `re/capture/samples/apk/` — pulled APK files live here (gitignored, never committed)
- `FINDINGS.md` — 4.0 protocol reference; frame format and command surface to cross-reference
- `DISCLAIMER.md §2` — legal boundary: no decompiled source, no APKs, no proprietary material
  in the repo; enum names + values are uncopyrightable factual information
- whoop-vault r52 — external community reference for Maverick enum map (cite, do not vendor)
