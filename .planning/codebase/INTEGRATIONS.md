# External Integrations

**Analysis Date:** 2026-05-30

## Bluetooth LE (CoreBluetooth)

**Type:** Hardware peripheral (WHOOP 4.0 strap)
**Direction:** iOS app ↔ strap (bidirectional)
**Used in:** `ios/OpenWhoop/BLE/BLEManager.swift`

### Custom WHOOP Service
| Characteristic | UUID suffix | Direction | Purpose |
|---------------|-------------|-----------|---------|
| Command write | `...0002` | App → strap | Send commands (GET_CLOCK, SEND_HISTORICAL_DATA, etc.) |
| Command response | `...0003` | Strap → app (notify) | Command acknowledgements and responses |
| Event notifications | `...0004` | Strap → app (notify) | WRIST_ON/OFF, CHARGING, BATTERY_LEVEL, BLE_BONDED |
| Data notifications | `...0005` | Strap → app (notify) | Realtime HR/RR, historical offload chunks, raw sensor data |

### Standard BLE Services
| Service | UUID | Usage | Auth required |
|---------|------|-------|---------------|
| Heart Rate | `180D` | Real-time BPM + RR intervals (standard `0x2A37` format) | No (unbonded) |
| Battery | `180F` | Battery level percentage | No (unbonded) |
| Device Information | `180A` | Firmware version, hardware rev | No (unbonded) |

### Bonding
- Triggered by first confirmed write to command characteristic
- Just-works pairing (no PIN)
- Required before historical data offload and sensor data streams

---

## Self-Hosted FastAPI Server (optional)

**Type:** Self-hosted REST API
**Direction:** iOS app → server (upload); server → iOS app (pull derived metrics)
**Auth:** Bearer token (`WHOOP_API_KEY`) on write endpoints; unauthenticated reads
**Base URL:** Configured in `Secrets.xcconfig` (`SERVER_BASE_URL`)

### Write Endpoints (Bearer required)
| Endpoint | Method | Usage |
|----------|--------|-------|
| `/v1/ingest-decoded` | POST | Upload decoded streams (HR, RR, events, battery) from phone |
| `/v1/ingest` | POST | Upload raw BLE frames + clock reference |
| `/v1/compute-daily` | POST | Trigger daily metric recomputation for a device/day |
| `/v1/backfill-workouts` | POST | Recompute workout calories after profile change |

### Read Endpoints (unauthenticated)
| Endpoint | Method | Returns |
|----------|--------|---------|
| `/v1/streams/hr` | GET | 1 Hz heart rate samples (downsampled) |
| `/v1/streams/rr` | GET | R-R intervals |
| `/v1/streams/events` | GET | Named strap events |
| `/v1/streams/battery` | GET | Battery state-of-charge samples |
| `/v1/daily-metrics` | GET | Daily recovery/strain/HRV/RHR/sleep minutes |
| `/v1/sleep-sessions` | GET | Hypnogram + stage breakdown |
| `/v1/workouts` | GET | Detected workouts with HR zones + strain |
| `/v1/profile` | GET | Body profile (height/weight/age/sex) |
| `/v1/devices` | GET | Known device list |
| `/healthz` | GET | Health check |
| `/` | GET | Static dashboard SPA |

**iOS client:** `ios/OpenWhoop/Upload/Uploader.swift`, `ios/OpenWhoop/Upload/ServerSync.swift`
**Server implementation:** `server/ingest/app/main.py`, `server/ingest/app/read.py`

---

## TimescaleDB (PostgreSQL 16 + time-series extension)

**Type:** Relational database with time-series hypertables
**Direction:** FastAPI server ↔ TimescaleDB
**Used in:** `server/ingest/app/store.py`, `server/ingest/app/read.py`, `server/ingest/app/db.py`
**Schema:** `server/db/init.sql`
**Connection:** `psycopg` v3 (synchronous; one connection per request — no pool, see CONCERNS.md)

### Hypertables (time-partitioned, 1-day chunks)
| Table | Key columns | Purpose |
|-------|-------------|---------|
| `hr_samples` | `device_id, ts, bpm` | 1 Hz heart rate |
| `rr_intervals` | `device_id, ts, rr_ms` | R-R intervals for HRV |
| `events` | `device_id, ts, kind, payload` | Strap events |
| `battery` | `device_id, ts, soc, mv, charging` | Battery state |
| `spo2_samples` | `device_id, ts, red, ir` | Raw optical (ADC counts) |
| `skin_temp_samples` | `device_id, ts, raw` | Raw skin temperature |
| `resp_samples` | `device_id, ts, raw` | Raw respiration |
| `gravity_samples` | `device_id, ts, x, y, z` | 3-axis accelerometer |

### Regular Tables (derived, low-volume)
| Table | Purpose |
|-------|---------|
| `daily_metrics` | Computed recovery/strain/HRV/RHR per device/day |
| `sleep_sessions` | Sleep start/end, efficiency, stages (JSON) |
| `exercise_sessions` | Detected workouts with HR zones |
| `raw_batches` | Raw frame archive index (batch_id, device, file_path) |
| `profile` | Body profile per device (height/weight/age/sex) |

---

## Filesystem Archive (optional)

**Type:** Local filesystem (host or Docker volume)
**Direction:** FastAPI server → disk
**Used in:** `server/ingest/app/archive.py`
**Path pattern:** `${DATA_ROOT}/whoop/raw/<device_id>/<date>/<batch_id>.zst`
**Format:** zstd-compressed binary (level 10), content-addressed by SHA256
**Index:** `raw_batches` table in TimescaleDB (stores `file_path` + metadata)

---

## WHOOP Cloud API (optional, validation only)

**Type:** WHOOP official REST API (OAuth2)
**Direction:** Server → WHOOP cloud (read-only, for validation)
**Used in:** `server/ingest/app/whoop_api/`, `server/ingest/tests/` (pytest validation harness)
**Purpose:** Compare self-computed metrics against official WHOOP values; not used in production ingest path
**Auth:** OAuth2 (credentials in `.env`, not committed)

---

## URLSession (iOS networking)

**Type:** Apple networking framework
**Used in:** `ios/OpenWhoop/Upload/Uploader.swift`, `ios/OpenWhoop/Upload/ServerSync.swift`
**Config:** Ephemeral `URLSessionConfiguration` with `StubURLProtocol` injected in tests
**Auth:** `Authorization: Bearer <WHOOP_API_KEY>` header on write requests

---

## No External Dependencies for Core Features

The following are explicitly **not** integrated:
- **WHOOP cloud** — all data comes directly from the strap over BLE
- **Apple HealthKit** — health data stays local; no HealthKit sync
- **Push notifications (APNs)** — only local `UNUserNotificationCenter` for battery/recovery alerts
- **Analytics / crash reporting** — no Crashlytics, Sentry, or similar
- **Ad networks** — none
