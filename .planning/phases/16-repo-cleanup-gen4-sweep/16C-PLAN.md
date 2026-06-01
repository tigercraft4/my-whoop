---
id: 16C
wave: 3
title: "CLEAN-02 — Gen4 sweep: extrair backfill channel e renomear variáveis"
objective: "Extrair o código 61080005 do BLEManager para BLEManager+BackfillChannel.swift e renomear gen4Service→backfillService, gen4DataNotifChar→backfillDataChar. Corrigir docstring em WhoopProtocol.swift. Nenhum comportamento alterado."
depends_on: [16B]
requirements_addressed: [CLEAN-02]
files_modified:
  - "ios/OpenWhoop/BLE/BLEManager.swift"
  - "ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift"
  - "ios/project.yml"
  - "Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift"
autonomous: true
---

# Plan 16C — CLEAN-02: Gen4 sweep e extracção do backfill channel

## Context

O `BLEManager.swift` tem dois UUIDs "gen4" que são enganosos:
- `gen4Service` (61080001) — service GATT para o canal de backfill histórico
- `gen4DataNotifChar` (61080005) — characteristic de notificação para dados históricos

Estes não são "Gen4 dead code" — são o canal activo que o WHOOP 5.0 usa para enviar dados históricos (type-47 frames). A nomenclatura "gen4" é enganosa porque este canal é usado pelo 5.0.

**D-06 decision**: Extrair para extensão separada e renomear para `backfillService` / `backfillDataChar`.

**D-07 decision**: A docstring `WhoopProtocol.swift` diz "WHOOP 4.0 frame decoder" — corrigir para "WHOOP frame decoder (4.0 and 5.0 historical frames)".

**D-08 decision**: Depois do rename, fazer grep por "gen4/Gen4/4.0" em todo o codebase Swift e remover apenas referências genuinamente dead (sem uso runtime). Referências em testes (HistoricalV24Tests, etc.) são intencionais — não remover.

## Tasks

<task id="16C-T1">
<title>Corrigir docstring em WhoopProtocol.swift</title>
<read_first>
- `Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` — ler antes de editar (confirmar texto actual)
- Ou se já foi movido: `ios/Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift`
</read_first>
<action>
1. Ler o ficheiro para confirmar a docstring actual: `/// OpenWhoop protocol library — schema-driven WHOOP 4.0 frame decoder.`
2. Editar apenas essa linha — substituir por: `/// OpenWhoop protocol library — WHOOP frame decoder (4.0 and 5.0 historical frames).`
3. Não alterar mais nada no ficheiro
4. Verificar: `grep "frame decoder" Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift` (ou caminho em ios/Packages/ se já foi movido)
</action>
<acceptance_criteria>
- `WhoopProtocol.swift` contém `/// OpenWhoop protocol library — WHOOP frame decoder (4.0 and 5.0 historical frames).`
- A string `WHOOP 4.0 frame decoder` já não existe no ficheiro
- Nenhuma outra linha do ficheiro foi alterada
</acceptance_criteria>
</task>

<task id="16C-T2">
<title>Criar BLEManager+BackfillChannel.swift com as constantes renomeadas</title>
<read_first>
- `ios/OpenWhoop/BLE/BLEManager.swift` — ler as linhas 24–28 com as constantes gen4Service e gen4DataNotifChar, e a linha que as usa em `peripheral.discoverServices`
- `ios/OpenWhoop/BLE/BackfillPolicy.swift` — ver padrão de extensão existente no directório BLE/
- `ios/project.yml` — verificar se o xcodegen usa `sources: [OpenWhoop]` recursivo (se sim, o novo ficheiro é detectado automaticamente)
</read_first>
<action>
1. Criar `ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift` com o conteúdo:
```
import CoreBluetooth

/// WHOOP backfill channel — Gen4 GATT service (61080xxx) used by WHOOP 5.0 to deliver
/// historical type-47 frames. Named "gen4" in the GATT spec but actively used by 5.0.
extension BLEManager {
    /// GATT service UUID for the backfill (historical data) channel.
    static let backfillService      = CBUUID(string: "61080001-8D6D-82B8-614A-1C8CB0F8DCC6")
    /// Notification characteristic that delivers historical type-47 frames during backfill.
    static let backfillDataChar     = CBUUID(string: "61080005-8D6D-82B8-614A-1C8CB0F8DCC6")
}
```
2. Verificar: `ls ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift`
3. O novo ficheiro NÃO precisa de ser adicionado ao `project.yml` se o target usa `sources: [OpenWhoop]` recursivo — xcodegen detecta automaticamente. Verificar com `xcodegen generate`.
</action>
<acceptance_criteria>
- `ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift` existe
- Contém `static let backfillService = CBUUID(string: "61080001-8D6D-82B8-614A-1C8CB0F8DCC6")`
- Contém `static let backfillDataChar = CBUUID(string: "61080005-8D6D-82B8-614A-1C8CB0F8DCC6")`
- O ficheiro compila (confirmado pelo build gate no final)
</acceptance_criteria>
</task>

