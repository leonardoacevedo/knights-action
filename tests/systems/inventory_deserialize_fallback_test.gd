extends SceneTree
# Regresión A9: InventorySystem._deserialize_item debe resolver un item por base_id
# cuando base_path es inválido (el .tres se movió/renombró), en vez de perder el item.
#
# Testeable headless: load() y DirAccess funcionan sin escena (igual que boss_phases_test.gd
# que carga .tres de disco). El fallback escanea res://resources/items/ por id.
# Usamos un item real existente: cota_glacial (resources/items/armor/cota_glacial.tres).
#
# Ejecución: godot --headless --script res://tests/systems/inventory_deserialize_fallback_test.gd

const REAL_ITEM_ID := &"cota_glacial"
const REAL_ITEM_PATH := "res://resources/items/armor/cota_glacial.tres"
const BAD_PATH := "res://resources/items/armor/__no_existe__.tres"

func _init() -> void:
	print("== inventory_deserialize_fallback_test ==")
	_test_fallback_resolves_by_base_id()
	_test_fallback_applies_overrides()
	_test_happy_path_still_uses_base_path()
	_test_unresolvable_returns_null()
	print("All passed.")
	quit()


# ─── base_path inválido + base_id válido → resuelve por id ────────────────────
func _test_fallback_resolves_by_base_id() -> void:
	var inv := _make_inventory()
	var dict := {
		"base_path": BAD_PATH,         # no existe → fuerza el fallback
		"base_id": str(REAL_ITEM_ID),  # válido → debe recuperarse por aquí
		"refinement_level": 0,
		"affixes": [],
	}
	var item: ItemData = inv._deserialize_item(dict)
	assert(item != null, "A9: con base_path inválido pero base_id válido NO debe perderse el item")
	assert(item.id == REAL_ITEM_ID,
		"A9: el item recuperado debe tener id '%s', obtuvo '%s'" % [REAL_ITEM_ID, str(item.id)])
	print("  - fallback_resolves_by_base_id ok")


# ─── El fallback igual aplica los overrides del save (refinement_level) ───────
func _test_fallback_applies_overrides() -> void:
	var inv := _make_inventory()
	var dict := {
		"base_path": BAD_PATH,
		"base_id": str(REAL_ITEM_ID),
		"refinement_level": 5,
		"affixes": [],
	}
	var item: ItemData = inv._deserialize_item(dict)
	assert(item != null, "A9: fallback debe resolver el item")
	assert(item.refinement_level == 5,
		"A9: el override refinement_level (5) debe aplicarse, es %d" % item.refinement_level)
	print("  - fallback_applies_overrides ok")


# ─── Camino feliz: base_path válido sigue resolviendo (no rompe el fix) ───────
func _test_happy_path_still_uses_base_path() -> void:
	var inv := _make_inventory()
	var dict := {
		"base_path": REAL_ITEM_PATH,   # válido → camino normal, sin fallback
		"base_id": str(REAL_ITEM_ID),
		"refinement_level": 2,
		"affixes": [],
	}
	var item: ItemData = inv._deserialize_item(dict)
	assert(item != null, "A9: con base_path válido debe resolver normal")
	assert(item.id == REAL_ITEM_ID, "A9: id debe ser '%s'" % REAL_ITEM_ID)
	# La instancia debe ser una copia propia, no el recurso compartido del disco.
	assert(item.resource_path == "" or item != (load(REAL_ITEM_PATH) as ItemData),
		"A9: el item deserializado debe ser una instancia duplicada, no el recurso compartido")
	print("  - happy_path_still_uses_base_path ok")


# ─── Ni path ni id resolubles → null (item perdido, comportamiento esperado) ──
func _test_unresolvable_returns_null() -> void:
	var inv := _make_inventory()
	var dict := {
		"base_path": BAD_PATH,
		"base_id": "__id_inexistente__",
		"refinement_level": 0,
		"affixes": [],
	}
	var item: ItemData = inv._deserialize_item(dict)
	assert(item == null,
		"A9: con path inválido e id inexistente debe devolver null (no inventar item)")
	print("  - unresolvable_returns_null ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_inventory() -> Node:
	return load("res://scripts/systems/inventory_system.gd").new()
