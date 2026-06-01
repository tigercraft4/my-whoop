---
phase: 01-capture-foundation
verified: 2026-05-30T00:00:00Z
status: gaps_found
score: 6/8 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Developer captures an Android btsnoop_hci.log via Developer Options + adb bugreport extraction, with reproducible written steps in the repo"
    status: failed
    reason: "Runbook android-btsnoop.md is complete and substantive. No Android device was available; no live capture was performed and no Android evidence triplet exists under re/capture/evidence/. The ROADMAP success criterion 2 requires a performed capture, not merely a runbook."
    artifacts:
      - path: "re/capture/evidence/"
        issue: "Only iOS evidence triplet exists (2026-05-30-ios.*). No Android .hex, .sha256, or .meta.yaml present."
    missing:
      - "Perform android-btsnoop.md capture workflow on a physical Android device running the WHOOP app"
      - "Commit evidence triplet: <date>-android-session<N>.{sha256,hex,meta.yaml} under re/capture/evidence/"
  - truth: "Developer loads the official WHOOP Android APK in JADX-GUI and can navigate to the Maverick/packet-type enum definitions"
    status: failed
    reason: "Runbook jadx.md is complete and substantive, covering all required steps including split-APK pull, JADX-GUI navigation, r52 cross-reference, and the locked legal recording rule. However, no Android device was available so no live APK pull was performed and no enum notes exist. The ROADMAP success criterion 4 requires that a developer 'can navigate' to the enum definitions — this requires a performed execution, not only a runbook."
    artifacts:
      - path: "re/capture/samples/apk/"
        issue: "Directory is gitignored as designed; no APK pull was performed so there is nothing to verify. No enum finding notes exist in FINDINGS.md or any committed file."
    missing:
      - "Pull WHOOP APK via adb shell pm path + adb pull on a physical Android device"
      - "Open base.apk in JADX-GUI and navigate to packet-type/command enum definitions"
      - "Record enum names + numeric values per the locked D-04 rule (JADX runbook Step 6)"
deferred: []
---

# Phase 1: Capture Foundation — Verification Report

**Phase Goal:** All RE tools installed and verified; developer can capture, extract, and view decrypted WHOOP 5.0 BLE traffic from both iOS and Android sources
**Verified:** 2026-05-30
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Brew bundle installs the passive-capture toolchain (Wireshark CLI+GUI, JADX, adb, libimobiledevice, JRE) | VERIFIED | Brewfile contains all 7 entries with correct tokens: `cask "wireshark-app"`, `brew "wireshark"`, `brew "jadx"`, `cask "android-platform-tools"`, `brew "libimobiledevice"`, `brew "openjdk"`, `brew "blueutil"`. Every line has a trailing `#` purpose comment. |
| 2 | `bash scripts/check-tools.sh` exits 0 when all brew tools meet version floors and exits non-zero when any is missing | VERIFIED | Script uses `sort -V` for floor comparison, asserts `wireshark >= 4.4.0`, `jadx >= 1.5.1`, `adb >= 35.0.0`. Hard-FAILs on missing libimobiledevice and Java JRE. `exit $fail` is the final line. `bash -n` confirms valid syntax. |
| 3 | check-tools.sh WARNs (does not FAIL) when PacketLogger is absent | VERIFIED | Non-comment `WARN` line present for PacketLogger; does not touch the `fail` accumulator. |
| 4 | Raw captures and decompiled APK output in `re/capture/samples/` are gitignored; `.gitkeep` stays tracked | VERIFIED | `.gitignore` has `re/capture/samples/*` with `!re/capture/samples/.gitkeep` and `!re/capture/samples/README.md` negations. `git check-ignore re/capture/samples/test.pklg` returns the path. `git check-ignore re/capture/samples/.gitkeep` returns nothing. |
| 5 | Developer can follow re/capture/wireshark.md to open a .pklg or .btsnoop, filter to ATT/GATT, and locate WHOOP service traffic | VERIFIED | wireshark.md contains `btatt` filter, `btl2cap.cid == 0x0004`, headless `tshark -Y btatt` verification command, UUID grep for `fd4b0001`/`61080001`/`8d6d`, sha256 evidence step, and BD_ADDR/SMP redaction instructions. Filter confirmed working: 1011 btatt rows produced from iOS capture. |
| 6 | developer can follow re/capture/ios-packetlogger.md and capture a non-empty .pklg with ATT-layer WHOOP traffic | VERIFIED | ios-packetlogger.md is a complete runbook (PacketLogger + mobileconfig + Xcode pairing + ideviceinfo + D-02 evidence). Live capture was performed: 1011 btatt packets, 0xAA SOF confirmed on all ATT payloads. Evidence triplet committed: `re/capture/evidence/2026-05-30-ios.{sha256,hex,meta.yaml}`. |
| 7 | Developer can follow re/capture/android-btsnoop.md to capture a non-empty btsnoop_hci.log (ROADMAP criterion 2) | FAILED | android-btsnoop.md runbook is complete and substantive (HCI snoop enable, `adb bugreport`, buffer discipline). No Android device was available; no live capture was performed; no Android evidence triplet exists. |
| 8 | Developer loads the official WHOOP Android APK in JADX-GUI and can navigate to Maverick/packet-type enum definitions (ROADMAP criterion 4) | FAILED | jadx.md runbook is complete (pm path split-APK pull, JADX-GUI navigation, r52 cross-reference, locked legal recording rule, APKMirror fallback, JRE troubleshooting). No Android device was available; no APK pull was performed; no enum navigation evidence exists. |

