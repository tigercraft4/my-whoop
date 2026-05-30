# Architecture

**Analysis Date:** 2026-05-30

## Pattern

**Local-first, schema-driven BLE pipeline: collect → decode → store → sync**

The app reads biometric data directly from a WHOOP 4.0 over Bluetooth LE (no WHOOP cloud dependency), decodes frames using a canonical JSON schema shared between Swift and Python, persists decoded streams on-device, and optionally syncs to a self-hosted FastAPI/TimescaleDB backend for analytics.

## System Layers

### 1. UI Layer
- **Location:** `ios/OpenWhoop/Tabs/`, `Live/`, `Charts/`, `Alarm/`, `Alerts/`, `Settings/`
- **Pattern:** SwiftUI views observing two environment objects injected at app root
  - `@EnvironmentObject var metrics: MetricsRepository` — historical data (daily/sleep/workouts/trends)
  - `@EnvironmentObject var live: LiveViewModel` — real-time BLE state (HR, battery, log)
- **Key views:** `TodayView`, `SleepView`, `TrendsView`, `WorkoutsView`, `LiveView`

### 2. BLE Transport Layer
- **Location:** `ios/OpenWhoop/BLE/`
- **Key types:**
  - `BLEManager` — CoreBluetooth orchestrator (`@MainActor`); owns scan/connect/bond/subscribe/handshake/backfill timer
  - `FrameRouter` — pure decode router; updates `LiveState` from parsed frames
  - `LiveState` — ObservableObject BLE + biometric snapshot (HR, battery, events, log lines)
  - `Commands` — WHOOP command enum with raw value payloads
  - `BackfillPolicy` — decides when to trigger `SEND_HISTORICAL_DATA`
  - `StuckStrapDetector` — watchdog for frozen strap frontier

### 3. Collect Layer
- **Location:** `ios/OpenWhoop/Collect/`
- **Key types:**
  - `Collector` — cadence-flush buffer (64 frames or 30s); commits decoded streams before raw frames (decoded-first invariant)
  - `Backfiller` — HISTORY_END chunk state machine with safe-trim invariant (ack only after durable persist)
  - `ClockCorrelation` — maps device epoch → wall clock via `GET_CLOCK` response
  - `PrunePolicy` — controls raw batch retention
  - `RawCaptureWindow` — sliding window for raw frame capture

### 4. Metrics / Upload Layer
- **Location:** `ios/OpenWhoop/Metrics/`, `ios/OpenWhoop/Upload/`
- **Key types:**
  - `MetricsRepository` — lazy-open view facade over `WhoopStore`; `@Published` properties drive UI
  - `Uploader` — drains decoded rows from store and POSTs to `/v1/ingest-decoded`
  - `ServerSync` — incremental pull from server (`GET /v1/streams/{kind}`, derived metrics)

### 5. WhoopProtocol (Swift Package)
- **Location:** `Packages/WhoopProtocol/`
- **Pattern:** Schema-driven decoder; `loadSchema()` lazy-loads `whoop_protocol.json` once
- **Key functions:** `parseFrame()`, `verifyFrame()`, `extractStreams()`, `extractHistoricalStreams()`
- **No UIKit/SwiftUI/CoreBluetooth imports** — pure decode library

### 6. WhoopStore (Swift Package)
- **Location:** `Packages/WhoopStore/`
- **Pattern:** Swift `actor` over GRDB/SQLite; WAL mode + 5s busy timeout; 5 migration versions
- **Tables:** `hrSample`, `rrInterval`, `event`, `battery`, `spo2Sample`, `skinTempSample`, `respSample`, `gravitySample`, `rawBatch`, `cursors`, `dailyMetric`, `sleepSession`

### 7. Server — FastAPI Ingest (optional)
- **Location:** `server/ingest/app/main.py`
- **Routes:**
  - `POST /v1/ingest-decoded` — receives decoded streams from phone; triggers `compute_day()`
  - `POST /v1/ingest` — receives raw BLE frames
  - `GET /v1/streams/{kind}` — incremental read (HR, RR, events, battery)
  - `GET /v1/daily-metrics`, `GET /v1/sleep-sessions`, `GET /v1/workouts`
  - `GET /` — static dashboard SPA

