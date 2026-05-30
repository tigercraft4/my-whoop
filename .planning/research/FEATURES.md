# WHOOP 5.0 BLE Feature Landscape

**Domain:** Local BLE reverse-engineering of WHOOP 5.0 / WHOOP MG fitness wearable
**Researched:** 2026-05-30
**Reference baseline:** WHOOP 4.0 protocol fully mapped (see `FINDINGS.md`)
**Overall confidence:** MEDIUM — hardware/marketing facts HIGH; on-wire layout MEDIUM; ECG/BP on-wire LOW.

---

## TL;DR for the roadmap

WHOOP 5.0 is **the same architecture as 4.0 with one hard-confirmed protocol change and several plausible-but-unproven additions**:

- **HARD CHANGE (confirmed in third-party RE code):** a *second* GATT service prefix `fd4b0001-cce1-4033-93ce-002d5875f58a` is exposed in parallel with the 4.0 `61080001-…` service. Same 7-characteristic shape, same `0xAA` framing, same CRC8/CRC32, same command IDs and event IDs as 4.0. **A 4.0 decoder that switches its UUID prefix will keep working.**
- **NEW MARKETING METRICS that need new on-wire decoding work:**
  - **ECG** (MG only) — on-demand 30s trace from thumb+index on the clasp electrodes (new HW)
  - **Blood Pressure Insights** (MG only) — overnight estimate, cuff-calibrated, PPG-derived
  - **Healthspan / WHOOP Age** (5.0 + MG) — cloud-computed from existing signals
  - **Hormonal Insights** (5.0 + MG) — cloud-computed from cycle log + HRV/temp
- **Skin temperature**: third-party RE claims a value is now in the event stream on 5.0 (`TEMPERATURE_LEVEL` event 17 with 4-byte LE int / 100000 → °C). On 4.0 we confirmed only the event *enum* exists with no decoded value. **Plausible 5.0 addition, but unverified by us.**
- **What's still cloud-only and not reachable from BLE on 5.0** (same as 4.0): Strain, Recovery, Sleep stages, HRV trends, "WHOOP Age", Blood Pressure trend, AFib classification. The strap is a sensor; analytics are server-side. Anyone claiming to decode "Recovery from BLE" is *computing their own*, not reading WHOOP's.

---

## 1. Hardware delta vs 4.0 (informs what *can* possibly be on the wire)

| Subsystem | WHOOP 4.0 | WHOOP 5.0 | WHOOP MG | Implication |
|---|---|---|---|---|
| Optical AFE | MAX86171 (5 LED / 4 PD) | unknown part, "likely upgraded", same 5/4 array | same as 5.0 | PPG packet shape probably similar; bit-depth may change |
| MCU | MAX32652 (Cortex-M4, 120 MHz) | unknown, presumed upgraded | same as 5.0 | More RAM → bigger historical buffer plausible |
| Temp sensor | MAX6631 (12-bit SPI) | "improved" | same as 5.0 -wire temp value is now claimed feasible |
| IMU | 6-axis (accel + gyro), 52 Hz | 6-axis, same shape per tazjin | same as 5.0 | Same int16 X/Y/Z×2 layout assumed |
| ECG electrodes | none | none | **clasp electrodes (thumb + index)** | New on-demand pathway, MG-only |
| BP cuff | none | none | **none — PPG-derived overnight** | No new HW; new firmware processing + cloud model |
| Battery life | ~5 days | "14+ days" (10× efficiency claim) | "14+ days" | Implies lower duty cycle or compression on raw streams |
| Headline sampling | 52 Hz raw / 1 Hz passive | "26 Hz HR/motion/temp" per teardown | same as 5.0 | Raw-data packet rate may halve vs 4.0 |
| Wear locations | wrist only | wrist + bicep + apparel | same | BLE protocol unchanged; affects PPG SNR not framing |

**Confidence:** HIGH for 4.0 chip IDs (TechInsights teardown), MEDIUM for 5.0 (the5krunner teardown reports "unknown exact part"), HIGH for ECG hardware existence (WHOOP support docs describe the thumb/finger procedure), HIGH for BP being cuff-calibrated PPG-derived overnight estimate (WHOOP marketing + multiple secondary sources).

---

