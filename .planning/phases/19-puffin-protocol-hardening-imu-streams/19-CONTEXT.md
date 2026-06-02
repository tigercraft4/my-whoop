# Phase 19: Puffin Protocol Hardening + IMU Streams — Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Source:** Analysis of https://github.com/b-nnett/goose (fork: tigercraft4/goose)

---

## What is "Puffin"?

"Puffin" is an internal codename in the Goose project for a WHOOP 5.0 firmware variant that uses **alternate packet type numbers** for some commands. It is NOT a new device — it uses the same 8-byte Maverick framing (CRC16 MODBUS), same GATT UUIDs, same BLE connection flow.

The only difference: certain packet types use Puffin-specific numbers:
- Type **37** `PUFFIN_COMMAND` (vs 35 COMMAND)
- Type **38** `PUFFIN_COMMAND_RESPONSE` (vs 36 COMMAND_RESPONSE)
- Type **53** `RELATIVE_PUFFIN_EVENTS`
- Type **54** `PUFFIN_EVENTS_FROM_STRAP`
- Type **55** `RELATIVE_BATTERY_PACK_CONSOLE_LOGS`
- Type **56** `PUFFIN_METADATA` (vs 49 METADATA)

## Current risks for our codebase

### Risk 1 — Backfill gets stuck (HIGH)

`classifyHistoricalMeta()` checks `p.typeName == "METADATA"`, which only matches type 49.
If the strap sends type 56 for HISTORY_END or HISTORY_COMPLETE, the function returns `.other`
and the backfill chunk never closes — session hangs until the 300s idle timeout fires.

**Fix:** Add type 56 to `whoop_protocol_5.json` as "PUFFIN_METADATA" and update
`classifyHistoricalMeta()` to also accept `p.typeName == "PUFFIN_METADATA"`.

### Risk 2 — Command responses silently dropped (MEDIUM)

BLE command routing checks for type 36 (COMMAND_RESPONSE). If the firmware sends type 38
(PUFFIN_COMMAND_RESPONSE) for some commands, those responses are silently discarded and the
command appears to time out or produce no result.

**Fix:** Route type 38 identically to type 36 in the BLE command response handler.

## New feature: IMU Streams (types 51/52)

The Goose project documents two new stream types we don't currently decode:
- **Type 51** `REALTIME_IMU_DATA_STREAM` — real-time accelerometer + gyroscope
- **Type 52** `HISTORICAL_IMU_DATA_STREAM` — historical IMU data (backfill)

These carry raw 6-DOF motion data (accelerometer x/y/z + gyroscope x/y/z). Currently we
capture gravity from type 43 (REALTIME_RAW_DATA), but types 51/52 may carry higher-fidelity
or differently-structured IMU data.

**Work needed:** Capture live frames of types 51/52 with TOGGLE_IMU_MODE, decode the layout,
add `imuSample` table to WhoopStore, and update the Swift decoder.

## Key Goose source files to reference

- `Rust/core/src/protocol.rs` — complete packet type enum + frame parser
- `GooseSwift/GooseBLEClient+HistoricalHandlers.swift` — how Puffin types are handled in historical sync
- `GooseSwift/GooseBLEClient.swift` — `V5PacketType` enum (Swift side)
- `Rust/core/src/historical_sync.rs` — historical sync state machine

## What Goose ALSO hasn't solved (relevant for Phase 18)

From `docs/goose-swift-mvp/RemainingDataTodo.md`:
> "Resolve respiratory rate, SpO₂, and wrist temperature packet semantics from band data."

Goose has the same gap we do with SpO₂/skin_temp/resp offsets. Our Phase 18 Ghidra analysis
is leading-edge — whatever we find, Goose doesn't have it yet.

## Implementation decisions

### D-01: Schema approach for type 56
Add as a separate named entry "PUFFIN_METADATA" in `packets` with `type: 56`, sharing the
same field layout as METADATA (type 49). The classifier accepts both names.

### D-02: Scope of Puffin types to implement in this phase
- **In scope**: 38, 56 (defensive — directly affect backfill and command routing)
- **In scope**: 51, 52 (IMU streams — new data value)
- **Out of scope**: 37, 53, 54, 55 (Puffin command variants + battery pack events — low evidence these appear on WHOOP 5.0 normal operation)

### D-03: IMU stream table name
`imuSample` — consistent with `hrSample`, `spo2Sample`, `gravitySample` naming convention.
Fields: `deviceId`, `ts`, `ax`, `ay`, `az`, `gx`, `gy`, `gz`, `synced`.
