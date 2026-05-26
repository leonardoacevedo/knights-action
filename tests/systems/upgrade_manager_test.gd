extends SceneTree
# Tests unitarios para UpgradeManager. GDD §5.6.
# No requiere escena — instancia las clases directamente y simula InventorySystem
# con un objeto stub mínimo.
#
# Ejecución: godot --headless --script res://tests/systems/upgrade_manager_test.gd

# ─── Stub de InventorySystem ──────────────────────────────────────────────────
# UpgradeManager llama a InventorySystem como autoload. En el contexto de tests
# headless los autoloads no cargan, así que sustituimos con un objeto duck-type.

class FakeInventory:
	var _stock: Dictionary = {}  # StringName id → int count

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

	func add(id: StringName, count: int) -> void:
		_stock[id] = _stock.get(id, 0) + count

	func clear_all() -> void:
		_stock.clear()


# ─── Setup ────────────────────────────────────────────────────────────────────

var _manager: UpgradeManager
var _inventory: FakeInventory

func _init() -> void:
	print("== upgrade_manager_test ==")
	_setup()
	_test_can_refine_null()
	_test_can_refine_max_level()
	_test_get_target_level()
	_test_get_success_chance()
	_test_get_penalty_type()
	_test_abort_no_stones()
	_test_fail_level_loss_no_scroll()
	_test_fail_level_loss_with_scroll()
	_test_success_level_1_to_4()
	_test_abort_max_level_attempt()
	_test_abort_scroll_not_applicable()
	_test_stat_formula()
	print("All passed.")
	quit()


func _setup() -> void:
	_manager = UpgradeManager.new()
	_inventory = FakeInventory.new()
	# Reemplazar referencia al autoload con el stub.
	# UpgradeManager llama a InventorySystem como nombre de clase; en tests lo inyectamos
	# poniendo el stub en una variable accesible. Como GDScript no tiene mocking nativo,
	# usamos una propiedad pública expuesta solo para tests.
	# Ver nota en "Decisiones técnicas" del doc de feature.
	_manager.set("_inventory_override", _inventory)


# ─── Helper: crear item con nivel dado ───────────────────────────────────────

func _make_item(refinement_level: int) -> ItemData:
	var item := ItemData.new()
	item.id = &"item_test"
	item.display_name = "Item de Test"
	item.slot = ItemData.Slot.ARMA
	item.stat_main = 100
	item.refinement_level = refinement_level
	return item


# ─── Helper: dar materiales al inventario stub ────────────────────────────────

func _give_stones(count: int) -> void:
	_inventory.add(&"piedra_resonancia", count)

func _give_scrolls(count: int) -> void:
	_inventory.add(&"pergamino_proteccion", count)

func _clear_inventory() -> void:
	_inventory.clear_all()


# ─── Caso 1: can_refine con item null → false ─────────────────────────────────

func _test_can_refine_null() -> void:
	assert(_manager.can_refine(null) == false, "can_refine(null) debe ser false")
	print("  - can_refine_null ok")


# ─── Caso 2: can_refine con item +10 → false ─────────────────────────────────

func _test_can_refine_max_level() -> void:
	var item := _make_item(10)
	assert(_manager.can_refine(item) == false, "can_refine(+10) debe ser false")
	print("  - can_refine_max_level ok")


# ─── Caso 3: get_target_level con item +5 → 6 ────────────────────────────────

func _test_get_target_level() -> void:
	var item := _make_item(5)
	assert(_manager.get_target_level(item) == 6,
		"get_target_level(+5) debe retornar 6, obtuvo %d" % _manager.get_target_level(item))
	print("  - get_target_level ok")


# ─── Caso 4: get_success_chance(7) → 0.50 ────────────────────────────────────

func _test_get_success_chance() -> void:
	var chance: float = _manager.get_success_chance(7)
	assert(abs(chance - 0.50) < 0.001,
		"get_success_chance(7) debe ser 0.50, obtuvo %.4f" % chance)
	print("  - get_success_chance ok")


