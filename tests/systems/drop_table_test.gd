extends SceneTree
# Tests unitarios para DropTable.roll() y roll_materials_only().
# No requiere escena ni autoloads — instancia clases directamente.
# GDD §111: final_chance = clamp(drop_chance * (1 + 0.1 * momentum), 0.0, 1.0)
#
# Ejecución: godot --headless --script res://tests/systems/drop_table_test.gd

func _init() -> void:
	print("== drop_table_test ==")
	_test_empty_table()
	_test_single_material_chance_100_momentum_0()
	_test_single_material_chance_0_momentum_0()
	_test_chance_0_momentum_10_still_zero()
	_test_momentum_scaling_near_100_percent()
	_test_momentum_cap_at_1()
	_test_count_min_max_range()
	_test_roll_materials_only_filters_items()
	_test_multiple_entries_independent()
	# Milestone B
	_test_roll_items_only_filters_materials()
	_test_roll_items_only_empty_on_materials_only_table()
	_test_roll_items_only_empty_table()
	print("All passed.")
	quit()


# ─── Caso 1: tabla vacía → [] ─────────────────────────────────────────────────

func _test_empty_table() -> void:
	var table := DropTable.new()
	table.entries = []
	var results: Array = table.roll(0)
	assert(results.size() == 0, "tabla vacía: roll debe retornar []")
	print("  - empty_table ok")


# ─── Caso 2: 1 entry MATERIAL, chance=1.0, momentum=0 → 1 elemento ───────────

func _test_single_material_chance_100_momentum_0() -> void:
	var table := _make_table_single_material(1.0, 1, 1)
	var results: Array = table.roll(0)
	assert(results.size() == 1, "chance=1.0 momentum=0: debe retornar 1 resultado")
	assert(results[0]["type"] == "material", "tipo debe ser 'material'")
	var count: int = results[0]["count"]
	assert(count >= 1 and count <= 1, "count debe estar en [1, 1]")
	print("  - single_material_chance_100_momentum_0 ok")


# ─── Caso 3: chance=0.0, momentum=0 → [] ─────────────────────────────────────

func _test_single_material_chance_0_momentum_0() -> void:
	var table := _make_table_single_material(0.0, 1, 1)
	# Con chance 0 debe fallar siempre — probar N veces para confirmar.
	for i: int in range(50):
		var results: Array = table.roll(0)
		assert(results.size() == 0,
			"chance=0.0 momentum=0: roll debe retornar [] (iter %d)" % i)
	print("  - chance_0_momentum_0 ok")


# ─── Caso 4: chance=0.0, momentum=10 → sigue siendo [] ──────────────────────
# Clamp respeta el 0 base: 0.0 * (1 + 1.0) = 0.0, clamp no cambia nada.

func _test_chance_0_momentum_10_still_zero() -> void:
	var table := _make_table_single_material(0.0, 1, 1)
	for i: int in range(50):
		var results: Array = table.roll(10)
		assert(results.size() == 0,
			"chance=0.0 momentum=10: fórmula da 0.0, debe seguir siendo [] (iter %d)" % i)
	print("  - chance_0_momentum_10_still_zero ok")


# ─── Caso 5: momentum scaling → 0.5 * (1 + 1.0) = 1.0 → ≥980/1000 ──────────

func _test_momentum_scaling_near_100_percent() -> void:
	var table := _make_table_single_material(0.5, 1, 1)
	var hits: int = 0
	var iterations: int = 1000
	for i: int in range(iterations):
		var results: Array = table.roll(10)
		if results.size() > 0:
			hits += 1
	# 0.5 * (1 + 0.1*10) = 0.5 * 2.0 = 1.0 → debe dropear siempre.
	# Toleramos 980/1000 por si hay fluctuación en float, pero con chance exacta 1.0 deben ser 1000.
	assert(hits >= 980, "momentum scaling: esperado ≥980 hits, obtuvo %d" % hits)
	print("  - momentum_scaling ok (%d/1000 hits)" % hits)


# ─── Caso 6: cap a 1.0 → 0.8 * 2.0 = 1.6 → clamp a 1.0 → 100% drops ────────

func _test_momentum_cap_at_1() -> void:
	var table := _make_table_single_material(0.8, 1, 1)
	var hits: int = 0
	var iterations: int = 200
	for i: int in range(iterations):
		var results: Array = table.roll(10)
		if results.size() > 0:
			hits += 1
	# 0.8 * (1 + 0.1*10) = 1.6 → clamp → 1.0 → 100% siempre.
	assert(hits == iterations,
		"cap a 1.0: esperado %d/200 hits, obtuvo %d" % [iterations, hits])
	print("  - momentum_cap ok (%d/%d)" % [hits, iterations])


# ─── Caso 7: count cae en [min, max] y media tiende a ~3.5 ──────────────────

