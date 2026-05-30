---
phase: 05-ios-app-server-port
plan: 03
subsystem: WhoopStore (iOS local persistence)
tags: [grdb, sqlite, migration, schema, gyroscope, ios]
requires:
  - "gravitySample table (v3 migration)"
  - "GravitySample struct extended in 05-01 (gx/gy/gz fields)"
provides:
  - "WhoopStore migration v8: nullable gx/gy/gz columns on gravitySample"
  - "schema ready for PROTO-14 (REALTIME_RAW_DATA type-43 gyro frames) without a future v9"
affects:
  - "Packages/WhoopStore (schema version bumped v7 → v8)"
tech-stack:
  added: []
  patterns:
    - "additive ADD COLUMN nullable migration (mirrors v6/v7 pattern)"
key-files:
  created: []
  modified:
    - "Packages/WhoopStore/Sources/WhoopStore/Database.swift"
decisions:
  - "D-06/IOS-09: gyro columns added to gravitySample (not a new table)"
  - "D-07: no device_generation column (fork is 5.0-only; redundant in app)"
  - "D-08: spo2Sample/skinTempSample left in raw ADC format (conversion happens server-side)"
  - "gx/gy/gz are nullable — null until a type-43 frame is captured (PROTO-14 HYPOTHESIS)"
metrics:
  duration: ~3m
  completed: 2026-05-30
---

# Phase 5 Plan 03: WhoopStore Migration v8 (Gyro Columns) Summary

Added GRDB migration v8 to WhoopStore that extends `gravitySample` with three nullable gyroscope columns (`gx`, `gy`, `gz` as `.double`), preparing the iOS schema to accept 5.0 gyro data without breaking inserts and without requiring a future v9 migration.

## What Was Built

- **Migration v8** registered in `makeMigrator()`, inserted between v7 and `return migrator`, preserving the v1..v8 ordering. It runs `try db.alter(table: "gravitySample")` and adds `gx`, `gy`, `gz` as nullable `.double` columns (no `.notNull()`), following the exact pattern established by v6/v7.
- Inline comments document that the columns stay null until a `REALTIME_RAW_DATA` type-43 frame (via `TOGGLE_IMU_MODE`) is captured (PROTO-14 HYPOTHESIS), and that spo2/skinTemp are intentionally untouched (D-08).

## Verification

- `swift build` → exit 0 (Build complete! in ~39s)
- `swift test` → 59 tests, 0 failures (migrations apply on a clean test DB)
- `grep -c 'registerMigration("v8")'` → 1
- `gx`/`gy`/`gz` present as `.double`, none with `.notNull()` (nullable confirmed)
- No `device_generation` reference (D-07 honored)
- v8 only touches `gravitySample`; `spo2Sample`/`skinTempSample` unchanged (D-08 honored)
- Migration order intact: v1, v2, v3, v4, v5, v6, v7, v8

## Decisions Made

- **D-06 / IOS-09**: Gyro fields added as columns on the existing `gravitySample` table rather than a new table — keeps the gravity/IMU data co-located and matches the extended `GravitySample` struct from 05-01.
- **D-07**: No `device_generation` column added — the fork targets 5.0 only, so the discriminator is redundant in the app.
- **D-08**: `spo2Sample(red, ir)` and `skinTempSample(raw)` left in raw ADC format; conversion to SpO2%/°C is the server's responsibility (`units.py`).
- Columns are nullable to allow rows to exist (null gyro) until PROTO-14 raw IMU frames are actually captured.

## Deviations from Plan

None - plan executed exactly as written.

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`. The migration is an additive ADD COLUMN nullable on a local SQLite DB inside the iOS App Sandbox; GRDB runs migrations transactionally (rollback on failure, no data corruption). Zero new packages introduced.

## Self-Check: PASSED

- FOUND: Packages/WhoopStore/Sources/WhoopStore/Database.swift (modified, contains `registerMigration("v8")`)
- FOUND: commit 38781ee (feat(05-03): add WhoopStore migration v8 with nullable gyro columns)
- FOUND: .planning/phases/05-ios-app-server-port/05-03-SUMMARY.md
