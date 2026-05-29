extends SceneTree
# Regresión A6: try_craft con inputs DUPLICADOS (mismo material en 2 inputs) y
# stock insuficiente para el total agregado debe ABORTAR sin agregar el item y
# sin consumir materiales ni oro (rollback / validación agregada).
#
# Usa el InventorySystem REAL (no stub) inyectado vía _inventory_override, y el
# autoload GoldSystem real (disponible en headless, ver drop_system_integration_test.gd).
# Mismo material en 2 inputs: [mat x2, mat x3] requiere 5 en total, no 3 por input.
#
# Ejecución: godot --headless --script res://tests/systems/crafting_rollback_test.gd

func _init() -> void:
	print("== crafting_rollback_test ==")
	_test_duplicate_inputs_insufficient_aborts_no_item()
	_test_duplicate_inputs_insufficient_preserves_materials()
	_test_duplicate_inputs_insufficient_preserves_gold()
	_test_duplicate_inputs_sufficient_consumes_aggregated_total()
	print("All passed.")
	quit()


# ─── Stock insuficiente para el total agregado → no se agrega el item ─────────
func _test_duplicate_inputs_insufficient_aborts_no_item() -> void:
	var inv := _make_inventory()
	var system := _make_system(inv)
	# Receta: [mat_dup x2, mat_dup x3] → total agregado 5.
	var recipe := _make_dup_recipe(&"r_dup_fail", &"mat_dup", 2, 3, &"item_dup", 0)
	system._register_recipe(recipe)
	inv.add_material(_make_material(&"mat_dup"), 3)  # solo 3, faltan 2 para el total

	var result: CraftResult = system.try_craft(recipe)

	assert(result != null, "A6: try_craft debe devolver CraftResult aunque falle")
	assert(result.success == false, "A6: debe fallar (stock total insuficiente)")
	assert(result.reason == "insufficient_materials",
		"A6: reason debe ser 'insufficient_materials', obtuvo '%s'" % result.reason)
	# El item NO debe haberse agregado al inventario.
	assert(inv.get_all().is_empty(),
		"A6: no debe agregarse ningún item en un craft abortado, hay %d" % inv.get_all().size())
	print("  - duplicate_inputs_insufficient_aborts_no_item ok")


# ─── Los materiales quedan intactos tras el aborto ────────────────────────────
func _test_duplicate_inputs_insufficient_preserves_materials() -> void:
	var inv := _make_inventory()
	var system := _make_system(inv)
	var recipe := _make_dup_recipe(&"r_dup_mat", &"mat_dup", 2, 3, &"item_dup", 0)
	system._register_recipe(recipe)
	inv.add_material(_make_material(&"mat_dup"), 3)

	system.try_craft(recipe)

	# Stock intacto — sin esto el bug viejo consumiría parcialmente (2 de los 3).
	assert(inv.get_material_count(&"mat_dup") == 3,
		"A6: los materiales deben quedar intactos (3), hay %d" % inv.get_material_count(&"mat_dup"))
	print("  - duplicate_inputs_insufficient_preserves_materials ok")


# ─── El oro queda intacto tras el aborto (reembolso / no-consumo) ─────────────
func _test_duplicate_inputs_insufficient_preserves_gold() -> void:
	var inv := _make_inventory()
	var system := _make_system(inv)
	# Receta con costo de oro 100 y stock insuficiente de material.
	var recipe := _make_dup_recipe(&"r_dup_gold", &"mat_dup", 2, 3, &"item_dup", 100)
	system._register_recipe(recipe)
	inv.add_material(_make_material(&"mat_dup"), 3)

	# Asegurar oro suficiente para que el ÚNICO motivo de fallo sea el material.
	# Usamos el autoload GoldSystem real; topeamos a un saldo conocido y lo restauramos.
	var gold_before: int = GoldSystem.get_gold()
	GoldSystem.add(500)
	var gold_topped: int = GoldSystem.get_gold()

	system.try_craft(recipe)

	assert(GoldSystem.get_gold() == gold_topped,
		"A6: el oro debe quedar intacto tras el aborto, esperado %d, hay %d" %
		[gold_topped, GoldSystem.get_gold()])

	# Restaurar el saldo original (no contaminar otros tests / global state).
	GoldSystem.consume(GoldSystem.get_gold() - gold_before)
	print("  - duplicate_inputs_insufficient_preserves_gold ok")


# ─── Control positivo: con stock suficiente, los inputs duplicados se suman ───
func _test_duplicate_inputs_sufficient_consumes_aggregated_total() -> void:
	var inv := _make_inventory()
	var system := _make_system(inv)
	# Mismo material x2 + x3 = total 5. Stock exacto 5 → debe craftear y consumir 5.
	var recipe := _make_dup_recipe(&"r_dup_ok", &"mat_dup", 2, 3, &"item_dup", 0)
	system._register_recipe(recipe)
	inv.add_material(_make_material(&"mat_dup"), 5)

	var result: CraftResult = system.try_craft(recipe)

	assert(result.success == true, "A6: con stock total suficiente (5) debe craftear")
	assert(inv.get_material_count(&"mat_dup") == 0,
		"A6: debe consumir el total agregado (5), quedan %d" % inv.get_material_count(&"mat_dup"))
	assert(inv.get_all().size() == 1, "A6: el item crafteado debe estar en el inventario")
	print("  - duplicate_inputs_sufficient_consumes_aggregated_total ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_inventory() -> Node:
	# InventorySystem real aislado (no el autoload global).
	return load("res://scripts/systems/inventory_system.gd").new()


func _make_system(inv: Node) -> CraftingSystem:
	var system := CraftingSystem.new()
	# Inyectar el inventario real en lugar del autoload (mismo patrón crafting_system_test.gd).
	system.set("_inventory_override", inv)
	return system


func _make_material(id: StringName) -> MaterialData:
	var mat := MaterialData.new()
	mat.id = id
	mat.display_name = str(id)
	mat.max_stack = 99
	return mat


func _make_item_data(item_id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = str(item_id)
	item.slot = ItemData.Slot.ARMADURA
	item.rarity = ItemData.Rarity.R1
	item.stat_main = 10
	return item


# Receta con el MISMO material en 2 inputs (count1 + count2). gold_cost configurable.
func _make_dup_recipe(
		recipe_id: StringName,
		mat_id: StringName,
		count1: int,
		count2: int,
		output_id: StringName,
		gold_cost: int
) -> CraftRecipe:
	# Dos inputs que apuntan al mismo material (mismo id) — caso A6.
	var input_a := CraftRecipeInput.new()
	input_a.material = _make_material(mat_id)
	input_a.count = count1

	var input_b := CraftRecipeInput.new()
	input_b.material = _make_material(mat_id)
	input_b.count = count2

	var recipe := CraftRecipe.new()
	recipe.id = recipe_id
	recipe.display_name = str(recipe_id)
	recipe.inputs = [input_a, input_b]
	recipe.output_item = _make_item_data(output_id)
	recipe.gold_cost = gold_cost
	return recipe
