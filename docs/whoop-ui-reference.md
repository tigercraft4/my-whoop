# WHOOP iOS UI Reference

> Documented via WHOOP iOS IPA analysis for Phase 8 — feeds Phase 9 SwiftUI redesign

**Source:** WHOOP iOS IPA `com.whoop.iphone_5.37.0_und3fined.ipa` (version **5.37.0**, January 2026)
**Analysis date:** 2026-05-31
**Method:** `unzip` + `plutil` extraction of binary `.strings` plist files from IPA bundle; `MetricsCache.swift` for iOS model property names.
**Legal notice:** Analysis performed under DISCLAIMER §2 — field names and UI labels only; no decompiled source committed.

> **Note on source deviation:** The Android APK (v5.453.0, APKMirror May 2026) was blocked by Cloudflare during automated download. The WHOOP iOS IPA (v5.37.0) is the direct iOS counterpart and is a superior source for this iOS-first project — iOS strings are directly applicable to Phase 9 SwiftUI redesign without Android→iOS translation.

---

## Tab Structure Overview

| Tab | Label | iOS View Controller Pattern |
|-----|-------|----------------------------|
| 1 | **Home** | HomeView (Overview/Today) |
| 2 | **Coaching** | CoachViewController |
| 3 | **Health** | HealthView |
| 4 | **Community** | CommunityLandingView |
| 5 | **Trends** | WhoopHistoricalTrends |

Secondary tabs (accessible via More): Profile, Shop, Plan.

---

## Tab 1: Home (Overview / Today)

### Field Labels

| String Key | Display Label | Notes |
|------------|---------------|-------|
| `OverviewGauge.Recovery.Label` | RECOVERY | 0–100 integer score |
| `OverviewGauge.Sleep.Label` | SLEEP | 0–100% sleep performance |
| `OverviewGauge.Strain.Label` | STRAIN | 0.0–21.0 daily strain |
| `OverviewGauge.Performance.Label` | PERFORMANCE | Overall performance gauge |
| `OverviewGauge.HRV.Label` | HRV | ms (RMSSD) |
| `OverviewGauge.Percent` | % | Unit suffix for percentage gauges |
| `CycleOverviewHeaderView.Title.Recovery` | RECOVERY | Header row metric |
| `CycleOverviewHeaderView.Title.HRV` | HRV | Header row metric (ms) |
| `CycleOverviewHeaderView.Title.DayStrain` | STRAIN | Header row metric |
| `CycleOverviewHeaderView.Title.Calories` | CALORIES | Header row metric |
| `SleepPerformance.Title` | SLEEP PERFORMANCE | Sleep tab card title |
| `SleepPerformance.HoursOfSleep` | HOURS OF SLEEP | Duration field label |
| `SleepPerformance.HoursNeeded` | SLEEP NEEDED | Sleep need field label |
| `ScoreBarView.highStrainRange` | 18.1– 21.0 | High strain range label |
| `ActivityStrainView.StrainLevel.Restorative` | RESTORATIVE | Strain zone 0–9 |
| `ActivityStrainView.StrainLevel.Optimal` | OPTIMAL | Strain zone 10–17 |
| `ActivityStrainView.StrainLevel.Overreaching` | OVERREACHING | Strain zone 18–21 |
| `ProcessNowInformationView.topInfo.label` | Process your Sleep now to calculate Recovery. | Sleep processing prompt |
| `ConcealedOverview.ConcealedModeTitle` | CONCEALED MODE | Stealth mode label |

### Screen Hierarchy

- Root: `HomeView` (SwiftUI tab root, `MainTab.TabHome = "Home"`)
  - `ScoreBarView` — four circular gauge rings
    - `OverviewGauge` ×4: RECOVERY | SLEEP | STRAIN | PERFORMANCE
    - Each gauge shows percentage/score + unit
  - `CycleOverviewHeaderView` — horizontal metric row below gauges
    - Fields: RECOVERY | HRV | STRAIN | CALORIES
  - `ProcessNowInformationView` — shown when sleep not yet processed
    - "Process your Sleep now to calculate Recovery" prompt
    - "LET'S GO" action button
  - `ConcealedOverview` — replaces normal content in stealth mode
  - `ImpactTile` — recovery impact tiles (shows +/-% behavior impacts)
  - `ActivityTile` — recent activity summary tile (pending indicator)

