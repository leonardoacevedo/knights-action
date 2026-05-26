---
description: Diseña una skill nueva (costo de Furia, efecto, asignable a slot de los 3 botones).
argument-hint: <descripción libre, ej. "skill de Fuego AoE corta">
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). Nombre/descripción delegados a `narrative-lore` se mantienen tal cual (NO caveman). Plantillas estructuradas intactas.

# /design-skill — Diseñar una skill nueva

Las skills se equipan en los 3 slots de skill (§4.2). Consumen Furia (§4.3) y suman al Momentum como el ataque básico.

## Input
$ARGUMENTS

## Si falta info, preguntá

1. **Rama del árbol** que la otorga: Guerrero / Mago / Ágil (o item-exclusive).
2. **Tipo:** Daño directo / Daño elemental / Buff / Debuff / Movilidad / Utilidad.
3. **Elemento** si aplica (Tierra/Fuego/Agua).
4. **Costo de Furia objetivo** (rango típico: 20-50 sobre 100).
5. **Cooldown** sugerido (rango típico: 2-8 s).
6. **¿Activa, cargable o instantánea?**

## Flujo

### 1. Especificación
Definí la skill con esta plantilla:

```
SKILL: <nombre tentativo>
RAMA: <guerrero/mago/agil>
TIPO: <daño/buff/debuff/movilidad>
ELEMENTO: <tierra/fuego/agua/—>

COSTO FURIA: X
COOLDOWN: X s
WINDUP: X ms (instantánea / 100-300 ms si cargada)

EFECTO:
  - Daño X (escalado por momentum y refinamiento de arma si aplica).
  - O: buff de Y por Z s.
  - O: debuff sobre enemigo: W por V s.

INTERACCIÓN CON MOMENTUM:
  - ¿Suma +1 al conectar? (default: SÍ).
  - ¿Multiplica daño por (1 + 0.05*mom)? (default: SÍ).

TARGETING:
  - Auto-hit en cono / proyectil / AoE bajo el jugador / etc.

VISUAL & SFX:
  - Color / partículas / sonido.

TELL PARA ENEMIGOS:
  - ¿Qué ven los Ecos en Coliseo cuando la usás? (debe ser leíble).
```

### 2. Delegá a especialistas
- **`combat-system`:** validar interacción con Momentum/Furia/dash.
- **`balance-engineer`:** validar DPS comparado con otras skills del mismo costo.
- **`narrative-lore`:** nombre y descripción ("Pulsar de Cendra" no "Fireball v2").
- **`art-prompt-engineer`:** icono + efecto visual (partículas).

### 3. Generá archivos
- `resources/skills/<rama>/<nombre_snake_case>.tres` (SkillData).
- Si requiere lógica compleja: `scripts/skills/<nombre_snake_case>.gd`.

### 4. Documentá
`docs/features/skills/<nombre>.md` con:
- Stats finales.
- Builds que la habilitan.
- Sinergias con set bonuses.
- Cómo se siente jugarla.

## Reglas inviolables

- **Toda skill suma a Momentum.** (Salvo decisión expresa con `game-designer`.)
- **Toda skill tiene icono claro** para los 3 botones (delegar a `art-prompt-engineer` y `ux-mobile`).
- **Sin "global cooldown".** Cada slot tiene su propio CD.
- **Sin skills que requieran inputs complejos** (combos de gestos en mobile = no).

## Cierre

```
SKILL: <nombre final>
RAMA: <...>
COSTO/CD: <X furia / Y s>
ARCHIVOS:
  - resources/skills/...
  - scripts/skills/... (si aplica)
ICONO: [generado / pendiente]
DOC: docs/features/skills/<nombre>.md
BALANCE: [validado]
```