# ─── Caso 5: get_penalty_type por nivel ──────────────────────────────────────

func _test_get_penalty_type() -> void:
	assert(_manager.get_penalty_type(3) == "none",
		"penalty(3) debe ser 'none'")
	assert(_manager.get_penalty_type(5) == "materials_only",
		"penalty(5) debe ser 'materials_only'")
	assert(_manager.get_penalty_type(8) == "level_loss",
		"penalty(8) debe ser 'level_loss'")
	print("  - get_penalty_type ok")


# ─── Caso 6: attempt_refine sin Piedras → abortado, nivel sin cambio ──────────

func _test_abort_no_stones() -> void:
	_clear_inventory()
	var item := _make_item(0)
	var aborted_reason: String = ""
	_manager.refine_aborted.connect(func(reason: String) -> void:
		aborted_reason = reason, CONNECT_ONE_SHOT)

	var result: RefineResult = _manager.attempt_refine(item)

	assert(result == null, "attempt_refine sin Piedras debe retornar null")
	assert(aborted_reason == "insufficient_materials",
		"reason debe ser 'insufficient_materials', obtuvo: '%s'" % aborted_reason)
	assert(item.refinement_level == 0, "nivel no debe cambiar si abortado")
	print("  - abort_no_stones ok")


# ─── Caso 7: item +9, fallo forzado, sin pergamino → baja a +8 ───────────────

func _test_fail_level_loss_no_scroll() -> void:
	_clear_inventory()
	_give_stones(1)
	var item := _make_item(9)
	_manager._test_force_outcome(false)  # forzar fallo

	var failed_result: RefineResult = null
	_manager.refine_failed.connect(func(r: RefineResult) -> void:
		failed_result = r, CONNECT_ONE_SHOT)

	var result: RefineResult = _manager.attempt_refine(item, false)

	assert(result != null, "result no debe ser null")
	assert(result.success == false, "debe fallar")
	assert(result.dropped_to_level == true, "debe marcar dropped_to_level")
	assert(item.refinement_level == 8,
		"item debe bajar a +8, obtuvo +%d" % item.refinement_level)
	assert(result.new_level == 8, "result.new_level debe ser 8")
	assert(result.previous_level == 9, "result.previous_level debe ser 9")
	assert(result.protected_by_scroll == false, "no debe estar protegido")
	# Verificar que la Piedra se consumió.
	assert(_inventory.get_material_count(&"piedra_resonancia") == 0,
		"Piedra debe haberse consumido en fallo")
	print("  - fail_level_loss_no_scroll ok")


# ─── Caso 8: item +9, fallo forzado, con pergamino → queda en +9, pergamino consumido

func _test_fail_level_loss_with_scroll() -> void:
	_clear_inventory()
	_give_stones(1)
	_give_scrolls(1)
	var item := _make_item(9)
	_manager._test_force_outcome(false)  # forzar fallo

	var result: RefineResult = _manager.attempt_refine(item, true)

	assert(result != null, "result no debe ser null")
	assert(result.success == false, "debe fallar")
	assert(result.dropped_to_level == false, "con pergamino NO debe bajar nivel")
	assert(item.refinement_level == 9, "item debe quedarse en +9 (protegido)")
	assert(result.new_level == 9, "result.new_level debe ser 9")
	assert(result.protected_by_scroll == true, "debe marcar protected_by_scroll")
	# Pergamino consumido aunque falló.
	assert(_inventory.get_material_count(&"pergamino_proteccion") == 0,
		"Pergamino debe haberse consumido aunque el intento falló")
	# Piedra también consumida.
	assert(_inventory.get_material_count(&"piedra_resonancia") == 0,
		"Piedra debe haberse consumido también")
	print("  - fail_level_loss_with_scroll ok")


# ─── Caso 9: item +3 (100% success) → sube a +4, exactamente 1 Piedra consumida

