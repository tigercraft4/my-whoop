# API Endpoints — WHOOP 5.37.0

**Extraído via:** Ghidra MCP (search_strings sobre binário ARM64, 151k funções)
**Data:** 2026-05-31

---

## Base URL

```
https://api.prod.whoop.com
```

QA/staging: `https://api-7.qa.whoop.com`

---

## Autenticação

**Sistema:** AWS Cognito + auth-service WHOOP próprio

### Endpoints de auth
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/auth-service/v2/whoop/sign-in` | POST | Login com email/password |
| `/auth-service/v2/whoop/refresh` | POST | Refresh token |
| `/auth-service/v2/whoop/sign-out` | POST | Logout |
| `/auth-service/v2/whoop/forgot-password` | POST | Reset password |
| `/auth-service/v2/whoop/change-password` | POST | Alterar password |
| `/auth-service/v2/whoop/nuke` | DELETE | Apagar conta |
| `/auth-service/v2/oauth/code/` | GET | OAuth code flow |
| `/auth-service/v3/whoop` | - | v3 auth base |

**Tokens:**
- `app.whoop.tokens` — UserDefaults key para tokens guardados
- `app.whoop.user.info` — UserDefaults key para info do utilizador
- `ProvisionalAuthorizationToken` / `ProvisionalAuthorizationTokenExpiresAt` — tokens temporários
- AWS Cognito MFA via `CognitoAuthService` (ficheiro: `WhoopAuth/Sources/WhoopAuth/APIService/CognitoAuthService.swift`)

---

## Serviços de Dados Biométricos (relevantes para o clone)

### Metrics Service — Upload de dados
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/metrics-service/v1/metrics` | POST | Upload de métricas gerais |
| `/metrics-service/v1/metrics/sensor` | POST | Upload de dados de sensor (HR, SpO2, etc.) |
| `/metrics-service/v1/metrics/user/` | GET | Métricas do utilizador |
| `/metrics-service/v1/research` | POST | Upload para research |

### Research Metrics — Upload biométrico raw
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/research-metrics-service/v1/research/upload` | POST | Upload dados de research |
| `/research-metrics-service/v1/imu/upload` | POST | Upload dados IMU |
| `/research-metrics-service/v1/optical/upload` | POST | Upload dados ópticos (SpO2, PPG) |
| `/pip-metrics-service/v1/pip/upload` | POST | PIP (Physiological Indicator Protocol) upload |

### Coaching Service — Algoritmos
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/coaching-service/v1/coaching/strain/optimal/mapping/cycle/` | GET | Training State lookup (recovery_to_strain.json source) |
| `/coaching-service/v1/performance-assessment/` | GET | Performance assessment |
| `/coaching-service/v2/sleepneed` | GET | Sleep Needed calculation |
| `/coaching-service/v1/sleepneed/onboarding` | GET | Sleep need onboarding |
| `/coaching-service/v1/sleepneed/onboarding?userId=` | GET | Sleep need onboarding por utilizador |
| `/coaching-service/v1/tile-dismissal` | POST | Dismissal de tiles |

### Core Details BFF
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/core-details-bff/v1/start-activity/strain` | POST | Iniciar actividade com strain |
| `/core-details-bff/v2/activity-type/user-created` | GET | Tipos de actividade custom |
| `/core-details-bff/v0/create-activity` | POST | Criar actividade |
| `/core-details-bff/v2/sleep-details/nap-to-sleep/` | GET | Nap → Sleep credit (referenciado em Sleep Needed) |

### HR Zones Service
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/hr-zones-service/v1/bff/zones` | GET | HR zones do utilizador |
| `/hr-zones-service/v1/bff/settings` | GET | Configurações HR zones |
| `/hr-zones-service/v1/bff/custom` | POST | HR zones customizadas |

### Activities Service
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/activities-service/v1/sports/history` | GET | Histórico de desportos |
| `/activities-service/v2/activities` | GET | Lista de actividades |
| `/activities-service/v2/activity-types` | GET | Tipos de actividade |

### Activity Settings
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/activity-settings-bff/v1/maxhr` | GET/POST | HRmax do utilizador |
| `/activity-settings-bff/v1/maxhr/estimate/` | GET | Estimativa HRmax |

