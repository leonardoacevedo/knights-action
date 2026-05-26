# UI de Crafteo (Forja)

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (ux-mobile) con dirección de Leo
**Fase del proyecto:** 2 — Loop Básico
**Sección GDD relevante:** §5.5 Sistema de Crafteo
**Pilar(es) reforzado(s):** #1 (mi build importa) / #2 (nada oculto, siempre sabés qué falta)

---

## Qué hace

Pantalla modal (`CanvasLayer` layer 26) que permite al jugador craftear items a partir de materiales drop. Muestra todas las recetas disponibles, el estado de disponibilidad de materiales en tiempo real, y ejecuta el crafteo con una animación corta de feedback. El crafteo en MVP es 100% determinístico: si tenés los materiales, funciona.

## Por qué (pilares)

**Pilar #1 — Mi build importa, mi skill también:**
- El jugador elige qué item craftear con los materiales que tiene, moldeando su build.
- Cinco recetas en MVP cubren los tres slots (arma, armadura, escudo) en rarezas R1-R3.

**Pilar #2 — Nada debe sentirse aleatorio o injusto:**
- Cada material requerido muestra "disponible / necesario" con color verde/rojo.
- Si faltan materiales, el botón FORJAR está deshabilitado con mensaje explicativo.
- El crafteo no consume nada si las precondiciones fallan (transacción atómica del backend).

## Cómo se integra

```
InventoryScreen (abierto)
  └── Botón "FORJA" en el header
        → InventoryScreen.close()
        → CraftingScreen.open()

CraftingScreen
  └── Llama CraftingSystem.try_craft(recipe)
      ├── Éxito → InventorySystem.add_item(output_item)
      └── Aborto → mensaje de razón sin consumir nada
```

## Archivos

| Archivo | Rol |
| :--- | :--- |
| `scripts/ui/crafting_screen.gd` | Lógica completa (procedural, sin layout en .tscn) |
| `scenes/ui/crafting_screen.tscn` | Escena mínima — solo nodo raíz + script |
| `scripts/ui/inventory_screen.gd` | Modificado: @export `crafting_screen_path`, botón FORJA en header, `_get_crafting_screen()`, `_find_crafting_screen_in_tree()` |

## Layout mobile vertical (1080×2400 referencia)

```
┌──────────────────────────────────────────┐
│  FORJA                              [X]  │  ← header 56dp, botón X 64×56dp
├─────────────────┬────────────────────────┤
│  RECETAS        │  RESULTADO             │
│  ┌───────────┐  │  ┌──────────────────┐  │
│  │[R2] Esc.  │  │  │ [icono 72×72]    │  │
│  │Hierro  OK │  │  │ Escudo de Hierro │  │
│  ├───────────┤  │  │ Raro             │  │
│  │[R1] Cota  │  │  │ BLQ: 18          │  │
│  │Cuero    X │  │  └──────────────────┘  │
│  ├───────────┤  ├────────────────────────┤
│  │[R3] Vara  │  │  DESCRIPCION           │
│  │Cristal  X │  │  Escudo forjado...     │
│  └───────────┘  ├────────────────────────┤
│                 │  MATERIALES REQUERIDOS │
│                 │  [o] Hierro x3  3/3 ✓ │
│                 │  [o] Cuero  x2  1/2 ✗  │
│                 ├────────────────────────┤
│                 │  Oro: 0 (no impl.)     │
│                 ├────────────────────────┤
│                 │  Faltan materiales.    │
│                 │  [   FORJAR   ] (dis.) │
└─────────────────┴────────────────────────┘
```

- Columna izquierda: ~38% del ancho, scroll vertical.
- Columna derecha: ~62%, scroll vertical interno.
- Botón FORJAR: 56dp alto, verde, hit area pleno ancho.
- StatusLabel en cada receta: "OK" verde / "X" rojo, esquina superior derecha de la fila.

## Flujo de interacción

1. Usuario abre InventoryScreen → toca botón **FORJA** en el header.
2. InventoryScreen se cierra, CraftingScreen se abre (sin apilar pausas).
3. Lista de recetas poblada desde `CraftingSystem.get_all_recipes()`. Primera crafteable preseleccionada.
4. Tap en receta → panel derecho muestra output (icono coloreado por rareza, nombre, stat) + descripción + materiales con estado "X/Y".
5. Si todos los materiales están disponibles → botón FORJAR habilitado (verde).
6. Tap FORJAR → animación "Forjando..." (1.0s con puntos suspensivos) → reveal:
   - **Éxito:** overlay dorado, "FORJADO", mensaje con nombre del item. Flash dorado. Item al inventario.
   - **Aborto:** overlay rojo, "FALLO", razón clara. No se consume nada.
