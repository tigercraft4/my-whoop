---
phase: 02-gatt-survey-bonding
plan: 02
subsystem: ble-protocol
tags: [ble, gatt, bleak, python-venv, whoop-5.0, survey, tooling]

# Dependency graph
requires:
  - phase: 02-01-gatt-survey-bootstrap
    provides: "Confirmed 5.0 UUID family FD4B0001..0005/0007 + handle->UUID map (0x099b->0002, 0x099d->0003, 0x09a3->0004); custom service visible pre-bonding (Pitfall 4 N/A)"
  - phase: 01-capture-handles
    provides: "Phase 1 ATT handles 0x099b/0x099d/0x09a3"
provides:
  - "Isolated 5.0 RE workspace re/survey_5/ (D-04) with working Python 3.11 venv + bleak 3.0.2"
  - "Committed device-identity template re/survey_5/device_local_5.example.py (all-zero placeholders)"
  - "survey_gatt_5.py — programmatic GATT enumeration + handle->UUID cross-check + gatt_dump_5.json output"
  - "Toolchain foundation that Wave 3 (bond_5.py, hr_5.py) imports/extends"
affects: [02-03-hr-battery, 03-framing-crc, 04-protocol-decode]

# Tech tracking
tech-stack:
  added:
    - "bleak==3.0.2 (BLE async client, CoreBluetooth backend)"
    - "Python 3.11 (Homebrew python@3.11) venv at re/survey_5/.venv (gitignored)"
    - "pyobjc-core / pyobjc-framework-corebluetooth 12.2 (bleak macOS deps, auto-installed)"
  patterns:
    - "re/survey_5/ as isolated 5.0 RE workspace separate from 4.0 re/ scripts (D-04)"
    - "Direct device_local_5 import (no device_config env-var fallback) per D-04b"
    - "bleak 3.x client.services property iteration; PHASE1_HANDLES match flag for handle->UUID closure"

key-files:
  created:
    - re/survey_5/__init__.py
    - re/survey_5/device_local_5.example.py
    - re/survey_5/requirements.txt
    - re/survey_5/survey_gatt_5.py
  modified: []

key-decisions:
  - "bleak version asserted via importlib.metadata.version('bleak') — bleak 3.0.2 exposes no bleak.__version__ attribute (plan's verify command corrected; deliverable version 3.0.2 unchanged)"
  - "Live BLE run deferred: requires gitignored real device_local_5.py (absent) + physical strap awake with WHOOP app force-quit (human-only). Script is static-verified complete; live run is a Wave 3 / developer action."

requirements-completed: [PROTO-01, PROTO-03]

# Metrics
duration: ~12min
completed: 2026-05-30
---

# Phase 2 Plan 02: GATT Survey Tooling (re/survey_5 + survey_gatt_5.py) Summary

**Built the isolated WHOOP 5.0 RE workspace — a Python 3.11 venv with bleak 3.0.2 plus the committed device-identity template — and survey_gatt_5.py, a port of re/gatt_dump.py that enumerates client.services, prints integer handles, and flags the Phase 1 handles 0x099b/0x099d/0x09a3 to cross-check the nRF Connect survey from the Bleak side.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-05-30
- **Tasks:** 2 (both committed)
- **Files created:** 4 (+ gitignored .venv)

## Accomplishments

