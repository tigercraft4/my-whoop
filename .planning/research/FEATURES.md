# Feature Research — v4.0 UI Redesign + Bug Fix

**Domain:** iOS WHOOP 5.0 client — 1:1 UI redesign via Ghidra IPA analysis + critical bug fixes
**Researched:** 2026-06-01
**Confidence:** HIGH (full codebase read + Ghidra IPA notes + git log of recent bug fixes)

---

## Context: What Was Already Shipped (v3.0 baseline)

Before identifying what is missing, the post-v3.0 state must be established. The app is functionally complete for the core pipeline; v4.0 is a fidelity and correctness milestone, not a feature-addition milestone.

**Already implemented and working:**
- 5-tab SwiftUI app: Today (Recovery), Sleep, Strain, Trends, Device
- RecoveryCard: ZoneRingView ring (green/yellow/red), HRV, RHR, sleep stat columns
- SleepCard: HOURS OF SLEEP + SLEEP PERFORMANCE columns, HypnogramView (4-lane)
- StrainCard: ZoneRingView ring (0–21), Training State badge (RESTORATIVE / OPTIMAL / OVERREACHING)
- SleepView: stage breakdown (Deep/REM/Light), in-sleep signals grid (RHR, HRV, Resp, SpO2, Skin Temp), 7-night chart, Smart Alarm card
- TrendsView: 7D/30D/90D picker, chart cards per MetricKind, raw HR card, day list
- StrainView: StrainCard hero + workout list rows with strain badge
- ALG-10: Sleep Performance (weighted 45% duration, 25% efficiency, 20% staging, 10% consistency)
- ALG-11: Training State (recovery_to_strain.json lookup, client-side fallback)
- ALG-12: Sleep Needed (baseline 7d + strain_debt + sleep_debt, clamp 300–660 min)
- ALG-13: Calories (Mifflin–St Jeor RMR + Keytel exercise; sex-specific)
- LocalMetricsComputer: offline-first, sole source of truth
- Backfill pipeline: 16000+ historical frames decoded, endData offset corrected (Maverick frame[21:29])
- HRV offset bug fixed: unverified RR offsets removed from V128
- HealthKit export: HR, HRV, sleep stages

---

## Feature Landscape

### Table Stakes (Must Replicate from Official WHOOP 5.37.0 App)

These are the elements identified through Ghidra IPA analysis (`binary: Whoop.app/Whoop`, 477 055 functions, ARM64 Swift) and the existing code audit. Missing any produces a visible gap versus the official app.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Recovery ring colour thresholds: green ≥67%, yellow 33–66%, red <33% | IPA-verified: `greenRecoveryScore`, `yellowRecoveryScore`, `redRecoveryScore` symbols + `recoveryColorForRecoveryScore:` | LOW | Already implemented in `WH.Color.recoveryColor(forPercent:)`. Thresholds match. No change needed. |
| Sleep Performance label: "SLEEP PERFORMANCE" (not "Efficiency") | IPA-verified: `kFilterSleepPerformanceTitle`, `sleepPerformanceAbove70Percent` symbols confirm label text | LOW | Already uses "SLEEP PERFORMANCE" label. No change needed. |
| Sleep Performance display in SleepCard | SleepCard shows it but sources `efficiency` (0–1 fraction) as proxy. ALG-10 computes a separate `sleepPerformance` score stored in `DailyMetric.sleepPerformance`; SleepCard does not yet read it | MEDIUM | SleepCard must prefer `daily.sleepPerformance` (ALG-10 result, 0–100) over raw efficiency. RecoveryCard stats column "SLEEP" should also use ALG-10. |
| Sleep Needed displayed in Sleep tab | Ghidra: `sleepNeedLabel`, `sleepNeedTimeLabel` — UI-only, value is server-side. We compute it (ALG-12 in `LocalMetricsComputer`) but `sleepNeededMin` is **never displayed anywhere in the current UI** | MEDIUM | Add "SLEEP NEEDED" stat to SleepCard or SleepView. Currently computed but silently discarded in the UI layer. |
| Calories (WHOOP-style Keytel workout + RMR) | IPA-verified: `CalorieCalculations::calculateWorkoutCaloriesWithPhysiologicalBaseline_` @ 0x10025c264 (Keytel, 251.04 divisor, sex-specific). Our ALG-13 matches. | LOW | Already displayed in TodayView caloriesCard. Display gated on `metrics.today?.totalCaloriesKcal`. No change needed. |
| Training State badge with correct colour semantics | IPA-verified: `helpPaneTrainingStateLabel`. Our StrainCard colours: RESTORATIVE→blue, OPTIMAL→green, OVERREACHING→red. Official mapping needs Ghidra confirmation for exact colour hex | LOW | Colour semantics already coded. Verify exact hex against official app screenshots. |
| Calories card: show sex-specific formula branch result | ALG-13 already has sex-specific path (male/female/nonbinary), but profile `sex` field must be populated in Settings for the result to differ | LOW | Ensure SettingsView sex picker is visible, defaults are handled, and the nil-profile case shows a prompt rather than silently using 0 |
| HRV sourcing: overnight RMSSD from sleep window only | The Ghidra IPA does not reveal the exact window but WHOOP's known practice is overnight. Current code uses `avgHrv` from `DailyMetric` which comes from LocalMetricsComputer's RR window. | LOW | Verify LocalMetricsComputer's RMSSD window aligns with the sleep session window. No UI change needed. |
| Recovery card "SLEEP" stat shows sleep performance, not raw efficiency | RecoveryCard `sleepLabel` computes `"\(Int($0 * 100))%"` from `daily.efficiency`. When ALG-10 `sleepPerformance` is available, it should be preferred | LOW | One-line fix: prefer `daily.sleepPerformance` in `RecoveryCard.sleepLabel` |
| "No data" / placeholder states use consistent "—" | Currently consistent across cards | LOW | Verify all metric tiles use "—" (not "N/A" or nil-crash) |

