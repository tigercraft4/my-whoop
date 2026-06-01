# BUGFIX-04 Findings — Ghidra IPA Analysis (Phase 15)

**Date:** 2026-06-01
**Source:** Passive findings during Phase 15 screen mapping and coefficient decode
**Phase for fixes:** Phase 17 (UI Redesign) unless noted

---

## Summary

| ID | Description | Priority | Phase |
|----|-------------|----------|-------|
| BUG-04-01 | Simplified Keytel coefficients in secondary path | Low | Informational |
| BUG-04-02 | `DailyMetric.efficiency` used as sleepPerformance (raw 0–1 vs 0–100%) | High | Phase 14 (already fixed BUGFIX-02) |

---

## Bugs Found

### BUG-04-01: Simplified Keytel Coefficients in Secondary Estimation Path

- **Description:** Two sets of Keytel workout calorie coefficients exist in the WHOOP 5.37.0 binary:
  1. **Precise** (primary): `0x1058a5ac0` — matches `calories.py` exactly (men_alpha=-55.0969, men_hr=0.6309, etc.)
  2. **Simplified** (secondary): `0x1058a5a40` — rounded values (men_alpha=-50.0, men_hr=0.6, women_alpha=-15.0, women_hr=0.4)

- **Expected behavior (WHOOP 5.37.0 app):** Main `calculateWorkoutCalories` @ `0x10025c264` uses the precise array. The simplified array is used in a secondary/simplified estimation path (likely for real-time display during workout, not final calculation).

- **Actual behavior (OpenWhoop):** `calories.py` and `LocalMetricsComputer.swift` use the precise Keytel values — this is CORRECT for the final calculation. No action needed.

- **Reproduction:** Compare `0x1058a5a40` (simplified) vs `0x1058a5ac0` (precise) in Ghidra.

- **Priority:** Low (informational — no bug in OpenWhoop, finding explains secondary path)

- **Phase for fix:** Informational only — no fix needed.

---

### BUG-04-02: Sleep Performance Display (efficiency raw → percentage) — ALREADY FIXED

- **Description:** During Ghidra analysis of `SleepPerformance` UI components, the binary confirms that SLEEP PERFORMANCE is displayed as a 0–100 integer percentage. In earlier OpenWhoop versions, `DailyMetric.efficiency` (raw 0.0–1.0) was used directly without × 100 conversion.

- **Expected behavior (WHOOP 5.37.0 app):** SLEEP PERFORMANCE displayed as integer % (e.g., "85%").

- **Actual behavior (OpenWhoop — pre-fix):** Was showing raw float (e.g., "0.85") in some views.

- **Reproduction:** N/A — fixed in Phase 14 (BUGFIX-02).

- **Priority:** High (was high, now resolved)

- **Phase for fix:** Phase 14 — BUGFIX-02 (COMPLETE).

- **Note:** This finding confirms Phase 14 fix was correct.

---

## No Additional Bugs Found

During Phase 15 Ghidra screen mapping:
- Component hierarchies discovered match the OpenWhoop implementation patterns
- Color token names (recoveryGreen, sleepNeedGreen, etc.) confirm the design system direction in `DesignTokens.swift`
- Typography (Proxima Nova + DIN Pro) matches existing font usage in OpenWhoop
- No additional protocol or algorithm bugs discovered passively

---

## BUGFIX-04 Scope — Final Assessment

GHIDRA-01 screen mapping revealed no critical implementation bugs in OpenWhoop beyond what was already addressed in Phase 14. The primary value of BUGFIX-04 scope is:

1. **Confirming** that the Keytel simplified coefficients are expected WHOOP behavior (not a bug)
2. **Confirming** that Phase 14 BUGFIX-02 (efficiency → sleepPerformance) was the correct fix
3. **Informing** Phase 17 UI work: color tokens from Ghidra confirm which design tokens to implement in `DesignTokens.swift`

---

*Cross-reference: `FINDINGS_5.md` §BUGFIX-04*
*Phase: 15-ghidra-ipa-deep-dive*
