extends Resource
class_name CraftRecipe

# Receta de crafteo. GDD §5.5.
#
# Crear: New Resource → CraftRecipe → poblar inputs + output_item.
# Guardar en resources/recipes/<id>.tres.
#
# Las recetas son fijas en MVP — no desbloqueables. CraftingSystem las carga
# automáticamente al arrancar desde resources/recipes/*.tres.

# ─── Identidad ────────────────────────────────────────────────────────────────

## ID único en snake_case. CraftingSystem usa esto como clave de búsqueda.
## Ej: &"craft_espada_hierro", &"craft_cota_cuero".
@export var id: StringName = &""

## Nombre legible para UI futura. narrative-lore puede ajustar.
@export var display_name: String = ""

## Descripción corta de 1-2 líneas. Para UI de crafteo y docs.
@export_multiline var description: String = ""

# ─── Inputs ───────────────────────────────────────────────────────────────────

## Lista de materiales requeridos. Cada elemento es un CraftRecipeInput con
## material + count. Godot los muestra como sub-Resources en el inspector.
@export var inputs: Array[CraftRecipeInput] = []

# ─── Output ───────────────────────────────────────────────────────────────────

## Item resultante. Apunta a un .tres existente en resources/items/.
## NO crear items nuevos en MVP — solo referencias a items ya existentes.
@export var output_item: ItemData

# ─── Costos extra ─────────────────────────────────────────────────────────────

## Costo en Oro. CraftingSystem valida con GoldSystem.can_afford() y consume con GoldSystem.consume().
@export var gold_cost: int = 0

# ─── Gating futuro ────────────────────────────────────────────────────────────

## Nivel mínimo del jugador para poder craftear. No usado en MVP (siempre 1).
## Preparado para gating de zonas/progresión post-Fase 2.
@export_range(1, 99) var required_player_level: int = 1


# ─── Helpers ─────────────────────────────────────────────────────────────────

## true si la receta está configurada correctamente (id, al menos un input, output).
func is_valid() -> bool:
	if id == &"":
		return false
	if output_item == null:
		return false
	if inputs.is_empty():
		return false
	for input: CraftRecipeInput in inputs:
		if input == null or input.material == null or input.count <= 0:
			return false
	return true
