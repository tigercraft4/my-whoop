# Requirements — WHOOP 5.0 v4.0

**Project:** my-whoop (WHOOP 5.0)
**Version:** v4.0
**Date:** 2026-06-01

---

## v4.0 Requirements

### Bug Fixes (Data Layer)

- [ ] **BUGFIX-01**: SleepCard e SleepView mostram `sleepNeededMin` (resultado ALG-12) — campo é calculado pelo LocalMetricsComputer mas nenhuma view o exibe actualmente
- [ ] **BUGFIX-02**: SleepCard e RecoveryCard lêem `DailyMetric.sleepPerformance` (ALG-10, score composto 0–100) em vez de `efficiency` (raw 0.0–1.0) — correcção em 2 sítios
- [ ] **BUGFIX-03**: Migration GRDB v10 para purgar/sinalizar valores `avgHrv` armazenados antes do commit e65fa31 (offsets V128 RR incorrectos) — baseline de recovery fica limpo
- [ ] **BUGFIX-04**: Bugs adicionais identificados durante a fase Ghidra RE (GHIDRA-01) — scope concreto definido após análise do IPA

### Ghidra IPA Analysis

- [ ] **GHIDRA-01**: Screen map completo de todos os ecrãs da app oficial WHOOP 5.37.0 via PyGhidra batch extraction + decompilação dirigida — output em `FINDINGS_5.md` e `docs/specs/v4-ui-map.md`; nenhum ficheiro Swift tocado nesta fase; um ecrã por sessão, findings commitados antes de avançar
- [ ] **GHIDRA-02**: Decodar os 8 doubles LE @ `0x1058a5a80` (coeficientes Keytel sex-specific para ALG-13) e validar/corrigir `calories.py` e `LocalMetricsComputer.swift`
- [ ] **GHIDRA-03**: Confirmar offsets V128 para SpO₂ (PROTO-11), skin temp (PROTO-12) e respiration (PROTO-13) via Ghidra + PacketLogger quando hardware disponível

### Repo Cleanup + Device Validation

- [ ] **CLEAN-01**: Reorganizar estrutura de pastas do repositório (Swift ios/, Python server/, RE re/, docs/) sem mudanças de arquitectura; xcodegen generate + xcodebuild build como gate após cada move
- [ ] **CLEAN-02**: Gen4 sweep — grep por 4.0/gen4/Gen4 em todo o codebase; anotar código dual-path intencional (canal 61080005 para dados históricos WHOOP 5.0); remover dead code do WHOOP 4.0
- [ ] **CLEAN-03**: Device type validation — garantir que o código detecta correctamente WHOOP 4.0 vs 5.0 via device_generation quando conectado, e aplica os paths Maverick (5.0) vs Gen4 (4.0) correctos

### UI Redesign 1:1

- [ ] **UI-01**: Actualizar tokens `WH.*` em `DesignTokens.swift` com constantes verificadas no Ghidra (cores hex, espaçamentos, raios de canto) — gate obrigatório antes de qualquer componente
- [ ] **UI-02**: Modificar componentes UI por ecrã (RecoveryCard, SleepCard, StrainCard, TrendsView, e outros identificados em GHIDRA-01) de acordo com o screen map; clean-room — nenhum asset ou pseudocódigo do Ghidra directamente no Swift
- [ ] **UI-03**: Suite de snapshot tests com `swift-snapshot-testing 1.17.6` por ecrã — referências criadas à medida que cada ecrã é implementado, usadas como gate de regressão visual
- [ ] **UI-04**: Testes 1:1 no simulador via XcodeBuildMCP (`snapshot_ui`, `screenshot`) — validação visual interactiva contra referências do Ghidra para confirmar fidelidade antes de VERIFIED

### Hardware Validation (parallel-eligible, hardware-gated)

- [ ] **PROTO-11**: SpO₂ VERIFIED via PacketLogger TOGGLE_IMU_MODE + oxímetro ground truth; schema actualizado de HYPOTHESIS para VERIFIED
- [ ] **PROTO-12**: Skin temperature VERIFIED via PacketLogger TOGGLE_IMU_MODE + termómetro ground truth
- [ ] **PROTO-13**: Respiration rate VERIFIED via PacketLogger TOGGLE_IMU_MODE (12–20 rpm range)

---

## Future Requirements (deferred)

- IOS-03/04: Today/Sleep views com dados reais do WHOOP — requer sessão sem usar app oficial durante 1+ semana
- IOS-08: Background reconnect validado em iPhone físico
- PROTO-14: IMU/gravity VERIFIED (TOGGLE_IMU_MODE, 6-axis)
- Android btsnoop + JADX (Fase 999.1)

## Out of Scope (v4.0)

- Novas features algorítmicas além dos bug fixes identificados
- Mudanças de arquitectura servidor (Python/TimescaleDB mantido como backup)
- WHOOP 4.0 support activo — sweep identifica/remove, não adiciona
- Firmware modification ou escrita para o strap
- Copiar assets, artwork ou pseudocódigo Ghidra para ficheiros Swift (clean-room obrigatório)

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUGFIX-01 | Phase 14 | Pending |
| BUGFIX-02 | Phase 14 | Pending |
| BUGFIX-03 | Phase 14 | Pending |
| BUGFIX-04 | Phase 15 | Pending |
| GHIDRA-01 | Phase 15 | Pending |
| GHIDRA-02 | Phase 15 | Pending |
| GHIDRA-03 | Phase 18 | Pending |
| CLEAN-01 | Phase 16 | Pending |
| CLEAN-02 | Phase 16 | Pending |
| CLEAN-03 | Phase 16 | Pending |
| UI-01 | Phase 17 | Pending |
| UI-02 | Phase 17 | Pending |
| UI-03 | Phase 17 | Pending |
| UI-04 | Phase 17 | Pending |
| PROTO-11 | Phase 18 | Pending |
| PROTO-12 | Phase 18 | Pending |
| PROTO-13 | Phase 18 | Pending |