### Field-to-Model Mapping

| UI Field (Label) | iOS Model Property | Requirement |
|-----------------|-------------------|-------------|
| RECOVERY (ring gauge) | `DailyMetric.recovery` (Double 0–100) | ALG-01 |
| HRV | `DailyMetric.avgHrv` (Double ms) | — |
| STRAIN | `DailyMetric.strain` (Double 0.0–21.0) | ALG-03 |
| SLEEP PERFORMANCE | `DailyMetric.efficiency` (Double 0.0–1.0 → displayed as %) | ALG-02 |
| HOURS OF SLEEP | `DailyMetric.totalSleepMin` (Double → /60 for hours) | — |
| CALORIES | `[computed from hrSample stream]` | — |
| Recovery Impact tiles | `DailyMetric.recovery` delta | ALG-01 |

---

## Tab 2: Coaching (Strain / Workouts / Activities)

### Field Labels

| String Key | Display Label | Notes |
|------------|---------------|-------|
| `CoachViewController.title` | COACHING | Tab main title |
| `CoachView.tabs.overviewTitle` | OVERVIEW | Sub-tab |
| `CoachView.tabs.insightsTitle` | INSIGHTS | Sub-tab |
| `CoachView.tabs.reportsTitle` | REPORTS | Sub-tab |
| `CoachView.tabs.weeklyPlanTabTitle` | MY WEEK | Sub-tab |
| `CoachView.SleepPlanner.Title` | SLEEP PLANNER | Section header |
| `CoachView.StrainTarget.Title` | STRAIN TARGET | Section header |
| `CoachView.PerformanceAssessments.Title` | PERFORMANCE ASSESSMENTS | Section header |
| `ActivityStrainView.Label.ActivityStrain` | ACTIVITY STRAIN | Live activity strain counter |
| `ActivityStrainView.Label.HeartRate` | HEART RATE | Live HR during activity |
| `ActivityStrainView.Label.Live` | LIVE | Live mode indicator |
| `ActivityDetailsView.StatsSelection.Title` | ACTIVITY STATISTICS | Post-workout stats panel |
| `ActivityDetailsView.StatsSelection.Duration` | DURATION | Activity duration |
| `ActivityDetailsView.StatsSelection.Calories` | CALORIES | Calories burned |
| `ActivityDetailsView.StatsSelection.Distance` | DISTANCE | GPS distance |
| `ActivityDetailsView.StatsSelection.MaxHR` | MAX HR | Maximum heart rate |
| `ActivityDetailsView.StatsSelection.MinHR` | MIN HR | Minimum heart rate |
| `ActivityDetailsView.StatsSelection.AvgHR` | AVG HR | Average heart rate |
| `ActivityDetailsView.StatsSelection.Strain` | STRAIN | Activity strain score |
| `ActivityDetailsView.StatsSelection.RHR` | RHR | Resting HR from activity |
| `ActivityDetailsView.StatsSelection.Pace` | PACE | Running/cycling pace |
| `CalendarView.DayStrainAboveTenFormat` | Day Strain %@+ | Calendar heat map label |
| `CalendarView.GreenRecoveryScore` | > %@ | Recovery threshold label (green) |
| `CalendarView.YellowRecoveryScore` | %@ - %@ | Recovery threshold label (yellow) |
| `CalendarView.RedRecoveryScore` | < %@ | Recovery threshold label (red) |
| `CalendarView.SleepPerformanceOver70Percent` | Sleep Performance %@+ | Calendar label |
| `WorkoutOverviewView.BottomDrawer.TotalTime` | TOTAL TIME | Strength workout total |
| `WorkoutOverviewView.BottomDrawer.SetsCompleted` | SETS COMPLETED | Strength sets counter |
| `WorkoutOverviewView.SetRow.RepsTitle` | REPS | Per-set reps counter |
| `CoachView.Button.SleepCoachGoal.Peak` | TOMORROW: PEAK | Sleep goal option |
| `CoachView.Button.SleepCoachGoal.Perform` | TOMORROW: PERFORM | Sleep goal option |
| `CoachView.Button.SleepCoachGoal.GetBy` | TOMORROW: GET BY | Sleep goal option |

