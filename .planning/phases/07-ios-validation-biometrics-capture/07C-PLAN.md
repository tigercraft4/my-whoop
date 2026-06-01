---
phase: 7
plan: 07C
title: "iOS View Validation + IOS-08 Maestro Test"
wave: 2
depends_on: [06A, 06B]
files_modified:
  - ios/maestro/07_ios08_background_reconnect.yaml
  - .planning/REQUIREMENTS.md
autonomous: true
requirements: [IOS-03, IOS-04, IOS-08]
---

<objective>
With Phase 6 backfill fix in place, validate that TodayView and SleepView display real WHOOP 5.0 data (not placeholders), and create the Maestro E2E test `07_ios08_background_reconnect.yaml` to verify IOS-08 background reconnect via `willRestoreState`. Mark IOS-03, IOS-04, IOS-08 as done in REQUIREMENTS.md when confirmed.
</objective>

<context>
TodayView and SleepView both use `@EnvironmentObject var metrics: MetricsRepository` — data flows automatically once the GRDB store is populated by backfill (Phase 6). No view logic changes are required: this plan is validation-only for TodayView and SleepView.

IOS-05 (SpO₂/skinTemp chart series in TrendsView) is explicitly DEFERRED to Phase 9 — do NOT modify `MetricKind.dailyCases` or `TrendsView.swift` in this plan.

BLEManager already implements `willRestoreState` at line 685 — it captures the restored peripheral into `restoredPeripheral` and does NOT call `p.discoverServices()` immediately (the comment at line ~706 explains this). Background reconnect relies on the OS calling `willRestoreState` after a force-quit and BLEManager reconnecting to the peripheral.

The Maestro IOS-08 test must follow the same pattern as the 6 existing tests: `appId: com.openwhoop.OpenWhoop`, `launchApp`, `runFlow: utils/allow_notifications.yaml`, then the reconnect scenario.

IOS-08 success criterion (from ROADMAP): app reconnects within 30s via willRestoreState without manual intervention.
</context>

<tasks>

<task id="07C-T1">
<type>execute</type>
<title>Validate TodayView shows real WHOOP 5.0 data (IOS-03)</title>

<read_first>
- ios/OpenWhoop/Tabs/TodayView.swift — understand what data bindings are used, what placeholders look like (e.g., "—", "0", nil guards)
- .planning/REQUIREMENTS.md — IOS-03 exact criterion: "Today view shows recovery score, HRV and sleep summary with dados reais do WHOOP 5.0 (após backfill funcional)"
</read_first>

<action>
With Phase 6 backfill functional and GRDB store populated:

1. Launch the iOS app on a physical iPhone connected to WHOOP 5.0
2. Allow backfill to complete (watch BLEManager logs for backfill completion)
3. Navigate to Today tab
4. Verify:
   - Recovery score shows a numeric value (not "—" or "0" or placeholder)
   - HRV shows a numeric value in ms
   - Sleep summary shows at least one real sleep session title (not "No sleep data")
5. Take a screenshot or note the observed values as evidence

Document the result in a brief log: observed values, date, firmware version of WHOOP observed in logs.

If data does not appear (Phase 6 fix not yet deployed or backfill incomplete): document the blocker explicitly — do NOT mark IOS-03 done.
</action>

<acceptance_criteria>
- TodayView displays a non-zero, non-placeholder recovery score (observable on physical device)
- TodayView displays a non-zero HRV value in ms
- No "—" placeholder visible for recovery or HRV fields after backfill completes
- Developer log confirms `DailyMetric` rows exist in GRDB (via sqlite3 or BLEManager debug log after backfill)
</acceptance_criteria>
</task>

<task id="07C-T2">
<type>execute</type>
<title>Validate SleepView shows real sleep sessions with staging (IOS-04)</title>

<read_first>
- ios/OpenWhoop/Tabs/SleepView.swift — understand what data bindings are used, staging display, and placeholder states
- .planning/REQUIREMENTS.md — IOS-04 criterion: "Sleep view shows sessões de sono históricas reais com staging (REM/Deep/Light/Awake)"
</read_first>

<action>
With Phase 6 backfill functional:

1. Navigate to Sleep tab on the physical iPhone
2. Verify:
   - At least one sleep session is visible in the list (not "No sleep sessions")
   - The session shows stage breakdown (REM/Deep/Light/Awake or equivalent staging labels)
   - Duration is non-zero
   - The SpO₂ field in SleepView (if present) may show "—" with a HYPOTHESIS comment — this is acceptable; do NOT attempt to fix it in this plan
3. Document observed values (session date, duration, staging data visible)

Note: the existing `// SpO₂ HYPOTHESIS comment` on a line in SleepView.swift is intentional and must NOT be removed — it documents that SpO₂ display is gated on PROTO-11 VERIFIED.
</action>

