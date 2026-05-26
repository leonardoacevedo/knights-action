# Crafteo — Backend

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (con dirección de Leo)
**Fase del proyecto:** 2 — Loop Básico
**Sección GDD relevante:** §5.5
**Pilar(es) reforzado(s):** #1 (mi build importa), #2 (cada muerte enseña algo)

---

## Qué hace

Implementa el sistema de crafteo de items a partir de materiales. El jugador puede producir items nuevos combinando materiales específicos (drops de zonas) según recetas fijas. El crafteo es instantáneo y determinístico: si se tienen los materiales, el craft siempre tiene éxito. No hay RNG de resultado — si falla, es porque falta algo concreto.

La feature cubre solo el backend (lógica + datos). La UI de crafteo es trabajo de `ux-mobile` en una iteración post-playtest.

## Por qué (pilares)

**Pilar #1 — Mi build importa, mi skill también.** El crafteo convierte el farmeo de materiales en una decisión activa: el jugador elige qué item producir según la build que está persiguiendo. Craftear la Vara de Cristal es más caro que craftear la Espada de Hierro — es una elección.

**Pilar #2 — Cada muerte enseña algo.** El crafteo determinístico refuerza esto: si un craft falla, es porque al jugador le falta X de Y material — información accionable. No hay "mala suerte" en el crafteo MVP. `get_missing_materials()` devuelve exactamente qué falta antes de intentar.

## Cómo se integra

```
CraftingSystem (autoload)
  ├── _ready()  → carga resources/recipes/*.tres
  ├── can_craft()  → consulta InventorySystem.get_material_count()
  ├── get_missing_materials()  → diff receta vs inventario
  └── try_craft()
        ├── valida con can_craft()
        ├── consume via InventorySystem.remove_material()  (atómico)
        └── agrega via InventorySystem.add_item()
```

Dependencias:
- `InventorySystem` (autoload) — fuente de verdad de materiales e items.
- `CraftRecipe`, `CraftRecipeInput`, `CraftResult` — clases de datos (Resources).
- `resources/recipes/*.tres` — recetas fijas cargadas al arrancar.

Señales emitidas:
- `recipe_added(recipe)` — al cargar cada receta desde disco.
- `craft_started(recipe)` — justo antes de consumir materiales.
- `craft_succeeded(result)` — craft completado.
- `craft_aborted(result)` — craft cancelado (materiales insuficientes, receta inválida, etc.).

## Decisiones técnicas no obvias

**`CraftRecipeInput` como sub-Resource separado.**
Godot 4 no tiene `Array[Dictionary]` tipado editable en el inspector. La alternativa —Array de Dictionaries genéricos— es fea de editar y no tiene autocompletado. Con `CraftRecipeInput` como Resource: en el inspector aparece como "sub-resource editable" y el tipado es explícito. El código GDScript puede iterar `inputs: Array[CraftRecipeInput]` con tipado completo.

**Crafteo determinístico (sin RNG).**
GDD §5.5 no especifica RNG para el crafteo base — solo para refinamiento (§5.6). Se eligió éxito garantizado para cumplir Pilar #2: el jugador controla el resultado, la habilidad está en farmear los materiales correctos. Esto diferencia crafteo (decisión de recursos) de refinamiento (apuesta con riesgo).

**Recetas fijas cargadas desde disco en `_ready()`.**
En MVP no hay recetas desbloqueables. `CraftingSystem._ready()` hace un scan de `res://resources/recipes/` y carga todos los `.tres` que encuentre. Agregar una receta nueva es tan simple como crear un `.tres` nuevo — no requiere tocar el código. El flag `required_player_level` en `CraftRecipe` queda preparado para gating futuro sin romper el schema.

**Oro como placeholder.**
`CraftRecipe.gold_cost` existe con valor 0 en todas las recetas MVP. Cuando `GoldSystem` esté activo, `CraftingSystem.try_craft()` tiene dos `TODO (Oro)` comentados que indican exactamente dónde agregar validación y consumo. No requiere refactor — solo descomentar e implementar el GoldSystem.

