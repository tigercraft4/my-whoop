---
phase: 05-ios-app-server-port
plan: 01
subsystem: protocol-decode
tags: [swift, python, ble, maverick, schema, decoder, crc, whoop5]

# Dependency graph
requires:
  - phase: 04-protocol-decode-schema
    provides: "canonical protocol/whoop_protocol_5.json (Maverick wrapper + body-absolute offsets), validate_frames_5.py strip_maverick() reference, FINDINGS_5.md framing layout"
provides:
  - "stripMaverick() — pure, bounds-guarded Maverick wrapper strip (Swift, byte-equivalent to validate_frames_5.py)"
  - "parseFrame() Maverick path — strips wrapper internally and decodes the flat body schema-driven, no public signature change"
  - "loadSchema()/schemaResourceURL() now target whoop_protocol_5.json (5.0 schema is the runtime default)"
  - "GravitySample.gx/gy/gz optional gyro fields (D-06), defaulted nil — call sites unchanged"
  - "Python whoop_protocol package: load_schema_5() + bundled whoop_protocol_5.json"
affects: [05-02 (5.0 parity + golden fixtures), iOS app decode path, server ingest 5.0]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Maverick strip-then-decode: detect [0xAA][0x01][len u16-LE][body][trailer 4B] before the 4.0 SOF check, strip header+trailer, decode the flat body with body-absolute schema offsets"
    - "No inner CRC on the Maverick body (T-05-02 accepted): parseBody() never calls verifyFrame(); crcOK is nil on that path"
    - "Dual schema loaders coexist (load_schema 4.0 / load_schema_5 5.0) so the 4.0 package stays usable"

key-files:
  created:
    - Packages/WhoopProtocol/Tests/WhoopProtocolTests/MaverickTests.swift
    - server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json
  modified:
    - Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift
    - Packages/WhoopProtocol/Sources/WhoopProtocol/Interpreter.swift
    - Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift
    - Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift
    - Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift
    - Packages/WhoopProtocol/Package.swift
    - Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json
    - server/packages/whoop-protocol/whoop_protocol/schema.py

key-decisions:
  - "Maverick body is decoded by a dedicated parseBody() helper rather than reusing parseFrame's 4.0 envelope handling — the body has no SOF/length/crc8 prefix and no crc32 trailer, so reusing the 4.0 trailer/CRC logic would mis-read offsets"
  - "crcOK is nil (not false) on the Maverick path — the flat body carries no inner CRC32 to verify (T-05-02 accepted); false would wrongly imply a failed check"
  - "Package.swift was extended to declare Resources/whoop_protocol_5.json (Rule 3) — without it Bundle.module cannot resolve the 5.0 schema and loadSchema() would fatalError at runtime"
  - "The stale Swift Resources/whoop_protocol_5.json was re-synced from canonical via scripts/sync-schema-5.sh (Rule 3) — it had drifted (missing offset_base: body-absolute), which the body-absolute decode path depends on"

patterns-established:
  - "Wrapper detection guard: frame.count >= 9 && frame[0]==0xAA && frame[1]==0x01 && frame.count == (u16-LE@2)+8"
  - "Optional biometric fields with nil defaults (GravitySample gyro) follow BatterySample's soc: Double? pattern so synthesized Codable + existing call sites keep working"

requirements-completed: [SWIFT-01, SWIFT-02, SWIFT-03, SWIFT-04, SWIFT-06]

# Metrics
duration: ~9min
completed: 2026-05-30
---

# Phase 5 Plan 01: WHOOP 5.0 Decoder Core Port Summary

**Swift decoder + Python mirror ported to WHOOP 5.0: parseFrame() strips the Maverick outer wrapper internally and decodes the flat body against the 5.0 schema (body-absolute offsets, no inner CRC), with GravitySample gaining optional gyro axes and the Python package gaining load_schema_5().**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-05-30T22:13Z (approx)
- **Completed:** 2026-05-30T22:22Z
- **Tasks:** 3/3
- **Files modified:** 8 (+2 created)

## Accomplishments
- `stripMaverick()` is a pure, bounds-guarded function byte-equivalent to `strip_maverick()` in `validate_frames_5.py`; `parseFrame()` transparently strips Maverick-wrapped frames and decodes the flat body with NO public signature change and NO inner CRC re-check.
- `loadSchema()` and `schemaResourceURL()` now load `whoop_protocol_5.json` as the runtime default; the resource is declared in `Package.swift` and re-synced from canonical so `Bundle.module` resolves it.
- `GravitySample` gained optional `gx/gy/gz` gyro fields (D-06 / PROTO-14 HYPOTHESIS) with nil defaults — existing call sites compile unchanged.
- The Python `whoop_protocol` package ships `whoop_protocol_5.json` (byte-identical to canonical) and a cached `load_schema_5()` loader, with the 4.0 `load_schema()` left intact.

## Task Commits

1. **Task 1 (RED): failing test for stripMaverick + parseFrame Maverick path** - `cfc3093` (test)
2. **Task 1 (GREEN): stripMaverick + parseFrame Maverick path (D-02)** - `26a870a` (feat)
3. **Task 2: loadSchema() -> whoop_protocol_5 + GravitySample gyro (D-01, D-06)** - `0e4e5b8` (feat)
4. **Deferred-items log (4.0 parity failures owned by 05-02)** - `06fd43b` (chore)
5. **Task 3: Python whoop_protocol package supports schema 5.0 (SWIFT-06)** - `ea8755d` (feat)

_TDD task 1 produced test -> feat commits (no refactor needed)._

