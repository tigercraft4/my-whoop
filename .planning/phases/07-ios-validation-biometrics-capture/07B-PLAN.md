---
phase: 7
plan: 07B
title: "iOS TOGGLE_IMU_MODE Debug Button"
wave: 1
depends_on: []
files_modified:
  - ios/OpenWhoop/BLE/Commands.swift
  - ios/OpenWhoop/BLE/BLEManager.swift
  - ios/OpenWhoop/Settings/SettingsView.swift
autonomous: true
requirements: []
---

<objective>
Add a `toggleIMUMode` debug button to the Settings tab of the iOS app so that TOGGLE_IMU_MODE can be sent to the WHOOP 5.0 directly from the iPhone without requiring the Python harness. The button is gated behind `#if DEBUG` and shows current IMU mode state (ON/OFF).
</objective>

<context>
`WhoopCommand` enum in `ios/OpenWhoop/BLE/Commands.swift` already has `case toggleIMUMode = 106` (rawValue 106). `BLEManager.send(_:payload:)` is the public method to dispatch commands with Maverick framing. SettingsView.swift uses a `Section`-based Form layout with a `Button` inside `saveSection` — the same pattern applies for the debug section.

The button must:
- Live in a `#if DEBUG` section of SettingsView (not visible in Release builds)
- Show current IMU mode state using a `@State` bool (`imuModeOn: Bool`)
- Send `.toggleIMUMode` with payload `[0x01]` to turn ON, `[0x00]` to turn OFF
- Use `BLEManager.logger.notice(...)` for the action log (matches existing `.notice` log-level pattern throughout BLEManager)
- Be labeled "IMU Mode: ON" or "IMU Mode: OFF" to reflect current state

This plan does NOT require a physical WHOOP connection for implementation — it is a UI + BLE command wiring task. Hardware validation happens in Plan 07A.
</context>

<tasks>

<task id="07B-T1">
<type>execute</type>
<title>Verify Commands.swift has toggleIMUMode and no duplicates</title>

<read_first>
- ios/OpenWhoop/BLE/Commands.swift — full file; confirm `case toggleIMUMode = 106` exists (line ~67), verify no other case has rawValue 106
</read_first>

<action>
Read `ios/OpenWhoop/BLE/Commands.swift` in full. Confirm:
1. `case toggleIMUMode = 106` exists in the `WhoopCommand` enum
2. No duplicate rawValue 106 exists in the enum
3. The `label` computed property has a case for `toggleIMUMode` (if not, add: `case .toggleIMUMode: return "Toggle IMU Mode"`)

If `label` case is missing, add it to the switch in the `label` var — following the alphabetical or logical ordering already present.

No other changes to Commands.swift are required.
</action>

<acceptance_criteria>
- `grep "toggleIMUMode" ios/OpenWhoop/BLE/Commands.swift` returns exactly 1 enum case line and 1 label case line (or 1 enum case if label already covers it via default)
- `grep "= 106" ios/OpenWhoop/BLE/Commands.swift` returns exactly 1 match
- `swift build` (or Xcode build) for the OpenWhoop target does not produce errors related to Commands.swift
</acceptance_criteria>
</task>

<task id="07B-T2">
<type>execute</type>
<title>Add sendToggleIMUMode helper to BLEManager</title>

<read_first>
- ios/OpenWhoop/BLE/BLEManager.swift — read the `send(_:payload:)` public method signature (lines ~250–270), and the `setAlarmTime` or `runAlarm` methods as a pattern for wrapping send() in a public convenience method (lines ~553, ~100)
- ios/OpenWhoop/BLE/Commands.swift — confirm toggleIMUMode rawValue and label (from T1)
</read_first>

<action>
Add a public convenience method to `BLEManager.swift` after the existing `disableAlarm()` or similar utility methods:

```swift
/// Send TOGGLE_IMU_MODE command to the strap.
/// - Parameter on: `true` to activate IMU/biometric streams; `false` to deactivate.
public func toggleIMUMode(on: Bool) {
    let payload: [UInt8] = on ? [0x01] : [0x00]
    log("toggleIMUMode(on: \(on))")
    send(.toggleIMUMode, payload: payload)
}
```

Use `log(...)` (the existing BLEManager internal logger method) — not `BLEManager.logger.notice(...)` directly in this method, since `log()` already calls the logger internally at `.notice` level (verify this in the existing log() implementation before writing).

Placement: add the method in the MARK section that contains device control commands (near `runHapticsPattern`, `setAlarmTime`, etc.) — search for `// MARK: - Commands` or equivalent.
</action>

<acceptance_criteria>
- `grep "func toggleIMUMode" ios/OpenWhoop/BLE/BLEManager.swift` returns 1 match
- Method accepts a `Bool` parameter and calls `send(.toggleIMUMode, payload:)` with `[0x01]` for `true` and `[0x00]` for `false`
- No compiler errors in BLEManager.swift (verify by checking for syntax correctness in the file)
</acceptance_criteria>
</task>

