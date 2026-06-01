---
id: 16A
wave: 1
title: "CLEAN-01 — Mover documentação, RE e dashboard para pastas lógicas"
objective: "Reorganizar pastas de documentação e RE usando git mv, sem tocar em código Swift ou Packages/. Gate: build passa após cada move."
depends_on: []
requirements_addressed: [CLEAN-01]
files_modified:
  - "docs/protocol/"
  - "docs/findings/"
  - "server/dashboard/"
  - "re/ghidra/"
  - "FINDINGS_5.md"
  - "FINDINGS.md"
  - "protocol/"
  - "dashboard/"
  - "APPS IOS APK/"
  - "bridge_mcp_ghidra.py"
autonomous: true
---

# Plan 16A — CLEAN-01: Mover documentação, RE e dashboard

## Context

A raiz do repo tem ficheiros de documentação e RE misturados com o código iOS. As pastas `docs/`, `server/` e `re/` já existem — apenas faltam as sub-pastas destino. Este plano move tudo excepto `Packages/` (risco alto — plano 16B).

Ordem de moves (do menos arriscado para o mais arriscado):
1. `protocol/` → `docs/protocol/` (documentação pura, sem impacto no build)
2. `FINDINGS_5.md` + `FINDINGS.md` → `docs/findings/` (markdowns, sem impacto)
3. `dashboard/` → `server/dashboard/` (Python/web, sem impacto no build iOS)
4. `APPS IOS APK/` + `bridge_mcp_ghidra.py` → `re/ghidra/` (arquivos RE, sem impacto)

Gate após CADA move: `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10`

## Tasks

<task id="16A-T1">
<title>Criar pastas destino e mover protocol/ para docs/protocol/</title>
<read_first>
- `docs/` — verificar se existe e o que contém
- `protocol/` — verificar o que contém antes de mover
- `ios/project.yml` — confirmar que não referencia protocol/
</read_first>
<action>
1. Criar `docs/findings/` se não existe: `mkdir -p docs/findings`
2. Mover: `git mv protocol docs/protocol`
3. Verificar: `ls docs/protocol/`
4. Run build gate: `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10`
5. Gate deve terminar com `** BUILD SUCCEEDED **`
6. Commit: `git commit -m "chore: move protocol/ → docs/protocol/ (CLEAN-01)"`
</action>
<acceptance_criteria>
- `docs/protocol/` existe com os mesmos conteúdos de `protocol/`
- `protocol/` já não existe na raiz
- `git mv` preserva o histórico (verificável com `git log docs/protocol/ --follow`)
- Build gate: `xcodebuild build` termina com `BUILD SUCCEEDED`
</acceptance_criteria>
</task>

<task id="16A-T2">
<title>Mover FINDINGS_5.md e FINDINGS.md para docs/findings/</title>
<read_first>
- `FINDINGS_5.md` — confirmar que existe na raiz
- `FINDINGS.md` — confirmar que existe na raiz
- `ios/project.yml` — confirmar que não referencia estes ficheiros
- `ios/OpenWhoop/BLE/BLEManager.swift` — verificar se referencia FINDINGS_5.md em comentários (só leitura — não editar agora)
</read_first>
<action>
1. `git mv FINDINGS_5.md docs/findings/FINDINGS_5.md`
2. `git mv FINDINGS.md docs/findings/FINDINGS.md`
3. Verificar: `ls docs/findings/`
4. Run build gate: `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10`
5. Gate deve terminar com `** BUILD SUCCEEDED **`
6. Commit: `git commit -m "chore: move FINDINGS*.md → docs/findings/ (CLEAN-01)"`
</action>
<acceptance_criteria>
- `docs/findings/FINDINGS_5.md` e `docs/findings/FINDINGS.md` existem
- Os dois ficheiros já não existem na raiz do repo
- `git log docs/findings/FINDINGS_5.md --follow` mostra histórico
- Build gate: `** BUILD SUCCEEDED **`
</acceptance_criteria>
</task>

<task id="16A-T3">
<title>Mover dashboard/ para server/dashboard/</title>
<read_first>
- `dashboard/` — verificar o que contém
- `server/` — verificar se já tem sub-pasta dashboard
- `ios/project.yml` — confirmar ausência de referência a dashboard/
</read_first>
<action>
1. `git mv dashboard server/dashboard`
2. Verificar: `ls server/dashboard/`
3. Run build gate: `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10`
4. Gate deve terminar com `** BUILD SUCCEEDED **`
5. Commit: `git commit -m "chore: move dashboard/ → server/dashboard/ (CLEAN-01)"`
</action>
<acceptance_criteria>
- `server/dashboard/` existe com conteúdos de `dashboard/`
- `dashboard/` já não existe na raiz
- Build gate: `** BUILD SUCCEEDED **`
</acceptance_criteria>
</task>

<task id="16A-T4">
<title>Mover APPS IOS APK/ e bridge_mcp_ghidra.py para re/ghidra/</title>
<read_first>
- `APPS IOS APK/` — verificar o que contém (APKs/IPAs para análise RE)
- `bridge_mcp_ghidra.py` — verificar conteúdo
- `re/` — verificar estrutura existente
- `ios/project.yml` — confirmar ausência de referências
</read_first>
<action>
1. Criar `re/ghidra/` se não existe: `mkdir -p re/ghidra`
2. Mover APK folder (com espaço no nome): `git mv "APPS IOS APK" re/ghidra/APPS`
3. Mover bridge script: `git mv bridge_mcp_ghidra.py re/ghidra/bridge_mcp_ghidra.py`
4. Verificar: `ls re/ghidra/`
5. Run build gate: `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10`
6. Gate deve terminar com `** BUILD SUCCEEDED **`
7. Commit: `git commit -m "chore: move RE artifacts → re/ghidra/ (CLEAN-01)"`
</action>
<acceptance_criteria>
- `re/ghidra/APPS/` existe com os conteúdos de `APPS IOS APK/`
- `re/ghidra/bridge_mcp_ghidra.py` existe
- `APPS IOS APK/` e `bridge_mcp_ghidra.py` já não existem na raiz
- Build gate: `** BUILD SUCCEEDED **`
</acceptance_criteria>
</task>

## Verification

<must_haves>
<truths>
- Todos os `git mv` usados (não `cp`/`rm`) — histórico preservado
- Build gate passa (`** BUILD SUCCEEDED **`) após cada move individual
- Nenhum ficheiro Swift foi modificado neste plano
- `ios/project.yml` não foi alterado (não referencia nenhum dos itens movidos)
</truths>
</must_haves>

**Gate final**: `cd ios && xcodegen generate && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5` → `** BUILD SUCCEEDED **`
