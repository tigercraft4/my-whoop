# Roadmap — WHOOP 5.0

**Project:** my-whoop (clean fork for WHOOP 5.0)

---

## Milestones

- ✅ **v1.0 — WHOOP 5.0 Protocol + iOS App** — Phases 1–5 (shipped 2026-05-31)
- 🚧 **v2.0 — Complete iOS + WHOOP-Style UI + Algorithms** — Phases 6–11 (in progress)
- 📋 **v3.0 — WHOOP Parity** — Phases 12–13 (planned)

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

### 🚧 v2.0 — Complete iOS + WHOOP-Style UI + Algorithms (In Progress)

**Milestone Goal:** Transformar a app num cliente completo do WHOOP 5.0 — backfill funcional, UI WHOOP-style, todos os streams biométricos VERIFIED, algoritmos de Recovery/Strain/Sleep integrados e HealthKit export.

- [x] **Phase 6: Backfill Fix** — Corrigir a race condition no FF key exchange para que os dados históricos fluam do WHOOP 5.0 — completed 2026-05-31
- [x] **Phase 7: iOS Validation + Biometrics Capture** — Validar todas as iOS views com dados reais e verificar streams biométricos HYPOTHESIS (completed 2026-05-31)
- [x] **Phase 8: JADX APK Analysis + UI Design Document** — Analisar o APK Android via JADX e documentar a arquitectura de informação da app WHOOP — completed 2026-05-31
- [x] **Phase 9: SwiftUI Redesign WHOOP-Style** — Redesenhar a UI em WHOOP-style com tab bar, Recovery card, Sleep card e Strain card (completed 2026-05-31)
- [x] **Phase 10: Algorithms Display + Server Endpoint** — Ligar os resultados dos algoritmos às iOS views e adicionar o endpoint GET /v1/today (completed 2026-05-31)
- [x] **Phase 11: HealthKit Export** — Exportar dados biométricos do WHOOP para a Apple Health (completed 2026-05-31)

---

## Phase Details

### Phase 6: Backfill Fix
**Goal**: Fix the FF key exchange race condition in Backfiller so historical data actually flows from WHOOP 5.0 te app — the hard prerequisite for everything else in v2.0
**Depends on**: Phase 5 (v1.0 complete)
**Requirements**: BF-01, BF-02
**Success Criteria** (what must be TRUE):
  1. Backfiller connects to WHOOP 5.0 and pulls historical data without getting stuck — at least one complete session of frames received
  2. 14+ days of historical backfill completes with safe-trim invariant; intentional process kill during pending ack does NOT lose data on reconnect
  3. `DailyMetric` rows appear in local GRDB store after backfill (verified via sqlite3 or debug log)
**Plans**: TBD

### Phase 7: iOS Validation + Biometrics Capture
**Goal**: Validate all iOS views with real WHOOP 5.0 data (unblocked by Phase 6) and run dedicated TOGGLE_IMU_MODE captures to verify HYPOTHESIS biometric streams
**Depends on**: Phase 6
**Requirements**: IOS-03, IOS-04, IOS-05, IOS-08, PROTO-11, PROTO-12, PROTO-13, PROTO-14
**Success Criteria** (what must be TRUE):
  1. Today view shows non-placeholder recovery score and HRV from real WHOOP 5.0 data
  2. Sleep view shows at least one real sleep session with staging breakdown
  3. TOGGLE_IMU_MODE capture session produces frames for SpO₂ (PROTO-11), skin temp (PROTO-12), respiration (PROTO-13), and IMU (PROTO-14); at least SpO₂ VERIFIED against oximeter ground truth
  4. App reconnects to WHOOP after force-quit within 30s via willRestoreState (IOS-08)
**Plans**: TBD
**UI hint**: yes

