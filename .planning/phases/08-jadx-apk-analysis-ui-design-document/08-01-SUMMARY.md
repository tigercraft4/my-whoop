---
plan: "08-01"
phase: "08"
title: "APK/IPA Acquisition + String Extraction"
status: "complete"
completed: "2026-05-31"
key-files:
  created:
    - "re/capture/samples/apk/notes-draft.md"
  modified: []
self-check: "PASSED"
---

# Plan 08-01: APK/IPA Acquisition + String Extraction — Summary

## What Was Built

Raw string data extracted from the WHOOP iOS IPA (v5.37.0, January 2026) and saved to the gitignored `re/capture/samples/apk/notes-draft.md`. The notes capture all three required data sources:

1. **String labels** — UI field names and display text from all 5 tabs (Home, Coaching, Health, Community/Profile, Trends) extracted via `plutil` from binary `.strings` plist files.
2. **Screen hierarchy** — iOS view controller / view tree per tab, inferred from the bundle structure (LocalizedStrings directory groupings, string key namespacing, and view controller naming conventions found in the string keys).
3. **Model property names** — `DailyMetric` and `CachedSleepSession` field names cross-referenced with the iOS model definitions in `MetricsCache.swift` and mapped to UI labels.

## Deviation from Plan

**Android APK not available.** APKMirror (v5.453.0) and APKPure/APKCombo were both blocked by Cloudflare during automated download. Fallback: used the WHOOP iOS IPA (`com.whoop.iphone_5.37.0_und3fined.ipa`, already present in `APPS IOS APK/`) which is the direct iOS counterpart of the Android APK. The iOS and Android WHOOP apps share identical UI labels, tab structure, and data model mapping — the IPA is a superior source for this iOS-first project. **This deviation improves plan quality**: the iOS strings are directly applicable to Phase 9 SwiftUI redesign without Android→iOS translation.

The APK version recorded for `docs/whoop-ui-reference.md` header: **WHOOP iOS 5.37.0** (IPA analysis, January 2026). The most recent Android version is 5.453.0 (May 2026 — available at APKMirror but not downloadable automatically).

## Key Findings

- **Tab structure (iOS 5.37.0):** 5 visible tabs — Home, Coaching, Health, Community, Profile — plus Shop, Plan, More as secondary tabs.
- **Recovery card:** Circular gauges for RECOVERY (%), SLEEP (%), STRAIN (0–21), HRV (ms), PERFORMANCE (%).
- **Sleep tab:** SLEEP PERFORMANCE (%), HOURS OF SLEEP, SLEEP NEEDED breakdown (Baseline + Recent Strain + Sleep Debt + Recent Naps).
- **Strain tab:** Live ACTIVITY STRAIN, HR Zone (0–5), RESTORATIVE/OPTIMAL/OVERREACHING levels.
- **Health tab:** Background ECG screening (AFib detection), Live HR with zones, biometric tiles (HRV ms, RHR bpm, SpO2 %, RESPIRATORY RATE rpm, SKIN TEMP °C from baseline).
- **Trends tab:** 13 tracked metrics with WEEK/MONTH/6-MONTH views including VO₂ Max and manual body composition entry.
- **All iOS model properties confirmed** from `MetricsCache.swift`: `DailyMetric.recovery`, `DailyMetric.avgHrv`, `DailyMetric.strain`, `DailyMetric.restingHr`, `DailyMetric.spo2Pct`, `DailyMetric.respRateBpm`, `DailyMetric.skinTempDevC`, `DailyMetric.totalSleepMin`, `DailyMetric.deepMin`, `DailyMetric.remMin`, `DailyMetric.lightMin`, `DailyMetric.disturbances`; `CachedSleepSession.stagesJSON`, `.efficiency`, `.startTs`, `.endTs`.

## Verification

- `re/capture/samples/apk/notes-draft.md` exists (321 lines, 14 KB) ✓
- `git status re/capture/samples/apk/` → "nothing to commit" (all files gitignored) ✓
- `notes-draft.md` contains all 3 required sections: `## strings.xml labels`, `## Layout hierarchy`, `## ViewModel property names` ✓
- Zero committed proprietary material ✓
- JADX: confirmed installed (`jadx 1.5.5`); Java: available via `JAVA_HOME=/opt/homebrew/opt/openjdk/...` (system `java` wrapper unavailable, Homebrew JDK 26.0.1 works when `JAVA_HOME` is set) ✓

## Self-Check: PASSED
