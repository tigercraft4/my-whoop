# Phase 4: Protocol Decode & Schema - Research

**Researched:** 2026-05-30
**Domain:** WHOOP 5.0 (Maverick) BLE protocol reverse-engineering — body decode, biometric streams, schema authoring
**Confidence:** HIGH (body layout empirically cracked during this research; streams MEDIUM/HYPOTHESIS pending live capture)

> NOTE (language): per `~/CLAUDE.md` the user speaks pt-PT, but this document is a technical
> protocol-RE artifact consumed by the planner agent. Kept in English for byte-offset/code
> precision and consistency with `FINDINGS_5.md` / `FINDINGS.md`. The conversational summary to
> the user is in pt-PT.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Body Field Layout (D-01 to D-03)**
- **D-01:** Hipótese 4.0 first, validate empirically. Assume `body[1:]` (after stripping the Maverick wrapper's role byte at body[0]) follows the 4.0 inner layout `[type 1B][seq 1B][cmd 1B][payload...][CRC32-LE 4B]`. Validate against the 46 frames in `frames_5_golden.json` as the first decode step. If it passes (even on a majority), hypothesis confirmed. If it fails, fall back to bottom-up empirical derivation.
- **D-02:** `re/survey_5/decode_5.py` — isolation pattern. All 5.0 decode scripts stay in `re/survey_5/`. `decode_5.py` imports `strip_maverick()` from `validate_frames_5.py` and adapts `parse_frame()` from `re/decode.py`. Does NOT import 4.0 `WhoopPacket`.
- **D-03:** CRC32 body failure → log-and-continue. Frames with invalid body CRC32 are logged (hex + characteristic source) but do not abort the decode loop.

**Corpus Expansion (D-04 to D-05)**
- **D-04:** Expand to full ~5028-frame corpus first. Existing pklg captures contain 4714 data, 158 cmd-resp, 155 cmd-in, 1 events; `frames_5_golden.json` only extracted 46. Wave 1/2 expands tshark extraction to the full corpus, classified by characteristic and stream type.
- **D-05:** Targeted capture session in Wave 1. One PacketLogger capture (iPhone + strap worn) triggering: 5-10 min realtime HR/RR streaming, sleep review (historical backfill), workout history, events tab. New capture in `re/capture/samples/` (gitignored) with evidence sidecar in `re/capture/evidence/`.

**Command Surface Strategy (D-06 to D-07)**
- **D-06:** Capture analysis + r52 enum maps — no live probe. macOS Bleak cannot bond. PROTO-06 fulfilled by: (a) extracting all command IDs observed in iOS pklg via tshark + `decode_5.py`, (b) cross-referencing whoop-vault r52 enum maps for the full expected surface, (c) documenting observed vs. expected.
- **D-07:** Unobserved commands → HYPOTHESIS with r52 attribution. Commands in r52 maps not observed in any capture are added to the schema as `"confidence": "HYPOTHESIS"` with `"note": "not observed in captures, expected from r52 enum map"`.

**Ground-Truth Validation (D-08 to D-09)**
- **D-08:** SpO₂ and skin temp — validate against the official WHOOP app display. No independent oximeter/thermometer available. Capture the decoded stream value at the moment the WHOOP app shows the metric. Within ±2% SpO₂ / ±0.5°C of app display = VERIFIED. HR/RR validated against HR strap (hardware available).
- **D-09:** PROTO-10 kill-process test → deferred to Phase 5. The historical offload protocol is DOCUMENTED in Phase 4 from captures (identify ACK command, data range command, frame sequence). The live kill-process test requires Swift CoreBluetooth on iPhone — Phase 5 scope.

### Claude's Discretion
- Exact tshark command to extract all frames into the expanded corpus
- Internal format of expanded `frames_5_golden.json` (add `"stream_type"` field)
- Whether `decode_5.py` exposes a CLI or is pure library (library fine)
- How to structure the `FINDINGS_5.md §Phase 4` extension (follow §Phase 3 pattern: subsections per stream type)
- How `scripts/sync-schema-5.sh` is implemented (cp + validation or proper sync)
- Cross-source golden fixture format (reuse Phase 3 sidecar pattern: redacted hex + SHA256 + YAML)

### Deferred Ideas (OUT OF SCOPE)
- Live command probe 0–255 via re_harness-style harness (not possible from macOS without bond) — Phase 5 with Swift CoreBluetooth, or accept capture-analysis as the surface documentation.
- Kill-process store-then-ack test (PROTO-10 live test) — Phase 5.
- Android btsnoop cross-source fixtures — not attempted in Phase 4; stretch goal only.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROTO-06 | Command surface probed (IDs 0–255; known 4.0 commands cross-checked) | D-06: capture-analysis path. `decode_5.py` reads `body[6]` = cmd byte against r52 `CommandNumber`. Observed in corpus so far: 34 GET_DATA_RANGE, 117/118 (FF/research config), 110 TOGGLE? — see Command Surface section. Cross-validate the 14 listed reused IDs. |
| PROTO-07 | Live HR + RR intervals decoded from realtime stream | Two paths: (a) standard HR `0x2A37` via `re/standard_ble.py:parse_hr()` (works unbonded, already CONFIRMED Phase 2); (b) custom REALTIME_DATA (4.0 type 40) on `data` char — decode `body[7:]` HR-header. Validate against HR strap (D-08). |
| PROTO-08 | Battery level decoded | Standard `0x2A19` (CONFIRMED, 23%). Custom: BATTERY_LEVEL event (3) + GET_BATTERY_LEVEL cmd (26) u16÷10. |
| PROTO-09 | Events decoded (IDs 3, 7, 8, 9, 10, 17, 24, 33, 46, 63) | EVENT body[4]=48 confirmed in corpus (STRAP_CONDITION_REPORT event 29 decoded). Event num at body[6]; device-epoch u32 at body[8]. r52 `EventNumber` map applies. |
| PROTO-10 | Historical data offload with store-then-ack discipline | DOCUMENTED only (D-09). Corpus already contains the full CONSOLE_LOGS narration of a live offload (`SEND_HISTORICAL_DATA` cmd 22, "hist transfer start response ack", "History burst success. Trim: 0x00000004:..."). Decode the METADATA HISTORY_START/END + the trim cursor. Live test = Phase 5. |
| PROTO-11 | SpO₂ decoded (type 53 byte 10) | HYPOTHESIS. Requires the D-05 targeted overnight/sleep-review capture. Validate vs app display (D-08). NOTE: 4.0 FINDINGS says SpO₂ is NOT on the 4.0 wire (cloud-computed) — 5.0 may differ; treat as open. |
| PROTO-12 | Skin temperature decoded (event 17, LE-int / 100000 → °C) | HYPOTHESIS. TEMPERATURE_LEVEL event 17 not yet in corpus. Needs D-05 capture. Validate vs app display. 4.0 never captured this event either. |
| PROTO-13 | Respiration rate decoded | HYPOTHESIS. Likely a derived/sleep metric, may be cloud-only like 4.0. Needs D-05 capture; flag as open. |
| PROTO-14 | IMU / gravity (6-axis) decoded; sample rate confirmed | Adapt 4.0 REALTIME_RAW_DATA type 43 layout (FINDINGS.md §9b: 100 samples/axis int16-LE, accel @ body-offset, gyro). Needs raw-data stream in a capture (START_RAW_DATA cmd 81). tazjin confirms 5.0 IMU = "6 integers X/Y/Z per sensor". |
| PROTO-15 | Dual-epoch timestamp model (device epoch vs Unix) | CONFIRMED present in corpus: GET_DATA_RANGE payload carries real Unix u32 (2026-05-30 decoded); EVENT body carries device-epoch u32 (`0x6a1afcc2`). Schema `"epoch"` tag per field. |
| PROTO-16 | Firmware version recorded in every capture session metadata | Already in schema (`WG50_r52`). Add `firmware_revision` to every evidence sidecar (read Device Info `0x2A26` Firmware Revision + `0x2A27` Hardware Revision). |
| SCHEMA-01 | `protocol/whoop_protocol_5.json` canonical, schema-driven | Populate `enums` (PacketType/EventNumber/CommandNumber/MetadataType from r52) + `packets` (body field maps at offset 4+). v0 envelope already correct. |
| SCHEMA-02 | All fields: `"epoch"` tag + provenance + confidence | Follow 4.0 schema field shape; add `"epoch"`, `"note"` (provenance), `"confidence"` to every field. |
| SCHEMA-03 | `FINDINGS_5.md` protocol reference | Extend with §Phase 4: command surface, decoded streams, timestamps, historical offload. |
| SCHEMA-04 | Golden fixtures per decoded packet type (cross-source) | Expand `frames_5_golden.json` + per-type fixtures. iOS pklg primary; Android btsnoop deferred (D). |
| SCHEMA-05 | `scripts/sync-schema-5.sh` syncs schema to Swift bundle | Mirror existing `scripts/sync-schema.sh` (4.0). Target `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json`. |
</phase_requirements>

## Summary

The single most important question for Phase 4 — **does the wrapper-stripped flat body reuse the
4.0 `[type][seq][cmd]` field layout?** — is now **answered empirically during this research, with
HIGH confidence**, against all 46 golden frames. The answer refines D-01: **the 4.0 inner layout
IS reused, but at body offset 4, not body offset 1.** The body is:

```
body[0]        role            0x00 = cmd-in write, 0x01 = notify   (== Maverick role)
body[1:4]      session token   3 bytes; per-(session,packet-family) constant, NOT a length
body[4]        packet_type     == 4.0 r52 PacketType  (36 COMMAND_RESPONSE, 48 EVENT, 49 METADATA, 50 CONSOLE_LOGS, ...)
body[5]        seq             monotonic per-stream sequence counter
body[6]        cmd / sub-type  == 4.0 r52 CommandNumber (resp) / EventNumber (event) / MetadataType (meta)
body[7:]       payload         stream-specific, identical semantics to 4.0
(no inner CRC32 — the 4-byte trailer is the Maverick outer trailer; body has no separate CRC)
```

This was proven by decoding the corpus: `body[4]=36 → COMMAND_RESPONSE` with `body[6]=34 →
GET_DATA_RANGE` whose `body[7:]` payload decodes to **real Unix timestamps for 2026-05-30**
(the capture date); `body[4]=48 → EVENT` with `body[6]=29 → STRAP_CONDITION_REPORT` and a
device-epoch u32 at body[8]; `body[4]=49 → METADATA` with `body[6]=1 → HISTORY_START`; and 13
`body[4]=50 → CONSOLE_LOGS` frames carrying the **full ASCII narration of a live historical
offload** ("Command Send Historical Data 18, 1400674179", "hist transfer start response ack",
"History burst success. Trim: 0x00000004:000130ef"). Every PacketType, EventNumber, CommandNumber,
and MetadataType decoded **matches the r52 enum maps verbatim**. The `WG50_r52` revision guarantee
holds.

This converts Phase 4 from "derive the protocol" to "confirm and complete the schema". The fastest
gate (D-01 / the Specific Idea) — run `strip_maverick()` + a body parser keyed at offset 4 on the
46 golden frames — will pass immediately. Most subsequent work is breadth (enumerate all
PacketTypes/commands across the full 5028-frame corpus) and the biometric streams that need a
**fresh targeted capture (D-05)** because the existing two captures lack realtime HR streaming,
raw IMU, SpO₂/temp, and a sleep-review backfill of biometric (non-console-log) historical packets.

**Primary recommendation:** Build `decode_5.py` with the **body-offset-4** layout (NOT offset 1 —
correct D-01's literal wording). Wave 1: confirm body layout on golden corpus + run the D-05
targeted capture. Wave 2: full-corpus extraction + command-surface enumeration + event/metadata/
historical decode (all present in current captures). Wave 3: biometric streams from the new D-05
capture (HR/RR, IMU, SpO₂/temp HYPOTHESIS) + complete schema + fixtures + `sync-schema-5.sh`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Frame wrapper strip | RE / Python (`re/survey_5/`) | Swift (Phase 5) | `strip_maverick()` already exists; Phase 4 is Python-only analysis |
| Body field decode | RE / Python (`decode_5.py`) | Canonical schema JSON | decode_5.py is the reference impl; schema is the cross-language contract |
| Stream classification | RE / Python | Corpus JSON | `body[4]` PacketType drives `stream_type` tagging in expanded corpus |
| Command-surface enumeration | RE / Python (capture analysis) | r52 enum map (external) | macOS cannot live-probe; observed-vs-expected reconciliation |
| Ground-truth validation | Physical (strap, app display) | RE / Python | D-08: human-in-the-loop capture alignment |
| Canonical protocol contract | Schema JSON (`whoop_protocol_5.json`) | Swift + Python loaders (Phase 5) | single source of truth, synced by `sync-schema-5.sh` |
| Schema → Swift bundle sync | Build script (`sync-schema-5.sh`) | — | mirrors 4.0 `sync-schema.sh` |

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tshark (Wireshark) | 4.6.6 | Extract ATT values from `.pklg` | [VERIFIED: `tshark --version` → 4.6.6 installed]; the established Phase 1-3 extraction tool |
| Python | 3.x (`re/survey_5/.venv`) | All decode/analysis scripts | [VERIFIED: `re/survey_5/.venv/bin/python` exists]; project convention |
| `struct` (stdlib) | — | LE/BE int unpacking | [VERIFIED] used throughout `decode.py`/`validate_frames_5.py` |
| `zlib` (stdlib) | — | CRC32 (4.0 gate only; body has none) | [VERIFIED] used in `decode.py` — but NOTE: body has no inner CRC32, do not apply to body |
| `json` (stdlib) | — | corpus + schema I/O | [VERIFIED] |

### Supporting
| Asset | Purpose | When to Use |
|-------|---------|-------------|
| `re/survey_5/validate_frames_5.py:strip_maverick()` | bytes→bytes wrapper strip | Import directly in `decode_5.py` (D-02). Entry point for every frame. |
| `re/decode.py:parse_frame()` | 4.0 type/seq/cmd parser | ADAPT (not import) — shift offsets from 1/2/3 to 4/5/6 for 5.0 body |
| `re/standard_ble.py:parse_hr()` | standard HR + RR decode | Reuse verbatim for HR-strap ground-truth (D-08, PROTO-07) |
| `re/survey_5/hr_5.py` | standard HR streaming via Bleak (unbonded) | Run during D-05 ground-truth capture to log HR alongside app display |
| `scripts/sync-schema.sh` | 4.0 schema sync template | Copy → `scripts/sync-schema-5.sh` (SCHEMA-05) |
| r52 enum maps (in `protocol/whoop_protocol.json` `enums`) | PacketType/Event/Command/Metadata IDs | Copy verbatim into `whoop_protocol_5.json enums`; they are confirmed applicable (WG50_r52) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tshark CLI extraction | pyshark / scapy | Adds a heavy dependency; tshark is already the verified, committed pipeline. Don't switch. |
| Adapting `parse_frame()` | Importing 4.0 `WhoopPacket` | FORBIDDEN by D-02 — WhoopPacket assumes 4.0 framing (offset 1) and would mis-parse. |
| Live Bleak command probe | — | Not possible on macOS (no bond, Phase 2/3 confirmed). Capture analysis is the only path (D-06). |

**Installation:** No new packages required. Existing `re/survey_5/.venv` + system tshark suffice.

**Version verification:** [VERIFIED: `tshark --version` → "TShark (Wireshark) 4.6.6"]. No
external package installs in this phase → Package Legitimacy Audit is N/A (see below).

## Package Legitimacy Audit

**N/A — this phase installs no external packages.** All tooling is the Python standard library
(`struct`, `zlib`, `json`, `subprocess`, `pathlib`) plus the already-installed system `tshark`
(Wireshark 4.6.6, Homebrew). The existing `re/survey_5/.venv` (bleak, used only for the optional
HR-monitoring helper during the D-05 capture) is unchanged from Phase 2-3. No npm/PyPI/crates
package is added, so slopcheck does not apply.

If a planner later decides to add a Python dependency (e.g. `crcmod` for further trailer-checksum
exploration), gate it behind a `checkpoint:human-verify` task and run the Package Legitimacy Gate
first. The trailer checksum is explicitly OPEN/non-blocking (D / Specific Ideas) so no such
dependency should be needed in Phase 4.

## Architecture Patterns

### System Architecture Diagram

```
                         ┌─────────────────────────────────────────────────────┐
   .pklg captures        │                  decode_5.py (library)               │
  (gitignored, local)    │                                                       │
        │                │   strip_maverick(frame)  ──►  flat body bytes        │
        ▼                │            │                                          │
  ┌──────────────┐       │            ▼                                          │
  │   tshark     │       │   parse_body_5(body):                                │
  │ -Y btatt.    │──hex──►│     role  = body[0]                                  │
  │  value       │ frames │     token = body[1:4]     (session token)           │
  │ -e handle    │       │     ptype = body[4]  ──►  r52 PacketType enum        │
  │ -e value     │       │     seq   = body[5]                                   │
  └──────────────┘       │     cmd   = body[6]  ──►  r52 Command/Event/Meta     │
        │                │     payload = body[7:]                                │
   (filter aa-SOF,       │            │                                          │
    4 custom handles)    │            ▼                                          │
                         │   ┌─────────── dispatch by ptype ───────────┐        │
                         │   │ 36 COMMAND_RESPONSE → cmd payload decode │        │
                         │   │ 48 EVENT            → event payload      │        │
                         │   │ 49 METADATA         → HISTORY_START/END  │        │
                         │   │ 40 REALTIME_DATA    → HR/RR header       │        │
                         │   │ 43 REALTIME_RAW     → IMU 6-axis (D-05)  │        │
                         │   │ 50 CONSOLE_LOGS     → ASCII (offload log)│        │
                         │   └──────────────────────────────────────────┘       │
                         └────────────────┬─────────────────────┬──────────────┘
                                          ▼                     ▼
                          frames_5_golden.json        protocol/whoop_protocol_5.json
                          (+ stream_type tag)          (enums + packets, confidence-tagged)
                                                                │
                                            scripts/sync-schema-5.sh
                                                                ▼
                              Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/
                                            whoop_protocol_5.json   (Phase 5 consumer)

   Ground-truth (D-08):  iPhone WHOOP app display  ◄── screen-record ──┐
                         HR strap                   ◄── hr_5.py log ───┤ align by timestamp
                         (NO independent SpO₂/temp sensor — app display is the reference)
```

The diagram traces the primary use case: a raw `.pklg` capture flows through tshark → `decode_5.py`
(strip wrapper → parse body at offset 4 → dispatch by PacketType) → two outputs (expanded corpus +
canonical schema) → synced to the Swift bundle for Phase 5.

### Component Responsibilities

| File | Responsibility |
|------|----------------|
| `re/survey_5/decode_5.py` | NEW. `strip_maverick()` (imported) + `parse_body_5()` (body offset-4 layout) + per-PacketType payload decoders. Library, no CLI required (D). |
| `re/survey_5/validate_frames_5.py` | EXISTING. Provides `strip_maverick()`, `parse_maverick()`, `extract_frames()`, full-corpus extraction. Phase 4 may extend `extract_frames()` to drop the 15-per-handle cap for the full corpus, or `decode_5.py` calls it. |
| `re/survey_5/frames_5_golden.json` | EXPAND. Add `stream_type` field; cover all observed PacketTypes; keep curated (do not commit all 5028 — see Pitfall: committed-bytes). |
| `protocol/whoop_protocol_5.json` | COMPLETE. Populate `enums` (copy r52) + `packets` (body field maps). |
| `FINDINGS_5.md` | EXTEND §Phase 4 (per-stream subsections, mirror §Phase 3). |
| `scripts/sync-schema-5.sh` | NEW. Mirror `scripts/sync-schema.sh`. |

### Pattern 1: Body parse at offset 4 (the corrected D-01)
**What:** The 4.0 `[type][seq][cmd][payload]` triple lives at `body[4:7]`, preceded by `role`(1) +
`session token`(3). There is **no inner CRC32** on the body (4.0 had one; 5.0's checksum is the
Maverick outer trailer, which is OPEN/non-blocking).
**When to use:** Every notify-role frame (`role==1`). cmd-in writes (`role==0`) have a different
short layout — see Pattern 2.
**Example:**
```python
# Source: empirically derived this research (HIGH confidence, 46/46 golden frames)
def parse_body_5(body: bytes) -> dict:
    role  = body[0]                 # 0x00 cmd-in / 0x01 notify
    token = body[1:4]               # 3-byte session token (per family constant)
    ptype = body[4]                 # r52 PacketType: 36 CMD_RESP, 48 EVENT, 49 META, 50 LOGS, 40 RT, 43 RAW
    seq   = body[5]                 # monotonic sequence
    cmd   = body[6]                 # r52 CommandNumber / EventNumber / MetadataType (context = ptype)
    payload = body[7:]
    return {"role": role, "token": token.hex(), "type": ptype,
            "seq": seq, "cmd": cmd, "payload": payload}
# Verified: ptype 36 + cmd 34 → GET_DATA_RANGE, payload decodes to 2026-05-30 unix timestamps.
#           ptype 48 + cmd 29 → STRAP_CONDITION_REPORT, device-epoch u32 at body[8].
#           ptype 49 + cmd 1  → HISTORY_START.   ptype 50 → CONSOLE_LOGS (offload narration).
```

### Pattern 2: cmd-in write frames (role 0)
**What:** Writes the app sends to the strap. Body is short (8 bytes in corpus): `00 01 <token3>
<cmd> <args>`. Example `0001 e67123 94 2200` — these are the app's outgoing commands. The cmd
byte here is the request that the corresponding `COMMAND_RESPONSE` (type 36) answers. Use these
to enumerate the **request** side of the command surface (PROTO-06).
**When to use:** `role==0` frames on `FD4B0002` (cmd-in). Pair with the matching cmd-resp by seq.

### Pattern 3: Historical offload decode (documentation-only, D-09)
**What:** The corpus already contains a complete offload session as CONSOLE_LOGS (type 50) +
METADATA (type 49) HISTORY_START. The narration reveals the protocol:
`SEND_HISTORICAL_DATA(22)` → strap streams bursts → "hist transfer start response ack" →
"History burst success. Trim: 0x00000004:000130ef" (the trim cursor = the store-then-ack pointer).
**When to use:** Document the ACK command (`HISTORICAL_DATA_RESULT`, cmd 23 in r52), the data-range
command (`GET_DATA_RANGE` 34 / `SET_READ_POINTER` 33), and the trim-cursor format in
`FINDINGS_5.md §Phase 4`. The **live kill-process test is Phase 5** (D-09).

### Anti-Patterns to Avoid
- **Parsing body at offset 1 (the literal D-01 wording):** WRONG. `body[1]` is the first session-
  token byte, not PacketType. body[1] decodes to 0x00/0x01 nonsense. Use offset 4. This research
  corrects the CONTEXT.md hypothesis empirically.
- **Re-running the 4.0 CRC32 gate on the stripped body:** FORBIDDEN (Finding 5, validate_frames_5
  docstring). The body has no inner CRC32; the trailer is the Maverick outer checksum (OPEN).
- **Importing 4.0 `WhoopPacket` / `whoomp`:** FORBIDDEN (D-02). Assumes offset-1 layout.
- **Committing all 5028 frames to `frames_5_golden.json`:** the golden corpus is a CURATED fixture
  (Pitfall: committed bytes). Tag with `stream_type`, keep one+ exemplar per PacketType/command,
  cap the bulk data frames.
- **Treating SpO₂/temp/respiration as guaranteed on-wire:** on 4.0 these were cloud-computed and
  NOT on the BLE stream (FINDINGS.md §6/§9b). 5.0 *may* differ (PROTO-11 cites type 53 byte 10),
  but treat as HYPOTHESIS until a D-05 capture proves the bytes exist. Do not fabricate offsets.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Wrapper strip | new parser | `strip_maverick()` (Phase 3) | Verified on 5028/5028 frames; importing avoids drift |
| ATT extraction | pcap parser | tshark `-Y btatt.value -T fields` | Established, verified pipeline; handles `.pklg` natively |
| Enum IDs | re-derive command/event names | r52 maps in `whoop_protocol.json enums` | WG50_r52 confirmed identical; re-derivation wastes effort and risks errors |
| Standard HR/RR | custom 0x2A37 parser | `re/standard_ble.py:parse_hr()` | Already validated live (71/72 bpm); BLE-standard format |
| Schema → bundle sync | bespoke copy logic | mirror `scripts/sync-schema.sh` | Existing, tested pattern; consistent with 4.0 |
| Unix↔device-epoch correlation | guess | 4.0 model: GET_CLOCK device-epoch + wall-clock-at-capture; stored records carry absolute Unix | Documented in FINDINGS.md §9b; corpus confirms Unix in GET_DATA_RANGE |

**Key insight:** Because `WG50_r52` is byte-for-byte the revision behind the 4.0 enum maps, Phase 4
is overwhelmingly a **confirmation-and-completion** exercise, not a fresh derivation. The risk is
not "can we decode it" but "do the existing captures contain every stream" — they don't (no
realtime HR streaming, no raw IMU, no SpO₂/temp), which is exactly what D-05 addresses.

## Runtime State Inventory

> This is a decode/schema/analysis phase, not a rename or migration. Most categories are N/A, but
> two are load-bearing for plan correctness.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | The two existing `.pklg` captures hold the only command/event/console-log/historical-narration corpus. They lack: realtime HR streaming (type 40), raw IMU/PPG (type 43), SpO₂/temp/respiration biometrics, and biometric (non-console) historical packets. | D-05 targeted capture is REQUIRED before PROTO-07/11/12/13/14 can be VERIFIED. Plan a human capture task early (Wave 1). |
| Live service config | None — no external service holds protocol state. | None. |
| OS-registered state | iOS PacketLogger mobileconfig + Bluetooth logging profile (TOOL-01) must be active for the D-05 capture. | Verify before D-05 capture session (`re/capture/ios-packetlogger.md`). |
| Secrets/env vars | `re/survey_5/device_local_5.py` holds device UUID (gitignored); SMP keys must be scrubbed from any committed `.hex` (DISCLAIMER §2). | Keep gitignored; scrub before committing evidence. |
| Build artifacts | `Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json` does **not yet exist** (only the 4.0 `whoop_protocol.json` is there). `sync-schema-5.sh` creates it. | `sync-schema-5.sh` must `mkdir -p` the Resources dir (it exists for 4.0) and copy the 5.0 schema. Phase 5 Swift package additions reference it. |

**Nothing found in category "Live service config":** None — verified; this is local file + capture analysis only, no servers or external state stores involved in Phase 4.

## Common Pitfalls

### Pitfall 1: Parsing the body at offset 1 (literal D-01)
**What goes wrong:** D-01 literally says `body[1:]` follows `[type][seq][cmd]`. Decoding `body[1]`
as PacketType yields 0x00/0x01 — meaningless. All downstream decode fails or produces garbage.
**Why it happens:** The Maverick body prepends `role`(body[0]) + a 3-byte session token (body[1:4])
before the 4.0 triple. The 4.0 doc's offsets are relative to a frame that had no such token.
**How to avoid:** Parse at `body[4]` (PacketType), `body[5]` (seq), `body[6]` (cmd), `body[7:]`
(payload). This research proved it on 46/46 golden frames.
**Warning signs:** PacketType byte not in {35,36,40,43,47,48,49,50,51,52,53}; cmd byte not in the
r52 CommandNumber/EventNumber maps.

### Pitfall 2: Expecting an inner CRC32 on the body
**What goes wrong:** Adapting `parse_frame()` directly carries its `crc32_ok` check; on the 5.0 body
it always fails and (without D-03) could abort the loop.
**Why it happens:** 4.0 had `[...payload][CRC32-LE]`; 5.0 moved the checksum to the Maverick outer
trailer (which is OPEN). The body is uncrc'd payload.
**How to avoid:** Drop the body-CRC check. Apply D-03 (log-and-continue) only for genuinely
malformed/short bodies, not for "CRC mismatch" (there is no body CRC to mismatch).
**Warning signs:** 100% body-CRC failure rate (you're checking a checksum that isn't there).

### Pitfall 3: Missing biometric streams in the existing corpus
**What goes wrong:** Planner schedules PROTO-07/11/12/13/14 decode against the two existing captures
and finds no realtime HR / IMU / SpO₂ / temp frames → those requirements stall at HYPOTHESIS.
**Why it happens:** The existing captures were bonding/command sessions, not biometric-streaming
sessions. The 4714 data frames are dominated by CONSOLE_LOGS and historical-offload narration, not
sensor streams.
**How to avoid:** Run the D-05 targeted capture (5-10 min realtime HR/RR + sleep review + workout
history + events tab) BEFORE the biometric-decode wave. Sequence it in Wave 1.
**Warning signs:** No type-40 (REALTIME_DATA) or type-43 (REALTIME_RAW_DATA) frames after full-
corpus extraction.

### Pitfall 4: Over-committing protocol bytes / evidence policy
**What goes wrong:** Committing all 5028 frames or raw `.pklg`, or leaking BD_ADDR / SMP keys /
serial in committed hex.
**Why it happens:** Convenience; forgetting DISCLAIMER §2 + evidence policy.
**How to avoid:** Keep `frames_5_golden.json` curated (exemplars per type). Raw `.pklg` stays
gitignored. Committed evidence = redacted hex + SHA256 + YAML sidecar only. Scrub identifiers.
**Warning signs:** `git status` shows `samples/` staged; hex contains `xx:xx:xx:xx:xx:xx` MAC or a
serial string.

### Pitfall 5: Treating SpO₂/temp/respiration as confirmed-on-wire
**What goes wrong:** Inventing byte offsets for SpO₂/temp/respiration to "complete" the schema.
**Why it happens:** PROTO-11/12/13 imply they exist; 4.0 prior art says they were **cloud-computed,
not on the BLE wire** (FINDINGS.md §6/§9b: "SpO2/skin-temp computed VALUES: NOT in the BLE stream").
**How to avoid:** Capture first (D-05 overnight/sleep-review), then decode only what's observed.
If absent, tag the schema field HYPOTHESIS with `note: "not observed; 4.0 precedent = cloud-computed"`
and flag honestly. PROTO-11 cites "type 53 byte 10 per Sivasai2207" — verify against the capture,
do not assume.
**Warning signs:** A VERIFIED SpO₂/temp field with no corresponding captured frame in the corpus.

## Code Examples

### Full-corpus extraction (the exact tshark command — answers research Q1)
```bash
# Source: re/capture/wireshark.md + verified this research (yields 5028 aa-frames total).
# Per-characteristic counts confirmed: data(0x09a3)=4714, cmd-resp(0x099d)=158,
#   cmd-in(0x099b)=155, events(0x09a0)=1.
for f in "re/capture/samples/whoop- iPhone de Francisco.pklg" \
         "re/capture/samples/2026-05-30-smp-bond-full.pklg"; do
  tshark -r "$f" -Y "btatt.value" -T fields -e btatt.handle -e btatt.value
done
# In Python (decode_5.py reuses validate_frames_5.extract_frames(), which already runs exactly
# this command; to get the FULL corpus instead of the curated 46, raise/remove GOLDEN_PER_HANDLE_CAP
# or call build_report() and consume `records` rather than `golden`).
```
Note: the Phase 1 file name **contains a space** — `whoop- iPhone de Francisco.pklg` — and is the
real on-disk name (the CONTEXT.md `-ios` suffix name does NOT exist). `validate_frames_5.py`
already hardcodes the correct names in `DEFAULT_CAPTURES`.

### Decode a COMMAND_RESPONSE and read GET_DATA_RANGE timestamps (PROTO-15 dual-epoch)
```python
# Source: empirically verified this research (HIGH confidence).
import struct, datetime
from validate_frames_5 import strip_maverick   # D-02 import

frame = bytes.fromhex("aa014c00010032d124...")  # a cmd-resp frame from the corpus
body  = strip_maverick(frame)
ptype, seq, cmd, payload = body[4], body[5], body[6], body[7:]
assert ptype == 36 and cmd == 34   # COMMAND_RESPONSE / GET_DATA_RANGE
# real Unix u32-LE timestamps appear in the payload (the stored-history window):
for i in range(len(payload) - 4):
    v = struct.unpack_from("<I", payload, i)[0]
    if 1_400_000_000 < v < 1_900_000_000:
        print(i, v, datetime.datetime.utcfromtimestamp(v))   # decoded 2026-05-30 in corpus
```

### Decode an EVENT (device-epoch timestamp) — PROTO-09 / PROTO-15
```python
# Source: empirically verified this research.
body = strip_maverick(frame)            # events char FD4B0004 or data char
assert body[4] == 48                    # EVENT
event_num = body[6]                      # r52 EventNumber (e.g. 29 STRAP_CONDITION_REPORT)
device_epoch = struct.unpack_from("<I", body, 8)[0]   # device-epoch u32 (NOT unix) → tag "epoch":"device"
# For battery event (3): u16 SOC×10 + u16 millivolts in payload (4.0 precedent, validate).
```

### `scripts/sync-schema-5.sh` (mirror of 4.0, SCHEMA-05)
```bash
# Source: derived from scripts/sync-schema.sh (4.0). Verify Resources dir exists (it does for 4.0).
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANON="$ROOT/protocol/whoop_protocol_5.json"
PKG="$ROOT/Packages/WhoopProtocol/Sources/WhoopProtocol/Resources/whoop_protocol_5.json"
mkdir -p "$(dirname "$PKG")"
# Optional: validate JSON before copying
python3 -c "import json,sys; json.load(open('$CANON'))" || { echo "invalid JSON"; exit 1; }
cp "$CANON" "$PKG"
echo "synced → $PKG"
```

## State of the Art

| Old Approach (4.0) | Current Approach (5.0) | When Changed | Impact |
|--------------------|------------------------|--------------|--------|
| Inner frame `[0xAA][len][crc8][type][seq][cmd][payload][crc32]` | Maverick outer wrapper `[0xAA][0x01][len][body][trailer]`; body = `[role][token3][type][seq][cmd][payload]` (NO inner crc32) | Phase 3 + this research | body decode keys at offset 4, not 1; trailer checksum OPEN but non-blocking |
| Live Bleak bond + confirmed-write trick | iOS-only; macOS cannot bond → capture-analysis only | Phase 2 | command surface from captures + r52 maps, not live probe |
| 4.0 UUID family `61080001-...` | `FD4B0001-...` (legacy ABSENT on this unit) | Phase 2 | no dual-UUID branch needed |
| SpO₂/temp = cloud-computed, NOT on wire | UNKNOWN for 5.0 (PROTO-11 cites type 53 byte 10) | TBD (needs D-05 capture) | treat as HYPOTHESIS until captured |

**Public state of the art (from FINDINGS.md §7 prior-art, training-knowledge — no new web access this session):**
- whoomp (jogolden): framing, commands, HR/RR, historical — 4.0; never parses raw array. [CITED: FINDINGS.md §7]
- bWanShiTong: deepest 4.0 traffic analysis; failed to locate accelerometer. [CITED: FINDINGS.md §7]
- taz* — IMU = "6 integers (X/Y/Z per sensor)", ~70 commands, code unpublished, no scale factors. [CITED: FINDINGS.md §7 / §9b]
- This project is at/beyond public state of the art for the raw 4.0 sensor array; the 5.0 body
  layout cracked here (offset-4, r52-reuse) is not published anywhere known.

**Deprecated/outdated:**
- christianmeurer/whoop-reader: fabricated UUIDs/commands — DO NOT use (FINDINGS.md §7).
- Any 4.0 `61080001-...` UUID in 5.0 code — wrong family.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SpO₂ is on the 5.0 BLE wire (type 53 byte 10) | PROTO-11 / Pitfall 5 | If cloud-only (4.0 precedent), PROTO-11 cannot reach VERIFIED — must stay HYPOTHESIS. Mitigate: D-05 capture decides. |
| A2 | Skin temp is on the wire as event 17 (LE-int / 100000) | PROTO-12 | Same as A1; 4.0 never captured event 17. Capture-gated. |
| A3 | Respiration rate is on the BLE wire | PROTO-13 | Likely a derived/sleep metric; may be cloud-only. Capture-gated; flag open. |
| A4 | 5.0 IMU layout matches 4.0 (100 samples/axis, int16-LE) at the same relative offsets | PROTO-14 | tazjin confirms "6 integers X/Y/Z" but exact stride/scale for 5.0 unverified. Needs raw-data capture + validation. |
| A5 | The 3-byte `body[1:4]` is a session token (not length/flags) | Pattern 1 | If it encodes a length or routing field, dispatch still works (offset-4 type is stable across all 46 frames) but the field name in schema would be wrong. Low risk; tag `note` as HYPOTHESIS for body[1:4]. |
| A6 | Battery event payload layout (u16 SOC×10 @1, u16 mV @5) carries over from 4.0 | PROTO-08 | Validate against the standard 0x2A19 read (23%) cross-check, as 4.0 did. |
| A7 | The cmd byte at body[6] for cmd-in writes is the request command ID | Pattern 2 / PROTO-06 | Pair-by-seq with cmd-resp to confirm; corpus has few write exemplars. |

**Note:** A1–A4 are the high-risk items — all four biometric streams (SpO₂, temp, respiration, IMU)
are **capture-gated**. The D-05 targeted capture is the single dependency that unblocks them. The
core protocol (framing, body layout, commands, events, metadata, historical narration, dual-epoch)
is VERIFIED and not assumption-dependent.

## Open Questions

1. **Do SpO₂ / skin-temp / respiration appear on the 5.0 BLE wire at all?**
   - What we know: 4.0 computed these in the cloud — NOT on the wire (FINDINGS.md §6/§9b). PROTO-11
     cites a specific offset (type 53 byte 10) from an external source (Sivasai2207).
   - What's unclear: whether 5.0 streams them. Not present in the existing corpus.
   - Recommendation: D-05 overnight/sleep-review capture; decode only if observed; else HYPOTHESIS.

2. **What is the 3-byte `body[1:4]` session token?**
   - What we know: it's constant per (session, packet-family) — e.g. `002cd1` for cmd-resp,
     `0030b1` for console-logs in this session.
   - What's unclear: whether it's a session ID, a routing/length field, or a token tied to the
     trailer checksum (the OPEN trailer may be computed over it — Finding 6 hypothesis).
   - Recommendation: tag as `session_token` HYPOTHESIS in schema; cross-check across the D-05
     session (a different session should show a different token). Non-blocking for decode.

3. **Does the realtime HR custom stream (type 40) exist on 5.0, or only standard 0x2A37?**
   - What we know: standard 0x2A37 works unbonded (CONFIRMED). 4.0 also had custom type-40
     REALTIME_DATA.
   - What's unclear: whether 5.0 emits type-40 on the data char (needs a streaming capture).
   - Recommendation: D-05 capture with realtime HR enabled; if type-40 absent, standard 0x2A37
     satisfies PROTO-07 (RR included).

4. **Trailer checksum algorithm (carried from Phase 3).**
   - What we know: standard CRC16/CRC32 variants ruled out (exhaustive negative). NON-BLOCKING.
   - What's unclear: the algorithm (possibly over the session token / a masked input).
   - Recommendation: record any new evidence in §Phase 4 but do NOT block phase closure (Specific
     Ideas / D). Decode operates on the body, not the trailer.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| tshark (Wireshark) | corpus extraction | ✓ | 4.6.6 | — |
| Python venv (`re/survey_5/.venv`) | decode scripts | ✓ | present | system python3 (stdlib only suffices) |
| Existing `.pklg` captures | Wave 1-2 decode (commands/events/metadata/historical-log) | ✓ | 5028 frames | — |
| iPhone + PacketLogger + worn strap | D-05 targeted capture (biometric streams) | ✗ (human action) | — | **NO fallback** — biometric streams (PROTO-07/11/12/13/14) cannot be VERIFIED without it |
| HR strap (ground truth) | D-08 HR/RR validation | ✓ (user-confirmed available) | — | standard 0x2A37 self-consistency |
| Independent SpO₂/temp sensor | D-08 ground truth | ✗ | — | WHOOP app display comparison (D-08 explicitly accepts this) |
| Swift toolchain | sync-schema-5.sh target dir | ✓ (package exists) | — | dir created by `mkdir -p` in the script |

**Missing dependencies with no fallback:**
- The D-05 targeted capture (human, on-device). This is the gating dependency for all four
  biometric-stream requirements. Plan it as the FIRST executable task (Wave 1) so the rest of the
  phase can proceed in parallel against the existing corpus.

**Missing dependencies with fallback:**
- Independent SpO₂/temp ground truth → WHOOP app display comparison (D-08, accepted).

> **Validation Architecture section omitted:** `.planning/config.json` sets
> `workflow.nyquist_validation: false`. Per the researcher spec, this section is skipped.

## Security Domain

> `security_enforcement` not present in config (treat as enabled). This is a local-only,
> read-only BLE reverse-engineering phase — no auth, sessions, access control, or network surface.
> The relevant controls are data-handling / legal, not application security.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface; BLE bond is out of scope (Phase 5) |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a |
| V5 Input Validation | yes | `decode_5.py` MUST guard `len(body)` before indexing offsets 4/5/6/7+ (the T-02-07 mitigation already applied in `parse_hr`/`strip_maverick`). Malformed/truncated frames → D-03 log-and-continue, never crash. |
| V6 Cryptography | no (hand-roll forbidden anyway) | Do NOT attempt to implement/guess the trailer checksum as a security control — it's a protocol-fact, OPEN, non-blocking. No crypto is authored. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Index-out-of-range on truncated/fragmented BLE body | Denial of Service (crash) | Length guards before every offset access; D-03 log-and-continue |
| Committing PII (BD_ADDR, serial, SMP keys) to git | Information Disclosure | DISCLAIMER §2 evidence policy: redacted hex + SHA256 + YAML only; raw `.pklg` gitignored; scrub identifiers before `git add` |
| Decompiled APK / copyrighted source in repo | Legal / Info Disclosure | DISCLAIMER §2: only uncopyrightable protocol facts (byte layouts, UUIDs) committed; no decompiled source |

## Sources

### Primary (HIGH confidence)
- **Empirical corpus analysis (this research session)** — decoded all 46 frames in
  `re/survey_5/frames_5_golden.json`; proved body-offset-4 layout, r52 enum reuse, Unix+device
  dual-epoch timestamps, historical-offload narration. Reproducible via the Python snippets above.
- `re/survey_5/validate_frames_5.py` — `strip_maverick()`, wrapper structure, full-corpus extraction.
- `protocol/whoop_protocol.json` (4.0) `enums` — r52 PacketType/EventNumber/CommandNumber/MetadataType.
- `protocol/whoop_protocol_5.json` (v0) — confirmed Maverick envelope.
- `FINDINGS_5.md` §7 — Phase 3 framing verdict, wrapper, r52 guarantee.
- `FINDINGS.md` §3/§4/§5/§9b — 4.0 frame format, command surface, stream decoders, IMU layout, offload.
- `.planning/phases/03-.../03-VERIFICATION.md` — confirmed wrapper/body-offset (off:4) facts.
- `re/capture/wireshark.md` — tshark extraction command.
- Tool versions: [VERIFIED] `tshark --version` → 4.6.6; `re/survey_5/.venv/bin/python` present.
- Corpus counts: [VERIFIED] full-corpus tshark run this session → 5028 aa-frames
  (data 4714 / cmd-resp 158 / cmd-in 155 / events 1).

### Secondary (MEDIUM confidence)
- tazjin / Gadgetbridge #5731 (WHOOP 5.0 IMU = "6 integers X/Y/Z per sensor") — [CITED via FINDINGS.md §7/§9b]; code unpublished.
- PROTO-11 external attribution (Sivasai2207, "type 53 byte 10") — [CITED via REQUIREMENTS.md]; unverified against a 5.0 capture.

### Tertiary (LOW confidence) / Not accessed this session
- WebSearch was UNAVAILABLE in this environment (org policy blocked the web_search feature). No new
  external web sources were fetched. All prior-art claims trace to committed `FINDINGS.md` /
  `FINDINGS_5.md` (themselves citing the original repos). New 5.0-specific public RE, if any has
  appeared since those docs, was NOT checked — flag for the planner if external corroboration of
  SpO₂/temp/respiration on-wire is needed.

## Wave Sequencing Recommendation

Phase 3 used 3 waves; Phase 4 naturally splits into **3 waves** (answers research Q8):

- **Wave 1 — Foundation + capture (parallelisable):**
  - 1a: `decode_5.py` with body-offset-4 layout + import `strip_maverick`; run the D-01 gate on the
    46 golden frames (minutes; will pass — already proven here). Establishes the decode primitive.
  - 1b: **D-05 targeted PacketLogger capture** (human task; realtime HR/RR + sleep review + workout
    history + events tab). Gating dependency for Wave 3 biometrics — start it first.
  - 1c: full-corpus extraction (5028 frames) + `stream_type` classification into expanded
    `frames_5_golden.json` (curated commit).

- **Wave 2 — Command surface + already-captured streams (against existing corpus):**
  - Command-surface enumeration (D-06): observed cmd IDs (body[6]) vs r52 expected; cross-validate
    the 14 reused IDs (1,2,3,7,11,14,22,26,35,81,82,106,107,145); unobserved → HYPOTHESIS (D-07).
  - EVENT decode (PROTO-09): all event types incl. battery (PROTO-08), with device-epoch tagging.
  - METADATA + historical-offload documentation (PROTO-10, D-09): HISTORY_START/END, trim cursor,
    ACK command 23 — documentation only.
  - Dual-epoch model (PROTO-15) from GET_DATA_RANGE (unix) + events (device-epoch).

- **Wave 3 — Biometric streams (from the D-05 capture) + schema completion:**
  - Realtime HR/RR (PROTO-07): standard 0x2A37 + custom type-40 if present; validate vs HR strap.
  - IMU/gravity (PROTO-14): adapt 4.0 type-43 layout; confirm sample rate.
  - SpO₂ (PROTO-11) / skin temp (PROTO-12) / respiration (PROTO-13): decode IF observed; validate
    vs app display (D-08); else HYPOTHESIS with honest provenance.
  - Complete `whoop_protocol_5.json` (enums + packets, every field epoch/provenance/confidence —
    SCHEMA-01/02); golden fixtures per type (SCHEMA-04); `scripts/sync-schema-5.sh` (SCHEMA-05);
    `FINDINGS_5.md §Phase 4` (SCHEMA-03); PROTO-16 firmware in every sidecar.

## Metadata

**Confidence breakdown:**
- Framing / wrapper / body layout: **HIGH** — empirically proven on 46/46 golden frames this session; r52 enums match verbatim.
- Command surface (observed subset): **HIGH** for observed (GET_DATA_RANGE, FF/research config); **MEDIUM** for the full reused-14 set (cross-validate in Wave 2); unobserved = HYPOTHESIS by design (D-07).
- Events / metadata / historical-offload protocol: **HIGH** — present and decoded in existing corpus.
- Dual-epoch timestamps: **HIGH** — both Unix and device-epoch decoded from corpus.
- Biometric streams (HR/RR custom, IMU, SpO₂, temp, respiration): **LOW/HYPOTHESIS** — capture-gated on D-05; SpO₂/temp/respiration may be cloud-only per 4.0 precedent.
- Schema/sync tooling: **HIGH** — mirrors verified 4.0 pattern.

**Research date:** 2026-05-30
**Valid until:** 2026-06-29 (30 days — stable protocol facts; the only fast-moving element is any new public 5.0 RE, not checked this session)
