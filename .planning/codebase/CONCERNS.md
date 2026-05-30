# Technical Concerns

**Analysis Date:** 2026-05-30

## Tech Debt

### High Priority

**`_cachedSchema` module-level mutable global (Swift 6 strict-concurrency violation)**
- Location: `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift:174`
- Issue: A module-level `var _cachedSchema` is accessed from `@MainActor` code without isolation annotation. This is a latent data race under Swift 6 strict concurrency.
- Fix: Change to a `nonisolated(unsafe) let` after first-load, or wrap in an actor.

**`makeDefault` dead factory in `MetricsRepository`**
- Issue: A `static func makeDefault()` factory exists but is unused in the call graph. Creates a path for accidental double-open.
- Fix: Remove or mark `@available(*, deprecated)`.

**`DesignGallery.swift` wired in "TEMPORARILY"**
- Location: `ios/OpenWhoop/Design/DesignGallery.swift`, referenced in `RootTabView`
- Issue: An in-progress design gallery is exposed as a tab. Dev-only UI leaking into production builds.
- Fix: Guard behind `#if DEBUG`.

**Sleep headline is a TODO placeholder**
- Location: `ios/OpenWhoop/Tabs/SleepView.swift:139`
- Issue: A headline metric is hardcoded/placeholder, not computed from real data.

**Server opens a new `psycopg.connect` per request (no connection pool)**
- Location: `server/ingest/app/main.py`
- Issue: Each FastAPI request opens and closes a raw connection. Under any load, this saturates available PG connections.
- Fix: Use `psycopg_pool.AsyncConnectionPool` or `psycopg.AsyncConnection` with dependency injection.

**Per-process `_last_recompute` dict breaks multi-worker single-flight guarantee**
- Location: `server/ingest/app/main.py:41`
- Issue: The 120s debounce for `compute_day` is an in-memory dict. Multiple uvicorn workers each maintain their own dict → the throttle does not work across processes. Under Gunicorn with workers>1, `compute_day` runs unconstrained.
- Fix: Move throttle state to Redis or a TimescaleDB lock row; or enforce `workers=1` in `docker-compose.yml`.

### Medium Priority

**`raw prune maxUnsyncedBytes` silently ignored**
- Location: `Packages/WhoopStore/Sources/WhoopStore/RawOutbox.swift:193`
- Issue: The `maxUnsyncedBytes` parameter is accepted but the branch that enforces it is commented out. Raw batches can grow unboundedly when raw capture is enabled.
- Fix: Implement and re-enable the prune branch.

**`StalenessPolicy` physically in `Sync/` but imported in `Collect/`**
- Issue: File placement mismatches module responsibility. Minor but causes confusion when grepping.

**`pullDerivedWindow` issues up to 60 sequential HTTP requests serially**
- Location: `ios/OpenWhoop/Upload/ServerSync.swift`
- Issue: For a 60-day lookback window, `pullDerived` issues one GET per day sequentially. Cold-start restore takes minutes.
- Fix: Batch endpoint (`GET /v1/daily-metrics?from=&to=` returning a date-keyed array).

## Known Bugs

**`pullStream` stalls permanently on an unparseable full page**
- Location: `ios/OpenWhoop/Upload/ServerSync.swift:170`
- Issue: If a complete 1000-row page arrives and all rows fail to decode, `pullStream` loops forever — cursor never advances, progress never made. The loop has no maximum-retries or skip-bad-page escape hatch.
- Severity: Data corruption recovery path → can permanently break incremental sync.
- Fix: Add a `failedAttempts >= 3` → advance cursor and log warning escape.

**`Backfiller.finishChunk` silently swallows store errors**
- Location: `ios/OpenWhoop/Collect/Backfiller.swift`
- Issue: When `WhoopStore.insert()` or `enqueueRawBatch()` throws, `finishChunk` returns early without logging the error. The strap retransmits indefinitely. The user sees no indication of the failure.
- Fix: Log the error to `LiveState.logLines`; surface in the Device tab.

**`bootstrapStore` failure leaves `collector = nil` silently**
- Location: `ios/OpenWhoop/App/OpenWhoopApp.swift`
- Issue: If `WhoopStore` init throws (e.g., disk full), `collector` remains `nil`. Subsequent BLE events silently no-op. No user-visible error or alert.
- Fix: Show an error sheet; retry on foreground.

## Security

**API key baked into `Info.plist` via xcconfig**
- Location: `ios/OpenWhoop/Config/Secrets.xcconfig` → `Info.plist`
- Risk: Low for personal use, but the key is extractable from an IPA binary string table. If the user ever distributes the app (TestFlight, etc.) the server key is exposed.
- Mitigation: For distribution, generate the key at first launch and store in Keychain.