<task id="07B-T3">
<type>execute</type>
<title>Add IMU Mode debug section to SettingsView</title>

<read_first>
- ios/OpenWhoop/Settings/SettingsView.swift — full file; understand the Form structure, the list of `private var XxxSection: some View` computed properties, how `@EnvironmentObject` or `@ObservedObject` is used to access BLEManager (or how to access it)
- ios/OpenWhoop/App/RootTabView.swift or OpenWhoopApp.swift — check how BLEManager is injected into the environment (to confirm `@EnvironmentObject var ble: BLEManager` pattern or similar)
</read_first>

<action>
In `ios/OpenWhoop/Settings/SettingsView.swift`:

1. Add `@EnvironmentObject var ble: BLEManager` if not already present (check first — it may already exist)

2. Add a `@State private var imuModeOn: Bool = false` property to the SettingsView struct

3. Add a private computed property `debugSection` inside a `#if DEBUG / #endif` block:

```swift
#if DEBUG
private var debugSection: some View {
    Section(header: Text("Developer")) {
        Button(action: {
            imuModeOn.toggle()
            ble.toggleIMUMode(on: imuModeOn)
        }) {
            HStack {
                Text("IMU Mode")
                Spacer()
                Text(imuModeOn ? "ON" : "OFF")
                    .foregroundColor(imuModeOn ? .green : .secondary)
            }
        }
    }
}
#endif
```

4. In the Form body (where `unitsSection`, `heightSection`, etc. are listed), add `debugSection` at the end inside `#if DEBUG / #endif`:

```swift
#if DEBUG
debugSection
#endif
```

Placement: after `footerSection` (the last existing section) so the debug section appears at the bottom of the form.
</action>

<acceptance_criteria>
- `grep "imuModeOn" ios/OpenWhoop/Settings/SettingsView.swift` returns ≥ 2 matches (@State declaration + usage in button)
- `grep "#if DEBUG" ios/OpenWhoop/Settings/SettingsView.swift` returns ≥ 1 match wrapping the debugSection
- `grep "debugSection" ios/OpenWhoop/Settings/SettingsView.swift` returns ≥ 2 matches (definition + usage in Form body)
- `grep "IMU Mode" ios/OpenWhoop/Settings/SettingsView.swift` returns ≥ 1 match
- Swift build succeeds (no compilation errors in SettingsView.swift)
</acceptance_criteria>
</task>

<task id="07B-T4">
<type>execute</type>
<title>Build iOS app and confirm debug section compiles</title>

<read_first>
- ios/OpenWhoop/BLE/Commands.swift — confirm final state
- ios/OpenWhoop/BLE/BLEManager.swift — confirm toggleIMUMode method present
- ios/OpenWhoop/Settings/SettingsView.swift — confirm debug section present
</read_first>

<action>
Build the iOS app for simulator to confirm no compilation errors:
- Use xcodebuild or XcodeBuildMCP build_sim to build the OpenWhoop scheme
- Check build output for errors related to:
  - SettingsView.swift (debugSection, imuModeOn, toggleIMUMode call)
  - BLEManager.swift (toggleIMUMode method)
  - Commands.swift (toggleIMUMode case)

If any build errors appear, fix them before marking this task complete.
</action>

<acceptance_criteria>
- `xcodebuild build -scheme OpenWhoop -destination "platform=iOS Simulator"` exits with code 0 (or XcodeBuildMCP build_sim reports success)
- No compilation errors in BLEManager.swift, Commands.swift, or SettingsView.swift
- Build output does not contain "error:" for any of the modified files
</acceptance_criteria>
</task>

</tasks>

<verification>
1. `grep "func toggleIMUMode" ios/OpenWhoop/BLE/BLEManager.swift` — method exists
2. `grep "#if DEBUG" ios/OpenWhoop/Settings/SettingsView.swift` — debug gate present
3. `grep "IMU Mode" ios/OpenWhoop/Settings/SettingsView.swift` — UI label present
4. `grep "case toggleIMUMode = 106" ios/OpenWhoop/BLE/Commands.swift` — command still correct rawValue
5. Simulator build succeeds (via XcodeBuildMCP or xcodebuild) — exit code 0
</verification>

<must_haves>
truths:
  - Debug section is wrapped in #if DEBUG — not visible in Release builds
  - Button state (imuModeOn) correctly maps to payload [0x01] ON / [0x00] OFF
  - toggleIMUMode method in BLEManager delegates to existing send(_:payload:) — no new BLE infrastructure
  - App compiles without errors
</must_haves>

<threat_model>
- **Debug code leaking to Release:** If #if DEBUG guard is missing or misplaced. Mitigation: acceptance criteria explicitly grep for #if DEBUG in SettingsView.
- **BLEManager not in environment:** SettingsView may not have @EnvironmentObject var ble. Mitigation: T3 read_first includes RootTabView/App injection check before writing.
- **Duplicate rawValue:** Another command accidentally shares rawValue 106. Mitigation: T1 explicitly checks for duplicates with grep.
</threat_model>
