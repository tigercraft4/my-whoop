---
phase: 01-capture-foundation
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - .gitignore
  - Brewfile
  - re/capture/README.md
  - re/capture/android-btsnoop.md
  - re/capture/ios-packetlogger.md
  - re/capture/jadx.md
  - re/capture/samples/README.md
  - re/capture/wireshark.md
  - scripts/check-tools.sh
findings:
  critical: 2
  warning: 5
  info: 4
  total: 11
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-30
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the Phase 1 Capture Foundation files: shell toolchain checker, Homebrew manifest,
gitignore rules, and four operational runbooks (iOS PacketLogger, Android btsnoop, Wireshark,
JADX). The gitignore coverage for raw capture files is sound — the wildcard `re/capture/samples/*`
correctly swallows every file placed under that directory regardless of extension or filename
(including the real capture found at `re/capture/samples/whoop- iPhone de Francisco.pklg`).
The committed evidence directory is not gitignored.

Two critical findings were identified: (1) the committed `.sha256` file leaks the local
absolute path including the real username and device name, which is a personal identifier
disclosure; (2) the `assert_min` function in `check-tools.sh` silently reports "ok" when
version extraction returns an empty string, meaning a broken tool would be reported as
passing the version floor. Five warnings address runbook inconsistencies that could cause
failed evidence artifacts or privacy leaks in future sessions.

---

## Critical Issues

### CR-01: Committed `.sha256` file discloses personal identifiers

**File:** `re/capture/evidence/2026-05-30-ios.sha256:1`

**Issue:** The `sha256sum` command writes the file hash followed by the full absolute path
of the input file. The committed file contains:

```
60d2d1f8c79e2...  /Users/francisco/Documents/my-whoop/re/capture/samples/whoop- iPhone de Francisco.pklg
```

This embeds: (a) the real username `francisco` from the local filesystem path, (b) the device
name `iPhone de Francisco` — a personal identifier stored in the iOS Bluetooth device name and
therefore a linkable biometric-session identifier. The `.sha256` file is committed and public.
None of the runbooks warn about stripping the path before committing the checksum file.

**Fix:** Produce the checksum with a path-stripped command so only the bare filename (or a
`-` representing stdin) appears in the output:

```bash
# Option A — compute from stdin, outputs hash + " -"
shasum -a 256 < re/capture/samples/<session>.pklg \
  > re/capture/evidence/<session>.sha256

# Option B — cd first so only the basename appears
(cd re/capture/samples && shasum -a 256 <session>.pklg) \
  > re/capture/evidence/<session>.sha256
```

Add an explicit warning to the evidence-production steps in `ios-packetlogger.md` (Step 9),
`android-btsnoop.md` (Step 6), and `wireshark.md` (Step 5a) that the path suffix must be
stripped before committing. The existing committed file should be amended to remove the path.

---

### CR-02: `assert_min` passes silently when version extraction returns empty string

**File:** `scripts/check-tools.sh:16-22`

**Issue:** The version-floor assertion uses:

```bash
if [ "$(printf '%s\n%s' "$min" "$actual" | sort -V | head -1)" != "$min" ]; then
```

On macOS, `sort -V` silently discards empty lines rather than sorting them at position zero.
When `$actual` is empty (version extraction grep fails), `printf` produces two lines — the
min version and a blank — but `sort -V` outputs only the non-blank line. `head -1` therefore
returns `$min`, the comparison `"$min" != "$min"` is false, and the function prints `"ok"`.

This means if `tshark` is installed but `grep -oE '[0-9]+\.[0-9]+\.[0-9]+'` returns no
match (e.g. a future version string format change), the script reports the tool as passing
the version floor rather than failing. The `$WS_VER`, `$JADX_VER`, and `$ADB_VER` extraction
paths are all affected.

Verified on macOS:
```
$ printf '%s\n%s' "4.4.0" "" | sort -V | head -1
4.4.0   ← sort silently dropped the empty line; head -1 returns the min itself
```

**Fix:** Add an explicit empty-string guard in `assert_min`:

```bash
assert_min() {
  local name="$1" actual="$2" min="$3"
  if [ -z "$actual" ]; then
    echo "FAIL $name: version could not be determined (empty output)"
    fail=1
    return
  fi
  if [ "$(printf '%s\n%s' "$min" "$actual" | sort -V | head -1)" != "$min" ]; then
    echo "FAIL $name: $actual < required $min"
    fail=1
  else
    echo "ok   $name: $actual (>= $min)"
  fi
}
```

