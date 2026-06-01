# Phase 11: HealthKit Export - Context

**Gathered:** 2026-05-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Exportar dados biométricos do WHOOP para a Apple Health: HR samples, HRV, sleep sessions com staging, e SpO₂ (gateado). HealthKit capability + entitlements + plist keys adicionados ANTES de qualquer `import HealthKit` no Swift. Autorização pedida lazily na Today view.

**Entry condition:** Phase 9 (UI construída) + Phase 10 (server data disponível). HealthKit é zero-code actualmente.

**Deliverables:**
1. `ios/project.yml` — `com.apple.developer.healthkit` entitlement + `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` em Info.plist (XcodeGen)
2. `HealthKitExporter` — actor/class que exporta HR, HRV, e sleep sessions (HK-01/02/04)
3. Highwater cursors em UserDefaults (`hk.hrHighwater`, `hk.hrvHighwater`, `hk.sleepHighwater`) para idempotência
4. Autorização HealthKit lazy no `.task` da TodayView — app degrada graciosamente se negada + banner subtil "Health not connected" (uma vez)
5. HK-03 (SpO₂): **omitido** nesta fase — PROTO-11 é HYPOTHESIS; marcado como deferred no VERIFICATION.md
6. Sleep: delete + reinsert por sessão para evitar overlaps

**Out of scope:** SpO₂ export (→ quando PROTO-11 VERIFIED, fase futura), HealthKit read (só escrita), notificações push.

</domain>

<decisions>
## Implementation Decisions

### Setup order (HK-P1 — crítico)

- **D-01:** **XcodeGen project.yml PRIMEIRO, Swift imports DEPOIS** — a ordem é:
  1. Adicionar à secção `capabilities` do `project.yml`: `com.apple.developer.healthkit: {}`
  2. Adicionar à secção `plistEntries` do `project.yml`: `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription`
  3. Correr `xcodegen generate` para regenerar o `.xcodeproj`
  4. SÓ DEPOIS: `import HealthKit` em qualquer ficheiro Swift
  
  **Se esta ordem for invertida: crash garantido no device.** O HK-P1 do STATE.md é uma invariante de segurança — o planeador DEVE enforçar esta ordem nas tarefas.

### HK-03 SpO₂ gate

- **D-02:** **HK-03 completamente omitido nesta fase** — ao critério do planeador (Claude decide). Zero código HealthKit para SpO₂. `VERIFICATION.md` deve marcar HK-03 como `deferred — PROTO-11 HYPOTHESIS`. Quando PROTO-11 for VERIFIED numa sessão futura, implementar HK-03 como fase incremental.

  Rationale: código morto/gateado por flag é pior do que ausência. PROTO-11 pode nunca ser VERIFIED — melhor não ter dead code.

### Auth request timing

- **D-03:** **`.task` modifier em TodayView — lazy quando dados existem:** Pedir autorização HealthKit quando TodayView aparece E `metrics.today != nil` (há dados para exportar). Estrutura:
  ```swift
  .task {
      guard metrics.today != nil else { return }
      await healthKitExporter.requestAuthorization()
  }
  ```

- **D-04:** **Negação → banner subtil "Health not connected" uma única vez.** Banner não bloqueante em TodayView. Deep link para `UIApplication.shared.open(URL(string: "x-apple-health://")!)` ou Settings se o utilizador toca. Após dismiss, não mostrar novamente (flag `hk.authDeniedShown` em UserDefaults).

### Highwater cursors

