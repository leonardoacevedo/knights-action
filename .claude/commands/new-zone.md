---
description: Diseñá una zona PvE completa (5-8 etapas + boss + lore + drops).
argument-hint: <descripción libre, ej. "zona de Fuego en cráter volcánico, niveles 15-25">
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). Nombres/lore de zona, etapas, materiales delegados a `narrative-lore` se mantienen tal cual (NO caveman — son copy del juego). Plantillas estructuradas intactas.

# /new-zone — Diseñar una zona PvE completa

Las zonas son la unidad mayor de contenido PvE (§7, §10 GDD).

## Input
$ARGUMENTS

## Si falta info, preguntá

1. **Elemento dominante** (Tierra/Fuego/Agua en MVP).
2. **Rango de nivel** (ej. 15-25).
3. **Tema visual / bioma** (volcán, cueva, mar, bosque).
4. **¿Qué la diferencia** de las anteriores en mecánicas y look?
5. **¿Qué nuevo enemigo o mecánica** introduce?

## Flujo

### 1. Delegá a `level-designer` (Agent)
Pasale info clarificada. El agente devolverá la plantilla con:
- Zona overview (paleta, materiales únicos, rango).
- 5-8 etapas con encuentros, pacing, checkpoints.
- Composición de enemigos por etapa (R1, R2, R3 según rango).
- Modo Eco Profundo (variantes).

### 2. Delegá enemigos a `enemy-ai` (Agent) — uno por especie
- R1 de la zona.
- R2 de la zona.
- R3 de la zona.

(Reutilizá especies de zonas anteriores si tiene sentido, pero idealmente 3 especies nuevas por zona.)

### 3. Delegá boss a `boss-designer` (Agent)
El boss R4 del final.

### 4. Delegá naming/lore a `narrative-lore` (Agent)
- Nombre de la zona.
- Nombre de cada etapa (opcional pero recomendado).
- Lore de fondo (1 párrafo).
- Materiales únicos: nombres y flavor.

### 5. Delegá arte a `art-prompt-engineer` (Agent)
- Parallax: 3-5 capas.
- Sprites de enemigos.
- Sprite del boss.
- Tileset del suelo.

### 6. Delegá items a `equipment-system` (Agent) — opcional
Si la zona introduce items específicos (típicamente sí — al menos 1 set drop exclusivo del elemento).

### 7. Validá balance con `balance-engineer`
- TTK promedio en cada etapa coherente con DPS del rango de nivel.
- Drop rates calibrados para que crafteo y refinamiento avancen.
- XP por etapa coherente con curva.

### 8. Generá archivos
```
resources/zones/<nombre_snake>.tres
resources/enemies/<nombre_snake>/*.tres
resources/bosses/<nombre_snake>/*.tres
resources/items/<...>/*.tres (si hay set específico)
resources/materials/<nombre_snake>/*.tres
scripts/enemies/species/<...>.gd (si hay lógica nueva)
scripts/bosses/species/<...>.gd
scenes/zones/<nombre_snake>/stage_01.tscn
scenes/zones/<nombre_snake>/stage_02.tscn
...
scenes/zones/<nombre_snake>/boss_<...>.tscn
```

### 9. Documentá
- `docs/features/zones/<nombre>.md`: zona completa con todos los links a los sub-docs.

## Reglas inviolables

- **Rango de nivel fijo. SIN auto-scaling** (§7.1).
- **5-8 etapas + 1 boss.**
- **Eco Profundo reutiliza arte y layout.** No crear `_eco/` separados.
- **Cada zona tiene materiales únicos** que la identifican.

## Cierre

```
ZONA: <nombre final>
ELEMENTO: <...>
RANGO NIVEL: <N-M>
ETAPAS: <n>
BOSS: <nombre>
ENEMIGOS NUEVOS: [...]
ITEMS NUEVOS: [si aplica]
ARCHIVOS PRINCIPALES: [...]
ASSETS DE ARTE NECESARIOS: [parallax + N sprites + boss]
DOC: docs/features/zones/<nombre>.md
PLAYTEST REQUERIDO: [Leo: jugar 3 veces, cronometrar etapas]
```
