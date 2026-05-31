---
phase: "08"
status: "clean"
depth: "standard"
files_reviewed: 1
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
reviewed: "2026-05-31"
---

# Code Review — Phase 08: JADX APK Analysis + UI Design Document

**Files reviewed:** `docs/whoop-ui-reference.md`
**Depth:** standard
**Phase type:** Documentation-only (no source code changed)

---

## Summary

This is a documentation-only phase. The single committed file is `docs/whoop-ui-reference.md`. No Swift, Python, or configuration files were changed. The review focuses on documentation accuracy, internal consistency, and mapping correctness.

**Two issues were identified and fixed inline before this review was committed:**
1. Tab Structure Overview table listed Community as Tab 4 — inconsistent with the detailed tab sections which treat Sleep as Tab 4. Fixed to match the OpenWhoop tab ordering.
2. `Workout.duration` model property reference was unverified (no `Workout` struct in `MetricsCache.swift`). Fixed to `[not in local model — per-activity duration from hrSample timestamps]`.

---

## Findings

### CR-INFO-01 — String key typo transcription (Info)

**File:** `docs/whoop-ui-reference.md`, line 206
**Finding:** The string key `HealthMetric.respitoryRateUnit` (missing 'a' — should be `respiratoryRateUnit`) is accurately transcribed from the WHOOP IPA source, where this typo exists in the original app. The document is correct to faithfully capture the actual key name; however, a clarifying note would prevent Phase 9 implementors from assuming the key is wrong and "correcting" it to a non-existent key.
**Recommendation (advisory):** Add inline annotation: `[sic — typo in source app]` after the key name if the document is used as a copy-paste reference for Phase 9 string lookups. Not blocking — Phase 9 uses iOS native strings, not Android keys.
**Action:** Not applied (advisory only — not a blocking issue for the document's purpose).

---

## Fixes Applied

### FIX-01 — Tab Structure Overview table alignment

**Before:** Tab 4 listed as "Community (CommunityLandingView)" — inconsistent with the document's own detailed sections that treat Tab 4 as Sleep.
**After:** Tab 4 updated to "Sleep (SleepDetailsView)" with a clarifying note explaining the deviation from WHOOP's native tab ordering. Added note that Community/Profile/Shop are additional WHOOP-app tabs not in OpenWhoop scope.

### FIX-02 — Unverified `Workout.duration` model reference

**Before:** `Activity DURATION → Workout.duration (seconds)` — `Workout` struct does not exist in `MetricsCache.swift`.
**After:** `Activity DURATION → [not in local model — per-activity duration from hrSample timestamps]` — accurately reflects that workout duration is computed from raw BLE timestamps, not a named model property.

---

## Assessment

**Documentation quality: HIGH**
- 427 lines covering all 5 tabs with consistent structure
- String keys faithfully extracted from IPA binary plists
- iOS model property names verified against `MetricsCache.swift` source
- ALG-* requirement IDs correctly assigned per REQUIREMENTS.md
- Legal boundary (DISCLAIMER §2) respected — no decompiled source, no assets
- Inconsistencies with prior UX plan documented explicitly with Phase 9 implications

**No critical or warning findings remain after the two inline fixes.**