### 8. Server — Analysis Pipeline
- **Location:** `server/ingest/app/analysis/`
- **Orchestrator:** `daily.compute_day(conn, device_id, day)` — runs after each ingest
- **Pipeline:** `sleep.py` + `sleep_features.py` (neurokit2 staging) → `hrv.py` (RMSSD) → `recovery.py` (Winsorized-EWMA baselines) → `strain.py` → `exercise.py`
- **Units:** `units.py` converts raw ADC counts to SpO₂%, °C, breaths/min

### 9. whoop-protocol (Python Package)
- **Location:** `server/packages/whoop-protocol/whoop_protocol/`
- **Pattern:** Python port of the Swift decoder; shares the same canonical `whoop_protocol.json`
- **Key functions:** `parse_frame()`, `extract_streams()`

## Critical Data Flows

### Live path (real-time)
```
BLE char-05 notification
  → BLEManager reassembly
  → FrameRouter.handle()        (updates LiveState immediately)
  → Collector.ingest()          (buffers frame)
  → [cadence: 64 frames or 30s]
  → Collector.flush()
      → extractStreams(clockRef:)
      → WhoopStore.insert()     (decoded, synced=0)
      → WhoopStore.enqueueRaw() (raw BLOB, after decoded)
  → Uploader.drain()            (every 30s)
      → POST /v1/ingest-decoded
      → mark rows synced=1
  → daily.compute_day()         (throttled 120s per device/day)
```

### Historical offload path (14-day strap store)
```
BackfillPolicy.shouldRun() → true
  → BLEManager sends SEND_HISTORICAL_DATA
  → strap streams HISTORY_START … chunks … HISTORY_END
  → Backfiller.ingest(chunk)
      → extractHistoricalStreams()
      → WhoopStore.insert(decoded)      # decoded-first
      → WhoopStore.enqueueRaw(raw)      # then raw
      → store.setCursor("strap_trim")   # safe-trim invariant
      → send ackTrim()                  # only after durable persist
```

### Server pull path (derived metrics)
```
MetricsRepository.refresh()
  → ServerSync.pullDerived()
      → GET /v1/daily-metrics (60-day window, incremental cursor)
      → GET /v1/sleep-sessions
      → GET /v1/workouts
  → WhoopStore upsert into MetricsCache
  → MetricsRepository.load()
  → @Published → SwiftUI re-render
```

## Architectural Constraints

- All BLE + UI operations on `@MainActor`; `WhoopStore` is a Swift `actor` (serial executor off main)
- Server is entirely optional — `AppConfig.uploaderConfig()` returns `nil` on placeholder values → full offline mode
- **Decoded-first invariant:** `Collector.flush()` snapshots buffer before first `await`; decoded streams committed before raw frames enqueued; pruning raw never loses decoded metrics
- **Safe-trim invariant:** `Backfiller.finishChunk()` early-returns on any persist failure; strap never acked without durable commit
- `BLEManager` cannot run in the iOS Simulator — requires physical device with CoreBluetooth
- `_cachedSchema` is a module-level singleton (loaded once, not thread-safe under Swift 6 strict concurrency — see CONCERNS.md)

## Entry Points

- **iOS App:** `ios/OpenWhoop/App/OpenWhoopApp.swift` — `@main`, creates `MetricsRepository` + `LiveViewModel`, injects into `RootTabView`
- **Server:** `server/ingest/app/main.py` — FastAPI `app` object; run via `uvicorn app.main:app`
- **Docker:** `server/docker-compose.yml` — orchestrates TimescaleDB + FastAPI containers
- **RE Harness:** `re/re_harness.py` — entry point for reverse-engineering experiments
- **Dashboard:** `dashboard/server.py` — Mac BLE inspection tool (WebSocket → browser)
