# Phase 3: Framing Confirmation (Critical Gate) - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate that the 4.0 inner framing CRC algorithms (`0xAA` SOF, len-LE-u16, CRC8 poly 0x07, CRC32-LE) pass on ≥20 captured 5.0 frames from the custom characteristics (cmd-resp, events, data) across at least two sessions — OR fully characterise the Maverick outer wrapper (version, length, role bytes, CRC16 polynomial, inner-buffer alignment) and implement a wrapper stripper if the 98% CRC gate fails.

**Deliverables:**
1. `re/survey_5/validate_frames_5.py` — CRC8 + CRC32 validator with tshark/hex input, pass-rate report, and optional `strip_maverick()` fallback
2. `re/survey_5/frames_5_golden.json` — CRC-valid frames corpus (Phase 4 fixture seed)
3. `protocol/whoop_protocol_5.json` v0 — framing section + GATT constants, confidence-tagged
4. Go/no-go decision recorded in `FINDINGS_5.md` §Phase 3

**Out of scope:** Protocol decode (Phase 4), biometric streams, command surface enumeration, iOS app work (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Frame Source (D-01)
- **D-01:** **Primary source: tshark extraction from existing `.pklg` captures.** Extract ATT payloads from `re/capture/samples/2026-05-30-ios.pklg` (1011 ATT packets, Phase 1 — official app session with `0xAA` SOF on all payloads) and `re/capture/samples/2026-05-30-smp-bond-full.pklg` (4216 ATT packets, Phase 2 — pairing + post-bond session). These two captures are treated as two distinct sessions for ROADMAP criterion 1.
- **D-01b:** **If tshark extracts < 20 frames with `0xAA` SOF from the existing captures:** do a new PacketLogger capture (open official app + PacketLogger for 2–3 minutes). The existing captures are the first attempt; a fresh capture is the fallback.

### CRC Validator (D-02)
- **D-02:** **New standalone `validate_frames_5.py` in `re/survey_5/`** — follows D-04 isolation from 4.0 scripts. Reads ATT payload hex (tshark output or a hex list), attempts `reassemble()` + CRC8 (poly 0x07) + CRC32-LE validation, prints a pass/fail report with frame breakdown by characteristic, and writes `frames_5_golden.json`.
- **D-02b:** **Validate both CRC8 and CRC32-LE.** CRC8 uses poly 0x07 (same as `CRC8_TABLE` in `Packages/WhoopProtocol/Framing.swift`). CRC32 uses `zlib.crc32(pkt) & 0xFFFFFFFF` against the 4-byte trailer (identical to `re/decode.py:parse_frame()`). Validating both gives full confidence the inner framing is identical.
- **D-02c:** **Save valid frames as `re/survey_5/frames_5_golden.json`.** Format mirrors `Packages/WhoopProtocolTests/Resources/frames.json` (the 4.0 golden fixture): raw hex, type/seq/cmd, payload hex, and characteristic source. Phase 4 uses this file directly as its starting corpus.

### Maverick Fallback (D-03)
- **D-03:** **If CRC gate fails (< 98% pass rate): document wrapper structure AND implement `strip_maverick()` in `validate_frames_5.py`.** The ROADMAP criterion 4 ("decode work cleared with wrapper-strip step") requires a working stripper, not just documentation. `strip_maverick()` removes the outer wrapper (version offset, length encoding, role bytes, CRC16 polynomial, inner-buffer alignment) and exposes the inner `0xAA` frame ready for the CRC8+CRC32 check.
- **D-03b:** **Phase 3 is a blocking gate — it does not close until framing is locked.** If the Maverick RE takes more plans than expected, Phase 3 expands. Phase 4 does not begin without the go/no-go decision in `FINDINGS_5.md`.

### whoop_protocol_5.json v0 Scope (D-04)
- **D-04:** **v0 contains: framing section + GATT constants + firmware_revision.** Specifically:
  - Framing: SOF `0xAA`, len-LE-u16, CRC8 poly 0x07, CRC32-LE (zlib), frame struct `[SOF][len 2B][crc8 1B][type 1B][seq 1B][cmd 1B][payload][crc32 4B]`
  - GATT: custom service UUID `FD4B0001-CCE1-4033-93CE-002D5875F58A`, 5 characteristic UUIDs (cmd-in `...0002`, cmd-resp `...0003`, events `...0004`, data `...0005`, diagnostics `...0007`), legacy `61080001-...` verdict: ABSENT
  - firmware_revision: `WG50_r52` (read from Device Information `0x2A27`, VERIFIED)
  - Confidence tagging: `VERIFIED` for CRC-gate-passed framing and confirmed GATT; `HYPOTHESIS` for anything not yet validated
- **D-04b:** The GATT UUIDs belong in the JSON (single source of truth for Phase 5 code), not just in `FINDINGS_5.md`. Phase 5 Swift/Python code imports the canonical JSON — not a markdown file.

### Claude's Discretion
- Exact tshark filter expression to extract ATT payload hex from `.pklg`
- Whether `validate_frames_5.py` reads from stdin, a file argument, or a hardcoded hex list
- Internal structure of `frames_5_golden.json` (as long as it mirrors the 4.0 pattern)
- How the CRC8 table is implemented (lookup table vs. bitwise poly computation)
- Whether `strip_maverick()` is a separate script or a function in `validate_frames_5.py` (conditional on gate failure)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Framing & CRC Reference (4.0 baseline)
- `FINDINGS.md` — 4.0 inner framing ground truth: `[0xAA][len u16 LE][crc8 poly 0x07][type][seq][cmd][payload][crc32 LE]`. This is what Phase 3 validates against.
- `protocol/whoop_protocol.json` — 4.0 canonical schema; v0 structure mirrors this file's top-level layout.
- `re/decode.py` — 4.0 `reassemble()` and `parse_frame()` with CRC32 validation; `validate_frames_5.py` follows the same logic (adapt, don't copy — stays in `re/survey_5/`).
- `Packages/WhoopProtocol/Sources/WhoopProtocol/Framing.swift` — CRC8 poly 0x07 table (`CRC8_TABLE`) and CRC32 zlib; validate the Python and Swift implementations produce identical results on the same input.

### Existing Captures (primary frame source)
- `re/capture/samples/2026-05-30-ios.pklg` — Phase 1 iOS PacketLogger capture (1011 ATT packets, `0xAA` SOF on all payloads, official app session). **Gitignored — local only.**
- `re/capture/samples/2026-05-30-smp-bond-full.pklg` — Phase 2 SMP bond + post-bond session (4216 ATT packets). **Gitignored — local only.**
- `re/capture/evidence/2026-05-30-ios.meta.yaml` — Phase 1 evidence metadata: characteristic handles (`0x099b`/`0x099d`/`0x09a3`), `0xAA` SOF confirmation, 1011 ATT packets.
- `re/capture/evidence/2026-05-30-smp-bond.meta.yaml` — Phase 2 SMP evidence: 4216 ATT packets, LE Legacy Pairing confirmed, bond outcome.

### Capture & Analysis Tooling
- `re/capture/wireshark.md` — tshark commands for ATT/SMP analysis; adapt the ATT filter to extract payload hex from `.pklg`.
- `re/capture/ios-packetlogger.md` — PacketLogger runbook (needed if a fresh capture is required because existing captures yield < 20 frames).

### Phase 2 Findings (GATT map confirmed)
- `FINDINGS_5.md` — confirmed GATT map (§1), legacy UUID verdict (§2, ABSENT), bonding outcome (§3), handle→UUID map (§5), open questions for Phase 3 (§6). **Extend this file with Phase 3 framing confirmation and go/no-go decision.**

### Phase 3 ROADMAP & Requirements
- `.planning/ROADMAP.md` §"Phase 3: Framing Confirmation" — 4 success criteria + go/no-go framing for `FINDINGS_5.md`.
- `.planning/REQUIREMENTS.md` — PROTO-04 (4.0 inner framing CRC-validated on ≥20 frames), PROTO-05 (Maverick outer wrapper characterised if CRC validation fails).

### Legal & Evidence Policy
- `DISCLAIMER.md` — RE legal frame (17 U.S.C. §1201(f)); no proprietary material in repo.
- `re/capture/evidence/` evidence policy (from D-02, Phase 1) — redacted hex + SHA256 + YAML sidecar; raw captures gitignored.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `re/decode.py` — `reassemble()` (BLE fragment → complete frame via `0xAA` SOF + len-LE-u16) and `parse_frame()` (type/seq/cmd/payload + CRC32-LE check via zlib). Port the logic to `validate_frames_5.py`; adapt input to accept tshark hex instead of `capture.jsonl`.
- `re/survey_5/` — Phase 2 script home (D-04). `validate_frames_5.py` goes here alongside `survey_gatt_5.py`, `bond_5.py`, `hr_5.py`.
- `re/survey_5/device_local_5.py` / `device_local_5.example.py` — device identity pattern; Phase 3 scripts follow the same import convention.
- `Packages/WhoopProtocolTests/Resources/frames.json` — 4.0 golden fixture format; `frames_5_golden.json` should mirror this structure (raw hex + parsed fields).

### Established Patterns
- **Evidence policy (D-02, Phase 1):** committed = redacted hex + SHA256 + YAML sidecar. Raw captures gitignored. Phase 3 follows the same policy: commit the validator output report + pass-rate evidence YAML; don't commit raw `.pklg` paths.
- **CRC8 poly 0x07:** used identically in `Framing.swift` (Swift) and expected in `validate_frames_5.py` (Python). Cross-check that both produce the same byte for the same input.
- **`0xAA` SOF quick-check:** Phase 1 confirmed this on all 1011 ATT payloads. Use it as the first filter to identify frames before attempting full CRC validation.
- **JSONL logging from re_harness.py:** if a Bleak live capture is needed (D-01b fallback), the log format is `{"ts":..., "char":..., "hex":...}` — `validate_frames_5.py` can accept this format too.

### Integration Points
- `frames_5_golden.json` → consumed by Phase 4 as the starting decode corpus (command surface probe + biometric stream decode starts from these validated frames).
- `protocol/whoop_protocol_5.json` v0 → consumed by Phase 5 (`WhoopProtocol` Swift package and Python `whoop_protocol` package); structure and field names must be compatible with the 4.0 schema loader in `Packages/WhoopProtocol/Sources/WhoopProtocol/Schema.swift`.
- `FINDINGS_5.md` §Phase 3 section → the go/no-go decision here is the Phase 4 entry condition; Phase 4 planning reads this verdict.

</code_context>

<specifics>
## Specific Ideas

- Hardware revision `WG50_r52` matches whoop-vault r52 — the r52 enum maps (command IDs, event IDs) are directly usable in Phase 4 without re-derivation. Mention this explicitly in the go/no-go `FINDINGS_5.md` entry.
- The two existing captures constitute "two sessions" for ROADMAP criterion 1 — tshark extraction attempts both before concluding a fresh capture is needed.
- If `strip_maverick()` is implemented (gate failure path), it should be a pure function (bytes → bytes) with explicit field offsets documented in a docstring — Phase 4 can then inline it or import it.
- The Phase 3 go/no-go entry in `FINDINGS_5.md` should contain one of two exact verdicts per ROADMAP criterion 4: "framing locked, decode work cleared" or "wrapper characterised, decode work cleared with wrapper-strip step."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-framing-confirmation-critical-gate*
*Context gathered: 2026-05-30*
