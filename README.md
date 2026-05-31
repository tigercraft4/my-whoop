# Wearable

Open-source, local-first client for **WHOOP 5.0** (and legacy WHOOP 4.0) bands: read **your
own** biometrics from **your own** device over Bluetooth LE and keep the data on hardware you
control. A native iOS app (collect → decode → store → sync) backed by an optional self-hosted
server. Decoding is schema-driven and shared by the phone and the server so they never drift.

| Hardware | Schema | Status |
|---|---|---|
| WHOOP 5.0 | `protocol/whoop_protocol_5.json` | ✅ Functional (v1.0) |
| WHOOP 4.0 | `protocol/whoop_protocol.json` | ✅ Stable |

> **Disclaimer.** This is an independent, unofficial project. It is **not affiliated with,
> endorsed by, or sponsored by WHOOP, Inc.** "WHOOP" is a trademark of its respective owner and
> is used here only descriptively, to identify the hardware this software interoperates with.
> The project is the result of independent reverse-engineering for interoperability and is
> provided **for personal and educational use** with **your own device and your own data**, at
> your own risk. No warranty of any kind.
>
> **Not a medical device.** Heart rate, HRV, recovery, strain, sleep, SpO₂, and related
> outputs are approximations from published methods, are **not** clinically validated, and are
> **not medical advice**. Do not use them for diagnosis or treatment.
>
> **No proprietary material.** This repository contains **only original, independently written
> code** and factual protocol notes. Protocol facts were established by observing Bluetooth
> traffic to and from a device the author owns and, where needed for interoperability, by
> examining the official app — an activity permitted under 17 U.S.C. §1201(f). **None** of that
> material is reproduced here: the repository does **not** contain, redistribute, or link to any
> WHOOP, Inc. software, firmware, app binaries, decompiled source, artwork, logos, or other
> copyrighted or trademarked assets. It does not circumvent any access control, DRM, or
> account/paywall, and requires the user's own physical device and their own data.
>
> **Purpose: interoperability & research.** The work exists to let an owner read **their own
> device's data** in an interoperable way and for security-research and educational purposes —
> protected interests under interoperability and good-faith research principles (e.g. 17 U.S.C.
> §1201(f) reverse-engineering for interoperability). It is not intended to compete with,
> substitute for, or harm WHOOP's products or services.
>
> See [`DISCLAIMER.md`](DISCLAIMER.md) for the full notice, including a good-faith takedown
> contact.

## What's here

| Path | What it is |
|---|---|
| `protocol/whoop_protocol_5.json` | **5.0 canonical decode schema** — Maverick wrapper, command/event enums, all decoded packet types |
| `protocol/whoop_protocol.json` | 4.0 canonical decode schema |
| `FINDINGS_5.md` | **5.0 protocol reference** — framing, GATT map, commands, events, biometric layouts, historical offload |
| `FINDINGS.md` | 4.0 protocol reference |
| `Packages/WhoopProtocol/` | Swift decoder — supports 5.0 (Maverick) and 4.0; cross-language parity-tested against Python |
| `Packages/WhoopStore/` | Local on-device store (GRDB); schema v8 supports 5.0 data types |
| `ios/` | SwiftUI + CoreBluetooth iOS app (targets WHOOP 5.0 via `FD4B0001-...` UUIDs) |
| `server/` | Optional self-hosted FastAPI + TimescaleDB server with 5.0 ingest support |
| `re/survey_5/` | **5.0 BLE discovery scripts** — GATT enumeration, bonding, live HR/battery |
| `re/` | 4.0 RE scripts and analysis harness |
| `re/capture/` | Capture runbooks: PacketLogger (iOS), btsnoop (Android), Wireshark, JADX |
| `scripts/` | `sync-schema-5.sh` / `sync-schema.sh` — sync canonical JSON to Swift bundle and Python package |
| `dashboard/` | Mac BLE reference/inspection tool used during development |
| `docs/` | Design specs and implementation plans (4.0 era) |

**Start here for WHOOP 5.0:** `FINDINGS_5.md` — the complete protocol reference.
**Start here for WHOOP 4.0:** `FINDINGS.md`.

## WHOOP 5.0 — Protocol Notes

The 5.0 BLE protocol differs significantly from 4.0:

- **Custom service UUID:** `FD4B0001-CCE1-4033-93CE-002D5875F58A` (not `61080001-...`)
- **Outer framing:** Maverick wrapper — `[0xAA][0x01][len u16 LE][role][token 3B][type][seq][payload]`
  - Writes (phone → WHOOP): 4.0 inner format `[0xAA][len u16][CRC8][type][seq][cmd][payload][CRC32]`
  - Reads (WHOOP → phone): Maverick format (outer wrapper, body-relative offsets, no inner CRC gate)
