extends SceneTree
# Regresión A4: al reemplazar un item en un slot ocupado, InventorySystem.equip
# debe emitir unequipped(slot, prev_item) con prev_item == la pieza anterior.
# Instancia el InventorySystem real aislado (patrón inventory_system_test.gd).
# Ejecución: godot --headless --script res://tests/systems/inventory_unequipped_signal_test.gd

func _init() -> void:
	print("== inventory_unequipped_signal_test ==")
	_test_replace_emits_unequipped_with_prev()
	_test_first_equip_does_not_emit_unequipped()
	_test_replace_updates_equipped_to_new()
	print("All passed.")
	quit()


# ─── Equipar A, luego B en el mismo slot → unequipped(slot, A) ────────────────
func _test_replace_emits_unequipped_with_prev() -> void:
	var inv := _make_inventory()
	# add_item devuelve la copia que vive en el inventario — esa es la que se equipa.
	var item_a: ItemData = inv.add_item(_make_item(ItemData.Slot.ARMA, &"item_a"))
	var item_b: ItemData = inv.add_item(_make_item(ItemData.Slot.ARMA, &"item_b"))

	# Capturar la signal unequipped.
	var captured: Dictionary = { "fired": false, "slot": -1, "prev": null }
	inv.unequipped.connect(func(slot: ItemData.Slot, prev_item: ItemData) -> void:
		captured["fired"] = true
		captured["slot"] = slot
		captured["prev"] = prev_item)

	inv.equip(item_a)   # slot ARMA ← A (no debe emitir unequipped: slot estaba vacío)
	assert(captured["fired"] == false, "A4: el primer equip no debe emitir unequipped")

	inv.equip(item_b)   # slot ARMA ← B, desplaza a A → debe emitir unequipped(ARMA, A)
	assert(captured["fired"] == true, "A4: reemplazar en slot ocupado debe emitir unequipped")
	assert(captured["slot"] == ItemData.Slot.ARMA,
		"A4: unequipped debe reportar el slot ARMA")
	assert(captured["prev"] == item_a,
		"A4: prev_item debe ser exactamente la pieza anterior (A)")
	print("  - replace_emits_unequipped_with_prev ok")


# ─── Equipar en slot vacío NO debe emitir unequipped ──────────────────────────
func _test_first_equip_does_not_emit_unequipped() -> void:
	var inv := _make_inventory()
	var item: ItemData = inv.add_item(_make_item(ItemData.Slot.ESCUDO, &"escudo_x"))
	var fired: Array[bool] = [false]
	inv.unequipped.connect(func(_slot: ItemData.Slot, _prev: ItemData) -> void:
		fired[0] = true)
	inv.equip(item)
	assert(fired[0] == false, "A4: equipar en slot vacío no debe emitir unequipped")
	print("  - first_equip_does_not_emit_unequipped ok")


# ─── Tras el reemplazo, el slot queda con B (no con A) ────────────────────────
func _test_replace_updates_equipped_to_new() -> void:
	var inv := _make_inventory()
	var item_a: ItemData = inv.add_item(_make_item(ItemData.Slot.ARMADURA, &"arm_a"))
	var item_b: ItemData = inv.add_item(_make_item(ItemData.Slot.ARMADURA, &"arm_b"))
	inv.equip(item_a)
	inv.equip(item_b)
	assert(inv.get_equipped(ItemData.Slot.ARMADURA) == item_b,
		"A4: tras reemplazar, el slot debe tener B")
	# A queda en el inventario (no se elimina al desequipar por reemplazo).
	assert(inv.get_all().has(item_a),
		"A4: la pieza desplazada A debe seguir en el inventario")
	print("  - replace_updates_equipped_to_new ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_inventory() -> Node:
	return load("res://scripts/systems/inventory_system.gd").new()


func _make_item(slot: ItemData.Slot, id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = str(id)
	item.slot = slot
	item.stat_main = 10
	return item