### Screen Hierarchy

- Root: `CoachViewController` (COACHING)
  - Sub-tab bar: OVERVIEW | INSIGHTS | REPORTS | MY WEEK
  - `CoachView` sub-tab root
    - `StrainCoachView` — day strain target + coaching voice of wisdom
      - STRAIN TARGET section
      - OPTIMAL / RESTORATIVE / OVERREACHING zone indicator
    - `ActivityListView` — scrollable list of past workouts
      - `WHPActivitiesListTableViewCell` per row (activity type, date, strain)
      - Segmented: MY WORKOUTS | ALL | STRAIN | SLEEP | RECOVERY
    - `CalendarView` — monthly calendar heat map
      - Recovery color coding (green/yellow/red per day)
      - Day Strain annotation
      - Sleep Performance annotation
    - `ActivityDetailsView` — per-activity detail sheet (on tap)
      - HEART RATE graph (time series)
      - ACTIVITY STATISTICS panel (6–9 stats)
      - Map tab (if GPS recorded)
    - `ActivityStrainView` — live strain view (recording mode only)
      - Circular ACTIVITY STRAIN display
      - Real-time HEART RATE with zone coloring
      - LIVE indicator
    - `SleepPlanner` section (SLEEP PLANNER)
      - Tomorrow's goal buttons (PEAK / PERFORM / GET BY / OPTIMIZE SLEEP)
    - `PerformanceAssessments` section
    - `WorkoutOverviewView` — weightlifting mode overlay
      - Exercise set editor
      - SETS COMPLETED counter, TOTAL TIME, REST timer

### Field-to-Model Mapping

| UI Field (Label) | iOS Model Property | Requirement |
|-----------------|-------------------|-------------|
| Day Strain (coaching view) | `DailyMetric.strain` (Double 0.0–21.0) | ALG-03 |
| Activity Strain (live) | `[computed from hrSample stream]` | ALG-03 |
| Activity DURATION | `Workout.duration` (seconds) | — |
| Activity CALORIES | `[computed from hrSample stream]` | — |
| Activity MAX HR | `[computed from hrSample stream]` | — |
| Activity AVG HR | `[computed from hrSample stream]` | — |
| Activity STRAIN | `DailyMetric.strain` or per-activity strain | ALG-03 |
| Sleep Coach goal | `[not in local model — server-computed]` | — |
| Calendar recovery color | `DailyMetric.recovery` thresholds | ALG-01 |
| Reps / Sets (strength) | `[not in local model — user input]` | — |

---

## Tab 3: Health (Health Monitor / ECG)

### Field Labels