- **re/survey_5/ workspace (D-04)** established, isolated from the 4.0 `re/` production scripts.
- **Python 3.11 venv** created at `re/survey_5/.venv` (gitignored). The system Python is 3.9.6 which cannot run bleak 3.x (Pitfall 6); installed `python@3.11` via Homebrew (was absent) → `python3.11 -m venv` → `pip install -r requirements.txt`. `bleak==3.0.2` is importable; venv Python is 3.11.15.
- **device_local_5.example.py** committed with all-zero `DEVICE_UUID`/`DEVICE_MAC`/`DEVICE_SERIAL` placeholders and a comment pointing at the gitignored `re/survey_5/device_local_5.py`. The real identity file was NOT created/committed (verified empty in `git status`; `git check-ignore` confirms it is ignored).
- **requirements.txt** pins exactly `bleak==3.0.2`.
- **survey_gatt_5.py** ports `re/gatt_dump.py` with the Phase 2 additions:
  - `from device_local_5 import DEVICE_UUID as ADDR` (direct import, no env-var fallback per D-04b).
  - `BleakScanner.find_device_by_address(ADDR, timeout=15.0)` with device-not-found guard; macOS uses a CoreBluetooth UUID, never a MAC.
  - `PHASE1_HANDLES = {0x099b, 0x099d, 0x09a3}`; iterates `client.services` (bleak 3.x property — no `get_services()`), prints each service/char/descriptor with `0x{handle:04x}`, appends `<<< PHASE1 MATCH` when `char.handle in PHASE1_HANDLES`, and prints a final matched-handle summary. Closes the Phase 1 handle→UUID loop from the Bleak side (D-02).
  - Builds a nested result dict (device + services→characteristics→descriptors with uuid/handle/properties) and writes `gatt_dump_5.json` via `json.dump(..., indent=2)`.
  - Bare `asyncio.run(main())` entry (no `__main__` guard — project convention).

## Task Commits

1. **Task 1: scaffold re/survey_5 + Python 3.11 venv with bleak 3.0.2** — `e268ea8` (chore)
2. **Task 2: survey_gatt_5.py programmatic GATT enumeration** — `a2f429a` (feat)

## Files Created/Modified

- `re/survey_5/__init__.py` (created) — empty package marker
- `re/survey_5/device_local_5.example.py` (created) — committed all-zero device-identity template (5 lines)
- `re/survey_5/requirements.txt` (created) — `bleak==3.0.2`
- `re/survey_5/survey_gatt_5.py` (created) — programmatic GATT enumeration + handle cross-check + JSON dump (84 lines)
- `re/survey_5/.venv/` (created, gitignored) — Python 3.11.15 venv with bleak 3.0.2

## Decisions Made

- **bleak version check method.** The plan's verify command used `bleak.__version__`, but bleak 3.0.2 does not expose a `__version__` module attribute (`AttributeError`). Asserted the version via `importlib.metadata.version("bleak")` instead — confirmed `3.0.2`. This is a verification-method correction only; the pinned/installed deliverable version is exactly 3.0.2 as the plan requires.
- **Static verification + import smoke-test in lieu of live BLE run.** Validated `survey_gatt_5.py` with `ast.parse`, all grep acceptance checks, and a module-load smoke-test (temporary gitignored copy of the example as `device_local_5.py`, immediately removed) that confirmed `PHASE1_HANDLES`, `ADDR`, and `main()` resolve and bleak/asyncio import cleanly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Verify command used non-existent `bleak.__version__`**
- **Found during:** Task 1 verification
- **Issue:** The plan's automated verify ran `assert bleak.__version__ == '3.0.2'`, which raises `AttributeError` because bleak 3.0.2 has no `__version__` attribute. This blocked the verification gate despite the correct version being installed.
- **Fix:** Used `importlib.metadata.version("bleak")` for the assertion. Confirmed `3.0.2`. The deliverable (pinned requirement + installed package) is unchanged.
- **Files modified:** none (verification command only)
- **Commit:** n/a (gate adjustment)

**2. [Rule 3 - Blocking] Docstring contained `get_services` substring, failing anti-pattern gate**
- **Found during:** Task 2 verification
- **Issue:** The script docstring referenced the removed `await client.get_services()` API to explain why `client.services` is used. The plan's verify asserts `! grep -q 'get_services'`, so the explanatory mention tripped the anti-pattern check.
- **Fix:** Reworded the docstring to describe the removed coroutine without the literal `get_services` token. The code never calls `get_services()`; only the property `client.services` is used.
- **Files modified:** `re/survey_5/survey_gatt_5.py` (committed in `a2f429a`)
- **Commit:** `a2f429a`

## Live-Run Outcome (deferred — Wave 3 / developer action)

The live run against the physical strap was **not performed in this wave**, for two independent reasons:

