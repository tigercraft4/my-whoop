---
plan: 16A
phase: 16
status: complete
started: 2026-06-01T21:16:00Z
completed: 2026-06-01T21:18:00Z
---

# Plan 16A Summary — CLEAN-01: Mover documentação, RE e dashboard

## What Was Built

Reorganização de pastas de documentação e RE na raiz do repositório usando `git mv` (e `mv` para ficheiros untracked). Build gate passou após cada move individual.

## Tasks Completed

| Task | Description | Result |
|------|-------------|--------|
| 16A-T1 | `protocol/` → `docs/protocol/` | ✓ git mv + BUILD SUCCEEDED |
| 16A-T2 | `FINDINGS_5.md` + `FINDINGS.md` → `docs/findings/` | ✓ git mv + BUILD SUCCEEDED |
| 16A-T3 | `dashboard/` → `server/dashboard/` | ✓ git mv + BUILD SUCCEEDED |
| 16A-T4 | `APPS IOS APK/` + `bridge_mcp_ghidra.py` → `re/ghidra/` | ✓ mv + BUILD SUCCEEDED |

## Deviations

- `APPS IOS APK/` era untracked (não estava no git), portanto `git mv` falhou — usado `mv` simples e `git add` para rastrear `bridge_mcp_ghidra.py`. O IPA (304MB) foi adicionado ao `.gitignore` com a entrada `re/ghidra/APPS/`.
- Adicionado `.gitignore` para ficheiros Ghidra workspace (`*.gpr`, `*.rep`, `*.lock`) em `re/ghidra/`.

## Commits

- `chore: move protocol/ → docs/protocol/ (CLEAN-01)`
- `chore: move FINDINGS*.md → docs/findings/ (CLEAN-01)`
- `chore: move dashboard/ → server/dashboard/ (CLEAN-01)`
- `chore: move RE artifacts → re/ghidra/ (CLEAN-01)`
- `chore: gitignore Ghidra APPS/ and workspace files in re/ghidra/ (CLEAN-01)`

## Key Files

### key-files.created
- `docs/protocol/` (3 ficheiros: README.md, whoop_protocol.json, whoop_protocol_5.json)
- `docs/findings/` (2 ficheiros: FINDINGS.md, FINDINGS_5.md)
- `server/dashboard/` (6 ficheiros: server.py, static/, whoop_fields.py, etc.)
- `re/ghidra/` (bridge_mcp_ghidra.py + APPS/ untracked)

## Self-Check: PASSED

- Todos os `git mv` usados para ficheiros tracked
- Build gate passou (BUILD SUCCEEDED) após cada move individual
- Nenhum ficheiro Swift modificado
- `ios/project.yml` não alterado
- IPA de 304MB não comitado — adicionado ao `.gitignore`