**Atomicidad.**
`try_craft()` valida todos los materiales con `can_craft()` antes de consumir cualquiera. Si la validación pasa, `InventorySystem.remove_material()` es atómico por diseño (ya existente). En MVP el inventario es ilimitado, así que no hay escenario de "consume materiales pero no puede agregar el item". Si eso cambiara, habría que revisar el flujo de revert.

**`_register_recipe()` para tests y futuro.**
Método público (convención con `_` indica "no-UI, no-gameplay directo") que permite inyectar recetas en runtime sin disco. Usado en los tests unitarios headless. También útil para futuros sistemas de recetas desbloqueables sin cambiar la arquitectura.

## Cómo agregar nuevas recetas (workflow para Leo)

1. En Godot Editor: botón derecho en `resources/recipes/` → New Resource → CraftRecipe.
2. Asignar `id` (StringName único, ej. `&"craft_escudo_torre"`).
3. Asignar `display_name` y `description`.
4. En `inputs`: agregar elementos → cada uno es un CraftRecipeInput. Asignar `material` (apuntar a un `.tres` de `resources/materials/`) y `count`.
5. En `output_item`: apuntar a un `.tres` de `resources/items/`.
6. Guardar como `resources/recipes/craft_<nombre>.tres`.
7. Al arrancar el juego, `CraftingSystem._ready()` la carga automáticamente.

No tocar `crafting_system.gd` para agregar recetas.

## API para UI futura

La UI de crafteo (responsabilidad de `ux-mobile`) debe usar esta API:

```gdscript
# Obtener todas las recetas para mostrar la lista.
var recipes: Array[CraftRecipe] = CraftingSystem.get_all_recipes()

# Verificar si el jugador puede craftear (habilitar/deshabilitar botón).
var can: bool = CraftingSystem.can_craft(recipe)

# Mostrar qué falta (feedback antes de intentar).
var missing: Dictionary = CraftingSystem.get_missing_materials(recipe)
# missing = { &"mat_id": int_cantidad_faltante, ... }

# Ejecutar el crafteo al presionar el botón de confirmar.
var result: CraftResult = CraftingSystem.try_craft(recipe)

# O conectarse a las signals para feedback asincrónico:
CraftingSystem.craft_succeeded.connect(_on_craft_succeeded)
CraftingSystem.craft_aborted.connect(_on_craft_aborted)
```

`CraftResult` tiene:
- `result.success: bool`
- `result.output_item: ItemData` — el item producido (null si abortado)
- `result.materials_consumed: Dictionary` — para mostrar "consumiste X de Y"
- `result.reason: String` — para mostrar mensaje de error si abortado

## Recetas iniciales (MVP)

| ID | Output | Rareza | Inputs | Oro |
| :--- | :--- | :---: | :--- | :---: |
| `craft_cota_cuero` | Cota de Cuero | R1 | 8 Hierba Antigua + 2 Savia Resonante | 0 |
| `craft_espada_hierro` | Espada de Hierro | R2 | 5 Hierba Antigua + 2 Savia Resonante + 1 Piedra Resonancia | 0 |
| `craft_escudo_hierro` | Escudo de Hierro | R2 | 4 Savia Resonante + 2 Piedra Resonancia | 0 |
| `craft_vara_cristal` | Vara de Cristal | R3 | 3 Savia Resonante + 2 Esencia del Verdor + 3 Piedra Resonancia | 0 |
| `craft_martillo_guardian` | Martillo del Guardián | R3 | 6 Hierba Antigua + 4 Savia Resonante + 2 Esencia del Verdor + 2 Piedra Resonancia | 0 |

