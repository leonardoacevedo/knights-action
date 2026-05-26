extends SceneTree
# Tests unitarios para CraftingSystem. GDD §5.5.
# No requiere escena — instancia las clases directamente y simula InventorySystem
# con un objeto stub mínimo (mismo patrón que upgrade_manager_test.gd).
#
# Ejecución: godot --headless --script res://tests/systems/crafting_system_test.gd

# ─── Stub de InventorySystem ──────────────────────────────────────────────────
# CraftingSystem llama a InventorySystem como autoload. En headless los autoloads
# no cargan, así que sustituimos con un objeto duck-type.

class FakeInventory:
	var _stock: Dictionary = {}      # StringName id → int count
	var _items_added: Array = []     # Registro de items agregados al inventario

	func get_material_count(id: StringName) -> int:
		return _stock.get(id, 0)

	func remove_material(id: StringName, count: int) -> bool:
		var current: int = _stock.get(id, 0)
		if current < count:
			return false
		var nuevo: int = current - count
		if nuevo == 0:
			_stock.erase(id)
		else:
			_stock[id] = nuevo
		return true

	func add_item(item: ItemData) -> ItemData:
		# El stub devuelve el mismo item (sin duplicar) — suficiente para tests de crafteo.
		# En producción InventorySystem.add_item devuelve una copia real.
		_items_added.append(item)
		return item

	func add(id: StringName, count: int) -> void:
		_stock[id] = _stock.get(id, 0) + count

	func clear_all() -> void:
		_stock.clear()
		_items_added.clear()


# ─── Setup global ─────────────────────────────────────────────────────────────

var _system: CraftingSystem
var _inventory: FakeInventory

func _init() -> void:
	print("== crafting_system_test ==")
	_setup()
	_test_get_all_recipes_empty()
	_test_get_recipe_by_id_found()
	_test_get_recipe_by_id_not_found()
	_test_can_craft_empty_inventory()
	_test_can_craft_exact_materials()
	_test_can_craft_surplus_materials()
	_test_get_missing_materials_partial()
	_test_try_craft_success()
	_test_try_craft_insufficient_materials()
	_test_try_craft_null_recipe()
	_test_try_craft_consumes_exact_count()
	_test_try_craft_surplus_only_consumes_needed()
	print("All passed.")
	quit()


func _setup() -> void:
	_system = CraftingSystem.new()
	_inventory = FakeInventory.new()
	# Inyectar stub en lugar del autoload real.
	_system.set("_inventory_override", _inventory)
	# Las recetas del disco no cargan en headless (_ready no corre en .new()).
	# Inyectamos recetas sintéticas con _register_recipe() en cada test.


# ─── Helper: resetear estado entre tests ──────────────────────────────────────

func _reset() -> void:
	_system = CraftingSystem.new()
	_system.set("_inventory_override", _inventory)
	_inventory.clear_all()


# ─── Helper: crear MaterialData sintético ─────────────────────────────────────

func _make_material(id: StringName) -> MaterialData:
	var mat := MaterialData.new()
	mat.id = id
	mat.display_name = str(id)
	mat.max_stack = 99
	return mat


# ─── Helper: crear ItemData sintético ─────────────────────────────────────────

