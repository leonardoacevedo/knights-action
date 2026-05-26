extends SceneTree
# Test de smoke para InventorySystem. GDD §5.
# Ejecución: godot --headless --script res://tests/systems/inventory_system_test.gd

func _init() -> void:
	print("== inventory_system_test ==")
	_test_add_item()
	_test_add_item_returns_instance()
	_test_remove_item()
	_test_equip_get_equipped()
	_test_unequip()
	_test_equip_auto_adds_to_inventory()
	_test_remove_equipped_clears_slot()
	print("All passed.")
	quit()


func _test_add_item() -> void:
	var inv := _make_inventory()
	var item := _make_item(ItemData.Slot.ARMA)
	inv.add_item(item)
	assert(inv.get_all().size() == 1, "add_item: size debe ser 1")
	print("  - add_item ok")


func _test_add_item_returns_instance() -> void:
	# add_item devuelve la instancia duplicada (no null, no la misma referencia).
	var inv := _make_inventory()
	var item := _make_item(ItemData.Slot.ARMA)
	var instance: ItemData = inv.add_item(item)
	assert(instance != null, "add_item: retorno no debe ser null")
	assert(instance != item, "add_item: retorno debe ser una copia distinta al original")
	print("  - add_item returns instance ok")


func _test_remove_item() -> void:
	var inv := _make_inventory()
	var item := _make_item(ItemData.Slot.ARMA)
	# Usar la instancia devuelta por add_item — es la que vive en el inventario.
	var instance: ItemData = inv.add_item(item)
	var removed: bool = inv.remove_item(instance)
	assert(removed, "remove_item: debe retornar true")
	assert(inv.get_all().size() == 0, "remove_item: size debe ser 0 tras eliminar")
	print("  - remove_item ok")


func _test_equip_get_equipped() -> void:
	var inv := _make_inventory()
	var item := _make_item(ItemData.Slot.ARMA)
	var instance: ItemData = inv.add_item(item)
	inv.equip(instance)
	var equipped: ItemData = inv.get_equipped(ItemData.Slot.ARMA)
	assert(equipped == instance, "get_equipped: debe retornar la instancia del inventario")
	print("  - equip / get_equipped ok")


func _test_unequip() -> void:
	var inv := _make_inventory()
	var item := _make_item(ItemData.Slot.ARMADURA)
	var instance: ItemData = inv.add_item(item)
	inv.equip(instance)
	var returned: ItemData = inv.unequip(ItemData.Slot.ARMADURA)
	assert(returned == instance, "unequip: debe retornar la instancia que estaba equipada")
	assert(inv.get_equipped(ItemData.Slot.ARMADURA) == null, "unequip: slot debe quedar null")
	print("  - unequip ok")


func _test_equip_auto_adds_to_inventory() -> void:
	# equip() agrega al inventario si el item no estaba ahí.
	var inv := _make_inventory()
	var item := _make_item(ItemData.Slot.ESCUDO)
	inv.equip(item)
	assert(inv.get_all().size() == 1, "equip sin add previo: item debe estar en inventario")
	print("  - equip auto-add ok")


func _test_remove_equipped_clears_slot() -> void:
	# remove_item de un item equipado debe limpiar el slot.
	var inv := _make_inventory()
	var item := _make_item(ItemData.Slot.ARMA)
	# equip sin add previo — internamente llama add_item y equipa la copia.
	inv.equip(item)
	# La instancia que vive en el inventario es la que está equipada.
	var equipped: ItemData = inv.get_equipped(ItemData.Slot.ARMA)
	inv.remove_item(equipped)
	assert(inv.get_equipped(ItemData.Slot.ARMA) == null, "remove equipado: slot debe quedar null")
	assert(inv.get_all().size() == 0, "remove equipado: inventario debe quedar vacío")
	print("  - remove_equipped_clears_slot ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_inventory() -> Node:
	# Instancia InventorySystem directo — sin add_child porque los métodos no requieren árbol.
	# Misma clase que el autoload, distinta instancia aislada para el test.
	var inv := load("res://scripts/systems/inventory_system.gd").new()
	return inv


func _make_item(slot: ItemData.Slot) -> ItemData:
	var item := ItemData.new()
	item.id = &"test_item"
	item.display_name = "Item de Test"
	item.slot = slot
	item.stat_main = 10
	return item
