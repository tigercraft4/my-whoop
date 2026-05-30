# Directory Structure

**Analysis Date:** 2026-05-30

## Top-Level Layout

```
my-whoop/
├── protocol/                    # Canonical decode schema (single source of truth)
│   └── whoop_protocol.json      # Schema defining all WHOOP 4.0 frame layouts
├── Packages/                    # Swift local packages (SwiftPM)
│   ├── WhoopProtocol/           # Frame decoder (schema-driven)
│   └── WhoopStore/              # On-device SQLite persistence (GRDB)
├── ios/                         # iOS application (SwiftUI, iOS 16+)
│   ├── OpenWhoop/               # App source
│   ├── OpenWhoopTests/          # XCTest unit + integration tests
│   └── maestro/                 # Maestro E2E UI flows (YAML)
├── server/                      # Self-hosted backend (optional)
│   ├── ingest/                  # FastAPI + analytics
│   ├── packages/whoop-protocol/ # Python frame decoder package
│   ├── client/                  # CLI upload client
│   └── db/                      # TimescaleDB schema
├── dashboard/                   # Mac BLE inspection tool (dev only)
├── re/                          # Reverse-engineering scripts (Python)
├── docs/                        # Design specs + implementation plans
│   ├── specs/                   # Architecture design docs (~8 detailed specs)
│   └── plans/                   # Per-feature implementation plans
├── Plans/                       # GSD plan files
├── scripts/                     # Utility scripts (schema sync, fixture gen)
├── FINDINGS.md                  # Reverse-engineering protocol reference (219 lines)
├── DISCLAIMER.md
└── README.md
```

## Swift Packages

```
Packages/WhoopProtocol/
├── Sources/WhoopProtocol/
│   ├── Resources/whoop_protocol.json  # Bundled copy (sync via scripts/sync-schema.sh)
│   ├── Schema.swift                   # JSON schema types + loadSchema()
│   ├── Framing.swift                  # SOF/CRC reassembly, crc8/crc32
│   ├── Interpreter.swift              # Field extraction, parseFrame()
│   ├── Streams.swift                  # Decoded row types (HRSample, RRInterval, …)
│   ├── PostHooks.swift                # Post-decode transforms
│   ├── HistoricalStreams.swift
│   ├── HistoricalMeta.swift
│   └── Values.swift                   # ParsedValue enum
└── Tests/WhoopProtocolTests/
    ├── FramingTests.swift
    ├── ParityTests.swift              # Cross-language parity (Swift == Python golden)
    ├── SchemaSyncTests.swift          # Bundled schema == canonical schema
    └── Resources/
        ├── golden.json                # Python-generated expected parse results
        └── frames.json                # Corresponding raw hex frames

Packages/WhoopStore/
├── Sources/WhoopStore/
│   ├── WhoopStore.swift               # Actor, schema migrations, init(path:)
│   ├── Database.swift                 # Migration definitions (v1–v5)
│   ├── StreamStore.swift              # Decoded insert operations
│   ├── UnsyncedReads.swift            # Upload queue (synced=0 reads)
│   ├── Reads.swift                    # History/range reads
│   ├── MetricsCache.swift             # dailyMetric + sleepSession tables
│   ├── RawOutbox.swift                # Raw batch BLOB store
│   └── Cursors.swift                  # Read/trim highwater cursors
└── Tests/WhoopStoreTests/
```

## iOS App

```
ios/OpenWhoop/
├── App/
│   ├── OpenWhoopApp.swift             # @main, creates MetricsRepository + LiveViewModel
│   └── RootTabView.swift              # 5-tab TabView
├── BLE/
│   ├── BLEManager.swift               # CoreBluetooth orchestrator (scan/connect/bond)
│   ├── FrameRouter.swift              # Pure decode router → LiveState
│   ├── LiveState.swift                # ObservableObject BLE + biometric snapshot
│   ├── Commands.swift                 # WHOOP command enum
│   ├── StandardHeartRate.swift        # 0x180D HR profile (unbonded)
│   ├── StuckStrapDetector.swift
│   └── BackfillPolicy.swift
├── Collect/
│   ├── Collector.swift                # Cadence-flush buffer → WhoopStore
│   ├── Backfiller.swift               # Historical offload state machine
│   ├── ClockCorrelation.swift
│   ├── ClockPolicy.swift
│   ├── PrunePolicy.swift
│   ├── RawCaptureWindow.swift
│   └── StorePaths.swift
├── Metrics/
│   └── MetricsRepository.swift        # Lazy-open view facade over WhoopStore
├── Upload/
│   ├── Uploader.swift                 # Decoded drain → POST /v1/ingest-decoded
│   └── ServerSync.swift               # GET /v1/streams + derived metrics pull
├── Live/
│   ├── LiveView.swift                 # Device tab
│   └── LiveViewModel.swift            # Owns BLEManager + LiveState
├── Tabs/
│   ├── TodayView.swift
│   ├── SleepView.swift
│   ├── TrendsView.swift
│   ├── WorkoutsView.swift
│   ├── DayDetailView.swift
│   ├── HypnogramView.swift
│   ├── SevenNightChart.swift
│   ├── TrendChartCard.swift
│   └── WorkoutDetailView.swift
├── Charts/
│   ├── MetricChart.swift
│   ├── MetricDetailView.swift
│   ├── MetricKind.swift
│   └── HeartRateDetailView.swift
├── Design/
│   ├── DesignTokens.swift             # WH enum (Color, Spacing, Radius, Font)
│   ├── DesignGallery.swift            # Dev-only design gallery (TODO: #if DEBUG)
│   ├── ScreenHeader.swift
│   └── Components/
│       ├── MetricCard.swift
│       ├── RecoveryRing.swift
│       └── Sparkline.swift
├── Alarm/
│   ├── AlarmView.swift
│   └── SmartAlarmController.swift
├── Alerts/
│   ├── BatteryAlertMonitor.swift
│   ├── BatteryAlerts.swift
│   └── RecoveryNotifier.swift
├── Sync/
│   ├── SyncNudge.swift
│   └── StalenessPolicy.swift
├── Settings/
│   └── SettingsView.swift
└── Config/
    ├── AppConfig.swift                # UploaderConfig, deviceId, server URL/key
    └── Secrets.example.xcconfig      # Template (Secrets.xcconfig is gitignored)
```