| String Key | Display Label | Notes |
|------------|---------------|-------|
| `HealthView.Title` | HEALTH | Tab main title |
| `HealthView.BackgroundScreener` | BACKGROUND SCREENING | AFib background monitoring label |
| `HealthView.HeartScreener` | Heart Screener | ECG feature label |
| `HealthView.TakeALabrador` | Take ECG Reading | ECG action button |
| `HealthView.LabradorReport` | ECG REPORT | Report section label |
| `HealthView.LastLabradorReport` | LAST ECG REPORT | Most recent report label |
| `HealthView.NormalRhythmTitle` | AFib not Detected | Normal result label |
| `HealthView.ShepherdDetected` | Possible AFib Detected | Abnormal result label |
| `HealthView.HighHeartRate` | High HR | Alert label |
| `HealthView.LowHeartRate` | Low HR | Alert label |
| `LiveHR.Info.Title` | HEART RATE | Live HR section title |
| `LiveHR.Info.BPM` | BPM | HR unit |
| `LiveHR.Zone.0` | Zone 0 | HR zone 0 (resting, <50% maxHR) |
| `LiveHR.Zone.1` | Zone 1 | HR zone 1 (50–60% maxHR) |
| `LiveHR.Zone.2` | Zone 2 | HR zone 2 (60–70% maxHR) |
| `LiveHR.Zone.3` | Zone 3 | HR zone 3 (70–80% maxHR) |
| `LiveHR.Zone.4` | Zone 4 | HR zone 4 (80–90% maxHR) |
| `LiveHR.Zone.5` | Zone 5 | HR zone 5 (90–100% maxHR) |
| `HealthMetric.Title.HeartRateVariability` | HRV | Biometric tile title |
| `HealthMetric.Title.RestingHeartRate` | RHR | Biometric tile title |
| `HealthMetric.Title.BloodOxygen` | BLOOD OXYGEN | Biometric tile title |
| `HealthMetric.Abbreviated.BloodOxygen` | SpO2 | Abbreviated label |
| `HealthMetric.Title.RespiratoryRate` | RESPIRATORY RATE | Biometric tile title |
| `HealthMetric.Abbreviated.RespiratoryRate` | RESP. | Abbreviated label |
| `HealthMetric.Title.SkinTemperature` | SKIN TEMPERATURE | Biometric tile title |
| `HealthMetric.ShortTitle.SkinTemperature` | SKIN TEMP | Short label |
| `HealthMetric.Abbreviated.SkinTemperature` | TEMP. | Abbreviated label |
| `HealthMetric.Title.FromBaseline` | FROM BASELINE | Skin temp deviation label |
| `HealthMetric.heartRateVariabilityUnit` | ms | HRV unit |
| `HealthMetric.restingHeartRateUnit` | bpm | RHR unit |
| `HealthMetric.bloodOxygenUnit` | % | SpO2 unit |
| `HealthMetric.respitoryRateUnit` | rpm | Respiration unit |
| `HealthMetric.skinTemperatureCelsiusUnit` | C | Skin temp °C unit |
| `HealthMetric.skinTemperatureFarenheitUnit` | F | Skin temp °F unit |
| `HealthMonitorTile.Label` | Health Monitor | Composite tile label |
| `HealthMetricReading.calibrating` | Calibrating | Data state |
| `HealthMetricReading.withinTypical` | typical | In-range state |
| `HealthMetricReading.elevated` | elevated | Above-range state |
| `HealthMetricReading.low` | low | Below-range state |
| `HealthMetricReading.veryElevated` | very elevated | Far above state |
| `HealthMetricReading.veryLow` | very low | Far below state |
| `HealthMetricReading.noData` | No Data | Missing data state |
| `HealthMetricReading.sleepDataRequired` | Sleep data required | Dependency state |

### Screen Hierarchy

- Root: `HealthView` (HEALTH)
  - `HealthMonitorTile` — composite tile at top
    - `HealthMetric.Title.HeartRateVariability` tile → HRV (ms, typical range indicator)
    - `HealthMetric.Title.RestingHeartRate` tile → RHR (bpm, typical range indicator)
    - `HealthMetric.Title.BloodOxygen` tile → SpO2 (%, typical range indicator)
    - `HealthMetric.Title.RespiratoryRate` tile → RESPIRATORY RATE (rpm, typical range indicator)
    - `HealthMetric.Title.SkinTemperature` tile → SKIN TEMP (°C FROM BASELINE, typical range indicator)
    - Each tile shows: current value | state label (typical/elevated/low) | typical range
  - `LiveHRView` section — real-time heart rate
    - Large BPM display
    - Zone indicator (Zone 0–5 coloured bar)
    - Disconnect / off-body / calibrating states
  - Background Screening tile (BACKGROUND SCREENING)
    - AFib status: "AFib not Detected" | "Possible AFib Detected"
    - ECG action: "Take ECG Reading"
    - "LAST ECG REPORT" with share button
  - [hierarchy not resolved — deeper sub-screens are premium/device-dependent]

### Field-to-Model Mapping

| UI Field (Label) | iOS Model Property | Requirement |
|-----------------|-------------------|-------------|
| HRV (biometric tile) | `DailyMetric.avgHrv` (Double ms) | — |
| RHR (biometric tile) | `DailyMetric.restingHr` (Int bpm) | — |
| BLOOD OXYGEN / SpO2 | `DailyMetric.spo2Pct` (Double %) | — (PROTO-11 gated) |
| RESPIRATORY RATE | `DailyMetric.respRateBpm` (Double rpm) | — |
| SKIN TEMP FROM BASELINE | `DailyMetric.skinTempDevC` (Double °C deviation) | — |
| Live HEART RATE / BPM | `[BLE stream — not in DailyMetric]` | — |
| HR Zone (0–5) | `[computed from live hrSample vs maxHR]` | — |
| ECG / AFib detection | `[Health Monitor service — not in local model]` | — |