func _test_count_min_max_range() -> void:
	var table := _make_table_single_material(1.0, 2, 5)
	var total_count: int = 0
	var iterations: int = 1000
	for i: int in range(iterations):
		var results: Array = table.roll(0)
		assert(results.size() == 1, "count_min_max: siempre debe dropear con chance=1.0")
		var c: int = results[0]["count"]
		assert(c >= 2 and c <= 5, "count fuera de [2,5]: obtuvo %d" % c)
		total_count += c
	var mean: float = float(total_count) / float(iterations)
	# Media esperada de randi_range(2,5) = (2+3+4+5)/4 = 3.5. Toleramos ±0.3.
	assert(mean >= 3.2 and mean <= 3.8,
		"media de count esperada ~3.5, obtuvo %.3f" % mean)
	print("  - count_min_max ok (mean=%.3f)" % mean)


# ─── Caso 8: roll_materials_only filtra ITEM entries ─────────────────────────

func _test_roll_materials_only_filters_items() -> void:
	var material_entry := _make_material_entry(1.0, 1, 1)
	var item_entry := _make_item_entry(1.0)
	var table := DropTable.new()
	table.entries = [material_entry, item_entry]
	var results: Array = table.roll_materials_only(0)
	assert(results.size() == 1, "roll_materials_only: debe retornar solo 1 (el material)")
	assert(results[0]["type"] == "material", "el resultado debe ser de tipo 'material'")
	print("  - roll_materials_only_filters ok")


# ─── Caso 9: múltiples entries son independientes (no exclusivas) ─────────────

func _test_multiple_entries_independent() -> void:
	var entry_a := _make_material_entry(1.0, 1, 1)
	# Material B distinto para que no sean el mismo objeto.
	var mat_b := _make_material(&"mat_b", "Material B")
	var entry_b := DropEntry.new()
	entry_b.drop_type = DropEntry.DropType.MATERIAL
	entry_b.material_data = mat_b
	entry_b.material_count_min = 1
	entry_b.material_count_max = 1
	entry_b.drop_chance = 1.0
	var table := DropTable.new()
	table.entries = [entry_a, entry_b]
	var results: Array = table.roll(0)
	# Ambas entries con chance=1.0 deben caer siempre.
	assert(results.size() == 2,
		"entries independientes: ambas chance=1.0 → debe retornar 2, obtuvo %d" % results.size())
	print("  - multiple_entries_independent ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_material(id: StringName, display: String) -> MaterialData:
	var m := MaterialData.new()
	m.id = id
	m.display_name = display
	m.max_stack = 99
	return m


func _make_material_entry(chance: float, count_min: int, count_max: int) -> DropEntry:
	var entry := DropEntry.new()
	entry.drop_type = DropEntry.DropType.MATERIAL
	entry.material_data = _make_material(&"mat_test", "Material Test")
	entry.drop_chance = chance
	entry.material_count_min = count_min
	entry.material_count_max = count_max
	return entry


func _make_item_entry(chance: float) -> DropEntry:
	# Item mínimo — ItemData necesita id y slot para no romper, pero no cargamos .tres.
	var item := ItemData.new()
	item.id = &"item_test"
	item.display_name = "Item Test"
	item.slot = ItemData.Slot.ARMA
	var entry := DropEntry.new()
	entry.drop_type = DropEntry.DropType.ITEM
	entry.item_data = item
	entry.drop_chance = chance
	return entry


func _make_table_single_material(chance: float, count_min: int, count_max: int) -> DropTable:
	var table := DropTable.new()
	table.entries = [_make_material_entry(chance, count_min, count_max)]
	return table


# ─── Caso 10 (Milestone B): roll_items_only filtra materiales, retorna solo items ──

func _test_roll_items_only_filters_materials() -> void:
	var material_entry := _make_material_entry(1.0, 1, 1)
	var item_entry := _make_item_entry(1.0)
	var table := DropTable.new()
	table.entries = [material_entry, item_entry]
	var results: Array = table.roll_items_only(0)
	assert(results.size() == 1, "roll_items_only: tabla mixta → solo 1 item, obtuvo %d" % results.size())
	assert(results[0]["type"] == "item", "roll_items_only: el resultado debe ser de tipo 'item'")
	print("  - roll_items_only_filters_materials ok")


# ─── Caso 11 (Milestone B): tabla solo materiales → roll_items_only retorna [] ──

func _test_roll_items_only_empty_on_materials_only_table() -> void:
	var table := _make_table_single_material(1.0, 1, 1)
	var results: Array = table.roll_items_only(0)
	assert(results.size() == 0,
		"roll_items_only en tabla solo-materiales: debe retornar [], obtuvo %d" % results.size())
	print("  - roll_items_only_empty_on_materials_only ok")


# ─── Caso 12 (Milestone B): tabla vacía → roll_items_only retorna [] ─────────

func _test_roll_items_only_empty_table() -> void:
	var table := DropTable.new()
	table.entries = []
	var results: Array = table.roll_items_only(0)
	assert(results.size() == 0, "roll_items_only en tabla vacía: debe retornar []")
	print("  - roll_items_only_empty_table ok")