## 2. App-visible metrics: 4.0 vs 5.0/MG (what users see → what BLE must carry)

| Metric | 4.0 app | 5.0 app | MG app | On-wire on 4.0? | Likely on-wire on 5.0/MG? |
|---|---|---|---|---|---|
| HR (live BPM) | ✅ | ✅ | ✅ | ✅ standard `0x2A37` + proprietary type 40 | ✅ same; standard HR works unbonded |
| R-R intervals | ✅ | ✅ | ✅ | ✅ standard `0x2A37` | ✅ same |
| SpO₂ overnight | ✅ | ✅ | ✅ | ❌ cloud-computed from raw PPG | ⚠️ possibly in metadata type 53 (third-party claim, unverified) |
| Skin temperature | ✅ | ✅ | ✅ | ❌ event enum exists, no value | ⚠️ third-party RE claims event 17 payload now carries °C×100000 |
| Respiration rate | ✅ | ✅ | ✅ | ❌ cloud (derived from PPG/RR) | ❌ likely still cloud — can be self-estimated from R-R |
| Strain | ✅ | ✅ | ✅ | ❌ cloud | ❌ cloud |
| Recovery score | ✅ | ✅ | ✅ | ❌ cloud | ❌ cloud |
| Sleep stages | ✅ | ✅ | ✅ | ❌ cloud (from IMU+PPG) | ❌ cloud |
| Workout / activities | ✅ | ✅ | ✅ | ❌ cloud (auto-detected from IMU) | ❌ cloud |
| Battery % | ✅ | ✅ | ✅ | ✅ standard `0x2A19` + cmd 26 | ✅ same |
| Historical 14-day buffer | ✅ | ✅ | ✅ | ✅ cmd 22 + trim cursor | ✅ same (likely longer window) |
| Raw accel + gyro (6-axis) | dev/research | dev/research | dev/research | ✅ 100 samples/axis/packet | ✅ same shape per tazjin |
| Raw PPG (multi-channel) | dev/research | dev/research | dev/research | ✅ 1921-B paired packet, 24-bit, ~4 channels | ✅ likely same; bit-depth may change |
| **Healthspan / WHOOP Age** | ❌ | ✅ | ✅ | n/a | ❌ cloud-only |
| **Hormonal Insights / cycle** | partial | ✅ | ✅ | n/a | ❌ cloud (input is user log + temp) |
| **ECG (30s on-demand)** | ❌ | ❌ | ✅ | n/a | ⚠️ new pathway — likely a new packet type triggered by a new command. **Not yet in any public RE.** |
| **Blood Pressure (daily)** | ❌ | ❌ | ✅ | n/a | ❌ overnight cloud estimate from same PPG already on the wire; no new BLE surface expected |
| **AFib screen** | ❌ | ❌ | ✅ | n/a | ❌ cloud classification on ECG trace |
| Stress monitor | ✅ (later FW) | ✅ | ✅ | ❌ cloud | ❌ cloud — derivable from HRV locally |

**Confidence by row:**
- Standard BLE rows: HIGH (cross-referenced with 4.0 protocol)
- "Cloud" claims: HIGH (whoomp, bWanShiTong, tazjin, our own findings all agree the strap is dumb)
- Skin-temp 5.0 row: LOW — single third-party RE source (Sivasai2207), formula not validated against the app
- ECG row: MEDIUM-LOW — no public RE has captured an ECG packet yet; the inference is from product behaviour
- BP row: HIGH — confirmed marketing description matches "no new sensor, PPG model"

---

## 3. BLE protocol delta: 4.0 → 5.0 (the *concrete* RE picture)

### Confirmed-novel finding for 5.0

**New GATT service prefix exposed in parallel.** The only published WHOOP 5.0 RE codebase (Sivasai2207/WHOOP-Reverse-Engineering-5.0, Kotlin/Android) hardcodes *both* prefixes as alternatives:

```
Service:      61080001-8d6d-82b8-614a-1c8cb0f8dcc6   (4.0)
              fd4b0001-cce1-4033-93ce-002d5875f58a   (5.0)
Cmd in:       …0002…
Cmd resp:     …0003…
Events:       …0004…
Data:         …0005…
Diagnostics:  …0007…
```