### Differentiators (Beyond WHOOP's Official Feature Set)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Sleep Needed visualisation in Sleep tab | WHOOP shows "sleep need" only in the Coach tab (AI-powered). We compute it locally (ALG-12) — displaying it in the Sleep tab makes it visible without a subscription | MEDIUM | Add a "SLEEP NEEDED" row below HOURS OF SLEEP / SLEEP PERFORMANCE in SleepCard. Source: `daily.sleepNeededMin` |
| Offline-first ALG-10..13 pipeline | WHOOP's Sleep Performance, Sleep Needed, Training State are server-side (IPA-confirmed). Our LocalMetricsComputer does them on-device | Already shipped | No change needed, just document as differentiator |
| LocalMetricsComputer as sole source of truth | No cloud dependency for any metric | Already shipped | Consider exposing "computed locally" badge in settings to educate user |
| Raw 1 Hz HR stream chart | WHOOP hides sub-minute granularity | Already shipped | Maintain |
| 90-day trends | WHOOP practical limit is closer to 30 days in UI | Already shipped | Maintain |

### Anti-Features (Explicitly Do Not Build)

| Feature | Why Avoid | Alternative |
|---------|-----------|-------------|
| WHOOP Coach tab (AI coaching, sleep targets) | Cloud-only AI; algorithms proprietary and server-side; legal ambiguity | Show Sleep Needed (ALG-12) as a simple stat — no recommendations engine |
| Copy WHOOP UI assets, colour palette hex values, animations | Copyright infringement. Legal constraint documented in PROJECT.md | Implement from scratch in SwiftUI using our own DesignTokens. Use Ghidra only for information architecture, not for pixel-exact hex values of WHOOP's brand colours |
| AFib detection from R-R intervals | Medical device territory; our R-R stream is unvalidated (PROTO-11/12 flags) | Do not add. Export R-R data to HealthKit only. |
| Sleep "debt" coaching messages | Requires calibrated target + baseline not yet stable enough | Display raw numbers (sleep got vs sleep needed) without coaching text |
| Manual workout logging / sport type selection | Scope creep; WHOOP's activity taxonomy is large | Auto-detect only; no sport labels |
| Multi-user or account sync | Personal device tool; antithetical to local-first design | Single device/single user |
| WHOOP cloud API calls | TOS violation; breaks local-first guarantee | BLE-only; server is our own Dockge instance |

---

## Bug Patterns in iOS BLE Fitness Apps

This section catalogues the bugs already encountered (and fixed) in this project, plus the remaining known bugs that v4.0 must address. Root causes and patterns are noted for the roadmap.

### Category A: BLE Protocol Offset Bugs (Confirmed, Partially Fixed)

**Pattern:** Frame offset constants from Gen4 documentation carried over silently into the Maverick (Gen5) decoder. The WHOOP 5.0 changes the byte layout of historical frames; using wrong offsets produces either: (a) silent wrong values, (b) cursor never advancing (infinite re-read of same frames), or (c) NaN/Inf values crashing downstream math.