### Candidate Service (Apple Health integration)
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/candidate-service/v1/applehealthkit/heartrate` | POST | Enviar HR do HealthKit para WHOOP |
| `/candidate-service/v1/applehealthkit/mindful-session` | POST | Sessões mindfulness |

### Users Service
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/users-service/v1/users/` | GET | Info do utilizador |
| `/users-service/v2/bootstrap` | GET | Bootstrap da app (dados iniciais ao arrancar) |

### Smart Alarm BFF
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/smart-alarm-bff/v1/schedule` | GET | Schedule do alarme inteligente |
| `/smart-alarm-bff/v1/schedule/components` | GET | Componentes do schedule |
| `/smart-alarm-bff/v1/schedule/components/populated/` | GET | Componentes preenchidos |
| `/smart-alarm-bff/v1/schedule/all` | GET | Todos os schedules |

### Outros serviços relevantes
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/firmware-service/v3/firmware/check` | GET | Verificar firmware WHOOP |
| `/firmware-service/v3/firmware/latest` | GET | Firmware mais recente |
| `/log-service/v1/log/strap` | POST | Logs da strap |
| `/gps-service/v1/gps?userId=` | GET | Dados GPS |
| `/strap-location-service/v1/garment/user/input` | POST | Localização da strap no corpo |

### Membership / Billing (não essencial para clone)
- `/membership-service/v1-v3/*` — Subscrição, billing, planos
- `/commerce-service/v2/mobile/carts/*` — E-commerce in-app
- `/social-service/v1/*` — Features sociais, Strava integration
- `/community-service/v1/*` — Comunidades
- `/journal-service/v3/*` — Diário de comportamentos

---

## Adaptação para Servidor Docker Local

### O que a app envia → como adaptar

| Fluxo WHOOP | URL WHOOP | Adaptar para |
|-------------|-----------|--------------|
| Auth (login) | `/auth-service/v2/whoop/sign-in` | Mock auth local — retornar token fixo |
| Auth (refresh) | `/auth-service/v2/whoop/refresh` | Mock refresh local |
| Bootstrap | `/users-service/v2/bootstrap` | Retornar perfil do utilizador local |
| Upload biometrics | `/metrics-service/v1/metrics` | Redirect para `/v1/ingest-decoded` local |
| Sensor data | `/metrics-service/v1/metrics/sensor` | Mapear para ingest local |
| Sleep Needed | `/coaching-service/v2/sleepneed` | Calcular localmente e retornar |
| Training State | `/coaching-service/v1/coaching/strain/optimal/mapping/cycle/` | Servir `recovery_to_strain.json` |
| HRmax | `/activity-settings-bff/v1/maxhr` | Retornar HRmax guardado localmente |
| HR zones | `/hr-zones-service/v1/bff/zones` | Retornar zones calculadas localmente |
| Bootstrap | `/users-service/v2/bootstrap` | Retornar perfil local |

### Headers necessários (baseado em análise)
- `Authorization: Bearer <token>` (obtido via `/auth-service/v2/whoop/sign-in`)
- `x-amz-api-version` (AWS API Gateway)
- `Content-Type: application/json`

---

## Sleep Needed — Componentes Confirmados

Do binário (string keys encontradas):
```
SleepNeeded.Baseline      → Baseline sleep need (rolling avg)
SleepNeeded.RecentStrain  → Strain-based additional need
SleepNeeded.SleepDebt     → Accumulated debt
SleepNeeded.RecentNaps    → Nap credit (negative)
```

Fórmula: `sleep_needed = Baseline + RecentStrain + SleepDebt - RecentNaps`

Endpoint: `GET /coaching-service/v2/sleepneed` → retorna todos os componentes

---

## Confidence

| Item | Confiança | Método |
|------|-----------|--------|
| Base URL `api.prod.whoop.com` | HIGH | String literal directa no binário |
| Auth endpoints `/auth-service/v2/whoop/*` | HIGH | String literals directas |
| AWS Cognito para MFA | HIGH | Class name + file path no binário |
| Metrics upload `/metrics-service/v1/metrics` | HIGH | String literals directas |
| Sleep Needed 4 componentes | HIGH | String keys `SleepNeeded.*` no binário |
| Training State endpoint | HIGH | String literal + recovery_to_strain.json |
| HR zones endpoint | HIGH | String literal `/hr-zones-service/v1/bff/zones` |
| Payload formats (JSON fields) | LOW | Requer intercepção de tráfego real |
