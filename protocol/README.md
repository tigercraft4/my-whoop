# Protocol — canonical decode schemas

This directory contains the single source of decode truth for WHOOP BLE frames. **Edit only
these files to improve decode.** Never edit the copies in `Packages/` or `server/` directly —
use the sync scripts below.

## Schemas

### `whoop_protocol_5.json` — WHOOP 5.0 (current)

Canonical schema for WHOOP 5.0 frames: Maverick outer wrapper constants, GATT UUIDs
(`FD4B0001-...`), command/event/packet-type enum maps (from WG50_r52 firmware), and per-packet
field layouts (body-relative offsets, dtype, name, epoch tag, provenance, confidence level).

Every field is tagged with:
- `"epoch": "device" | "unix"` — timestamp model
- `"confidence": "VERIFIED" | "HYPOTHESIS"` — validation status
- `"provenance"` — the capture session and method that established the value

**Framing note:** WHOOP 5.0 uses an asymmetric format — writes (phone→WHOOP) use 4.0 inner
format; reads (WHOOP→phone) use the Maverick outer wrapper. See `FINDINGS_5.md` for full
framing details.

Consumers (must never drift from this file):
- `../Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json` — bundled
  into the Swift package; `SchemaSyncTests` asserts byte-identical copy.
- `../server/packages/whoop-protocol/whoop_protocol/schema/whoop_protocol_5.json` — Python
  package copy loaded by `load_schema_5()`; server parity tests assert consistency.

After editing: run `../scripts/sync-schema-5.sh`, then run both test suites.

### `whoop_protocol.json` — WHOOP 4.0 (stable)

Canonical schema for WHOOP 4.0 frames: packet-type / command / event enum tables, per-packet
field layout (offset, dtype, name, category), and type-43 IMU/optical variant offsets.

Consumers (must never drift):
- `../Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol.json` — bundled
  into the Swift package; `SchemaSyncTests` asserts byte-identical copy.
- The server `whoop-protocol` Python package — synced via `../scripts/sync-schema.sh`.

After editing: run `../scripts/sync-schema.sh`, then run both test suites.

## Sync scripts

```bash
# Sync 5.0 schema to Swift bundle + Python package
../scripts/sync-schema-5.sh

# Sync 4.0 schema to Swift bundle + Python package
../scripts/sync-schema.sh
```

Both scripts validate JSON before writing and exit non-zero if the schema is malformed.

## Test suites

After syncing, verify the copies are consistent:

```bash
# Swift (covers both 4.0 and 5.0)
cd .. && xcodebuild test -scheme WhoopProtocol   # or: swift test (inside Packages/WhoopProtocol)

# Python (5.0)
cd ../server && pytest packages/whoop-protocol/tests/
```

`SchemaSyncTests.swift` asserts that the committed copies in `Packages/` and `server/` are
byte-identical to the canonical files in `protocol/`. A discrepancy means you forgot to run the
sync script.
