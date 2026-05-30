# WHOOP 5.0 BLE Protocol — Reverse-Engineering Findings

_Last updated: 2026-05-30. Working dir: `~/Documents/my-whoop`. Target: the user's own WHOOP 5.0 (serial `[REDACTED]`, macOS BLE UUID `[REDACTED]`). Hardware revision `WG50_r52`._

## Goal

Read raw biometrics off your own WHOOP 5.0 **locally over BLE**, for interoperability with your own device data — the 5.0 counterpart of `FINDINGS.md` (4.0). This document is the primary committed artifact for Phases 2–4: Phase 2 bootstraps the confirmed GATT map, the legacy-UUID verdict, and the Phase 1 handle->UUID loop; Phases 3–4 extend it with framing/CRC confirmation and decoded streams. Independent reverse-engineering for interoperability; not affiliated with WHOOP, Inc.

> Do NOT copy the 4.0 UUIDs (`61080001-...`) into 5.0 code. The 5.0 custom service uses the `FD4B0001-...` family confirmed below.

## Status at a glance

| Capability | Status |
|---|---|
| GATT enumeration (visual, nRF Connect) | Done — full service + characteristic map captured 2026-05-30 |
| Custom service UUID confirmed (`FD4B0001-...`) | Confirmed on this unit |
| Legacy `61080001-...` service | **Absent** — not in discovered services (see section 2) |
| Handle -> UUID map (closes Phase 1 loop) | 0x099b / 0x099d / 0x09a3 resolved (see section 5) |
| Service visible **pre-bonding** | Custom service enumerable before bonding (Pitfall 4 does NOT apply) |
| **Bonding** (confirmed-write trick) | Pending Wave 3 — not yet attempted programmatically |
| Heart rate (standard `0x2A37`) | Pending Wave 3 — characteristic present, programmatic read pending |
| Battery (standard `0x2A19`) | Pending Wave 3 — characteristic present, programmatic read pending |
| Command/response protocol | Phase 3 (framing/CRC confirmation) |
| Decoded data streams (HR/RR, IMU, PPG, historical) | Phase 4 |

---

## 1. GATT Map

**Source:** nRF Connect visual enumeration of the physical WHOOP 5.0, 2026-05-30 (D-01). Official WHOOP app force-quit first per Pitfall 1. Custom service `FD4B0001-...` was **immediately visible after connecting, without bonding first** — so Pitfall 4 (custom service hidden until bonded) does **NOT** apply to this device, and Wave 3 may run `survey_gatt_5.py` and `bond_5.py` in either order.

### Services discovered

| Service | UUID | Notes |
|---|---|---|
| Heart Rate | `0x180D` | standard |
| Device Information | `0x180A` | standard |
| Battery Service | `0x180F` | standard |
| WHOOP 5.0 custom | `FD4B0001-CCE1-4033-93CE-002D5875F58A` | command/response + realtime + diagnostics |

### Custom service characteristics (all under `FD4B0001-CCE1-4033-93CE-002D5875F58A`)

| Characteristic UUID | Role | Properties | CCCD | Phase 1 handle |
|---|---|---|---|---|
| `FD4B0002-CCE1-4033-93CE-002D5875F58A` | cmd-in | write | no CCCD | `0x099b` |
| `FD4B0003-CCE1-4033-93CE-002D5875F58A` | cmd-resp | notify | yes | `0x099d` |
| `FD4B0004-CCE1-4033-93CE-002D5875F58A` | events | notify | yes | `0x09a3` |
| `FD4B0005-CCE1-4033-93CE-002D5875F58A` | data | notify | yes | — |
| `FD4B0007-CCE1-4033-93CE-002D5875F58A` | diagnostics / memfault | notify | yes | — |

All seven expected characteristics from the 4.0 analog are accounted for: cmd-in (...0002), cmd-resp (...0003), events (...0004), data (...0005), diagnostics (...0007), plus standard HR (`0x2A37`) and battery (`0x2A19`). No `...0006` characteristic was observed (same gap as 4.0).

### Standard service characteristics

| Service | Characteristic | UUID | Properties |
|---|---|---|---|
| Heart Rate | Heart Rate Measurement | `0x2A37` | notify |
| Battery | Battery Level | `0x2A19` | notify / read |
| Device Information | Manufacturer Name | `0x2A29` | read |
| Device Information | Model Number | `0x2A2A` | read |
| Device Information | Serial Number | `0x2A25` | read (value `[REDACTED]`) |
| Device Information | Firmware Revision | `0x2A26` | read |
| Device Information | Hardware Revision | `0x2A27` | read — value `WG50_r52` (hex `5747 3530 5F72 3532`) |

The Hardware Revision string `WG50_r52` matches the whoop-vault **r52** revision — the same revision used to build the 4.0 enum maps. See section 6 for the Phase 3 implication.

---

## 2. Legacy UUID Verdict

**Verdict: ABSENT.** The legacy `61080001-...` service was **not present** in the discovered services list during the nRF Connect enumeration (observation date **2026-05-30**, this specific WHOOP 5.0 unit). Only the `FD4B0001-CCE1-4033-93CE-002D5875F58A` custom service appears, alongside the three standard services.

