# Architecture Patterns — WHOOP 5.0 RE Discovery Pipeline

**Domain:** BLE wearable protocol reverse engineering → local-first iOS client
**Researched:** 2026-05-30
**Mode:** Ecosystem (RE workflow architecture)
**Overall confidence:** HIGH for the discovery loop and tooling order (validated by the 4.0 codebase, Gadgetbridge's documented RE workflow, and the whoomp project's progression); MEDIUM for the specific build-order recommendation (informed opinion based on what made the 4.0 fork tractable in retrospect).

---

## Executive Summary

The 4.0 codebase already encodes the right pattern — it just isn't named or sequenced explicitly. This document makes the implicit architecture explicit and prescribes the order for WHOOP 5.0.

**The single most important architectural decision:** the **canonical JSON schema** (`whoop_protocol.json`) is the boundary between RE and app code. Discovery writes to the schema; decoders read from it; both Swift and Python consume the same artifact. This is what makes the pipeline shippable while RE is still in progress — the schema is the **only** thing that needs to be "right" before downstream code can be useful.

**Recommended discovery order:**
```
1. GATT survey         (passive enumerate; ~1 day)
2. Reference capture   (PacketLogger + Android btsnoop, golden traces; ~1 day)
3. Framing             (is it 4.0's [0xAA][len][crc8][type][seq][cmd][payload][crc32]?)
4. Command surface     (probe-and-respond enumeration; ~3-5 days)
5. Stream decode       (live realtime + historical, biggest unknown; ~weeks)
6. Schema freeze v0    (whoop_protocol_5.json — minimum viable schema)
7. Swift decoder fork  (consumes schema)
8. Store migration     (kinds/tables stay; columns may shift)
9. BLE layer (iOS)     (CoreBluetooth orchestrator — last, but a simplified spike earlier)
10. UI                 (last; trivial once data flows)
```

**The critical insight:** do **not** build the iOS BLE layer until the protocol is understood. Build it on the **Mac** (Python + bleak, like `re_harness.py`) until you have ≥3 working streams. The iOS app only ports a known protocol; it never *discovers* a protocol. Cross-platform RE is a category error — the discovery loop needs Python speed, not Swift safety.

---

## The Recommended Architecture: a Discovery Pipeline (not a product pipeline)

The 4.0 architecture (`collect → decode → store → sync`) is the **product** architecture. For 5.0, while protocol is unknown, the operating architecture is a **discovery loop** that *produces* the artifacts the product architecture consumes.

```
┌─────────────────────────────────────────────────────────────────┐
│                       DISCOVERY LOOP (Mac/Python)               │
│                                                                 │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│   │ Capture  │ →  │ Replay & │ →  │ Hypothes-│ →  │ Schema   │ │
│   │ (HCI +   │    │ Compare  │    │ ise &    │    │ Patch    │ │
│   │  bleak)  │    │ (golden  │    │ Validate │    │ (JSON)   │ │
│   │          │    │ fixtures)│    │ (analyze │    │          │ │
│   │          │    │          │    │ scripts) │    │          │ │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘ │
│         ↑                                              │        │
│         └──────────────────────────────────────────────┘        │
│                       (iterate until                            │
│                        coverage ≥ MVP)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ↓
                  protocol/whoop_protocol_5.json  (the contract)
                              │
                ┌─────────────┴─────────────┐
                ↓                           ↓
┌──────────────────────────┐    ┌──────────────────────────┐
│ Swift decoder (iOS)      │    │ Python decoder (server)  │
│ Packages/WhoopProtocol/  │    │ server/.../whoop-        │
│ — pure decode library    │    │ protocol/                │
└──────────────────────────┘    └──────────────────────────┘
                │                           │
                ↓                           ↓
        Product pipeline                Server analysis
        (BLE → Collect →               (compute_day, HRV,
         Store → Upload)                recovery, strain)
```

