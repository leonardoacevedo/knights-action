extends SceneTree
# Tests de independencia de instancias de items en el inventario. GDD §5.6.
# Bug original: refinar un item modificaba TODAS las instancias del mismo .tres.
# Fix: add_item hace duplicate(true) — cada instancia en _items es independiente.
#
# Ejecución: godot --headless --script res://tests/systems/item_independence_test.gd

func _init() -> void:
	print("== item_independence_test ==")
	_test_two_adds_produce_independent_instances()
	_test_refine_one_does_not_affect_other()
	_test_original_tres_not_modified()
	_test_add_item_return_value_is_usable_for_equip()
	print("All passed.")
	quit()


func _test_two_adds_produce_independent_instances() -> void:
	# add_item dos veces con la misma referencia → dos instancias distintas en el inventario.
	var inv := _make_inventory()
	var template: ItemData = _make_item(ItemData.Slot.ARMA)

	var inst_a: ItemData = inv.add_item(template)
	var inst_b: ItemData = inv.add_item(template)

	assert(inv.get_all().size() == 2, "independencia: inventario debe tener 2 items")
	assert(inst_a != null, "independencia: inst_a no debe ser null")
	assert(inst_b != null, "independencia: inst_b no debe ser null")
	assert(inst_a != inst_b, "independencia: las dos instancias deben ser objetos distintos")
	assert(inst_a != template, "independencia: inst_a no debe ser el template original")
	assert(inst_b != template, "independencia: inst_b no debe ser el template original")
	print("  - dos add_item producen instancias independientes ok")


func _test_refine_one_does_not_affect_other() -> void:
	# Modificar refinement_level de una instancia NO modifica la otra.
	# Smoke check del bug reportado: drop 2 martillos R4 → refinar uno → el otro queda en +0.
	var inv := _make_inventory()
	var template: ItemData = _make_item(ItemData.Slot.ARMA)

	var inst_a: ItemData = inv.add_item(template)
	var inst_b: ItemData = inv.add_item(template)

	assert(inst_a.refinement_level == 0, "refine isolado: inst_a comienza en +0")
	assert(inst_b.refinement_level == 0, "refine isolado: inst_b comienza en +0")

	# Simula lo que hace UpgradeManager.attempt_refine — modifica refinement_level directamente.
	inst_a.refinement_level = 3

	assert(inst_a.refinement_level == 3, "refine isolado: inst_a debe estar en +3")
	assert(inst_b.refinement_level == 0, "refine isolado: inst_b debe seguir en +0")
	assert(template.refinement_level == 0, "refine isolado: template no debe modificarse")
	print("  - refinar uno no afecta al otro ok")


func _test_original_tres_not_modified() -> void:
	# Modificar una instancia del inventario NO modifica el .tres original (template).
	# Escenario: el .tres sirve como base immutable para futuros drops/crafts.
	var inv := _make_inventory()
	var template: ItemData = _make_item(ItemData.Slot.ARMA)
	template.refinement_level = 0

	var instance: ItemData = inv.add_item(template)
	instance.refinement_level = 7

	assert(template.refinement_level == 0, "template inmutable: .tres no debe cambiar tras refinar la instancia")
	print("  - template .tres inmutable ok")


func _test_add_item_return_value_is_usable_for_equip() -> void:
	# El valor de retorno de add_item es la instancia correcta para pasar a equip().
	# Si se pasa el template (no la instancia), equip() duplicaría de nuevo — bug potencial.
	var inv := _make_inventory()
	var template: ItemData = _make_item(ItemData.Slot.ARMA)

	var instance: ItemData = inv.add_item(template)
	inv.equip(instance)

	var equipped: ItemData = inv.get_equipped(ItemData.Slot.ARMA)
	assert(equipped == instance, "equip con return value: el item equipado debe ser la instancia del inventario")
	assert(inv.get_all().size() == 1, "equip con return value: no debe haber duplicados en inventario")
	print("  - add_item return value usable para equip ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_inventory() -> Node:
	var inv := load("res://scripts/systems/inventory_system.gd").new()
	return inv


func _make_item(slot: ItemData.Slot) -> ItemData:
	var item := ItemData.new()
	item.id = &"martillo_r4_test"
	item.display_name = "Martillo R4 de Test"
	item.slot = slot
	item.rarity = ItemData.Rarity.R4
	item.stat_main = 80
	item.refinement_level = 0
	return item