---

## Tab 4: Sleep

### Field Labels

| String Key | Display Label | Notes |
|------------|---------------|-------|
| `SleepDetailsView.Title.Sleep` | Sleep | Tab/screen title |
| `SleepPerformance.Title` | SLEEP PERFORMANCE | Main score label |
| `SleepPerformance.HoursOfSleep` | HOURS OF SLEEP | Duration field |
| `SleepPerformance.HoursNeeded` | SLEEP NEEDED | Need field |
| `SleepPerformance.Percent` | % | Performance unit |
| `SleepNeeded.SleepNeedTotal` | Sleep Needed | Need total label |
| `SleepNeeded.Baseline` | Baseline | Baseline sleep need component |
| `SleepNeeded.RecentStrain` | Recent Strain | Strain-added sleep component |
| `SleepNeeded.SleepDebt` | Sleep Debt | Debt component |
| `SleepNeeded.RecentNaps` | Recent Naps | Nap offset component |
| `SleepDetails.Edit.Bedtime` | Bedtime | Edit field |
| `SleepDetails.Edit.WakeTime` | Wake up Time | Edit field |
| `SleepDetails.Edit.Time` | TIME | Edit panel header |
| `HistoricalTrendView.deepSleepTitleText` | DEEP SLEEP | Stage label |
| `HistoricalTrendView.remSleepTitleText` | REM SLEEP | Stage label |
| `Activity.Title.Sleep` | SLEEP | Activity type label |
| `Activity.Title.Nap` | NAP | Nap type label |
| `HealthMetricReading.sleepDataRequired` | Sleep data required | Dependency state for biometrics |
| `HealthMetricReading.sleepProcessing` | Sleep is processing. | Processing state |

### Screen Hierarchy

- Root: Sleep tab (accessed via Coaching/Calendar or dedicated tab in redesign)
  - `SleepDetailsView` — main sleep detail card
    - `SleepPerformance` widget (SLEEP PERFORMANCE % ring)
      - HOURS OF SLEEP vs SLEEP NEEDED display
    - Sleep stage breakdown (hypnogram / stacked bar)
      - DEEP SLEEP bar segment (deepMin)
      - REM SLEEP bar segment (remMin)
      - Light Sleep bar segment (lightMin)
      - Awake segments (awakeSec)
    - `SleepNeeded` breakdown popover (on tap)
      - Baseline + Recent Strain + Sleep Debt + Recent Naps = Sleep Needed
    - Bedtime / Wake time edit fields
    - Sleep biometric summary (during-sleep HRV, RHR, SpO2, respiration)
    - [hierarchy not resolved — deeper sub-screens from layout XMLs not available]
  - `SleepCoach` section (within Coaching tab)
    - Sleep goal selection (PEAK / PERFORM / GET BY / OPTIMIZE / WEEKLY)
    - SLEEP PLANNER section

### Field-to-Model Mapping

| UI Field (Label) | iOS Model Property | Requirement |
|-----------------|-------------------|-------------|
| SLEEP PERFORMANCE (%) | `DailyMetric.efficiency` (Double 0.0–1.0 → × 100) | ALG-02 |
| HOURS OF SLEEP | `DailyMetric.totalSleepMin` (Double → / 60) | — |
| SLEEP NEEDED | `[server-computed — not in local model]` | ALG-02 |
| Bedtime | `CachedSleepSession.startTs` (unix s → Date) | — |
| Wake up Time | `CachedSleepSession.endTs` (unix s → Date) | — |
| DEEP SLEEP | `DailyMetric.deepMin` (Double minutes) | ALG-02 |
| REM SLEEP | `DailyMetric.remMin` (Double minutes) | ALG-02 |
| Light Sleep | `DailyMetric.lightMin` (Double minutes) | ALG-02 |
| Awake | `[derived from (endTs - startTs) - totalSleepMin]` | — |
| Disturbances | `DailyMetric.disturbances` (Int count) | — |
| Sleep stage timeline | `CachedSleepSession.stagesJSON` (JSON array of intervals) | ALG-02 |
| Sleep HRV | `CachedSleepSession.avgHrv` (Double ms) | — |
| Sleep RHR | `CachedSleepSession.restingHr` (Int bpm) | — |
| Sleep SpO2 | `DailyMetric.spo2Pct` (Double %) | — (PROTO-11 gated) |
| Sleep Respiration | `DailyMetric.respRateBpm` (Double rpm) | — |
| Sleep Skin Temp | `DailyMetric.skinTempDevC` (Double °C deviation) | — |

