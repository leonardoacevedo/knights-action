extends SceneTree
# Regresión A7: InventorySystem.add_material debe respetar max_stack y devolver
# la cantidad REALMENTE agregada (puede ser < la pedida). No debe exceder el cap.
# Instancia el InventorySystem real aislado (mismo patrón que inventory_system_test.gd).
# Ejecución: godot --headless --script res://tests/systems/inventory_material_overflow_test.gd

func _init() -> void:
	print("== inventory_material_overflow_test ==")
	_test_add_within_cap_returns_full()
	_test_add_overflow_caps_and_returns_partial()
	_test_add_to_full_stack_returns_zero()
	print("All passed.")
	quit()


# ─── Agregar por debajo del cap → devuelve la cantidad completa ───────────────
func _test_add_within_cap_returns_full() -> void:
	var inv := _make_inventory()
	var mat := _make_material(&"mat_cap", 10)
	var added: int = inv.add_material(mat, 4)
	assert(added == 4, "A7: dentro del cap debe agregar 4, devolvió %d" % added)
	assert(inv.get_material_count(&"mat_cap") == 4,
		"A7: stock debe ser 4, es %d" % inv.get_material_count(&"mat_cap"))
	print("  - add_within_cap_returns_full ok")


# ─── Llenar al máximo y pedir más → devuelve solo lo que cupo, no excede cap ──
func _test_add_overflow_caps_and_returns_partial() -> void:
	var inv := _make_inventory()
	var mat := _make_material(&"mat_cap", 10)
	# Dejar el stack en 8 (faltan 2 para el cap de 10).
	inv.add_material(mat, 8)
	# Pedir 5 más: solo deben caber 2.
	var added: int = inv.add_material(mat, 5)
	assert(added == 2, "A7: con 8/10 y pidiendo 5, debe agregar solo 2, devolvió %d" % added)
	assert(added < 5, "A7: el retorno debe ser MENOR a lo pedido (5)")
	assert(inv.get_material_count(&"mat_cap") == 10,
		"A7: stock no debe exceder el cap de 10, es %d" % inv.get_material_count(&"mat_cap"))
	print("  - add_overflow_caps_and_returns_partial ok")


# ─── Stack ya lleno → devuelve 0 y no cambia el stock ─────────────────────────
func _test_add_to_full_stack_returns_zero() -> void:
	var inv := _make_inventory()
	var mat := _make_material(&"mat_cap", 10)
	inv.add_material(mat, 10)  # lleno exacto
	var added: int = inv.add_material(mat, 7)
	assert(added == 0, "A7: stack lleno debe devolver 0, devolvió %d" % added)
	assert(inv.get_material_count(&"mat_cap") == 10,
		"A7: stock debe seguir en 10, es %d" % inv.get_material_count(&"mat_cap"))
	print("  - add_to_full_stack_returns_zero ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_inventory() -> Node:
	# Instancia el InventorySystem real (misma clase que el autoload, instancia aislada).
	return load("res://scripts/systems/inventory_system.gd").new()


func _make_material(id: StringName, max_stack: int) -> MaterialData:
	var mat := MaterialData.new()
	mat.id = id
	mat.display_name = str(id)
	mat.max_stack = max_stack
	return mat
