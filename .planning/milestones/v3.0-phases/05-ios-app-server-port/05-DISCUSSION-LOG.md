# Phase 5: iOS App & Server Port - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 05-ios-app-server-port
**Areas discussed:** API do decoder Swift, UUID wiring no iOS, Escopo do WhoopStore v8, Migração do servidor, Como será a app

---

## API do decoder Swift

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Substituir em-place | loadSchema() passa a carregar whoop_protocol_5.json. Zero mudanças de assinatura. | ✓ |
| loadSchema5() paralelo | Função separada; app decide qual usar. Requer mudar call sites e singleton. | |
| generation param | loadSchema(generation: .five). Adiciona complexidade ao singleton de caching. | |

**Escolha:** Substituir em-place

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Encapsulada internamente | parseFrame() detecta e strip o Maverick wrapper antes de processar. Call sites não mudam. | ✓ |
| Parâmetro explícito | parseFrame(data:maverick:Bool). Requer mudar BLEManager. | |

**Escolha:** Encapsulada internamente

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Adaptar frames_5_golden.json para XCTest | gen_golden.py gera frames_5.json para WhoopProtocolTests. Reutiliza Fase 4, garante paridade Python↔Swift. | ✓ |
| Fixtures sintéticos novos | gen_synthetic_fixtures.py de raiz. Menos representativos. | |

**Escolha:** Adaptar frames_5_golden.json

---

## UUID wiring no iOS

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Substituir em-place nos Constants | BLEManager e Commands.swift com UUIDs 5.0 (FD4B0001-…). Mais simples para clean fork. | ✓ |
| Lidos do whoop_protocol_5.json | Schema.swift expõe UUIDs GATT; BLEManager carrega-os. Adiciona init async. | |
| AppConfig-driven | AppConfig.gattConfig() retorna UUIDs. Mais flexível mas mais overhead. | |

**Escolha:** Substituir em-place

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| IDs idênticos ao 4.0 — sem mudanças | Fase 4 cruzou r52 map; mesmos IDs funcionais. | |
| Rever o Commands enum completo | Adicionar comandos novos descobertos na Fase 4. | ✓ |

**Escolha:** Rever o Commands enum completo
**Notas:** Descoberto que há 50+ comandos no whoop_protocol_5.json não presentes no enum iOS. Critério de inclusão decidido na pergunta seguinte.

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Só os observados nas captures + já existentes | 10 VERIFIED do Fase 4 + existentes. HYPOTHESIS ficam fora. | ✓ |
| Todos os não-destrutivos do schema 5.0 | Incluir todos os não-DFU/firmware/wipe. | |

**Escolha:** Só os observados nas captures + já existentes

---

## Escopo do WhoopStore v8

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Adicionar gx, gy, gz já (nullable) | Migration v8 adiciona gyro columns nullable. Prontas para tipo 43 na Fase 5. | ✓ |
| Diferir para quando type-43 for observado | Sem mudança agora; migration v9 se necessário. | |

**Escolha:** Adicionar gx, gy, gz já (nullable)

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Desnecessário no iOS | Fork limpo 5.0-only; device_generation vai no servidor. | ✓ |
| Adicionar device_generation no iOS | Consistente com servidor mas redundante. | |

**Escolha:** Desnecessário no iOS

---

## Migração do servidor

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Modificar init.sql diretamente | ALTER TABLE IF NOT EXISTS + DEFAULT '5.0'. Idempotente. Docker fresh-start funciona. | ✓ |
| Ficheiro de migração separado | server/db/v2_device_generation.sql. Mais formal mas overhead para clean fork. | |

**Escolha:** Modificar init.sql diretamente

| Opção | Descrição | Seleccionado |
|-------|-----------|-------------|
| Opcional com default '5.0' | Optional[str] = '5.0' no Pydantic. Clientes antigos continuam a funcionar. | ✓ |
| Obrigatório | Mais estrito; quebra clientes 4.0 no mesmo servidor. | |

**Escolha:** Opcional com default '5.0'

---

## Como será a app

**Resposta livre do utilizador:** "eu quero que a app seja um clone da whoop, talvez seja melhor numa milestone separada?"

**Notas:** O utilizador quer eventualmente uma app com visual equivalente à WHOOP oficial. Clarificado que a Fase 5 entrega um port funcional (dados 5.0 end-to-end com vistas existentes 4.0). O "WHOOP clone" é uma nova capability e fica para milestone v2. O utilizador concordou.

---

## Claude's Discretion

- Estrutura de waves dos planos (Swift decoder → iOS BLE → Store → UI → servidor)
- Adaptação exacta de gen_golden.py para frames_5.json
- Se BackfillPolicy precisa de ajustes para 5.0 (provavelmente não)
- Formato dos gyro samples em extractStreams() quando tipo 43 ausente
- Kill-process test: UAT manual vs. XCTest automatizado

## Deferred Ideas

- **WHOOP clone / redesign UX:** milestone v2 — após Fase 5 validada, com dados 5.0 corretos como pré-condição
- **Raw IMU tipo 43 (PROTO-14):** colunas gyro prontas (D-06); decoder template no schema; promover a VERIFIED quando captura tipo 43 disponível
- **Dual 4.0/5.0 support:** explicitamente fora de âmbito (PROJECT.md)