### Phase 8: JADX APK Analysis + UI Design Document
**Goal**: Use JADX on the WHOOP Android APK to document the information architecture (what each screen shows, field labels, data hierarchy) and produce a UI design document that guides the SwiftUI implementation in Phase 9
**Depends on**: Nothing (runs in parallel with Phase 6)
**Requirements**: UI-01
**Success Criteria** (what must be TRUE):
  1. JADX analysis complete: each of the 5 main tabs documented with field names, labels, and data relationships
  2. UI design document committed to `docs/` with wireframe-level description of each card (Recovery, Sleep, Strain) — no artwork or assets copied
  3. Field-to-model mapping table: each UI field mapped to its corresponding `DailyMetric`/`CachedSleepSession` property or `ALG-*` requirement
**Plans**: 2/2 complete

### Phase 9: SwiftUI Redesign WHOOP-Style
**Goal**: Evolve the existing iOS app UI to WHOOP-style: new tab bar structure with @SceneStorage, Recovery card, Sleep card, Strain card — all wired to real data from Phase 7
**Depends on**: Phase 7, Phase 8
**Requirements**: UI-02, UI-03, UI-04, UI-05
**Success Criteria** (what must be TRUE):
  1. Tab bar has 5 tabs (Today, Sleep, Strain, Trends, Device) with persistent tab selection (@SceneStorage)
  2. Recovery card on Today tab shows score 0–100 with color zone ring, HRV, RHR, sleep performance — all from real DailyMetric data
  3. Sleep card shows stacked bar with REM/Deep/Light/Awake stages from real CachedSleepSession.stagesJSON via HypnogramView
  4. Strain card shows 0–21 gauge with HR zones breakdown from real DailyMetric.strain
**Plans**: TBD
**UI hint**: yes

### Phase 10: Algorithms Display + Server Endpoint
**Goal**: Wire algorithm results (already computed server-side) into the iOS views; add GET /v1/today endpoint to server; add staleness indicator
**Depends on**: Phase 7
**Requirements**: ALG-01, ALG-02, ALG-03, ALG-04
**Success Criteria** (what must be TRUE):
  1. GET /v1/today?device=<id> endpoint returns most-recent DailyMetric row correctly
  2. Today view shows Recovery score sourced from server compute_day() with staleness indicator when lastRefreshedAt > 6h
  3. Sleep view shows staging from sleep.py (Cole-Kripke algorithm output)
  4. Strain view shows strain score from strain.py (Edwards TRIMP)
**Plans**: TBD
**UI hint**: yes

### Phase 11: HealthKit Export
**Goal**: Export WHOOP biometric data to Apple Health — HealthKit capability, entitlements, and plist keys added before any import; SpO₂ export gated behind PROTO-11 VERIFIED
**Depends on**: Phase 9, Phase 10
**Requirements**: HK-01, HK-02, HK-03, HK-04, HK-05
**Success Criteria** (what must be TRUE):
  1. HealthKit capability + NSHealthShareUsageDescription + NSHealthUpdateUsageDescription in Info.plist; com.apple.developer.healthkit entitlement present
  2. HR samples visible in Apple Health app after backfill (HKQuantityType.heartRate, count/min unit)
  3. HRV RMSSD visible in Apple Health as heartRateVariabilitySDNN samples
  4. Sleep sessions visible in Apple Health with correct stage mapping (asleepCore/asleepDeep/asleepREM)
  5. SpO₂ export only present if PROTO-11 is VERIFIED; otherwise HK-03 shows as deferred in VERIFICATION.md
  6. Authorization requested lazily in Today view; app continues normally if denied
**Plans**: TBD

### 📋 v3.0 — WHOOP Parity (Planned)

**Milestone Goal:** Atingir paridade total com a app WHOOP — UI labels correctos, métricas em falta, algoritmos de backend equivalentes aos do WHOOP, e haptics funcionais.

- [ ] **Phase 12: UI Parity** — Corrigir labels e adicionar métricas em falta identificadas via IPA analysis (3 plans)
- [ ] **Phase 13: Backend Parity** — Algoritmos equivalentes ao WHOOP: Sleep Performance, Training State, Sleep Needed, Calorias

