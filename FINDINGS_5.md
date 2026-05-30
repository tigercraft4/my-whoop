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
| Command/response protocol (framing) | **Maverick wrapper characterised** — 4.0 inner CRC gate fails 0% on 5028 frames; outer wrapper `[AA][01][len][role]...[trailer]` confirmed, `strip_maverick()` working (see section 7) |
| Trailer checksum algorithm | **OPEN** (HYPOTHESIS) — standard CRC16/CRC32 variants ruled out; non-blocking (see section 7) |
| Decoded data streams (HR/RR, IMU, PPG, historical) | Phase 4 — **cleared to start** (go/no-go verdict in section 7) |

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

---

## 7. Framing (Phase 3)

**Source:** tshark extraction of the two local captures (Phase 1 iOS ATT session + Phase 2 SMP-bond session) validated by `re/survey_5/validate_frames_5.py`, run 2026-05-30. Empirical results recorded in the redacted evidence sidecar `re/capture/evidence/2026-05-30-framing-5.meta.yaml`. Numbers below are the actual validator output over **5028 captured `0xAA`-SOF frames** across the two sessions.

### 4.0 inner-framing CRC gate — DOCUMENTED NEGATIVE (PROTO-04)

The central Phase 3 hypothesis — that 5.0 reuses the 4.0 inner framing (`[0xAA][len u16 LE][crc8 poly 0x07][type][seq][cmd][payload][crc32 LE]`) — is **empirically false.** Running the exact 4.0 CRC8+CRC32 validator (ported, not imported, from `re/decode.py` + `Framing.swift`) against all 5028 frames yields a **0% CRC pass rate** (0 / 10056 CRC8+CRC32 checks). Read with the 4.0 layout, the "length field" `frame[1:3]` decodes to nonsense (`0x0801 = 2049` for a 16-byte frame) because byte[1] is a version byte, not part of the length. PROTO-04 is therefore a **documented negative**: the 4.0 inner framing is **NOT reused verbatim** on 5.0. This is the result the critical gate was built to produce, and it triggers the PROTO-05 wrapper-characterisation path (D-03).

### Maverick outer wrapper — CHARACTERISED (PROTO-05)

Every ATT value across both sessions follows a flat outer wrapper, verified 100% consistent on 5028/5028 frames:

```
offset 0     SOF      0xAA           (constant)
offset 1     version  0x01           (constant)
offset 2-3   length   u16 LE         (body length)
offset 4     role     0x00 = cmd-in write, 0x01 = notify   (== body[0])
offset 5..   body     flat payload   (length bytes, incl. role at body[0])
last 4       trailer  per-frame checksum (algorithm OPEN)
```

The 8-byte overhead invariant `total_len == length + 8` (4-byte header + body + 4-byte trailer) holds for **5028/5028 frames** across both sessions, yielding `Maverick wrapper: CONFIRMED`. Per-characteristic frame counts: cmd-in `FD4B0002` 155, cmd-resp `FD4B0003` 158, events `FD4B0004` 1, data `FD4B0005` 4714.

**The body is FLAT** — it is NOT a nested 4.0 `0xAA` frame (corrects the CONTEXT D-03 mental model; only incidental `0xAA` bytes appear mid-body, none at a frame boundary). `strip_maverick()` returns the flat body `frame[4:4+length]` directly; the stripped body is opaque decode input for Phase 4 and must **not** be re-run through the 4.0 CRC gate.

### Trailer checksum — OPEN / HYPOTHESIS (non-blocking)

The 4-byte trailer is a per-frame checksum whose algorithm is **OPEN**. An exhaustive negative was recorded: CRC32 variants (zlib, BZIP2, MPEG2, POSIX, JAMCRC, CRC32C — LE and BE, all leading offsets) and CRC16 variants (CCITT-FALSE, XMODEM, MODBUS, IBM/ARC — over every plausible region) all fail to match consistently. The trailer is non-standard or computed over a transformed/masked input (e.g. the session-token bytes). This is the one genuine open RE problem, recorded as `HYPOTHESIS`/`OPEN` in `protocol/whoop_protocol_5.json`. **It does NOT block phase closure:** the wrapper is characterised and `strip_maverick()` does not need the trailer algorithm — Phase 4 decodes the flat body without trailer validation.

### Committed artifacts

- `protocol/whoop_protocol_5.json` v0 — the canonical 5.0 schema: the Maverick outer-wrapper envelope (length@off2, role@off4, flat body, 4-byte trailer tagged HYPOTHESIS), the verified GATT constants, and `firmware_revision: WG50_r52`, every field confidence-tagged.
- `re/survey_5/validate_frames_5.py` — the critical-gate validator providing the working `strip_maverick()` (pure `bytes -> bytes`) that Phase 4 imports or inlines.
- `re/survey_5/frames_5_golden.json` — 46 wrapper-stripped entries spanning all four custom characteristics, the Phase 4 starting decode corpus.
- `re/capture/evidence/2026-05-30-framing-5.meta.yaml` — the redacted pass-rate + wrapper-overhead evidence sidecar (no BD_ADDR / SMP keys / device identity committed; raw `.pklg` captures local-only and gitignored).

### r52 enum-map reuse (Phase 4 input)

The Hardware Revision reads `WG50_r52` (section 1), which matches the whoop-vault **r52** revision behind the 4.0 enum maps. The r52 command-ID and event-ID enum maps are therefore **directly usable in Phase 4 without re-derivation** — Phase 4 decodes the wrapper-stripped flat body against the existing r52 maps rather than re-deriving codes from scratch.

### Go/no-go verdict (Phase 4 entry condition, D-03b)

> **wrapper characterised, decode work cleared with wrapper-strip step**

Phase 3 (the critical gate) is closed: the 4.0 inner framing is conclusively not reused (0% gate), the Maverick outer wrapper is characterised with HIGH confidence (5028/5028), and a working `strip_maverick()` exposes the flat body for decoding. The OPEN trailer-checksum algorithm is recorded but does not gate Phase 4. This verdict is the committed Phase 4 entry condition per D-03b — Phase 4 may begin.