## Files Created/Modified
- `Packages/WhoopProtocol/Tests/WhoopProtocolTests/MaverickTests.swift` (created) - 8 synthetic-frame tests for stripMaverick guards + body offset + parseFrame Maverick/non-Maverick paths.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` - added pure `stripMaverick(_:) -> [UInt8]?` after `verifyFrame()`.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Interpreter.swift` - Maverick detection before the 4.0 SOF check; new private `parseBody()` decodes the flat body schema-driven without the CRC gate.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` - `loadSchema()` resource + 3 error messages -> `whoop_protocol_5.json`.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` - `schemaResourceURL()` -> `whoop_protocol_5`.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Streams.swift` - `GravitySample` optional `gx/gy/gz` with defaults.
- `Packages/WhoopProtocol/Package.swift` - declare `Resources/whoop_protocol_5.json` as a processed resource.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json` - re-synced from canonical (was stale).
- `server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json` (created) - byte-identical canonical copy.
- `server/packages/whoop-protocol/whoop_protocol/schema.py` - `_SCHEMA_PATH_5` + cached `load_schema_5()`.

## Verification

- `cd Packages/WhoopProtocol && swift build` -> exit 0.
- `MaverickTests`: 8/8 pass (stripMaverick guards: count<9, wrong SOF, wrong version byte, length+8 invariant; body slice at offset 4; parseFrame Maverick reads seq from body[5]; non-wrapped frame uses the existing path).
- `grep -c 'func stripMaverick' Framing.swift` = 1; `grep 'stripMaverick' Interpreter.swift` present; no `verifyFrame()` call inside `parseBody`.
- `grep -c whoop_protocol_5 Schema.swift` = 4; no `forResource: "whoop_protocol"` (4.0) left; `whoop_protocol_5` in WhoopProtocol.swift; `gx/gy/gz` present with `= nil` defaults.
- Python plan verify: `json.load(...whoop_protocol_5.json)` -> "keys 9"; `diff` vs canonical = identical; `load_schema_5()` returns a Schema (7 packets), `load_schema()` (4.0) intact and distinct, lru_cache preserved (verified under python3.11 — the package requires 3.10+).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] whoop_protocol_5.json not declared in Package.swift**
- **Found during:** Task 2
- **Issue:** `loadSchema()` was switched to `Bundle.module.url(forResource: "whoop_protocol_5")`, but `Package.swift` only processed `whoop_protocol.json`. The 5.0 resource would be absent from the bundle, causing a runtime `fatalError`.
- **Fix:** Added `.process("Resources/whoop_protocol_5.json")` to the WhoopProtocol target (both 4.0 and 5.0 now bundled).
- **Files modified:** Packages/WhoopProtocol/Package.swift
- **Commit:** 0e4e5b8

**2. [Rule 3 - Blocking] Stale Swift Resources/whoop_protocol_5.json**
- **Found during:** Task 2 (read_first asked to confirm the resource present in the target)
- **Issue:** The committed `Sources/.../Resources/whoop_protocol_5.json` had drifted from canonical `protocol/whoop_protocol_5.json` — it was missing `offset_base: "body-absolute"` and carried an outdated type-43 note. The Maverick body-absolute decode path depends on the canonical content, and `SchemaSyncTests` enforces bundled == canonical.
- **Fix:** Re-synced via `scripts/sync-schema-5.sh` (the canonical sync pipeline). `diff` now identical.
- **Files modified:** Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json
- **Commit:** 0e4e5b8

## Deferred Issues

The plan's `<verification>` is `swift build` only, and SWIFT-03/04 explicitly state "paridade validada em 05-02". Switching the runtime schema from 4.0 to 5.0 (D-01) knowingly invalidates the pre-existing **4.0** parity/golden test suite (`HistoricalStreamsParityTests`, `HistoricalV24Tests`, and the other 4.0-fixture-bound tests, plus `SchemaSyncTests.testBundleModuleSchemaAlsoMatchesCanonical` which still points at the 4.0 canonical). These are NOT regressions in this plan's code — `swift build` passes and the new Maverick path is independently green in `MaverickTests`. Fixing them requires 5.0 golden fixtures from real captures, which is the explicit scope of **plan 05-02**. Logged in `.planning/phases/05-ios-app-server-port/deferred-items.md` (commit 06fd43b). No 5.0 offsets/fixtures were fabricated.

Note: the system default `python3` is 3.9.6, which cannot import the package's `framing.py` (`int | None` PEP-604 syntax requires 3.10+). This is a pre-existing environment constraint, not introduced here; `load_schema_5()` was verified functional under `python3.11`.

## Known Stubs

`GravitySample.gx/gy/gz` default to `nil` until a real type-43 REALTIME_RAW_DATA frame is captured (raw IMU was absent from the Phase 4 D-05 capture — PROTO-14 HYPOTHESIS). This is an intentional, documented stub: the gyro axes are wired into the data shape now so downstream storage/UI are forward-compatible, and they are populated when a TOGGLE_IMU_MODE/START_RAW_DATA capture lands (Phase 5 follow-up). No fabricated values.

## Threat Surface

No new trust-boundary surface beyond the plan's `<threat_model>`. T-05-01 (DoS via malformed wrapper) is mitigated: `stripMaverick()` and the Maverick branch in `parseFrame()` guard every index read (`frame.count >= 9`, `frame.count == length + 8`, `body.count >= 6`) and return nil/INVALID rather than reading out of range. T-05-02 (no inner CRC on the stripped body) is accepted by design — `parseBody()` never re-runs the CRC gate. No new packages installed (T-05-SC).

## Self-Check: PASSED

All claimed files exist on disk (MaverickTests.swift, Python whoop_protocol_5.json, Framing.swift, Interpreter.swift, schema.py, 05-01-SUMMARY.md) and all five task commits (cfc3093, 26a870a, 0e4e5b8, 06fd43b, ea8755d) are present in git history.