---

## Warnings

### WR-01: `device_udid` in `ios-packetlogger.md` template instructs committing a device identifier

**File:** `re/capture/ios-packetlogger.md:216`

**Issue:** The Step 9 meta.yaml template includes:

```yaml
device_udid: "<from ideviceinfo -k UniqueDeviceID>"
```

The iOS UDID is a permanent, globally unique hardware identifier. Committing it to a public
repository is a personal data disclosure. The README.md canonical schema does not include
`device_udid` as a field, so this field is both privacy-violating and schema-divergent. A
future follower of the runbook would commit their device UDID.

**Fix:** Remove `device_udid` from the Step 9 template. If device tracking is needed for
reproducibility, record only the device model (`ProductType`, e.g. `iPhone15,3`) which is
not a unique identifier:

```yaml
device_model: "<from ideviceinfo -k ProductType>"   # e.g. iPhone15,3 — not a unique ID
```

---

### WR-02: `.pklg` and `.btsnoop` captures placed outside `re/capture/samples/` are not gitignored

**File:** `.gitignore:75`

**Issue:** The gitignore rule `re/capture/samples/*` only protects captures saved under that
specific directory. A capture saved one level up (`re/capture/session.pklg`), at the repo root
(`session.pklg`), or under `re/` (`re/session.btsnoop`) would be untracked and staggable.
There are no global `*.pklg` or `*.btsnoop` rules.

The runbooks instruct saving to `re/capture/samples/`, but there is no automated enforcement.
A user who deviates — or whose tool (e.g. PacketLogger) defaults to a different save location
— would have no gitignore safety net.

**Fix:** Add global extension rules to `.gitignore` as a belt-and-suspenders layer:

```gitignore
# Belt-and-suspenders: raw BLE captures are sensitive regardless of save location
*.pklg
*.btsnoop
```

These are safe to add because no committed source file uses these extensions; the only
exception is the re/capture/samples/ glob (which already matches first).

---

### WR-03: `ios-packetlogger.md` and `android-btsnoop.md` meta.yaml templates omit Phase 3 required fields

**File:** `re/capture/ios-packetlogger.md:211-223`, `re/capture/android-btsnoop.md:174-184`

**Issue:** The README.md schema (the Phase 2–3 contract) defines two fields that downstream
phase consumers depend on:

- `inner_frame_sof` — Phase 3 framing-gate evidence input
- `att_packet_count` — Phase 3 gate evidence input

Neither `ios-packetlogger.md` Step 9 nor `android-btsnoop.md` Step 6 includes these fields
in their meta.yaml templates. A user following these runbooks would produce a sidecar missing
Phase 3 gate data, silently breaking the downstream contract.

Additionally, `wireshark.md` Step 5c uses the field name `btatt_frame_count` for the packet
count, while the README.md schema uses `att_packet_count`. These are the same datum under
different keys, causing schema fragmentation.

**Fix:** Add the missing fields to both runbook templates:

```yaml
inner_frame_sof: "0xAA — confirmed | not yet checked"
att_packet_count: <integer from tshark ... | wc -l>
```

Standardise the field name to `att_packet_count` (matching the README.md schema) in
`wireshark.md` Step 5c, replacing `btatt_frame_count`.

---

### WR-04: `jadx.md` Step 3 loop uses unquoted command substitution — word-splitting on paths with spaces

**File:** `re/capture/jadx.md:93`

**Issue:** The APK pull loop is:

```bash
for p in $(adb shell pm path com.whoop.android | sed 's/package://'); do
  adb pull "$p" re/capture/samples/apk/
done
```

The command substitution `$(adb shell ...)` is unquoted. If any APK path returned by `adb`
contains spaces (unusual but OEM-possible — e.g. paths with version strings on some Samsung
builds), word-splitting will break the path into multiple tokens and `adb pull` will attempt
to pull non-existent paths. The inner `"$p"` is correctly quoted, but that only protects
against the already-split token.

**Fix:** Use a `while read` loop which handles spaces correctly:

```bash
adb shell pm path com.whoop.android \
  | sed 's/package://' \
  | while IFS= read -r p; do
      adb pull "$p" re/capture/samples/apk/
    done
```

---

### WR-05: `wireshark.md` Step 5c meta.yaml template sets `tool: Wireshark` — inconsistent with README.md schema

**File:** `re/capture/wireshark.md:183`

