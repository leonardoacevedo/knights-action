---
description: Diseña un item nuevo (Arma / Armadura / Escudo) con afijos y entregalo como Resource .tres.
argument-hint: <descripción libre del item, ej. "arma R2 tierra para build físico">
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). Nombre/lore del item delegados a `narrative-lore` se mantienen tal cual (NO caveman — son copy del juego). Plantillas estructuradas intactas.

# /design-item — Diseñar un item nuevo

Vas a diseñar un item siguiendo las reglas del §5 del GDD.

## Input
$ARGUMENTS

## Si falta info, preguntá

Pedí al usuario cualquier dato faltante antes de avanzar:
1. **Slot:** Arma / Armadura / Escudo.
2. **Rareza:** R1 / R2 / R3 (R4 está fuera del MVP).
3. **Elemento:** Tierra / Fuego / Agua.
4. **Zona donde aparece** (define materiales requeridos, paleta de naming).
5. **¿Empuja qué build?** (push hacia físico, elemental, defensivo, dash-heavy).

## Flujo

### 1. Delegá a `equipment-system` (Agent)
Pasale el input + datos clarificados + esta plantilla a llenar:

```
ITEM: <nombre tentativo>
SLOT: <weapon/armor/shield>
RAREZA: R<1-3>
ELEMENTO: <earth/fire/water>
ZONA ORIGEN: <zona>

STATS BASE:
  - Daño: X (si arma)
  - Defensa: X (si armadura)
  - Cargas de escudo: X (si escudo: R1=0, R2=1, R3=2)
  - HP/Def pasivos extra: X (si escudo R3)

AFIJOS (cantidad según rareza: R1=1, R2=2, R3=3):
  - Afijo 1: <stat> <valor> <peso>
  - ...

EFECTO ESPECIAL (solo R3, menor):
  - ...

MATERIALES DE CRAFTEO:
  - X de Madera Ancestral
  - Y de Núcleos de Tierra
  - Z oro
```

### 2. Delegá nombre/flavor a `narrative-lore` (Agent)
Pasale: slot, rareza, elemento, zona. Pedí 3-5 opciones de nombre + 1 línea de flavor para la recomendada.

### 3. Delegá arte a `art-prompt-engineer` (Agent) si el item es R3 o destacado
Pasale: tipo de item (icono), descripción visual, rareza (para tint).

### 4. Validá balance con `balance-engineer` (Agent)
Mostrale stats y afijos. Pedí confirmación de que no rompe DPS/TTK del tier.

### 5. Generá el `.tres`
Creá el archivo en `resources/items/<slot>/<nombre_snake_case>.tres`. Usá la clase de datos correspondiente (`WeaponData`, `ArmorData`, `ShieldData`).

Si las clases de datos todavía no existen, **stoppea** y avisá que primero hay que implementar `equipment-system` (ver agente).

### 6. Documentá
- Doc en `docs/features/items/<nombre>.md` con: stats, afijos, lore, prompt de arte usado, zona de drop.
- Si introduce afijo nuevo, agregalo a un archivo `resources/items/affixes/`.

## Cierre

```
ITEM: <nombre final>
SLOT / RAREZA / ELEMENTO: <...>
ARCHIVO: resources/items/<slot>/<nombre>.tres
PROMPT DE ARTE: [generado / pendiente]
DOC: docs/features/items/<nombre>.md
BALANCE: [validado por balance-engineer]
```