---

## Tab 5: Trends (Historical)

### Field Labels

| String Key | Display Label | Notes |
|------------|---------------|-------|
| `HistoricalTrendView.HRVNavBarTitleText` | Heart Rate Variability | Trend metric title |
| `HistoricalTrendView.RHRNavBarTitleText` | Resting Heart Rate | Trend metric title |
| `HistoricalTrendView.StrainNavBarTitleText` | DAY STRAIN | Trend metric title |
| `HistoricalTrendView.RecoveryNavBarTitleText` | Recovery | Trend metric title |
| `HistoricalTrendView.SleepPerformanceNavBarTitleText` | SLEEP PERFORMANCE | Trend metric title |
| `HistoricalTrendView.HoursVNeedNavBarTitleText` | HOURS VS. NEED | Trend metric title |
| `HistoricalTrendView.hoursVsNeed` | HOURS VS. NEEDED | Alternate label |
| `HistoricalTrendView.TimeInBedNavBarTitleText` | TIME IN BED | Trend metric title |
| `HistoricalTrendView.AvgHRNavBarTitleText` | AVERAGE HEART RATE | Trend metric title |
| `HistoricalTrendView.CaloriesNavBarTitleText` | CALORIES | Trend metric title |
| `HistoricalTrendView.deepSleepTitleText` | DEEP SLEEP | Sleep trend label |
| `HistoricalTrendView.remSleepTitleText` | REM SLEEP | Sleep trend label |
| `HistoricalTrendView.RRNavBarTitleText` | Respiratory Rate | Trend metric title |
| `HistoricalTrendView.trendView` | TREND VIEW | Section label |
| `HistoricalTrendView.typicalRange` | TYPICAL RANGE | Reference band label |
| `HistoricalTrendView.WeekSegmentSelectionText` | WEEK | Time segment |
| `HistoricalTrendView.MonthSegmentSelectionText` | MONTH | Time segment |
| `HistoricalTrendView.SixMonthSegmentSelectionText` | 6-MONTH | Time segment |
| `HistoricalTrendView.todayTitle` | Today | Current day marker |
| `HistoricalTrendView.trendMenuVO2MaxRecommendation` | (VO₂ Max assessment info) | VO2 max manual entry |
| `HistoricalTrendView.manualMeasurementWeightSubtitle` | WEIGHT | Body comp metric |
| `HistoricalTrendView.manualMeasurementBodyFatPercentageSubtitle` | BODY FAT | Body comp metric |
| `HistoricalTrendView.manualMeasurementLeanBodyMassSubtitle` | LEAN BODY MASS | Body comp metric |
| `HistoricalTrendView.deleteVo2MaxEntryTitle` | Delete VO₂ Max? | Delete confirmation |

### Screen Hierarchy

- Root: `WhoopHistoricalTrends` (HistoricalTrendsView)
  - Trend menu list (scrollable, one row per tracked metric)
    - Each row → drill-down to `HistoricalTrendView` for that metric
  - `HistoricalTrendView` detail (per metric):
    - Time segment selector: WEEK | MONTH | 6-MONTH
    - Line/bar chart with TYPICAL RANGE reference band
    - Today marker
    - TREND VIEW label
  - **Tracked metrics (13):**
    1. Heart Rate Variability (HRV, ms)
    2. Resting Heart Rate (bpm)
    3. DAY STRAIN (0–21)
    4. Recovery (0–100%)
    5. SLEEP PERFORMANCE (%)
    6. HOURS VS. NEEDED
    7. TIME IN BED
    8. AVERAGE HEART RATE (bpm)
    9. CALORIES
    10. DEEP SLEEP (minutes)
    11. REM SLEEP (minutes)
    12. Respiratory Rate (rpm)
    13. VO₂ Max (manual entry, mL/kg/min)
  - **Manual measurement entry** (body composition):
    - WEIGHT (kg / lbs)
    - BODY FAT (%)
    - LEAN BODY MASS (kg / lbs)
    - Date/time picker