---

## Phase Details

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Capture Foundation | v1.0 | 3/3 | Complete | 2026-05-30 |
| 2. GATT Survey & Bonding | v1.0 | 4/4 | Complete | 2026-05-30 |
| 3. Framing Confirmation | v1.0 | 3/3 | Complete | 2026-05-30 |
| 4. Protocol Decode & Schema | v1.0 | 5/5 | Complete | 2026-05-30 |
| 5. iOS App & Server Port | v1.0 | 6/6 | Complete | 2026-05-31 |
| 6. Backfill Fix | v2.0 | 2/2 | Complete | 2026-05-31 |
| 7. iOS Validation + Biometrics Capture | v2.0 | 3/3 | Complete   | 2026-05-31 |
| 8. JADX APK Analysis + UI Design Document | v2.0 | 2/2 | Complete | 2026-05-31 |
| 9. SwiftUI Redesign WHOOP-Style | v2.0 | 6/6 | Complete    | 2026-05-31 |
| 10. Algorithms Display + Server Endpoint | v2.0 | 3/3 | Complete   | 2026-05-31 |
| 11. HealthKit Export | v2.0 | 4/4 | Complete    | 2026-05-31 |
| 12. UI Parity | v3.0 | 1/3 | In Progress|  |
| 13. Backend Parity | v3.0 | 0/? | Not started | - |

### Phase 12: UI Parity
**Goal**: Corrigir todos os labels e métricas identificados via IPA analysis (WHOOP 5.37.0) para atingir paridade visual com a app oficial
**Depends on**: Phase 9 (SwiftUI Redesign done)
**Source**: IPA analysis de `/APPS IOS APK/com.whoop.iphone_5.37.0_und3fined.ipa` + `docs/whoop-ui-reference.md`
**Requirements**: UI-03, UI-04, UI-05, IOS-05
**Success Criteria** (what must be TRUE):
  1. SleepCard mostra "SLEEP PERFORMANCE" (não "SLEEP EFFICIENCY") e "HOURS OF SLEEP" (não "TIME ASLEEP")
  2. Staging breakdown inclui tempo AWAKE como 4ª fase
  3. StrainCard mostra Training State (OPTIMAL / RESTORATIVE / OVERREACHING / IMPOSSIBLE) baseado em Recovery + Strain
  4. Haptics funcionam no WHOOP 5.0 — PacketLogger capture da app oficial confirma o comando correcto (Gen5: RunAppDrivenHapticsCommandPacket com DRV2605 waveform effects)
  5. TrendsView inclui SLEEP PERFORMANCE (não duração) como métrica principal de sono

**Gaps identificados (IPA 5.37.0):**
- `SleepView`: "SLEEP EFFICIENCY" → "SLEEP PERFORMANCE"; "TIME ASLEEP" → "HOURS OF SLEEP"
- `SleepCard`: adicionar AWAKE como 4ª fase no HypnogramView; adicionar SLEEP LATENCY e DISTURBANCES se disponíveis
- `StrainView`: adicionar TRAINING STATE badge (OPTIMAL/RESTORATIVE/OVERREACHING/IMPOSSIBLE)
- Haptics: Gen5 usa `RunAppDrivenHapticsCommandPacket` com até 8 DRV2605 waveform effects — requer PacketLogger capture da app oficial a fazer buzz
- `MetricKind`: SLEEP PERFORMANCE como métrica de tendência (não sleepDuration)
- Skin temp: separar valor absoluto de "FROM BASELINE" (desvio)

**Plans:** 1/3 plans executed
- [x] 12-01-PLAN.md — SleepView labels (SLEEP PERFORMANCE / HOURS OF SLEEP / SLEEP LATENCY / SKIN TEMP) + AWAKE confirm
- [ ] 12-02-PLAN.md — StrainCard Training State badge from recovery_to_strain.json
- [ ] 12-03-PLAN.md — MetricKind.sleepPerformance + dailyCases, Today/DayDetail RHR & SKIN TEMP labels

