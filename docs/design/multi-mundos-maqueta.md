# Maqueta — Múltiples Mundos (jerarquía Mundo → Zona → Etapa)

> **Pedido de Leo (29/05):** las zonas+etapas actuales forman "un mundo"; debería haber MUCHOS mundos para que el juego no sea corto. Maquetear la estructura + veredicto de complejidad (hoy solo existe un `world.tscn`).
> **Estado:** dirección CONFIRMADA por Leo (29/05). Implementación post Fase 3. GDD vigente v2.2.
> **Decisiones cerradas:** muchos mundos (jerarquía Mundo→Zona→Etapa) · **mapa de mundos** para seleccionar (§2.4) · **desbloqueo lineal** (vencer un mundo habilita el siguiente). Pendientes menores: MW1 (datos), MW3 (mecánicas nuevas), MW5 (timing).

---

## TL;DR — Veredicto de complejidad

**NO es complicado de implementar la ESTRUCTURA.** El "solo hay un `world.tscn`" **no es un problema** — ese archivo es el **renderer** (la escena que dibuja la zona activa), no es "un mundo". Hoy ya se reusa para las 4 zonas. Agregar Mundos = **un nivel más de índice en los datos + routing**, reusando el mismo `world.tscn`. **No se crean N escenas.**

| Capa | Costo |
|---|---|
| **Motor / código** | **BAJO-MEDIO** — ~3 archivos (`stage_manager.gd`, `world.gd`, un selector de mundo en UI). Sin escenas nuevas. Backward-compatible. |
| **Contenido** | **ALTO por mundo** — cada mundo = sus zonas × etapas × backgrounds × bosses × lore × drops. Pero ESE es el objetivo (más contenido = juego más largo). |

El engineering es chico y se hace una vez. El costo real es contenido — que es exactamente lo que alarga el juego.

---

## 1. Cómo funciona HOY (importante entenderlo)

- **`scenes/world.tscn`** = una sola escena **renderer**. En `_ready` lee `StageManager.current_zone`, carga las etapas de esa zona y las corre. **No es "un mundo"** — es el contenedor que dibuja lo que toque.
- **`StageManager.current_zone`** (1-4) + **`ZONE_STAGE_PATHS`** = dict `{ zona_id: [paths de etapas .tres] }`.
- **Etapa** = un `StageData.tres`.
- **Chaining** (`world.gd:_on_run_completed`): `next_zone = current_zone + 1`; si `ZONE_STAGE_PATHS.has(next_zone)` → `set_zone(next)` + recarga `world.tscn`; si no → menú.

```
HOY:   (Mundo implícito único) → Zona (1..4) → Etapa
                                  ↑ current_zone + ZONE_STAGE_PATHS
       world.tscn = renderer reusado por cada zona
```

→ Ya existe la noción "una run = la lista de etapas de UNA zona, renderizada por world.tscn". El "Mundo" como agrupador de zonas **todavía no existe** — hay un único mundo implícito (zonas 1-4, o 1-7 con la expansión).

## 2. Propuesta — agregar la capa Mundo

```
PROPUESTA:   Mundo (1..N) → Zona (1..M) → Etapa
              ↑ current_world      ↑ current_zone
       world.tscn = MISMO renderer, reusado por cada (mundo, zona)
```

### 2.1 Cambio de datos (el corazón, y es chico)

**Opción A — dict anidado (rápido, MVP):**
```gdscript
# HOY en stage_manager.gd:
var current_zone: int = 1
const ZONE_STAGE_PATHS := { 1: [...], 2: [...], 3: [...], 4: [...] }

# PROPUESTA — un nivel más:
var current_world: int = 1
var current_zone: int = 1
const WORLD_DATA := {
    1: {
        "name": "El Imperio Caído",
        "level_band": [1, 60],
        "zones": { 1: [...etapas...], 2: [...], 3: [...], 4: [...] },  # las zonas de hoy
    },
    2: {
        "name": "<Mundo 2>",
        "level_band": [55, 120],
        "zones": { 1: [...], 2: [...], ... },
    },
}
# get_stages_for(world, zone) := WORLD_DATA[world]["zones"][zone]
```

**Opción B — `WorldData` Resource (.tres) (recomendada para escalar):**
Sigue la convención del proyecto (CLAUDE.md §5: "datos en `.tres`, no hardcodear"). Un custom Resource:
```
WorldData (.tres):
  id: int
  display_name: String           # "El Imperio Caído"
  level_band: Vector2i           # [min, max] nivel
  zones: Array[ZoneData]         # cada ZoneData = nombre + Array[StageData] + elemento + boss
  unlock_requirement: ...        # ej. completar mundo anterior
```
Un registro `WORLDS: Array[WorldData]` (o un dir `resources/worlds/`). Esto saca los paths hardcodeados del `.gd` y deja el contenido como data pura — más limpio y editable desde el inspector.

### 2.2 Cambios de routing (chicos)

- **StageManager:** `current_world` + `set_world(id)`. `get_stages_for_zone(z)` → `get_stages_for(world, zone)`. `reset()` igual.
- **`world.gd:_on_run_completed`** — el chaining gana un nivel:
  ```
  al morir el último boss de la zona:
    si hay zona siguiente en ESTE mundo → set_zone(zona+1), recargar world.tscn
    si no, y hay mundo siguiente        → set_world(mundo+1), set_zone(1), recargar world.tscn
    si no                                → "juego completado", menú
  ```
