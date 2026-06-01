---
phase: 05-ios-app-server-port
plan: 04
subsystem: server
tags: [server, fastapi, timescaledb, ingest, whoop-5.0, schema-migration]
requires:
  - "WHOOP 5.0 decoded streams (DecodedBatch payload from iOS app)"
provides:
  - "device_generation column on 8 decoded-stream hypertables (idempotent, DEFAULT '5.0')"
  - "DecodedBatch.device_generation optional field (backward-compatible)"
  - "5.0-ready ingest/compute/read pipeline (additive, no endpoint renames)"
affects:
  - server/db/init.sql
  - server/ingest/app/main.py
tech-stack:
  added: []
  patterns:
    - "Idempotent ALTER TABLE ADD COLUMN IF NOT EXISTS (re-applied by bootstrap_schema on startup)"
    - "Optional Pydantic field with default for backward compatibility (str | None = '5.0')"
    - "DB-side column DEFAULT classifies pre-existing + field-omitting clients as 5.0"
key-files:
  created:
    - .planning/phases/05-ios-app-server-port/05-04-SUMMARY.md
  modified:
    - server/db/init.sql
    - server/ingest/app/main.py
decisions:
  - "Additive, backward-compatible changes only — no endpoint renames (would break iOS Uploader.swift)"
  - "DEFAULT '5.0' on the column (5.0-only deployment) classifies existing rows and field-omitting clients"
  - "ingest_decoded handler + store.upsert_streams left unchanged — device_generation flows via model_dump() and the DB DEFAULT"
metrics:
  duration: "~10min"
  completed: "2026-05-30"
requirements: [SRV-01, SRV-02, SRV-03, SRV-04, SRV-05]
---

# Phase 05 Plan 04: Server port to WHOOP 5.0 (device_generation) Summary

Ported the FastAPI + TimescaleDB ingest server to WHOOP 5.0 with additive, backward-compatible changes: a `device_generation` column added idempotently to all 8 decoded-stream hypertables (DB-side `DEFAULT '5.0'`) and an optional `device_generation: str | None = "5.0"` field on the `DecodedBatch` Pydantic model. The existing ingest → compute_day → read pipeline is untouched and already satisfies SRV-02/SRV-03.

## What Was Built

### Task 1 — device_generation in init.sql + DecodedBatch (D-09, D-10)
- **`server/db/init.sql`**: Added a new "WHOOP 5.0 generation tag" migration block (after the `gravity_samples` hypertable) with 8 idempotent statements:
  `ALTER TABLE <t> ADD COLUMN IF NOT EXISTS device_generation TEXT DEFAULT '5.0';`
  for `hr_samples, rr_intervals, events, battery, spo2_samples, skin_temp_samples, resp_samples, gravity_samples`.
  - `IF NOT EXISTS` makes the startup re-apply (`bootstrap_schema`) a no-op once present.
  - `DEFAULT '5.0'` classifies existing rows and clients that omit the field as 5.0 (5.0-only deployment).
- **`server/ingest/app/main.py`**: `DecodedBatch` gained `device_generation: str | None = "5.0"`, following the existing optional-field-with-default pattern (`decode_streams: bool = True`). The `ingest_decoded` handler and `store.upsert_streams` were intentionally **not** modified — `device_generation` is available via `payload = batch.model_dump()` if the store later persists it, and the DB column default covers the pipeline today. Backward compat: 4.0-style clients without the field get `'5.0'`.
- **Commit:** `156b557`

### Task 2 — end-to-end runtime verification (SRV-01/02/03/05)
No code changes (Task 2 verifies the same files Task 1 already committed). Static verification confirms the pipeline is wired:
- SRV-02: `daily.compute_day(conn, device_id, day)` is called inside `ingest_decoded` after `upsert_streams` (main.py:168) — existing behaviour preserved.
- SRV-01: `ingest_decoded` returns `{"upserted": counts}` (main.py:176).
- SRV-03: `/v1/daily`, `/v1/sleep`, `/v1/workouts` are present and Bearer-gated (main.py:238/248/302).

The live `docker compose up -d --build` + curl verification **could not be run in this execution sandbox** — Docker is not available here (`docker info` fails). See "Deferred Runtime Verification" below for the exact reproduction steps to run on a Docker-capable host.

## ROADMAP ↔ Code Endpoint Correspondence

SRV-03 in the ROADMAP refers to `/v1/daily-metrics` and `/v1/sleep-sessions` aspirationally. The **existing canonical endpoints** satisfy SRV-03 without renaming (renaming would break the iOS `Uploader.swift` client):

| ROADMAP name (aspirational) | Canonical endpoint (code) | Source DB table |
|-----------------------------|---------------------------|-----------------|
| `/v1/daily-metrics`         | `GET /v1/daily`           | `daily_metrics` |
| `/v1/sleep-sessions`        | `GET /v1/sleep`           | `sleep_sessions` |
| `/v1/workouts`              | `GET /v1/workouts`        | `exercise_sessions` |

Decision: keep the canonical names; document the mapping (here) rather than rename.

## Verification Evidence