### Phase 13: Backend Parity
**Goal**: Implementar algoritmos equivalentes ao WHOOP no servidor: Sleep Performance score ponderado, Training State, Sleep Needed, Calorias — substituindo ou complementando o openwhoop-algos actual
**Depends on**: Phase 10 (server endpoint done), Phase 12 (UI ready to display)
**Source**: IPA analysis revela nomes de classes: `SleepPerformanceCalculator`, `RecoveryScoreCalculator`, `TrainingStateCalculator`, `SleepNeededCalculator`
**Requirements**: ALG-10, ALG-11, ALG-12, ALG-13
**Success Criteria** (what must be TRUE):
  1. `sleep.py`: Sleep Performance = score ponderado (não raw efficiency) — fórmula: duração + eficiência + staging adequado + consistência; range 0–100
  2. `daily.py`: Training State calculado a partir de Recovery + Day Strain: OPTIMAL (Recovery 67–100, Strain moderado), RESTORATIVE (Recovery baixo, Strain baixo), OVERREACHING (Strain alto vs Recovery), IMPOSSIBLE (Recovery < 33 + Strain alto)
  3. `daily.py`: Sleep Needed = Baseline (média 7d) + Strain Debt (função do strain do dia anterior) + Sleep Debt (défice acumulado) − Recent Naps
  4. `strain.py`: Calorias estimadas (RMR via Mifflin–St Jeor + TEE via strain) e expostas no endpoint `/v1/today`
  5. iOS Today view mostra CALORIES e Training State a partir dos valores computados pelo servidor

**Como o WHOOP analiza (baseado em IPA class names + openwhoop-algos):**
- **Sleep Performance**: não é `efficiency = time_asleep / time_in_bed`. É um score composto que penaliza fragmentação, premia staging adequado (REM + Deep > 20%), e normaliza por duração. Classes: `SleepPerformanceCalculator`, `SleepStagingQualityMetric`
- **Training State**: função bidimensional de (Recovery Score, Day Strain). 4 zonas no plano Recovery-Strain. Classes: `TrainingStateCalculator`, `TrainingZoneClassifier`
- **Sleep Needed**: `baseline_sleep + strain_sleep_debt - nap_credit`. Baseline = média rolling 7d. Strain debt aumenta com Day Strain > 14. Classes: `SleepNeededCalculator`, `SleepDebtTracker`
- **Calorias**: RMR (Mifflin–St Jeor com perfil corporal) + TEE proporcional ao strain acumulado. Classes: `CalorieCalculator`, `BasalMetabolicRateModel`
- **Haptics Gen5**: `RunAppDrivenHapticsCommandPacket` → DRV2605 waveform effects (até 8 por chamada). Sem patternId simples — envia sequências de efeitos pré-definidos. Requer PacketLogger capture para reverse-engineer os bytes exactos.

---

## Progress

### Phase 999.1: Follow-up — Phase 1 Android device items (BACKLOG)

**Goal:** Resolve Phase 1 verification failures that require a physical Android device
**Source phase:** 1
**Deferred at:** 2026-05-30 during /gsd-progress --next advancement to Phase 2
**Root cause:** No Android device available during Phase 1 execution — runbooks are complete and ready
**Plans:**
- [ ] Android btsnoop live capture: enable HCI snoop, run `adb bugreport`, produce evidence triplet under `re/capture/evidence/` (ROADMAP criterion 2, TOOL-02)
- [ ] JADX-GUI APK live navigation: pull split APK via `adb shell pm path`, navigate to Maverick/packet-type enums, produce enum notes cross-referenced against whoop-vault r52 (ROADMAP criterion 4, TOOL-03)

**Unblocked by:** Access to a physical Android device running the WHOOP app

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