1. **Real device identity absent.** `re/survey_5/device_local_5.py` (the gitignored file holding this Mac's CoreBluetooth peripheral UUID for the strap) has not been created by the developer. Without it the script cannot resolve `ADDR`.
2. **Physical + human-only preconditions.** A live run needs the WHOOP 5.0 strap awake and in range with the official WHOOP app force-quit (Pitfall 1) — a manual, physical action that cannot be automated here.

**Important — no bonding dependency for the survey:** Wave 1 (02-01-SUMMARY / FINDINGS_5.md §1) confirmed the custom `FD4B0001-...` service is visible **pre-bonding**, so **Pitfall 4 does NOT apply** and `survey_gatt_5.py` may be run **before** `bond_5.py` in Wave 3 (no ordering constraint). The custom data-channel notifications (cmd-resp/events/data/diagnostics) may still need an encrypted link to deliver payloads, but GATT enumeration itself does not.

**Developer runbook for the live cross-check (Wave 3 or now):**
1. Force-quit the official WHOOP app on iPhone (Pitfall 1).
2. Copy `re/survey_5/device_local_5.example.py` → `re/survey_5/device_local_5.py` and fill the real CoreBluetooth `DEVICE_UUID` (scan to find; it is Mac-specific — Pitfall 3).
3. `cd re/survey_5 && .venv/bin/python survey_gatt_5.py`
4. **Expected:** exits 0; prints services/characteristics with `0x` handles; flags ≥1 Phase 1 handle (`<<< PHASE1 MATCH` on 0x099b→FD4B0002, and likely 0x099d/0x09a3); writes `gatt_dump_5.json`.
5. Record the matched handles and confirm they agree with FINDINGS_5.md §5. Treat `gatt_dump_5.json` as a **local artifact** — do NOT commit it if it embeds the real device name/address (T-02-05).

## Known Stubs

`re/survey_5/device_local_5.example.py` contains all-zero placeholder values (`DEVICE_UUID`/`DEVICE_MAC`/`DEVICE_SERIAL`). This is **intentional and by design** (D-04b): the example is a committed template; the real values live only in the gitignored `device_local_5.py` the developer fills locally. Not a defect — required by the evidence/identity policy (T-02-04).

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`. Mitigations honored:
- **T-02-SC** (bleak install): pinned to exact `bleak==3.0.2`; bleak [SUS] is a confirmed slopcheck false positive (RESEARCH §Package Legitimacy Audit) — no other packages added beyond bleak's own pyobjc deps.
- **T-02-04** (device identity): only the all-zero `device_local_5.example.py` committed; real `device_local_5.py` confirmed absent + gitignored.
- **T-02-05** (gatt_dump_5.json): no live run, so no dump produced; documented as a local-only artifact for Wave 3.

## Issues Encountered

- `python3.11` was not on PATH; installed via `brew install python@3.11` (CLI install Claude performs, per Task 1 action — not a human-only step).
- Two verification-gate frictions (non-existent `bleak.__version__`; `get_services` substring in docstring) — both auto-fixed (see Deviations).

## User Setup Required

To run the live GATT cross-check, the developer must create `re/survey_5/device_local_5.py` (gitignored) with their Mac's CoreBluetooth UUID for the strap, and have the strap awake with the WHOOP app force-quit. See the runbook above.

## Next Wave Readiness

- The `re/survey_5/` toolchain (venv + bleak 3.0.2 + device_local_5 import pattern) is the foundation Wave 3 `bond_5.py` and `hr_5.py` build on — they reuse the same venv, import structure, and confirmed UUID constants from FINDINGS_5.md.
- No bonding/ordering constraint on the survey run (Pitfall 4 N/A) — Wave 3 may run the survey before or after bonding.

## Self-Check: PASSED

- FOUND: re/survey_5/__init__.py
- FOUND: re/survey_5/device_local_5.example.py
- FOUND: re/survey_5/requirements.txt
- FOUND: re/survey_5/survey_gatt_5.py
- FOUND: re/survey_5/.venv/bin/python (bleak 3.0.2, Python 3.11.15)
- FOUND commit: e268ea8 (Task 1)
- FOUND commit: a2f429a (Task 2)
- VERIFIED: re/survey_5/device_local_5.py absent and gitignored (no real identifiers committed)

---
*Phase: 02-gatt-survey-bonding*
*Completed: 2026-05-30*
