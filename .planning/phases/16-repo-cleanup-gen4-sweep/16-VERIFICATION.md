---
phase: 16
status: passed
verified_at: 2026-06-01
requirements: [CLEAN-01, CLEAN-02, CLEAN-03]
plans_verified: [16A, 16B, 16C, 16D]
must_haves_score: 4/4
---

# Verification — Phase 16: Repo Cleanup + Gen4 Sweep

**Goal**: Repository structure is reorganised and WHOOP 4.0 dead code is removed, so UI diffs in Phase 17 stay clean and review-able.

## Verification Result: PASSED

All 4 success criteria met. All 3 requirements addressed. Build gate passed throughout.

---

## Success Criteria Verification

### SC-1: Pastas reorganizadas sem alterações de arquitectura; build gate após cada move

**Status: PASSED**

| Move | Source | Destination | Build Gate |
|------|--------|-------------|------------|
| docs/protocol/ | protocol/ | docs/protocol/ | ✓ BUILD SUCCEEDED |
| docs/findings/ | FINDINGS_5.md + FINDINGS.md | docs/findings/ | ✓ BUILD SUCCEEDED |
| server/dashboard/ | dashboard/ | server/dashboard/ | ✓ BUILD SUCCEEDED |
| re/ghidra/ | APPS IOS APK/ + bridge_mcp_ghidra.py | re/ghidra/ | ✓ BUILD SUCCEEDED |
| ios/Packages/ | Packages/ | ios/Packages/ | ✓ BUILD SUCCEEDED |

**Evidence:**
- `ls /` → raiz contém apenas: `docs/`, `ios/`, `re/`, `server/`, `scripts/`, `README.md`, etc. (sem protocol/, dashboard/, Packages/, FINDINGS*.md)
- `xcodebuild build` → `** BUILD SUCCEEDED **` em todos os gates e no gate final

### SC-2: Gen4 sweep — backfill channel anotado; dead code removido

**Status: PASSED**

- `grep -rn "gen4Service\|gen4DataNotifChar" ios/ --include="*.swift"` → **0 resultados**
- `backfillService` e `backfillDataChar` definidos em `BLEManager+BackfillChannel.swift`
- UUIDs preservados: `61080001` (service) e `61080005` (characteristic)
- Docstring de `WhoopProtocol.swift` actualizada: "WHOOP frame decoder (4.0 and 5.0 historical frames)"
- Comentário inline no `didUpdateValueFor` actualizado para "Backfill channel"
- Testes intencionais (HistoricalV24Tests, etc.) não foram tocados

### SC-3: Device-type detection distingue WHOOP 4.0 vs 5.0 via device_generation

**Status: PASSED**

- `enum DeviceGeneration { case gen4, gen5 }` em `WhoopStore.swift` (público, Codable, Sendable)
- `BLEManager.inferGeneration(hardwareRevision: "WG50_r52")` → `.gen5` (lógica verificada)
- `BLEManager.inferGeneration(hardwareRevision: "other")` → `.gen4`
- `applyGenerationRouting()` chamado em `runConnectHandshake()` — stub documenta paths gen4/gen5
- `detectedGeneration` defaults para `.gen5` — comportamento WHOOP 5.0 actual inalterado

### SC-4: Full build e testes passam; sem regressão comportamental

**Status: PASSED**

- `xcodebuild build` final → **BUILD SUCCEEDED** (3.1s)
- Nenhuma alteração de lógica BLE (apenas renaming e extracção de constantes)
- `applyGenerationRouting()` para `.gen5` apenas adiciona um log — zero mudança de comportamento
- Os paths Maverick (FD4B0002/0003/0005) são exactamente os mesmos de antes

---

## Requirements Coverage

| Requirement | Description | Status |
|-------------|-------------|--------|
| CLEAN-01 | Reorganizar estrutura de pastas | ✓ Completo |
| CLEAN-02 | Gen4 sweep — renomear canal backfill, remover dead code | ✓ Completo |
| CLEAN-03 | Device type validation — detect gen4 vs gen5 | ✓ Completo |

---

## Must-Haves Check

| Must-Have | Result |
|-----------|--------|
| git mv usado para todos os moves (histórico preservado) | ✓ |
| Build gate passa após cada move individual | ✓ |
| gen4Service/gen4DataNotifChar removidos de todo o código Swift | ✓ |
| backfillService/backfillDataChar apontam para UUIDs correctos | ✓ |
| DeviceGeneration enum é público e funciona | ✓ |
| Comportamento WHOOP 5.0 idêntico ao anterior | ✓ |
| IPA de 304MB não commitado | ✓ |

---

## Commits da Fase

```
3ca9258 docs(16): create phase 16 plan — CLEAN-01/02/03
8c301e8 chore: move protocol/ → docs/protocol/ (CLEAN-01)
f30450c chore: move FINDINGS*.md → docs/findings/ (CLEAN-01)
86a0185 chore: move dashboard/ → server/dashboard/ (CLEAN-01)
9fa8e3b chore: move RE artifacts → re/ghidra/ (CLEAN-01)
b333b7c chore: gitignore Ghidra APPS/ and workspace files
73d3e41 chore: move Packages/ → ios/Packages/ + update project.yml (CLEAN-01)
61c8e40 refactor: rename gen4Service→backfillService, gen4DataNotifChar→backfillDataChar (CLEAN-02)
065ac63 docs: fix WhoopProtocol docstring (CLEAN-02)
accc0ef feat: add DeviceGeneration enum to WhoopStore (CLEAN-03)
ffa6be4 feat: add generation detection stub and routing in BLEManager (CLEAN-03)
```