The 7-characteristic shape is **identical**. Same `0xAA[len][crc8][type][seq][cmd][payload][crc32]` frame. Same CRC polys. Same command IDs (1, 2, 3, 7, 11, 14, 22, 26, 35, 81, 82, 106, 107, 145 all reused). Same event IDs (3, 7, 8, 9, 10, 17, 24, 33, 46, 63 all reused).

**Implication for the codebase:** any 4.0 decoder that hardcodes the UUID needs to become prefix-agnostic. **One-line fix at the GATT layer**, then everything below in `whoomp/scripts/packet.py` should keep working.

### Plausible-but-unverified 5.0 changes (flagged for empirical validation)

| Claim | Source | Confidence | How to verify on the device |
|---|---|---|---|
| Skin temp now in event 17 payload (4 LE bytes / 100000 = °C) | Sivasai2207 README + code | LOW | Subscribe to event char, wear strap; expect ~30–37°C; cross-check with a thermometer |
| SpO₂% in metadata type 53 payload byte 10 | Sivasai2207 | LOW | Capture overnight, look for type-53 packets, check 90–100 range |
| `REALTIME_DATA` type byte changed from 0x14 (=20) to 0x28 (=40) | Sivasai2207 | LOW | Conflict: 4.0 already uses 0x28 (=40) for `REALTIME_DATA`. Likely the *4.0* code was wrong, not a 5.0 change. **Don't trust.** |
| `EVENT` type byte 0x30 (=48) instead of 0x04 | Sivasai2207 | LOW | Same as above — 0x30 is the established 4.0 value. The claim of "corrected from 0x04" is suspect. **Don't trust.** |
| Raw-data sample rate 26 Hz instead of 52 Hz | the5krunner teardown | MEDIUM | Count samples in a `REALTIME_RAW_DATA` packet; if ~50 instead of ~100, the 26 Hz claim holds |
| Bigger historical buffer (>14 days) | inferred from "14+ day battery" marketing | LOW | `GET_DATA_RANGE` (cmd 34) returns the actual stored window |
| New command(s) for ECG capture trigger | inferred from MG ECG feature | MEDIUM | Sniff MG app session, or probe-enumerate commands 145–255 |
| New data packet type for ECG samples (likely high-rate single-channel) | inferred | MEDIUM | After ECG trigger, watch char `…0005` for an unfamiliar type ID |

---

## 4. Table stakes for v1 (must decode for the project to be "WHOOP-5-capable")

These are the metrics a 5.0 owner expects their own-data app to show. Missing any → product feels broken.

| Feature | Why expected | Complexity | Status (relative to 4.0 work) |
|---|---|---|---|
| Live HR | The headline number | **Low** | Standard `0x2A37` works unbonded; trivial |
| R-R intervals (HRV substrate) | Required for any self-Recovery | **Low** | Standard `0x2A37`; trivial |
| Battery % + voltage | UX must show it | **Low** | Standard `0x2A19` + cmd 26 |
| Bonding + custom service unlock | Gate to everything proprietary | **Medium** | Same trick as 4.0 (one confirmed write); just at the new UUID |
| Historical offload (14-day buffer) | Background sync is the product | **Medium** | Cmd 22 loop + trim cursor; same as 4.0 |
| Device clock correlation | Without it, timestamps are unusable | **Low** | Cmd 11 + wall-clock anchor |
| Wrist-on / charging events | Needed for session segmentation | **Low** | Event chars 9/10/7/8 |
| Skin temperature (decoded value) | Visible in 5.0 app, users will expect it | **Medium** | New for us — validate the LE-int/100000 hypothesis |
| Raw 6-axis IMU (100 samples/packet) | Substrate for self-sleep, self-activity | **Medium** | Layout known from 4.0; verify sample count on 5.0 |
| UUID-prefix abstraction | Same codebase supports 4.0 + 5.0 + MG | **Low** | Refactor GATT layer |

---

## 5. Differentiators for v1 (set us apart, but defer past MVP)