**Read this diagram as: the loop on top runs for weeks. The arrows down the middle are the moment the protocol is "good enough" to start the iOS work in earnest.** Both sides keep evolving — the schema is patched as new packets are understood, and the decoders re-load it.

### Component boundaries

| Component | Responsibility | Owns | Communicates with |
|-----------|---------------|------|-------------------|
| **RE harness** (`re/re_harness.py` 5.0 port) | Hold BLE link, log raw + parsed, drive commands via control file | `re_log.jsonl`, `control.txt`, raw histories | bleak (BLE), whoomp `WhoopPacket` (until 5.0 framing diverges) |
| **Capture tooling** (PacketLogger + btsnoop) | Reference traces from official apps | `*.pklg`, `btsnoop_hci.log` | None — input only |
| **Replay/compare scripts** (`re/analyze_*.py` family) | Apply hypotheses, validate against captures | Diagnostic outputs, golden fixtures | Reads JSONL + binary captures |
| **Schema** (`protocol/whoop_protocol_5.json`) | Single source of truth for framing + packet layouts | The contract | Read by both decoders |
| **Swift decoder** (`Packages/WhoopProtocol/`) | Parse frames, extract streams. Pure library. | Decode functions | Loads schema lazily; consumed by iOS Collect layer |
| **Python decoder** (`server/.../whoop-protocol/`) | Mirror of Swift decoder for server-side | Decode functions | Loads same schema; consumed by ingest pipeline |
| **iOS app** (`ios/OpenWhoop/`) | Product UI + BLE transport + storage | User-facing experience | Uses WhoopProtocol + WhoopStore packages |
| **Server** (`server/ingest/`) | Optional analysis + dashboard | Derived metrics, dashboard | Pulls decoded streams from app |

The boundary that matters most: **`whoop_protocol_5.json` is the only artifact shared between RE and product code.** Everything else is implementation-local.

### Data flow during discovery

```
WHOOP 5.0 ──┬─→ PacketLogger / iPhone-paired-to-Mac ──→ .pklg trace ──┐
            │                                                          │
            ├─→ Android (HCI snoop)                  ──→ btsnoop.log ──┤
            │                                                          │
            └─→ Mac (re_harness.py via bleak)        ──→ re_log.jsonl ─┤
                                                                       │
                                                                       ↓
                                                     ┌─────────────────────────┐
                                                     │  fixtures/ (committed)  │
                                                     │  • motion_capture.jsonl │
                                                     │  • optical_capture.jsonl│
                                                     │  • hist_v??_sample.bin  │
                                                     └─────────────────────────┘
                                                                │
                                              analyze_*.py + verify_protocol.py
                                                                │
                                                                ↓
                                              protocol/whoop_protocol_5.json
```

Once the schema produces stable results against the fixtures, the product pipeline takes over and the loop only re-runs when a new packet variant is observed in the wild.

---

## Patterns to Follow

### Pattern 1: Schema as Contract (the "living schema")

**What:** A versioned JSON file (`whoop_protocol_5.json`) describes envelope framing, packet types, payload field offsets, enums, and variants. Both decoders load it. Tests assert against it. Hypotheses are encoded *into* it. Nothing about the protocol exists outside it.

**When:** Always. Start the schema empty on day 1; commit a patch each time you understand a new field. Treat the schema like source code — it's diffable, reviewable, and the unit of progress.

**Why it works (from the 4.0 evidence):**
- The 4.0 schema documents not just *what works* but *what's open* — see the `note` fields on `1917` (IMU) and `1921` (optical), which contain provenance ("Gen4-VERIFIED (motion_capture.jsonl + gyro_calib 720deg rotations)"). The schema doubles as a research log.
- `ref` indirection (`"7": {"ref": "5"}`) lets variants share definitions when discovered to be equivalent — incremental refinement is cheap.
- Both Swift (`WhoopProtocol.loadSchema()`) and Python (`whoop_protocol.parse_frame()`) reduce to "look up the offset in the JSON and slice bytes" — no protocol logic lives in either language. Adding a field is a JSON edit, not a code change.