### Field-to-Model Mapping

| UI Field (Label) | iOS Model Property | Requirement |
|-----------------|-------------------|-------------|
| HRV trend | `DailyMetric.avgHrv` series via `MetricsRepository.daily()` | — |
| Resting Heart Rate trend | `DailyMetric.restingHr` series | — |
| DAY STRAIN trend | `DailyMetric.strain` series | ALG-03 |
| Recovery trend | `DailyMetric.recovery` series | ALG-01 |
| SLEEP PERFORMANCE trend | `DailyMetric.efficiency` series (×100 for %) | ALG-02 |
| HOURS VS. NEEDED | `DailyMetric.totalSleepMin` vs sleep need (server) | ALG-02 |
| TIME IN BED | `CachedSleepSession.endTs - startTs` (seconds → hours) | — |
| AVERAGE HEART RATE trend | `[computed from hrSample stream]` | — |
| CALORIES trend | `[computed from hrSample stream]` | — |
| DEEP SLEEP trend | `DailyMetric.deepMin` series | ALG-02 |
| REM SLEEP trend | `DailyMetric.remMin` series | ALG-02 |
| Respiratory Rate trend | `DailyMetric.respRateBpm` series | — |
| VO₂ Max | `[not in local model — manual entry, server-stored]` | — |
| WEIGHT / BODY FAT / LBM | `[not in local model — manual entry]` | — |

---

## Inconsistencies with Prior UX Plan

Compared against `docs/plans/2026-05-27-app-ux-plan.md`:

- **Tab structure differs:** Prior UX plan specified 5 tabs: Today, Sleep, Trends, Workouts, Device. The WHOOP iOS 5.37.0 IPA reveals: Home, Coaching, Health, Community, (Profile/More). The "Sleep" tab is not a top-level tab in the WHOOP app — sleep data is accessed via the Coaching tab's calendar/list or via a dedicated sleep detail sheet. **Implication for Phase 9:** OpenWhoop should maintain the original 5-tab plan (Today, Sleep, Trends, Workouts, Device) as it better serves the technical use case.

- **Coaching vs Strain tab:** The prior plan called Tab 2 "Strain/Workouts". WHOOP calls it "Coaching" and bundles strain coaching, activity history, sleep planning, and performance assessments together. **Implication:** Phase 9 can keep the "Strain" label for simplicity, or use "Coach" for closer parity.

- **Health tab is WHOOP premium:** The Health tab (ECG, AFib background screening) is device/subscription dependent and not in our original plan. The biometric data (HRV, RHR, SpO2, respiration, skin temp) is exposed as tiles within the Health tab in WHOOP's app, not inline on the Today view. **Implication:** Phase 9 should embed the biometric tiles in the Today/Overview card rather than a separate Health tab.

- **"Trends" is a separate named bundle:** The Trends functionality lives in `WhoopHistoricalTrends` framework. Our plan matches this — Trends tab is correct.

- **"Device" tab is OpenWhoop-specific:** There is no equivalent Device/console tab in the WHOOP app. This is our differentiated feature for BLE technical access.

- **`DailyMetric.avgHrv` vs plan's `DailyMetric.hrv`:** The actual iOS model property is `avgHrv` (not `hrv`). Plan 08-02 must use `avgHrv` consistently. (Plan corrects this in the mapping tables above.)

- **`DailyMetric.restingHr` vs plan's `DailyMetric.rhr`:** The actual property is `restingHr` (not `rhr`). Mapping tables above use the correct name.

---

*Document generated: 2026-05-31*
*Phase: 08-jadx-apk-analysis-ui-design-document*
*Feeds: Phase 9 SwiftUI redesign (09-swiftui-redesign-whoop-style)*