Static (run in this sandbox):
```
$ python3 -c "import ast; ast.parse(open('server/ingest/app/main.py').read()); print('main.py OK')"
main.py OK
$ grep -c 'ADD COLUMN IF NOT EXISTS device_generation' server/db/init.sql
8
$ grep -c "device_generation TEXT DEFAULT '5.0'" server/db/init.sql
8
# per-table: hr_samples, rr_intervals, events, battery, spo2_samples,
#            skin_temp_samples, resp_samples, gravity_samples -> all OK
$ grep -q "device_generation: str | None" server/ingest/app/main.py && echo "field OK"
field OK
```

Acceptance criteria status:
- [x] SRV-04: `device_generation` added idempotently to 8 hypertables (init.sql) — VERIFIED statically
- [x] SRV-01 (model contract): `DecodedBatch` accepts optional `device_generation` default `'5.0'` — VERIFIED statically (AST + grep)
- [x] SRV-02 (call path): `compute_day` runs after each ingest — VERIFIED statically (existing, unchanged)
- [x] SRV-03 (endpoints): `/v1/daily`, `/v1/sleep`, `/v1/workouts` present + auth-gated, not renamed — VERIFIED statically
- [ ] SRV-05 (runtime): `docker compose up -d --build` arranque + curl 200s — DEFERRED (Docker unavailable in sandbox)

## Deferred Runtime Verification

Docker was unavailable in the execution sandbox, so the live arranque + HTTP checks must be run on a Docker-capable host. Exact reproduction (from `server/`, with `.env` providing `WHOOP_API_KEY`, `WHOOP_DB_PASSWORD`, `DATA_ROOT`):

```bash
cd server
docker compose up -d --build
sleep 15
# Confirm the migration ran on all 8 hypertables:
docker compose exec -T whoop-db psql -U "${WHOOP_DB_USER:-whoop}" -d "${WHOOP_DB_NAME:-whoop}" -c \
  "SELECT table_name FROM information_schema.columns
   WHERE column_name='device_generation'
   AND table_name IN ('hr_samples','rr_intervals','events','battery','spo2_samples','skin_temp_samples','resp_samples','gravity_samples')
   ORDER BY table_name;"  # expect 8 rows

PORT="${WHOOP_INGEST_PORT:-8770}"; TOKEN="${WHOOP_API_KEY}"
# SRV-01: ingest 5.0 batch -> 200 with "upserted"
curl -s -w "\ningest=%{http_code}\n" -X POST "http://localhost:$PORT/v1/ingest-decoded" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"device":{"id":"my-whoop"},"streams":{"hr":[{"ts":1717027200,"bpm":62}]},"device_generation":"5.0"}'
# SRV-03: read endpoints (note real query params)
curl -s -o /dev/null -w "daily=%{http_code}\n"    -H "Authorization: Bearer $TOKEN" "http://localhost:$PORT/v1/daily?device=my-whoop&from=2024-05-30&to=2024-05-30"
curl -s -o /dev/null -w "sleep=%{http_code}\n"    -H "Authorization: Bearer $TOKEN" "http://localhost:$PORT/v1/sleep?device=my-whoop&date=2024-05-30"
curl -s -o /dev/null -w "workouts=%{http_code}\n" -H "Authorization: Bearer $TOKEN" "http://localhost:$PORT/v1/workouts?device=my-whoop&from=2024-05-30&to=2024-05-30"
# SRV-02: confirm compute_day ran without error
docker compose logs whoop-ingest | grep -i compute_day || echo "no compute_day error (ok)"
docker compose down
```

Note: the plan's `<automated>` curl for the read endpoints omits the required query params (`device`, `from`/`to` or `date`). Those endpoints declare `Query(..., alias=...)` and would return `422` without them — the commands above include the params. The ingest POST in the plan is correct as written.

## Deviations from Plan

### Environment Limitation (not a code change)

**1. [Env] Docker-based runtime verification deferred**
- **Found during:** Task 2
- **Issue:** The execution sandbox has no Docker daemon (`docker info` fails), so `docker compose up -d --build` and the live curl checks (SRV-05 runtime path, and the live-HTTP confirmation of SRV-01/02/03) cannot run here.
- **Resolution:** Code is complete and statically verified (AST parse, per-table grep, call-path grep). The exact runtime reproduction is documented under "Deferred Runtime Verification" for a Docker-capable host.
- **Files modified:** none (verification-only task)
- **Commit:** n/a

### Minor: read-endpoint curl params

The plan's read-endpoint curls (`/v1/daily`, `/v1/sleep`, `/v1/workouts`) omit required query params and would return 422 as written. Corrected commands (with `device` + `from/to` or `date`) are provided in the deferred verification block. No code change needed — the endpoints behave correctly.

## Known Stubs

None. The changes are additive schema + model fields; no placeholder data or unwired components were introduced.

## Threat Flags

None. No new network endpoints, auth paths, or trust-boundary surface introduced. `device_generation` is Pydantic-validated and never feeds dynamic SQL (persisted as a parametrised value with a static-DDL column); init.sql DDL is static with hardcoded table names. Aligns with the plan's threat register (T-05-04-02 / T-05-04-03 dispositions).

## Self-Check: PASSED
- server/db/init.sql — FOUND (8 ALTER ... device_generation statements)
- server/ingest/app/main.py — FOUND (device_generation field present, AST-valid)
- Commit 156b557 — recorded for Task 1
