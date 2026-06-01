# Roadmap — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)

---

## Milestones

- ✅ **v1.0 — WHOOP 5.0 Protocol + iOS App** — Phases 1–5 (shipped 2026-05-31)
- ✅ **v2.0 — Complete iOS + WHOOP-Style UI + Algorithms** — Phases 6–11 (shipped 2026-05-31)
- ✅ **v3.0 — WHOOP Parity** — Phases 12–13 (shipped 2026-06-01)
- 🚧 **v4.0 — UI Redesign + Bug Fix** — Phases 14–18 (in progress)

---

## Phases

<details>
<summary>✅ v1.0 — WHOOP 5.0 Protocol + iOS App (Phases 1–5) — SHIPPED 2026-05-31</summary>

- [x] Phase 1: Capture Foundation (3/3 plans) — completed 2026-05-30
- [x] Phase 2: GATT Survey & Bonding (4/4 plans) — completed 2026-05-30
- [x] Phase 3: Framing Confirmation — Critical Gate (3/3 plans) — completed 2026-05-30
- [x] Phase 4: Protocol Decode & Schema (5/5 plans) — completed 2026-05-30
- [x] Phase 5: iOS App & Server Port (6/6 plans) — completed 2026-05-31

Full archive: `.planning/milestones/v1.0-ROADMAP.md`

</details>

<details>
<summary>✅ v2.0 — Complete iOS + WHOOP-Style UI + Algorithms (Phases 6–11) — SHIPPED 2026-05-31</summary>

- [x] Phase 6: Backfill Fix (2/2 plans) — completed 2026-05-31
- [x] Phase 7: iOS Validation + Biometrics Capture (3/3 plans) — completed 2026-05-31
- [x] Phase 8: JADX APK Analysis + UI Design Document (2/2 plans) — completed 2026-05-31
- [x] Phase 9: SwiftUI Redesign WHOOP-Style (6/6 plans) — completed 2026-05-31
- [x] Phase 10: Algorithms Display + Server Endpoint (3/3 plans) — completed 2026-05-31
- [x] Phase 11: HealthKit Export (4/4 plans) — completed 2026-05-31

Full archive: `.planning/milestones/v3.0-ROADMAP.md`

</details>

<details>
<summary>✅ v3.0 — WHOOP Parity (Phases 12–13) — SHIPPED 2026-06-01</summary>

- [x] Phase 12: UI Parity (3/3 plans) — completed 2026-06-01
- [x] Phase 13: Backend Parity (4/4 plans) — completed 2026-06-01

Full archive: `.planning/milestones/v3.0-ROADMAP.md`

</details>

### 🚧 v4.0 — UI Redesign + Bug Fix (Phases 14–18) — IN PROGRESS

- [x] **Phase 14: Critical Bug Fixes (Data Layer)** — Wire computed metrics into views and clean corrupt HRV baseline (completed 2026-06-01)
- [ ] **Phase 15: Ghidra IPA Deep-Dive** — Map every official-app screen and decode Keytel coefficients; produce the UI source-of-truth
- [ ] **Phase 16: Repo Cleanup + Gen4 Sweep** — Reorganise folders and remove dead WHOOP 4.0 code without architecture changes
- [ ] **Phase 17: UI Redesign 1:1** — Replicate each screen against Ghidra findings with snapshot + simulator validation
- [ ] **Phase 18: Hardware Validation (parallel-eligible)** — Verify SpO₂, skin temp and respiration against ground truth; does NOT gate v4.0 ship

---

## Phase Details

### Phase 14: Critical Bug Fixes (Data Layer)
**Goal**: Metrics already computed by `LocalMetricsComputer` are correctly displayed and the recovery baseline is free of corrupt HRV values.
**Depends on**: Nothing (first v4.0 phase — unblocks accurate metric display for later UI work)
**Requirements**: BUGFIX-01, BUGFIX-02, BUGFIX-03
**Success Criteria** (what must be TRUE):
  1. SleepCard and SleepView display the `sleepNeededMin` value (ALG-12 output) instead of nothing.
  2. SleepCard and RecoveryCard show the composite `sleepPerformance` score (0–100) rather than raw `efficiency` (0.0–1.0) in both locations.
  3. After GRDB migration v10, no `avgHrv` values stored before commit e65fa31 (corrupt V128 RR offsets) remain in the recovery baseline — they are purged or flagged.
  4. App builds and existing decode/metric tests pass after the migration (no regression in displayed Recovery score).