**Bugs fixed in recent commits:**
- `endData` offset: Gen4 used `frame[17:25]`, Maverick requires `frame[21:29]` — fixed in `fix(backfill): correct endData offset` (3c22b9e)
- `numFF` offset: `payloadOff+2` gave 1 instead of 15 features — fixed
- `SET_CLOCK` 8 bytes instead of 9 — fixed
- Gravity NaN/Inf skipping: `fix(backfill): skip gravity samples with NaN/Inf` (17896ce)

**Bug still open (UI placeholder issue):**
- `DailyMetric.sleepNeededMin` is computed by LocalMetricsComputer but never rendered in any SwiftUI view. The field exists in the store, the algorithm runs, the value is discarded at the UI boundary. This is not a data bug but a display gap — the column header in SleepCard/SleepView is missing.

### Category B: HRV / R-R Offset Errors

**Pattern:** The standard BLE Heart Rate Measurement characteristic (0x2A37) encodes R-R intervals in units of 1/1024 seconds. Misreading as milliseconds directly produces a ~2.4× overestimate. Our `StandardHeartRate.parse()` applies the correct `× 1000 / 1024` conversion.

**Second layer:** The V128 WHOOP 5.0 historical frame format includes HRV-related offsets that were initially assumed to match the Gen4 layout. After analysis of actual frame data (commit e65fa31), unverified R-R offsets from V128 were purged — the HRV values in the store were potentially corrupt for those frames.

**Residual risk:** Recovery score relies heavily on HRV (60% weight in LocalMetricsComputer). If HRV baseline was computed from corrupted V128 RR data before e65fa31, the rolling 28-night baseline may contain tainted values. Baseline will self-correct over time (EWMA), but a one-time purge of suspect daily metrics may be warranted.

**Action for v4.0:** Add a database migration that flags or purges `avgHrv` values from `DailyMetric` rows that predate commit e65fa31 (or mark them as `confidence = "provisional"`). This prevents corrupt HRV from distorting the personal baseline.

### Category C: Backfill Stuck / Cursor Not Advancing

**Pattern:** The backfill cursor is a high-water mark: `endData` from the last received historical frame is stored and used as the `from_ts` in the next `SEND_HISTORICAL_DATA` request. If `endData` is computed from the wrong offset (Category A), `trim = 60` is a constant (or some small wrong value) and the cursor never advances — each connection re-offloads the same 60-second window.

**Fixed:** endData offset corrected. Safe-trim invariant now enforced.

**Residual risk (open):** The `LocalMetricsComputer.triggerOnDisconnect` path was added (commit 4d6b225) to ensure computation runs when BLE disconnects mid-backfill. This was a race where the computer was never triggered if the strap disconnected before the backfill completion event. The fix is in place but needs end-to-end validation with a 14-day backfill session (IOS items 03/04 in backlog).

### Category D: UI Placeholder / Missing Data Rendering

**Pattern:** A metric is computed and stored in the database, but the SwiftUI view reads a different field or a nil-check short-circuits the display, leaving the user seeing "—" even when data exists.

**Currently identified placeholder issues:**

| Metric | Computed? | Stored? | Displayed? | Root Cause |
|--------|-----------|---------|------------|------------|
| Sleep Needed (ALG-12) | YES (LocalMetricsComputer) | YES (`DailyMetric.sleepNeededMin`) | NO | No SwiftUI view reads `sleepNeededMin` |
| Sleep Performance (ALG-10) | YES | YES (`DailyMetric.sleepPerformance`) | PARTIAL | `SleepCard` and `RecoveryCard` read `efficiency` instead of `sleepPerformance` |
| Training State | YES | YES (`DailyMetric.trainingState`) | YES (StrainCard badge) | Working correctly |
| Total Calories (ALG-13) | YES (conditional on profile) | YES (`DailyMetric.totalCaloriesKcal`) | CONDITIONAL | Requires profile to be set; correct but brittle when profile nil |

### Category E: Gen4 Remnants in WHOOP 5.0 Codebase

**Pattern:** The codebase was forked from a WHOOP 4.0 project. Several constants, comments, and code paths still reference Gen4 semantics. Most are benign (comments), but some are active codepaths:

