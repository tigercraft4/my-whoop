# Tech Stack

**Analysis Date:** 2026-05-30

## Languages

| Language | Version | Usage |
|----------|---------|-------|
| Swift | 5.9 | iOS app + Swift packages (WhoopProtocol, WhoopStore) |
| Python | 3.11+ | FastAPI server, analysis pipeline, RE scripts |
| SQL | PostgreSQL 16 dialect | TimescaleDB schema + queries |
| JSON | — | Canonical BLE protocol schema |
| YAML | — | XcodeGen project config, Maestro E2E tests |

## iOS / Swift

### Runtime
- **iOS 16+** minimum deployment target
- **macOS 13+** for Swift package tests
- **Swift Tools Version:** 5.9
- **Concurrency model:** Swift structured concurrency (`async/await`, `actor`); `@MainActor` on all BLE/UI types

### Frameworks (Apple)
| Framework | Usage |
|-----------|-------|
| SwiftUI | All UI (5 tabs, charts, design system) |
| CoreBluetooth | BLE scanning, connecting, bonding, notifications |
| Charts | Native chart views (trends, HR detail) |
| CryptoKit | CRC32 / SHA256 utilities |
| Combine | `@Published` property wrappers in ObservableObjects |
| Foundation | Data, URLSession, DateFormatter, UserDefaults |
| XCTest | Unit + integration test runner |

### Third-Party Dependencies (SwiftPM)
| Package | Version | Usage |
|---------|---------|-------|
| `GRDB.swift` | 6.0.0+ | SQLite ORM for `WhoopStore` actor |

### Local Packages (SwiftPM)
| Package | Path | Purpose |
|---------|------|---------|
| `WhoopProtocol` | `Packages/WhoopProtocol/` | Schema-driven BLE frame decoder |
| `WhoopStore` | `Packages/WhoopStore/` | On-device SQLite persistence |

### Build System
- **XcodeGen** — `ios/project.yml` generates `OpenWhoop.xcodeproj`
- **SwiftPM** — manages both local packages and `GRDB.swift`
- **xcconfig** — `Secrets.xcconfig` injects server URL, API key, device ID at build time

## Server (Python)

### Runtime
- **Python 3.11+**
- **Deployment:** Docker + Docker Compose

### Frameworks & Libraries
| Package | Version | Usage |
|---------|---------|-------|
| `fastapi` | latest | REST API framework |
| `uvicorn` | latest | ASGI server |
| `psycopg` (v3) | latest | PostgreSQL async adapter |
| `pydantic` | v2 | Request/response validation |
| `neurokit2` | latest | Sleep staging (EEG-style pipeline on HR/RR) |
| `numpy` | latest | Numerical operations (HRV, strain, recovery) |
| `scipy` | latest | Signal processing utilities |
| `httpx` | latest | Test client for FastAPI integration tests |
| `pytest` | 8+ | Test runner |
| `zstd` | latest | Raw frame archive compression |

### whoop-protocol Python Package
- **Path:** `server/packages/whoop-protocol/`
- **Install:** `pip install -e ".[dev]"`
- **Purpose:** Python port of Swift decoder; shares canonical `whoop_protocol.json`

## Database

### On-Device (iOS)
- **SQLite** via GRDB actor
- **WAL mode** + 5s busy timeout
- **Location:** App sandbox (Documents or Application Support)
- **Migrations:** 5 versions defined in `Packages/WhoopStore/Sources/WhoopStore/Database.swift`

### Server
- **TimescaleDB** (PostgreSQL 16 + time-series extensions)
- **Schema:** `server/db/init.sql`
- **Hypertables** (time-partitioned): `hr_samples`, `rr_intervals`, `events`, `battery`, `spo2_samples`, `skin_temp_samples`, `resp_samples`, `gravity_samples`
- **Regular tables** (derived, low-volume): `daily_metrics`, `sleep_sessions`, `exercise_sessions`, `raw_batches`, `profile`
- **Partition interval:** 1 day on `ts` column

## Infrastructure

### Docker Compose Services
| Service | Image | Port |
|---------|-------|------|
| `db` | `timescale/timescaledb:latest-pg16` | 5432 |
| `ingest` | Custom `Dockerfile` (Python 3.11) | 8770 |

### Configuration
- **Server:** `.env` from `.env.example` — `WHOOP_API_KEY`, `WHOOP_DB_PASSWORD`, `WHOOP_DB_DSN`, `DATA_ROOT`, `PORT`
- **iOS app:** `Secrets.xcconfig` — `SERVER_BASE_URL`, `WHOOP_API_KEY`, `WHOOP_DEVICE_ID`
- **Raw archive:** `DATA_ROOT/whoop/raw/<device>/<date>/<batch>.zst` — content-addressed, zstd level 10

## Protocol / Schema

- **Canonical schema:** `protocol/whoop_protocol.json` (~12KB JSON)
- **BLE custom service UUID:** `61080001-8d6d-82b8-614a-1c8cb0f8dcc6`
- **Frame format:** `[0xAA][len u16 LE][crc8(len)][type u8][seq u8][cmd u8][payload...][crc32 LE]`
- **CRC8:** poly `0x07` (Dallas/Maxim)
- **CRC32:** zlib standard
- **Sync script:** `scripts/sync-schema.sh` — copies canonical schema to Swift bundle resource

## Testing Infrastructure

### iOS
- XCTest (unit + integration)
- `StubURLProtocol` (custom `URLProtocol` for HTTP interception — no external mock library)
- In-memory GRDB (`:memory:` path)
- Maestro CLI (E2E on physical device): `ios/maestro/*.yaml`
- Golden fixture files: `Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/`

### Python
- pytest 8+
- `httpx.TestClient` (FastAPI test client)
- Docker-managed TimescaleDB (session-scoped, per-test TRUNCATE) for integration tests
- `@requires_docker` marker to skip when Docker unavailable

## Development Tools

| Tool | Purpose |
|------|---------|
| XcodeGen | Generate `.xcodeproj` from `ios/project.yml` |
| Maestro CLI | E2E UI test runner |
| `scripts/sync-schema.sh` | Sync canonical schema to Swift bundle |
| `scripts/gen_golden.py` | Generate Python parity golden fixtures |
| `scripts/gen_synthetic_fixtures.py` | Generate synthetic test frames |
| `dashboard/server.py` | Mac BLE inspector (WebSocket → browser) |
| `re/re_harness.py` | RE experiment harness |