| Feature | Value proposition | Complexity | Notes |
|---|---|---|---|
| Self-computed Recovery (HRV-based) | Drops the subscription requirement for the headline number | Medium | RMSSD over night-window R-R; documented method |
| Self-computed Strain | Same, second headline number | Medium | HR-reserve TRIMP-style; many published formulas |
| Self-computed Respiration rate | RSA from R-R series | Medium | FFT or zero-cross on R-R; reference: Sivasai2207 does it live |
| Raw PPG decode + own SpO₂ estimate | Crosses what WHOOP charges for | **High** | We located the 1921-B PPG packet on 4.0; channel→LED map still open; same likely on 5.0 |
| **ECG capture + waveform export** (MG only) | The single biggest "we did what they charge $$ for" win | **High** | Requires probing the unmapped command space, identifying the trigger, capturing the 30s stream, validating waveform shape. No public RE has done this. |
| Wear-location switching (bicep, apparel) | Matches 5.0 product flexibility | Low | Probably just an event/config flag |
| Open data export (CSV/Parquet/FIT) | Trivial once data is in our SQLite | Low | Pure software; defer to a later phase |

---

## 6. Anti-features (explicitly do NOT build for v1)

| Anti-feature | Why avoid | What to do instead |
|---|---|---|
| Implementing WHOOP's exact Strain/Recovery formulas | They are proprietary, cloud-only, and a moving target. Reverse-engineering scoring is a copyright/T&C minefield distinct from interoperability. | Compute *our own* scores from raw R-R + IMU and label them as ours. |
| Spoofing the official WHOOP app's identity to their cloud | Trivially TOS-violating and uninteresting for a local-first project. | Stay purely on the BLE side; don't touch their cloud auth. |
| Decoding "WHOOP Age", "Pace of Aging", "Hormonal Insights" from BLE | These are cloud-computed model outputs. The inputs are *already* on the BLE wire (HR, HRV, temp). | Decode the inputs. Let the user compute their own derivatives later. |
| Pushing firmware updates / writing to flash / changing device config persistently | High brick risk on someone's $200 hardware. | Read-only + transient-toggle (`TOGGLE_REALTIME_HR`, `START_RAW_DATA`) only. Document any setter as "do not call". |
| BP estimation without cuff calibration | Even WHOOP requires 3 cuff readings to bootstrap. Doing it ungated is medically irresponsible. | Don't ship BP at all in v1; it's an MG-cloud feature anyway. |
| Claiming AFib detection | Medical-device regulated; WHOOP themselves got an FDA notice on BP. | Don't. Ever. Ship the ECG *waveform* as a research export; let users take it to a clinician. |

---

## 7. Feature dependencies (drives phase ordering)

```
1. UUID-prefix abstraction (5.0 GATT)
        ↓
2. Bonding handshake on new prefix
        ↓
3. Standard HR/Battery (works without bonding — quick win)
        ↓
4. Command surface re-probe on 5.0 (which IDs work? unsupported = 0a03)
        ↓
5. Historical offload on 5.0 (validates trim-cursor, gives backfill UX)
        ↓
6. Event-stream decode including new TEMPERATURE_LEVEL value
        ↓
7. Raw 6-axis IMU validation (sample count, scale)
        ↓
8. Raw PPG re-validation on new optical AFE
        ↓
9. (MG only) ECG command discovery + waveform capture
```

Each arrow is a hard prereq, not a soft one. 5 unlocks 6 (you need history-stream parsing to spot the temp value). 7 must succeed before 9 makes sense (same data char, you need to confidently distinguish packet types).

---

## 8. MVP recommendation

