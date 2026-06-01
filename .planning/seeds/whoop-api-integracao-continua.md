---
name: whoop-api-integracao-continua
title: "Integração WHOOP API contínua"
trigger_condition: "Após Fase 18.1.1 (dump histórico) completada E quando houver decisão sobre renovar premium ou usar Developer API tier gratuito"
planted_date: "2026-06-01"
related_phase: "999.3"
---

## Ideia

Após o dump histórico imediato (Fase 18.1.1), integrar a WHOOP Developer API de forma contínua:
- Sync automático diário de Recovery/Sleep/Strain processados
- WHOOP Age e Healthspan actualizados regularmente
- Complement ao BLE local — API para dados processados, BLE para tempo real

## Referência

- Repo: https://github.com/shashankswe2020-ux/whoop-mcp (14 endpoints, OAuth2 PKCE implementado)
- Fase 999.3 no backlog — promover quando trigger activar