**Plans**: TBD
**UI hint**: yes

### Phase 15: Ghidra IPA Deep-Dive
**Goal**: A committed, clean-room reference map of every official WHOOP 5.37.0 screen and the verified Keytel calorie coefficients, ready to drive the UI redesign.
**Depends on**: Phase 14 (clean data layer so any Ghidra-discovered bugs land on correct metrics)
**Requirements**: GHIDRA-01, GHIDRA-02, BUGFIX-04
**Success Criteria** (what must be TRUE):
  1. `FINDINGS_5.md` and `docs/specs/v4-ui-map.md` are committed with a complete screen map (one screen per session, findings committed before advancing) — no Swift file touched in this phase.
  2. The 8 sex-specific Keytel doubles at `0x1058a5a80` are decoded and `calories.py` plus `LocalMetricsComputer.swift` are validated/corrected against them.
  3. BUGFIX-04 scope (additional bugs surfaced during IPA analysis) is documented with concrete reproduction notes for fix in this milestone.
  4. All extracted findings are structural/data-only — no proprietary assets, artwork or pseudocode copied into the repo.
**Plans**: TBD

### Phase 16: Repo Cleanup + Gen4 Sweep
**Goal**: Repository structure is reorganised and WHOOP 4.0 dead code is removed, so UI diffs in Phase 17 stay clean and review-able.
**Depends on**: Phase 15 (run after Ghidra RE, before UI component work, to avoid contaminating UI diffs)
**Requirements**: CLEAN-01, CLEAN-02, CLEAN-03
**Success Criteria** (what must be TRUE):
  1. Folders are reorganised (Swift `ios/`, Python `server/`, RE `re/`, `docs/`) with no architecture changes; `xcodegen generate` + `xcodebuild build` passes as a gate after each move.
  2. A Gen4 sweep (grep for 4.0/gen4/Gen4) annotates intentional dual-path code (channel 61080005 for WHOOP 5.0 historical data) and removes WHOOP 4.0 dead code.
  3. Device-type detection correctly distinguishes WHOOP 4.0 vs 5.0 via `device_generation` on connect and applies the right Maverick (5.0) vs Gen4 (4.0) path.
  4. Full build and decode test suite pass after cleanup — no behavioural regression introduced by moves or deletions.
**Plans**: TBD

### Phase 17: UI Redesign 1:1
**Goal**: Each iOS screen matches the official WHOOP app 1:1 against the Ghidra screen map, validated by snapshot tests and interactive simulator checks.
**Depends on**: Phase 16 (clean repo) and Phase 15 (GHIDRA-01 `FINDINGS_5.md`/`v4-ui-map.md` committed — required before UI-01/UI-02 can start)
**Requirements**: UI-01, UI-02, UI-03, UI-04
**Success Criteria** (what must be TRUE):
  1. `WH.*` tokens in `DesignTokens.swift` are updated with Ghidra-verified constants (hex colours, spacings, corner radii) — and this gate is committed before any component change.
  2. Per-screen components (RecoveryCard, SleepCard, StrainCard, TrendsView, and others from GHIDRA-01) are modified to match the screen map, clean-room (no Ghidra asset/pseudocode in Swift).
  3. A `swift-snapshot-testing 1.17.6` snapshot suite exists per screen, with references that act as a visual-regression gate.
  4. Simulator 1:1 validation via XcodeBuildMCP (`snapshot_ui`, `screenshot`) confirms each screen matches the Ghidra reference before it is marked VERIFIED.
**Plans**: TBD
**UI hint**: yes

