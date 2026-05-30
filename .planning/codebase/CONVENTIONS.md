# Coding Conventions

**Analysis Date:** 2026-05-30

## Naming Patterns

**Files:**
- Swift source files: `PascalCase.swift` matching the primary type (e.g. `FrameRouter.swift`, `BLEManager.swift`)
- Python source files: `snake_case.py` (e.g. `framing.py`, `hrv.py`, `test_hrv.py`)
- Swift test files: `<Subject>Tests.swift` in a parallel `Tests/` or `OpenWhoopTests/` directory
- Python test files: `test_<module>.py` per pytest convention

**Types / Classes:**
- Swift: `PascalCase` for all types — `final class BLEManager`, `struct FieldSpec`, `enum WH`, `protocol StoreWriting`
- Python: `PascalCase` for dataclasses and pytest class suites — `class FrameCheck`, `class TestFilterRR`

**Functions / Methods:**
- Swift: `camelCase` — `verifyFrame()`, `bootstrapStore()`, `shouldRunPeriodicBackfill()`
- Python: `snake_case` — `verify_frame()`, `frame_from_payload()`, `derive_clock_ref()`

**Properties / Variables:**
- Swift: `camelCase` — `heartRate`, `batteryPct`, `connectHandshakeDone`, `backfillLastAtKey`
- Python: `snake_case` — `clock_ref`, `batch_id`, `device_id`

**Constants / Enum namespaces:**
- Swift: `static let camelCase` inside a `PascalCase` type — `BLEManager.backfillIntervalSeconds`, `WH.Color.background`
- Design tokens namespaced under `enum WH` with nested enums `WH.Color`, `WH.Spacing`, `WH.Radius`, `WH.Font`
- See: `ios/OpenWhoop/Design/DesignTokens.swift`

## Code Style

**Formatting (Swift):**
- No SwiftFormat or SwiftLint config detected — Xcode default conventions:
  - 4-space indentation
  - Opening brace on same line as declaration
  - Trailing closures: `t.setEventHandler { [weak self] in ... }`
  - Explicit `[weak self]` captures in all retained closures

**Formatting (Python):**
- No `.flake8`, `.black`, or `ruff` config detected; PEP 8 by convention
- `from __future__ import annotations` used at the top of analysis files

**Access Control (Swift):**
- `public` for package APIs (`WhoopProtocol`, `WhoopStore` types and methods)
- `internal` (default) for app-level types (`Collector`, `Backfiller`, `FrameRouter`)
- `private` for all fields and helpers; `fileprivate` not used
- `final class` used consistently on all concrete reference types

**Actor isolation:**
- `@MainActor` at class level for all UI-touching types: `BLEManager`, `Collector`, `Backfiller`, `FrameRouter`, `LiveViewModel`, `MetricsRepository`
- Test classes annotate `@MainActor` on the whole `final class` when testing actor-isolated types

## Import Organization

**Swift order (observed):**
1. Apple system frameworks: `Foundation`, `SwiftUI`, `Combine`
2. Apple domain frameworks: `CoreBluetooth`, `GRDB`
3. Local SPM packages: `WhoopProtocol`, `WhoopStore`
4. `@testable import TargetName` last, in test files only

**Python order (observed):**
1. `from __future__ import annotations` (when present)
2. Standard library: `os`, `sys`, `struct`, `zlib`, `dataclasses`
3. Third-party: `numpy`, `pytest`, `psycopg`, `fastapi`
4. Local: `from app.analysis.hrv import ...`, `from whoop_protocol.framing import ...`

## Error Handling

**Swift patterns:**
- `guard let … else { return }` — dominant pattern for optional unwrapping in void contexts
- `try?` + `guard` for non-critical failures:
  ```swift
  guard let path = try? StorePaths.defaultDatabasePath() else { return }
  guard let store = try? await WhoopStore(path: path) else { return }
  ```
- `fatalError()` reserved for missing required Bundle resources
- `throws` propagation — `WhoopStore` async methods throw; callers use `try await`
- Never force-unwrap (`!`) in production paths; `!` is used in test fixtures on known-good data only

**Python patterns:**
- Functions return `None` for "not found"; raise for truly unexpected inputs
- Pytest tests use bare `assert` statements

## Logging

**Framework (Swift):** Custom `private func log(_ s: String)` on `BLEManager` appends to `LiveState.logLines`. No `os.log` or `print` in production code.

**Format:** `[HH:mm:ss] message` — timestamp via a static cached `DateFormatter`

**Patterns:**
- Log significant lifecycle events: connect, bond, backfill start/end, clock correlation, errors
- Command sends use direction prefix: `→ COMMAND_NAME payload=hex`
- Do NOT log full raw BLE frame bytes

**Python:** No structured logging — bare `print` in research scripts; FastAPI default logging in server.

## Comments

**When to Comment:**
- Explain non-obvious decisions and constraints discovered via reverse engineering
- Document "why NOT" when obvious alternatives were ruled out
- Mark regression fixes with `// MARK: - REGRESSION:` in both source and test files

**Format:**
- `/// ` triple-slash doc comment for all `public` API functions and types
- `// MARK: -` section dividers used throughout
- `// MARK: - REGRESSION:` prefix before regression test blocks in test files

## Function Design

**Dependency injection pattern:**
```swift
init(store: StoreWriting, deviceId: String,
     policy: CollectorPolicy = .default,
     enableRawCapture: Bool = false,
     now: @escaping () -> Int = { Int(Date().timeIntervalSince1970) },
     monotonic: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate })
```
Injected closures (e.g. `monotonic`, `now`) replace singletons to enable deterministic unit tests.

**Return Values:**
- Named tuple returns for multi-value results
- Return `nil` for "not found" or "precondition not met"
- `@discardableResult` used when callers legitimately ignore the return value

## Module Design

**Swift SPM packages:**
- `Packages/WhoopProtocol` — pure decode library; no UIKit/SwiftUI/CoreBluetooth imports
- `Packages/WhoopStore` — SQLite persistence via GRDB; no app-layer imports
- `ios/OpenWhoop` (app target) — imports both packages; owns BLE, UI, and sync logic

**Protocols as test seams:**
- `StoreWriting` protocol allows test injection of `SpyStore` without subclassing `final WhoopStore`
- `StubURLProtocol` (a `URLProtocol` subclass) intercepts all `URLSession` traffic in networking tests

**Barrel files:** Not used — each type lives in its own file and is imported directly.
