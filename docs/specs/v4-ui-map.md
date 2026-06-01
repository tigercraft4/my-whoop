# WHOOP 5.37.0 — v4 UI Screen Map

**Source:** WHOOP iOS IPA 5.37.0 (`Whoop` binary, AARCH64 LE, Ghidra static analysis)
**Date:** 2026-06-01
**Method:** Ghidra MCP — byte pattern search, memory inspection, symbol extraction. Clean-room: structural/data only.
**Legal:** Analysis under DISCLAIMER §2 — field names, layout structure, and design tokens only; no proprietary assets or decompiled code committed.

> **Relationship to `docs/whoop-ui-reference.md`:** This document complements the existing UI reference. The `whoop-ui-reference.md` covers **string keys and field labels** (from Phase 8 IPA extraction). This document focuses on **visual values** (colors, typography, spacing tokens) and **component hierarchy** from Ghidra binary analysis. Do not duplicate — cross-reference where appropriate.

---

## Design System — Colors (from Ghidra @ `0x1067353b5`–`0x106735900`)

Color token names extracted from the WHOOP 5.37.0 binary. These are the `Assets.xcassets` color set names used by the design system.

### Semantic Color Tokens

| Token Name | Semantic Role | Hex (light/dark — to be confirmed via Assets) |
|------------|---------------|-----------------------------------------------|
| `recoveryGreen` | Recovery ring fill, positive state | [not decoded — name confirmed] |
| `recoveryDarkerGreen` | Recovery ring darker accent | [not decoded] |
| `recoveryBlue` | Recovery ring alt color variant | [not decoded] |
| `sleepNeedGreen` | Sleep need indicator fill | [not decoded] |
| `sleepNeedDarkerGreen` | Sleep need darker accent | [not decoded] |
| `sleepNeedGradientGreen` | Sleep need gradient end | [not decoded] |
| `sleepNeedGreen50` | Sleep need at 50% opacity | [not decoded] |
| `sleepPerformanceDarkBlue` | Sleep performance ring fill | [not decoded] |
| `lowStrainBlue` | Strain ring: low zone (0–9) | [not decoded] |
| `lowStrainBlueDarkMode` | Strain ring: low zone dark mode | [not decoded] |
| `mediumStrainBlue` | Strain ring: medium zone (10–17) | [not decoded] |
| `mediumStrainBlueDarkMode` | Strain ring: medium zone dark mode | [not decoded] |
| `highStrainBlue` | Strain ring: high zone (18–21) | [not decoded] |
| `highStrainBlueDarkMode` | Strain ring: high zone dark mode | [not decoded] |
| `lowSleepBlue` | Sleep stage: low range | [not decoded] |
| `lowSleepBlueDarkMode` | Sleep stage: low range dark mode | [not decoded] |
| `mediumSleepBlue` | Sleep stage: medium range | [not decoded] |
| `mediumSleepBlueDarkMode` | Sleep stage: medium range dark mode | [not decoded] |
| `highSleepBlue` | Sleep stage: high range | [not decoded] |
| `highSleepBlueDarkMode` | Sleep stage: high range dark mode | [not decoded] |
| `backgroundBlack` | Main screen background | [not decoded] |
| `veryDarkBlue` | Surface dark (card background) | [not decoded] |
| `whoopProGold` | WHOOP Pro tier accent | [not decoded] |
| `teal` | Health monitor teal accent | [not decoded] |
| `warningOrange` | Warning/alert state | [not decoded] |
| `peachBorder` | Border accent (menstrual cycle?) | [not decoded] |
| `purpleBorder` | Border accent | [not decoded] |
| `clear` | Transparent | `#00000000` |

### Grey Scale Tokens