### Phase 18: Hardware Validation (parallel-eligible)
**Goal**: SpO₂, skin temperature and respiration streams are confirmed against ground-truth references and promoted from HYPOTHESIS to VERIFIED. Parallel-eligible and hardware-gated — does NOT gate v4.0 ship.
**Depends on**: Phase 15 (GHIDRA-03 offset confirmation feeds validation) — runnable in parallel with Phase 17 whenever hardware is available
**Requirements**: GHIDRA-03, PROTO-11, PROTO-12, PROTO-13
**Success Criteria** (what must be TRUE):
  1. V128 offsets for SpO₂, skin temp and respiration are confirmed via Ghidra + PacketLogger (GHIDRA-03).
  2. SpO₂ is VERIFIED via TOGGLE_IMU_MODE capture against an oximeter ground truth; schema moves HYPOTHESIS → VERIFIED (PROTO-11).
  3. Skin temperature is VERIFIED against a thermometer ground truth (PROTO-12).
  4. Respiration rate is VERIFIED within the 12–20 rpm range via TOGGLE_IMU_MODE capture (PROTO-13).
**Plans**: TBD

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Capture Foundation | v1.0 | 3/3 | Complete | 2026-05-30 |
| 2. GATT Survey & Bonding | v1.0 | 4/4 | Complete | 2026-05-30 |
| 3. Framing Confirmation | v1.0 | 3/3 | Complete | 2026-05-30 |
| 4. Protocol Decode & Schema | v1.0 | 5/5 | Complete | 2026-05-30 |
| 5. iOS App & Server Port | v1.0 | 6/6 | Complete | 2026-05-31 |
| 6. Backfill Fix | v2.0 | 2/2 | Complete | 2026-05-31 |
| 7. iOS Validation + Biometrics Capture | v2.0 | 3/3 | Complete | 2026-05-31 |
| 8. JADX APK Analysis + UI Design Document | v2.0 | 2/2 | Complete | 2026-05-31 |
| 9. SwiftUI Redesign WHOOP-Style | v2.0 | 6/6 | Complete | 2026-05-31 |
| 10. Algorithms Display + Server Endpoint | v2.0 | 3/3 | Complete | 2026-05-31 |
| 11. HealthKit Export | v2.0 | 4/4 | Complete | 2026-05-31 |
| 12. UI Parity | v3.0 | 3/3 | Complete | 2026-06-01 |
| 13. Backend Parity | v3.0 | 4/4 | Complete | 2026-06-01 |
| 14. Critical Bug Fixes (Data Layer) | v4.0 | 2/2 | Complete    | 2026-06-01 |
| 15. Ghidra IPA Deep-Dive | v4.0 | 0/? | Not started | - |
| 16. Repo Cleanup + Gen4 Sweep | v4.0 | 0/? | Not started | - |
| 17. UI Redesign 1:1 | v4.0 | 0/? | Not started | - |
| 18. Hardware Validation (parallel-eligible) | v4.0 | 0/? | Not started | - |

---

## Backlog

### Phase 999.2: Hardware validation — v1.0 UNCERTAIN items (BACKLOG)

**Goal:** Validate the 5 hardware-dependent items deferred at v1.0 close
**Deferred at:** 2026-05-31 during v1.0 milestone close
**Plans:**
- [ ] IOS-03/04/05: Today/Sleep/Trends views — requires WHOOP with unsynced data (don't use official app for 1+ week)
- [ ] IOS-06: 14+ day historical backfill with safe-trim invariant (same session as above)
- [ ] IOS-08: Background reconnect after force-quit — 30s test on physical iPhone
- [ ] PROTO-02 D-03b: SMP PacketLogger capture during official-app re-bonding
- [ ] PROTO-11/12/13/14: IMU/SpO2/skin temp/respiration — requires dedicated TOGGLE_IMU_MODE capture session

**Unblocked by:** Physical iPhone + WHOOP with fresh data; available development session

### Phase 999.3: WHOOP Cloud API MCP Integration (BACKLOG)

**Goal:** Adicionar cloud sync opcional via WHOOP API oficial usando um servidor MCP TypeScript com OAuth2 PKCE
**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

**Reference:** https://github.com/shashankswe2020-ux/whoop-mcp — implementação de referência com 14 health tools (recovery, sleep, workouts, cycles, analytics), trend detection via linear regression, token refresh automático
**Notes:** Offline-first mantém-se como default; MCP cloud seria opt-in. Não gate nenhuma fase v4.0.