## Server

```
server/
├── ingest/
│   ├── app/
│   │   ├── main.py                   # FastAPI app, all /v1/ routes
│   │   ├── store.py                  # TimescaleDB upsert ops (idempotent)
│   │   ├── read.py                   # Query API (streams, summary, derived)
│   │   ├── ingest.py                 # Raw batch processing
│   │   ├── db.py                     # Schema bootstrap (init.sql)
│   │   ├── config.py                 # load_config() from env vars
│   │   ├── archive.py
│   │   ├── analysis/
│   │   │   ├── daily.py              # Orchestrator: compute_day()
│   │   │   ├── sleep.py              # Sleep staging (neurokit2)
│   │   │   ├── sleep_features.py
│   │   │   ├── hrv.py                # RMSSD / nightly HRV
│   │   │   ├── recovery.py           # Recovery score (Winsorized-EWMA)
│   │   │   ├── strain.py             # Day strain
│   │   │   ├── exercise.py           # Workout detection
│   │   │   ├── calories.py
│   │   │   ├── baselines.py          # Winsorized-EWMA baseline machinery
│   │   │   ├── units.py              # ADC → SpO₂%, °C, breaths/min
│   │   │   ├── activity.py
│   │   │   └── _utils.py
│   │   ├── whoop_api/                # Optional WHOOP cloud API client
│   │   └── static/                   # Dashboard SPA (HTML + JS + CSS)
│   ├── tests/
│   │   ├── conftest.py               # Session-scoped Docker DB fixtures
│   │   ├── test_hrv.py
│   │   └── test_ingest_api.py        # Docker-gated integration tests
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   └── Dockerfile
├── packages/whoop-protocol/
│   └── whoop_protocol/
│       ├── __init__.py               # parse_frame, extract_streams, load_schema
│       ├── framing.py
│       ├── interpreter.py
│       ├── schema.py
│       └── whoop_protocol.json
├── client/                           # CLI upload client
├── db/
│   └── init.sql                      # TimescaleDB schema (hypertables)
├── docker-compose.yml
└── .env.example
```

## Key File Locations (Quick Reference)

| What | Path |
|------|------|
| App entry point | `ios/OpenWhoop/App/OpenWhoopApp.swift` |
| Canonical BLE schema | `protocol/whoop_protocol.json` |
| BLE engine | `ios/OpenWhoop/BLE/BLEManager.swift` |
| Frame decoder (Swift) | `Packages/WhoopProtocol/Sources/WhoopProtocol/Interpreter.swift` |
| On-device store | `Packages/WhoopStore/Sources/WhoopStore/WhoopStore.swift` |
| Server routes | `server/ingest/app/main.py` |
| Analytics orchestrator | `server/ingest/app/analysis/daily.py` |
| TimescaleDB schema | `server/db/init.sql` |
| Design tokens | `ios/OpenWhoop/Design/DesignTokens.swift` |
| App config / secrets | `ios/OpenWhoop/Config/AppConfig.swift` |
| Protocol findings | `FINDINGS.md` |

## Where to Add New Code

| Task | Location |
|------|----------|
| New iOS tab | `ios/OpenWhoop/Tabs/NewView.swift` — consume `@EnvironmentObject var metrics: MetricsRepository` |
| New BLE command | `ios/OpenWhoop/BLE/Commands.swift`; handler in `BLEManager.swift` |
| New decoded stream (sensor type) | `WhoopProtocol/Streams.swift` → `WhoopStore/StreamStore.swift` + `UnsyncedReads.swift` + `Reads.swift` → `Uploader.drainDecoded()` → `ServerSync.decodedKinds` → `server/store.py` → `server/read.py` → `init.sql` (new hypertable) |
| New analytics metric | `server/ingest/app/analysis/` → wire into `daily.compute_day()` → add to `init.sql` → update `MetricsCache.swift` → expose via `MetricsRepository` |
| New server endpoint | `server/ingest/app/main.py`; add query to `server/ingest/app/read.py` |
| New UI component | `ios/OpenWhoop/Design/Components/NewComponent.swift` — use only `WH.*` tokens |
| New RE script | `re/` — standalone Python using `whoop-protocol` package |

## Naming Conventions

**iOS Swift:**
- Files: `PascalCase.swift` matching the primary type name
- Types/protocols: `PascalCase`
- Functions/methods: `camelCase`
- Protocol seams for testability: `XxxWriting` / `XxxReading` suffix (e.g., `StoreWriting`)

**Python server:**
- Files: `snake_case.py`
- Functions: `snake_case`
- FastAPI route handlers named for their HTTP action: `ingest_decoded`, `get_stream`, `compute_daily`
- Analysis entry points follow: `compute_day(conn, device_id, day)` pattern
