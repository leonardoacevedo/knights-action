---
description: Implementa una feature del GDD de punta a punta — plan, código, tests y doc.
argument-hint: <nombre o descripción de la feature, ej. "sistema de momentum">
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). Plantillas estructuradas, code blocks y la doc final en `docs/features/` van **normales** (humanos los leen en frío).

# /feature — Implementación punta-a-punta de una feature

Vas a implementar una feature del juego siguiendo el flujo oficial del proyecto.

## Feature solicitada
$ARGUMENTS

## Flujo obligatorio

### 1. Comprensión
1. Leé [`CLAUDE.md`](CLAUDE.md) si todavía no lo hiciste en esta sesión.
2. Identificá la sección del [`GDD.md`](GDD.md) que define la feature. Citala por número.
3. Si la feature NO está en el GDD, **pará e invocá `game-designer`** para validar scope antes de seguir.

### 2. Pillar-check
Corré mentalmente `/pillar-check` sobre la feature. ¿Qué pilar refuerza? ¿Contradice alguno?
- Si contradice un pilar → frená y avisá a Leo.
- Si no refuerza ninguno → frená y avisá a Leo.

### 3. Plan corto
Antes de codear, escribí un plan en este formato:

```
FEATURE: <nombre>
GDD §: <sección>
PILAR(ES) REFORZADO(S): <#X #Y>

ARCHIVOS A CREAR:
  - scripts/...
  - resources/...
  - scenes/...
  - tests/...

ARCHIVOS A MODIFICAR:
  - ...

NUEVOS AUTOLOADS (si aplica): ...

INTERACCIÓN CON SISTEMAS EXISTENTES:
  - ...

RIESGOS:
  - ...
```

Si el plan toca más de 2 sistemas core (player.gd, sistemas autoload importantes), **mostrá el plan al usuario y pedí OK** antes de avanzar.

### 4. Delegación a agentes especialistas
Según qué toque la feature:
- Combate / momentum / dash / bloqueo → `combat-system` y/o `godot-expert`.
- Items / refinamiento / fusión → `equipment-system`.
- Niveles / XP / skills → `progression-system`.
- Enemigos R1-R3 → `enemy-ai`.
- Boss R4 → `boss-designer`.
- Coliseo / Ecos → `ecos-coliseum` + `backend-architect` si hay sync.
- UI / HUD → `ux-mobile`.
- Balance numérico → `balance-engineer` para validar.

Si la feature cae claramente en UN dominio, delegá al agente correspondiente vía la tool `Agent` con un prompt autocontenido (incluyendo el plan ya escrito).

### 5. Implementación
- Tipado fuerte (argumentos, retornos, exports).
- Datos en `.tres`, lógica en `.gd`.
- Componentes reutilizables sobre lógica monolítica.
- Señales antes que polling.

### 6. Tests
Si la feature toca:
- Una fórmula → test que la fórmula calcula correcto.
- RNG → test con N alto (10000) que las probabilidades convergen.
- State machine → test que entra/sale de estados según condiciones.

Tests en `tests/<area>/<nombre>_test.gd`.

### 7. Documentación
Creá `docs/features/<nombre-feature>.md` siguiendo el template de [`docs/features/README.md`](docs/features/README.md). Mínimo debe incluir:
- Qué hace.
- Por qué (pilares).
- Cómo se integra con el resto.
- Decisiones técnicas no obvias.
- Cómo testear manualmente.

### 8. Actualizar índices
- Si la feature introduce un término nuevo → actualizar [`.claude/docs/glossary.md`](.claude/docs/glossary.md).
- Si toca números → actualizar [`.claude/docs/formulas.md`](.claude/docs/formulas.md).
- Si afecta el estado de fase → mencionarlo en [`.claude/docs/fases.md`](.claude/docs/fases.md).

### 9. Verificación final
Antes de cerrar:
- `godot --headless --check-only` (vía Bash) si es posible.
- Probar manualmente en Godot Editor si la feature tiene componente visual / de input.
- Si no podés probar manualmente, **decilo explícitamente**: "no testeado en Godot Editor, Leo validar".

## Cierre

```
FEATURE IMPLEMENTADA: <nombre>
PILAR(ES) REFORZADO(S): [...]
ARCHIVOS NUEVOS: [...]
ARCHIVOS MODIFICADOS: [...]
TESTS: [pasaron/pendientes]
DOC: docs/features/<nombre>.md
PRÓXIMO PASO PARA LEO: [qué validar en mobile / Godot Editor]
```