**Active Gen4 code still in the 5.0 path:**
- `BLEManager` subscribes to `gen4Service` (61080001) and `gen4DataNotifChar` (61080005) in addition to Maverick UUIDs. This was intentional: historical DATA frames (type-47) from `SEND_HISTORICAL_DATA` arrive on 61080005. This is not a bug — it is correct behaviour confirmed by protocol analysis. It does however look like dead code to a new reader and should be documented in-code.
- `Commands.swift` retains `runHapticsPattern` (cmd 79, "4.0 legacy") alongside the Maverick haptics command (cmd 19). The legacy command is kept for test compatibility. The DeviceView debug section exposes both. This is intentional but should be labelled more clearly in UI.
- `StandardHeartRate.swift` line 23: R-R conversion `1/1024 s → ms` — this is correct for the BLE standard. The comment is accurate. Not a bug.

**Note from 2026-06-01 note (`analisa-codigo-verifica-4-0.md`):** The user flagged a general concern that "things still wrong from 4.0" may exist. The audit above did not find any active functional bugs introduced by Gen4 legacy code — the ones found are already fixed or are intentional dual-path support. The v4.0 milestone should include a documented sweep confirming there are no silent Gen4 assumptions remaining.

### Category F: Ghidra-Identified UI Gaps (UI Screens Not Yet Implemented)

From the Ghidra IPA analysis of WHOOP 5.37.0:

**Confirmed server-side (not implementable from RE, but known to exist in official app):**
- `sleepPerformanceAbove70Percent` — a UI string used when sleep performance exceeds 70%. The official app shows a threshold message ("above 70%") rather than just a number. Our implementation shows a numeric percentage which is more informative, but the threshold copy is a cosmetic gap.
- `updateSleepNeed` in `CoachViewController` — the Sleep Need display is in the Coach tab in the official app, not the Sleep tab. We already decided to show it in Sleep tab (which is better UX).

**Confirmed client-side (in IPA, could be replicated):**
- `CalorieCalculations::calculateWorkoutCaloriesWithPhysiologicalBaseline_` — Keytel formula with exact sex-specific coefficients in memory at 0x1058a5a80. The 8 doubles are: raw bytes `2506819543cb2a40 6666666666fe7d40 ...`. Decoding these would confirm the exact Keytel coefficients vs. our implementation. This is a MEDIUM complexity research task (decode f64 LE) with HIGH value for algorithm fidelity.

**Not yet confirmed (requires deeper Ghidra search when 477k function analysis completes):**
- Biometric decode offsets for SpO2 (PROTO-11), skin temperature (PROTO-12), respiratory rate (PROTO-13) in V128 frames — Ghidra analysis timed out on these searches. When the binary finishes indexing, search for `oxygenSaturation`, `skinTemperature`, `respirationRate` to find the frame offsets used by the official app.
- R20/R21/R22/R25/R26 packet parsing constants — useful for confirming our protocol schema matches the official decode path.

---

## Feature Dependencies

```
[Ghidra coefficient decode]
    └──enables──> [Exact Keytel coefficient validation] (ALG-13 fidelity)

[DB migration: purge corrupt HRV baseline]
    └──required before──> [Recovery score baseline trust]

[DailyMetric.sleepPerformance wired to SleepCard/RecoveryCard]
    └──requires──> [ALG-10 already computed] (already shipped)
    └──then enables──> [Accurate "SLEEP" column in RecoveryCard]

[DailyMetric.sleepNeededMin display in SleepView]
    └──requires──> [ALG-12 already computed] (already shipped)

[Gen4 sweep / code audit]
    └──independent──> [Can run in parallel with UI fixes]

[Repository reorganisation]
    └──independent──> [No architecture change; rename/move only]
```

---

## MVP Definition for v4.0

### Must Ship

- [ ] **SleepCard fix:** read `daily.sleepPerformance` (ALG-10 result) instead of `efficiency` for the SLEEP PERFORMANCE column — prevents showing wrong number
- [ ] **RecoveryCard fix:** "SLEEP" stat column reads `daily.sleepPerformance` when available — same data source correction
- [ ] **Sleep Needed display:** add "SLEEP NEEDED" metric tile to SleepView/SleepCard reading `daily.sleepNeededMin` — ALG-12 is computed but silently discarded
- [ ] **DB migration:** flag/purge `avgHrv` in DailyMetric rows predating the V128 RR fix (e65fa31, 2026-06-01) — prevents corrupt HRV distorting 28-night recovery baseline
- [ ] **Gen4 remnant sweep:** audit all files with "4.0" or "Gen4" references; document intentional vs. accidental; clean up comments so future readers understand dual-path is intentional

### Add After Core Fixes

