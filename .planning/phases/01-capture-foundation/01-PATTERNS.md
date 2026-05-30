# Phase 1: Capture Foundation - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 9 (7 new docs/scripts + Brewfile + .gitignore additions)
**Analogs found:** 7 / 9 (2 documentation files have no in-repo runbook analog — markdown-doc conventions provided instead)

> **Phase nature:** This is a tooling + documentation + evidence phase, NOT a software-building
> phase. "Role" and "data flow" are mapped to the operational equivalents: docs are
> `documentation / runbook`, the script is `utility / verify-on-host`, config files are
> `config / declarative`. The closest analogs are the repo's existing bash utility
> (`scripts/sync-schema.sh`), the gitignore policy, and the gitignored-local-config convention
> (`re/device_local.example.py`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/check-tools.sh` | utility (verify) | request-response (assert→exit code) | `scripts/sync-schema.sh` | exact (same dir, same bash idiom) |
| `Brewfile` | config | declarative | RESEARCH §Standard Stack sketch (no repo Brewfile) | no-analog (use research sketch) |
| `.gitignore` (additions) | config | declarative | existing `.gitignore` (apk/, device_local.py, fixtures/) | exact (extend in place) |
| `re/capture/samples/.gitkeep` + ignore | config/local-artifact | file-I/O (local only) | `re/device_local.example.py` + `apk/` ignore rule | exact (same "raw stays local" pattern) |
| `re/capture/README.md` | documentation (index) | n/a | `re/README.md` | role-match (RE index doc) |
| `re/capture/ios-packetlogger.md` | documentation (runbook) | n/a | `docs/specs/...-debugging-runbook.md` (style) | role-match (runbook prose) |
| `re/capture/android-btsnoop.md` | documentation (runbook) | n/a | `docs/specs/...-debugging-runbook.md` (style) | role-match |
| `re/capture/wireshark.md` | documentation (runbook) | n/a | RESEARCH §Code Examples (tshark snippets) | partial (commands from research) |
| `re/capture/jadx.md` | documentation (runbook) | n/a | RESEARCH §Code Examples (adb/jadx snippets) | partial (commands from research) |

## Pattern Assignments

### `scripts/check-tools.sh` (utility, verify-on-host)

**Analog:** `scripts/sync-schema.sh` — the ONLY existing bash utility in the repo; it defines
the project's canonical script conventions. Copy these directly.

**Shebang + safety + run-from-anywhere root** (`scripts/sync-schema.sh` lines 1-4):
```bash
#!/usr/bin/env bash
# Sync the canonical decode schema into its consumers. Run from anywhere.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
```
**Copy verbatim:** the `#!/usr/bin/env bash` shebang, a one-line `#` purpose comment, the
`set -euo pipefail` line, and the `ROOT="$(cd "$(dirname "$0")/.." && pwd)"` idiom so the
script works regardless of caller cwd. Every new path in `check-tools.sh` should be anchored
on `$ROOT` exactly as `sync-schema.sh` anchors `$CANON`/`$PKG` on it.

**Graceful-degradation / optional-target pattern** (`scripts/sync-schema.sh` lines 12-17):
```bash
if [ -f "$HOMESERVER" ]; then
  cp "$CANON" "$HOMESERVER"
  echo "synced → $HOMESERVER  ..."
else
  echo "home-server not found at $HOMESERVER (set HOME_SERVER_REPO to override); skipped server sync"
fi
```
**Reuse this shape** for the PacketLogger / mobileconfig presence checks: present → `ok`,
absent → a `WARN` line (NOT a `FAIL`), because those are the locked irreducible-manual-step
tools (D-03). This mirrors how `sync-schema.sh` treats the optional home-server target as a
skip, not an error. The env-var override idiom (`${HOME_SERVER_REPO:-$HOME/...}`) is also the
pattern to copy for any overridable path.

**Version-floor assertion core** (from RESEARCH §Pattern 1 — no repo analog, this is new logic):
```bash
fail=0
assert_min() { # name actual min
  if [ "$(printf '%s\n%s' "$3" "$2" | sort -V | head -1)" != "$3" ]; then
    echo "FAIL $1: $2 < required $3"; fail=1
  else echo "ok   $1: $2 (>= $3)"; fi
}
assert_min wireshark "$(tshark --version | sed -n '1s/.* \([0-9.]*\).*/\1/p')" 4.4.0
assert_min jadx      "$(jadx --version 2>/dev/null)" 1.5.1
assert_min adb       "$(adb --version | sed -n '1s/.* version \([0-9.]*\).*/\1/p')" 35.0.0
exit $fail
```
**Exit-code contract:** accumulate failures in `fail`, `exit $fail` at the end (non-zero on any
mismatch per D-03). PacketLogger/mobileconfig checks must NOT touch `fail` — they print `WARN`
only. Note: with `set -euo pipefail`, guard `command -v X >/dev/null && ... || ...` carefully so
a missing tool doesn't abort the whole script before later checks run.

---

### `Brewfile` (config, declarative)

**Analog:** None in repo (no existing Brewfile). Use the RESEARCH §Standard Stack sketch as the
source of truth — package names are VERIFIED against the live brew index this session.

**Pattern to copy** (RESEARCH lines 110-122):
```ruby
# Brewfile
cask "wireshark-app"          # GUI 4.6.6 (post-rename token; NOT cask "wireshark")
brew "wireshark"              # CLI: tshark/editcap
brew "jadx"                   # provides jadx + jadx-gui
cask "android-platform-tools" # adb/fastboot
brew "libimobiledevice"       # ideviceinfo/idevice_id
brew "openjdk"                # JRE for jadx (keg-only — note caveat in jadx.md)
brew "blueutil"               # optional Mac BT CLI
```
**Load-bearing gotcha:** the GUI cask token is `wireshark-app`, NOT `wireshark` (which is the
CLI-only formula). A `cask "wireshark"` line installs the wrong thing / fails. Comment each line
with its purpose, mirroring how `scripts/sync-schema.sh` and `.gitignore` annotate every entry
with a `#` rationale (the repo strongly favors self-documenting config).

---

### `.gitignore` additions (config, declarative)

**Analog:** the existing `.gitignore` — extend it IN PLACE, do not create a new ignore file.
The repo already encodes the exact "raw/proprietary stays local, redacted evidence committed"
policy that D-02/D-04 require.

**Existing precedent to mirror** (`.gitignore` lines 25-26, 52-57, 70-71):
```gitignore
# Decompiled proprietary app — DO NOT publish
apk/
...
# Secrets (real values — never commit; Secrets.example.xcconfig IS committed as a template)
ios/OpenWhoop/Config/Secrets.xcconfig
# Personal device identity for RE scripts (real BLE UUID/MAC/serial — never commit;
# device_local.example.py IS committed as a template)
re/device_local.py
...
# Mac-side device-soak captures (gitignored; not the committed hist_biometric.bin fixture)
fixtures/soak_*.bin
```
**Copy the annotation style exactly:** a `#` block comment stating WHY it's ignored AND noting
the committed counterpart that IS kept. The repo's established idiom is "ignore the raw, keep the
redacted/template, and say so in a comment." New rules to add (per D-02/D-04):
```gitignore
# Raw BLE/HCI captures — kept LOCAL (may contain device IDs / SMP bonding material).
# Redacted hex excerpts + SHA256 + metadata under re/capture/evidence/ ARE committed.
re/capture/samples/*
!re/capture/samples/.gitkeep
# Decompiled WHOOP APK / JADX project output — DO NOT publish (DISCLAIMER §2; D-04).
re/capture/samples/apk/
```
**Note:** `apk/` is already ignored at line 26; confirm whether the new APK lands under
`re/capture/samples/apk/` (covered by the `samples/*` rule above) or needs a scoped rule. The
`!...gitkeep` negation mirrors the existing `!server/ingest/tests/fixtures/...` and
`!.planning/research/` negation idiom (lines 13, 33) — commit the dir, ignore its contents.

---

### `re/capture/samples/` local-artifact convention (config, file-I/O local-only)

**Analog:** `re/device_local.example.py` (committed template) + the `re/device_local.py` ignore
rule. This is the canonical "local-only data, committed template/placeholder" pattern.

**Pattern** (`re/device_local.example.py` lines 1-2):
```python
# Copy to re/device_local.py (gitignored) and fill in your strap's real values.
# These are personal identifiers — device_local.py must never be committed.
```
**Apply:** the `samples/.gitkeep` (or a `samples/README.md` placeholder) should carry the same
kind of header comment — "raw captures live here, gitignored, never committed; see
`re/capture/README.md` for the redaction workflow." The committed-template-beside-ignored-real
pattern is the repo's established way to keep a dir present and self-documenting while its real
contents stay local.

---

### `re/capture/README.md` (documentation, index)

**Analog:** `re/README.md` — the existing RE index doc. New `re/capture/README.md` sits one level
down and should adopt the same voice.

**Pattern** (`re/README.md` lines 1-11): short title, one-paragraph purpose, a pointer to the
authoritative reference (`../FINDINGS.md`), and a bulleted list of the sub-pieces with one-line
descriptions, explicitly noting what is/isn't committed and why.
```markdown
# Reverse-engineering history

Scripts and notes from decoding the WHOOP 4.0 BLE protocol. The authoritative reference is
`../FINDINGS.md`. Several scripts import third-party clones that are intentionally **not**
committed (see root `.gitignore`):

- `whoomp/` — github.com/jogolden/whoomp ...
```
**Apply:** `re/capture/README.md` = a 4-source index (ios-packetlogger / android-btsnoop /
wireshark / jadx), a pointer to `../README.md` and `../../FINDINGS.md` as upstream refs, the
evidence checklist (success-criterion → committed artifact), and an explicit "raw under
`samples/` is gitignored; redacted evidence under `evidence/` is committed" note — echoing how
`re/README.md` calls out the gitignored third-party clones.

---

### `re/capture/{ios-packetlogger,android-btsnoop,wireshark,jadx}.md` (documentation, runbook)

**Analog (style):** `docs/specs/2026-05-25-debugging-runbook.md` is the repo's existing runbook-
style doc (operational, step-by-step). The four capture docs are runbooks of the same family,
just living under `re/capture/` per D-01 (operational RE material, not architecture specs).

**Command content source:** RESEARCH §Code Examples (lines 295-332) provides the concrete,
copy-ready command blocks for each runbook:
- **wireshark.md** ← `tshark -r ... -Y btatt` filter/count snippets (RESEARCH lines 298-307) and
  the redact+SHA256+hex-excerpt block (lines 310-316).
- **android-btsnoop.md** ← `adb bugreport` → unzip → locate `btsnoop*` flow (RESEARCH Pitfall 3,
  lines 277-282).
- **jadx.md** ← `adb shell pm path` multi-split pull + `jadx-gui base.apk` (RESEARCH lines
  318-326); plus the locked legal recording rule (enum names+values only).
- **ios-packetlogger.md** ← the manual mobileconfig + Xcode pairing steps (RESEARCH Pitfall 2,
  lines 271-275); flag the irreducible-manual `checkpoint:human`.

**Apply:** each runbook should follow the repo doc convention of a dated/versioned header, a
"prerequisites" section, numbered reproducible steps, and a "how to verify it worked"
(non-empty-trace) check — matching the operational tone of the existing `docs/specs/*runbook*`
and the metadata-sidecar pattern below.

---

## Shared Patterns

### Bash script hygiene
**Source:** `scripts/sync-schema.sh` lines 1-4
**Apply to:** `scripts/check-tools.sh`
```bash
#!/usr/bin/env bash
# <one-line purpose>. Run from anywhere.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
```
Every repo script opens this way. `check-tools.sh` MUST match (set -euo pipefail + ROOT anchor).

### Gitignore annotation policy ("ignore raw, keep redacted, say why")
**Source:** `.gitignore` lines 25-26, 52-71
**Apply to:** all `.gitignore` additions for `re/capture/samples/` and APK output
Every ignore rule carries a `#` comment explaining the WHY and naming the committed counterpart
(template/redacted/fixture). The `!path` negation idiom keeps the example/placeholder committed.

### Local-only artifact with committed placeholder
**Source:** `re/device_local.example.py` lines 1-2 + `.gitignore` line 57
**Apply to:** `re/capture/samples/` (gitkeep/README placeholder), gitignored raw captures
"Real data local + committed template/placeholder + header comment stating the rule."

### Capture metadata sidecar (provenance / no-empty-trace)
**Source:** RESEARCH §Pattern 2 (lines 227-241) — no repo analog yet; this phase establishes it
**Apply to:** every committed evidence artifact under `re/capture/evidence/`
```yaml
source: ios            # ios | android
tool: PacketLogger
tool_version: "x.y"
firmware: "<from ideviceinfo / app About>"
captured: 2026-05-30
raw_sha256: <sha256 of the gitignored .pklg in samples/>
custom_service_uuid_seen: "fd4b0001-... | 61080001-... | none-yet"
notes: "ATT/GATT traffic present; N WHOOP-service writes/notifies observed"
```
This sidecar is the contract Phases 2–3 consume (firmware-per-session pre-stages PROTO-16).

### Doc index voice
**Source:** `re/README.md` lines 1-11
**Apply to:** `re/capture/README.md`
Short title → purpose paragraph → pointer to authoritative refs → annotated bullet list noting
what's committed vs gitignored.

## No Analog Found

| File | Role | Data Flow | Reason / Where to source pattern |
|------|------|-----------|----------------------------------|
| `Brewfile` | config | declarative | No existing Brewfile in repo. Use RESEARCH §Standard Stack sketch (lines 110-124); package names + `wireshark-app` rename gotcha are VERIFIED there. |
| `re/capture/wireshark.md` (commands) | documentation | n/a | No in-repo Wireshark/tshark usage. Commands come from RESEARCH §Code Examples (lines 298-316). Verify filter syntax (`btatt`, `btl2cap.cid==0x0004`) against installed 4.6.6 (Assumption A6). |
| `re/capture/jadx.md` (commands) | documentation | n/a | No in-repo JADX/adb usage. Commands from RESEARCH §Code Examples (lines 318-326). Confirm package id `com.whoop.android` live (Assumption A4). |

> The two iOS/Android runbook *narratives* have a style analog (`docs/specs/*runbook*`) but their
> *procedural content* is external (PacketLogger/btsnoop) and tagged `[ASSUMED]` in RESEARCH —
> the planner should treat those steps as confirm-at-execution, not copy-from-codebase.

## Metadata

**Analog search scope:** `scripts/` (bash utilities), `re/` (RE scripts + README +
device_local example), `.gitignore`, `docs/specs/` + `docs/plans/` (doc-style), root config files.
**Files scanned:** ~10 (full repo file tree enumerated; 5 read in full: sync-schema.sh,
.gitignore, device_local.example.py, re/README.md, gen_golden.py header).
**Key finding:** the repo has exactly ONE bash-utility analog (`sync-schema.sh`) and a mature,
consistently-annotated gitignore policy — both map cleanly onto this phase's script + config
deliverables. The four runbook docs draw their procedural content from RESEARCH (web-unavailable,
`[ASSUMED]` tags) rather than the codebase.
**Pattern extraction date:** 2026-05-30
