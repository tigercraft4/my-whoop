---
phase: 01-capture-foundation
plan: "02"
subsystem: documentation
tags: [wireshark, tshark, jadx, adb, ble, btatt, gatt, reverse-engineering, runbook]

# Dependency graph
requires:
  - phase: 01-01
    provides: "Brewfile, check-tools.sh, .gitignore rules, re/capture/ directory scaffold with evidence/ and samples/"

provides:
  - "re/capture/wireshark.md — TOOL-04 runbook: open .pklg/.btsnoop, filter ATT/GATT, prove non-empty WHOOP traffic, produce D-02 redacted evidence"
  - "re/capture/jadx.md — TOOL-03 runbook: adb pull all APK splits, open in JADX-GUI, navigate packet-type/command enums, cross-reference r52, locked legal recording rule"

affects: [02-protocol-survey, 03-crc-gate, re-analysis, jadx-findings]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Runbook doc convention: dated header, prerequisites, numbered steps, how-to-verify non-empty-trace check"
    - "D-02 evidence pattern: sha256 + redacted hex excerpt + metadata sidecar under re/capture/evidence/"
    - "D-04 locked recording rule: enum names + numeric values only; APK + JADX output gitignored"

key-files:
  created:
    - re/capture/wireshark.md
    - re/capture/jadx.md
  modified: []

key-decisions:
  - "Version floor for Wireshark (>=4.4.0) and JADX (>=1.5.1) confirmed acceptable — brew delivers 4.6.6/1.5.5 which are behaviourally equivalent for ATT/GATT work"
  - "Assumption A6 (btatt / btl2cap.cid filter syntax) tagged inline in wireshark.md — developer must confirm against installed 4.6.6"
  - "Assumption A4 (WHOOP package id) tagged inline in jadx.md — developer confirms live via pm list packages, never hardcoded"

patterns-established:
  - "Runbook pattern: each file has a dated/versioned header, Prerequisites, numbered Steps, How to Verify It Worked, and Troubleshooting"
  - "Evidence pattern: every committed evidence bundle = .sha256 + .hex (redacted) + .meta.yaml; raw captures stay in gitignored samples/"
  - "Legal recording pattern: jadx.md establishes enum-only recording rule as the locked template for all JADX-based findings"

requirements-completed: [TOOL-03, TOOL-04]

# Metrics
duration: 4min
completed: 2026-05-30
---

# Phase 01 Plan 02: Capture Analysis Runbooks Summary

**Wireshark/tshark TOOL-04 runbook and JADX-GUI TOOL-03 runbook — ATT/GATT filter workflow + APK enum navigation under locked D-04 legal recording rule**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-30T13:40:03Z
- **Completed:** 2026-05-30T13:44:11Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- `re/capture/wireshark.md` — complete TOOL-04 runbook: open `.pklg`/`.btsnoop`, filter with `btatt` and `btl2cap.cid == 0x0004`, prove non-empty WHOOP traffic via headless `tshark -Y btatt`, grep for WHOOP custom service UUID (`fd4b0001` / `61080001` / `8d6d`), produce D-02 evidence (sha256 + redacted hex + metadata sidecar) with BD_ADDR / SMP scrub step before commit (DISCLAIMER §2)
- `re/capture/jadx.md` — complete TOOL-03 runbook: confirm package id live via `pm list packages | grep whoop` (not hardcoded — A4), pull all split APK paths via `pm path` loop to `re/capture/samples/apk/`, open `base.apk` in JADX-GUI, navigate Maverick / packet-type enums, cross-reference whoop-vault r52, locked legal recording rule (enum names + values only, never commit source), APKMirror fallback documented, JRE/openjdk keg-only troubleshooting note (Pitfall 5)
- Threat mitigations T-01-05 and T-01-06 both implemented inline (redaction + BD_ADDR scrub in wireshark.md; locked recording rule in jadx.md)

## Task Commits

Each task was committed atomically:

1. **Task 1: Write re/capture/wireshark.md (TOOL-04 runbook)** - `9ed55f0` (docs)
2. **Task 2: Write re/capture/jadx.md (TOOL-03 runbook)** - `c79456d` (docs)

**Plan metadata:** see self-check below

## Files Created/Modified

- `re/capture/wireshark.md` — TOOL-04 operational runbook: Wireshark GUI open + ATT/GATT filter + headless tshark verification + D-02 evidence production (sha256 + redacted hex + metadata sidecar)
- `re/capture/jadx.md` — TOOL-03 operational runbook: adb APK pull (split-aware) + JADX-GUI enum navigation + r52 cross-reference + D-04 locked legal recording rule + JRE troubleshooting

## Decisions Made

- Version floors confirmed acceptable: Wireshark `>= 4.4.0` (brew 4.6.6) and JADX `>= 1.5.1` (brew 1.5.5) are behaviourally equivalent for ATT/GATT analysis. No exact pin needed for Phase 1 goals.
- Assumption A6 (btatt / btl2cap.cid filter syntax) is tagged inline in wireshark.md — developer confirms against installed Wireshark when first using the runbook.
- Assumption A4 (WHOOP package id `com.whoop.android`) is explicitly NOT hardcoded in jadx.md — developer confirms live on device via `pm list packages`.

## Deviations from Plan

None — plan executed exactly as written. Both runbooks follow the specified runbook doc convention (dated header, prerequisites, numbered steps, how-to-verify check). All code examples match the exact commands from RESEARCH §Code Examples. All acceptance criteria verified via automated checks.

## Issues Encountered

None. The automated verification grep for `sha256sum` matched a non-stub line (alternative `shasum -a 256` command for macOS), not a real stub — confirmed not a placeholder.

## User Setup Required

None — these are documentation-only files. No external service configuration required.

## Next Phase Readiness

- TOOL-03 (JADX) and TOOL-04 (Wireshark) runbooks are complete and satisfy their plan requirements
- All four `re/capture/*.md` runbooks are now in place (ios-packetlogger, android-btsnoop from Plan 01; wireshark, jadx from this plan)
- `re/capture/README.md` will be needed to index the four runbooks — check if Plan 01 created it; if not, it may be needed before Phase 2
- Phase 2 (protocol survey) can consume captures produced by following ios-packetlogger.md/android-btsnoop.md and analysed via wireshark.md/jadx.md

## Known Stubs

None — both runbooks are complete operational procedures with real commands. Placeholder-style text (`<session>`, `<from ideviceinfo...>`) are correctly labelled template tokens for the developer to fill in at execution time, not stubs blocking the runbook's purpose.

## Threat Flags

No new threat surface introduced — these are documentation files with no network endpoints, auth paths, file access patterns, or schema changes. Existing threats T-01-05 and T-01-06 from the plan's threat model are mitigated inline in the runbooks (BD_ADDR/SMP scrub step and locked recording rule respectively).

---
*Phase: 01-capture-foundation*
*Completed: 2026-05-30*