**Ship in v1 (target: any 5.0 owner gets useful local data):**
1. Dual-prefix GATT layer + bonding on 5.0
2. Live HR, R-R, battery (the standard-services unlock)
3. Historical 14-day offload with trim-cursor sync
4. Decoded events (wrist on/off, charging, battery, temperature value)
5. Raw 6-axis IMU stream to SQLite (don't compute anything yet — just store)

**Ship in v1.1 / v2 (differentiators):**
6. Self-computed nightly HRV / RMSSD / our-own-Recovery
7. Raw PPG channel mapping (port 4.0 work, re-validate)
8. (MG only) ECG packet hunt — this is research, not a deadline feature

**Defer indefinitely / out of scope:**
- BP estimation, AFib, WHOOP Age, Hormonal Insights, sleep staging
- Anything that requires us to replicate a cloud-only ML model

---

## 9. Gaps in this research (what we *don't* know and should flag)

1. **No one has published a 5.0 GATT dump with bonded characteristics enumerated.** Sivasai2207 lists UUIDs and reuses 4.0 command IDs but the README is silent on whether they confirmed each one returns the same payload shape on 5.0. **Action:** run our existing `probe_commands.py` against a 5.0 once we have access.
2. **No one has captured an MG ECG session over BLE.** This is genuinely virgin territory. Even tazjin's Gadgetbridge issue doesn't mention ECG.
3. **The 5.0 optical AFE part number is not public.** If it changed, the PPG bit-packing may have changed too. Plan to re-run our raw-PPG analysis pipeline on the new device.
4. **`fd4b` service prefix origin is undocumented.** It might be the regulatory rebrand (MG is a separate FCC ID, PCB 820-000188 vs 820-000100). Possible that *only* MG advertises `fd4b` and base 5.0 still uses `6108` — we cannot tell from the available code. **Action:** observe both flavours when accessible.
5. **The "26 Hz" claim from the5krunner conflicts with 4.0's confirmed 52 Hz.** Worth measuring on real hardware; affects expected sample counts per packet.

---

## 10. Sources

| URL | What it gave us | Confidence |
|---|---|---|
| `FINDINGS.md` (this repo) | Full 4.0 protocol baseline, including bonded layout, IMU offsets, raw-PPG packet location | HIGH (self-validated) |
| https://codeberg.org/Freeyourgadget/Gadgetbridge/issues/5731 (tazjin) | First-hand WHOOP 5.0 RE notes: ~70 commands, IMU = 6 ints, skin-temp format unsolved, no on-device analytics | MEDIUM (claim, code unpublished) |
| https://github.com/Sivasai2207/WHOOP-Reverse-Engineering-5.0 | **Only published 5.0 codebase**: dual UUID prefixes (`6108…` + `fd4b…`), shared 4.0 command/event IDs, claimed skin-temp + SpO₂ decode formulas | MEDIUM (UUIDs HIGH; decode formulas LOW — unvalidated) |
| https://github.com/jogolden/whoomp | Canonical 4.0 packet structure and command enum — confirmed reused on 5.0 | HIGH |
| https://github.com/bWanShiTong/reverse-engineering-whoop | Historical sync, CRC, alarm/clock — confirmed reused on 5.0 | HIGH |
| https://www.whoop.com/us/en/thelocker/introducing-whoop-5-0-and-whoop-mg/ | Marketing: Healthspan, Hormonal Insights, MG ECG + BP exist; 14+ day battery; 10× power efficiency | HIGH for feature *existence* |
| the5krunner WHOOP 4.0 vs 5.0 sensor architecture article (URL: https://the5krunner.com/2025/06/16/whoop-4-0-vs-whoop-5-0-sensor-architecture-changes-detailed-technical-content/) | 4.0 chip IDs (MAX86171/MAX32652/MAX6631), 5.0 PCB 820-000100, MG PCB 820-000188, MG has ECG electrode clasp, 26 Hz claim | MEDIUM-HIGH (teardown reporting) |
| WHOOP support docs (via search) | MG ECG procedure: 30s hold of thumb+index on clasp; BP requires 3 cuff calibration readings | HIGH |
| TechInsights teardown of WHOOP 4.0 (via the5krunner) | 4.0 chip part numbers | HIGH |

---

## 11. One-paragraph guidance for the roadmap author

The WHOOP 5.0 work is **not a rewrite of the 4.0 work — it's a port plus three additions**. The port (1 weekend of work if 4.0 code is clean) is making the GATT layer accept the `fd4b…` UUID family. The three additions are: (a) **validate** each 4.0 finding still holds on 5.0 hardware via the existing probe scripts; (b) **decode the skin-temperature value** in the event stream that Sivasai2207 claims exists (we never solved this on 4.0); (c) **discover the ECG capture pathway** on MG — this is genuinely novel research and should be its own milestone with a research-mode flag, not lumped into a feature phase. Everything WHOOP markets as "new on 5.0" that *isn't* ECG or BP (Healthspan, Hormonal, Pace of Aging) is cloud-side and irrelevant to a BLE project; do not let it inflate scope.
