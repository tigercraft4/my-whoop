# Technology Stack — v4.0 Milestone

**Project:** OpenWhoop WHOOP 5.0 — v4.0 UI Redesign + Bug Fix
**Researched:** 2026-06-01
**Scope:** Stack additions/changes for Ghidra IPA automation, SwiftUI 1:1 UI replication, and BLE/GRDB/SwiftUI debugging
**Confidence:** HIGH

---

## Summary

v4.0 does not require significant new dependencies. The existing stack (Ghidra 12.1.1 + GhidraMCP 5.12.0 + bridge_mcp_ghidra.py, Swift 6.3.2 + SwiftUI + GRDB 6.29.3) already supports all three goal areas. What is needed is:

1. **Ghidra scripting automation** — PyGhidra 3.1.0 is bundled with the already-installed Ghidra 12.1.1 but not yet installed as a Python module. Installing it enables batch Python 3 scripts against the already-loaded IPA without the GUI. The existing bridge (`bridge_mcp_ghidra.py`) covers interactive one-off queries; `pyghidra` covers batch extraction pipelines.

2. **SwiftUI 1:1 UI replication** — zero new Swift packages needed. The existing design system (`WH` enum in `DesignTokens.swift`, `Design/Components/`) is the right foundation. The additions are workflow tools: `swift-snapshot-testing` for pixel-accurate regression, and the already-present XcodeBuildMCP for UI hierarchy inspection and screenshot capture. No SwiftUI Layout extension library is warranted — the iOS 16 `Layout` protocol is sufficient.

3. **Debugging** — GRDB 6.29.3 `Configuration.trace` already enables full SQL tracing. OSLog (system framework) already in the codebase. The only additions are workflow-level: structured log subsystems per component (BLE, backfill, GRDB), and `GRDB.Configuration.publicStatementArguments = true` in DEBUG builds. No new packages.

**Net new packages: 1 Swift (swift-snapshot-testing) + 0 Python + PyGhidra module install.**

---

## Ghidra IPA Analysis Stack

### Current State (what already works)

| Component | Version | Status |
|-----------|---------|--------|
| Ghidra | 12.1.1 (Homebrew) | Installed — `/opt/homebrew/Cellar/ghidra/12.1.1/libexec` |
| GhidraMCP plugin | 5.12.0 | Installed in user extensions — 245 MCP tools, HTTP server on :8080 |
| bridge_mcp_ghidra.py | project file | Wraps GhidraMCP HTTP as MCP stdio — `list_methods`, `search_functions_by_name`, `decompile_function`, `list_strings` etc. |
| PyGhidra | 3.1.0 | Bundled in Ghidra install (`pypkg/dist/pyghidra-3.1.0-py3-none-any.whl`) — **NOT YET INSTALLED** as Python module |
| JPype | 1.5.2 | Bundled alongside PyGhidra — `jpype1-1.5.2` wheels present for all Python versions |
| ghidra-bridge | 1.0.0 (pip) | Installed — legacy Jython-based bridge, superseded by PyGhidra for new scripts |

### Addition: Install PyGhidra as Python module

**Why:** PyGhidra 3.1.0 provides native CPython 3 access to the full Ghidra Java API (`FlatProgramAPI`, `FlatDecompilerAPI`, all symbol/string/xref APIs) via JPype. This enables batch extraction scripts — e.g. dump all string literals matching UI patterns, walk all Swift class namespaces, bulk-decompile functions by prefix — without Ghidra GUI interaction and without GhidraMCP's HTTP round-trip overhead (which times out on 477k-function binaries).

The existing `ghidra-bridge` (Jython) cannot use modern Python 3 libraries (pandas, json streaming). PyGhidra uses real CPython 3.

**Install (one command):**
```bash
python3 -m pip install --no-index \
  -f /opt/homebrew/Cellar/ghidra/12.1.1/libexec/Ghidra/Features/PyGhidra/pypkg/dist \
  pyghidra
```

