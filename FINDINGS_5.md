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
| **Bonding** (confirmed-write trick) | macOS does NOT auto-bond — confirmed-write trick is iOS-only; D-03b SMP-capture fallback required (see section 3) |
| Heart rate (standard `0x2A37`) | **Confirmed** — live BPM via Bleak, unbonded (HR=71/72 bpm, see section 4) |
| Battery (standard `0x2A19`) | **Confirmed** — read via Bleak, unbonded (23%, see section 4) |
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
| `FD4B0004-CCE1-4033-93CE-002D5875F58A` | events | notify | yes | `0x09a0` |
| `FD4B0005-CCE1-4033-93CE-002D5875F58A` | data | notify | yes | `0x09a3` |
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

**Status: confirmed-write trick is iOS-only — macOS CoreBluetooth does NOT auto-bond.** Run live 2026-05-30 with `re/survey_5/bond_5.py` from a fresh state (Forget Device on iPhone + removed the Mac-side bond entry + official WHOOP app force-quit, per D-03c and Pitfalls 1–3).

### Live outcome (`bond_5.py`, fresh state, 2026-05-30)

The ported 4.0 confirmed-write mechanism (`write_gatt_char(FD4B0002-..., b"\x00", response=True)` on cmd-in, per D-03) connected pre-bonding but did **not** trigger bonding on macOS:

| Step | Result |
|---|---|
| `client.pair()` | `NotImplementedError` — expected on macOS CoreBluetooth (RESEARCH anti-patterns) |
| `start_notify(cmd-resp FD4B0003-...)` | `BleakError: Encryption is insufficient` (CBATTErrorDomain Code=15) |
| `write_gatt_char(cmd-in FD4B0002-..., b"\x00", response=True)` | `BleakGATTProtocolError: Insufficient Authentication` |
| macOS pairing dialog | **Did not appear** |

**Finding (resolves RESEARCH assumption A6):** the confirmed-write "just-works" bonding trick works on **iOS** CoreBluetooth (where the OS presents a pairing dialog), but **macOS** CoreBluetooth does not expose SMP pairing programmatically and does not auto-bond when a Bleak-accessed peripheral returns authentication errors. The custom data channels (cmd-resp / events / data / diagnostics notifications) require an encrypted link, so they cannot be exercised from macOS Bleak until a bond exists.

### D-03b fallback (required for ROADMAP criterion 3 SMP evidence)

Because macOS Bleak cannot produce the bond, the SMP-visible evidence for ROADMAP criterion 3 must come from the **PacketLogger SMP capture of the official app's pairing handshake** — the documented D-03b path:
1. Forget Device on iPhone, then re-pair via the official WHOOP app while capturing with PacketLogger per `re/capture/ios-packetlogger.md`.
2. Extract the SMP handshake with `tshark -Y btsmp` per `re/capture/wireshark.md`.
3. Scrub BD_ADDR and any pairing-key bytes from the committed `.hex` (DISCLAIMER §2 + Pitfall 5) before adding it to `re/capture/evidence/`.

This fallback is left as a developer action; the Phase 2 evidence sidecar (`re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml`) records the macOS bond outcome above. Standard HR/battery (section 4) work **without** any bond, so Phase 3 framing work on the custom channels does depend on completing the D-03b iOS bond first.

---

## 4. Standard Characteristics

**Status: CONFIRMED — both work via Bleak WITHOUT bonding.** Run live 2026-05-30 with `re/survey_5/hr_5.py` (strap worn). This resolves RESEARCH assumptions A3/A4/A5 and satisfies ROADMAP criterion 4.

| Characteristic | UUID / Service | Access | Live result (2026-05-30) |
|---|---|---|---|
| Heart Rate Measurement | `0x2A37` / `0x180D` | `start_notify` (notify) | **12 notifications over 12 s → HR = 71 bpm (10×), 72 bpm (2×)** |
| Battery Level | `0x2A19` / `0x180F` | `read_gatt_char` (uint8 %) | **23%** |
| Manufacturer Name | `0x2A29` / `0x180A` | `read_gatt_char` | **`WHOOP Inc.`** |

- HR parsing used the validated `parse_hr()` (flags byte + uint8/uint16 HR + optional R-R intervals) ported verbatim from `re/standard_ble.py` (T-02-07 input-validation mitigation — guards `len(data)` before indexing).
- **No bond was needed** for any of the above: the standard GATT profiles are readable on the unencrypted link, matching the 4.0 precedent. This confirms ROADMAP criterion 4 (live BPM via Bleak subscription) end-to-end on the 5.0 strap.
- Off-wrist behaviour (HR reads 0 while charging) was not re-checked this run — open question 5, section 6.

---

## 5. Handle -> UUID Map

