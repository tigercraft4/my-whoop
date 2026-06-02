# Phase 20: Goose UI Foundation — Context

**Gathered:** 2026-06-03
**Status:** Ready for planning
**Milestone:** v5.0 — Goose UI Migration + Ecosystem

---

## Decisão de direcção

Após análise do repositório https://github.com/b-nnett/goose (fork: tigercraft4/goose) e visualização
do app em simulador, o utilizador decidiu **migrar toda a UI para o estilo Goose/Bevel em dark mode**.

**O que se mantém:**
- BLE stack (WhoopProtocol / WhoopStore) — não se toca
- Algoritmos locais (LocalMetricsComputer) — mantém-se
- Servidor local — downgraded para backup opcional apenas

**O que muda:**
- Design system completo: dark-first, Bevel-inspired
- Estrutura de tabs: Home / Health / Coach / More (igual ao Goose)
- Todas as superfícies de métricas reimplementadas no novo estilo
- Servidor deixa de ser dependência primária

---

## Referência visual — Goose (observado em simulador)

### Home tab
- 3 rings circulares: Sleep (roxo/azul) · Recovery (verde) · Strain (laranja)
- Coach card com "Ask Coach" button azul
- Stress & Energy section com ring de stress
- Cardio Load card
- Fundo cinza muito claro (#F2F2F7 light / ~#1C1C1E dark)
- Tab bar: casa · saúde · estrela · mais

### Health tab
- Grid 2×2 de cards: Sleep · Recovery · Strain · Stress
- Cada card tem valor "--" quando sem dados, cor temática
- Health Monitor section (HRV, RHR, SpO₂, temperatura)
- Trend charts por métrica

### Coach tab
- "Close the data gaps first" — estado vazio com checklist de requisitos
- "Chat signed out" card com Sign In
- Metric Highlights section (Sleep · Recovery · Strain · Stress em grid 2×2)
- Usa OpenAI API para streaming (opcional)

### More tab
- "Good evening, [name]" greeting com Update Profile
- Device section — WHOOP band, connection, battery
- App section — Apple Health Profile
- Settings section — Privacy
- Support section

---

## Paleta de cores do Goose (light — observado)

```
Background:      #F2F2F7 (iOS systemGroupedBackground)
Card background: #FFFFFF
Tab bar:         branca com ícones cinza/preto
Accent azul:     #007AFF (botões primários)
Sleep:           roxo/lavanda (#7B68EE ou similar)
Recovery:        verde (#34C759 ou similar)
Strain:          laranja (#FF9500 ou similar)
Stress:          amarelo (#FFCC00 ou similar)
```

**Para dark mode** (o que queremos):
```
Background:      #000000 ou #1C1C1E
Card background: #2C2C2E
Tab bar:         #1C1C1E
Text primário:   #FFFFFF
Text secundário: #8E8E93
Accent azul:     #0A84FF (dark variant)
```

---

## Estrutura de tabs a implementar

| Tab | Ícone Goose | Conteúdo |
|-----|------------|----------|
| Home | casa | Rings + Coach card + Stress & Energy + Cardio Load |
| Health | saúde/coração | Grid métricas + Health Monitor + Trends |
| Coach | estrela/spark | Coach AI (local metrics summary) |
| More | três pontos | Profile · Device · Settings · Privacy · Support |

---

## Decisões de implementação

### D-01: Dark mode por defeito
`preferredColorScheme(.dark)` como default global no `RootTabView`.
Toggle em More > Settings para permitir light.

### D-02: Botão W (LiveView)
O botão W (acesso BLE ao strap) passa a ser um item no More > Device em vez de botão flutuante.
O LiveView abre a partir de Device, não da tab bar.

### D-03: Tab Coach — implementação offline-first
Coach mostra resumo das métricas locais sem IA.
OpenAI sign-in é opt-in para respostas em streaming.
Sem sign-in: mostra "Local Coach" com análise determinística.

### D-04: Servidor → backup apenas
`ServerSync.pullDerived()` continua a ser chamado (já implementado).
Upload de dados continua (já implementado).
Mas a UI **nunca bloqueia** em dados do servidor — sempre offline-first.
Secção "Sync" em More > Settings mostra estado de upload.

### D-05: Typography
SF Pro como base (iOS default).
Títulos de secção em uppercase tracking (estilo Goose).
Números de métricas em `.largeTitle` bold.

---

## Referência de código Goose útil

Para cada superfície, os ficheiros Swift relevantes:

| Superfície | Ficheiro Goose |
|-----------|---------------|
| Home shell | `GooseSwift/AppShellView.swift` |
| Home content | `GooseSwift/HomeView.swift` + `Home*.swift` |
| Health grid | `GooseSwift/HealthView.swift` + `Health*.swift` |
| Coach | `GooseSwift/CoachView.swift` + `Coach*.swift` |
| More | `GooseSwift/MoreView.swift` |
| Design tokens | rever via inspecção do app em simulador |

Repo local: `~/Documents/goose/`

---

## O que NÃO fazemos (fora de scope v5.0)

- **Não portamos o Rust core** — a nossa stack Swift é melhor para nós
- **Não adoptamos a arquitectura JSON-bridge** do Goose
- **Não removemos o servidor** — só o downgrademoss para backup
- **Coach com OpenAI** — fase 22, não fase 20