**Verification:**
```python
import pyghidra
with pyghidra.open_program("/tmp/whoop_ipa_deep/Payload/Whoop.app/Whoop") as flat_api:
    prog = flat_api.getCurrentProgram()
    print(prog.getName(), prog.getFunctionManager().getFunctionCount())
    # Expected: Whoop 477055
```

**Confidence: HIGH** — PyGhidra 3.1.0 + JPype 1.5.2 wheels are physically present in the Ghidra install. `analyzeHeadless` and `pyghidraRun` scripts already exist in `/opt/homebrew/Cellar/ghidra/12.1.1/libexec/support/`.

### Python version constraint

The bundled JPype wheel for macOS is `cpython-310`. The system Python is 3.9.6 (`/usr/bin/python3`). **Use a Python 3.10+ environment** for PyGhidra scripting, or install via `brew install python@3.10` and use `python3.10 -m pip install ...`. Alternatively use the `pyghidraRun` script which manages its own environment.

| Python version | PyGhidra support | Notes |
|---------------|-----------------|-------|
| 3.9 (system) | No — jpype wheel missing | Bundled wheels start at 3.10 |
| 3.10 | Yes | Bundled wheel: `cpython-310-macosx_10_9_universal2` |
| 3.11 | Yes | Bundled wheel available |
| 3.12 | Yes | Bundled wheel available |
| 3.13 | Yes | Bundled wheel available |

### Scripting approach: Python vs Java

**Use Python (PyGhidra/GhidraScript)** for all batch extraction tasks in v4.0. Do not write Java scripts.

| Criterion | Python (PyGhidra) | Java (GhidraScript) |
|-----------|-------------------|---------------------|
| Iteration speed | Fast — edit-and-run | Slow — compile cycle |
| JSON/CSV output | Native stdlib | Requires Gson or manual |
| Integration with existing scripts | Direct — same Python toolchain as `re/` scripts | Separate build system |
| Access to Ghidra API | Full via JPype | Full native |
| Debugging | pdb, print statements | Ghidra console |
| When to use | All v4.0 extraction tasks | Only if JPype bridge has a specific API gap |

Java scripts are warranted only when a Ghidra API requires a Java-specific interface that JPype cannot bridge (rare in v4.0 scope).

### Extraction workflow for UI specs

The IPA (Whoop binary at `/tmp/whoop_ipa_deep/Payload/Whoop.app/Whoop`) is already loaded and analysed in Ghidra. The analysis is complete (Ghidra persists the project at `~/Library/ghidra/ghidra_12.1.1_PUBLIC/`).

**Recommended extraction pipeline:**

1. **String scan for UI labels** — `list_strings` via bridge or `currentProgram().getStringData()` via PyGhidra. Filter for known UI patterns: `"RECOVERY"`, `"STRAIN"`, `"SLEEP PERFORMANCE"`, `"HRV"`, tab titles, section headers.

2. **Namespace walk for Swift class hierarchy** — `currentProgram().getSymbolTable().getSymbols()` filtered by namespace. Swift mangled names follow `_TtC<module><class>` or `$s<module><class>`. Extract class names, method names, and their addresses.

3. **Function search by keyword** — `search_functions_by_name` (via existing bridge) or `getGlobalFunctions("<prefix>")`. Target UI-related prefixes: `CoachViewController`, `RecoveryViewController`, `TodayViewController`, `TabBarController`, `MetricCard`, `SleepCard`.

4. **Decompile targeted functions** — `decompile_function` (bridge) or `FlatDecompilerAPI` (PyGhidra). Target the `body` property or `setupView` methods of identified view controllers.

5. **Xref walk for colour/font constants** — `get_xrefs_to` on addresses of known constants (e.g. `0x1058a5a80` for Keytel coefficients). Identify which functions reference UI token addresses.

