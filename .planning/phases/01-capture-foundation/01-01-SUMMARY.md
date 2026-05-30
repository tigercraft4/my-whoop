---
phase: 01-capture-foundation
plan: 01
subsystem: infra
tags: [homebrew, wireshark, jadx, adb, libimobiledevice, openjdk, bash, gitignore, ble-capture]

requires: []

provides:
  - Brewfile with version-floored passive-capture toolchain (wireshark-app, wireshark CLI, jadx, android-platform-tools, libimobiledevice, openjdk, blueutil)
  - scripts/check-tools.sh version-asserting verifier (sort -V floor compare, hard-fail on missing tools, WARN-only on manual-install tools)
  - .gitignore rules preventing raw BLE captures and decompiled APK output from being committed
  - re/capture/samples/ and re/capture/evidence/ directory scaffolding with .gitkeep trackers

affects:
  - 01-02 (capture runbooks — depend on this toolchain foundation)
  - 01-03 (capture execution — uses check-tools.sh to verify readiness)

tech-stack:
  added: [wireshark-app, wireshark, jadx, android-platform-tools, libimobiledevice, openjdk, blueutil]
  patterns:
    - "Brewfile declarative toolchain manifest with inline purpose comments"
    - "sort -V semver floor comparison in bash for version assertions"
    - "set -euo pipefail + ROOT anchor bash script idiom (mirrors sync-schema.sh)"
    - "gitignore: ignore raw captures with !.gitkeep + !README.md negation to track empty dirs"

key-files:
  created:
    - Brewfile
    - scripts/check-tools.sh
    - re/capture/samples/.gitkeep
    - re/capture/samples/README.md
    - re/capture/evidence/.gitkeep
  modified:
    - .gitignore

key-decisions:
  - "Version floor pins (>= 4.4.0 wireshark, >= 1.5.1 jadx, >= 35.0.0 adb) instead of exact pins — brew delivers 4.6.6/1.5.5/37.0.0 today; homebrew/versions is deprecated; ATT/GATT dissection is identical across these version ranges (Assumption A7)"
  - "PacketLogger and mobileconfig are WARN-only in check-tools.sh — they are irreducible manual steps (Apple UI requirement, D-03)"
  - "Added !re/capture/samples/README.md negation to gitignore (deviation: samples/* caught README.md — needed for self-documenting directory)"

patterns-established:
  - "Pattern: gitignore raw-stays-local policy with tracked placeholders (.gitkeep + README.md negations, following device_local.example.py convention)"
  - "Pattern: bash toolchain verifier using sort -V floor compare with accumulator exit code"

requirements-completed: [TOOL-01, TOOL-02, TOOL-03, TOOL-04]

duration: 10min
completed: 2026-05-30
---

# Phase 1 Plan 01: Capture Foundation Toolchain Summary

**Brewfile + check-tools.sh passive-capture toolchain foundation with sort -V floor assertions and gitignore policy enforcing raw-captures-stay-local (D-02)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-30T14:23:00Z
- **Completed:** 2026-05-30T14:35:00Z
- **Tasks:** 2
- **Files modified:** 6 (1 modified, 5 created)

## Accomplishments

- Brewfile declaring wireshark-app cask (correct post-rename token), wireshark CLI, jadx, android-platform-tools, libimobiledevice, openjdk, and blueutil — each with inline purpose comments
- scripts/check-tools.sh asserting version floors via sort -V, hard-failing on missing tools, WARN-only on PacketLogger (irreducible manual install), exits non-zero on any hard mismatch per D-03
- .gitignore extended in-place with `re/capture/samples/*` + `!.gitkeep` + `!README.md` negations and explicit `re/capture/samples/apk/` rule with DISCLAIMER §2 annotation
- re/capture/samples/ and re/capture/evidence/ directory scaffolding tracked via .gitkeep; samples/README.md documents the gitignored-content / committed-evidence split

## Task Commits