**Example** (5.0 schema scaffold to start with):
```json
{
  "version": 1,
  "device_generation": 5,
  "enums": { "PacketType": { /* fill as discovered */ } },
  "envelope": [
    { "off": 0, "len": 1, "name": "SOF", "cat": "frame",
      "note": "HYPOTHESIS: 0xAA per 4.0; verify in first capture" }
  ],
  "packets": {}
}
```

Mark unconfirmed fields with `"note": "HYPOTHESIS: ..."` and have `verify_protocol.py` (port from 4.0) flag any frame whose decode invokes a HYPOTHESIS field. That keeps unvalidated assumptions visible.

### Pattern 2: Golden Fixtures (record-once, replay-forever)

**What:** A small set of committed binary or JSONL captures that exercise each known packet variant, paired with expected decode output. New schema changes must keep all goldens green.

**When:** As soon as a packet type is even partially understood. The 4.0 project has `motion_capture.jsonl` (labeled controlled-motion: 4 static orientations + 3 single-axis rotations) and `optical_capture.jsonl` (finger-on / air phase). These were the foundation of every later refinement.

**How:**
- `scripts/gen_golden.py` (per the 4.0 `re/README.md`) snapshots a capture and its decoded form together
- CI (or a pre-commit hook) replays goldens through the current decoder and diffs against expected output
- When a schema edit changes a golden's output, the diff is reviewed; if intentional, the golden is updated in the same commit

**Why it works:** the 4.0 IMU offsets were guessed wrong twice before being correct (FINDINGS §9b: "Earlier purely-empirical guesses (accel 38–68, gyro 1512–1692) were WRONG"). Goldens give you a regression net so you can fearlessly try new offsets — if your guess breaks motion_capture decode, you know within seconds.

### Pattern 3: Capture from Two Independent Sources

**What:** Always capture the same scenario from **both** the iPhone WHOOP app (via PacketLogger) **and** the Android WHOOP app (via HCI snoop). Cross-reference.

**When:** Every time you're stuck on what a command does or what a payload means.

**Why:** iOS and Android implementations of the same protocol will often have:
- Different command timing → reveals which commands are *required* vs. cosmetic
- Different error handling → reveals optional response fields
- Different framing fragmentation → confirms the wire format (BLE MTU varies by stack)
- Slightly different feature surfaces → reveals server-driven feature flags