**Output format:** Write extracted specs to `re/capture/samples/ipa/ui-specs-v4.json` (gitignored). Structure: `{ "screen": "Today", "components": [...], "labels": {...}, "colors": [...] }`. Feed these JSON files into the SwiftUI build phase.

### What NOT to use for Ghidra automation

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Jython (`ghidra-bridge` 1.0.0) | Python 2 syntax, no modern stdlib, no pip packages | PyGhidra 3.1.0 |
| Ghidrathon (Mandiant) | Requires separate Ghidra extension install; PyGhidra is now native | PyGhidra (built into Ghidra 12+) |
| Java GhidraScript for batch tasks | Slow iteration, no JSON stdlib | Python via PyGhidra |
| `analyzeHeadless` on the already-loaded project | Re-runs analysis from scratch, takes hours on 477k functions | `pyghidra.open_program()` with `analyze=False` on existing project |

---

## SwiftUI 1:1 UI Replication Stack

### Current State (what already works)

| Component | Version | Status |
|-----------|---------|--------|
| Swift | 6.3.2 (swiftlang-6.3.2.1.108) | Installed — Xcode 26 toolchain |
| SwiftUI | iOS 16.0+ | Deployment target set; all Layout protocol features available |
| GRDB | 6.29.3 | Pinned in `WhoopStore/Package.resolved` |
| WH design system | project code | `DesignTokens.swift` — colors, spacing, radius, fonts; `Design/Components/` — MetricCard, RecoveryRing, RecoveryCard, SleepCard, StrainCard, Sparkline, ZoneRingView |
| DesignGallery | project code | Living visual reference view — use as-is for regression checks |
| XcodeBuildMCP | MCP server | `snapshot_ui` captures accessibility hierarchy with pixel coordinates; `capture_screenshot` captures PNG; `attach_lldb` / `set_breakpoint` for runtime debugging |
| Maestro | flows present at `ios/maestro/` | YAML flows exist; `maestro` binary not in PATH — install if automated flow testing needed |

### Addition: swift-snapshot-testing

**Why:** SwiftUI 1:1 replication means pixel-accurate regression. Without snapshot tests, every UI change requires manual visual inspection on device/simulator. `swift-snapshot-testing` from Point-Free captures `assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneX)))` and fails the test with a diff image when pixels change. This is the only reliable way to confirm a replication is 1:1 and stays that way through bug-fix iterations.

**Use case in v4.0:** After extracting UI specs from Ghidra, implement each screen, add a snapshot test, and commit the reference PNG. Any subsequent bug-fix that accidentally changes layout will fail CI immediately.

**Package:** `https://github.com/pointfreeco/swift-snapshot-testing` — `from: "1.17.6"` (latest stable as of 2026-06-01).

**Add to `ios/project.yml`:**
```yaml
packages:
  WhoopProtocol:
    path: ../Packages/WhoopProtocol
  WhoopStore:
    path: ../Packages/WhoopStore
  SnapshotTesting:
    url: https://github.com/pointfreeco/swift-snapshot-testing
    from: "1.17.6"

targets:
  OpenWhoopTests:
    dependencies:
      - package: WhoopProtocol
      - package: WhoopStore
      - package: SnapshotTesting
```

**Usage pattern:**
```swift
import SnapshotTesting
import SwiftUI
import XCTest

final class TodayViewSnapshotTests: XCTestCase {
    func testTodayView_recoveryGreen() {
        let view = TodayView()
            .environment(\.colorScheme, .dark)
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone16ProMax), traits: UITraitCollection(userInterfaceStyle: .dark)),
            record: false  // set true once to create reference PNG
        )
    }
}
```

**Confidence: HIGH** — verified via Context7 `/pointfreeco/swift-snapshot-testing`. The library supports SwiftUI views directly, dark mode trait collections, and device configs including iPhone 16 Pro Max. Tests run on simulator (no physical device needed for snapshot comparison).