1. **Task 1: Brewfile, gitignore rules, capture directory scaffolding** - `3d2b5c8` (feat)
2. **Task 2: scripts/check-tools.sh version-asserting verifier** - `4451272` (feat)

## Files Created/Modified

- `Brewfile` — Declarative toolchain manifest: wireshark-app cask, wireshark CLI, jadx, android-platform-tools, libimobiledevice, openjdk, blueutil; each entry has trailing purpose comment
- `scripts/check-tools.sh` — Version-floor asserting bash script; mirrors sync-schema.sh idiom; assert_min() via sort -V; hard FAILs on tshark/jadx/adb/ideviceinfo/java; WARN-only on PacketLogger
- `.gitignore` — Extended with raw BLE capture rules (re/capture/samples/*), negation for .gitkeep and README.md, explicit apk/ rule with D-04/DISCLAIMER §2 comment
- `re/capture/samples/.gitkeep` — Tracks empty directory; contents gitignored
- `re/capture/samples/README.md` — States raw captures are gitignored, must never be committed, points to re/capture/README.md for redaction workflow
- `re/capture/evidence/.gitkeep` — Tracks empty evidence directory for committed redacted artifacts

## Decisions Made

- **Version floor over exact pin:** brew delivers Wireshark 4.6.6 and JADX 1.5.5 today; D-03 specified 4.4.x / 1.5.1. The homebrew/versions tap is deprecated and cask pinning is unsupported. ATT/GATT dissection is behaviorally identical across these minor versions (Assumption A7 in RESEARCH). Floors are documented in check-tools.sh header comment.
- **PacketLogger as WARN-only:** Cannot be installed by script (ships only in Apple's "Additional Tools for Xcode" DMG, Apple UI required). check-tools.sh mirrors sync-schema.sh's optional-target graceful-degradation pattern.
- **openjdk keg-only note:** check-tools.sh prints the PATH export hint when java check fails, matching the RESEARCH finding that the local java stub reports "Unable to locate a Java Runtime".

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added !re/capture/samples/README.md negation to .gitignore**
- **Found during:** Task 1 (staging files for commit)
- **Issue:** `git add re/capture/samples/README.md` was blocked — the `re/capture/samples/*` ignore rule caught README.md. The plan's acceptance criteria require README.md to be tracked (self-documenting directory).
- **Fix:** Added `!re/capture/samples/README.md` negation immediately after `!re/capture/samples/.gitkeep` in the .gitignore block.
- **Files modified:** .gitignore
- **Verification:** `git add re/capture/samples/README.md` succeeded; file is tracked in commit 3d2b5c8.
- **Committed in:** 3d2b5c8 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical negation for README.md)
**Impact on plan:** Necessary for correctness — the plan specified README.md as a deliverable to track. No scope creep.

## Issues Encountered

None beyond the README.md gitignore negation deviation above.

## User Setup Required

Manual steps before the toolchain is fully functional:

1. **Install tools:** `brew bundle --file=Brewfile` — installs all brew-installable tools
2. **Link openjdk (keg-only):** Add to shell profile: `export PATH="$(brew --prefix openjdk)/bin:$PATH"`
3. **Install PacketLogger:** Download "Additional Tools for Xcode" DMG from Apple Developer Downloads; drag PacketLogger.app to /Applications
4. **Verify:** `bash scripts/check-tools.sh` — exits 0 with only PacketLogger WARNed once brew bundle + openjdk link are done

## Next Phase Readiness

- Toolchain foundation ready: Plans 02 and 03 can use check-tools.sh to verify machine readiness before capture sessions
- `brew bundle --file=Brewfile` installs all brew-installable tools in one command
- re/capture/ directory structure in place; evidence/ and samples/ correctly tracked/gitignored
- The four capture runbooks (ios-packetlogger, android-btsnoop, wireshark, jadx) are planned for later plans in this phase

---
*Phase: 01-capture-foundation*
*Completed: 2026-05-30*