<task id="16C-T3">
<title>Actualizar BLEManager.swift — renomear gen4Service e gen4DataNotifChar e actualizar comentários</title>
<read_first>
- `ios/OpenWhoop/BLE/BLEManager.swift` — ler o ficheiro completo antes de editar; identificar TODAS as ocorrências de `gen4Service`, `gen4DataNotifChar`, e comentários "Gen4/legacy" relativos a 61080005
- `ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift` — confirmar que as novas constantes já existem antes de editar
</read_first>
<action>
1. Em `BLEManager.swift`, remover as duas linhas com as constantes originais (linhas 27–28):
   ```
   static let gen4Service       = CBUUID(string: "61080001-8D6D-82B8-614A-1C8CB0F8DCC6")
   static let gen4DataNotifChar = CBUUID(string: "61080005-8D6D-82B8-614A-1C8CB0F8DCC6")
   ```
2. Remover também o bloco de comentário acima delas (linhas 24–26):
   ```
   // Gen4 / legacy service (61080xxx) — same WHOOP device, different GATT service.
   // Historical DATA frames (type-47) from SEND_HISTORICAL_DATA arrive on 61080005,
   // NOT on FD4B0005, as confirmed by re/sync_openwhoop.py which subscribes 61080005.
   ```
   (O novo comentário está no BLEManager+BackfillChannel.swift)
3. Substituir todas as ocorrências de `BLEManager.gen4Service` por `BLEManager.backfillService`
4. Substituir todas as ocorrências de `BLEManager.gen4DataNotifChar` por `BLEManager.backfillDataChar`
5. Substituir todas as ocorrências de `gen4Service` (sem prefixo) por `backfillService`
6. Substituir todas as ocorrências de `gen4DataNotifChar` (sem prefixo) por `backfillDataChar`
7. Actualizar comentário inline na `didUpdateValueFor` que diz "Gen4/legacy data channel — historical frames arrive here during backfill." → "Backfill channel — historical type-47 frames arrive here during backfill. The GATT service UUID (61080001) follows the Gen4 spec but is actively used by WHOOP 5.0."
8. Verificar: `grep -n "gen4Service\|gen4DataNotifChar" ios/OpenWhoop/BLE/BLEManager.swift` → deve retornar 0 resultados
</action>
<acceptance_criteria>
- `BLEManager.swift` não contém `gen4Service` nem `gen4DataNotifChar` em nenhum lugar
- `BLEManager.swift` contém referências a `backfillService` e `backfillDataChar` nos mesmos locais onde antes estavam `gen4Service` e `gen4DataNotifChar`
- O comentário "Gen4/legacy data channel" foi actualizado para descrever o backfill channel
- As duas linhas de declaração de constantes foram removidas (agora vivem na extensão)
</acceptance_criteria>
</task>