### SwiftUI Layout patterns for pixel-accurate replication

**No new packages needed.** The iOS 16 `Layout` protocol, `GeometryReader`, `PreferenceKey`, and `matchedGeometryEffect` are sufficient for any layout found in the WHOOP app. Use these patterns:

| Pattern | When | API |
|---------|------|-----|
| Custom ring with exact stroke width | Recovery/Strain rings | `Circle().trim().stroke(style: StrokeStyle(lineWidth: N, lineCap: .round))` |
| Size-relative spacing | Cards that scale to screen width | `GeometryReader` → `geometry.size.width * ratio` |
| Matched geometry transitions | Tab switch animations | `matchedGeometryEffect(id:in:)` with `@Namespace` |
| Custom equal-width grid | Metric card rows | `Layout` protocol `sizeThatFits` + `placeSubviews` |
| Preference-based size propagation | Child-to-parent size reporting | `PreferenceKey` + `onPreferenceChange` |

**Do not** reach for third-party layout libraries (TCA, Composable Architecture, etc.) — the existing MVVM + Combine + GRDB architecture is stable and sufficient.

### XcodeBuildMCP for UI inspection (already available)

The XcodeBuildMCP MCP server is active. Use it for:

- `snapshot_ui` — captures the full accessibility hierarchy as JSON with `AXFrame` coordinates. Use this to measure exact pixel positions of UI elements in the official WHOOP app (if running in Simulator from App Store). Compare against your implementation's `snapshot_ui` output.
- `capture_screenshot` — captures PNG of the simulator screen at any point. Use for side-by-side comparison with Ghidra-extracted UI specs.
- `attach_lldb` + `set_breakpoint` + `get_variable_value` — runtime inspection of SwiftUI state, GRDB query results, BLE frame buffers.

### Instruments.app — not installed, not needed

`Instruments.app` is absent from this machine. For v4.0's debugging needs, the combination of OSLog (system), GRDB SQL trace, and XcodeBuildMCP LLDB is sufficient. Instruments would be needed for memory/CPU profiling (not a v4.0 goal).

### What NOT to add for SwiftUI

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| TCA (The Composable Architecture) | Architectural migration cost; existing MVVM + Combine is stable | Keep MVVM + ObservableObject + Combine |
| Lottie | No evidence of Lottie animations in WHOOP iOS app | SwiftUI `.animation()` + custom transitions |
| SnapKit / Auto Layout bridges | Project is pure SwiftUI; UIKit layout bridges add complexity | SwiftUI Layout protocol |
| Third-party chart library (Charts Kit, etc.) | Swift Charts (system framework, iOS 16+) is already used | Keep `import Charts` |
| SwiftUI Backports package | Deployment target is iOS 16; all needed APIs are available natively | Native SwiftUI APIs |
| Emerge Tools Snapshot Previews | More complex than swift-snapshot-testing; requires Emerge account | `swift-snapshot-testing` (self-hosted, local) |

---

## Debugging Stack

### Current State

| Component | Version | Status |
|-----------|---------|--------|
| OSLog | system framework | Already used (`import OSLog`) in BLEManager and others |
| GRDB SQL trace | `Configuration.trace {}` | Available in GRDB 6.29.3 — not yet wired in DEBUG builds |
| XcodeBuildMCP LLDB | MCP server | `attach_lldb`, `set_breakpoint`, `get_variable_value`, `execute_lldb_command` |
| PacketLogger | Mac system (requires Xcode pairing) | Used for BLE frame capture — already documented in runbooks |

### Addition: GRDB SQL tracing in DEBUG builds

**Why:** The backfill-stuck bug and HRV offset issues are data-layer problems. Without SQL trace, diagnosing incorrect GRDB writes requires print-statement archaeology. One configuration change exposes every SQL statement with arguments in DEBUG builds.

**No new package.** Add to `WhoopStore` init:

