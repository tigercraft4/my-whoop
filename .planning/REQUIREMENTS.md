# Requirements — WHOOP 5.0 v2.0

**Project:** my-whoop (WHOOP 5.0)
**Version:** v2.0
**Date:** 2026-05-31

---

## v2.0 Requirements

### Backfill Pipeline Fix

- [ ] **BF-01**: O Backfiller puxa dados históricos do WHOOP 5.0 sem ficar preso — a race condition no FF key exchange é corrigida (gating em `ffExchangePending == false` em vez de `asyncAfter(1.5s)`)
- [ ] **BF-02**: Historical backfill de 14+ dias completa end-to-end com safe-trim invariant sem perda de dados; kill-process durante ack não perde dados

### iOS Validation (hardware-dependente)

- [ ] **IOS-03**: Today view mostra recovery score, HRV e sleep summary com dados reais do WHOOP 5.0 (após backfill funcional) — hardware validation pending (requires physical device + Phase 6 backfill)
- [ ] **IOS-04**: Sleep view mostra sessões de sono históricas reais com staging (REM/Deep/Light/Awake) — hardware validation pending (requires physical device + Phase 6 backfill)
- [ ] **IOS-05**: Trends view mostra gráficos de HR/HRV/SpO₂/skin temp com séries temporais reais (deferred to Phase 9 SwiftUI Redesign)
- [ ] **IOS-08**: Background reconnect após force-quit funciona — app reconecta via `willRestoreState` sem intervenção manual — Maestro test ready (ios/maestro/07_ios08_background_reconnect.yaml); hardware execution pending (requires physical iPhone + WHOOP 5.0)

### Biométricos HYPOTHESIS → VERIFIED

- [ ] **PROTO-11**: SpO₂ decode VERIFIED — captura dedicada com TOGGLE_IMU_MODE; valor validado contra oxímetro de referência; schema atualizado para VERIFIED
- [ ] **PROTO-12**: Skin temperature VERIFIED — captura dedicada; valor validado contra termómetro de referência
- [ ] **PROTO-13**: Respiration rate VERIFIED — captura dedicada; valor plausível (12–20 rpm)
- [ ] **PROTO-14**: IMU/gravity VERIFIED — TOGGLE_IMU_MODE ativo; 6-axis accelerometer decode confirmado; sample rate documentado

### UI WHOOP-Style

- [ ] **UI-01**: JADX APK analysis documentado — estrutura de ecrãs WHOOP registada (hierarquia de dados por tab, labels e unidades dos campos) dentro dos limites da regra D-04; nenhum asset/artwork copiado
- [x] **UI-02**: Tab bar inferior com 5 tabs — Today/Overview, Sleep, Strain/Workouts, Trends, Device — e persistência de seleção via `@SceneStorage`
- [x] **UI-03**: Recovery card na Today view — score 0–100 com color zones (green/yellow/red), HRV RMSSD, RHR, sleep performance; alimentado por `DailyMetric.recovery`
- [x] **UI-04**: Sleep card na Sleep view — duração, eficiência, stacked bar com fases (REM/Deep/Light/Awake); alimentado por `CachedSleepSession.stagesJSON` via `HypnogramView`
- [x] **UI-05**: Strain card na Strain view — day strain score 0–21 com gauge, HR zones breakdown; alimentado por `DailyMetric.strain`

### Algoritmos

- [ ] **ALG-01**: Recovery score (0–100) calculado pelo servidor (`compute_day()`, `recovery.py`) e apresentado na Today view; indicador de staleness quando `lastRefreshedAt` > 6h
- [ ] **ALG-02**: Sleep staging (wake/light/deep/REM por épocas de 30s) calculado pelo servidor (`sleep.py`, Cole-Kripke + HRV) e apresentado na Sleep view
- [ ] **ALG-03**: Strain score (0–21, Edwards TRIMP) calculado pelo servidor (`strain.py`) e apresentado na Strain view
- [ ] **ALG-04**: Endpoint `GET /v1/today?device=<id>` adicionado ao servidor — retorna o `daily_metrics` row mais recente sem edge case de UTC no client

### HealthKit Export

- [ ] **HK-01**: Amostras de HR exportadas para HealthKit (`HKQuantityType(.heartRate)`, unidade `count/min`) após cada ingest/backfill; cursor de highwater em UserDefaults para idempotência
- [ ] **HK-02**: HRV RMSSD exportado para HealthKit (`HKQuantityType(.heartRateVariabilitySDNN)`) por sessão de sono
- [ ] **HK-03**: SpO₂ exportado para HealthKit (`HKQuantityType(.oxygenSaturation)`, valor `0.0–1.0`) — **gateado atrás de PROTO-11 VERIFIED**
- [ ] **HK-04**: Sessões de sono exportadas para HealthKit (`HKCategoryType(.sleepAnalysis)`) com stages `.asleepCore/.asleepDeep/.asleepREM` (iOS 16+); sem sobreposição temporal
- [ ] **HK-05**: Autorização HealthKit pedida lazily na Today view (não em `AppRootCoordinator.init()`); app degrada graciosamente se negada

---

## v3.0 Requirements (Deferred)

- PROTO-02 D-03b: SMP PacketLogger capture (bonding via official app) — requer acção física
- Dual 4.0/5.0 support na mesma app — complexidade desnecessária antes de v2.0 estabilizar
- WHOOP MG ECG pathway — RE virgin territory, milestone separado
- macOS app / watchOS complications
- HealthKit read (importar dados de outras apps) — v2.0 só escreve
- Notificações push de recovery/strain — depende de background processing estável

---

## Out of Scope

- Copiar assets, cores exatas, artwork ou código proprietário do WHOOP — JADX para estrutura de dados e labels apenas
- WHOOP cloud API — local-first by design
- Jailbreak/root para acesso ao IPA iOS — stock devices only
- Validação clínica dos biométricos — uso pessoal/educacional
- Modificação de firmware — RE only

---

## Definition of Done

Um requisito está **Done** quando:
1. O comportamento é observável no dispositivo físico (iPhone + WHOOP 5.0)
2. Para streams biométricos: validado contra ground truth (oxímetro, termómetro, etc.)
3. Para UI: dados reais aparecem no ecrã (não placeholder "—")
4. Para HealthKit: amostras visíveis na app Saúde do iPhone

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BF-01 | Phase 6 | Pending |
| BF-02 | Phase 6 | Pending |
| IOS-03 | Phase 7 | Pending |
| IOS-04 | Phase 7 | Pending |
| IOS-05 | Phase 7 | Pending |
| IOS-08 | Phase 7 | Pending |
| PROTO-11 | Phase 7 | Pending |
| PROTO-12 | Phase 7 | Pending |
| PROTO-13 | Phase 7 | Pending |
| PROTO-14 | Phase 7 | Pending |
| UI-01 | Phase 8 | Pending |
| UI-02 | Phase 9 | Complete |
| UI-03 | Phase 9 | Complete |
| UI-04 | Phase 9 | Complete |
| UI-05 | Phase 9 | Complete |
| ALG-01 | Phase 10 | Pending |
| ALG-02 | Phase 10 | Pending |
| ALG-03 | Phase 10 | Pending |
| ALG-04 | Phase 10 | Pending |
| HK-01 | Phase 11 | Pending |
| HK-02 | Phase 11 | Pending |
| HK-03 | Phase 11 | Pending |
| HK-04 | Phase 11 | Pending |
| HK-05 | Phase 11 | Pending |
