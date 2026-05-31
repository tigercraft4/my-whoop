---
status: root_cause_found
slug: historico-vazio-sleep-metrics
trigger: "ainda ha problemas na app, nao tenho dados nem no sleep metros workouts etc"
created: 2026-05-31
updated: 2026-05-31
---

# Debug Session: historico-vazio-sleep-metrics

## Symptoms

- **Expected**: Sleep/Metrics/Workouts populam com dados do WHOOP 5.0
- **Actual**: Vistas vazias — sem dados de sono, métricas ou workouts
- **Live view**: HR em tempo real a aparecer (BLE OK — ligação BLE funcional)
- **Backfill**: Nunca apareceram dados históricos (GET_DATA_RANGE / tipo 47 nunca recebido ou processado)
- **Timeline**: Nunca funcionou para dados históricos
- **Reproduction**: Abrir a app com WHOOP ligado; Sleep/Metrics/Workouts vazias apesar do Live view funcionar

## Current Focus

hypothesis: "O servidor não está configurado (Secrets.xcconfig tem placeholders), logo serverSync=nil em toda a app. As vistas de Sleep/Metrics/Workouts dependem EXCLUSIVAMENTE de ServerSync.pullDerived() — não lêem os streams BLE directamente."
next_action: "aplicar fix"
test: ~
expecting: ~
reasoning_checkpoint: "Confirmado por AppConfig.uploaderConfig() que retorna nil quando apiKey=='replace-me' ou url=='https://whoop.example.com'. Com serverSync=nil: pullDerived() é no-op, sleepSession e dailyMetric ficam vazias, e as vistas mostram estado vazio."

## Evidence

- timestamp: 2026-05-31T00:00:00Z
  source: ios/OpenWhoop/Config/Secrets.xcconfig
  data: "WHOOP_BASE_URL = https://whoop.example.com (placeholder); WHOOP_API_KEY = replace-me (placeholder)"
  interpretation: Servidor nunca configurado — AppConfig.uploaderConfig() retorna nil

- timestamp: 2026-05-31T00:00:00Z
  source: ios/OpenWhoop/Config/AppConfig.swift L21-32
  data: "guard key != 'replace-me', urlStr != 'https://whoop.example.com' → return nil"
  interpretation: Quando nil, serverSync=nil em BLEManager e MetricsRepository

- timestamp: 2026-05-31T00:00:00Z
  source: ios/OpenWhoop/Metrics/MetricsRepository.swift L136-148
  data: "refresh() chama serverSync?.pullDerived() — quando nil é no-op completo"
  interpretation: pullDerived() nunca corre → sleepSession e dailyMetric vazias

- timestamp: 2026-05-31T00:00:00Z
  source: ios/OpenWhoop/Upload/ServerSync.swift + WhoopStore/MetricsCache.swift
  data: "sleepSession e dailyMetric só são populadas por upsertSleepSessions/upsertDailyMetrics chamados de pullDerivedWindow()"
  interpretation: Não há caminho local (offline) para popular estas tabelas — dependem 100% do servidor

- timestamp: 2026-05-31T00:00:00Z
  source: ios/OpenWhoop/Collect/Backfiller.swift L136
  data: "store.insert(decoded, deviceId:) guarda hrSample/spo2Sample/etc — NÃO sleepSession/dailyMetric"
  interpretation: O backfill BLE guarda streams crus; as métricas derivadas (sono, recovery, strain) são computadas server-side

## Eliminated

- BLE não funciona: eliminado — Live HR visível confirma ligação OK
- beginBackfill() não dispara: eliminado — lógica presente e correcta (connectHandshakeDone + requestSync(.connect) após 1.5s)
- Frames tipo 47 não chegam: possível mas irrelevante para o problema das vistas vazias (as vistas lêem sleepSession/dailyMetric, não hrSample)
- MetricsRepository query com filtro errado: eliminado — queries correctas, tabelas simplesmente vazias

## Resolution

root_cause: "Secrets.xcconfig tem valores de placeholder (WHOOP_BASE_URL=https://whoop.example.com, WHOOP_API_KEY=replace-me). AppConfig.uploaderConfig() detecta placeholders e retorna nil. Com serverSync=nil, pullDerived() é no-op permanente — as tabelas sleepSession e dailyMetric nunca são populadas. As vistas Sleep/Metrics/Workouts lêem exclusivamente estas tabelas."
fix: ~
verification: ~
files_changed: ~
