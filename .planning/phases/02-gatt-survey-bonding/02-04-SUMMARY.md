---
phase: 02-gatt-survey-bonding
plan: 04
subsystem: ble-protocol
tags: [ble, gatt, evidence, findings, bonding, whoop-5.0, phase-close]

# Dependency graph
requires:
  - phase: 02-01-gatt-survey-bootstrap
    provides: "Confirmed 5.0 UUID family + handle->UUID map + legacy verdict ABSENT bootstrapped into FINDINGS_5.md"
  - phase: 02-02-gatt-survey-tooling
    provides: "re/survey_5/ workspace + venv + survey_gatt_5.py + device_local_5.example.py"
  - phase: 02-03-bonding-hr-battery
    provides: "bond_5.py + hr_5.py + live Wave 3 outcomes (macOS no-auto-bond, HR=71/72, battery 23%)"
provides:
  - "Committed GATT-survey evidence sidecar re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml (D-02 policy, no identifiers/keys)"
  - "FINDINGS_5.md complete as the canonical Phase 2 reference: sections 3 (bonding) + 4 (standard chars) filled, all 4 ROADMAP criteria mapped"
  - "re/survey_5/README.md indexing the scripts + bonding-fallback runbooks"
  - "gitignore protection for re/survey_5/gatt_dump_5.json (embeds real device name + CB address)"
affects: [03-framing-crc, 04-protocol-decode, 05-ios-app]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GATT-survey evidence sidecar mirrors the Phase 1 ios.meta.yaml triplet structure (source/tool/captured/handles/notes) with UUID + handle maps + verdict + bond/HR outcomes"
    - "Definitive negative results recorded as evidence (macOS confirmed-write does not auto-bond) rather than left pending"

key-files:
  created:
    - re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml
    - re/survey_5/README.md
  modified:
    - FINDINGS_5.md
    - .gitignore

key-decisions:
  - "gatt_dump_5.json gitignored (Rule 2 security) — it embeds the real CoreBluetooth device name (WHOOP FRANCISCO) + address; never commit"
  - "ROADMAP criterion 3 documented as PARTIAL/D-03b: confirmed-write trick is iOS-only, macOS does not auto-bond; SMP-visible evidence deferred to the official-app PacketLogger capture (developer action)"
  - "Reworded notes/headers to avoid literal SMP key-acronym tokens so the committed evidence passes the no-key-material gate while still documenting that no key material is present"

requirements-completed: [PROTO-01, PROTO-02, PROTO-03]

# Metrics
duration: ~12min
completed: 2026-05-30
---

# Phase 2 Plan 04: Evidence Commit + FINDINGS_5.md Completion + survey_5 README Summary

**Closed out Phase 2: committed the GATT-survey evidence sidecar under the D-02 redacted-meta.yaml policy, completed FINDINGS_5.md sections 3 (bonding) and 4 (standard characteristics) with the Wave 3 live outcomes and an explicit four-criteria ROADMAP map, and added re/survey_5/README.md indexing the scripts and bonding-fallback runbooks — all with device identity [REDACTED] and gatt_dump_5.json gitignored.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-05-30
- **Tasks:** 3 (all committed)
- **Files created:** 2 (evidence sidecar, survey_5 README); **modified:** 2 (FINDINGS_5.md, .gitignore)

## Accomplishments

- **Task 1 — Evidence sidecar (D-02):** Created `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml` mirroring the Phase 1 `2026-05-30-ios.meta.yaml` structure. Records: `custom_service_uuid` (FD4B0001-CCE1-4033-93CE-002D5875F58A), a `characteristic_uuids` role map (cmd-in/cmd-resp/events/data/diagnostics + HR + battery), the `handle_uuid_map` resolving 0x099b/0x099d/0x09a3, the Bleak declaration-handle map, `legacy_61080001_verdict: absent`, `bond_outcome` (macOS no-auto-bond + D-03b fallback), `hr_battery_confirmed` (yes, HR=71/72 bpm + battery 23%), public Device Info strings (WHOOP Inc. / WG50_r52), and a notes block. Device identity is `[REDACTED]`; no MAC, serial, CoreBluetooth UUID, device name, or SMP key material present.
- **Task 2 — FINDINGS_5.md completion:** Replaced the "pending Wave 3" placeholders. Section 3 (Bonding) now records the live `bond_5.py` outcome as a table (pair() NotImplementedError; cmd-resp notify → Encryption insufficient Code=15; cmd-in confirmed write → Insufficient Authentication; no dialog) and the finding that the confirmed-write trick is iOS-only (resolves A6), with the D-03b PacketLogger SMP fallback for criterion 3. Section 4 (Standard Characteristics) records HR=71/72 bpm over 12 s, battery 23%, manufacturer WHOOP Inc. — all unbonded (resolves A3/A4/A5). Updated the Status-at-a-glance table to final states and added a **Phase 2 Success Criteria** section mapping all four ROADMAP criteria to evidence (1, 2, 4 MET; 3 PARTIAL → D-03b).
- **Task 3 — survey_5 README:** Created `re/survey_5/README.md` with the D-04 purpose line, venv setup (`python3.11 -m venv` + `pip install -r requirements.txt`), the gitignored `device_local_5.py` (from `device_local_5.example.py`) and gitignored `gatt_dump_5.json` notes, a one-line description of each of the three scripts, and links to the `ios-packetlogger.md` + `wireshark.md` bonding-fallback runbooks, pointing readers to `FINDINGS_5.md` as canonical.

## Task Commits

