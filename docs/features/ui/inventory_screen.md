# Feature: Pantalla de Inventario (`inventory_screen`)

**Fecha de implementación:** 2026-05-24
**Fase:** 1 (Prototipo de Combate — sub-feature de UI)
**Archivos principales:**
- `scripts/ui/inventory_screen.gd`
- `scenes/ui/inventory_screen.tscn`

---

## Qué hace

Pantalla in-game que permite al jugador ver, equipar y desequipar items sin salir del juego. Se abre sobre el combate pausando la ejecución del juego (`SceneTree.paused = true`) y se cierra reestableciendo la pausa.

### Secciones de la UI

**Columna izquierda — EQUIPADO**
- 3 filas (ARMA, ARMADURA, ESCUDO), una por slot.
- Cada fila muestra el nombre del item equipado (color según rareza) o "—" si está vacío.
- Tap en una fila ocupada → desequipa el item (vuelve a la mochila).

**Columna derecha superior — MOCHILA**
- Lista scrolleable de items no equipados.
- Cada fila: franja de rareza (izquierda), badge de rareza `[C/R/E/L]`, nombre del item, stat principal (ATK/DEF/BLQ + nivel de refinamiento si > 0).
- Tap en un item → lo equipa en su slot correspondiente + lo selecciona para el panel de detalle.

**Columna derecha inferior — DETALLE**
- Muestra el item seleccionado (último tapado, sea de mochila o de slot equipado antes de desequipar).
- Campos: nombre (color rareza), stat principal, descripción, lista de afijos.
- Si no hay selección: placeholder `(ningún ítem seleccionado)`.

**Header**
- Título "INVENTARIO" centrado.
- Botón "X" top-right (hit area 60×52 dp) para cerrar.

---

## Cómo se integra con InventorySystem

| Acción del jugador | Llamada a InventorySystem | Señal resultante |
| :--- | :--- | :--- |
| Tap item en mochila | `equip(item)` | `equipped_changed(slot, item)` |
| Tap slot equipado | `unequip(slot)` | `equipped_changed(slot, null)` |
| (automático al abrir) | `get_all()` / `get_equipped(slot)` | — |

Las señales `item_added`, `item_removed` y `equipped_changed` de `InventorySystem` están conectadas en `_ready`. Cuando se disparan y la pantalla está abierta, se llaman `_refresh_bag_list()`, `_refresh_equipped_slots()` y `_refresh_detail()`.

**No se toca `PlayerStatsComponent` directamente.** Los stats se recalculan solos cuando `equipped_changed` se propaga al componente (ya conectado por él mismo).

---

## Cómo abrir y cerrar

### Desde código

```gdscript
# Obtener la referencia (nodo hijo de World):
var inv: InventoryScreen = get_node("/root/World/InventoryScreen")

inv.open()    # abre + pausa
inv.close()   # cierra + despausa
inv.toggle()  # alterna estado
```

### Desde el jugador

- **Teclado (PC):** tecla `I` (física) o la action `inventory` del InputMap.
- **Touch (mobile):** botón "I" en el cluster de botones del HUD touch (bottom-right, arriba-derecha del cluster). Dispara la action `inventory`, que `InventoryScreen` escucha via `_unhandled_input`.

La pantalla está instanciada en `scenes/world.tscn` como hijo directo de `World` con `visible = false` por defecto.

---

## Decisiones técnicas

### UI 100% procedural

No se usan imágenes externas. Todo con `ColorRect`, `Label`, `VBoxContainer`, `HBoxContainer`, `ScrollContainer` y `PanelContainer`. Esto garantiza cero dependencias de assets externos y facilita el ajuste de colores/tamaños sin reimportar texturas.

### Pause + `PROCESS_MODE_WHEN_PAUSED`

El `CanvasLayer` y su árbol se setean a `PROCESS_MODE_WHEN_PAUSED` en `_ready`. Esto permite que los botones, labels y señales respondan mientras el juego está pausado. El resto del árbol (player, enemigos, physics) se detiene.

El bloqueo de cierre accidental al tocar el fondo se resuelve seteando el fondo (`ColorRect`) con `MOUSE_FILTER_IGNORE` — no consume eventos, solo decora.

### Colores de rareza como constantes

Las 4 constantes `COLOR_R1..R4` son la fuente de verdad visual para rareza en este archivo. Si en el futuro se crea un `ThemeManager` o similar, migrar desde acá.

### Hit areas

| Elemento | Mínimo garantizado |
| :--- | :--- |
| Filas de slot equipado | 72 dp de alto × ancho de columna |
| Filas de item en mochila | 60 dp de alto × ancho completo |
| Botón cerrar (X) | 60 × 52 dp |
| Botón INV (touch) | 90 × 90 dp (heredado de `touch_button.tscn`) |

Todos superan el mínimo de 44×44 dp (Apple HIG) / 48×48 dp (Material).

### Posición del botón INV en touch_controls

Se agregó `BtnInventory` en posición `offset_left=190, offset_top=0` (arriba-derecha del cluster), simétricamente opuesto al botón JUMP. Color gris neutro (`0.45, 0.45, 0.55`) para diferenciarlo claramente de ATTACK (rojo), DASH (azul) y JUMP (verde).

---

## Pendientes / limitaciones actuales

- **Drag & drop:** no implementado. El tap simple equipa/desequipa directamente (mobile-first).
- **Comparación de stats:** no hay overlay de "stat actual vs. stat si equipás este item". Pendiente para cuando `PlayerStatsComponent` exponga stats calculados como señal.
- **Tooltips:** no existen en mobile. El panel de detalle sirve como reemplazo al seleccionar un item.
- **Filtros de mochila:** la lista no tiene filtros por slot o rareza. Pendiente para cuando el inventario tenga más de 10-15 items.
- **Animación de apertura/cierre:** no implementada. La transición es instantánea. Si se agrega, debe ser ≤ 300 ms (regla de UX mobile del rol).
- **Feedback visual de "equipado":** las filas de mochila no muestran un estado "ya equipado" con overlay visual porque los items equipados ya se excluyen de la lista. Si en el futuro un mismo item puede estar en inventario y equipado simultáneamente (diseño actual: no), revisar este punto.
- **No testeado en mobile real.** Validar en celular físico antes de declarar la pantalla como estable. Ver Riesgo #2 del GDD §14.