```swift
// WhoopStore.swift — DEBUG-only SQL tracing
var config = Configuration()
#if DEBUG
config.publicStatementArguments = true
config.prepareDatabase { db in
    db.trace(options: .profile) { event in
        // Prints: "SQL> <statement> (<args>) — 0.3ms"
        os_log(.debug, log: .grdb, "\(event)")
    }
}
#endif
```

**Confidence: HIGH** — verified via Context7 `/groue/grdb.swift`. `Configuration.publicStatementArguments` and `db.trace(options: .profile)` are GRDB 6.x APIs. Gating behind `#if DEBUG` is the documented GRDB recommendation (privacy: SQL args may contain biometric data).

### Addition: Structured OSLog subsystems

**Why:** The existing codebase uses `OSLog` but without consistent subsystem/category structure, making it hard to filter in Console.app or via `log stream` during BLE debugging sessions.

**No new package.** Add a single extension:

```swift
// Logging.swift — add to app target
import OSLog
extension Logger {
    static let ble      = Logger(subsystem: "com.francisco.openwhoop", category: "BLE")
    static let backfill = Logger(subsystem: "com.francisco.openwhoop", category: "Backfill")
    static let grdb     = Logger(subsystem: "com.francisco.openwhoop", category: "GRDB")
    static let hrv      = Logger(subsystem: "com.francisco.openwhoop", category: "HRV")
    static let ui       = Logger(subsystem: "com.francisco.openwhoop", category: "UI")
}
```

Then filter on Mac: `log stream --predicate 'subsystem == "com.francisco.openwhoop" AND category == "BLE"'`

**Confidence: HIGH** — Apple OSLog `Logger` struct available iOS 14+; project targets iOS 16.

### XcodeBuildMCP LLDB (already available)

For SwiftUI state inspection during UI placeholder bugs:

```
attach_lldb → simulatorId
set_breakpoint → file: "TodayView.swift", line: 42
get_variable_value → variableName: "viewModel.recoveryScore"
execute_lldb_command → command: "po viewModel"
```

For BLE frame debugging:
```
set_breakpoint → function: "BLEManager.handleFrame(_:)"
get_variable_value → variableName: "frame"
execute_lldb_command → command: "memory read -f x -c 32 &frame"
```

### What NOT to add for debugging

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| CocoaLumberjack / SwiftyBeaver | Overkill for a single-device app; OSLog is sufficient | OSLog with structured subsystems |
| Pulse (network inspector) | This app's networking is minimal (server sync only); overhead not justified | OSLog + GRDB trace |
| Firebase Crashlytics | No remote crash reporting needed; this is a personal tool, not a distributed app | XcodeBuildMCP LLDB + OSLog |
| Charles Proxy | For HTTPS traffic inspection — not needed; server communication is simple HTTP to gonzaga over LAN | curl + server logs on gonzaga |
| Inject (hot reload) | Adds complexity; SwiftUI previews + Simulator builds are fast enough | Xcode Simulator build |

---

## Repo Structure Changes

No new packages. The structure cleanup (v4.0 goal) is filesystem reorganisation, not a dependency change. Recommended additions to the existing layout:

```
re/
  scripts/
    ui_extract.py          # NEW: PyGhidra batch extraction script
    decode_keytel_coeffs.py # NEW: decode 0x1058a5a80 Keytel constants
  capture/samples/ipa/
    ui-specs-v4.json       # NEW: gitignored; extracted UI specs

ios/
  OpenWhoopTests/
    Snapshots/             # NEW: reference PNGs from swift-snapshot-testing (gitignored or committed)
    TodayViewSnapshotTests.swift   # NEW
    SleepViewSnapshotTests.swift   # NEW
```

---

## Installation Summary

### 1. PyGhidra (one-time, no project file change)

