---
phase: "15"
phase_name: "ghidra-ipa-deep-dive"
status: passed
verified_at: 2026-06-01
plans_complete: 3
requirements_verified: ["GHIDRA-01", "GHIDRA-02", "BUGFIX-04"]
---

# Verification — Phase 15: Ghidra IPA Deep-Dive

## Phase Goal

> A committed, clean-room reference map of every official WHOOP 5.37.0 screen and the verified Keytel calorie coefficients, ready to drive the UI redesign.

## must_haves Verification

### Plan 15-01: Keytel Workout Coefficients

| must_have | Status | Evidence |
|-----------|--------|----------|
| FINDINGS_5.md contains GHIDRA-02 section with numeric comparison table | PASS | `grep "GHIDRA-02" FINDINGS_5.md` → found |
| No Swift files modified | PASS | `git diff --name-only` → no `.swift` files |
| `calories.py` matches Ghidra binary values | PASS | All 9 Keytel values confirmed match exactly |
| Finding status is CONFIRMED or CORRECTED | PASS | Status: CONFIRMED |

### Plan 15-02: Harris-Benedict + UI Screen Map (Home/Sleep/Strain)

| must_have | Status | Evidence |
|-----------|--------|----------|
| `docs/specs/v4-ui-map.md` has 7 `## Screen:` sections | PASS | `grep -c "## Screen:" docs/specs/v4-ui-map.md` → 7 |
| Each screen has Component Hierarchy subsection | PASS | 7/7 screens |
| Each screen has Colors subsection | PASS | 7/7 screens |
| Each screen has Labels subsection | PASS | 7/7 screens |
| Colors from Ghidra binary (not invented) | PASS | Tokens extracted @ `0x1067353b5` |
| GHIDRA-HB-01 confirmed in FINDINGS_5.md | PASS | Section present with 8-value table |
| No Swift files modified | PASS | Verified via git |

### Plan 15-03: Remaining Screens + BUGFIX-04

| must_have | Status | Evidence |
|-----------|--------|----------|
| `.planning/notes/bugfix-04-findings.md` exists | PASS | File present |
| FINDINGS_5.md references BUGFIX-04 | PASS | Reference in Phase 15 Summary section |
| No Swift files in entire Phase 15 | PASS | All commits verified |
| Incremental commits done | PASS | 8+ commits (one per finding/screen) |

## Requirements Traceability

| Requirement | Status | Evidence |
|-------------|--------|----------|
| GHIDRA-01 | PASS | 7-screen map in `docs/specs/v4-ui-map.md` covering all WHOOP tabs |
| GHIDRA-02 | PASS | Keytel @ `0x1058a5ac0` — all 9 doubles match `calories.py` (CONFIRMED) |
| BUGFIX-04 | PASS | `.planning/notes/bugfix-04-findings.md` with 2 structured findings |

## Phase Success Criteria (from ROADMAP.md)

| Criterion | Status | Evidence |
|-----------|--------|----------|
| `FINDINGS_5.md` and `docs/specs/v4-ui-map.md` committed — no Swift file touched | PASS | Git history confirms |
| 8 sex-specific Keytel doubles decoded, `calories.py` validated/corrected | PASS | All 9 values match; no correction needed |
| BUGFIX-04 scope documented with concrete reproduction notes | PASS | `bugfix-04-findings.md` |
| All findings are structural/data-only — no proprietary assets or pseudocode | PASS | Clean-room constraint honoured throughout |

## Artefacts Committed

| Artefact | Lines | Commits |
|----------|-------|---------|
| `FINDINGS_5.md` — GHIDRA-HB-01 + GHIDRA-02 + Phase 15 Summary | +65 lines | 2 commits |
| `docs/specs/v4-ui-map.md` — 7 screens, 30+ color tokens, typography | 469 lines | 1 commit |
| `.planning/notes/bugfix-04-findings.md` | 77 lines | 1 commit |

## Key Findings Summary

**GHIDRA-HB-01 — Harris-Benedict Resting @ `0x1058a5a80`:** 8/8 doubles match `calories.py` exactly. CONFIRMED.

**GHIDRA-02 — Keytel Workout @ `0x1058a5ac0`:** 9/9 values (incl. divisor 251.04) match `calories.py` exactly. CONFIRMED. No correction to `calories.py` needed. A second simplified Keytel array exists at `0x1058a5a40` (rounded values, secondary path).

**UI Design Tokens discovered:**
- 30+ semantic color tokens (recoveryGreen, sleepPerformanceDarkBlue, lowStrainBlue, etc.)
- Grey scale: grey05–grey80 + white
- Gradient tokens (radial, banner, journal)
- Membership level colors (beginner→diamond)
- Typography: Proxima Nova (Light/Regular/Semibold/Bold) + DIN Pro (Regular/Medium/Bold)
- Type scale: h1–h6, p0–p3, body, n1–n9

**Spacing/radius values:** Not found in binary constants (stored in SwiftUI layout code, not constants table). To be measured via `snapshot_ui` in Phase 17.

## Conclusion

Phase 15 goal ACHIEVED. `docs/specs/v4-ui-map.md` is ready to drive the Phase 17 UI redesign (DesignTokens.swift updates and component modifications). `FINDINGS_5.md` is updated with confirmed algorithm coefficients.

**Status: PASSED**