| Token | Description |
|-------|-------------|
| `grey05` | 5% grey (near-transparent) |
| `grey10` | 10% grey |
| `grey15` | 15% grey |
| `grey20` | 20% grey |
| `grey30` | 30% grey |
| `grey50` | 50% grey |
| `grey80` | 80% grey |
| `white` | Pure white (#FFFFFF) |

### Gradient Tokens

| Token | Description |
|-------|-------------|
| `greyRadialGradient1` | Radial gradient step 1 |
| `greyRadialGradient2` | Radial gradient step 2 |
| `greyRadialGradient3` | Radial gradient step 3 |
| `lightShadeGradient` | Light shade gradient |
| `mediumShadeGradient` | Medium shade gradient |
| `darkShadeGradient` | Dark shade gradient |
| `darkBlueGradient` | Dark blue gradient (card/banner) |
| `lightBlueGradient` | Light blue gradient |
| `journalBannerBlueGradient` | Journal banner gradient |
| `journalBannerLightBlueGradient` | Journal banner light blue |
| `bannerPurpleGradient` | Banner purple gradient |
| `bannerLightPurpleGradient` | Banner light purple gradient |
| `bannerGreen` | Banner green accent |

### Membership Level Colors

| Token | Membership Tier |
|-------|----------------|
| `beginnerLevelGreen` | Beginner level |
| `beginnerLevel` | Beginner (base) |
| `bronzeLevel` | Bronze tier |
| `silverLevel` | Silver tier |
| `goldLevel` | Gold tier |
| `platinumLevel` | Platinum tier |
| `diamondLevel` | Diamond tier |

### Special Colors

| Token | Usage |
|-------|-------|
| `sleepRawHR` | Sleep raw HR chart line |
| `sleepRawHR50` | Sleep raw HR at 50% opacity |
| `sleepRawHRGradient` | Sleep HR area gradient |
| `shortCutBackground` | Shortcut tile background |
| `menstruatingIndicatorBlack` | Menstrual cycle indicator |
| `RecoveryGraphBackgroundLayer` | Recovery graph background layer |

---

## Typography — Font Tokens (from Ghidra @ `0x106735900`)

| Token | Font | Usage |
|-------|------|-------|
| `proximaNovaLight` | Proxima Nova Light | Body text light weight |
| `proximaNovaRegular` | Proxima Nova Regular | Body text regular |
| `proximaNovaSemibold` | Proxima Nova Semibold | Emphasized labels |
| `proximaNovaBold` | Proxima Nova Bold | Headers, key metrics |
| `dinProRegular` | DIN Pro Regular | Numeric data display |
| `dinProMedum` | DIN Pro Medium | Metric values (medium weight) |
| `dinProBold` | DIN Pro Bold | Large metric numbers |

### Type Scale (from binary symbol `h1`–`h6`, `p0`–`p3`, `n1`–`n9`)

| Token | Role |
|-------|------|
| `h1`–`h6` | Heading levels 1–6 |
| `p0`–`p3` | Paragraph/body text sizes |
| `body` | Default body text |
| `n1`–`n9` | Numeric display scale |

**Typography properties found:** `font`, `fontSize`, `lineHeight`, `characterSpacingRatio`, `forceUppercase`

---

## Screen: Home / Overview

> **Labels:** See `docs/whoop-ui-reference.md` Tab 1 for complete string keys (RECOVERY, SLEEP, STRAIN, PERFORMANCE gauges; CALORIES header; etc.)

### Component Hierarchy

```
HomeView (root)
├── ScoreBarView
│   ├── OverviewGauge ×4 (circular rings)
│   │   ├── RECOVERY ring (recoveryGreen fill)
│   │   ├── SLEEP ring (sleepPerformanceDarkBlue fill)
│   │   ├── STRAIN ring (lowStrainBlue / mediumStrainBlue / highStrainBlue)
│   │   └── PERFORMANCE ring
│   └── RecoveryGraphBackgroundLayer
├── CycleOverviewHeaderView (horizontal metric row)
│   └── Fields: RECOVERY | HRV | STRAIN | CALORIES
├── ProcessNowInformationView (sleep not processed state)
│   └── "Process your Sleep now to calculate Recovery." + "LET'S GO"
├── ImpactTile (recovery impact tiles)
├── ActivityTile (recent activity summary)
└── ConcealedOverview (stealth mode replacement)
```

### Colors

| Element | Token | Notes |
|---------|-------|-------|
| Screen background | `backgroundBlack` | Dark mode primary bg |
| Recovery ring fill | `recoveryGreen` | Gradient to `recoveryDarkerGreen` |
| Sleep ring fill | `sleepPerformanceDarkBlue` | Sleep performance |
| Strain ring — low | `lowStrainBlue` | Zone 0–9 (Restorative) |
| Strain ring — medium | `mediumStrainBlue` | Zone 10–17 (Optimal) |
| Strain ring — high | `highStrainBlue` | Zone 18–21 (Overreaching) |
| Card surface | `veryDarkBlue` | Card/panel background |
| Metric labels | `white` | Primary text |
| Secondary text | `grey50` | Subdued labels |
| Warning state | `warningOrange` | Alerts/errors |

### Spacing & Radii

| Element | Value | Source |
|---------|-------|--------|
| Ring gauge diameter | [not found in binary] | — |
| Card corner radius | [not found in binary] | — |
| Gauge ring spacing | [not found in binary] | — |
| Header row padding | [not found in binary] | — |

> **Note:** Spacing/radius constants were not found via Ghidra byte search (likely in SwiftUI layout code, not constants table). Values should be measured from the live app or extracted via XcodeBuildMCP snapshot_ui during Phase 17.

### Labels

> See `docs/whoop-ui-reference.md` Tab 1: Home for complete label list. No additional labels found in Phase 15 Ghidra analysis.

---

## Screen: Sleep

> **Labels:** See `docs/whoop-ui-reference.md` Tab 4: Sleep for complete string keys.

### Component Hierarchy

```
SleepDetailsView (root)
├── SleepPerformance widget
│   ├── SLEEP PERFORMANCE ring (sleepPerformanceDarkBlue)
│   └── HOURS OF SLEEP vs SLEEP NEEDED
├── Sleep stage breakdown bar
│   ├── DEEP SLEEP segment (highSleepBlue)
│   ├── REM SLEEP segment (mediumSleepBlue)
│   ├── Light Sleep segment (lowSleepBlue)
│   └── Awake segments (warningOrange or grey)
├── sleepNeedGreen breakdown popover (tap to expand)
│   └── Baseline + Recent Strain + Sleep Debt + Recent Naps
├── sleepRawHR chart (raw HR during sleep)
│   └── sleepRawHRGradient area fill
├── Biometric tiles (HRV, RHR, SpO2, Respiration, Skin Temp)
└── Bedtime / Wake time edit fields
```

### Colors

| Element | Token | Notes |
|---------|-------|-------|
| Performance ring | `sleepPerformanceDarkBlue` | Main sleep score |
| Deep Sleep segment | `highSleepBlue` / `highSleepBlueDarkMode` | Dark stage bar |
| REM segment | `mediumSleepBlue` / `mediumSleepBlueDarkMode` | REM stage bar |
| Light segment | `lowSleepBlue` / `lowSleepBlueDarkMode` | Light stage bar |
| Sleep need indicator | `sleepNeedGreen` | Sleep need fill |
| Sleep need accent | `sleepNeedDarkerGreen` | Darker accent |
| Sleep need gradient | `sleepNeedGradientGreen` | Gradient end |
| HR chart line | `sleepRawHR` | Raw HR during sleep |
| HR area gradient | `sleepRawHRGradient` | Chart area fill |
| Sleep need 50% | `sleepNeedGreen50` | Reduced opacity variant |

### Spacing & Radii

| Element | Value | Source |
|---------|-------|--------|
| Stage bar height | [not found in binary] | — |
| Card corner radius | [not found in binary] | — |
| Biometric tile padding | [not found in binary] | — |

> **Note:** Values to be measured via `snapshot_ui` in Phase 17.

### Labels

> See `docs/whoop-ui-reference.md` Tab 4: Sleep. No additional labels found in Phase 15 analysis.

---

## Screen: Strain

> **Labels:** See `docs/whoop-ui-reference.md` Tab 2: Coaching for strain/workout labels.

### Component Hierarchy

```
StrainView / CoachingView (root)
├── Day Strain gauge ring
│   └── Strain zone coloring (lowStrainBlue → mediumStrainBlue → highStrainBlue)
├── StrainCoachView
│   ├── STRAIN TARGET section
│   └── OPTIMAL / RESTORATIVE / OVERREACHING zone indicator
├── ActivityListView (workout history)
│   ├── ActivityListCollectionViewCell per workout
│   └── Segmented: MY WORKOUTS | ALL | STRAIN | SLEEP | RECOVERY
├── CalendarView (monthly heat map)
│   ├── Recovery color coding (recoveryGreen / warningOrange / grey)
│   └── Day Strain annotation
└── ActivityDetailsView (per-workout detail, bottom sheet)
    ├── HR time series chart
    └── ACTIVITY STATISTICS panel
```

### Colors

| Element | Token | Notes |
|---------|-------|-------|
| Strain ring — restorative | `lowStrainBlue` | 0–9 zone |
| Strain ring — optimal | `mediumStrainBlue` | 10–17 zone |
| Strain ring — overreaching | `highStrainBlue` | 18–21 zone |
| Calendar — green recovery | `recoveryGreen` | > threshold |
| Calendar — warning recovery | `warningOrange` | Below threshold |
| Calendar — red recovery | [not found] | Critical low |
| Activity tile background | `veryDarkBlue` | Card bg |
| HR chart | `sleepRawHR` | HR line color |

### Spacing & Radii

| Element | Value | Source |
|---------|-------|--------|
| Activity cell height | [not found in binary] | — |
| Calendar day cell size | [not found in binary] | — |
| Bottom sheet corner radius | [not found in binary] | — |

### Labels

> See `docs/whoop-ui-reference.md` Tab 2: Coaching. Labels: ACTIVITY STRAIN, DURATION, CALORIES, MAX HR, MIN HR, AVG HR, STRAIN, SETS COMPLETED, REPS.

---

## Screen: Trends

> **Labels:** See `docs/whoop-ui-reference.md` Tab 5: Trends for complete string keys (13 tracked metrics).

### Component Hierarchy

```
WhoopHistoricalTrends (root)
├── Trend metric list (scrollable)
│   └── One row per metric → drills to HistoricalTrendView
├── HistoricalTrendView (per-metric detail)
│   ├── Segment selector: WEEK | MONTH | 6-MONTH
│   ├── Line/bar chart
│   │   ├── TYPICAL RANGE reference band (greyRadialGradient1/2/3)
│   │   └── Today marker
│   └── TREND VIEW label
└── Manual measurement entry (WEIGHT, BODY FAT, LEAN BODY MASS)
```

### Colors

| Element | Token | Notes |
|---------|-------|-------|
| Chart line — recovery | `recoveryGreen` | Recovery metric trend |
| Chart line — sleep | `sleepPerformanceDarkBlue` | Sleep metric trend |
| Chart line — strain | `highStrainBlue` | Strain metric trend |
| Typical range band | `greyRadialGradient1` | Reference fill |
| Chart background | `backgroundBlack` | Dark bg |
| Today marker | `white` | Highlighted today |
| Segment selector active | `white` | Active tab |
| Segment selector inactive | `grey30` | Inactive tab |

### Spacing & Radii

| Element | Value | Source |
|---------|-------|--------|
| Chart height | [not found in binary] | — |
| Period selector padding | [not found in binary] | — |

### Labels

> See `docs/whoop-ui-reference.md` Tab 5: Trends. 13 metrics: HRV, RHR, DAY STRAIN, Recovery, SLEEP PERFORMANCE, HOURS VS. NEEDED, TIME IN BED, AVG HR, CALORIES, DEEP SLEEP, REM SLEEP, Respiratory Rate, VO₂ Max.

---

## Screen: Coaching

> **Note:** Coaching tab is not implemented in OpenWhoop — mapped here as reference for Phase 17 backlog.

### Component Hierarchy

```
CoachViewController (root)
├── Sub-tab bar: OVERVIEW | INSIGHTS | REPORTS | MY WEEK
├── CoachView
│   ├── StrainCoachView (coaching insights + strain target)
│   ├── SleepPlanner (SLEEP PLANNER section)
│   │   └── Goal buttons: TOMORROW: PEAK | PERFORM | GET BY
│   ├── PerformanceAssessments
│   └── WeeklyPlan / reports
└── CalendarView (monthly calendar + sleep/strain data)
```

### Colors

| Element | Token | Notes |
|---------|-------|-------|
| Background | `backgroundBlack` | Same dark bg |
| Coaching banner | `journalBannerBlueGradient` | Insight banners |
| Pro insight banner | `bannerPurpleGradient` | Pro tier feature |
| Sleep planner | `sleepNeedGreen` | Sleep goal fill |

### Labels

> See `docs/whoop-ui-reference.md` Tab 2: Coaching for OVERVIEW, INSIGHTS, REPORTS, MY WEEK, STRAIN TARGET, SLEEP PLANNER, PERFORMANCE ASSESSMENTS labels.

---

## Screen: Health

> **Note:** Health tab is not implemented in OpenWhoop — mapped here as reference. Some biometrics are HYPOTHESIS (SpO₂, skin temp, respiration pending PROTO-11/12/13 hardware validation).

### Component Hierarchy

```
HealthView (root)
├── HealthMonitorTile (composite biometric tile)
│   ├── HRV tile (ms, teal accent)
│   ├── RHR tile (bpm)
│   ├── SpO2 / BLOOD OXYGEN tile (%, HYPOTHESIS)
│   ├── RESPIRATORY RATE tile (rpm, HYPOTHESIS)
│   └── SKIN TEMPERATURE tile (°C FROM BASELINE, HYPOTHESIS)
├── LiveHRView (real-time BPM)
│   ├── Large BPM display
│   └── Zone 0–5 coloured bar
└── Background Screening tile (ECG / AFib)
    ├── "AFib not Detected" / "Possible AFib Detected"
    └── "Take ECG Reading" action
```

### Colors

| Element | Token | Notes |
|---------|-------|-------|
| Health tile accent | `teal` | Primary health monitor color |
| Warning HR alert | `warningOrange` | High/Low HR alert |
| Normal state | `recoveryGreen` | Normal/typical state |
| Abnormal state | `warningOrange` | Elevated/low state |

### Labels

> See `docs/whoop-ui-reference.md` Tab 3: Health for complete label list (HRV, RHR, BLOOD OXYGEN, RESPIRATORY RATE, SKIN TEMPERATURE, ECG labels, zone labels Zone 0–5).

**Status per biometric:**
- HRV: VERIFIED (available in local model via `DailyMetric.avgHrv`)
- RHR: VERIFIED (available via `DailyMetric.restingHr`)
- SpO2: HYPOTHESIS (pending PROTO-11 hardware validation)
- Respiratory Rate: HYPOTHESIS (pending PROTO-13)
- Skin Temp: HYPOTHESIS (pending PROTO-12)

---

## Screen: Profile + Settings

> **Note:** Profile and Settings screens are not implemented in OpenWhoop — mapped here as structural reference.

### Component Hierarchy

```
ProfileView / SettingsView (root — accessed via More / tab)
├── User profile card
│   ├── Profile photo + name
│   └── Membership level badge (beginnerLevel / bronzeLevel / silverLevel / goldLevel / platinumLevel / diamondLevel)
├── Settings list
│   ├── Notification preferences (alarmSettingsOff, capsense)
│   └── Account settings
└── WHOOP Pro section (whoopProGold accent)
```

### Colors

| Element | Token | Notes |
|---------|-------|-------|
| Membership badge | `beginnerLevelGreen` / `bronzeLevel` / `silverLevel` / `goldLevel` / `platinumLevel` / `diamondLevel` | Tier-specific colors |
| Pro badge | `whoopProGold` | Gold accent for WHOOP Pro |
| Settings background | `backgroundBlack` | Dark bg |
| Cell separator | `grey10` | Subdued separator |
| Action text | `white` | Primary text |
| Disabled state | `grey30` | Inactive controls |

### Labels

| Key | Display | Notes |
|-----|---------|-------|
| `alarmSettingsOff` | Alarm Settings Off | Notification setting state |
| `capsense` | Capsense | Device hardware setting |

---

## Phase 15 Notes

### Ghidra search limitations

String search (`search_strings`) timed out on this 477k-function binary during Phase 15 execution. Color hex values could not be decoded from Assets.xcassets (these are not embedded as hex strings in the binary — they are stored as asset catalog binary format). The token names above are the canonical identifiers; hex values must be confirmed via:

1. Asset catalog extraction from the IPA bundle: `xcrun actool --compile <output> <Assets.xcassets>`
2. Visual measurement in the simulator via `snapshot_ui` + color picker during Phase 17
3. Comparing against public WHOOP brand guidelines

### Known simplified coefficient array

A second set of rounded Keytel coefficients was found at `0x1058a5a40` (men_hr=0.6, men_alpha=-50.0, women_hr=0.4, etc.) — these are a simplified/rounded estimation path in the binary. The main `calculateWorkoutCalories` @ `0x10025c264` uses the precise array at `0x1058a5ac0` (all values confirmed matching `calories.py` exactly — see GHIDRA-02 in `FINDINGS_5.md`).

---

*Phase: 15-ghidra-ipa-deep-dive*
*Generated: 2026-06-01*
*Feeds: Phase 17 UI Redesign — DesignTokens.swift (UI-01), component updates (UI-02)*