- [ ] **Ghidra coefficient decode:** parse 8 × f64 LE at 0x1058a5a80 — confirm Keytel sex-specific coefficients match our `calories.py` implementation. If they differ, correct ALG-13.
- [ ] **Calories: nil-profile UX:** show an inline "Set profile for calorie estimate" prompt when `profile.weightKg == nil`, rather than hiding the Calories card entirely
- [ ] **`sleepPerformanceAbove70Percent` copy:** add threshold message ("above 70%") when sleep performance exceeds 70 — cosmetic but 1:1 with official app behaviour

### Future (Hardware-Dependent)

- [ ] **PROTO-11/12 decode offsets:** when Ghidra analysis completes, extract SpO2/skin temp frame offsets from official app decoder path — verify against PROTO-11/12 HYPOTHESIS values
- [ ] **IOS-03/04 end-to-end validation:** Today + Sleep views with real WHOOP data (requires dedicated session without official app)

---

## Feature Prioritisation Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| SleepCard: read sleepPerformance (ALG-10) | HIGH — fixes wrong number shown | LOW (one property read) | P1 |
| RecoveryCard: read sleepPerformance | HIGH | LOW (one property read) | P1 |
| Sleep Needed display in SleepView | HIGH — hides computed result from user | LOW (add one MetricCard) | P1 |
| DB migration: purge corrupt HRV | HIGH — recovery score accuracy | MEDIUM (migration + test) | P1 |
| Gen4 remnant sweep | MEDIUM — code quality | LOW (comments + docs) | P2 |
| Keytel coefficient decode via Ghidra | MEDIUM — algorithm fidelity | MEDIUM (f64 decode + compare) | P2 |
| Nil-profile UX for Calories card | MEDIUM — first-run experience | LOW (conditional Text) | P2 |
| sleepPerformanceAbove70Percent copy | LOW — cosmetic fidelity | LOW | P3 |
| PROTO-11/12 offset verification | HIGH — unblocks SpO2/skin temp | HIGH (hardware-dependent) | P3 (hardware gate) |

---

## Competitor Feature Analysis

| Feature | Official WHOOP 5.37.0 | Our Implementation (v3.0) |
|---------|----------------------|--------------------------|
| Recovery score | Server-side (IPA confirmed) | LocalMetricsComputer (offline-first) |
| Sleep Performance | Server-side; shown in Coach tab | ALG-10 local; shown in Today + Trends |
| Sleep Needed | Server-side; Coach tab | ALG-12 local; COMPUTED BUT NOT DISPLAYED |
| Training State | Client lookup table | Identical lookup table (recovery_to_strain.json) |
| Calories | Client-side Keytel + Harris-Benedict (IPA confirmed) | Matches: ALG-13 Keytel + Mifflin–St Jeor |
| SpO2 | Shows in Sleep tab | "—" (PROTO-11 unverified) |
| Skin Temp deviation | Shows in Sleep tab | "—" (PROTO-12 unverified) |
| Respiratory rate | Shows in Sleep tab | Wired; placeholder pending data |
| Hypnogram | 4-lane chart in Sleep tab | Identical structure (HypnogramView) |
| 7-night chart | Yes | Yes (SevenNightChart) |
| Smart Alarm | Coach tab + Sleep tab | Sleep tab (AlarmView) |
| Raw HR chart | Not exposed | Yes (Trends tab, differentiator) |
| Trends 7D/30D/90D | No equivalent single screen | Yes (differentiator) |

---

## Sources

| Source | Confidence |
|--------|------------|
| Ghidra IPA analysis: `Whoop.app/Whoop` 5.37.0 ARM64 (`.planning/notes/ghidra-ios-algorithm-findings.md`) | HIGH |
| Ghidra phase scope notes (`.planning/notes/ghidra-ios-phases-scope.md`) | HIGH |
| Full Swift source audit: all `.swift` files in `ios/OpenWhoop/` | HIGH |
| Git log: recent commits e65fa31, 4d6b225, 17896ce, 4c17952, 3c22b9e | HIGH |
| `.planning/PROJECT.md` v4.0 milestone definition | HIGH |
| `.planning/notes/2026-06-01-ble-sync-discoveries.md` | HIGH |
| `.planning/notes/2026-06-01-analisa-codigo-verifica-4-0.md` (user intent note) | MEDIUM |

---
*Feature research for: WHOOP 5.0 iOS client — v4.0 UI Redesign + Bug Fix*
*Researched: 2026-06-01*