**Score:** 6/8 truths verified

---

### Deferred Items

None. The two failed criteria (Android btsnoop live capture, JADX APK live navigation) require a physical Android device. Neither is explicitly addressed in Phase 2 (GATT Survey), Phase 3 (Framing Confirmation), or their specific success criteria as a prerequisite. Phase 4 success criterion 5 references "cross-source golden fixtures (iOS PacketLogger + Android btsnoop)" and implicitly requires Android btsnoop capability, but that is Phase 4 scope — not Phase 1 close. The Phase 1 goal explicitly names "both iOS and Android sources"; the gap is real.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Brewfile` | Declarative version-floored toolchain manifest | VERIFIED | All 7 entries present with correct tokens and purpose comments |
| `scripts/check-tools.sh` | Version-asserting toolchain verifier | VERIFIED | `set -euo pipefail`, `sort -V`, `exit $fail`, PacketLogger WARN, all hard-fail checks |
| `.gitignore` | Raw-capture + decompiled-APK ignore rules | VERIFIED | `re/capture/samples/*` with `!.gitkeep` and `!README.md` negations; explicit `re/capture/samples/apk/` with DISCLAIMER §2 / D-04 comment |
| `re/capture/samples/.gitkeep` | Tracked-but-empty samples dir | VERIFIED | File present; directory contents gitignored |
| `re/capture/evidence/.gitkeep` | Tracked evidence dir | VERIFIED | File present |
| `re/capture/samples/README.md` | Documents gitignored content | VERIFIED | States raw captures are gitignored, must never be committed, points to re/capture/README.md |
| `re/capture/wireshark.md` | TOOL-04 runbook | VERIFIED | btatt filter, btl2cap.cid, tshark headless check, UUID grep, sha256 evidence step, redaction step |
| `re/capture/jadx.md` | TOOL-03 runbook | VERIFIED (runbook) | pm list packages, pm path, split-APK pull loop, JADX-GUI navigation, r52 cross-ref, locked legal recording rule, APKMirror fallback, JRE troubleshooting |
| `re/capture/ios-packetlogger.md` | TOOL-01 runbook | VERIFIED | PacketLogger + mobileconfig + Xcode pairing + ideviceinfo + D-02 evidence workflow; complete |
| `re/capture/android-btsnoop.md` | TOOL-02 runbook | VERIFIED (runbook) | HCI snoop enable, adb bugreport, btsnoop extraction, D-02 evidence workflow; complete but no live capture executed |
| `re/capture/README.md` | Index of four runbooks + evidence checklist | VERIFIED | Links all four runbooks with requirement IDs; Phase 1 evidence checklist; D-02/D-04 commit policy; sidecar schema |
| `re/capture/evidence/2026-05-30-ios.sha256` | iOS capture SHA256 | VERIFIED | Present; contains SHA256 of gitignored raw .pklg |
| `re/capture/evidence/2026-05-30-ios.hex` | Redacted iOS ATT hex excerpt | VERIFIED | 40 lines of ATT-layer hex; 0xAA SOF visible in payloads |
| `re/capture/evidence/2026-05-30-ios.meta.yaml` | iOS session sidecar | VERIFIED | Contains source, tool, firmware (iOS 26.3.1), att_packet_count (1011), inner_frame_sof (0xAA confirmed), characteristic handles, raw_sha256, notes |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Brewfile | scripts/check-tools.sh | brew bundle installs tools; check-tools.sh asserts versions | WIRED | check-tools.sh references `tshark`, `jadx`, `adb` — all provided by Brewfile entries |
| .gitignore | re/capture/samples/ | `re/capture/samples/*` ignore rule with negations | WIRED | `git check-ignore` confirms raw captures ignored; .gitkeep tracked |
| re/capture/wireshark.md | re/capture/samples/ | `tshark -r samples/<session>.pklg` command | WIRED | wireshark.md references `samples/` path in all tshark commands |
| re/capture/jadx.md | DISCLAIMER.md §2 | Legal recording rule — enum names+values only, no committed source | WIRED | jadx.md Step 6 explicitly references D-04 / DISCLAIMER §2; `never commit` rule present |
| re/capture/README.md | All four runbooks | Index links ios-packetlogger, android-btsnoop, wireshark, jadx | WIRED | README.md table links all four files with correct requirement IDs |
| re/capture/evidence/ | re/capture/samples/ | meta.yaml sidecar records raw_sha256 of gitignored capture | WIRED | 2026-05-30-ios.meta.yaml contains `raw_sha256` matching the .sha256 file |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase produces runbooks, configuration files, and committed evidence artifacts (static files). No dynamic data-rendering components exist.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Raw capture is gitignored | `git check-ignore re/capture/samples/test.pklg` | Returns the path | PASS |
| .gitkeep is tracked (not ignored) | `git check-ignore re/capture/samples/.gitkeep` | Returns nothing | PASS |
| No raw captures are stage-able | `git status --porcelain re/capture/samples` (filtered for .pklg/.btsnoop) | No output | PASS |
| check-tools.sh has valid bash syntax | `bash -n scripts/check-tools.sh` | Exit 0 | PASS |
| Brewfile has correct GUI token | `grep 'cask "wireshark-app"' Brewfile` | Match found | PASS |
| Evidence triplet is complete | `ls re/capture/evidence/2026-05-30-ios.{sha256,hex,meta.yaml}` | All three present | PASS |
| iOS evidence sidecar records 0xAA SOF and 1011 packets | `grep 'att_packet_count: 1011' meta.yaml` | Match found | PASS |

---

### Probe Execution

No probe scripts declared or present for this phase (`scripts/tests/probe-*.sh` not found). Phase is documentation + toolchain, not an automated pipeline. Skipped.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TOOL-01 | 01-01, 01-03 | Developer can capture live BLE traffic from WHOOP 5.0 using PacketLogger | SATISFIED | ios-packetlogger.md complete; live capture performed: 1011 btatt packets, 0xAA SOF; evidence triplet committed |
| TOOL-02 | 01-01, 01-03 | Documented reproducible workflow for Android HCI snoop capture | PARTIAL | android-btsnoop.md is a complete, reproducible runbook. No live capture performed (no Android device). The workflow is documented; the capture is not. REQUIREMENTS.md wording: "documented, reproducible workflow" — the runbook satisfies the documentation clause; the live demonstration does not exist. ROADMAP criterion 2 requires a performed capture. |
| TOOL-03 | 01-01, 01-02 | Developer can decompile WHOOP Android APK in JADX-GUI to reference enums | PARTIAL | jadx.md runbook is complete and correct. No live APK pull performed (no Android device). ROADMAP criterion 4 requires that the developer "can navigate" — demonstrated capability, not just a runbook. |
| TOOL-04 | 01-01, 01-02 | Developer can load captures in Wireshark and filter by ATT/GATT | SATISFIED | wireshark.md complete; filter confirmed: tshark -Y btatt produced 1011 rows from live iOS capture; redacted hex evidence committed |

**TOOL-01:** SATISFIED  
**TOOL-02:** PARTIAL — runbook complete; live capture not performed (no Android device)  
**TOOL-03:** PARTIAL — runbook complete; live APK decompilation not performed (no Android device)  
**TOOL-04:** SATISFIED

**Orphaned requirements check:** REQUIREMENTS.md maps TOOL-01 through TOOL-04 to Phase 1. All four are claimed by the three plans. No orphaned requirements.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | — |

No `TBD`, `FIXME`, or `XXX` markers found in any phase-modified file. No placeholder implementations. The unchecked checklist items in `re/capture/README.md` (Android evidence, JADX notes) are correctly labelled with explanatory prose — they are honest status indicators, not code stubs.

---

### Gaps Summary

**Two gaps block full goal achievement.** Both stem from a single root cause: no Android device was available during Phase 1 execution.

**Gap 1 — Android btsnoop live capture (ROADMAP criterion 2, TOOL-02)**

The ROADMAP phase goal states "both iOS and Android sources". The android-btsnoop.md runbook is complete, accurate, and reproducible. However, no live capture was performed and no Android evidence triplet exists under `re/capture/evidence/`. The iOS capture (1011 btatt packets, 0xAA SOF) satisfies the iOS half of the goal. The Android half remains open.

**Gap 2 — JADX-GUI APK live navigation (ROADMAP criterion 4, TOOL-03)**

The jadx.md runbook is complete, including the split-APK pull workflow, JADX-GUI navigation instructions, r52 cross-reference, locked legal recording rule, and JRE troubleshooting. No APK was pulled and no enum name/value notes were produced because no Android device was available. The runbook is ready for execution when a device is available.

**Shared root cause:** Both gaps are blocked by the absence of a physical Android device — an external constraint, not an executor error. The runbooks for both are complete and correct. Resolution requires access to an Android device running the WHOOP app.

**What is NOT a gap:** The `check-tools.sh` WARN on PacketLogger at script invocation is intentional by design (D-03 locked manual step). The WARN correctly does not set the `fail` accumulator. This is fully VERIFIED behavior.

---

_Verified: 2026-05-30_
_Verifier: Claude (gsd-verifier)_