<task id="16C-T4">
<title>Gen4 sweep — grep e limpar referências dead code restantes</title>
<read_first>
- `ios/OpenWhoop/BLE/BLEManager.swift` — após rename (T3), confirmar que não há mais gen4/Gen4 neste ficheiro além de contexto histórico legítimo
- `ios/OpenWhoop/` — grep por "gen4\|Gen4\|4\.0" em todo o código Swift da pasta ios/
- `ios/OpenWhoopTests/` — grep por "gen4\|Gen4\|4\.0" para identificar testes intencionais
</read_first>
<action>
1. Correr grep geral: `grep -rn "gen4\|Gen4\|WHOOP 4\.0\|whoop_4" ios/OpenWhoop/ --include="*.swift"`
2. Para cada ocorrência, classificar:
   - **Comentário histórico/contexto** (ex: "the Gen4 spec uses...") → deixar, pode clarificar com nota
   - **Referência a protocolo 4.0 em contexto de documentação** → pode actualizar para incluir "5.0" se enganoso
   - **Dead code sem uso runtime** (variável/função nunca chamada) → remover
3. Correr grep em testes: `grep -rn "gen4\|Gen4\|HistoricalV24\|4\.0" ios/OpenWhoopTests/ --include="*.swift"`
   - Testes que testam frames V24 (ex: `HistoricalV24Tests`) são intencionais → NÃO remover
4. Documentar num comentário inline o que foi encontrado e a decisão tomada para cada caso
5. Se zero alterações após T3: commit apenas os ficheiros do T3 com nota "sweep encontrou zero dead code adicional"
</action>
<acceptance_criteria>
- `grep -rn "gen4Service\|gen4DataNotifChar" ios/ --include="*.swift"` → 0 resultados
- Referências "Gen4" restantes são comentários contextuais ou testes intencionais (documentados)
- Nenhum teste foi apagado
- Nenhuma função/variável dead code (sem chamadores) permanece sem decisão documentada
</acceptance_criteria>
</task>

<task id="16C-T5">
<title>Build gate final e commit do sweep completo</title>
<read_first>
- `ios/OpenWhoop/BLE/BLEManager.swift` — verificar estado final após todos os renames
- `ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift` — confirmar que o ficheiro existe e compila
</read_first>
<action>
1. Regenerar projecto Xcode: `cd ios && xcodegen generate`
2. Build gate: `cd ios && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15`
3. Gate deve terminar com `** BUILD SUCCEEDED **`
4. Se falhar com erro de compilação: ler o erro e corrigir (provavelmente referência perdida ou typo no rename)
5. Commit: `git add ios/OpenWhoop/BLE/BLEManager.swift ios/OpenWhoop/BLE/BLEManager+BackfillChannel.swift && git commit -m "refactor: rename gen4Service→backfillService, gen4DataNotifChar→backfillDataChar (CLEAN-02)"`
6. Commit da docstring: `git add Packages/WhoopProtocol/Sources/WhoopProtocol/WhoopProtocol.swift && git commit -m "docs: fix WhoopProtocol docstring — 4.0+5.0 historical frames (CLEAN-02)"`
   (Ou `ios/Packages/...` se o plano 16B moveu os Packages com sucesso)
</action>
<acceptance_criteria>
- `xcodebuild build` termina com `** BUILD SUCCEEDED **`
- `BLEManager+BackfillChannel.swift` está commitado no repo
- `BLEManager.swift` não contém `gen4Service` nem `gen4DataNotifChar`
- `WhoopProtocol.swift` contém "WHOOP frame decoder (4.0 and 5.0 historical frames)"
- Comportamento BLE idêntico ao anterior (apenas renaming — nenhuma lógica alterada)
</acceptance_criteria>
</task>

## Verification

<must_haves>
<truths>
- Nenhuma alteração de comportamento BLE — só renaming e extracção de constantes
- `gen4Service` e `gen4DataNotifChar` já não existem em nenhum ficheiro Swift (excepto possivelmente comentários contextuais documentados)
- `backfillService` e `backfillDataChar` apontam para os mesmos UUIDs (61080001 e 61080005)
- Build gate passa: `** BUILD SUCCEEDED **`
- Testes HistoricalV24 e outros testes de protocolo 4.0 não foram tocados
</truths>
</must_haves>

**Gate final**: `cd ios && xcodebuild build -scheme OpenWhoop -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5` → `** BUILD SUCCEEDED **`
