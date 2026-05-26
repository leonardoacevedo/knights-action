extends Resource
class_name CraftResult

# Resultado de un intento de crafteo. GDD §5.5.
# Análogo a RefineResult — producido por CraftingSystem.try_craft().
#
# El crafteo en MVP es determinístico: si se cumplen las precondiciones, success=true.
# success=false solo en abortos (materiales insuficientes, receta inválida, etc.).
# Esto refuerza Pilar #2: si un craft falla, el jugador sabe exactamente qué falta.
#
# Uso:
#   var result: CraftResult = CraftingSystem.try_craft(recipe)
#   CraftingSystem.craft_succeeded.connect(_on_craft_succeeded)
#   CraftingSystem.craft_aborted.connect(_on_craft_aborted)

# ─── Resultado principal ──────────────────────────────────────────────────────

## true si el crafteo completó exitosamente.
@export var success: bool = false

## Item producido. null si success=false.
@export var output_item: ItemData

# ─── Materiales y costos ──────────────────────────────────────────────────────

## Materiales consumidos durante el crafteo. StringName id → int count.
## Solo se puebla si success=true (nada se consume en un aborto).
@export var materials_consumed: Dictionary = {}

## Oro consumido en el crafteo. Actualizado por CraftingSystem con recipe.gold_cost.
@export var gold_consumed: int = 0

# ─── Contexto de fallo ────────────────────────────────────────────────────────

## Razón del aborto si success=false. Vacío si success=true.
## Valores posibles:
##   "invalid_recipe"         — recipe es null o no pasa CraftRecipe.is_valid().
##   "no_recipe"              — get_recipe_by_id no encontró la receta.
##   "insufficient_materials" — el inventario no tiene todos los materiales.
@export var reason: String = ""
