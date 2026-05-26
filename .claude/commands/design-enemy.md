---
description: Diseña un enemigo R1-R3 (sin bosses — usar /design-boss para R4) con stats, IA y .tscn.
argument-hint: <descripción libre, ej. "R2 acuático que bloquea y contraataca">
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). Nombre/lore/bestiario delegados a `narrative-lore` se mantienen tal cual (NO caveman — son copy del juego). Plantillas estructuradas intactas.

# /design-enemy — Diseñar un enemigo PvE

Vas a diseñar un mob estándar (R1, R2 o R3) siguiendo §7.3 del GDD.

## Input
$ARGUMENTS

## Si falta info, preguntá

1. **Rareza:** R1 / R2 / R3.
2. **Zona** donde aparece (define paleta, materiales drop).
3. **Nicho mecánico:** ¿qué le enseña al jugador? (bloquear, esperar telegrafía, dashear, romper guardia).
4. **Rango de nivel** dentro de la zona.
5. **Drops específicos** (qué materiales únicos sueltan).
6. **Tema visual** (especie, look-and-feel).

## Flujo

### 1. Delegá a `enemy-ai` (Agent)
Pasale toda la info clarificada + esta plantilla:

```
ESPECIE: <nombre tentativo>
RAREZA: R<1-3>
ZONA: <zona>
NIVEL: <rango>

STATS:
  - HP: X
  - Daño base: X
  - Defensa: X
  - Resistencia elemental: <elemento opuesto -%, propio +%>

DETECCIÓN:
  - Rango de visión: X px
  - FOV: X°
  - Rango de oído: X px

ATAQUES:
  - Ataque A: telegrafía Xs, daño Y, cooldown Z, alcance W
  - (Ataque B si aplica)
  - (Skill si R3)

COMPORTAMIENTOS POR RAREZA:
  - R1: simple, sin block.
  - R2: block cuando HP<70%, contraataque tras block.
  - R3: skill cada 4-6s, dash de reposicionamiento si jugador<150px.

DROP TABLE:
  - <material 1>: prob X
  - <material 2>: prob Y
  - oro: rango
```

### 2. Delegá nombre/flavor a `narrative-lore` (Agent)
Pedí 3-5 nombres + 3 entradas de bestiario (10/50/100 kills) según template del agente.

### 3. Delegá arte a `art-prompt-engineer` (Agent)
Pasale: especie, rareza, zona, paleta.

### 4. Validá balance con `balance-engineer` (Agent)
Calculá TTK contra DPS de jugador del rango de nivel sugerido. Debe encajar:
- R1: TTK 1-2 s.
- R2: TTK 3-5 s.
- R3: TTK 5-10 s.

### 5. Generá archivos
- `resources/enemies/<zona>/<nombre_snake_case>.tres` (EnemyData).
- `scripts/enemies/species/<nombre_snake_case>.gd` (lógica específica si es necesaria).
- `scenes/enemies/<zona>/<nombre_snake_case>.tscn`.

### 6. Documentá
`docs/features/enemies/<nombre>.md` con: lore, tipo, drops, contraestrategia, telegrafías.

## Cierre

```
ESPECIE: <nombre final>
RAREZA: R<1-3>
ZONA: <...>
ARCHIVOS:
  - resources/...
  - scripts/...
  - scenes/...
PROMPT DE ARTE: [generado / pendiente]
DOC: docs/features/enemies/<nombre>.md
BALANCE: [TTK validado]
```