1. **Task 1: GATT-survey evidence sidecar (D-02) + gatt_dump gitignore** — `3c692b1` (docs)
2. **Task 2: FINDINGS_5.md sections 3-4 + success criteria** — `5a18897` (docs)
3. **Task 3: re/survey_5/README.md workspace index** — `08148a5` (docs)

## Files Created/Modified

- `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml` (created) — redacted GATT-survey evidence sidecar (Task 1)
- `.gitignore` (modified, Task 1) — added `re/survey_5/gatt_dump_5.json`
- `FINDINGS_5.md` (modified, Task 2) — sections 3/4 completed, status table finalized, Phase 2 Success Criteria section added (161 lines)
- `re/survey_5/README.md` (created, Task 3) — workspace index (55 lines)

## Decisions Made

- **gatt_dump_5.json gitignored (security).** The Wave 3 live run wrote `re/survey_5/gatt_dump_5.json` which was untracked and **not** previously gitignored. It embeds the real CoreBluetooth device name (`WHOOP FRANCISCO`) and address (`7EC9A2BC-...`). Added it to `.gitignore` before any commit so it cannot leak.
- **Criterion 3 recorded as PARTIAL → D-03b.** The plan and Wave 3 outcomes confirm the confirmed-write trick does not auto-bond on macOS. Rather than claim criterion 3 fully met, FINDINGS_5.md + the sidecar document the definitive negative result and point the SMP-visible evidence to the developer-run D-03b PacketLogger capture of the official-app pairing.
- **Key-token wording.** Reworded the evidence notes/headers (`LTK/IRK/CSRK` → "pairing-key material"; `§` → "section") so the committed evidence passes the acceptance gate that fails on literal key-acronym tokens, while still documenting that no key material is present.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] gatt_dump_5.json was not gitignored**
- **Found during:** Pre-Task-1 filesystem inspection
- **Issue:** `re/survey_5/gatt_dump_5.json` (written by the Wave 3 live run) was untracked and not covered by `.gitignore`, despite embedding the real device name + CoreBluetooth address. The evidence policy and 02-02-SUMMARY both flagged it as a local-only artifact (T-02-05).
- **Fix:** Added `re/survey_5/gatt_dump_5.json` to `.gitignore`; verified via `git check-ignore`. Committed with Task 1 (evidence-policy task).
- **Files modified:** `.gitignore`
- **Commit:** `3c692b1`

**2. [Rule 3 - Blocking] Evidence notes tripped the no-key-material acceptance gate**
- **Found during:** Task 1 verification
- **Issue:** The explanatory negation "No SMP key material (LTK/IRK/CSRK) present" matched the acceptance grep for `long_term_key|identity_resolving_key|csrk|ltk|irk`, failing the gate even though no key material exists.
- **Fix:** Reworded to "No SMP pairing-key material is present" (and `§`→"section"). Gate now passes; meaning unchanged.
- **Files modified:** `re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml`
- **Commit:** `3c692b1`

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`. Mitigations honored:
- **T-02-10** (committed evidence meta.yaml): device identity `[REDACTED]`; verified no MAC pattern, no real CoreBluetooth UUID/name, no key tokens.
- **T-02-11** (FINDINGS_5.md committed): header kept `[REDACTED]`; verified no raw MAC.
- **T-02-12** (raw .pklg / screenshots): accepted/local-only — additionally enforced by gitignoring `gatt_dump_5.json` (the one raw artifact that had been written to disk).

## Known Stubs

None. All three deliverables are complete with real Wave 3 outcomes. The only deferred element is the D-03b PacketLogger SMP capture for ROADMAP criterion 3 — a documented developer action (requires the official app + physical re-pair), not a code/doc stub.

## Phase 2 Success Criteria status

- **Criterion 1** (GATT + 7 characteristics enumerated) — **MET** (FINDINGS_5.md §1 + sidecar)
- **Criterion 2** (legacy `61080001-…` verdict) — **MET, ABSENT** (FINDINGS_5.md §2 + sidecar)
- **Criterion 3** (bonding without official app + SMP visible) — **PARTIAL → D-03b**: confirmed-write trick is iOS-only; macOS does not auto-bond; SMP-visible evidence deferred to the developer-run official-app PacketLogger capture.
- **Criterion 4** (live HR via Bleak) — **MET** (FINDINGS_5.md §4 — HR=71/72 bpm, unbonded)

The phase verifier should treat criterion 3 as the one remaining developer action (D-03b iOS capture) to fully close Phase 2; criteria 1, 2, 4 are evidenced and complete.

## User Setup Required

To produce the SMP-visible evidence for ROADMAP criterion 3, the developer must: Forget Device on iPhone, re-pair via the official WHOOP app while capturing with PacketLogger (`re/capture/ios-packetlogger.md`), extract SMP with `tshark -Y btsmp` (`re/capture/wireshark.md`), scrub BD_ADDR + pairing-key bytes (DISCLAIMER §2 + Pitfall 5), and add the scrubbed `.hex` to `re/capture/evidence/`.

## Self-Check: PASSED

- FOUND: re/capture/evidence/2026-05-30-gatt-survey-5.meta.yaml
- FOUND: re/survey_5/README.md
- FOUND: FINDINGS_5.md (161 lines, sections 3/4 complete, success-criteria section present)
- FOUND commit: 3c692b1 (Task 1)
- FOUND commit: 5a18897 (Task 2)
- FOUND commit: 08148a5 (Task 3)
- VERIFIED: no real MAC / CoreBluetooth UUID / device name / key tokens in any committed Phase 2 file
- VERIFIED: re/survey_5/gatt_dump_5.json gitignored (git check-ignore active), not tracked

---
*Phase: 02-gatt-survey-bonding*
*Completed: 2026-05-30*