<acceptance_criteria>
- SleepView displays at least 1 real sleep session (date visible, not placeholder)
- At least one staging field (REM, Deep, Light, or Awake minutes) shows a non-zero value
- No modification made to TrendsView.swift or MetricKind.swift (IOS-05 is deferred)
- SleepView HYPOTHESIS comment line for SpO₂ remains unchanged
</acceptance_criteria>
</task>

<task id="07C-T3">
<type>execute</type>
<title>Create Maestro test 07_ios08_background_reconnect.yaml</title>

<read_first>
- ios/maestro/06_device_settings.yaml — most recent existing Maestro test; follow exact same appId, flow structure, waitForAnimationToEnd patterns
- ios/maestro/utils/allow_notifications.yaml — utility to include in runFlow at the start
- ios/OpenWhoop/BLE/BLEManager.swift lines ~685–710 — willRestoreState implementation; understand that reconnect is driven by the OS calling willRestoreState after force-quit; the app should show a "Connected" indicator within 30s
- ios/OpenWhoop/App/RootTabView.swift or LiveView.swift — find the UI indicator for BLE connection status (text label, icon, or status string that confirms reconnect)
</read_first>

<action>
Create `ios/maestro/07_ios08_background_reconnect.yaml` following the pattern of existing Maestro tests:

```yaml
appId: com.openwhoop.OpenWhoop
---
# Flow 7: Force-quit reconnect via willRestoreState (IOS-08)
# Verifies: App reconnects to WHOOP 5.0 within 30s after force-quit without manual intervention

- launchApp
- runFlow: utils/allow_notifications.yaml

# Wait for initial connection
- waitForAnimationToEnd:
    timeout: 8000

- takeScreenshot: /tmp/maestro_07a_connected.png

# Assert connected before force-quit (look for "Connected" text or HR value)
# [Update the assertVisible text to match the actual UI string from LiveView/RootTabView]
- assertVisible:
    text: "Connected"

# Force-quit the app (simulates user pressing home twice and swiping up)
# Maestro stopApp sends SIGKILL equivalent
- stopApp

# Wait 5s for the OS to process the termination
- extendedWaitUntil:
    visible: false
    timeout: 5000

# Relaunch — iOS CBCentralManager will call willRestoreState on next launch
- launchApp
- runFlow: utils/allow_notifications.yaml

- takeScreenshot: /tmp/maestro_07b_relaunch.png

# Wait up to 30s for reconnect (IOS-08 criterion: within 30s)
- waitForAnimationToEnd:
    timeout: 30000

- takeScreenshot: /tmp/maestro_07c_reconnected.png

# Assert reconnect succeeded — "Connected" indicator or live HR value visible
- assertVisible:
    text: "Connected"

- takeScreenshot: /tmp/maestro_07d_final.png
```

Important: Before writing the file, read `ios/OpenWhoop/Live/LiveView.swift` or `RootTabView.swift` to find the exact string that indicates BLE connection (search for "Connected", "connected", or HR unit labels). Replace the placeholder `"Connected"` in assertVisible with the actual UI string used in the app.
</action>

<acceptance_criteria>
- `ios/maestro/07_ios08_background_reconnect.yaml` exists
- File begins with `appId: com.openwhoop.OpenWhoop` (exact match)
- File contains `runFlow: utils/allow_notifications.yaml`
- File contains `stopApp` command to simulate force-quit
- File contains a second `launchApp` after `stopApp`
- File contains `waitForAnimationToEnd` with timeout ≥ 30000ms for the reconnect wait
- File contains at least 2 `assertVisible` calls (one before force-quit, one after reconnect)
- File contains at least 3 `takeScreenshot` calls with paths in `/tmp/maestro_07*.png`
- `assertVisible` text matches an actual UI string from the app (not a placeholder)
</acceptance_criteria>
</task>

<task id="07C-T4">
<type>execute</type>
<title>Run IOS-08 Maestro test and document result</title>

<read_first>
- ios/maestro/07_ios08_background_reconnect.yaml — the test created in T3
- re/capture/android-btsnoop.md or ios/maestro/README.md (if exists) — confirm how to run Maestro tests against physical device
</read_first>

<action>
Run the Maestro test against a physical iPhone with WHOOP 5.0 nearby:

```bash
maestro test ios/maestro/07_ios08_background_reconnect.yaml
```

Document the result:
- If PASS: note the actual reconnect time observed (from screenshots timestamps or log)
- If FAIL with "assertVisible" timeout: the willRestoreState path may require the WHOOP to be in range and Phase 6 backfill to be running — document what was observed instead