The 4.0 project leaned mostly on a single source (whoomp's firmware extraction) and consequently has open questions that two-source captures could have closed earlier (e.g., the 1917 vs 1921 packet distinction).

### Pattern 4: Probe-and-Respond Command Enumeration

**What:** Send every command ID in the suspected enum space (0–255, or a smaller seeded range) with a known-safe payload (e.g., `\x00`) and log the response. Bucket responses into "ok / unsupported / no response / crash".

**When:** Right after framing is solved (step 4 in the build order). The 4.0 project did this with `re/probe_commands.py` → `command_probe.jsonl`.

**Why:** Many commands are simple GETs that respond with self-describing payloads. Enumerating the surface up front gives you a map of "what's available" before you understand any one command in depth. Status byte conventions emerge (4.0: `0x0a 0x01` = ok, `0x0a 0x03` = unsupported) which then become parsing primitives for every subsequent response.

**Safety:** start with GET-prefixed names from the 4.0 enum as your initial probe list — they're known non-destructive. Save destructive-sounding ones (REBOOT, FORCE_TRIM, START_FIRMWARE_LOAD) for last and behind a manual confirmation.

### Pattern 5: Hold-Connection Harness as Always-On Substrate

**What:** A long-running script (port of `re/re_harness.py`) that:
1. Holds the BLE link open with auto-reconnect
2. Subscribes to every characteristic and logs notifications losslessly to JSONL
3. Reads a control file (`control.txt`) for command dispatch — lets you experiment without restarting

**When:** From day 1 of capture-phase work. Everything else in the discovery loop layers on top of this.

**Why:** BLE bonding state is fragile (4.0 finding: must issue a confirmed write to trigger "just-works" bonding). Re-bonding repeatedly during exploration is slow and risks losing context. Hold the link; use a control file to issue commands without disrupting the subscription state.

### Pattern 6: Lossless Raw Capture Before Decoding

**What:** Store the raw bytes of every notification **before** trying to decode. Decoded output is derived; raw is canonical.

**When:** Always — both in the RE harness (`re_log.jsonl` keeps `hex`) and in the product app (4.0 `WhoopStore` has a `rawBatch` table and the "decoded-first" invariant ensures raw is enqueued *after* decoded streams, so pruning raw never loses decoded data).

**Why:** When you later discover a packet had more fields than you decoded, you can re-run analysis on stored raw data. Without this, you have to re-capture the scenario — which may not be reproducible (e.g., it was during a specific workout, or under specific firmware).

### Pattern 7: Replay-Driven Validation

**What:** `re/verify_protocol.py` style: load the canonical schema, replay every captured frame, assert every byte is accounted for (or explicitly marked "unknown"). Track coverage.

**When:** Continuously, as a CI check.

**Why:** Coverage is the discovery progress metric. "We decode 73% of bytes across 12 packet types" is far more meaningful than "we have a decoder." The 4.0 schema notes flag uncovered regions explicitly ("Gaps [24:82],[682:685] + tail [1292:1917] (~36%) still unmapped") — port this discipline to 5.0 from day 1.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Building iOS First

**What:** Starting with CoreBluetooth + SwiftUI before the protocol is understood.

**Why bad:**
- Swift/Xcode iteration is 10–100× slower than Python iteration for byte-level work
- iOS can't run in the Simulator for BLE (FINDINGS confirms 4.0 already); every experiment is a real-device build-deploy cycle
- You'll prematurely freeze interfaces (frame format, command enum) that the discovery loop hasn't validated yet
- You'll write protocol logic in Swift that should live in the schema

**Instead:** Mac + Python until you have ≥3 working decoded streams (HR, RR, battery is a reasonable bar). Port to Swift only when the schema is stable for those streams.

### Anti-Pattern 2: Skipping the Schema and Hardcoding Offsets

**What:** Writing decode functions with literal byte offsets (`data[14]` for heart rate) directly in Swift or Python.

**Why bad:** When the offset turns out to be wrong (it will — see 4.0 IMU history), you change code in two languages and re-test both. The whole point of `whoop_protocol.json` is that offsets are data, not code.

**Instead:** Even your first prototype decoder reads from JSON. The JSON can be `{"hr_off": 14}` initially — it doesn't need to be elegant, it needs to be *one place to change*.

### Anti-Pattern 3: Treating "Unsupported" as Useful Signal Too Early

**What:** Probing commands and concluding "command X doesn't exist on this firmware" from a single `0x0a 0x03` response.

**Why bad:** WHOOP firmware has gated/configurable features. Commands that respond "unsupported" on the default config may activate after a `SET_DP_TYPE` (4.0: `52`) or research-mode flag (`SET_RESEARCH_PACKET` 131 with `enable_r19_packets`). Discarding them prematurely shrinks your map of the device.

**Instead:** Log unsupported separately, retry after configuration changes, and especially retry after observing the official app issue any unfamiliar command.

### Anti-Pattern 4: Mixing 4.0 and 5.0 Code

**What:** Adding `if generation == 5` branches throughout the existing 4.0 codebase.

**Why bad:** You don't know how different 5.0 is yet. PROJECT.md correctly identifies this as a key decision and proposes a clean fork. Honor that.

**Instead:** Fork, then aggressively delete 4.0-specific assumptions until something breaks; that's the surface area that needs 5.0 RE.

### Anti-Pattern 5: Decoder Catches Exceptions Silently

**What:** `try: parse_frame(...) except: pass` in the harness so the loop keeps running.

**Why bad:** You lose the signal that a packet doesn't match your model. The whole job is *finding* mismatches.

**Instead:** Log unparsed frames with the exception (4.0 `re_harness.py` does this correctly: `log(char_name, raw, note=f"unparsed: {e}")`). These become your TODO list.

### Anti-Pattern 6: Skipping Two-Source Capture

**What:** Working only from iPhone PacketLogger because it's easier on a Mac.

**Why bad:** When iPhone-side traffic shows a behavior you can't explain, you have no second perspective. Android btsnoop logs are cheap; capture both from session one.

### Anti-Pattern 7: Living-Schema Without Provenance

**What:** Updating the schema without a `"note"` explaining how each offset was confirmed.

**Why bad:** Six months later, no one remembers whether `accel_x_off` came from a controlled capture, the official APK, or a guess. When something breaks, you don't know which fields to trust.

**Instead:** Every field gets a `"note": "..."` with verification source. The 4.0 schema models this well — copy the convention.

---

## Build Order (the actionable recommendation)

This is the order to build for a successful 5.0 fork. Earlier steps unblock later ones; skipping ahead causes rework.

### Phase A — Reconnaissance (week 1)

| # | Step | Tool | Output | Done when |
|---|------|------|--------|-----------|
| 1 | GATT service enumeration | `re/gatt_dump.py` port + iOS `nRF Connect` | Service/characteristic table | All services + characteristics listed with permissions |
| 2 | Standard profile check | bleak `BleakClient.read_gatt_char` | Confirm `0x180D`/`0x180F`/`0x180A` work | HR or battery readable from standard profile |
| 3 | Bonding workflow | Adapt 4.0 "confirmed write" trick | Documented bonding sequence | Custom service characteristics start emitting notifications |
| 4 | Two-source reference captures | PacketLogger + Android btsnoop | `captures/reference/{ios,android}/*.{pklg,log}` | At least 3 scenarios captured: idle 5min, workout start/stop, sleep night |

**Exit criteria:** GATT map documented; bonded link established; reference traces committed to repo.

### Phase B — Framing (week 1–2)

| # | Step | Tool | Output | Done when |
|---|------|------|--------|-----------|
| 5 | Test 4.0 framing on 5.0 | adapt `whoomp/scripts/packet.py` | Verdict: same / shifted / different | Frames decode with CRC valid OR fail with characterized error |
| 6 | If different: bit-pattern analysis | manual + Wireshark btatt | Sketch envelope structure | First/last byte conventions identified, length field located, CRC algorithm identified |
| 7 | Write `verify_protocol.py` for 5.0 | port from 4.0 | Coverage report (initially 0%) | Script runs against all captures and reports byte-level coverage |
| 8 | Write schema v0 (envelope only) | manual JSON | `protocol/whoop_protocol_5.json` | Coverage report ≥ "envelope-only" baseline (~5–10 bytes/frame) |

**Exit criteria:** Framing fully documented in schema; coverage script operational.

### Phase C — Command Surface (week 2)

| # | Step | Tool | Output | Done when |
|---|------|------|--------|-----------|
| 9 | Port `re_harness.py` for 5.0 | adapt | Long-running harness with control file | Can hold link, drive commands, log losslessly |
| 10 | Probe command enumeration | port `probe_commands.py` | `command_probe_5.jsonl` | Every ID 0–255 tested; bucketed ok/unsupported/silent |
| 11 | Decode self-describing responses | `analyze_*.py` family | Schema entries for COMMAND_RESPONSE variants | `GET_BATTERY_LEVEL` equivalent decoded |
| 12 | Map enum names from reference traces | Diff vs. 4.0 enum | Updated `CommandNumber` enum in schema | Names assigned to all responding commands (best-effort) |

**Exit criteria:** Command surface mapped; at least battery + clock readable.

### Phase D — Realtime Streams (week 3–4)

| # | Step | Tool | Output | Done when |
|---|------|------|--------|-----------|
| 13 | Enable HR streaming | port `TOGGLE_REALTIME_HR` equivalent | Realtime packet captures | HR packets arriving at expected cadence |
| 14 | Decode HR + RR | analysis scripts | Schema entries for REALTIME_DATA | HR matches standard `0x2A37` profile reading; RR plausible |
| 15 | Capture events stream | passive | Event packet log | `WRIST_ON`/`WRIST_OFF`/`CHARGING_*` observed and decoded |
| 16 | Generate first goldens | `scripts/gen_golden.py` port | `fixtures/golden_*.jsonl` | Goldens replay green against current schema |

**Exit criteria:** HR + RR + events flowing through schema-driven decoder; goldens in CI.

### Phase E — Schema v0 Freeze + Port (week 5)

This is the **handoff moment**. The Mac/Python work has produced enough understood protocol to make iOS work productive.

| # | Step | Tool | Output | Done when |
|---|------|------|--------|-----------|
| 17 | Freeze `whoop_protocol_5.json` v0 | review | Tagged schema version | Schema decodes HR+RR+events+battery from goldens |
| 18 | Fork `Packages/WhoopProtocol/` | Swift | `WhoopProtocol` for 5.0 | Swift tests pass against same goldens |
| 19 | Fork `Packages/WhoopStore/` | Swift | Schema migrations for 5.0 tables | If kinds same as 4.0, just re-export; if different, new migrations |
| 20 | Spike iOS BLE layer | CoreBluetooth | Connect + bond + read HR end-to-end | Live HR visible in a debug view on device |

**Exit criteria:** iOS app reads HR live from 5.0 strap. Everything downstream (UI, server, analysis) can now proceed in parallel with continued RE on harder packets.

### Phase F — Historical & Raw Streams (week 6+)

The hard problems (IMU layout, optical channel mapping, historical-data versions) continue in the Python harness while iOS work proceeds. **Schema patches flow forward** to Swift via JSON edits, no Swift code changes needed.

| # | Step | Tool | Output |
|---|------|------|--------|
| 21 | Historical offload state machine | port `Backfiller` logic | Historical packets captured + acked |
| 22 | Historical decode versions | `analyze_v??_*.py` family | Schema `versions: {...}` populated |
| 23 | IMU layout (controlled motion) | port `capture_motion.py` | IMU offsets in schema variants |
| 24 | Optical/PPG layout | port `capture_optical.py` | PPG offsets in schema variants |

### Phase G — Product Pipeline (parallel with F, after E)

Once the iOS spike works, the existing 4.0 app architecture (collect → decode → store → sync) is mostly a re-skin:

| # | Step | Output |
|---|------|--------|
| 25 | `Collector` / `Backfiller` for 5.0 | Decoded-first invariant preserved |
| 26 | `BLEManager` for 5.0 services/chars | Connect/bond/backfill driver |
| 27 | `LiveViewModel` / UI | TodayView reads from MetricsRepository |
| 28 | Server schema migration | New `device_generation` column; reuse analysis pipeline |

---

## Scalability Considerations

Discovery doesn't scale by users, but the *cost of unknowns* grows with packet diversity. Treat these as the relevant scaling axes:

| Concern | At 1 packet type | At 10 packet types | At all packet types |
|---------|------------------|--------------------|--------------------|
| **Schema readability** | Hand-edit JSON | JSON Schema validator + lint | Generated docs from schema |
| **Coverage tracking** | Print statement | `verify_protocol.py` report | CI gate: coverage must not regress |
| **Golden fixtures** | 1 file | ~10 files per packet kind | Curated set + property tests |
| **Decoder iteration** | Try in REPL | Re-run analyze script | Replay all goldens, check diff |
| **Cross-source validation** | Manually eyeball | Diff iOS vs Android captures | Automated cross-source replay |

The 4.0 codebase has hit the right-hand column for envelope + commands + HR/RR + historical V24, and the middle column for IMU + optical. 5.0 starts in the left column.

---

## What "Successful Wearable RE Projects" Did (cross-reference)

A few patterns observable in mature wearable RE projects (Gadgetbridge for many devices, whoomp for WHOOP 4.0, openwhoop, bWanShiTong):

| Project | Architectural choice | Lesson for 5.0 |
|---------|---------------------|----------------|
| **Gadgetbridge** | `DeviceCoordinator` + `DeviceSupport` separation; standard profiles before custom; init handshake explicit | Mirrors the proposed phase order (GATT survey → framing → commands → streams) |
| **whoomp** | Started with firmware extraction, then Python packet parsing, then web UI last | Validates: protocol code before product code |
| **openwhoop** | Inherits `whoomp` packet definitions; layers app on top | Confirms: schema/parser is the asset; UI is replaceable |
| **bWanShiTong** | Deep traffic analysis without product code | Cautionary: shipped no app despite deepest reverse engineering — shows risk of staying in discovery forever. **Have an exit criterion to Phase E.** |
| **tazjin (Gadgetbridge #5731)** | WHOOP 5.0 IMU partial decode, code unpublished | Confirms there's prior art to cross-reference; check that issue regularly during 5.0 work |

The takeaway: every project that shipped used a **schema-or-equivalent contract** between RE and product. Every project that didn't ship either skipped that contract or kept the RE loop open indefinitely.

---

## Sources

- `C:\Users\z004shhs\Documents\Scripts\personal\my-whoop\.planning\codebase\ARCHITECTURE.md` — 4.0 product architecture (the destination)
- `C:\Users\z004shhs\Documents\Scripts\personal\my-whoop\FINDINGS.md` — 4.0 RE history (the playbook that worked)
- `C:\Users\z004shhs\Documents\Scripts\personal\my-whoop\protocol\whoop_protocol.json` — 4.0 schema (the artifact pattern to replicate)
- `C:\Users\z004shhs\Documents\Scripts\personal\my-whoop\re\re_harness.py` — proven harness pattern
- `C:\Users\z004shhs\Documents\Scripts\personal\my-whoop\re\README.md` — RE toolchain context
- [Gadgetbridge New Device Tutorial](https://codeberg.org/Freeyourgadget/Gadgetbridge/wiki/New-Device-Tutorial) — community standard for BLE wearable integration order (HIGH)
- [Gadgetbridge BT Protocol Reverse Engineering wiki](https://codeberg.org/Freeyourgadget/Gadgetbridge/wiki/BT-Protocol-Reverse-Engineering) — HCI snoop log + Wireshark + repeatable command isolation (HIGH)
- [Gadgetbridge #5731 (tazjin, WHOOP 5.0)](https://codeberg.org/Freeyourgadget/Gadgetbridge/issues/5731) — confirmed prior art for 5.0 IMU (MEDIUM, code unpublished)
- [jogolden/whoomp](https://github.com/jogolden/whoomp) — sequence: firmware extract → Python packet → web app (HIGH for sequence; HIGH for `WhoopPacket` framing)
- [Apple Developer Bluetooth (PacketLogger)](https://developer.apple.com/bluetooth/) — capture tooling confirmation (HIGH)

**Confidence calls:**
- **HIGH** for the discovery loop, schema-as-contract pattern, and capture/probe/validate cadence — all directly evidenced in the 4.0 codebase and Gadgetbridge wiki.
- **HIGH** for "build Python harness first, port to Swift after schema is stable" — explicitly the path the 4.0 fork took, and the only path that uses the dev velocity advantage of Python during the byte-level work.
- **MEDIUM** for the exact phase week estimates — these are informed by 4.0's elapsed timeline (visible in FINDINGS commit/update dates) but every protocol is different. Use as relative ordering, not calendar planning.
- **LOW** for any specific claim about *how different* 5.0 framing will be from 4.0 — that's the discovery loop's job to answer; the architecture above is structured to be neutral to that outcome.
