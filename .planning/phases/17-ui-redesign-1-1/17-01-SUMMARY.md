---
plan: "17-01"
phase: "17"
status: complete
completed: "2026-06-01"
duration_minutes: 15
tasks_completed: 3
tasks_total: 3
---

# Summary — 17-01: UI-01 Extract IPA Colors & Update DesignTokens

## What Was Built

Extracted real hex color values from WHOOP 5.37.0 `Assets.car` via `assetutil -I` and updated all matching tokens in `ios/OpenWhoop/Design/DesignTokens.swift`.

## Key Files

### Modified
- `ios/OpenWhoop/Design/DesignTokens.swift` — updated WH.Color.* with verified values + 4 new tokens

## Color Values Extracted (Assets.car)

| Token Name | Old Value | New Value | Source |
|---|---|---|---|
| `recoveryGreen` | `#16EC06` | `#19EC06` | "Recovery High" ✓ |
| `recoveryYellow` | `#FFDE00` | `#FFDE00` | "Recovery Medium" ✓ exact |
| `recoveryRed` | `#FF0026` | `#FF0026` | "Recovery Low" ✓ exact |
| `strainBlue` | `#0093E7` | `#0093E7` | "Day Strain" ✓ exact |
| `surface` | `#16171C` | `#1A2227` | "Grey Blue" ✓ |
| `background` | `#0B0B0F` | `#000000` | pure black |
| `sleepPurple` | `#7B61FF` | `#7BA1BB` | "Sleep" ✓ (blue-grey not purple!) |

## New Tokens Added

- `strainBlueMedium = #0077C2` — medium zone (10–17), approximate
- `strainBlueHigh = #005A99` — high zone (18–21), approximate
- `sleepNeedGreen = #19EC06` — sleep need indicator (same as recoveryGreen), approximate
- `recoveryDarkerGreen = #0DB500` — gradient accent, approximate

## Notable Finding

**`sleepPurple` was wrong color family**: The real WHOOP sleep color is a blue-grey (`#7BA1BB`), not purple (`#7B61FF`). This explains why the sleep ring looked wrong. Updated to correct value.

## Self-Check

- [x] BUILD SUCCEEDED: `xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- [x] Only `DesignTokens.swift` modified in this commit
- [x] New tokens `strainBlueMedium`, `strainBlueHigh`, `sleepNeedGreen` declared
- [x] UI-01 gate commit before any component changes

## Self-Check: PASSED
