# Phase 4: Protocol Decode & Schema - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Decode all v1 biometric streams from the WHOOP 5.0 and produce a complete, validated `protocol/whoop_protocol_5.json` schema with golden fixtures for every packet type. Entry condition: Phase 3 go/no-go verdict `"wrapper characterised, decode work cleared with wrapper-strip step"` is committed in `FINDINGS_5.md §7`.

**Deliverables:**
1. `re/survey_5/decode_5.py` — Maverick-aware frame decoder: `strip_maverick()` + body pars2. Expanded `re/survey_5/frames_5_golden.json` — full corpus (all ~5028 frames from existing pklg captures, classified by characteristic and stream type)
3. `protocol/whoop_protocol_5.json` — complete schema (all VERIFIED streams; HYPOTHESIS for unresolved fields)
4. `FINDINGS_5.md` — extended with §Phase 4 (command surface, decoded streams, timestamps, historical offload protocol)
5. Cross-source golden fixtures (iOS pklg + optional Android btsnoop) for each decoded packet type
6. `scripts/sync-schema-5.sh` — syncs canonical schema to Swift bundle resource

**Out of scope:** Swift decoder / iOS app port (Phase 5), kill-process store-then-ack live test (Phase 5, requires Swift CoreBluetooth), live command probing via Bleak (macOS bond constraint — covered by capture analysis instead).

</domain>

<decisions>
## Implementation Decisions

