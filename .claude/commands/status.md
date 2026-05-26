---
description: Resume el estado actual del proyecto y sugiere el próximo paso según la fase del GDD.
allowed-tools: Read, Glob, Grep, Bash
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). El bloque de reporte estructurado (`═══ ESTADO DEL PROYECTO ═══`) intacto. Lista de items con `✅ ⏳ ⏹` puede ser caveman (fragmentos cortos).

# /status — Estado del proyecto

Vas a generar un reporte breve y accionable del estado del proyecto.

## Flujo

### 1. Leé estos archivos
- [`CLAUDE.md`](CLAUDE.md) (sección "Estado Actual del Proyecto").
- [`.claude/docs/fases.md`](.claude/docs/fases.md).
- [`project.godot`](project.godot) (versión engine, autoloads registrados).
- Listado de `scripts/`, `scripts/components/`, `scripts/systems/`, `resources/`, `scenes/`.
- Últimas entradas de `docs/features/`.

### 2. Detectá la fase
Según §13 del GDD:
- Fase 1: Prototipo de Combate.
- Fase 2: Loop Básico.
- Fase 3: Sistemas RPG Completos.
- Fase 4: Coliseo.
- Fase 5: Pulido y Lanzamiento.

### 3. Generá reporte

```
═══════════════════════════════════════════════
ESTADO DEL PROYECTO — Knights Action
═══════════════════════════════════════════════

FASE ACTUAL: <#X - Nombre>
HITO A ALCANZAR: "<frase del hito>"
% ESTIMADO HACIA EL HITO: <ojo: estimación con datos visibles>

YA HECHO:
  ✅ <ítem 1>
  ✅ <ítem 2>
  ...

EN PROGRESO (en código pero sin docs en docs/features/):
  ⏳ <ítem>
  ...

PENDIENTE PARA EL HITO:
  ⏹ <ítem 1>
  ⏹ <ítem 2>
  ...

PRÓXIMO PASO RECOMENDADO:
  → <una acción concreta + qué agente/comando usar>

FUERA DE SCOPE DE LA FASE ACTUAL (NO DESVIARSE):
  - <items detectados que pertenecen a fases siguientes>

RIESGOS DETECTADOS:
  - <si algo en el código está rompiendo una regla del GDD>
═══════════════════════════════════════════════
```

### 4. Reglas

- **Honesto.** Si algo está mal hecho o desviado, decirlo.
- **Específico.** "Implementar Momentum" es vago. "Crear `scripts/systems/momentum_system.gd` como autoload con signal momentum_changed y aplicar reset on damage en player.gd" es accionable.
- **Una sola recomendación de próximo paso.** No 5 cosas en paralelo — Leo es solo.
- **No proponer features fuera de la fase actual.** Si el usuario quiere acelerar, que lo pida explícito.