- **UI:** un **selector de Mundo** (y dentro, selector de Zona). MainMenu setea `current_world` + `current_zone` antes de cargar `world.tscn`. Puede ser un mapa tipo K&D (mundos como nodos en un mapa).

### 2.3 Lo que NO cambia
- **`world.tscn`** — intacto, se reusa para cada (mundo, zona). No hay escenas nuevas.
- **Sistemas** — combate, elementos, shards, rareza, skills, set bonus: todos se reusan tal cual. Los mundos son más CONTENIDO sobre los mismos sistemas (cero sistemas nuevos si no querés).
- **StageData / Etapa** — mismo schema.

### 2.4 Mapa de Mundos (UI — CERRADO, decisión Leo 29/05)

La selección de mundo es un **mapa de mundos**: cada mundo es un **nodo** en un mapa navegable (estilo Knights & Dragons / mapa de campaña), no una lista plana.

- **Desbloqueo lineal (CERRADO):** hay que **vencer un mundo para habilitar el siguiente**. Mundo N+1 arranca bloqueado hasta completar el boss final del Mundo N.
- **Estado visual por nodo:** bloqueado (oscuro + candado), disponible (iluminado), completado (check / estrella). Muestra nombre + banda de nivel del mundo.
- **Flujo:** MainMenu → Mapa de Mundos → tap en un mundo desbloqueado → (selector de zona dentro del mundo, o entra a su zona 1) → `set_world` + `set_zone` → carga `world.tscn`.
- **Persistencia:** el progreso (qué mundos están completados/desbloqueados) se guarda en el save existente (un set de `world_id` completados). El desbloqueo se deriva: Mundo N disponible si N==1 o Mundo N-1 completado.
- **Mobile-friendly:** nodos grandes tappables, scroll horizontal del mapa, sin texto chico.

Dentro de un mundo, las **zonas** ya se encadenan automáticamente (chaining §2.2) — el mapa de mundos es solo la capa de arriba. Opcional: un sub-mapa de zonas dentro de cada mundo (post-MVP).

## 3. Migración (cero pérdida)

Las zonas actuales (1-4, o 1-7 con la expansión elemental) se envuelven como **Mundo 1 = "El Imperio Caído"**. `current_zone` sigue igual dentro del mundo. `current_world` default 1. Backward-compatible: si no se setea mundo, juega Mundo 1 = comportamiento actual.

## 4. Ejemplo de estructura escalable

| Mundo | Tema | Zonas | Banda nivel |
|:--:|:--|:--|:--|
| **1** | El Imperio Caído | 7 (Normal→Agua→Fuego→Tierra→Viento→Luz→Sombra, la expansión) | 1-60 |
| **2** | *(nuevo — ej. otro reino/era)* | N zonas con su propio arco | 55-120 |
| **3** | *(nuevo)* | … | 115-180 |

Cada mundo: su propio arco de lore, su roster de bosses, su banda de nivel (sin auto-scaling, GDD §7.1), drops escalados. Reusa elementos/shards/rareza/skills. Eco Profundo (GDD §7.2) aplica por zona dentro de cada mundo → aún más replay.

## 5. Cómo compone con lo ya diseñado

- La **expansión elemental 7 zonas** ([expansion-elemental-7-zonas.md](expansion-elemental-7-zonas.md)) = el contenido del **Mundo 1**. La capa Mundo va POR ENCIMA, no la reemplaza.
- Rareza 7-tier, shards, set bonus, skills con nivel → se reusan en todos los mundos. Mundos más altos = rarezas/elementos más altos disponibles, bandas de nivel mayores.
- Mundos nuevos podrían (opcional, más diseño) introducir mecánicas/elementos nuevos — pero NO es obligatorio; con solo escalar contenido ya alarga el juego.

## 6. Decisiones abiertas

| ID | Decisión | Default propuesto |
|:--:|:--|:--|
| MW1 | ¿Dict anidado (A) o `WorldData` Resource (B)? | **B** — Resource, sigue convención del proyecto, escala mejor |
| ~~MW2~~ ✅ | ¿Mundos lineales o libres? | **CERRADA: lineal — vencer el boss final de un mundo habilita el siguiente.** |
| MW3 | ¿Mundos nuevos reusan elementos/sistemas, o introducen mecánicas nuevas? | reusar (cero sistemas nuevos al inicio); mecánicas nuevas = diseño aparte |
| ~~MW4~~ ✅ | UI de selección | **CERRADA: mapa de mundos (cada mundo un nodo, bloqueado/disponible/completado). Detalle §2.4.** |
| MW5 | ¿Cuándo se implementa? | **post Fase 3** (es estructura de escala; Fase 3 cierra con 1 mundo jugable) |

## 7. Recomendación

La capa Mundo es **barata de codear y backward-compatible** — buen candidato para una Fase 4+ (o un "Fase 3.5" estructural). **No bloquea ni complica Fase 3** (que cierra con Mundo 1 jugable). El trabajo grande es siempre el CONTENIDO de cada mundo nuevo, no el engine. La estructura propuesta (Opción B + chaining de 2 niveles) está lista para especificar a detalle cuando se priorice.