### Body Field Layout (D-01 to D-03)
- **D-01:** **Hipótese 4.0 first, validate empirically.** Assume `body[1:]` (after stripping the Maverick wrapper's role byte at body[0]) follows the 4.0 inner layout: `[type 1B][seq 1B][cmd 1B][payload...][CRC32-LE 4B]`. Validate against the 46 frames already in `frames_5_golden.json` as the first decode step. If validation passes (even on a majority of frames), the hypothesis is confirmed. If it fails, fall back to bottom-up empirical derivation.
  - Rationale: Same firmware WG50_r52 as the 4.0 enum maps; the Maverick wrapper is the outer transport layer, not a protocol redesign. Very high prior probability that the inner body reuses 4.0 field layout.
- **D-02:** **`re/survey_5/decode_5.py` — isolation pattern.** Following the established Phase 2-3 convention, all 5.0 decode scripts stay in `re/survey_5/`. `decode_5.py` imports `strip_maverick()` from `validate_frames_5.py` and adapts `parse_frame()` from `re/decode.py` for the 5.0 body layout. Does NOT import 4.0 `WhoopPacket` (which assumes 4.0 framing).
- **D-03:** **CRC32 body failure → log-and-continue.** Frames with an invalid body CRC32 are logged (with hex + characteristic source) but do not abort the decode loop. Useful for partial frames, fragmented BLE payloads, and mixed-session captures.

### Corpus Expansion (D-04 to D-05)
- **D-04:** **Expand to full ~5028-frame corpus first.** The existing pklg captures (`2026-05-30-ios.pklg` + `2026-05-30-smp-bond-full.pklg`) contain 4714 `data` frames, 158 `cmd-resp`, 155 `cmd-in`, 1 `events` — but `frames_5_golden.json` only extracted 46. Wave 1 or 2 should expand the tshark extraction to cover the full corpus. Frames are classified by characteristic and (eventually) stream type.
- **D-05:** **Targeted capture session in Wave 1.** Schedule one PacketLogger capture (iPhone + strap worn) specifically triggering: 5-10 min realtime HR/RR streaming, navigate to sleep review (historical backfill), navigate to workout history, check events tab. This covers live stream types that may be absent from the existing captures. Avoids 3-4 mid-phase interruptions. New capture stored in `re/capture/samples/` (gitignored) with evidence sidecar in `re/capture/evidence/`.

### Command Surface Strategy (D-06 to D-07)
- **D-06:** **Capture analysis + r52 enum maps — no live probe.** macOS Bleak cannot bond to the 5.0 strap (Phase 2 finding, confirmed). Live command probing (0–255 via re_harness.py) is not possible from macOS. PROTO-06 is therefore fulfilled by: (a) extracting all command IDs observed in iOS pklg captures via tshark + `decode_5.py`, (b) cross-referencing the whoop-vault r52 enum maps for the full expected command surface, (c) documenting the observed vs. expected set.
- **D-07:** **Unobserved commands → HYPOTHESIS with r52 attribution.** Commands in the r52 maps that are not observed in any capture are added to the schema as `"confidence": "HYPOTHESIS"` with `"note": "not observed in captures, expected from r52 enum map"`. This is honest, non-blocking, and preserves the r52 reference for Phase 5.

### Ground-Truth Validation (D-08 to D-09)
- **D-08:** **SpO₂ and skin temp — validate against the official WHOOP app display.** No independent oximeter or thermometer is available. Validation method: capture the decoded stream value at the same moment the WHOOP app shows the metric on-screen. Decoded value within ±2% SpO₂ / ±0.5°C of the app display = `VERIFIED`. This is not an independent ground truth but validates the decode is byte-level correct relative to WHOOP's own interpretation.
  - HR/RR: validated against HR strap (hardware available per user).
- **D-09:** **PROTO-10 kill-process test → deferred to Phase 5.** The historical data offload protocol (store-then-ack discipline) is **documented in Phase 4** from captures: identify the ACK command, the data range command, and the frame sequence from the iOS pklg historical offload traffic. The live kill-process test (intentional crash during pending ACK, verify no data loss on reconnect) requires running Swift CoreBluetooth code on an iPhone — that's Phase 5 scope.

### Claude's Discretion
- Exact tshark command to extract all frames from both pklg captures into the expanded corpus
- Internal format of the expanded `frames_5_golden.json` (add `"stream_type"` field for classified frames)
- Whether `decode_5.py` exposes a CLI or is pure library (library is fine — analysis scripts import it)
- How to structure the `FINDINGS_5.md §Phase 4` extension (follow the §Phase 3 pattern: subsections per stream type)
- How `scripts/sync-schema-5.sh` is implemented (cp + validation or a proper sync script)
- Cross-source golden fixture format (can reuse Phase 3 sidecar pattern: redacted hex + SHA256 + YAML)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 3 Deliverables (Phase 4 entry point)
- `re/survey_5/validate_frames_5.py` — `strip_maverick()` (pure `bytes → bytes`), `parse_maverick()`, and the documented CRC8+CRC32 negative. Phase 4 imports `strip_maverick()` directly.
- `re/survey_5/frames_5_golden.json` — 46-frame starting corpus (Phase 4 seed); Phase 4 expands this to the full ~5028-frame set.
- `protocol/whoop_protocol_5.json` — v0 schema (Maverick envelope + GATT constants + firmware revision). Phase 4 populates `enums` and `packets` sections.
- `FINDINGS_5.md` §7 — go/no-go verdict + Maverick wrapper structure. Phase 4 extends §Phase 4.

### 4.0 Reference Implementation
- `re/decode.py` — `reassemble()` + `parse_frame()` (type/seq/cmd/payload + CRC32-LE). `decode_5.py` adapts this for the 5.0 body layout (D-01).
- `protocol/whoop_protocol.json` — 4.0 canonical schema structure; `whoop_protocol_5.json` follows the same top-level layout (`version/enums/envelope/packets`).
- `FINDINGS.md` — 4.0 ground truth: inner framing, stream decoders, historical offload protocol. Use as reference for what 5.0 streams should look like.
- `re/re_harness.py` — 4.0 harness (uses 4.0 UUIDs + WhoopPacket). Reference for the decode loop pattern. **Do NOT import directly** — 4.0 UUIDs and WhoopPacket are wrong for 5.0.

### Enum Maps & Protocol Reference
- `re/probe_commands.py` — 4.0 safe command probe list; the r52 command names in `SAFE` list apply to 5.0 with the same IDs (cross-check against captures).
- whoop-vault r52 — external reference for command/event enum maps. Hardware revision `WG50_r52` confirms r52 maps are directly applicable. The r52 maps are the primary source for D-06/D-07 unobserved command documentation.
- `re/survey_5/device_local_5.py` — device identity (UUID) for any Bleak scripts that run without bond (standard HR/battery only in Phase 4).

### Existing Captures (primary frame source)
- `re/capture/samples/2026-05-30-ios.pklg` — Phase 1 iOS session: 1011 ATT packets (official app, realtime session). **Gitignored — local only.**
- `re/capture/samples/2026-05-30-smp-bond-full.pklg` — Phase 2 SMP bond session: 4216 ATT packets (bond + post-bond data). **Gitignored — local only.**
- `re/capture/evidence/2026-05-30-ios.meta.yaml` — Phase 1 evidence metadata.
- `re/capture/evidence/2026-05-30-framing-5.meta.yaml` — Phase 3 framing evidence (pass-rate report, per-characteristic frame counts).
- `re/capture/wireshark.md` — tshark commands for ATT payload extraction from pklg; adapt for full-corpus extraction (D-04).

### Capture Tooling (for D-05 targeted capture)
- `re/capture/ios-packetlogger.md` — PacketLogger runbook; follow for the Wave 1 targeted capture session.
- `re/capture/evidence/` — evidence policy (redacted hex + SHA256 + YAML sidecar; raw pklg gitignored).

### Schema & Testing Patterns
- `Packages/WhoopProtocolTests/Resources/frames.json` — 4.0 golden fixture format (raw hex + parsed fields); `frames_5_golden.json` mirrors this structure.
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift` — JSON schema loader; `whoop_protocol_5.json` must stay compatible with this loader's field expectations.

### Phase 4 Requirements
- `.planning/ROADMAP.md` §"Phase 4: Protocol Decode & Schema" — 5 success criteria.
- `.planning/REQUIREMENTS.md` — PROTO-06 through PROTO-16, SCHEMA-01 through SCHEMA-05.

### Legal
- `DISCLAIMER.md` — RE legal frame; evidence policy applies to all Phase 4 fixtures.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `re/survey_5/validate_frames_5.py` — `strip_maverick()` is the Phase 4 entry point for every frame. Import directly; do not copy.
- `re/decode.py:parse_frame()` — adapt (not import) for 5.0 body[1:] → `[type][seq][cmd][payload][CRC32]` layout. The function signature and return dict structure can be reused.
- `re/decode.py:reassemble()` — BLE fragment reassembly using 0xAA SOF. In 5.0 the Maverick wrapper handles framing so reassembly may not be needed for notifications, but verify with the expanded corpus.
- `re/standard_ble.py` — `parse_hr()` (flags byte + uint8/uint16 HR + RR intervals); reuse verbatim for standard HR validation (D-08, HR strap comparison).
- `re/survey_5/hr_5.py` — standard HR streaming via Bleak (no bond needed); reuse to monitor realtime HR during ground-truth capture sessions.
- `Packages/WhoopProtocolTests/Resources/frames.json` — golden fixture structure template.

### Established Patterns
- **Isolation in `re/survey_5/`:** all 5.0 scripts live here. `decode_5.py`, the expanded corpus extractor, and any Phase 4 analysis scripts go in `re/survey_5/` (not main `re/`).
- **Evidence policy:** committed artifacts = redacted hex + SHA256 + YAML sidecar. Raw pklg gitignored. All Phase 4 golden fixtures follow this pattern.
- **Confidence tagging:** every schema field tagged `VERIFIED` (ground-truth-matched) or `HYPOTHESIS` (not yet validated). Phase 4 should push all v1 biometric fields from HYPOTHESIS → VERIFIED.
- **Log format:** `{"ts": ..., "char": ..., "len": ..., "hex": ...}` JSONL (from `re_harness.py`). If a new live capture script is written for standard HR monitoring, follow this format.
- **WG50_r52 enum maps:** r52 command/event IDs are directly usable. Do NOT re-derive from scratch — cross-reference r52 map first, then validate against captures.

### Integration Points
- `frames_5_golden.json` (expanded) → primary input for all biometric stream decoders in Phase 4
- `protocol/whoop_protocol_5.json` (Phase 4 complete) → consumed by Phase 5 `WhoopProtocol` Swift package via `Schema.swift`
- `FINDINGS_5.md §Phase 4` → canonical protocol reference; Phase 5 planner reads this
- `scripts/sync-schema-5.sh` → copies `protocol/whoop_protocol_5.json` to `Packages/WhoopProtocol/Resources/whoop_protocol_5.json` (Swift bundle resource)

</code_context>

<specifics>
## Specific Ideas

- **Body hypothesis validation first:** before writing any biometric stream decoder, run `strip_maverick()` + tentative 4.0 body parser on the 46 golden frames and check if `type/seq/cmd` fields yield recognisable command/event IDs from the r52 map. This is the fastest possible gate (minutes) that unlocks all subsequent decode work.
- **Data characteristic (FD4B0005) is the richest source:** 4714 captured frames vs. 1 events frame. Most biometric stream RE will come from this characteristic — historical backfill packets, realtime data streams. Prioritise decoding `data` frame body types first.
- **App display comparison protocol for D-08:** capture a PacketLogger session while simultaneously screen-recording the iPhone with the WHOOP app open. Align decoded values to timestamps in the screen recording. Simple and sufficient for byte-level correctness validation.
- **Trailer checksum (OPEN):** the Phase 3 open finding. Phase 4 should record any new evidence but does NOT need to solve it to close. All decode work is on the body, not the trailer.

</specifics>

<deferred>
## Deferred Ideas

- **Live command probe 0–255 via re_harness-style harness:** not possible from macOS without bond. If this is needed, implement in Phase 5 with Swift CoreBluetooth (can bond on iPhone) or accept capture-analysis as the command surface documentation.
- **Kill-process store-then-ack test (PROTO-10 live test):** Phase 5 — requires Swift CoreBluetooth running on iPhone.
- **Android btsnoop cross-source fixtures:** not attempted in Phase 4 corpus expansion. Worth adding as a stretch goal if Android capture is available.

</deferred>

---

*Phase: 04-protocol-decode-schema*
*Context gathered: 2026-05-30*