- **D-05:** **UserDefaults com keys prefixadas `hk.`:**
  - `hk.hrHighwater` — `TimeInterval` (epoch) do último HR sample exportado
  - `hk.hrvHighwater` — `TimeInterval` do último HRV sample exportado  
  - `hk.sleepHighwater` — não usado para sleep (ver D-07 delete+reinsert)
  - Reset em debug: `UserDefaults.standard.removeObject(forKey: "hk.hrHighwater")` via Settings debug section (Phase 7 #if DEBUG precedente)

### Sleep staging e overlaps

- **D-06:** **Sleep stage mapping ao critério do planeador.** Deployment target é iOS 16+, por isso `.asleepCore` (Light), `.asleepDeep` (Deep), `.asleepREM` (REM), `.awake` (Awake) são todos disponíveis. Planeador confirma o mapeamento com base nos HealthKit docs e no staging output de `sleep.py`.

- **D-07:** **Delete + reinsert por sessão para evitar overlaps.** Antes de exportar uma `CachedSleepSession`:
  1. `HKHealthStore.deleteObjects(of: HKCategoryType(.sleepAnalysis), predicate: NSPredicate(format: "startDate >= %@ AND endDate <= %@", session.start, session.end))`
  2. Inserir novos samples para a sessão
  
  Idempotente: re-exportar a mesma sessão não cria duplicados.

### Claude's Discretion

- Semântica exacta do stage mapping Light/Deep/REM/Awake → HealthKit (confirmar com HealthKit docs — `.asleepCore` = NREM1+2 = Light, `.asleepDeep` = NREM3 = Deep)
- Se `HealthKitExporter` é `actor`, `class @MainActor`, ou `struct` (actor preferido para async safety)
- Formato exacto do banner "Health not connected" (InformationBanner? SwiftUI overlay? Alert?)
- Trigger exacto de export (após `pullDerived()` completo? Após backfill? Periódico via timer?)
- HRV export: por amostra de sessão de sono ou daily RMSSD do `DailyMetric`?

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Invariante de segurança (HK-P1 e HK-P2)

- `.planning/STATE.md` §"Blockers / Concerns" — HK-P1 (entitlement antes do import), HK-P2 (SpO₂ = 0.0–1.0 não 0–100)
- `DISCLAIMER.md` — contextualização legal (não relevante para HealthKit mas confirma uso pessoal/educacional)

### XcodeGen

- `ios/project.yml` — adicionar `capabilities` e `plistEntries` aqui PRIMEIRO. Estrutura de exemplo:
  ```yaml
  capabilities:
    com.apple.developer.healthkit: {}
  plistEntries:
    NSHealthShareUsageDescription: "Read your WHOOP biometric data in Apple Health"
    NSHealthUpdateUsageDescription: "Write your WHOOP data to Apple Health"
  ```

### Requirements desta fase

- `.planning/REQUIREMENTS.md` — HK-01, HK-02, HK-03, HK-04, HK-05 (com critérios exactos; HK-03 é deferred)
- `.planning/ROADMAP.md` §"Phase 11" — 6 success criteria (SC-5 sobre HK-03 deferred se PROTO-11 HYPOTHESIS)

### Código iOS relevante

- `ios/OpenWhoop/Tabs/TodayView.swift` — local do `.task` para auth + banner "Health not connected"
- `ios/OpenWhoop/Metrics/MetricsRepository.swift` — `metrics.today`, `lastRefreshedAt`
- `ios/OpenWhoop/Settings/SettingsView.swift` — `#if DEBUG` section para reset de cursors HK (Phase 7 padrão)
- `Packages/WhoopStore/Sources/WhoopStore/` — tabela `hrSample`, `sleepSession` onde os dados a exportar existem

### Padrões de cursor existentes (referência)

- `ios/OpenWhoop/Upload/Uploader.swift` — highwater cursor pattern (`WHERE ts > highwater`) a adaptar para HK export
- `ios/OpenWhoopTests/UploaderTests.swift` — testes de cursor regression (replicar padrão para HKExporterTests)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Uploader` highwater cursor pattern — `UserDefaults` key + `WHERE ts > highwater` GRDB query; adaptar directamente para `hk.hrHighwater`
- `#if DEBUG` SettingsView section (Phase 7) — adicionar reset de cursors HK no mesmo bloco
- `MetricsRepository.today: DailyMetric?` — property já existe (ou será criada na Phase 10); guard para lazy auth

### Established Patterns

- **Highwater via UserDefaults:** `Uploader` e `ServerSync` usam o padrão; `hk.*` keys seguem a mesma convenção
- **Actor isolation:** `WhoopStore` é `actor`; `HealthKitExporter` deve ser `actor` (ou `@MainActor class`) para segurança de concorrência
- **`#if DEBUG` para debug features:** Phase 7 estabeleceu o padrão em SettingsView; usar o mesmo bloco para reset de cursors HK
- **Graceful degradation:** app já degrada graciosamente sem servidor (`AppConfig.uploaderConfig() == nil`); replicar padrão para HealthKit negado

### Integration Points

- `project.yml` → capabilities + plist keys (PRIMEIRO)
- `TodayView.task` → `requestAuthorization()` + banner condicional
- Após `MetricsRepository.refresh()` ou após backfill completo → `HealthKitExporter.export()`
- `SettingsView #if DEBUG` → reset de `hk.*` UserDefaults keys

</code_context>

<specifics>
## Specific Ideas

- **HK entitlement via XcodeGen:** `capabilities: { com.apple.developer.healthkit: {} }` no target do `project.yml`. Regenerar com `xcodegen generate` antes de qualquer código Swift.
- **`HealthKitExporter` actor:** `actor HealthKitExporter { let store = HKHealthStore(); ... }`. Injectado em `MetricsRepository` como opcional (nil quando não autorizado ou em simulator).
- **SpO₂ nota em VERIFICATION.md:** "HK-03: deferred — PROTO-11 is HYPOTHESIS; SpO₂ export will be added in a future session when PROTO-11 is VERIFIED."
- **HRV export sugestão:** HRV RMSSD da `DailyMetric.hrv_rmssd` por sessão de sono — um sample por noite com `startDate = sleepSession.start` e `endDate = sleepSession.end`.

</specifics>

<deferred>
## Deferred Ideas

- **HK-03 SpO₂ export** — deferred até PROTO-11 VERIFIED (capture session com hardware físico)
- HealthKit read (importar dados de outras apps) — fora do v2.0 scope
- Background HealthKit sync (background task para export sem abrir a app) — pós v2.0
- Notificações push quando export completo — pós v2.0

</deferred>

---

*Phase: 11-healthkit-export*
*Context gathered: 2026-05-31*