**Issue:** The README.md canonical schema defines the `tool` field as the *capture* tool:
`PacketLogger | btsnoop`. The `wireshark.md` Step 5c template instead sets `tool: Wireshark`
(the *analysis* tool). This is semantically incorrect and diverges from the schema consumed
by Phase 2/3. The actual committed `2026-05-30-ios.meta.yaml` correctly uses
`tool: PacketLogger`, showing the user deviated from the wireshark.md template — but a
future user following the template verbatim would produce wrong metadata.

**Fix:** Correct the `wireshark.md` Step 5c template:

```yaml
source: ios              # ios | android
tool: PacketLogger       # PacketLogger | btsnoop  (the CAPTURE tool, not the analysis tool)
tool_version: "<from PacketLogger About box or adb --version>"
```

Add a comment clarifying that `tool` refers to the capture tool, not Wireshark.

---

## Info

### IN-01: `ROOT` variable is assigned but never used in `check-tools.sh`

**File:** `scripts/check-tools.sh:4`

**Issue:** `ROOT="$(cd "$(dirname "$0")/.." && pwd)"` is computed on startup but never
referenced. The script checks tools by name via `command -v` and constructs no repo-relative
paths. This is dead code — harmless but misleading (suggests path-relative checks were
planned or were removed).

**Fix:** Remove the `ROOT` assignment, or add a comment explaining why it was preserved
(e.g. reserved for a future repo-relative check).

---

### IN-02: `libimobiledevice` has no version floor in `check-tools.sh`

**File:** `scripts/check-tools.sh:55-59`

**Issue:** All other tools assert a minimum version (`wireshark >= 4.4.0`, `jadx >= 1.5.1`,
`adb >= 35.0.0`). `libimobiledevice` is checked only for presence (`command -v ideviceinfo`).
`ideviceinfo --version` returns a parseable version string (confirmed: `ideviceinfo 1.4.0`),
so a floor could be asserted. Without it, an old incompatible version would be silently
accepted.

**Fix:** Add a version extraction and floor check. The version string format
(`ideviceinfo 1.4.0`) requires a different grep pattern than the other tools:

```bash
if command -v ideviceinfo >/dev/null 2>&1; then
  IMD_VER="$(ideviceinfo --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  assert_min libimobiledevice "$IMD_VER" 1.3.0
else
  echo "FAIL libimobiledevice: ideviceinfo not found — run: brew bundle --file=Brewfile"
  fail=1
fi
```

---

### IN-03: `android-btsnoop.md` and `ios-packetlogger.md` evidence steps use `sha256sum` without macOS fallback note

**File:** `re/capture/android-btsnoop.md:164`, `re/capture/ios-packetlogger.md:201`

**Issue:** Both runbooks present `sha256sum` as the command for producing the SHA256
checksum, with no note that macOS users may need `shasum -a 256` instead. `wireshark.md`
Step 5a correctly documents both and offers the macOS alternative. While `sha256sum` is
present at `/sbin/sha256sum` on modern macOS (Darwin 25.x), older macOS versions do not
include it and the Brewfile does not install GNU coreutils.

**Fix:** Add the macOS fallback note (mirroring `wireshark.md`) to both runbooks at the
sha256 step:

```bash
# macOS: use shasum if sha256sum is not available
shasum -a 256 re/capture/samples/<session>.pklg \
  > re/capture/evidence/<session>.sha256
```

---

### IN-04: `jadx.md` recommends `re/capture/samples/apk/notes-draft.md` as a local scratchpad but this path is gitignored by the directory wildcard

**File:** `re/capture/jadx.md:185`

**Issue:** Step 6 recommends:

> Record your findings in a local notes file (e.g. `re/capture/samples/apk/notes-draft.md`)
> that lives under `samples/apk/` and is gitignored.

The file would indeed be gitignored (covered by `re/capture/samples/*`), but this is
described as intentional. The concern is that the notes file contains enum names + values
meant to be transferred to a committed location — if the user forgets the transfer step, the
notes silently disappear (gitignored, no git history). The runbook should be explicit that the
local notes file is ephemeral and that transfer to a committed doc is mandatory before closing
the session.

**Fix:** Add a warning to Step 6:

```markdown
> **Warning:** `re/capture/samples/apk/notes-draft.md` is gitignored and will not be
> committed. Transfer all enum names + values to a committed file (e.g. `FINDINGS_5.md`
> or `docs/`) before ending the session. Do not rely on the local scratchpad as durable
> storage.
```

---

_Reviewed: 2026-05-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
