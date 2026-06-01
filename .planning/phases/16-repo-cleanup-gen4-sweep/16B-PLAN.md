---
id: 16B
wave: 2
title: "CLEAN-01 — Mover Packages/ para ios/Packages/ (move de alto risco)"
objective: "Mover o SPM local Packages/ para ios/Packages/ e actualizar ios/project.yml para apontar para os novos paths. Gate obrigatório: xcodegen generate + xcodebuild build passa após o move."
depends_on: [16A]
requirements_addressed: [CLEAN-01]
files_modified:
  - "Packages/"
  - "ios/Packages/"
  - "ios/project.yml"
autonomous: true
---

# Plan 16B — CLEAN-01: Mover Packages/ → ios/Packages/ (alto risco)

## Context

Este é o move mais arriscado da fase. O `Packages/` contém dois SPM locais (`WhoopProtocol`, `WhoopStore`) que são referenciados em `ios/project.yml` com paths relativos `../Packages/WhoopProtocol` e `../Packages/WhoopStore`.

Após o move para `ios/Packages/`:
- Os paths ficam `Packages/WhoopProtocol` e `Packages/WhoopStore` (relativos ao directório `ios/`)
- O `ios/project.yml` tem de ser actualizado ANTES de correr `xcodegen generate`
- Se algo correr mal, reverter com `git mv ios/Packages Packages` e restaurar `project.yml`

**IMPORTANTE**: Se o build gate falhar após todas as correcções tentadas, PARAR e documentar. Não forçar. O comportamento actual com `Packages/` na raiz é preferível a um build quebrado.

## Tasks

<task id="16B-T1">
<title>Verificar estado actual e confirmar paths em project.yml</title>
<read_first>
- `ios/project.yml` — verificar exactamente os paths de packages (linhas `path: ../Packages/WhoopProtocol` e `path: ../Packages/WhoopStore`)
- `Packages/WhoopProtocol/Package.swift` — verificar nome do package
- `Packages/WhoopStore/Package.swift` — verificar nome do package
- `ls Packages/` — confirmar estrutura actual
</read_first>
<action>
1. Ler `ios/project.yml` e confirmar os paths actuais de packages:
   - `WhoopProtocol: { path: ../Packages/WhoopProtocol }`
   - `WhoopStore: { path: ../Packages/WhoopStore }`
2. Anotar os paths exactos — serão actualizados na tarefa seguinte
3. Verificar que `ls Packages/` mostra `WhoopProtocol/` e `WhoopStore/` (não há mais sub-pastas)
4. Dry-run: confirmar que `ios/Packages/` não existe ainda: `ls ios/Packages/ 2>&1`
</action>
<acceptance_criteria>
- `ios/project.yml` confirmado com paths `../Packages/WhoopProtocol` e `../Packages/WhoopStore`
- `Packages/` confirmado com exactamente `WhoopProtocol/` e `WhoopStore/`
- `ios/Packages/` não existe ainda
</acceptance_criteria>
</task>

<task id="16B-T2">
<title>Mover Packages/ para ios/Packages/ e actualizar project.yml atomicamente</title>
<read_first>
- `ios/project.yml` — ler o ficheiro completo antes de editar
- `Packages/` — confirmar que git mv funciona de Packages/ para ios/Packages
</read_first>
<action>
1. Mover com git mv: `git mv Packages ios/Packages`
2. Verificar: `ls ios/Packages/` deve mostrar `WhoopProtocol/` e `WhoopStore/`
3. Editar `ios/project.yml` — actualizar a secção `packages:`:
   - `WhoopProtocol: { path: ../Packages/WhoopProtocol }` → `WhoopProtocol: { path: Packages/WhoopProtocol }`
   - `WhoopStore: { path: ../Packages/WhoopStore }` → `WhoopStore: { path: Packages/WhoopStore }`
   - (Paths passam a ser relativos ao directório `ios/`, não à raiz)
4. Verificar edição: `grep "path:" ios/project.yml`
5. Regenerar projecto Xcode: `cd ios && xcodegen generate`
6. Verificar que `xcodegen` terminou sem erros
</action>
<acceptance_criteria>
- `ios/Packages/WhoopProtocol/` e `ios/Packages/WhoopStore/` existem
- `Packages/` já não existe na raiz do repo
- `ios/project.yml` tem `path: Packages/WhoopProtocol` e `path: Packages/WhoopStore`
- `xcodegen generate` termina sem erros (sem mensagens de "package not found")
</acceptance_criteria>
</task>

<task id="16B-T3">
<title>Executar build gate e verificar que o projecto compila com a nova localização dos packages</title>
<read_first>
- `ios/OpenWhoop.xcodeproj/project.pbxproj` — verificar que os paths dos packages foram actualizados pelo xcodegen (contém referências a `Packages/WhoopProtocol`)
</read_first>
<action>
1. Correr o build gate completo:
   `cd ios && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
2. Se BUILD SUCCEEDED: commit `git add ios/project.yml ios/Packages ios/OpenWhoop.xcodeproj && git commit -m "chore: move Packages/ → ios/Packages/, update project.yml paths (CLEAN-01)"`
3. Se BUILD FAILED com erros de package resolution:
   a. Tentar: `cd ios && xcodebuild -resolvePackageDependencies` e depois repetir o build
   b. Se ainda falhar: reverter com `git mv ios/Packages Packages` e restaurar `project.yml` com os paths originais, depois commit "chore: revert Packages/ move — build gate failed, left in root"
   c. Documentar o erro encontrado num comentário no CONTEXT.md
4. Nunca deixar o build quebrado — reverter se necessário
</action>
<acceptance_criteria>
- `xcodebuild build` termina com `** BUILD SUCCEEDED **`
- OU: revert confirmado e `Packages/` restaurado na raiz com build a passar
- Nenhum estado intermédio de build quebrado commitado
- Se sucesso: `ios/Packages/WhoopProtocol/Package.swift` e `ios/Packages/WhoopStore/Package.swift` existem
- Se revert: `Packages/WhoopProtocol/Package.swift` e `Packages/WhoopStore/Package.swift` existem na raiz
</acceptance_criteria>
</task>

## Verification

<must_haves>
<truths>
- Build gate passa (`** BUILD SUCCEEDED **`) após o move
- OU: revert foi feito e build passa com `Packages/` na raiz
- `ios/project.yml` é consistente com a localização actual dos packages
- Nunca há um estado de "build quebrado" commitado
- `git mv` usado (não `cp`/`rm`) — histórico preservado
</truths>
</must_haves>

**Gate final**: `cd ios && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5` → `** BUILD SUCCEEDED **`

**Rollback plan**: `git mv ios/Packages Packages && git checkout ios/project.yml && cd ios && xcodegen generate && xcodebuild build ...`
