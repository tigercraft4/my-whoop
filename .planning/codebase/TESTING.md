# Testing Patterns

**Analysis Date:** 2026-05-30

## Test Frameworks

**Swift (iOS + SPM packages):**
- Runner: XCTest (built into Xcode / swift test)
- Config: `ios/project.yml` (XcodeGen) declares `OpenWhoopTests` as `bundle.unit-test`; SPM packages declare `.testTarget` in their `Package.swift`
- No third-party assertion library — only XCTest assertions

**Python (server + whoop-protocol package):**
- Runner: pytest >= 8
- Config: `[tool.pytest.ini_options]` in `server/packages/whoop-protocol/pyproject.toml` (`testpaths = ["tests"]`)
- Integration tests: `pytest` + `httpx` (FastAPI `TestClient`) + `psycopg` + Docker-managed TimescaleDB

**Run Commands:**
```bash
# Swift — SPM package tests
swift test --package-path Packages/WhoopProtocol
swift test --package-path Packages/WhoopStore

# Swift — app unit tests
xcodebuild test -project ios/OpenWhoop.xcodeproj -scheme OpenWhoopTests \
  -destination 'platform=iOS Simulator,...'

# Python — whoop-protocol package
cd server/packages/whoop-protocol && pip install -e ".[dev]" && pytest

# Python — server ingest
cd server/ingest && pip install -r requirements-dev.txt && pytest

# Python — skip Docker integration tests without Docker
pytest -k "not requires_docker"
```

## Test File Organization

**Swift — co-located `Tests/` sibling:**
```
Packages/WhoopProtocol/
  Sources/WhoopProtocol/       # production code
  Tests/WhoopProtocolTests/    # mirrored test target
    FramingTests.swift
    ParityTests.swift
    SchemaSyncTests.swift
```

**Swift — app tests in separate target directory:**
```
ios/
  OpenWhoop/                   # production app sources
  OpenWhoopTests/              # separate test target directory
    FrameRouterTests.swift
    CollectorTests.swift
    ServerSyncTests.swift
    UploaderTests.swift
    BackfillPolicyTests.swift
```

**Python:**
```
server/packages/whoop-protocol/
  whoop_protocol/              # package sources
  tests/
    fixtures/frames.py         # shared byte fixtures
    test_framing.py
    test_parity.py

server/ingest/
  app/                         # FastAPI app
  tests/
    conftest.py                # session-scoped DB fixtures
    test_hrv.py
    test_ingest_api.py         # Docker-gated integration tests
```

**Naming:** Each test file names the module under test: `FramingTests.swift` tests `Framing.swift`; `test_hrv.py` tests `analysis/hrv.py`.

## Test Structure

**Swift — XCTest suite:**
```swift
final class FrameRouterTests: XCTestCase {
    private let hr60 = "aa1800ff28020f3de10128663c00000000000000000001010d844e7c"

    private func makeStore() async throws -> WhoopStore {
        let store = try await WhoopStore(path: ":memory:")
        try await store.upsertDevice(id: "my-whoop", mac: nil, name: "test")
        return store
    }

    @MainActor func testRealtimeHRUpdatesHeartRate() {
        let state = LiveState()
        let router = FrameRouter(state: state)
        router.handle(frame: bytes(hr60))
        XCTAssertEqual(state.heartRate, 60)
    }
}
```

**Python — pytest class grouping:**
```python
class TestFilterRR:
    def test_all_plausible_pass_through(self):
        rr = [400, 800, 1000, 1500, 2000]
        assert _filter_rr(rr) == [400.0, 800.0, 1000.0, 1500.0, 2000.0]

    def test_boundary_values_included(self):
        assert _filter_rr([RR_MIN_MS, RR_MAX_MS]) == [float(RR_MIN_MS), float(RR_MAX_MS)]
```

## Mocking

**Swift — Protocol seam + hand-written spy:**
```swift
// Protocol defined in production code (Collector.swift)
protocol StoreWriting: AnyObject {
    func insert(_ streams: Streams, deviceId: String, markSynced: Bool) async throws -> (...)
    func enqueueRawBatch(_ meta: RawBatchMeta, frames: [[UInt8]]) async throws
}

// Spy in test file (CollectorTests.swift)
@MainActor
final class SpyStore: StoreWriting {
    private(set) var rawEnqueueCount = 0
    private let failRawEnqueue: Bool

    func enqueueRawBatch(_ meta: RawBatchMeta, frames: [[UInt8]]) async throws {
        rawEnqueueCount += 1
        if failRawEnqueue { throw RawEnqueueFailed() }
        try await wrapped.enqueueRawBatch(meta, frames: frames)
    }
}
```

**Swift — StubURLProtocol for HTTP:**
```swift
// Defined in ios/OpenWhoopTests/UploaderTests.swift
final class StubURLProtocol: URLProtocol {
    static var responses: [String: Int] = [:]        // path suffix → HTTP status
    static var bodies: [String: String] = [:]         // path suffix → response body
    static var bodiesByQuery: [String: String] = [:]  // full URL substring → body (paging)
    static var captured: [CapturedRequest] = []       // all captured requests, in order

    static func reset(responses: [String: Int] = [:],
                      bodies: [String: String] = [:],
                      bodiesByQuery: [String: String] = [:]) { ... }
}

// Injected via ephemeral URLSessionConfiguration:
let cfg = URLSessionConfiguration.ephemeral
cfg.protocolClasses = [StubURLProtocol.self]
let session = URLSession(configuration: cfg)
```