**Nota sobre `escudo_hierro`:** el `.tres` de Escudo de Hierro tiene `rarity=1` (R2 en el enum de GDScript donde R1=0, R2=1, R3=2). Sin embargo `block_charges()` para R2 retorna 1 carga. El escudo es funcional y correcto — el mapeo de rareza en el código es por índice, no por número.

**Progresión de las recetas:**
- R1 → materiales R1 básicos (Hierba Antigua domina, algo de Savia).
- R2 → materiales R1+R2 (Hierba + Savia + Piedra de Resonancia).
- R3 → incluye Esencia del Verdor (R3, drop de zonas profundas) + Piedra de Resonancia en cantidad mayor.

Esto refuerza Pilar #3 (el ranking premia al que mejora) — un jugador que farmea zonas profundas desbloquea crafteo de R3 que un jugador de zonas bajas no puede alcanzar aún.

## Tests unitarios

`tests/systems/crafting_system_test.gd` cubre 12 casos:

1. `get_all_recipes()` sin recetas → Array vacío.
2. `get_recipe_by_id` con id existente → CraftRecipe correcta.
3. `get_recipe_by_id` con id inexistente → null.
4. `can_craft(recipe)` con inventario vacío → false.
5. `can_craft(recipe)` con materiales exactos → true.
6. `can_craft(recipe)` con materiales de sobra → true.
7. `get_missing_materials` con inventario parcial → Dictionary con faltantes correctos.
8. `try_craft` exitoso → `success=true`, materiales consumidos, item en inventario.
9. `try_craft` sin materiales → `success=false`, `reason="insufficient_materials"`, inventario sin cambios.
10. `try_craft(null)` → `success=false`, `reason="invalid_recipe"`.
11. `try_craft` consume EXACTAMENTE los materiales especificados.
12. `try_craft` con sobra — solo consume lo necesario, resto intacto.

Ejecución: `godot --headless --script res://tests/systems/crafting_system_test.gd`

## Archivos tocados

**Nuevos (lógica):**
- `scripts/data/craft_recipe_input.gd` — sub-Resource de input de receta.
- `scripts/data/craft_recipe.gd` — Resource de receta completa.
- `scripts/data/craft_result.gd` — Resource de resultado de crafteo.
- `scripts/systems/crafting_system.gd` — Autoload principal de crafteo.

**Nuevos (datos):**
- `resources/recipes/craft_cota_cuero.tres`
- `resources/recipes/craft_espada_hierro.tres`
- `resources/recipes/craft_escudo_hierro.tres`
- `resources/recipes/craft_vara_cristal.tres`
- `resources/recipes/craft_martillo_guardian.tres`

**Nuevos (tests):**
- `tests/systems/crafting_system_test.gd`

**Modificados:**
- `project.godot` — registro de `CraftingSystem` como autoload, después de `UpgradeManager`.

## Pendientes / mejoras futuras

- **UI de crafteo** — trabajo de `ux-mobile`. Usar la API documentada arriba.
- **Integración con Oro** — descomentar los bloques `TODO (Oro)` en `crafting_system.gd` cuando `GoldSystem` esté implementado. Los `gold_cost` en los `.tres` de recetas ya están preparados (todos en 0 por ahora).
- **Fusión 3xR(n) → 1xR(n+1)** — feature separada (`FusionSystem`). GDD §5.5 segunda parte. No va en este sistema.
- **Recetas desbloqueables / descubribles** — en MVP todas están disponibles desde el arranque. Para desbloqueo usar `required_player_level` ya presente en `CraftRecipe`, o agregar un flag `unlocked: bool` con un sistema de progresión separado.
- **Gating de crafteo por zona completada** — cuando el `StageSystem` tenga flags de zona, se puede filtrar `get_all_recipes()` por `required_player_level` o por tag de zona.
- **Feedback de materiales drop** — la UI debería conectar `InventorySystem.material_added` para mostrar "tenés X/Y de Z" en la pantalla de crafteo sin hacer polling.
