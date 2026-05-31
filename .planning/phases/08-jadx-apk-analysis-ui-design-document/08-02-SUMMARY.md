---
plan: "08-02"
phase: "08"
title: "Author docs/whoop-ui-reference.md"
status: "complete"
completed: "2026-05-31"
key-files:
  created:
    - "docs/whoop-ui-reference.md"
  modified: []
self-check: "PASSED"
---

# Plan 08-02: Author docs/whoop-ui-reference.md — Summary

## What Was Built

`docs/whoop-ui-reference.md` — the committed WHOOP UI reference document, 427 lines, covering all 5 WHOOP tabs with field labels, screen hierarchies, and field-to-model mapping tables.

## Document Structure

- **Header:** IPA version (WHOOP iOS 5.37.0, January 2026), analysis date, legal notice (DISCLAIMER §2), method description.
- **Tab structure overview table** (5 tabs with iOS view controller names).
- **5 H2 sections** (one per tab), each with 3 H3 subsections:
  - `### Field Labels` — table of string keys, display labels, and notes
  - `### Screen Hierarchy` — indented bullet tree of Activity/View structure
  - `### Field-to-Model Mapping` — table mapping UI fields to iOS model properties + ALG-* requirements
- **Inconsistencies with Prior UX Plan** — 6 discrepancies identified vs `docs/plans/2026-05-27-app-ux-plan.md`

## Verification Against ROADMAP Success Criteria

**SC-1:** "JADX analysis complete: each of the 5 main tabs documented with field names, labels, and data relationships"
→ All 5 tabs (Home, Coaching, Health, Sleep, Trends) have `### Field Labels` and `### Screen Hierarchy` populated ✓

**SC-2:** "UI design document committed to `docs/` with wireframe-level description of each card — no artwork or assets copied"
→ `docs/whoop-ui-reference.md` committed; no image refs, no base64, no assets ✓
→ `git show HEAD --name-only` lists only `docs/whoop-ui-reference.md` ✓

**SC-3:** "Field-to-model mapping table: each UI field mapped to its corresponding `DailyMetric`/`CachedSleepSession` property or `ALG-*` requirement"
→ 5 Field-to-Model Mapping tables populated ✓
→ ALG-01, ALG-02, ALG-03 appear in appropriate rows ✓
→ iOS property names use exact casing from `MetricsCache.swift` (`DailyMetric.recovery`, `DailyMetric.avgHrv`, `DailyMetric.restingHr`, `CachedSleepSession.stagesJSON`, etc.) ✓

## Key Inconsistencies Found

1. **Tab structure differs** from prior UX plan — WHOOP uses Home/Coaching/Health/Community, not Today/Sleep/Trends/Workouts/Device. OpenWhoop should keep its original 5-tab plan (better suited to technical use case).
2. **Property names differ** — `avgHrv` not `hrv`; `restingHr` not `rhr` — corrected in all mapping tables.
3. **Sleep is not a top-level tab** in WHOOP's app — accessed via Coaching calendar. Phase 9 should maintain the dedicated Sleep tab in OpenWhoop.
4. **Health tab** (ECG, AFib) is WHOOP premium/device-dependent — not in OpenWhoop scope.

## Validation Results

- `wc -l docs/whoop-ui-reference.md` → 427 lines (> 100 ✓)
- `grep -c "Field-to-Model Mapping" docs/whoop-ui-reference.md` → 5 ✓
- `grep "ALG-0[123]" ... | wc -l` → 20 references ✓
- `grep -c "DailyMetric\|CachedSleepSession" ...` → 41 references ✓
- `git show HEAD --name-only` → only `docs/whoop-ui-reference.md` ✓
- No APK, no decompiled source, no assets committed ✓
- UI-01 acceptance criteria satisfied ✓

## Self-Check: PASSED