func _test_success_level_1_to_4() -> void:
	_clear_inventory()
	_give_stones(1)
	var item := _make_item(3)
	# Nivel +4 tiene 100% de éxito... espera, +4 tiene 70%.
	# +3 → +4 tiene success_chance=0.70. Para el test garantizamos con force.
	_manager._test_force_outcome(true)  # forzar éxito

	var result: RefineResult = _manager.attempt_refine(item, false)

	assert(result != null, "result no debe ser null")
	assert(result.success == true, "debe ser éxito")
	assert(item.refinement_level == 4, "item debe subir a +4")
	assert(result.new_level == 4, "result.new_level debe ser 4")
	assert(result.previous_level == 3, "result.previous_level debe ser 3")
	# Solo 1 Piedra consumida, nada más.
	assert(_inventory.get_material_count(&"piedra_resonancia") == 0,
		"Exactamente 1 Piedra debe haberse consumido")
	assert(result.materials_consumed.get(&"piedra_resonancia", 0) == 1,
		"result.materials_consumed debe registrar 1 piedra_resonancia")
	print("  - success_level_1_to_4 ok")


# ─── Caso 10: attempt_refine con item +10 → abortado "max_level" ─────────────

func _test_abort_max_level_attempt() -> void:
	_clear_inventory()
	_give_stones(5)
	var item := _make_item(10)
	var aborted_reason: String = ""
	_manager.refine_aborted.connect(func(reason: String) -> void:
		aborted_reason = reason, CONNECT_ONE_SHOT)

	var result: RefineResult = _manager.attempt_refine(item)

	assert(result == null, "attempt con +10 debe retornar null")
	assert(aborted_reason == "max_level",
		"reason debe ser 'max_level', obtuvo: '%s'" % aborted_reason)
	assert(item.refinement_level == 10, "nivel no debe cambiar")
	# Materiales no consumidos.
	assert(_inventory.get_material_count(&"piedra_resonancia") == 5,
		"Piedras no deben consumirse en abort max_level")
	print("  - abort_max_level ok")


# ─── Caso 11: scroll en nivel +5 → abortado "scroll_not_applicable" ──────────

func _test_abort_scroll_not_applicable() -> void:
	_clear_inventory()
	_give_stones(1)
	_give_scrolls(1)
	var item := _make_item(5)
	var aborted_reason: String = ""
	_manager.refine_aborted.connect(func(reason: String) -> void:
		aborted_reason = reason, CONNECT_ONE_SHOT)

	var result: RefineResult = _manager.attempt_refine(item, true)

	assert(result == null, "scroll en +5→+6 debe abortar")
	assert(aborted_reason == "scroll_not_applicable",
		"reason debe ser 'scroll_not_applicable', obtuvo: '%s'" % aborted_reason)
	# Ningún material consumido.
	assert(_inventory.get_material_count(&"piedra_resonancia") == 1,
		"Piedra no debe consumirse en abort scroll_not_applicable")
	assert(_inventory.get_material_count(&"pergamino_proteccion") == 1,
		"Pergamino no debe consumirse en abort scroll_not_applicable")
	print("  - abort_scroll_not_applicable ok")


# ─── Caso 12: fórmula stat_final coincide con GDD §5.6 ───────────────────────

func _test_stat_formula() -> void:
	var item := _make_item(0)
	item.stat_main = 100
	# +0: 100 * (1 + 0.05 * 0) = 100.0
	assert(abs(item.refined_stat() - 100.0) < 0.001,
		"+0: stat debe ser 100.0, obtuvo %.4f" % item.refined_stat())
	item.refinement_level = 5
	# +5: 100 * (1 + 0.05 * 5) = 125.0
	assert(abs(item.refined_stat() - 125.0) < 0.001,
		"+5: stat debe ser 125.0, obtuvo %.4f" % item.refined_stat())
	item.refinement_level = 10
	# +10: 100 * (1 + 0.05 * 10) = 150.0
	assert(abs(item.refined_stat() - 150.0) < 0.001,
		"+10: stat debe ser 150.0, obtuvo %.4f" % item.refined_stat())
	print("  - stat_formula ok")
