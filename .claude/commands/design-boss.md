---
description: Diseña un boss R4 con patrones telegrafiados, fases y BossData .tres.
argument-hint: <descripción libre, ej. "boss de la zona de Fuego, jefe forjador">
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). Nombre/lore del boss delegado a `narrative-lore` se mantiene tal cual (NO caveman — es copy del juego). Plantillas estructuradas intactas. Auto-pausa para warnings de fairness al diseñar patrones.

# /design-boss — Diseñar un boss R4

Bosses son R4 y exclusivamente se diseñan con `boss-designer` (§7.3, §10 GDD).

## Input
$ARGUMENTS

## Si falta info, preguntá

1. **Zona** donde aparece.
2. **Elemento dominante.**
3. **Fantasía** del boss (frase corta: qué tipo de pelea querés).
4. **¿Cuántas fases?** (mínimo 2). Thresholds (típico: 50% HP).
5. **¿Hay alguna mecánica nueva** que se introduce con este boss?
6. **¿Es boss de zona normal o variante "Eco Profundo"?**

## Flujo

### 1. Delegá a `boss-designer` (Agent)
Pasale toda la info clarificada. El agente devolverá la plantilla completa con:
- Stats: HP, defensa, cargas de escudo (2-3).
- Patrones por fase (3-5 cada una) con windup ≥0.5s.
- Tells visuales y de audio por patrón.
- Vulnerabilidades / ventanas de stagger.
- Drops garantizados (1 pieza R3 + materiales exclusivos).

### 2. Delegá nombre/flavor a `narrative-lore` (Agent)
Pedí: 3 opciones de nombre + flavor de bestiario + entrada lore de la zona.

### 3. Delegá arte a `art-prompt-engineer` (Agent)
- Sprite principal (2-4× tamaño del jugador).
- Posibles variantes de fase 2 (color shift, partículas).
- Tells visuales (particles, marcadores AoE).

### 4. Validá con `balance-engineer` (Agent)
- TTK target: 60-180s.
- HP coherente con DPS del rango de nivel.
- Drops alineados con economía de la zona.

### 5. Generá archivos
- `resources/bosses/<zona>/<nombre_snake_case>.tres` (BossData).
- `scripts/bosses/species/<nombre_snake_case>.gd` con state machine de fases.
- `scripts/bosses/patterns/*.gd` para nuevos patrones específicos del boss.
- `scenes/bosses/<zona>/<nombre_snake_case>.tscn`.

### 6. Documentá
`docs/features/bosses/<nombre>.md` debe contener:
- Lore.
- Fases (HP thresholds + patrones).
- Tells por patrón.
- Contra-estrategia.
- Drops garantizados.

### 7. Tests
`tests/bosses/<nombre>_test.gd` con:
- Cambio de fase en HP threshold exacto.
- Patrones respetan windup declarado.
- Reset de combate restaura estado inicial.

## Cierre

```
BOSS: <nombre final>
ZONA: <...>
FASES: <n>
PATRONES TOTALES: <n>
TELEGRAFÍA MÍNIMA: <Xs>
ARCHIVOS:
  - resources/bosses/...
  - scripts/bosses/...
  - scenes/bosses/...
DROPS: <...>
PLAYTEST REQUERIDO: [Leo validar fairness en mobile]
```
