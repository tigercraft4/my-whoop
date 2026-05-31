# Feature Landscape — WHOOP 5.0 iOS v2.0

**Domain:** Recovery/sleep/strain dashboard, WHOOP-style UI, local-first wearable app
**Researched:** 2026-05-31
**Scope:** Milestone v2.0 — UI redesign + algorithms + HealthKit (does NOT re-scope BLE RE)
**Overall confidence:** HIGH (based on reading existing codebase, server algo files, test suites, and PROJECT.md)

---

## Summary

The v1.0 codebase already has a working tab structure (Today/Sleep/Trends/Workouts/Device), a server-side algorithm stack (recovery, sleep staging, strain), and a SwiftUI design system. What v2.0 adds is: (1) validating those views with real backfilled data, (2) making the Recovery card the visual centrepiece with a proper ring + colour band, (3) completing sleep staging with the hypnogram already wired in the UI, (4) connecting strain to the Workouts tab, and (5) exporting to HealthKit.

The WHOOP app's information architecture is already correctly approximated in the existing app. The gap is data, not structure: the backfill pipeline bug means the views render empty. Fix the pipeline first; everything else flows from having real data.

---

## Information Architecture

### WHOOP app tabs (reference, from public documentation and app store screenshots)

The official WHOOP app uses a bottom tab bar with five destinations:

| Tab | Purpose |
|-----|---------|
| Overview / Home | Today's recovery ring, HRV, RHR, sleep performance summary, day strain |
| Sleep | Last night's hypnogram, stage breakdown (REM/Deep/Light/Awake), bed/wake time, sleep need vs got |
| Strain | Day strain score (0–21), workout list, HR zone breakdown |
| Coach | Recommendations, sleep target, strain targets |
| Profile / Device | Account, device connection, settings |

### Current app tabs (v1.0 baseline)

| Tab | Maps to | Status |
|-----|---------|--------|
| Today | WHOOP Overview | Exists; views empty (data gap) |
| Sleep | WHOOP Sleep | Exists; hypnogram wired; data gap |
| Trends | No direct WHOOP equivalent | Exists; 7D/30D/90D charts |
| Workouts | WHOOP Strain (activity list) | Exists; auto-detection from server |
| Device | WHOOP Profile/Device | Exists; live HR + BLE controls |