func _make_item_data(item_id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = str(item_id)
	item.slot = ItemData.Slot.ARMA
	item.rarity = ItemData.Rarity.R1
	item.stat_main = 10
	return item


# ─── Helper: crear receta sintética con 1 material ───────────────────────────

func _make_recipe(
		recipe_id: StringName,
		mat_id: StringName,
		mat_count: int,
		output_id: StringName
) -> CraftRecipe:
	var mat: MaterialData = _make_material(mat_id)
	var input := CraftRecipeInput.new()
	input.material = mat
	input.count = mat_count

	var output: ItemData = _make_item_data(output_id)

	var recipe := CraftRecipe.new()
	recipe.id = recipe_id
	recipe.display_name = str(recipe_id)
	recipe.inputs = [input]
	recipe.output_item = output
	return recipe


# ─── Helper: crear receta con múltiples materiales ───────────────────────────

func _make_recipe_multi(
		recipe_id: StringName,
		mat_ids: Array,
		mat_counts: Array,
		output_id: StringName
) -> CraftRecipe:
	var inputs: Array[CraftRecipeInput] = []
	for i: int in range(mat_ids.size()):
		var mat: MaterialData = _make_material(mat_ids[i])
		var input := CraftRecipeInput.new()
		input.material = mat
		input.count = mat_counts[i]
		inputs.append(input)

	var output: ItemData = _make_item_data(output_id)

	var recipe := CraftRecipe.new()
	recipe.id = recipe_id
	recipe.display_name = str(recipe_id)
	recipe.inputs = inputs
	recipe.output_item = output
	return recipe


# ─── Caso 1: get_all_recipes() sin recetas registradas → Array vacío ──────────

func _test_get_all_recipes_empty() -> void:
	_reset()
	var recipes: Array[CraftRecipe] = _system.get_all_recipes()
	assert(recipes.is_empty(),
		"get_all_recipes() sin recetas debe retornar Array vacío")
	print("  - get_all_recipes_empty ok")


# ─── Caso 2: get_recipe_by_id con id existente → CraftRecipe correcta ─────────

func _test_get_recipe_by_id_found() -> void:
	_reset()
	var recipe: CraftRecipe = _make_recipe(&"r_test", &"mat_a", 3, &"item_x")
	_system._register_recipe(recipe)

	var found: CraftRecipe = _system.get_recipe_by_id(&"r_test")
	assert(found != null, "get_recipe_by_id('r_test') no debe retornar null")
	assert(found.id == &"r_test",
		"id de receta encontrada debe ser 'r_test', obtuvo: '%s'" % str(found.id))
	print("  - get_recipe_by_id_found ok")


# ─── Caso 3: get_recipe_by_id con id inexistente → null ──────────────────────

func _test_get_recipe_by_id_not_found() -> void:
	_reset()
	var found: CraftRecipe = _system.get_recipe_by_id(&"no_existe")
	assert(found == null,
		"get_recipe_by_id('no_existe') debe retornar null")
	print("  - get_recipe_by_id_not_found ok")


# ─── Caso 4: can_craft con inventario vacío → false ──────────────────────────

func _test_can_craft_empty_inventory() -> void:
	_reset()
	var recipe: CraftRecipe = _make_recipe(&"r_empty", &"mat_x", 5, &"item_y")
	_system._register_recipe(recipe)

	# Inventario vacío → no puede craftear.
	assert(_system.can_craft(recipe) == false,
		"can_craft con inventario vacío debe ser false")
	print("  - can_craft_empty_inventory ok")


# ─── Caso 5: can_craft con exactamente los materiales necesarios → true ────────

func _test_can_craft_exact_materials() -> void:
	_reset()
	var recipe: CraftRecipe = _make_recipe(&"r_exact", &"mat_b", 3, &"item_z")
	_system._register_recipe(recipe)
	_inventory.add(&"mat_b", 3)

	assert(_system.can_craft(recipe) == true,
		"can_craft con exactamente 3/3 de mat_b debe ser true")
	print("  - can_craft_exact_materials ok")


# ─── Caso 6: can_craft con materiales de sobra → true ────────────────────────

func _test_can_craft_surplus_materials() -> void:
	_reset()
	var recipe: CraftRecipe = _make_recipe(&"r_surplus", &"mat_c", 2, &"item_w")
	_system._register_recipe(recipe)
	_inventory.add(&"mat_c", 10)  # tiene 10, necesita 2

	assert(_system.can_craft(recipe) == true,
		"can_craft con 10/2 de mat_c debe ser true (sobra)")
	print("  - can_craft_surplus_materials ok")


# ─── Caso 7: get_missing_materials con inventario parcial → dict con faltantes ─

func _test_get_missing_materials_partial() -> void:
	_reset()
	# Receta: 5 mat_p + 3 mat_q
	var recipe: CraftRecipe = _make_recipe_multi(
		&"r_partial",
		[&"mat_p", &"mat_q"],
		[5, 3],
		&"item_v"
	)
	_system._register_recipe(recipe)
	# El jugador tiene 2 mat_p (le faltan 3) y 0 mat_q (le faltan 3).
	_inventory.add(&"mat_p", 2)

	var missing: Dictionary = _system.get_missing_materials(recipe)
	assert(missing.size() == 2,
		"deben faltar 2 materiales distintos, obtuvo %d" % missing.size())
	assert(missing.get(&"mat_p", 0) == 3,
		"faltan 3 de mat_p, obtuvo %d" % missing.get(&"mat_p", 0))
	assert(missing.get(&"mat_q", 0) == 3,
		"faltan 3 de mat_q, obtuvo %d" % missing.get(&"mat_q", 0))
	print("  - get_missing_materials_partial ok")


# ─── Caso 8: try_craft exitoso → success=true, materiales restados, item agregado ─

func _test_try_craft_success() -> void:
	_reset()
	var recipe: CraftRecipe = _make_recipe(&"r_ok", &"mat_d", 4, &"item_crafted")
	_system._register_recipe(recipe)
	_inventory.add(&"mat_d", 4)

	var succeeded_result: CraftResult = null
	_system.craft_succeeded.connect(func(r: CraftResult) -> void:
		succeeded_result = r, CONNECT_ONE_SHOT)

	var result: CraftResult = _system.try_craft(recipe)

	assert(result != null, "try_craft exitoso no debe retornar null")
	assert(result.success == true, "result.success debe ser true")
	assert(result.output_item != null, "result.output_item no debe ser null")
	assert(result.output_item.id == &"item_crafted",
		"output_item.id debe ser 'item_crafted'")
	# Materiales deben haberse consumido.
	assert(_inventory.get_material_count(&"mat_d") == 0,
		"mat_d debe haber sido consumido (queda 0)")
	# Item debe haberse agregado al inventario.
	assert(_inventory._items_added.size() == 1,
		"debe haberse agregado 1 item al inventario")
	assert((_inventory._items_added[0] as ItemData).id == &"item_crafted",
		"el item agregado debe ser 'item_crafted'")
	# Signal emitida.
	assert(succeeded_result != null,
		"craft_succeeded debe haber sido emitido")
	print("  - try_craft_success ok")


# ─── Caso 9: try_craft sin materiales → success=false, reason, sin cambios ────

func _test_try_craft_insufficient_materials() -> void:
	_reset()
	var recipe: CraftRecipe = _make_recipe(&"r_fail", &"mat_e", 5, &"item_ghost")
	_system._register_recipe(recipe)
	_inventory.add(&"mat_e", 2)  # tiene 2, necesita 5

	var aborted_result: CraftResult = null
	_system.craft_aborted.connect(func(r: CraftResult) -> void:
		aborted_result = r, CONNECT_ONE_SHOT)

	var result: CraftResult = _system.try_craft(recipe)

	assert(result != null, "try_craft debe retornar CraftResult aunque falle")
	assert(result.success == false, "result.success debe ser false")
	assert(result.reason == "insufficient_materials",
		"reason debe ser 'insufficient_materials', obtuvo: '%s'" % result.reason)
	# Inventario sin cambios.
	assert(_inventory.get_material_count(&"mat_e") == 2,
		"mat_e no debe haberse consumido (aborto)")
	assert(_inventory._items_added.is_empty(),
		"no debe haberse agregado ningún item (aborto)")
	# Signal de abort emitida.
	assert(aborted_result != null, "craft_aborted debe haber sido emitido")
	print("  - try_craft_insufficient_materials ok")


# ─── Caso 10: try_craft(null) → success=false, reason="invalid_recipe" ────────

func _test_try_craft_null_recipe() -> void:
	_reset()

	var aborted_result: CraftResult = null
	_system.craft_aborted.connect(func(r: CraftResult) -> void:
		aborted_result = r, CONNECT_ONE_SHOT)

	var result: CraftResult = _system.try_craft(null)

	assert(result != null, "try_craft(null) debe retornar CraftResult")
	assert(result.success == false, "debe fallar con recipe null")
	assert(result.reason == "invalid_recipe",
		"reason debe ser 'invalid_recipe', obtuvo: '%s'" % result.reason)
	assert(_inventory._items_added.is_empty(),
		"no debe haberse agregado ningún item")
	assert(aborted_result != null, "craft_aborted debe haber sido emitido")
	print("  - try_craft_null_recipe ok")


# ─── Caso 11: try_craft consume EXACTAMENTE los materiales especificados ───────

func _test_try_craft_consumes_exact_count() -> void:
	_reset()
	# Receta: 3 mat_f + 2 mat_g
	var recipe: CraftRecipe = _make_recipe_multi(
		&"r_exact_consume",
		[&"mat_f", &"mat_g"],
		[3, 2],
		&"item_exact"
	)
	_system._register_recipe(recipe)
	_inventory.add(&"mat_f", 3)
	_inventory.add(&"mat_g", 2)

	var result: CraftResult = _system.try_craft(recipe)

	assert(result.success == true, "debe ser exitoso")
	# Exactamente 0 de cada material (consumido todo).
	assert(_inventory.get_material_count(&"mat_f") == 0,
		"mat_f debe quedar en 0 (consumidos exactamente 3)")
	assert(_inventory.get_material_count(&"mat_g") == 0,
		"mat_g debe quedar en 0 (consumidos exactamente 2)")
	# Registro de materiales consumidos correcto.
	assert(result.materials_consumed.get(&"mat_f", 0) == 3,
		"materials_consumed debe registrar 3 de mat_f")
	assert(result.materials_consumed.get(&"mat_g", 0) == 2,
		"materials_consumed debe registrar 2 de mat_g")
	print("  - try_craft_consumes_exact_count ok")


# ─── Caso 12: try_craft con sobra — solo consume lo necesario ─────────────────

func _test_try_craft_surplus_only_consumes_needed() -> void:
	_reset()
	# Receta: 2 mat_h
	var recipe: CraftRecipe = _make_recipe(&"r_surplus_consume", &"mat_h", 2, &"item_spare")
	_system._register_recipe(recipe)
	_inventory.add(&"mat_h", 10)  # el jugador tiene 10, receta pide 2

	var result: CraftResult = _system.try_craft(recipe)

	assert(result.success == true, "debe ser exitoso")
	# Solo deben haberse consumido 2, quedan 8.
	assert(_inventory.get_material_count(&"mat_h") == 8,
		"deben quedar 8 de mat_h (consumidos 2 de 10), obtuvo %d" %
		_inventory.get_material_count(&"mat_h"))
	assert(result.materials_consumed.get(&"mat_h", 0) == 2,
		"materials_consumed debe registrar solo 2 de mat_h")
	print("  - try_craft_surplus_only_consumes_needed ok")