**Dashboard `server.py` has zero authentication**
- Location: `dashboard/server.py`
- Risk: Anyone on the same network can read raw BLE frames and send commands to the strap. Acceptable for LAN-only dev tool; dangerous if exposed.
- Mitigation: Add a `--secret` flag and Bearer check if ever exposed beyond localhost.

**Server `GET /v1/*` read endpoints are unauthenticated**
- Location: `server/ingest/app/main.py` — only `POST /v1/ingest*` and `POST /v1/compute-daily` require Bearer.
- Risk: Health data readable by anyone who can reach the server port (LAN or forwarded).
- Mitigation: Acceptable for personal LAN deployment; document clearly; add auth if exposed to internet.

## Performance

**`compute_day` (neurokit2 sleep staging) runs synchronously in the ingest request handler**
- Location: `server/ingest/app/main.py` → `daily.compute_day()`
- Issue: Sleep staging via neurokit2 is CPU-bound and can take 10–30s for a full night. This blocks the uvicorn event loop during that window. All other requests queue behind it.
- Fix: Offload to `asyncio.get_event_loop().run_in_executor()` with a `ProcessPoolExecutor`, or push to a background task queue (Celery, ARQ).

**`upsert_streams` uses N individual `INSERT` calls per stream type**
- Location: `server/ingest/app/store.py`
- Issue: Each decoded stream row is inserted individually inside a loop. For a 14-day backfill (thousands of HR samples), this produces thousands of round-trips.
- Fix: Use `executemany` or `COPY` for batch upsert; `psycopg3` supports `executemany` with `UNNEST`.

**`loadSchema()` re-reads bundle resource on every call before caching**
- Location: `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift`
- Actual impact: Low (cached after first call), but the caching mechanism is a module-level mutable global (see Tech Debt).

## Fragile Areas

**`BLEManager` has 8 interacting boolean flags requiring precise reset on disconnect**
- Location: `ios/OpenWhoop/BLE/BLEManager.swift`
- Flags: `connectHandshakeDone`, `getClockSent`, `historicalDataRequested`, `strapFrontierKnown`, `backfillInProgress`, `waitingForHeartRateSubscription`, `waitingForBatterySubscription`, `standardHRSubscribed`
- Risk: A missed reset on the `didDisconnect` path leaves the next connection attempt in a wrong initial state. The guard conditions in the handshake sequence will be evaluated against stale values from the previous session. Currently, disconnect-then-reconnect is not tested.
- Priority: HIGH — write a `testDisconnectThenReconnect_resetsFlagState` test.

**`SmartAlarmController` BLE integration untested**
- Location: `ios/OpenWhoop/Alarm/SmartAlarmController.swift`
- Issue: The alarm set/clear command round-trip has no unit test (BLE cannot be mocked). Any regression in the command encoding or ack logic will not be caught before reaching hardware.

**`loadSchema()` calls `fatalError` on missing bundle resource**
- Location: `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift`
- Issue: If `whoop_protocol.json` is somehow absent from the bundle (misconfigured Xcode target membership), the app crashes at launch with an unrecoverable fatal error rather than a useful message.

**Backfiller `finishChunk` store-failure path untested**
- See "Known Bugs" above; also a coverage gap. A test should inject a `SpyStore` that throws on `enqueueRawBatch` and verify the chunk is not acked.

## Missing Features / Incomplete Areas

**SpO₂/skin-temp/respiration calibration constants are textbook defaults**
- Location: `server/ingest/app/analysis/units.py`
- Issue: The ADC→physical-unit conversions use generic constants (not calibrated to the WHOOP 4.0 optical hardware). Absolute SpO₂ and skin-temp values should be treated as approximate until validated against reference measurements.

**Smart-wake alarm not persisted across app force-quit**
- Location: `ios/OpenWhoop/Alarm/SmartAlarmController.swift`
- Issue: The strap stores the alarm time in firmware RTC (persistent), but the iOS app does not persist the last-set alarm time. If the app is force-quit and relaunched, the alarm UI shows no alarm even though the strap will still fire.
- Fix: Write alarm time to `UserDefaults` on set; restore on `BLEManager.didConnect`.

**No multi-device support**
- Location: `ios/OpenWhoop/Config/AppConfig.swift` — `deviceId` is a single string from xcconfig
- Issue: Architecture supports multiple devices in the store schema (all tables have `deviceId` column), but the UI and BLE layer only handle one device. A user with two straps cannot switch.

**RE scripts require a physical WHOOP 4.0 and `device_local.py`**
- Location: `re/` directory
- Issue: All 70+ RE scripts reference `device_local.py` (gitignored personal device identifiers). They are not runnable without a physical strap — this is expected, but the directory may confuse new contributors.