7. Tras 1.2s adicionales de lectura: overlay se cierra, UI se refresca (materiales actualizados, status de recetas re-evaluado).
8. El jugador puede seguir crafteando o cerrar con X / tap en el fondo.

## Decisiones técnicas

### Patrón calcado de RefinementScreen
Mismo esquema visual (colores, fuentes, sección headers, barras de rareza, separadores). Coherencia visual sin duplicar assets: todo procedural.

### Layer 26
Sobre InventoryScreen (20) y RefinementScreen (25). Debajo de Game Over. Permite que CraftingScreen y RefinementScreen coexistan en el árbol sin conflicto de z-order.

### Resolver de CraftingScreen en InventoryScreen
Mismo patrón de 3 opciones que `_get_refinement_screen()`:
1. NodePath explícito en Inspector.
2. Búsqueda en árbol por clase (`CraftingScreen`).
3. Instanciar `res://scenes/ui/crafting_screen.tscn` en runtime y agregar como hermano.

Resultado cacheado en `_crafting_screen` para llamadas sucesivas.

### Crafteo determinístico — sin animación de suspenso largo
RefinementScreen usa 1.6s de suspenso porque el resultado es aleatorio (suspenso real). CraftingScreen usa 1.0s porque el resultado es determinístico — la animación es solo feedback de "algo está pasando", no suspenso dramático. Diferencia intencional.

### Reactive a signals
`InventorySystem.materials_changed` → refresca lista y detalle mientras la pantalla está abierta.
`CraftingSystem.recipe_added` → preparado para recetas desbloqueables en runtime (no usado en MVP).

### Icono de output y materiales
`ColorRect` coloreado por rareza como placeholder. TODO: reemplazar por `TextureRect` cuando haya sprites.

## TODOs

- `TODO`: reemplazar `ColorRect` de iconos por `TextureRect` cuando haya sprites de items y materiales.
- `TODO`: implementar sistema de Oro (GoldSystem) y activar validación en `CraftingSystem` + mostrar estado en UI.
- `TODO`: remover tecla `C` de testing cuando no se necesite en debug builds.
- `TODO`: si `MaterialData` recibe campo `rarity` propio, mapear color en `_material_rarity_color()`.

## Smoke checks para playtest

1. Abrir InventoryScreen → botón FORJA visible en header → tap abre CraftingScreen (inventario se cierra primero).
2. Lista muestra las 5 recetas; recetas sin materiales muestran "X" rojo; recetas con materiales muestran "OK" verde.
3. Seleccionar receta crafteable → FORJAR habilitado → tap → animación → flash dorado → item aparece en inventario.
4. Seleccionar receta sin materiales → FORJAR deshabilitado → mensaje "Faltan materiales" visible.
5. Con pantalla abierta, recolectar un material (otro proceso) → status de receta se actualiza sin cerrar.
6. Tap en fondo oscuro → CraftingScreen se cierra, juego se despausa.
7. Probar en mobile (no testeado en device — validar vos, Leo).

## Notas de implementación no obvia

- `_detail_empty_label` es un Label centrado que reemplaza visualmente el preview del output cuando no hay receta seleccionada. Se oculta al seleccionar.
- `_detail_inputs_vbox` está dentro de un `ColorRect` contenedor que tiene `custom_minimum_size = Vector2(0, 60)` para evitar colapso cuando no hay inputs visibles.
- El `fill` (Control con `SIZE_EXPAND_FILL`) en `_build_action_row` empuja el botón FORJAR hacia el fondo del panel cuando el contenido es corto — mismo truco que RefinementScreen.
- `_highlight_selected_recipe_row()` opera sobre `wrapper.get_child(0)` (el outer ColorRect) igual que `_highlight_selected_row()` en RefinementScreen — misma convención de estructura de wrapper.

---

**TESTEAR EN MOBILE: SÍ — siempre. No testeado en device físico, validar con Leo.**
