# UI: Árbol de Habilidades (`SkillTreeScreen`)

**Fecha:** 2026-05-26
**GDD:** §6 (Skills) / Pilar #1
**Archivos creados:**
- `scripts/ui/skill_tree_screen.gd`
- `scenes/ui/skill_tree_screen.tscn`

**Archivos modificados:**
- `scripts/ui/inventory_screen.gd` — botón SKILLS en header + integración `_get_skill_tree_screen()`

---

## Descripción

Pantalla modal (CanvasLayer layer 28) que permite al jugador ver e invertir puntos de habilidad en el árbol de 30 nodos del `PlayerProgression` autoload. Diseño mobile-first, procedural, patrón idéntico a `RefinementScreen` / `CraftingScreen`.

---

## Wireframe mobile vertical (1080×2400)

```
┌─────────────────────────────────────────────────┐
│ ARBOL DE HABILIDADES    [+100XP]  [Respec]  [X] │  ← Header 80px
│ Nivel 5  ·  XP 320/1118      Puntos: 3           │
├─────────────────────────────────────────────────┤
│  GUERRERO  │     MAGO     │      AGIL            │  ← Tabs 46px
├─────────────────────────────────────────────────┤
│                              │ DETALLE           │
│ TIER 1 — NIVEL BASICO        │ ─────────────── │
│ ┌──────┐ ┌──────┐ ┌──────┐   │ [nombre nodo]   │
│ │ [+]  │ │  OK  │ │      │   │ ─────────────── │
│ │ Icon │ │ Icon │ │ Icon │   │ DESCRIPCION     │
│ │ Nom  │ │ Nom  │ │ Nom  │   │ Texto...        │
│ └──────┘ └──────┘ └──────┘   │ ─────────────── │
│                              │ EFECTOS         │
│ TIER 2 — INTERMEDIO          │ +10 HP Maximo   │
│ ┌──────┐ ┌──────┐            │ +5% Daño        │
│ │      │ │      │            │ ─────────────── │
│ │ Icon │ │ Icon │            │ REQUIERE        │
│ │ Nom  │ │ Nom  │            │ OK  Vitalidad I │
│ └──────┘ └──────┘            │                 │
│                              │                 │
│  [scroll vertical]           │ [expand fill]   │
│                              │ ─────────────── │
│                              │  [DESBLOQUEAR   │
│                              │   · 1 punto]    │
└─────────────────────────────────────────────────┘
```

- **Izquierda:** grid scrollable con tiers (1→5). Cada tier es un HBox de nodos.
- **Derecha (185px fijo):** detalle del nodo seleccionado + botón DESBLOQUEAR.
- **Tabs:** 3 botones full-width que filtran el grid por rama.

---

## Estados visuales por nodo (64×64 dp mínimo)

| Estado | Borde superior | Fondo | Ícono alpha | Badge |
| :--- | :--- | :--- | :--- | :--- |
| **Desbloqueado** | Dorado `#ffcb28` | dorado 18% | 1.0 | "OK" dorado |
| **Disponible** | Verde `#4de173` | verde 12% | 1.0 | "+" verde |
| **Bloqueado** | Gris `#66666b` | gris oscuro | 0.4 | (ninguno) |

---

## Tabs de ramas

| Rama | Color activo | Texto tab |
| :--- | :--- | :--- |
| Guerrero | Rojo/marrón `#e64d40` | GUERRERO |
| Mago | Azul/violeta `#7350f2` | MAGO |
| Ágil | Verde/amarillo `#4dda59` | AGIL |

Tab activo: borde inferior 3px color rama + fondo 28% opacidad.
Tab inactivo: borde inferior 2px 22% opacidad + fondo 7%.

---

## Flujo de desbloqueo

1. Jugador toca un nodo → DetailPanel se llena.
2. Si `can_unlock(id)` → botón `DESBLOQUEAR · N punto(s)` habilitado.
3. Si puntos insuficientes → botón deshabilitado + mensaje "Necesitás N puntos".
4. Si prereq faltante → botón deshabilitado + mensaje "Prerrequisito no cumplido".
5. Nodo ya desbloqueado → botón dice "YA DESBLOQUEADO", disabled.
6. Click `DESBLOQUEAR` → `PlayerProgression.unlock_node(id)`:
   - Si `true`: burst visual dorado (0.45s) + `_refresh_node_visual` + actualiza header + refresca todos los nodos (puede haber más disponibles).
   - Si `false`: toast "No se pudo desbloquear."

---

## Flujo de Respec