Implication (D-01c, RESEARCH assumption A2 resolved): Phase 5 / downstream code does **not** need a dual-UUID-family compatibility branch for this device — the 5.0 uses the `FD4B0001-...` family exclusively. The 4.0 `61080001-...` constants remain valid only for the 4.0 strap (`FINDINGS.md`).

---

## 3. Bonding

**Status: pending Wave 3.** Bonding has not yet been attempted programmatically on the 5.0.

Plan (per D-03 / D-03c, ported from the 4.0 confirmed-write mechanism in `re/bond_attempt.py`):
1. Forget Device on iPhone -> close official WHOOP app -> remove the Mac-side bond entry if present (System Settings -> Bluetooth -> Option+click -> Remove).
2. Run `bond_5.py`: subscribe to cmd-resp (`FD4B0003-...`) and events (`FD4B0004-...`), then issue a **confirmed write** (`write_gatt_char(FD4B0002-..., b"\x00", response=True)`) on the cmd-in characteristic to trigger CoreBluetooth "just-works" bonding.
3. Fallback (D-03b) if the confirmed-write trick fails: PacketLogger SMP capture of the official app handshake per `re/capture/ios-packetlogger.md`, then `tshark -Y btsmp`.

Record the bond outcome (BLE_BONDED event on the events characteristic, or SMP capture result) here when Wave 3 completes.

---

## 4. Standard Characteristics

**Status: pending Wave 3** for programmatic read/subscribe.

Both standard characteristics are present in the GATT map (section 1):
- **Heart Rate Measurement** (`0x2A37`, service `0x180D`) — notify property confirmed. Expected to work unbonded (4.0 precedent, RESEARCH assumption A3). `hr_5.py` (Wave 3) will subscribe and record live BPM + R-R intervals using the validated `parse_hr()` from `re/standard_ble.py`.
- **Battery Level** (`0x2A19`, service `0x180F`) — notify/read confirmed. `hr_5.py` will `read_gatt_char` the single uint8 percentage.

Sample BPM and battery % to be filled in after the Wave 3 `hr_5.py` run.

---

## 5. Handle -> UUID Map

Closes the Phase 1 loop (D-02). Phase 1 (`re/capture/evidence/2026-05-30-ios.meta.yaml`) captured three ATT handles but **not** their UUIDs; the nRF Connect enumeration resolves them:

| Phase 1 handle | Characteristic UUID | Role | Phase 1 observation |
|---|---|---|---|
| `0x099b` | `FD4B0002-CCE1-4033-93CE-002D5875F58A` | cmd-in (write) | ATT Write Requests by WHOOP app |
| `0x099d` | `FD4B0003-CCE1-4033-93CE-002D5875F58A` | cmd-resp (notify) | ATT Handle Value Notifications |
| `0x09a3` | `FD4B0004-CCE1-4033-93CE-002D5875F58A` | events (notify) | ATT Handle Value Notifications |

This confirms RESEARCH assumption A1 (the `FD4B0002/0003/0004` offsets map to cmd-in/cmd-resp/events, mirroring the 4.0 `61080002/0003/0004` layout). The Wave 2/3 Bleak scripts can now use confirmed UUID constants instead of placeholders.

---

## 6. Open Questions / Phase 3 Inputs

1. **Inner framing / CRC gate (Phase 3).** Phase 1 confirmed the `0xAA` SOF on all ATT payloads, suggesting the 4.0 inner framing (CRC8 poly 0x07 over length, CRC32-LE zlib over `[type][seq][cmd][payload]`) is reused. Phase 3 must validate the CRC gate against live 5.0 packets.
   - **High-confidence input:** the Hardware Revision reads `WG50_r52`, which matches whoop-vault **r52** — the same revision behind the 4.0 enum maps. Phase 3 can therefore use the **r52 enum maps with high confidence** for command/event codes, rather than re-deriving them.

2. **Bonding mechanism (Wave 3 / PROTO-02).** Whether the 4.0 confirmed-write trick triggers bonding on 5.0 (RESEARCH assumption A6) is unresolved until `bond_5.py` runs. The custom service being visible pre-bonding (section 1) means GATT enumeration does not depend on bonding, but the custom data channels (cmd-resp/events/data/diagnostics notifications) may still require an encrypted link before they deliver payloads.

3. **Full 128-bit UUID suffix.** The 5.0 custom family is `...-CCE1-4033-93CE-002D5875F58A` — a **different** 96-bit suffix from the 4.0 family (`...-8d6d-82b8-614a-1c8cb0f8dcc6`). Any hard-coded 4.0 UUID must not be reused for 5.0 code.

4. **`data` (...0005) and `diagnostics` (...0007) payloads.** Both characteristics are present with CCCDs but were not captured in Phase 1 (only the three handles above). Phase 4 will characterise the realtime/historical/raw streams on `...0005` and the memfault/diagnostics stream on `...0007`.

5. **Standard characteristic behaviour off-wrist.** On 4.0, HR reads 0 when off-wrist/charging while the subscription still succeeds. Confirm the same on 5.0 during the Wave 3 `hr_5.py` run.
