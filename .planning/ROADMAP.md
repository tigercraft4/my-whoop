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

### ✅ v4.0 — UI Redesign + Bug Fix (Phases 14–18) — SHIPPED 2026-06-03

- [x] **Phase 14: Critical Bug Fixes (Data Layer)** — Wire computed metrics into views and clean corrupt HRV baseline (completed 2026-06-01)
- [x] **Phase 15: Ghidra IPA Deep-Dive** — Map every official-app screen and decode Keytel coefficients; produce the UI source-of-truth (completed 2026-06-01)
- [x] **Phase 16: Repo Cleanup + Gen4 Sweep** — Reorganise folders and remove dead WHOOP 4.0 code without architecture changes (completed 2026-06-01)
- [x] **Phase 17: UI Redesign 1:1** — Replicate each screen against Ghidra findings with snapshot + simulator validation (completed 2026-06-01)
- [x] **Phase 18: Hardware Validation** — Ghidra offset analysis complete; hardware session deferred to v5.0 (completed 2026-06-03)
- [x] **Phase 19: Puffin Protocol Hardening** — Context captured; implementation deferred to v5.0 (completed 2026-06-03)

Full archive: `.planning/milestones/v4.0-ROADMAP.md`

---

### 🚧 v5.0 — Goose UI Migration + Ecosystem (Phases 20–26) — IN PROGRESS

**Vision:** Adopt the Goose UI design language (dark-first, Bevel-inspired) across all screens. Migrate to tab structure Home/Health/Coach/More. Downgrade server to backup-only role — app is fully self-contained. Carry forward protocol hardening (Puffin + IMU) from v4.0 context.

- [ ] **Phase 20: Goose UI Foundation** — Dark mode design system, tab restructure (Home/Health/Coach/More), typography and colour tokens matching Goose aesthetic
- [ ] **Phase 21: Home + Health Screens** — Migrate Home rings and Health metric surfaces (Sleep, Recovery, Strain, Stress, Cardio Load, Energy Bank, Health Monitor) to Goose/Bevel style
- [ ] **Phase 22: Coach Screen** — Local AI coach using on-device metrics; OpenAI optional sign-in for streaming replies
- [ ] **Phase 23: More + Settings** — Device screen, Privacy, Support surfaces; remove server dependency from primary flows
- [ ] **Phase 24: Server → Backup Only** — Demote server to optional backup; app works 100% offline; sync is opt-in
- [ ] **Phase 25: Puffin Protocol + IMU Streams** — Carry over from v4.0: type 56/38 defensive fix + types 51/52 IMU decode
- [ ] **Phase 26: Hardware Validation + Polish** — SpO₂/skin/resp ground-truth validation; TestFlight beta

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

**Plans**: 2 plans
Plans:
- [ ] 18-01-PLAN.md — Analise Ghidra: confirmar offsets V128 SpO2/skin temp/respiration (GHIDRA-03, sem hardware)
- [ ] 18-02-PLAN.md — Sessao hardware TOGGLE_IMU_MODE: validar SpO2/skin temp/respiration contra ground truth (PROTO-11/12/13)

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
| 15. Ghidra IPA Deep-Dive | v4.0 | 3/3 | Complete    | 2026-06-01 |
| 16. Repo Cleanup + Gen4 Sweep | v4.0 | 4/4 | Complete    | 2026-06-01 |
| 17. UI Redesign 1:1 | v4.0 | 5/5 | Complete    | 2026-06-01 |
| 18. Hardware Validation (parallel-eligible) | v4.0 | 0/2 | Not started | - |

---

## Backlog

### Phase 18.1: Layout Restructure 1:1 (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 18
**Plans:** 4/4 plans complete
Plans:

- [x] TBD (run /gsd-plan-phase 18.1 to break down) (completed 2026-06-01)

### Phase 18.1.1: WHOOP API Historical Dump (INSERTED)

**Goal:** Pull histórico completo da WHOOP antes do premium acabar e importar para iOS GRDB.
**Requirements**: TBD
**Depends on:** Phase 18.1
**Plans:** 1/1 plans complete

Plans:

- [x] WHOOP-DUMP-01: CSV Export Import para iOS GRDB (completed 2026-06-02)

### Phase 18.1.1.1: Algorithm RE: Recovery + Sleep Local Model (INSERTED)

**Goal:** Calibrar o modelo local de Recovery por regressão linear (HRV ratio → score 0-100) usando dados históricos WHOOP reais. MAE reduzido de 46.4 para 12.0 pts (melhoria 74%).
**Requirements**: TBD
**Depends on:** Phase 18.1.1
**Plans:** 1/1 plans complete

Plans:
- [x] ALG-RE-01: Calibração Recovery — regressão linear HRV+RHR → WHOOP score (completed 2026-06-02)

### Phase 19: Puffin Protocol Hardening + IMU Streams

**Goal**: Close the protocol gaps discovered via analysis of the Goose (b-nnett/goose) Rust core: add defensive support for Puffin packet types that the WHOOP 5.0 may emit, and implement decoding of the raw IMU data streams.
**Depends on:** Phase 18 (protocol verification baseline)
**Requirements:** PROTO-PUFFIN-01, PROTO-PUFFIN-02, PROTO-IMU-01
**Success Criteria:**
1. `whoop_protocol_5.json` documents types 38 (PUFFIN_COMMAND_RESPONSE) and 56 (PUFFIN_METADATA) as documented aliases of 36 and 49 respectively.
2. `classifyHistoricalMeta()` returns `.end`/`.complete` for both type 49 AND type 56 frames — backfill never hangs on a PUFFIN_METADATA HISTORY_END.
3. BLE command response routing handles type 38 identically to type 36.
4. Types 51 (REALTIME_IMU_DATA_STREAM) and 52 (HISTORICAL_IMU_DATA_STREAM) are parsed and stored in a new `imuSample` table in WhoopStore.
5. `FINDINGS_5.md` updated with Puffin/IMU stream documentation sourced from Goose analysis.
**Plans:** TBD
**Source:** Analysis of https://github.com/b-nnett/goose Rust/core/src/protocol.rs — Puffin is a WHOOP 5.0 firmware variant using same 8-byte Maverick framing with alternate packet type numbers.

Plans:
- [ ] PROTO-PUFFIN-01: Schema + classifyHistoricalMeta defensive fix (types 38 + 56)
- [ ] PROTO-PUFFIN-02: BLE command routing for type 38
- [ ] PROTO-IMU-01: IMU stream decode + WhoopStore imuSample table (types 51/52)
- [ ] PROTO-PUFFIN-DOCS: Update FINDINGS_5.md with Puffin + IMU documentation

### Phase 999.2: Hardware validation — v1.0 UNCERTAIN items (BACKLOG)

**Goal:** Validate the 5 hardware-dependent items deferred at v1.0 close
**Deferred at:** 2026-05-31 during v1.0 milestone close
**Plans:**
5/5 plans complete

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
