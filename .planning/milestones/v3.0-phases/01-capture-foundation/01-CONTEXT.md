# Phase 1: Capture Foundation - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Install and verify the **passive BLE capture toolchain** and produce reproducible,
evidence-backed capture workflows in the repo. This phase delivers the ability to
capture, extract, and view WHOOP 5.0 BLE traffic from two independent sources:

1. **iOS** — Apple PacketLogger on Mac with iPhone tethered (`iOSBluetoothLogging.mobileconfig`
   installed), sniffing the official WHOOP app ↔ 5.0 strap session → `.pklg`.
2. **Android** — `btsnoop_hci.log` via Developer Options HCI logging + `adb bugreport` extraction → `.btsnoop`.

Plus the analysis tools to read those captures:
- **Wireshark 4.4.x** — open `.pklg` and `.btsnoop`, filter to the ATT/GATT layer, see WHOOP custom service traffic.
- **JADX-GUI 1.5.1** — decompile the official WHOOP Android APK to reference Maverick / packet-type enum definitions (cross-referencing whoop-vault's r52 map).

**This is a tooling + documentation + evidence phase, not a software-building phase.**
The deliverable is a working, version-pinned toolchain; reproducible written workflows;
and committed evidence proving each tool produces real WHOOP traffic.

**Note on the existing `re/` directory:** the 4.0 fork's `re/` holds the *active* RE harness
(Bleak scripts that connect directly from the Mac). This phase adds the complementary
*passive* HCI capture path (sniffing the official app's traffic). They are different,
complementary techniques — passive capture observes what the official app does; active
scripting reproduces it. No existing capture-workflow docs exist in the repo (confirmed
by grep — zero mentions of packetlogger/btsnoop/wireshark/jadx outside `.planning/`).

**Out of scope for this phase** (belongs to later phases): GATT enumeration, bonding
replication, frame/CRC validation, decoding biometrics, schema work. Phase 1 stops at
"I can capture and view raw traffic from both sources and read the official enums."

</domain>

<decisions>
## Implementation Decisions

### Repo Layout (D-01)
- **D-01:** Capture workflow docs and sample artifacts live under a new **`re/capture/`** tree,
  co-located with the existing `re/` active-RE scripts (both are "how I get data off the device").
  Per-source workflow docs:
  - `re/capture/ios-packetlogger.md`
  - `re/capture/android-btsnoop.md`
  - `re/capture/wireshark.md`
  - `re/capture/jadx.md`
  - A `re/capture/README.md` index tying the four together.
  Raw capture binaries live in **`re/capture/samples/`** and are **gitignored** (see D-02).
  Rationale: capture runbooks are operational RE material adjacent to the Bleak scripts, NOT
  architecture design docs (those live in `docs/specs/`). Co-locating keeps the whole RE surface
  discoverable in one tree, and Phases 2–3 get a natural home for their capture sessions.

### Capture Privacy / Commit Policy (D-02)
- **D-02:** **Gitignore raw captures; commit redacted evidence only.** Raw `.pklg` / `.btsnoop`
  files (binary blobs that may contain device identifiers and SMP/bonding material) stay local
  and are gitignored under `re/capture/samples/`. What gets committed as the auditable evidence:
  - **Redacted hex excerpts** showing the WHOOP custom service traffic (ATT/GATT layer).
  - **SHA256 checksums** of each raw capture.
  - **Capture metadata** — firmware version, capture date, tool + version used, source (iOS/Android).
  This is the safest legal footing (no proprietary/raw traffic in the public repo) and avoids
  binary bloat while still proving each success criterion is met.

### Toolchain Setup Automation (D-03)
- **D-03:** **Maximal automation.** Provide a `Brewfile` + a `scripts/check-tools.sh`
  version-asserter that installs and verifies everything CLI/brew-installable:
  - `wireshark` (pin 4.4.x), `jadx` (pin 1.5.1), `android-platform-tools` (adb),
    `libimobiledevice` (iOS device interaction), plus any tshark/CLI helpers.
  - `scripts/check-tools.sh` asserts the **pinned versions** and exits non-zero on mismatch
    so setup is reproducible and verifiable.
  - **Irreducible manual step (known constraint):** the iOS side cannot be fully scripted —
    installing the `iOSBluetoothLogging.mobileconfig` profile and pairing the iPhone to the Mac
    in Xcode require Apple UI interaction. The plan automates everything automatable and
    *script-verifies* the rest; the manual iOS steps are documented precisely in
    `re/capture/ios-packetlogger.md`.

### APK Sourcing + JADX Output Handling (D-04)
- **D-04:** **Source the WHOOP Android APK via `adb pull` from the user's own installed copy**
  (matches the device's actual firmware version — cleanest legal footing: your own copy of your
  own app). Document the `adb pull` procedure in `re/capture/jadx.md`.
  - **Legal recording rule (locked):** record only packet-type / command **enum names and numeric
    values** in notes (cross-referencing whoop-vault's r52 map). **Never commit decompiled source**
    or any proprietary material. The decompiled APK and JADX project output are gitignored.
  - APKMirror is documented as a fallback only if `adb pull` is blocked, with the same recording rule.

### Claude's Discretion
- Exact filenames/structure within each `re/capture/*.md` doc (as long as the four sources are each covered).
- The precise format of redacted hex excerpts and the metadata schema (e.g., a small YAML/JSON sidecar per capture).
- How `scripts/check-tools.sh` reports results (table, checklist, etc.) and whether it's bash/python.
- Capture session naming convention and where firmware version is read from.
- Whether the `.gitignore` rules are added globally or scoped to `re/capture/samples/`.
- How each success criterion is mapped to its committed evidence (a checklist doc is fine).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project framing & legal boundary
- `.planning/PROJECT.md` — clean-fork strategy; iOS PacketLogger = primary, Android btsnoop = secondary; legal frame (17 U.S.C. §1201(f), own device/own data, no proprietary material reproduced); 4.0 custom service UUID `61080001-8d6d-82b8-614a-1c8cb0f8dcc6` (first UUID to look for on 5.0).
- `.planning/REQUIREMENTS.md` — TOOL-01..TOOL-04 (this phase); Definition of Done.
- `.planning/ROADMAP.md` §"Phase 1: Capture Foundation" — goal + 4 success criteria.
- `DISCLAIMER.md` — repo legal disclaimer; the "no proprietary material reproduced" rule that governs D-02 and D-04.

### Protocol reference (4.0 baseline — what to look for in 5.0 captures)
- `FINDINGS.md` — 4.0 protocol reference (framing `[0xAA][len u16 LE][crc8][type][seq][cmd][payload][crc32 LE]`, CRC8 poly 0x07, CRC32 zlib). Context for what "WHOOP custom service traffic" looks like in Wireshark.
- `protocol/whoop_protocol.json` — canonical 4.0 decode schema; the structure Phase 3+ will validate against.

### Existing RE tooling (the active-capture counterpart to this phase's passive capture)
- `re/README.md` and `re/re_harness.py` — existing active Bleak RE harness; new `re/capture/` sits alongside it.
- `re/gatt_dump.py`, `re/standard_ble.py` — examples of how the project already talks to the strap (reference for conventions, not reused directly here).

### Codebase maps (repo conventions)
- `.planning/codebase/STRUCTURE.md` — repo layout, "Where to Add New Code" table (new RE script → `re/`).
- `.planning/codebase/STACK.md` — toolchain context; existing scripts/ utilities pattern (`scripts/sync-schema.sh`, etc.).

### External reference (not in repo — cite, do not vendor)
- **whoop-vault r52 map** — external community reference for Maverick / packet-type enums; used to cross-reference JADX findings (D-04). Link/cite only; do not vendor proprietary content.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/` directory already hosts utility scripts (`sync-schema.sh`, `gen_golden.py`) — the new `Brewfile` + `scripts/check-tools.sh` (D-03) follow this established pattern.
- `re/device_local.example.py` — existing pattern for local-only config that's gitignored; mirror this convention for the gitignored `re/capture/samples/` raw artifacts (D-02).

### Established Patterns
- Repo already separates committed source from local/secret artifacts (`Secrets.xcconfig` gitignored, `device_local.py` gitignored). D-02/D-04 extend the same "raw/proprietary stays local, redacted evidence committed" pattern.
- `re/` is the documented home for RE scripts (per STRUCTURE.md "Where to Add New Code"). `re/capture/` is a natural sub-home.

### Integration Points
- This phase produces **inputs** for later phases: Phase 2 (GATT survey) and Phase 3 (framing confirmation) consume the captures and read tools set up here. The `re/capture/` layout and metadata convention chosen now is the contract those phases build on.
- No code is modified in existing packages — this phase adds new files only (`re/capture/**`, `Brewfile`, `scripts/check-tools.sh`, `.gitignore` rules).

</code_context>

<specifics>
## Specific Ideas

- Tool versions are pinned and must be asserted, not just installed: **Wireshark 4.4.x**, **JADX-GUI 1.5.1**.
- Evidence must demonstrate **non-empty traces** — success is "sees ATT-layer WHOOP custom service traffic," not "tool launches."
- Two independent capture sources (iOS + Android) are both required so later phases can cross-reference and fill gaps.
- The first concrete thing to look for in a 5.0 capture is whether the strap advertises the legacy `61080001-…` service or a new `fd4b0001-…` prefix (this is Phase 2's job, but capture evidence should make the service UUID visible).

</specifics>

<deferred>
## Deferred Ideas

- **GATT service/characteristic enumeration & UUID confirmation** → Phase 2 (PROTO-01, PROTO-03).
- **Bonding without the official app** → Phase 2 (PROTO-02).
- **Frame/CRC validation against captured 5.0 frames** → Phase 3 (PROTO-04, PROTO-05).
- **Decoding biometrics + schema authoring** → Phase 4.
- **Automating the iOS mobileconfig install** — not possible (Apple UI requirement); documented as a manual step, not pursued.

None of these were scope creep — they surfaced naturally as the boundary of where Phase 1 stops.

</deferred>

---

*Phase: 01-capture-foundation*
*Context gathered: 2026-05-30*