**What to Mock:**
- External HTTP (URLSession) — always via `StubURLProtocol`
- Store write operations — via `SpyStore` when testing ordering invariants (decoded-before-raw)
- Wall clock and monotonic time — injected `() -> TimeInterval` closures in `Collector`
- BLE (CBCentralManager) — NOT mocked; BLE-dependent tests are skipped or run on-device

**What NOT to Mock:**
- `WhoopStore` itself — use `:memory:` SQLite for all store tests
- The frame parser (`parseFrame`, `verifyFrame`) — always use real bytes from captures

## Fixtures and Factories

**Swift — hex string constants:**
```swift
private let hr60    = "aa1800ff28020f3de10128663c00000000000000000001010d844e7c"
private let hr72rr  = "aa1800ff28020f3de1012866480252038e0300000000010182605bf0"
private let batteryResp = "aa10005724231a0a01ff0000000000002f1ea284"
```

**Python — shared fixtures module:**
```python
# server/packages/whoop-protocol/tests/fixtures/frames.py
REALTIME_DATA_HR60 = bytes.fromhex("aa1800ff28020f3de10128663c00000000000000000001010d844e7c")
```

**Golden-file parity fixtures:**
- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/golden.json` — Python-generated expected parse results
- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json` — corresponding raw hex frames
- Generated by: `scripts/gen_golden.py`
- Tested by: `Packages/WhoopProtocol/Tests/WhoopProtocolTests/ParityTests.swift` (`testSwiftMatchesPythonGolden`)

**In-memory store factory:**
```swift
private func makeStore() async throws -> WhoopStore {
    let store = try await WhoopStore(path: ":memory:")
    try await store.upsertDevice(id: "my-whoop", mac: nil, name: "test")
    return store
}
// Also available as WhoopStore.inMemory() static factory (Packages/WhoopStore)
```

## Test Types

**Unit Tests (dominant):**
- Scope: single class or function in isolation
- Examples: `FramingTests.swift`, `BackfillPolicyTests.swift`, `ClockCorrelationTests.swift`, `test_hrv.py`, `test_framing.py`
- In-memory stores used for all store-touching unit tests

**Integration Tests (Swift — full pipeline):**
- Scope: `Collector` + `WhoopStore`, `ServerSync` + `WhoopStore` + `StubURLProtocol`
- Examples: `CollectorTests.swift`, `ServerSyncTests.swift`, `UploaderTests.swift`
- No external processes needed; `StubURLProtocol` replaces the network

**Integration Tests (Python — Docker-gated):**
- Scope: FastAPI endpoints + real TimescaleDB in a Docker container
- Marker: `@requires_docker` (auto-skips when Docker is unavailable)
- Located in: `server/ingest/tests/test_ingest_api.py`, `test_e2e.py`
- DB fixture: `server/ingest/tests/conftest.py` — session-scoped container, per-test `TRUNCATE`

**Parity Tests (cross-language contract):**
- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/ParityTests.swift` — Swift decode must match Python golden outputs exactly
- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/SchemaSyncTests.swift` — bundled schema file must match canonical `protocol/whoop_protocol.json`

**Schema Sync Test:**
```swift
func testBundledSchemaMatchesCanonical() throws {
    let canonical = repoRoot().appendingPathComponent("protocol/whoop_protocol.json")
    let bundled   = repoRoot().appendingPathComponent("Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol.json")
    XCTAssertEqual(try Data(contentsOf: bundled), try Data(contentsOf: canonical),
                   "run scripts/sync-schema.sh to re-copy")
}
```

**E2E / UI Tests:**
- Maestro flows: `ios/maestro/01_today_hrv_detail.yaml` through `06_device_settings.yaml`
- Run with the Maestro CLI against a physical device (cannot run in CI without a strap)

## Common Patterns

**Async Testing (Swift):**
```swift
func testFlushDrainsPartialBuffer() async throws {
    let store = try await makeStore()
    let c = Collector(store: store, deviceId: "my-whoop",
                      policy: .init(maxFrames: 100, maxInterval: 3600),
                      enableRawCapture: true)
    c.clockRef = ClockRef(device: 1_700_000_000, wall: 1_716_400_000)
    c.ingest(hex(hr60))
    await c.flush()
    let stats = try await store.storageStats()
    XCTAssertEqual(stats.rawBatches, 1)
}
```

**Deterministic Time Testing:**
```swift
var fakeTime: TimeInterval = 0
let c = Collector(store: store, deviceId: "my-whoop",
                  policy: .init(maxFrames: 100, maxInterval: 5),
                  monotonic: { fakeTime })
c.ingest(hex(hr60))  // buffered
fakeTime = 6          // advance past maxInterval
c.ingest(hex(hr60))  // triggers interval flush
await c.flush()
```

**Regression Test Labelling:**
```swift
// MARK: - REGRESSION: pre-clock buffered frames get the CORRECT ts once the clock lands
/// Audit 4.2 (clock-correlation edge case): ...
func testPreClockFramesFlushWithCorrectTsOnceClockLands() async throws { ... }
```

**Python pytest fixture injection:**
```python
@pytest.fixture
def client(clean_db, tmp_path, monkeypatch):
    monkeypatch.setenv("WHOOP_API_KEY", "secret")
    monkeypatch.setenv("WHOOP_DB_DSN", clean_db)
    import app.main as m
    import importlib
    importlib.reload(m)  # rebuild with patched env
    return TestClient(m.app, headers={"Authorization": "Bearer secret"})
```

## Coverage

**Requirements:** None enforced — no minimum coverage threshold configured.

**View Coverage:**
```bash
swift test --enable-code-coverage --package-path Packages/WhoopProtocol
# Xcode: Product → Test → show code coverage in Report navigator
```