Closes the Phase 1 loop (D-02). Phase 1 (`re/capture/evidence/2026-05-30-ios.meta.yaml`) captured three ATT handles but **not** their UUIDs; the nRF Connect enumeration resolves them:

| Phase 1 handle | Characteristic UUID | Role | Phase 1 observation |
|---|---|---|---|
| `0x099b` | `FD4B0002-CCE1-4033-93CE-002D5875F58A` | cmd-in (write) | ATT Write Requests by WHOOP app |
| `0x099d` | `FD4B0003-CCE1-4033-93CE-002D5875F58A` | cmd-resp (notify) | ATT Handle Value Notifications |
| `0x09a3` | `FD4B0005-CCE1-4033-93CE-002D5875F58A` | data (notify) | ATT Handle Value Notifications — corrected from events by Wave 2 Bleak survey |

This confirms RESEARCH assumption A1 (the `FD4B0002/0003/0004` offsets map to cmd-in/cmd-resp/events, mirroring the 4.0 `61080002/0003/0004` layout). The Wave 2/3 Bleak scripts can now use confirmed UUID constants instead of placeholders.

---

## Phase 2 Success Criteria

The four ROADMAP Phase 2 success criteria, each mapped to its evidence in this document and the committed sidecar `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml`:

| # | ROADMAP criterion | Status | Evidence |
|---|---|---|---|
| 1 | GATT services + all 7 characteristics enumerated (cmd-in `…0002`, cmd-resp `…0003`, events `…0004`, data `…0005`, diagnostics `…0007`, standard HR + battery), UUIDs documented per device | **MET** | Section 1 (GATT Map) — visual nRF Connect + programmatic Bleak cross-check; sidecar `characteristic_uuids` map |
| 2 | Presence/absence of legacy `61080001-…` confirmed on this unit | **MET** | Section 2 (Legacy UUID Verdict = **ABSENT**); sidecar `legacy_61080001_verdict: absent` |
| 3 | Bleak bonds from a fresh state without the official app, confirmed-write trick or equivalent, SMP packets visible in PacketLogger | **PARTIAL — fell back to D-03b** | Section 3: confirmed-write trick is iOS-only; macOS does **not** auto-bond. SMP-visible evidence must come from the documented D-03b PacketLogger capture of the official-app pairing (developer action). The macOS bond outcome is recorded in the sidecar `bond_outcome`. |
| 4 | Standard HR characteristic streams live BPM via Bleak | **MET** | Section 4: `hr_5.py` live run — HR=71/72 bpm over 12 s, battery 23%, all **unbonded**; sidecar `hr_battery_confirmed` |

**Net:** Criteria 1, 2, and 4 are fully met. Criterion 3's intent (bonding replicated without the official app) is informed by a definitive negative result — the 4.0 confirmed-write trick does **not** auto-bond on macOS — and the SMP-visible evidence is deferred to the D-03b iOS PacketLogger capture, which the phase verifier should treat as the remaining developer action to fully close criterion 3.

---

## 6. Open Questions / Phase 3 Inputs

1. **Inner framing / CRC gate (Phase 3).** Phase 1 confirmed the `0xAA` SOF on all ATT payloads, suggesting the 4.0 inner framing (CRC8 poly 0x07 over length, CRC32-LE zlib over `[type][seq][cmd][payload]`) is reused. Phase 3 must validate the CRC gate against live 5.0 packets.
   - **High-confidence input:** the Hardware Revision reads `WG50_r52`, which matches whoop-vault **r52** — the same revision behind the 4.0 enum maps. Phase 3 can therefore use the **r52 enum maps with high confidence** for command/event codes, rather than re-deriving them.

2. **Bonding mechanism (Wave 3 / PROTO-02).** Whether the 4.0 confirmed-write trick triggers bonding on 5.0 (RESEARCH assumption A6) is unresolved until `bond_5.py` runs. The custom service being visible pre-bonding (section 1) means GATT enumeration does not depend on bonding, but the custom data channels (cmd-resp/events/data/diagnostics notifications) may still require an encrypted link before they deliver payloads.

3. **Full 128-bit UUID suffix.** The 5.0 custom family is `...-CCE1-4033-93CE-002D5875F58A` — a **different** 96-bit suffix from the 4.0 family (`...-8d6d-82b8-614a-1c8cb0f8dcc6`). Any hard-coded 4.0 UUID must not be reused for 5.0 code.

4. **`data` (...0005) and `diagnostics` (...0007) payloads.** Both characteristics are present with CCCDs but were not captured in Phase 1 (only the three handles above). Phase 4 will characterise the realtime/historical/raw streams on `...0005` and the memfault/diagnostics stream on `...0007`.

5. **Standard characteristic behaviour off-wrist.** On 4.0, HR reads 0 when off-wrist/charging while the subscription still succeeds. Confirm the same on 5.0 during the Wave 3 `hr_5.py` run.