The tab structure is already correct for the goals of this project. There is no need to rename or re-order tabs. "Coach" (WHOOP's AI recommendation tab) is explicitly out of scope.

---

## Screen-by-Screen Breakdown

### Today (Overview tab)

**What it shows in the WHOOP app:**
- Hero recovery ring: percentage 0–100, colour-coded green (≥67%) / yellow (34–66%) / red (≤33%)
- HRV (overnight RMSSD, ms)
- Resting Heart Rate (overnight minimum, bpm)
- Sleep Performance (% of sleep need met — WHOOP's proprietary metric)
- Day strain score (0–21, running total)
- Live HR if strap is connected

**What the current app shows:**
- Recovery ring (percent, colour) — wired to server metric `recovery` (0–1 fraction)
- Strain card with "/ 21" scale — wired to server `strain`
- Sleep card: duration + efficiency — wired to `totalSleepMin` + `efficiency`
- HRV card (ms) and Resting HR card (bpm) — half-width row
- Live HR + battery chips when connected

**Gap vs WHOOP:** Sleep performance ("you got X% of your sleep need") is not implemented — the sleep need calculation requires a personal target which WHOOP sets through a proprietary algorithm. Using efficiency as proxy is the correct local-first alternative.

**v2.0 action:** Validate all cards with real backfilled data (requires backfill fix). No structural change needed.

---

### Sleep tab

**What it shows in the WHOOP app:**
- Sleep efficiency % (headline)
- Total time asleep (hours + minutes)
- Bed time → wake time
- Hypnogram: 4-lane (Awake/REM/Light/Deep) timeline chart across the night
- Stage totals: Deep Xh Xm, REM Xh Xm, Light Xh Xm
- Sleep stats: Time in bed, Disturbances, Sleep latency
- In-sleep signals: Resting HR, HRV, Respiratory rate, SpO₂, Skin temp deviation
- 7-night sleep/wake bar chart (bed time + wake time)
- Sleep need and sleep debt (WHOOP proprietary — not implemented here)
- Smart alarm integration

**What the current app shows:**
- Sleep efficiency % hero + total duration — wired
- Bed/wake time subtitle — wired
- Hypnogram (HypnogramView): 4-lane (Awake/REM/Light/Deep) with colour legend — wired to `stagesJSON` from server
- Stage breakdown: Deep/REM/Light minute cards — wired to `daily.deepMin / remMin / lightMin`
- Sleep stats row: Time in Bed, Disturbances, Latency — wired
- In-sleep signals grid: RHR, HRV, Resp Rate, SpO₂, Skin Temp Dev — wired (most show "—" pending data)
- 7-night sleep/wake chart (SevenNightChart) — wired
- Smart alarm card (AlarmView sheet) — exists

**Gap vs WHOOP:** `stagesJSON` is only populated when the server's sleep staging algorithm runs successfully. Until backfill is fixed and the staging pipeline runs on real data, the hypnogram renders "No stage data". The structure is complete.

**v2.0 action:** Fix backfill → server sleep staging produces `stagesJSON` → hypnogram shows real data. Validate SpO₂ and skin temp streams (PROTO-11/12) to fill remaining "—" values.

---

### Trends tab

**What it shows in the current app:**
- Range picker: 7D / 30D / 90D
- Chart cards for: Recovery (%), HRV (ms), Resting HR (bpm), Day Strain (/21), Sleep duration (hr)
- Raw HR card (last 24h / 7d stream, 1Hz downsampled)
- Day list: date, recovery colour dot + %, strain value
- Tapping a chart or day → DayDetailView sheet

**WHOOP equivalent:** The WHOOP app does not have an equivalent "Trends" tab — trends are accessed via the individual metric screens. This tab is a differentiator unique to this app (more data density than WHOOP's UI).

**v2.0 action:** No structural change. Validate with real data.

---

### Workouts tab

**What it shows in the current app:**
- Auto-detected workout bouts from `/v1/workouts` (last 30 days)
- Per-workout row: date, time, duration, avg HR, strain badge, calories
- Tapping → WorkoutDetailView (full HR chart, zone breakdown, strain)

**WHOOP equivalent:** WHOOP's Strain tab shows day strain, then lists activities with sport detection and manual logging. This app auto-detects from HR + IMU; no manual sport logging.

**v2.0 action:** Validate that workout auto-detection works with real backfilled HR + IMU data.

---

### Device tab (Live)

**What it shows:** Live HR, battery %, BLE connection state, reconnect controls. Not a WHOOP-equivalent screen; internal tooling.

**v2.0 action:** No change needed.

---

## Algorithm Inputs/Outputs

### Recovery Score (server-side: `app/analysis/recovery.py`)

**Method:** z-score + logistic composite (not WHOOP-identical; transparent proxy)

**Inputs:**
| Input | Weight | Direction | Source |
|-------|--------|-----------|--------|
| HRV (RMSSD, ms) — overnight | W=0.60 (dominant) | higher HRV vs personal baseline → higher recovery | Overnight RR intervals |
| Resting HR (bpm) | W=0.20 | lower RHR vs baseline → higher recovery | Overnight HR minimum |
| Respiratory rate (raw ADC) | W=0.05 | lower resp vs baseline → higher recovery | Resp stream (scale-invariant z) |
| Sleep performance (efficiency proxy) | W=0.15 | higher efficiency → higher recovery | Sleep session efficiency 0–1 |

**Baseline:** Personal rolling baseline (Winsorized EWMA), cold-start gated. Status: "calibrating" (<4 nights) → returns None; "provisional" (4–13 nights) → returns score; "trusted" (≥14 nights) → full score.

**Output:** Float 0–100. Bands: red ≤33%, yellow 34–66%, green ≥67% (matches WHOOP colour scheme).

**Population anchor:** Z=0 (at personal baseline) → ~58% (WHOOP's published average recovery).

**Note on WHOOP's actual formula:** WHOOP uses HRV (RMSSD), RHR, respiratory rate, and sleep performance as inputs — the same four signals in the same direction. The exact weighting and model architecture are proprietary. This implementation is a transparent, citable approximation using z-score + logistic, not a reverse-engineered copy.

---

### Sleep Staging (server-side: `app/analysis/sleep.py` + `sleep_features.py`)

**Method:** Multi-signal 4-class classifier on 30-second epochs

**Pipeline:**
1. **Sleep/wake detection** — accelerometer stillness spine (te Lindert 2013 + Cole-Kripke cross-check + HR gate). Window: 20:00 previous day → 12:00 next day.
2. **Feature extraction per 30s epoch** — HR, Walch DoG HR-variability, neurokit2 HRV features (RMSSD/SDNN/HF/LF-HF), respiration rate, RR variability, clock proxy.
3. **Stage classification** — transparent classifier (`sleep_features.classify_epochs`); designed as a model seam (can swap in ML model later).
4. **Smoothing + physiology re-imposition** — no REM in first ~15 min; deep concentrated in first third; isolated 30s stage flips killed.

**Inputs:**
| Stream | Required | Notes |
|--------|----------|-------|
| `hr` (bpm, 1Hz) | Yes | Sleep/wake + staging |
| `rr` (rr_ms) | Yes | HRV features |
| `gravity` (x/y/z, g) | Yes | Stillness detection |
| `resp` (raw ADC) | Optional | Resp rate feature |
| `skin_temp` (raw ADC) | Optional | Accepted, currently ignored |

**Output:** `SleepSession` with `stages: list[StageSegment]` where each segment has `{start, end, stage}` with stage ∈ {wake, light, deep, rem}. Summary metrics: TST, efficiency (TST/TIB), deep_min, rem_min, light_min, disturbances, latency, WASO.

**Honest ceiling:** EEG-free 4-class staging peaks at ~65–73% epoch agreement (Walch et al. 2019). Light/deep separation is the weakest link. Output is labelled "approximate".

**Current blocker:** IMU data (gravity stream) is HYPOTHESIS status (PROTO-14, TOGGLE_IMU_MODE capture needed). Without gravity, the sleep/wake spine degrades to HR-only detection — still works but less accurate.

---

### Strain Score (server-side: `app/analysis/strain.py`)

**Method:** Edwards TRIMP with Heart Rate Reserve (not WHOOP-identical; published method)

**Inputs:**
| Input | Source |
|-------|--------|
| HR time series (1Hz) | Historical HR stream |
| Max HR | Observed peak, or Tanaka formula (208 − 0.7×age), or 220−age |
| Resting HR | From recovery pipeline |

**HR zones (Edwards 1993, HRR-based):**
| Zone | % HRR | Weight |
|------|--------|--------|
| 0 (recovery) | <50% | 0 |
| 1 | 50–59% | 1 |
| 2 | 60–69% | 2 |
| 3 | 70–79% | 3 |
| 4 | 80–89% | 4 |
| 5 (max) | ≥90% | 5 |

**Output:** Float 0–21 (log-mapped from TRIMP). Scale matches WHOOP's 0–21 range. A full-day resting load is ~5–8; a hard workout can reach 18–21.

---

### Local Offline Fallback (iOS-side: `LocalMetricsComputer.swift`)

When the server is unconfigured or unreachable, the iOS app derives estimates directly from the BLE streams in WhoopStore:

- **Resting HR:** minimum bpm in the 00:00–09:00 UTC window
- **HRV (RMSSD):** root mean square of successive RR differences, overnight window
- **Sleep detection:** 5-minute slot classifier (HR ≤75 bpm AND gravity variance ≤0.05 g²); minimum 3h session; gaps ≤10 min bridged
- **Limitation:** `stagesJSON` is always nil in offline mode (no classifier runs on device). Recovery is always nil offline (needs personal baseline).

---

### HealthKit Export

**Targets (HK-01 to HK-04):**
| Export | HKSampleType | Status |
|--------|-------------|--------|
| HR samples | `HKQuantityType(.heartRate)` | Planned |
| HRV (RMSSD) | `HKQuantityType(.heartRateVariabilitySDNN)` | Planned — note: HealthKit only exposes SDNN; RMSSD is the internal metric |
| SpO₂ | `HKQuantityType(.oxygenSaturation)` | Planned, pending PROTO-11 VERIFIED |
| Sleep sessions | `HKCategoryType(.sleepAnalysis)` | Planned — stages map to HK sleep categories |

**Key implementation notes:**
- HealthKit write requires `NSHealthUpdateUsageDescription` in Info.plist and explicit capability in Xcode
- SpO₂ export should be gated behind PROTO-11 VERIFIED status to avoid exporting unvalidated data into Health
- Sleep stages map as: deep → `.asleepDeep`, rem → `.asleepREM`, light → `.asleepCore`, wake → `.awake`
- Deduplication: use `HKQueryOptions` source predicate to avoid re-exporting samples already in HealthKit

---

## Table Stakes

Features a WHOOP owner expects — missing any makes the app feel broken.

| Feature | Why Expected | Complexity | Current State |
|---------|--------------|------------|---------------|
| Recovery ring with colour band | The headline number; WHOOP's identity | Low | Exists in UI; needs real data |
| HRV (overnight RMSSD) | Core WHOOP metric | Low | Computed by server; needs backfill |
| Resting HR (overnight) | Core WHOOP metric | Low | Computed by server; needs backfill |
| Sleep duration + efficiency | Baseline sleep quality | Low | Wired; needs backfill |
| Hypnogram (4 stages) | Users have seen it in WHOOP; expect it | Medium | UI wired; needs staging algo data |
| Strain score 0–21 | Day load metric | Medium | Server computes; needs backfill |
| Historical trends (7D/30D) | "Am I improving?" | Low | Charts exist; needs data |
| Live HR when connected | Real-time feedback | Low | Working (VERIFIED v1.0) |
| Battery indicator | Device UX | Low | Working (VERIFIED v1.0) |
| HealthKit export (HR + sleep) | Users expect Apple ecosystem integration | Medium | Not yet built |

---

## Differentiators

Features that go beyond what WHOOP shows — not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|------------------|------------|-------|
| Raw HR stream chart (1Hz) | WHOOP hides sub-minute HR; we show it | Low | Already in Trends tab |
| Offline-first with local fallback | Works without server/internet | Medium | LocalMetricsComputer already built |
| Sleep stage timestamps (JSON) | Exportable raw staging data | Low | stagesJSON already stored |
| 90-day trends | WHOOP app shows ~30 days in practice | Low | Already in Trends tab |
| Day list with recovery + strain per day | Dense data view | Low | Already in Trends tab |
| SpO₂ overnight (if PROTO-11 verified) | WHOOP shows it; we'd show our own decode | High | Pending BLE verification |
| Skin temp deviation (if PROTO-12 verified) | WHOOP 5.0 specific | High | Pending BLE verification |
| Respiratory rate | Shown in WHOOP sleep screen | Medium | Wired in UI; needs server pipeline |
| Workout auto-detection (no manual logging) | Lower friction than WHOOP's manual sport entry | Medium | Server /v1/workouts exists |
| Smart alarm (HealthKit wake) | WHOOP's Coach tab feature | Medium | AlarmView already built |

---

## Anti-Features (What NOT to Build)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| WHOOP's exact Recovery/Strain formula | Proprietary, cloud-only, T&C minefield; also a moving target | Use our transparent z-score + logistic (already implemented); label it "estimated" |
| Sleep "Need" score (WHOOP sleep debt metric) | Requires proprietary target-setting model | Use efficiency as proxy; label it clearly |
| "Coach" AI recommendations tab | Would require a coaching model; WHOOP's is cloud-only | Defer indefinitely; out of scope for v2.0 |
| Hormonal Insights / WHOOP Age / Pace of Aging | Cloud-only computed on signals we already have | Decode the inputs (HRV, temp); let users derive later |
| Blood Pressure estimation | Requires cuff calibration; medical device territory | Never ship ungated; WHOOP requires 3 cuff reads to bootstrap |
| AFib detection | Regulated medical device feature | Do not implement; export ECG waveform as research artifact only |
| Copying WHOOP UI assets / artwork / animations | Copyright infringement; legal constraint | Implement from scratch in SwiftUI; same information hierarchy, different design |
| Cloud API integration (WHOOP's cloud) | TOS-violating; antithetical to local-first design | BLE-only; no cloud API calls |
| Firmware modification / persistent writes | High brick risk on user's hardware | Read-only + transient toggles only |
| Manual workout logging / sport labels | Scope creep; needs a sport taxonomy | Auto-detect from HR + IMU; no labels needed |
| Multi-user / account system | Personal device tool | Single device, local-first; no accounts |

---

## Feature Dependencies (Phase Ordering)

```
1. Backfill fix (BF-01/02)
        |
        v
2. Real data in WhoopStore
        |
        +——> 3a. Server sleep staging runs → stagesJSON populated → Hypnogram shows
        |
        +——> 3b. Server recovery score runs → Recovery ring shows real %
        |
        +——> 3c. Server strain score runs → Strain card shows real value
        |
        v
4. Validate biometric streams with real data (IOS-03/04/05)
        |
        +——> 5a. PROTO-11 (SpO₂) VERIFIED → SpO₂ card + HealthKit SpO₂ export
        |
        +——> 5b. PROTO-12 (skin temp) VERIFIED → Skin Temp Dev card
        |
        +——> 5c. PROTO-14 (IMU/gravity) VERIFIED → Sleep staging accuracy improves
        |
        v
6. HealthKit export (HR, HRV, sleep sessions)
        |
        v
7. SpO₂ HealthKit export (gated on PROTO-11 VERIFIED)
```

Backfill fix is the critical path gate. Everything downstream is blocked until the historical pipeline reliably pushes data to the server.

---

## MVP Recommendation for v2.0

**Must ship (blocks "complete product" claim):**
1. Backfill pipeline fix — gates all data-dependent features
2. Recovery ring with real % — the headline experience
3. Hypnogram with real staging data — the visual centrepiece of the Sleep tab
4. HealthKit export: HR samples + sleep sessions — ecosystem integration users expect
5. Validate IOS-03/04/05 — confirms the whole stack works end-to-end

**Ship if PROTO streams verify:**
6. SpO₂ display + HealthKit export (gated on PROTO-11)
7. Skin temp deviation display (gated on PROTO-12)

**Defer to v2.1 or later:**
- Respiratory rate (server pipeline exists; needs calibration validation)
- IMU-improved sleep staging (needs TOGGLE_IMU_MODE capture, PROTO-14)
- Workout calorie refinement (calorie formula depends on user weight/age input not yet collected)

---

## Sources

| Source | Type | Confidence |
|--------|------|------------|
| `ios/OpenWhoop/App/RootTabView.swift` | Codebase (v1.0) | HIGH |
| `ios/OpenWhoop/Tabs/TodayView.swift` | Codebase (v1.0) | HIGH |
| `ios/OpenWhoop/Tabs/SleepView.swift` | Codebase (v1.0) | HIGH |
| `ios/OpenWhoop/Tabs/TrendsView.swift` | Codebase (v1.0) | HIGH |
| `ios/OpenWhoop/Tabs/WorkoutsView.swift` | Codebase (v1.0) | HIGH |
| `ios/OpenWhoop/Tabs/HypnogramView.swift` | Codebase (v1.0) | HIGH |
| `ios/OpenWhoop/Charts/MetricKind.swift` | Codebase (v1.0) | HIGH |
| `ios/OpenWhoop/Metrics/LocalMetricsComputer.swift` | Codebase (v1.0) | HIGH |
| `server/ingest/app/analysis/recovery.py` | Server algo (v1.0) | HIGH |
| `server/ingest/app/analysis/sleep.py` | Server algo (v1.0) | HIGH |
| `server/ingest/app/analysis/strain.py` | Server algo (v1.0) | HIGH |
| `server/ingest/tests/test_recovery.py` | Test suite (v1.0) | HIGH |
| `server/ingest/tests/test_sleep.py` | Test suite (v1.0) | HIGH |
| `server/ingest/tests/test_strain.py` | Test suite (v1.0) | HIGH |
| `.planning/PROJECT.md` | Project context | HIGH |
| `FINDINGS_5.md` | BLE protocol reference | HIGH |
| `.planning/research/FEATURES.md` (v1.0 version) | Previous research | MEDIUM |
| WHOOP app store description / public marketing | External reference | MEDIUM (feature existence only; UI details approximate) |
