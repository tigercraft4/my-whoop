# Phase 1: Capture Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 01-capture-foundation
**Areas discussed:** Repo layout for captures + docs, Raw capture commit/privacy policy, Toolchain setup automation, APK sourcing + JADX output handling

---

## Repo Layout for Captures + Docs

| Option | Description | Selected |
|--------|-------------|----------|
| `re/capture/` (docs + samples/) | New re/capture/ dir holds per-source workflow docs; raw files in re/capture/samples/ (gitignored). All RE material in one tree. | ✓ |
| `docs/capture/` + `re/captures/` | Prose under docs/capture/, raw binaries under re/captures/ (gitignored). Separates prose from artifacts. | |
| Top-level `CAPTURE.md` | Single top-level runbook + captures/ dir. Simplest, but mixes four workflows into one file. | |

**User's choice:** Asked for a recommendation ("o que recomendas?") → recommended `re/capture/` (docs + gitignored samples/), accepted.
**Notes:** Rationale — capture runbooks are operational RE material adjacent to the existing `re/` Bleak scripts, not architecture design docs (docs/specs/). Co-locating keeps the whole RE surface discoverable and gives Phases 2–3 a home for their capture sessions. Per-source docs: ios-packetlogger.md, android-btsnoop.md, wireshark.md, jadx.md + README index.

---

## Raw Capture Commit / Privacy Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Gitignore raw + commit redacted evidence | Raw stays local (gitignored); commit redacted hex excerpts + SHA256 + capture metadata. Safest legally, no bloat. | ✓ |
| Commit small representative samples | Commit a few small raw captures, gitignore large ones. More reproducible, commits binary BLE traffic. | |
| Commit all raw captures | Full raw captures committed. Largest footprint and most privacy/legal exposure. | |

**User's choice:** Gitignore raw + commit redacted evidence.
**Notes:** Raw `.pklg`/`.btsnoop` may contain device identifiers and SMP/bonding material. Committed evidence = redacted hex excerpts showing WHOOP service traffic + SHA256 checksums + metadata (firmware, date, tool version, source).

---

## Toolchain Setup Automation

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid: Brewfile + verify script + manual iOS steps | Brewfile for CLI tools + check-tools.sh + documented manual iOS section. | |
| Manual checklist only | Pure markdown install checklist with version-check commands run by hand. | |
| Maximal automation | Brewfile + script that does everything brew/CLI can, automate as much of iOS as possible. | ✓ |

**User's choice:** Maximal automation.
**Notes:** Honored intent — Brewfile + `scripts/check-tools.sh` version-asserter for wireshark (4.4.x), jadx (1.5.1), android-platform-tools, libimobiledevice. Flagged the irreducible manual constraint: the `iOSBluetoothLogging.mobileconfig` install + Xcode device pairing cannot be scripted (Apple UI requirement). Plan automates everything automatable and script-verifies the rest; manual iOS steps documented precisely. User accepted this constraint (did not re-ask).

---

## APK Sourcing + JADX Output Handling

| Option | Description | Selected |
|--------|-------------|----------|
| adb pull own device; record enum names/values only | Pull APK from own installed copy (matches firmware); record enum names+values in notes only; never commit decompiled source. | ✓ |
| APKMirror pinned version; same recording rule | Download pinned version from APKMirror; same recording rule. | |
| Either source; rule is the boundary | Source doesn't matter; locked rule is no committed decompiled source. | |

**User's choice:** adb pull own device; record enum names/values only.
**Notes:** Cleanest legal footing — your own copy of your own app, matching your device's firmware. APKMirror documented as fallback only if adb pull is blocked. Legal rule locked: only packet-type/command enum names + numeric values recorded (cross-ref whoop-vault r52); decompiled source and JADX project output gitignored, never committed.

---

## Claude's Discretion

- Exact filenames/structure within each `re/capture/*.md` doc.
- Format of redacted hex excerpts and the per-capture metadata schema.
- Implementation language/format of `scripts/check-tools.sh` and how it reports results.
- Capture session naming convention; where firmware version is read from.
- Scope of `.gitignore` rules (global vs scoped to `re/capture/samples/`).
- How each success criterion maps to committed evidence (a checklist doc is acceptable).

## Deferred Ideas

- GATT service/characteristic enumeration & UUID confirmation → Phase 2.
- Bonding without the official app → Phase 2.
- Frame/CRC validation against captured 5.0 frames → Phase 3.
- Decoding biometrics + schema authoring → Phase 4.
- Automating the iOS mobileconfig install — not possible (Apple UI requirement); documented as manual.
