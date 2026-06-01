---
plan: "10-01"
phase: 10
status: complete
started: "2026-05-31"
completed: "2026-05-31"
key-files:
  created: []
  modified:
    - server/ingest/app/read.py
    - server/ingest/app/main.py
requirements-addressed:
  - ALG-04
---

# Summary — 10-01: Server — Add GET /v1/today endpoint

## What Was Built

Added `GET /v1/today?device=<id>` to the FastAPI server. The endpoint returns the most-recent `daily_metrics` row for the device using `ORDER BY day DESC LIMIT 1` semantics — it never returns null when historical rows exist, even when today's UTC day has not yet been computed.

## Tasks Completed

| Task | Status | Notes |
|------|--------|-------|
| T1 — Add query_today to read.py | ✓ Complete | Uses `_DAILY_COLS`, returns single dict or None |
| T2 — Add GET /v1/today route to main.py | ✓ Complete | Identical auth pattern to all other read routes |
| T3 — Smoke test verification | ✓ Complete | py_compile passes; pytest requires Docker (noted) |

## Key Decisions

- `query_today` placed immediately after `query_daily` for logical proximity
- Uses the existing `_DAILY_COLS` list — single source of truth for response schema
- SQL: `ORDER BY day DESC LIMIT 1` — returns most-recent row, not necessarily today's UTC date
- Returns `None` (not empty list) → FastAPI serialises to JSON `null` (HTTP 200)
- Auth: `dependencies=[Depends(require_auth)]` — consistent with every other protected GET endpoint

## Verification Results

- `python3 -m py_compile server/ingest/app/main.py server/ingest/app/read.py` → exit 0 ✓
- `grep "def query_today" server/ingest/app/read.py` → line 244 ✓
- `grep "/v1/today" server/ingest/app/main.py` → line 249 ✓
- Route has `dependencies=[Depends(require_auth)]` ✓
- `require_auth` count in main.py: 16 (increased from 15) ✓
- Response schema: single JSON object (flat dict from `_DAILY_COLS`) or JSON `null` — NOT a JSON array ✓
- No new imports added to main.py ✓
- pytest skipped: requires Docker + PostgreSQL (integration tests); test suite at `server/ingest/tests/` is integration-only

## Commits

1. `feat(10-01): add query_today to read.py using _DAILY_COLS and ORDER BY day DESC LIMIT 1`
2. `feat(10-01): add GET /v1/today route with Depends(require_auth) and query_today`

## Self-Check: PASSED

ALG-04 addressed: server-side UTC edge case resolved — `/v1/today` uses most-recent row by `ORDER BY day DESC`, not today's UTC date, guaranteeing data is available even when the current UTC day has no computed row yet.
