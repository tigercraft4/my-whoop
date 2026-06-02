---
created: 2026-06-02T22:32:54.094Z
title: Analisar Goose — UI e protocolo (Puffin/tipos 51-56)
area: general
files: []
---

## Problem

Fork identificado: https://github.com/tigercraft4/goose (original: b-nnett/goose)

**⚠️ DESCOBERTA CRÍTICA: Protocolo — não é só UI!**

O Rust core (Rust/core/src/protocol.rs) documenta packet types e device types que não temos:

### Packet types novos (desconhecidos para nós)
- **Tipo 37**: PUFFIN_COMMAND
- **Tipo 38**: PUFFIN_COMMAND_RESPONSE
- **Tipo 51**: REALTIME_IMU_DATA_STREAM
- **Tipo 52**: HISTORICAL_IMU_DATA_STREAM
- **Tipo 53**: RELATIVE_PUFFIN_EVENTS
- **Tipo 54**: PUFFIN_EVENTS_FROM_STRAP
- **Tipo 55**: RELATIVE_BATTERY_PACK_CONSOLE_LOGS
- **Tipo 56**: PUFFIN_METADATA

### Device type "Puffin" — nova geração WHOOP!
```rust
pub enum DeviceType { Gen4, Maverick, Puffin, Goose }
```
O "Puffin" usa o mesmo framing de 8 bytes que o Maverick (WHOOP 5.0). Provavelmente WHOOP 6.0 ou variante próxima. Ainda não documentado por nós.

O Goose é um cliente local-first para WHOOP 5.0 muito semelhante ao nosso projecto. Pontos-chave:

- **UI inspirada no Bevel** (https://www.bevel.health/) — as superfícies de Sleep, Recovery, Strain, Stress e trend-detail são referência visual directa
- **Arquitectura diferente da nossa**: Rust core (processamento biométrico) + Swift/SwiftUI shell, em vez de Python/Swift
- **Ecrãs implementados**: Home, Health (Sleep, Recovery, Strain, Stress, Cardio Load, Energy Bank, Health Monitor), Coach, More/Debug
- **Beta público**: 13 de Junho de 2026 no TestFlight — em 11 dias
- **iOS 26 SDK** — usa APIs mais recentes (incluindo Live Activity extension para workouts)
- **Decisão de design**: tabs Home / Health / Coach / More (diferente do nosso Home / Saúde / Comunidade / Mais / WHOOP)

**Relevância para o nosso redesign:**
- Ver como o Bevel organiza métricas de saúde (Sleep, Recovery, Strain) para inspirar a nossa HealthView
- Comparar a estrutura de tabs e navegação
- O ecrã "Health Monitor" cobre HRV, RHR, SpO₂ — exatamente o que temos na nossa HealthView
- O "Coach" é uma ideia nova que não temos (resumo com IA das métricas locais)

## Solution

1. Quando o beta lançar em 13 Jun: instalar no TestFlight e tirar screenshots dos ecrãs principais
2. Comparar side-by-side com o nosso HomeView, HealthView, e ecrãs de métricas
3. Identificar patterns de UI que possamos adoptar (especialmente layouts de trend-detail)
4. Verificar como tratam a ausência de dados (Coach explica missing data — boa UX)
5. Considerar adicionar uma tab/secção "Coach" ao nosso roadmap v5.0

Repositório a monitorizar: https://github.com/b-nnett/goose