If the Maestro test cannot be run on CI (no physical device): document "manual validation required — physical iPhone + WHOOP 5.0 in range" as the blocker. The test file is still committed as the artifact; hardware execution is the validation.

Update REQUIREMENTS.md:
- Mark `IOS-08` as `[x]` if the Maestro test PASSED on device
- Leave `[ ]` with a note if hardware test was not run in this session
</action>

<acceptance_criteria>
- Maestro test file exists at `ios/maestro/07_ios08_background_reconnect.yaml` (from T3)
- Either: `maestro test` exits 0 on physical device (IOS-08 PASS), OR a note is added to this task documenting "hardware test pending — test file ready for execution"
- `.planning/REQUIREMENTS.md` IOS-08 entry updated to `[x]` if test passed, otherwise `[ ]` with note
</acceptance_criteria>
</task>

<task id="07C-T5">
<type>execute</type>
<title>Update REQUIREMENTS.md for validated iOS views</title>

<read_first>
- .planning/REQUIREMENTS.md — IOS-03, IOS-04, IOS-05, IOS-08 entries (lines ~17-22)
</read_first>

<action>
Update `.planning/REQUIREMENTS.md` based on results from T1–T4:

- **IOS-03**: Change to `[x]` if TodayView showed real recovery score + HRV (T1 confirmed)
- **IOS-04**: Change to `[x]` if SleepView showed real sleep sessions with staging (T2 confirmed)
- **IOS-05**: Leave as `[ ]` — DEFERRED to Phase 9. Add note: "(deferred to Phase 9 SwiftUI Redesign)"
- **IOS-08**: Change to `[x]` if Maestro test passed on device (T4); leave `[ ]` with note if pending hardware

Do NOT check IOS-05. Confirm that `MetricKind.dailyCases` and `TrendsView.swift` were NOT modified in this phase (search for any uncommitted changes to those files).
</action>

<acceptance_criteria>
- `grep "\[x\].*IOS-03" .planning/REQUIREMENTS.md` returns 1 match (if T1 confirmed)
- `grep "\[x\].*IOS-04" .planning/REQUIREMENTS.md` returns 1 match (if T2 confirmed)
- `grep "\[ \].*IOS-05" .planning/REQUIREMENTS.md` returns 1 match (IOS-05 remains unchecked)
- `grep "deferred\|Phase 9" .planning/REQUIREMENTS.md` returns at least 1 match for IOS-05
- No modifications to `ios/OpenWhoop/Tabs/TrendsView.swift` or `ios/OpenWhoop/Charts/MetricKind.swift` in this phase (git diff --name-only shows these files are not changed)
</acceptance_criteria>
</task>

</tasks>

<verification>
1. `ls ios/maestro/07_ios08_background_reconnect.yaml` — Maestro test file exists
2. `grep "stopApp" ios/maestro/07_ios08_background_reconnect.yaml` — force-quit step present
3. `grep "30000" ios/maestro/07_ios08_background_reconnect.yaml` — 30s reconnect timeout present
4. `grep "\[x\].*IOS-03" .planning/REQUIREMENTS.md` — IOS-03 checked (if hardware validated)
5. `grep "\[x\].*IOS-04" .planning/REQUIREMENTS.md` — IOS-04 checked (if hardware validated)
6. `grep "\[ \].*IOS-05" .planning/REQUIREMENTS.md` — IOS-05 remains unchecked (deferred)
7. `git diff --name-only | grep -E "TrendsView|MetricKind"` — returns nothing (those files untouched)
</verification>

<must_haves>
truths:
  - IOS-05 (TrendsView SpO₂/skinTemp series) is NOT implemented in Phase 7 — deferred to Phase 9
  - MetricKind.swift and TrendsView.swift are NOT modified in this plan
  - Maestro test 07_ios08_background_reconnect.yaml follows the exact appId/flow structure of tests 01–06
  - willRestoreState reconnect timeout in Maestro is set to ≥ 30000ms (matching IOS-08 success criterion)
  - REQUIREMENTS.md IOS-03, IOS-04 are only marked done if physical device validation confirmed real data (not placeholder)
</must_haves>

<threat_model>
- **Phase 6 not ready:** This plan depends on Phase 6 (depends_on: [06A, 06B]). If backfill is not functional, T1 and T2 will fail validation. Mitigation: tasks explicitly require documenting the blocker rather than fabricating validation results.
- **Maestro assertVisible wrong string:** The "Connected" text may not match the actual UI string. Mitigation: T3 read_first explicitly requires reading LiveView or RootTabView before writing the assertVisible text.
- **IOS-05 accidentally implemented:** TrendsView or MetricKind modified. Mitigation: T5 and verification step 7 both check for this explicitly.
</threat_model>