```bash
# Requires Python 3.10+ (Ghidra 12.1.1 bundles cp310 wheels)
brew install python@3.10   # if not already installed
python3.10 -m pip install --no-index \
  -f /opt/homebrew/Cellar/ghidra/12.1.1/libexec/Ghidra/Features/PyGhidra/pypkg/dist \
  pyghidra
```

### 2. swift-snapshot-testing (project.yml + Package.resolved)

```yaml
# ios/project.yml — add to packages block
SnapshotTesting:
  url: https://github.com/pointfreeco/swift-snapshot-testing
  from: "1.17.6"
```

Then `xcodebuild -resolvePackageDependencies` or open Xcode and let SPM resolve.

### 3. GRDB SQL tracing + OSLog subsystems (code-only, no package)

Add `Logging.swift` to app target. Add `#if DEBUG` trace block to `WhoopStore` init.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Ghidra 12.1.1 | PyGhidra 3.1.0 + JPype 1.5.2 | Bundled together — guaranteed compatible |
| PyGhidra 3.1.0 | Python 3.10–3.13 | cp39 wheel absent from Ghidra 12.1.1 bundle |
| GRDB 6.29.3 | Swift 5.9+, iOS 16+ | Confirmed via `Package.resolved` |
| swift-snapshot-testing 1.17.6 | Swift 5.7+, iOS 16+, Xcode 15+ | Point-Free library; no UIKit dependency for SwiftUI snapshots |
| Swift 6.3.2 | GRDB 6.29.3 | GRDB declares `swiftLanguageVersions: [.v5]`; compiles under Swift 6 with strict-concurrency warnings (not errors) |

---

## Sources

- Context7 `/nationalsecurityagency/ghidra` — PyGhidra `open_program`, `run_script`, headless scripting patterns (HIGH confidence)
- Context7 `/nationalsecurityagency/ghidra` (Ghidra Headless docs) — `HeadlessAnalyzer`, `analyzeHeadless` CLI (HIGH confidence)
- Context7 `/mandiant/ghidrathon` — confirmed Ghidrathon is superseded by PyGhidra for Ghidra 11+ (HIGH confidence)
- Context7 `/clearbluejar/pyghidra-mcp` — `pyghidra-mcp-cli` batch workflow patterns (MEDIUM — alternative tooling, not used here)
- Local inspection: `/opt/homebrew/Cellar/ghidra/12.1.1/libexec/Ghidra/Features/PyGhidra/pypkg/dist/` — physically verified wheels present (HIGH confidence)
- Local inspection: `~/Library/ghidra/ghidra_12.1.1_PUBLIC/Extensions/*.properties` — GhidraMCP 5.12.0 confirmed (HIGH confidence)
- Context7 `/pointfreeco/swift-snapshot-testing` — SwiftUI `.image(layout: .device(...))` snapshots, dark mode traits (HIGH confidence)
- Context7 `/websites/developer_apple_swiftui` — `Layout` protocol iOS 16+, `GeometryReader`, `PreferenceKey`, `matchedGeometryEffect` (HIGH confidence)
- Context7 `/groue/grdb.swift` — `Configuration.trace(options: .profile)`, `publicStatementArguments`, `DatabaseError` fields (HIGH confidence)
- Local inspection: `Packages/WhoopStore/Package.resolved` — GRDB 6.29.3 pinned revision confirmed (HIGH confidence)
- Local inspection: `ios/OpenWhoop.xcodeproj/project.pbxproj` — SWIFT_VERSION = 5.0, IPHONEOS_DEPLOYMENT_TARGET = 16.0 (HIGH confidence)
- Context7 `/getsentry/xcodebuildmcp` — `snapshot_ui`, `capture_screenshot`, `attach_lldb` tool signatures (HIGH confidence)

---
*Stack research for: OpenWhoop v4.0 — Ghidra IPA automation, SwiftUI 1:1 UI replication, BLE/GRDB/SwiftUI debugging*
*Researched: 2026-06-01*