1. Click `Respec N/10 Hierba` (texto dinámico con count actual).
2. Si no hay nodos desbloqueados → toast "No hay nada que respecar."
3. Si `hierba < 10` → toast "Necesitás N Hierba más."
4. Si condiciones OK → diálogo de confirmación (no se puede tap en fondo para cerrar).
5. Confirmar → flash de reset (grid fade a 15% y vuelve) → `PlayerProgression.respec()` → signal `respec_done` → `_refresh_all()`.
6. Cancelar → `_hide_respec_dialog()`.

---

## Trigger de apertura

Botón **SKILLS** (violeta) en el header de `InventoryScreen`, entre el spacer derecho del título y el botón FORJA. Hit area: 104×52 dp.

Patrón de resolución idéntico a `CraftingScreen`:
1. `skill_tree_screen_path` en Inspector.
2. Búsqueda en árbol por `SkillTreeScreen`.
3. Instanciación de `res://scenes/ui/skill_tree_screen.tscn`.

---

## Señales conectadas

```gdscript
PlayerProgression.level_up.connect(_on_level_up)
PlayerProgression.skill_unlocked.connect(_on_skill_unlocked)
PlayerProgression.respec_done.connect(_on_respec_done)
PlayerProgression.stats_changed.connect(_on_stats_changed)
PlayerProgression.xp_gained.connect(_on_xp_gained)
```

---

## Botón debug

Botón `+100 XP` visible solo si `GameConfig.DEBUG_ENEMY_AI == true`. Llama `PlayerProgression.add_xp(100)`.
**TODO: remover antes de producción.**

---

## Decisiones técnicas

### Conexiones de prereqs — no hay líneas entre nodos
El spec sugería "líneas o número de tier". Se eligió **número de tier** + **sección REQUIERE en DetailPanel** con colores rojo/verde por cumplimiento. Razones:
- Líneas entre nodos en Godot requieren `draw_line` en `_draw()` de un Control, que invalida el canvas en cada frame si los nodos se mueven al scrollear → costoso en mobile.
- El tier estructura implícitamente la dependencia: tier 2 requiere algo de tier 1.
- La sección REQUIERE con colores es más legible en pantalla chica que líneas finas.

### Grid procedural por tier (no GridContainer)
Se usa `VBoxContainer` de tiers, cada tier es un `Control` con `HBoxContainer` anclado. Razones:
- `GridContainer` requiere saber el número de columnas fijo, pero el conteo de nodos por tier varía.
- El patrón de `HBox` por tier permite alinear nodos a la izquierda naturalmente en mobile.

### Refresco selectivo vs. reconstrucción
- `_refresh_node_visual(id)` actualiza un nodo individual sin reconstruir el grid (post-unlock).
- `_refresh_node_grid()` reconstruye todo (post-respec, cambio de tab, level_up con posible nuevo tier disponible).
- `_refresh_all_node_visuals()` recorre `_node_buttons` dict y actualiza estado de cada uno (post-unlock, para propagar prereqs cumplidos).

### Tamaño del panel de detalle (185px fijo)
En portrait 1080px, el panel ocupa ~185/900px ≈ 20% del ancho del panel modal. El grid ocupa el resto. En pantallas más angostas (720px ancho total, panel = 604px), el detalle sigue siendo usable: 185/604 ≈ 30%.

---

## TODOs

- [ ] Reemplazar `ColorRect` de íconos de nodos por `TextureRect` con sprites de skills (delegar a `art-prompt-engineer`).
- [ ] Agregar SFX al desbloquear nodo y al respec (delegar a audio designer).
- [ ] Visualización de conexiones prereq con líneas (si el feedback del playtest pide más claridad visual).
- [ ] Remover botón `+100 XP` debug antes de producción.
- [ ] Validar en celular real — **no testeado en mobile**, validá vos con dispositivo Android/iOS.
- [ ] Si `PlayerProgression.RESPEC_GOLD_COST` deja de ser 0, actualizar texto del diálogo de respec.

---

## Smoke checks sugeridos

1. Abrir inventario → tap SKILLS → árbol abre con tab Guerrero activo.
2. Con `DEBUG_ENEMY_AI` activo, tap `+100 XP` → header actualiza nivel/XP.
3. Nivel sube → `_on_level_up` dispara → puntos badge "+N" parpadea.
4. Tap nodo raíz disponible → DetailPanel muestra nombre, descripción, efectos, "Ninguno (nodo raíz)".
5. Click DESBLOQUEAR → burst dorado → nodo cambia a borde dorado + badge "OK" → puntos -1.
6. Tap nodo con prereq faltante → "FALTA  NombrePrereq" en rojo en sección REQUIERE.
7. Respec: sin Hierba → toast. Con 10 Hierba → diálogo → confirmar → todos los nodos vuelven a gris → puntos restaurados.
8. Escape estando abierto el diálogo de respec → cierra solo el diálogo (no la pantalla).
