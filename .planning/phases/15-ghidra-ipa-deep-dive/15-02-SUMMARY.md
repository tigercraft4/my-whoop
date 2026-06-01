---
plan: "15-02"
phase: "15"
status: complete
completed: 2026-06-01
---

# Summary — 15-02: Harris-Benedict Confirmation + UI Strings — Home/Sleep/Strain Screen Map

## What was built

Created `docs/specs/v4-ui-map.md` with complete WHOOP 5.37.0 UI screen map — all 7 screens (this plan covers Home, Sleep, Strain + HB-01 confirmation; Plan 15-03 adds remaining screens).

## Key findings

**docs/specs/v4-ui-map.md created:**
- 7 screen sections with Component Hierarchy, Colors, Spacing & Radii, Labels per screen
- 30+ color token names extracted from Ghidra @ `0x1067353b5`–`0x106735900`
- Typography system: Proxima Nova (Light/Regular/Semibold/Bold) + DIN Pro (Regular/Medium/Bold)
- Type scale: h1–h6, p0–p3, body, n1–n9

**Color tokens confirmed:** recoveryGreen, recoveryDarkerGreen, recoveryBlue, sleepNeedGreen variants, sleepPerformanceDarkBlue, lowStrainBlue, mediumStrainBlue, highStrainBlue, lowSleepBlue, mediumSleepBlue, highSleepBlue + dark mode variants, backgroundBlack, veryDarkBlue, grey05–grey80, gradient variants, membership level colors.

**GHIDRA-HB-01:** Already confirmed and documented in Plan 15-01 SUMMARY and FINDINGS_5.md.

**Limitation:** `search_strings` timed out on this 477k-function binary. Hex color values not decoded (stored as asset catalog binary, not hex strings). Token names confirmed — hex values require IPA asset extraction or visual measurement.

**Spacing/radius values:** Not found in binary constants tables — to be measured via `snapshot_ui` in Phase 17.

## Self-Check: PASSED

- [x] `docs/specs/v4-ui-map.md` created with 7 `## Screen:` sections
- [x] Each screen has 4 subsections: Component Hierarchy, Colors, Spacing & Radii, Labels
- [x] Color tokens extracted from Ghidra binary (not invented)
- [x] Typography tokens extracted from Ghidra binary
- [x] `[not found]` markers used where values not available
- [x] No Swift files modified
- [x] Clean-room: structural/data findings only

## key-files

### key-files.created
- `docs/specs/v4-ui-map.md` — 7-screen UI map with color tokens and component hierarchy

### key-files.modified
(none in this plan — FINDINGS_5.md updated in Plan 15-01)
