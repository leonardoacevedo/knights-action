extends Resource
class_name DropTable

## Tabla de drops que contiene N DropEntry. Cada entry se rolea en forma
## independiente (no exclusiva): un mismo kill puede dropear varios materiales.
##
## La fórmula de momentum sigue GDD §111:
##   drop_rate_final = base_chance * (1.0 + 0.1 * momentum_level)
##   Clampeado a [0.0, 1.0] para no romper randf().
##
## Uso típico:
##   var results := drop_table.roll_materials_only(MomentumSystem.current_level)
##   for r in results:
##       InventorySystem.add_material(r["data"], r["count"])

@export var entries: Array[DropEntry] = []


## Rolea TODAS las entries (items + materiales). Aplica multiplicador de momentum.
## Retorna Array de Dictionary con keys: "type" (String), "data" (Resource), "count" (int).
## "type" es "item" o "material" para facilitar el switch en quien llama.
func roll(momentum_level: int) -> Array:
	var results: Array = []
	for entry: DropEntry in entries:
		if entry == null:
			continue
		# Fórmula GDD §111: multiplicar chance base por bonus de momentum.
		var final_chance: float = clamp(
			entry.drop_chance * (1.0 + 0.1 * float(momentum_level)),
			0.0, 1.0
		)
		if randf() > final_chance:
			continue

		if entry.drop_type == DropEntry.DropType.MATERIAL:
			if entry.material_data == null:
				push_warning("DropTable.roll: entry MATERIAL sin material_data.")
				continue
			var count: int = randi_range(entry.material_count_min, entry.material_count_max)
			results.append({ "type": "material", "data": entry.material_data, "count": count })
		else:
			if entry.item_data == null:
				push_warning("DropTable.roll: entry ITEM sin item_data.")
				continue
			results.append({ "type": "item", "data": entry.item_data, "count": 1 })

	return results


## ADVERTENCIA (A5): roll_materials_only() y roll_items_only() ejecutan roll() de cero
## cada uno. NO llamar AMBOS para el mismo evento de drop: serían dos tiradas RNG
## independientes (doble-roll). Hoy es latente — materiales se tiran al matar enemy y
## items al limpiar stage, eventos distintos. Si en el futuro un mismo evento necesita
## materiales E items, usar un único roll() y filtrar su resultado por "type".


## Versión filtrada de roll() que retorna solo materiales.
## Lo usa DropSystem en Milestone A (los items vienen en Milestone B).
func roll_materials_only(momentum_level: int) -> Array:
	var all_results: Array = roll(momentum_level)
	var material_results: Array = []
	for result in all_results:
		if result["type"] == "material":
			material_results.append(result)
	return material_results


## Versión filtrada de roll() que retorna solo items.
## Lo usa DropSystem en Milestone B (drops por stage cleared).
func roll_items_only(momentum_level: int) -> Array:
	var all_results: Array = roll(momentum_level)
	var item_results: Array = []
	for result in all_results:
		if result["type"] == "item":
			item_results.append(result)
	return item_results
