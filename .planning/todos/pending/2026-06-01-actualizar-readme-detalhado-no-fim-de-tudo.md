---
created: "2026-06-01T19:50:38.317Z"
title: "Actualizar README detalhado no fim de tudo"
area: docs
files: []
---

## Problem

O README.md do repositório não reflecte o estado actual do projecto após 3 milestones completos (v1.0, v2.0, v3.0) e o início do v4.0. A documentação está desactualizada: não documenta o protocolo Maverick, os algoritmos implementados, como correr a app, como usar o servidor, nem o stack técnico completo.

## Solution

No fim do v4.0 (após todas as fases 14–17 completas), escrever um README.md detalhado que cubra:
- O que é o projecto e para que serve
- Stack técnico (Swift + GRDB + BLE, Python + FastAPI, Ghidra MCP)
- Como instalar e correr (iOS app, servidor, RE toolchain)
- Protocolo Maverick documentado (referência a FINDINGS_5.md)
- Algoritmos implementados (Recovery, Sleep Performance, Training State, Sleep Needed, Calories)
- Estrutura do repositório (após CLEAN-01 de Phase 16)
- Como contribuir / limitações legais (clean-room, D-04)
