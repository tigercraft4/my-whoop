---
plan: "15-01"
phase: "15"
status: complete
completed: 2026-06-01
---

# Summary — 15-01: Keytel Workout Coefficients — Ghidra Decode + calories.py Validation

## What was built

Decoded and validated all Keytel workout calorie coefficients from the WHOOP 5.37.0 binary via Ghidra MCP analysis, plus confirmed Harris-Benedict resting coefficients.

## Key findings

**GHIDRA-02: Keytel Workout Coefficients — CONFIRMED**
- Address: `0x1058a5ac0` (72 bytes, 9 doubles)
- All 9 values (men: hr, alpha, weight, age; divisor 251.04; women: hr, alpha, weight, age) match `calories.py` exactly
- No correction to `calories.py` required
- `calculateWorkoutCalories` @ `0x10025c264` uses this array

**GHIDRA-HB-01: Harris-Benedict Resting — CONFIRMED**
- Address: `0x1058a5a80` (64 bytes, 8 doubles)
- All 8 values match `calories.py` exactly (previously confirmed, now formally documented)

**Bonus finding:** Simplified/rounded Keytel constants at `0x1058a5a40` (men_hr=0.6, men_alpha=-50.0, etc.) — separate estimation path, not used by main workout calorie function.

## Self-Check: PASSED

- [x] GHIDRA-02 section added to `FINDINGS_5.md`
- [x] GHIDRA-HB-01 section added to `FINDINGS_5.md`
- [x] `calories.py` unchanged (all values confirmed correct)
- [x] No Swift files modified
- [x] Clean-room: structural/data findings only

## key-files

### key-files.modified
- `FINDINGS_5.md` — GHIDRA-02 + GHIDRA-HB-01 sections added

### key-files.created
(none — analysis only)