- **Command decode:** body offset +4 (not +0 as in 4.0); `strip_maverick()` required before parsing
- **GATT characteristics:** `FD4B0002` cmd-in, `FD4B0003` cmd-resp, `FD4B0004` events, `FD4B0005` data, `FD4B0007` diagnostics
- **Bonding:** confirmed-write trick on `FD4B0002` triggers iOS SMP pairing; macOS does not auto-bond
- **Handshake:** send `toggleRealtimeHR [0x01]` after subscribing to `FD4B0003/4/5` to activate the custom channel

See `FINDINGS_5.md` for full framing details, the complete command surface, and biometric decode offsets.

## Building & running

### iOS app (WHOOP 5.0)

```bash
# 1. Generate the Xcode project
cd ios && xcodegen generate

# 2. Copy and fill in server credentials (optional — app works fully offline)
cp ios/OpenWhoop/Config/Secrets.example.xcconfig ios/OpenWhoop/Config/Secrets.xcconfig
# Set SERVER_BASE_URL and WHOOP_API_KEY, or leave as placeholders for offline-only mode

# 3. Open in Xcode and run on a physical iPhone (CoreBluetooth requires real hardware)
open ios/OpenWhoop.xcworkspace
```

The app targets iOS 16+ and connects to WHOOP 5.0 via `FD4B0001-...` UUIDs. It works fully
offline — server upload is optional.

### Server

```bash
cd server
cp .env.example .env          # set WHOOP_API_KEY + WHOOP_DB_PASSWORD
export DATA_ROOT=/srv/whoop-data
docker compose up -d --build  # starts whoop-db (TimescaleDB) + whoop-ingest (FastAPI)
```

The server accepts WHOOP 5.0 decoded streams at `POST /v1/ingest-decoded` with a
`device_generation: "5.0"` field. See [`server/README.md`](server/README.md).

### RE scripts — WHOOP 5.0

```bash
# Create the venv
python3.11 -m venv re/survey_5/.venv
source re/survey_5/.venv/bin/activate
pip install -r re/survey_5/requirements.txt   # bleak==3.0.2

# Set your device identity (gitignored)
cp re/survey_5/device_local_5.example.py re/survey_5/device_local_5.py
# Edit DEVICE_UUID to your Mac's CoreBluetooth UUID for the strap

# Run scripts from re/survey_5/
cd re/survey_5
.venv/bin/python survey_gatt_5.py   # enumerate GATT
.venv/bin/python bond_5.py          # trigger bonding
.venv/bin/python hr_5.py            # live HR + battery
```

See [`re/survey_5/README.md`](re/survey_5/README.md) for full setup and script details.

### RE scripts — WHOOP 4.0

Clone the third-party dependencies (gitignored) per [`re/README.md`](re/README.md), then:

```bash
cp re/device_local.example.py re/device_local.py  # fill in your device identifiers
```

## Schema sync

After editing a protocol schema, sync it to the Swift bundle and Python package:

```bash
scripts/sync-schema-5.sh   # syncs whoop_protocol_5.json → Swift + Python (5.0)
scripts/sync-schema.sh     # syncs whoop_protocol.json → Swift + Python (4.0)
```

Run the Swift test suite after syncing: `SchemaSyncTests` asserts byte-identical copies.

## Credits & provenance

This work builds on prior community reverse-engineering of the WHOOP protocol. The framing,
command, and event identifiers were derived from independent reverse-engineering and from these
projects — thanks to their authors:

- [`bWanShiTong/openwhoop`](https://github.com/bWanShiTong/openwhoop) — Rust reference whose
  biometric decode layout and sleep/wake classifier informed the decoding here; the HRV and
  strain modules under `server/ingest/app/analysis/` were **ported** from its `openwhoop-algos`
  and adapted.
- [`jogolden/whoomp`](https://github.com/jogolden/whoomp) — community protocol reference
  (CRC, framing, packet types).
- [`bWanShiTong/reverse-engineering-whoop`](https://github.com/bWanShiTong/reverse-engineering-whoop)
  and [`christianmeurer/whoop-reader`](https://github.com/christianmeurer/whoop-reader) —
  earlier BLE exploration.

No third-party clones are included in this repository (they are gitignored). The committed code
is **entirely original work** plus factual protocol knowledge — observed from Bluetooth traffic
to and from the author's own device — documented in `FINDINGS.md` and `FINDINGS_5.md`. See
[`DISCLAIMER.md`](DISCLAIMER.md).
