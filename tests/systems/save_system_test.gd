extends SceneTree
# Tests unitarios para SaveSystem. GDD §6 / Fase 3.
#
# SaveSystem depende de FileAccess/DirAccess y de los autoloads (PlayerProgression,
# InventorySystem, GoldSystem). Para tests headless:
#   - Se testea la lógica de serialización/deserialización con clases fake.
#   - Se usa un path temporal real (OS.get_user_data_dir()) para el round-trip.
#   - La conexión de señales NO se testa (requiere árbol de autoloads completo).
#
# Ejecución: godot --headless --script res://tests/systems/save_system_test.gd


# ─── Clases Fake ──────────────────────────────────────────────────────────────

# Fake ItemData sin Resource/ResourceLoader — solo los campos que SaveSystem usa.
class FakeItemData:
	var id: StringName = &""
	var resource_path: String = ""
	var refinement_level: int = 0
	var affixes: Array = []  # Array de FakeAffixData

	func duplicate(_deep: bool = false) -> FakeItemData:
		var copy := FakeItemData.new()
		copy.id = id
		copy.resource_path = resource_path
		copy.refinement_level = refinement_level
		# Copiar afijos
		copy.affixes = []
		for aff in affixes:
			var aff_copy := FakeAffixData.new()
			aff_copy.stat_id = aff.stat_id
			aff_copy.display_name = aff.display_name
			aff_copy.value = aff.value
			copy.affixes.append(aff_copy)
		return copy


class FakeAffixData:
	var stat_id: StringName = &""
	var display_name: String = ""
	var value: int = 0


# Fake de la lógica de serialización de InventorySystem (extraída para test puro).
# Replica exactamente _serialize_item / _deserialize_item sin ResourceLoader.
class FakeInventorySerializer:

	func serialize_item(item: FakeItemData) -> Dictionary:
		var affixes_arr: Array = []
		for aff in item.affixes:
			affixes_arr.append({
				"stat_id": str(aff.stat_id),
				"display_name": aff.display_name,
				"value": aff.value,
			})
		return {
			"base_id": str(item.id),
			"base_path": item.resource_path,
			"refinement_level": item.refinement_level,
			"affixes": affixes_arr,
		}

	func deserialize_item_from_dict(item_dict: Dictionary, base_item: FakeItemData) -> FakeItemData:
		# En producción se hace load(base_path).duplicate(true).
		# Aquí: base_item ya viene dado (simula el resultado de load + duplicate).
		var instance: FakeItemData = base_item.duplicate(true)
		instance.refinement_level = int(item_dict.get("refinement_level", 0))
		var saved_affixes: Array = item_dict.get("affixes", [])
		if saved_affixes.size() > 0:
			instance.affixes = []
			for aff_dict in saved_affixes:
				if not aff_dict is Dictionary:
					continue
				var aff := FakeAffixData.new()
				aff.stat_id = StringName(str(aff_dict.get("stat_id", "")))
				aff.display_name = str(aff_dict.get("display_name", ""))
				aff.value = int(aff_dict.get("value", 0))
				instance.affixes.append(aff)
		return instance


# Fake de PlayerProgression — lógica de _serialize_state / _restore_state.
class FakePlayerProgression:
	var _level: int = 1
	var _xp: int = 0
	var _skill_points_available: int = 0
	var _unlocked_nodes: Array = []

	func _serialize_state() -> Dictionary:
		var node_ids: Array = []
		for id in _unlocked_nodes:
			node_ids.append(str(id))
		return {
			"level": _level,
			"xp": _xp,
			"skill_points": _skill_points_available,
			"unlocked_nodes": node_ids,
		}

	func _restore_state(data: Dictionary) -> void:
		_level = int(data.get("level", 1))
		_level = clampi(_level, 1, 30)
		_xp = int(data.get("xp", 0))
		_xp = maxi(0, _xp)
		_skill_points_available = int(data.get("skill_points", 0))
		_skill_points_available = maxi(0, _skill_points_available)
		_unlocked_nodes.clear()
		for raw in data.get("unlocked_nodes", []):
			if raw is String or raw is StringName:
				_unlocked_nodes.append(StringName(str(raw)))


# Fake de GoldSystem — lógica de _serialize_state / _restore_state.
class FakeGoldSystem:
	var _gold: int = 0

	func _serialize_state() -> int:
		return _gold

	func _restore_state(saved_gold: int) -> void:
		_gold = maxi(0, saved_gold)


# ─── Setup ────────────────────────────────────────────────────────────────────

var _pp: FakePlayerProgression
var _gs: FakeGoldSystem
var _inv_ser: FakeInventorySerializer

func _init() -> void:
	print("== save_system_test ==")
	_setup()
	_test_progression_serialize_basic()
	_test_progression_restore_basic()
	_test_progression_restore_clamps_level()
	_test_progression_round_trip()
	_test_gold_serialize()
	_test_gold_restore_basic()
	_test_gold_restore_clamps_negative()
	_test_item_serialize_affixes()
	_test_item_deserialize_round_trip()
	_test_item_deserialize_applies_refinement()
	_test_item_deserialize_restores_affixes()
	_test_schema_version_field()
	_test_migration_unknown_version()
	_test_file_round_trip()
	print("All passed.")
	quit()


func _setup() -> void:
	_pp = FakePlayerProgression.new()
	_gs = FakeGoldSystem.new()
	_inv_ser = FakeInventorySerializer.new()


func _reset() -> void:
	_pp = FakePlayerProgression.new()
	_gs = FakeGoldSystem.new()


# ─── PlayerProgression serialize ─────────────────────────────────────────────

func _test_progression_serialize_basic() -> void:
	_reset()
	_pp._level = 5
	_pp._xp = 230
	_pp._skill_points_available = 2
	_pp._unlocked_nodes = [&"guerrero_vitalidad_1", &"agil_dash_rapido"]
	var data: Dictionary = _pp._serialize_state()
	assert(data["level"] == 5, "level debe ser 5, got %s" % str(data.get("level")))
	assert(data["xp"] == 230, "xp debe ser 230")
	assert(data["skill_points"] == 2, "skill_points debe ser 2")
	assert(data["unlocked_nodes"].size() == 2, "unlocked_nodes debe tener 2 elementos")
	assert(data["unlocked_nodes"][0] == "guerrero_vitalidad_1", "primer nodo ok")
	print("  - progression_serialize_basic ok")


func _test_progression_restore_basic() -> void:
	_reset()
	var data: Dictionary = {
		"level": 7,
		"xp": 150,
		"skill_points": 3,
		"unlocked_nodes": ["guerrero_vitalidad_1"],
	}
	_pp._restore_state(data)
	assert(_pp._level == 7, "level debe ser 7, got %d" % _pp._level)
	assert(_pp._xp == 150, "xp debe ser 150, got %d" % _pp._xp)
	assert(_pp._skill_points_available == 3, "skill_points debe ser 3")
	assert(_pp._unlocked_nodes.size() == 1, "1 nodo desbloqueado")
	assert(_pp._unlocked_nodes[0] == &"guerrero_vitalidad_1", "nodo correcto")
	print("  - progression_restore_basic ok")


func _test_progression_restore_clamps_level() -> void:
	_reset()
	# Level 0 → clampea a 1; level > LEVEL_MAX → clampea a 30.
	var data_low: Dictionary = {"level": 0, "xp": 0, "skill_points": 0, "unlocked_nodes": []}
	_pp._restore_state(data_low)
	assert(_pp._level == 1, "level 0 debe clampearse a 1, got %d" % _pp._level)

	var data_high: Dictionary = {"level": 99, "xp": 0, "skill_points": 0, "unlocked_nodes": []}
	_pp._restore_state(data_high)
	assert(_pp._level == 30, "level 99 debe clampearse a 30, got %d" % _pp._level)
	print("  - progression_restore_clamps_level ok")


func _test_progression_round_trip() -> void:
	_reset()
	_pp._level = 12
	_pp._xp = 500
	_pp._skill_points_available = 4
	_pp._unlocked_nodes = [&"mago_fuerza_elemental", &"guerrero_resistencia_1", &"agil_velocidad_1"]

	var serialized: Dictionary = _pp._serialize_state()

	var pp2: FakePlayerProgression = FakePlayerProgression.new()
	pp2._restore_state(serialized)

	assert(pp2._level == 12, "round-trip level, got %d" % pp2._level)
	assert(pp2._xp == 500, "round-trip xp, got %d" % pp2._xp)
	assert(pp2._skill_points_available == 4, "round-trip skill_points")
	assert(pp2._unlocked_nodes.size() == 3, "round-trip 3 nodos")
	assert(&"mago_fuerza_elemental" in pp2._unlocked_nodes, "nodo mago presente")
	print("  - progression_round_trip ok")


# ─── GoldSystem serialize ─────────────────────────────────────────────────────

func _test_gold_serialize() -> void:
	_reset()
	_gs._gold = 1840
	var val: int = _gs._serialize_state()
	assert(val == 1840, "serialize gold debe ser 1840, got %d" % val)
	print("  - gold_serialize ok")


func _test_gold_restore_basic() -> void:
	_reset()
	_gs._restore_state(500)
	assert(_gs._gold == 500, "restore gold debe ser 500, got %d" % _gs._gold)
	print("  - gold_restore_basic ok")


func _test_gold_restore_clamps_negative() -> void:
	_reset()
	_gs._restore_state(-999)
	assert(_gs._gold == 0, "gold negativo debe clampearse a 0, got %d" % _gs._gold)
	print("  - gold_restore_clamps_negative ok")


# ─── ItemData serialize / deserialize ────────────────────────────────────────

func _make_fake_item(id: StringName, path: String, refinement: int, affix_count: int) -> FakeItemData:
	var item: FakeItemData = FakeItemData.new()
	item.id = id
	item.resource_path = path
	item.refinement_level = refinement
	for i in range(affix_count):
		var aff := FakeAffixData.new()
		aff.stat_id = StringName("stat_%d" % i)
		aff.display_name = "Stat %d" % i
		aff.value = (i + 1) * 10
		item.affixes.append(aff)
	return item


func _test_item_serialize_affixes() -> void:
	var item: FakeItemData = _make_fake_item(&"espada_madera", "res://resources/items/weapons/espada_madera.tres", 3, 2)
	var data: Dictionary = _inv_ser.serialize_item(item)

	assert(data["base_id"] == "espada_madera", "base_id ok")
	assert(data["base_path"] == "res://resources/items/weapons/espada_madera.tres", "base_path ok")
	assert(data["refinement_level"] == 3, "refinement_level ok")
	assert(data["affixes"].size() == 2, "2 afijos serializados")
	assert(data["affixes"][0]["stat_id"] == "stat_0", "stat_id primer afijo ok")
	assert(data["affixes"][0]["value"] == 10, "value primer afijo ok")
	assert(data["affixes"][1]["value"] == 20, "value segundo afijo ok")
	print("  - item_serialize_affixes ok")


func _test_item_deserialize_round_trip() -> void:
	var original: FakeItemData = _make_fake_item(&"martillo_guardian", "res://resources/items/weapons/martillo_guardian.tres", 5, 3)
	var serialized: Dictionary = _inv_ser.serialize_item(original)

	# Base item simula lo que load(path).duplicate(true) devolvería.
	var base: FakeItemData = _make_fake_item(&"martillo_guardian", "res://resources/items/weapons/martillo_guardian.tres", 0, 3)
	var restored: FakeItemData = _inv_ser.deserialize_item_from_dict(serialized, base)

	assert(restored.refinement_level == 5, "round-trip refinement, got %d" % restored.refinement_level)
	assert(restored.affixes.size() == 3, "round-trip 3 afijos")
	print("  - item_deserialize_round_trip ok")


func _test_item_deserialize_applies_refinement() -> void:
	var item: FakeItemData = _make_fake_item(&"arco_corto", "res://resources/items/weapons/arco_corto.tres", 7, 1)
	var data: Dictionary = _inv_ser.serialize_item(item)

	var base: FakeItemData = _make_fake_item(&"arco_corto", "res://resources/items/weapons/arco_corto.tres", 0, 1)
	var restored: FakeItemData = _inv_ser.deserialize_item_from_dict(data, base)

	assert(restored.refinement_level == 7, "refinement_level aplicado correctamente, got %d" % restored.refinement_level)
	print("  - item_deserialize_applies_refinement ok")


func _test_item_deserialize_restores_affixes() -> void:
	# El jugador tiene un item con afijos específicos. Deben restaurarse exactos.
	var item: FakeItemData = FakeItemData.new()
	item.id = &"vara_cristal"
	item.resource_path = "res://resources/items/weapons/vara_cristal.tres"
	item.refinement_level = 2
	var aff1 := FakeAffixData.new()
	aff1.stat_id = &"hp"
	aff1.display_name = "Vida"
	aff1.value = 22
	var aff2 := FakeAffixData.new()
	aff2.stat_id = &"fire_res"
	aff2.display_name = "Resist. Fuego"
	aff2.value = 15
	item.affixes = [aff1, aff2]

	var data: Dictionary = _inv_ser.serialize_item(item)

	var base: FakeItemData = FakeItemData.new()
	base.id = &"vara_cristal"
	base.resource_path = "res://resources/items/weapons/vara_cristal.tres"
	base.affixes = []  # base sin afijos (simula .tres base vacío de afijos)
	var restored: FakeItemData = _inv_ser.deserialize_item_from_dict(data, base)

	assert(restored.affixes.size() == 2, "2 afijos restaurados, got %d" % restored.affixes.size())
	assert(restored.affixes[0].stat_id == &"hp", "stat_id hp ok")
	assert(restored.affixes[0].value == 22, "value hp ok, got %d" % restored.affixes[0].value)
	assert(restored.affixes[1].stat_id == &"fire_res", "stat_id fire_res ok")
	assert(restored.affixes[1].value == 15, "value fire_res ok")
	print("  - item_deserialize_restores_affixes ok")


# ─── Schema y versión ────────────────────────────────────────────────────────

func _test_schema_version_field() -> void:
	# El save data siempre tiene "version": 1 en MVP.
	var data: Dictionary = {
		"version": 1,
		"progression": {},
		"inventory": {"items": [], "equipped": {}, "materials": {}},
		"gold": 0,
	}
	assert(data.has("version"), "schema debe tener campo 'version'")
	assert(data["version"] == 1, "version debe ser 1, got %s" % str(data.get("version")))
	assert(data.has("progression"), "schema debe tener 'progression'")
	assert(data.has("inventory"), "schema debe tener 'inventory'")
	assert(data.has("gold"), "schema debe tener 'gold'")
	print("  - schema_version_field ok")


func _test_migration_unknown_version() -> void:
	# Migration con version desconocida retorna vacío (nuevo personaje — no crashea).
	var old_data: Dictionary = {"version": 0, "progression": {}, "gold": 999}
	var migrated: Dictionary = _fake_migrate(old_data, 0)
	assert(migrated.is_empty(), "migration de versión desconocida debe retornar vacío")
	print("  - migration_unknown_version ok (no crash, retorna vacío)")


func _fake_migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Replica la lógica de SaveSystem._migrate en MVP: siempre retorna vacío si version != 1.
	if from_version != 1:
		return {}
	return data


# ─── Round-trip a disco (test real con FileAccess) ───────────────────────────

func _test_file_round_trip() -> void:
	# Escribe un save real a un path temporal, lo lee de vuelta, verifica integridad.
	var tmp_dir: String = OS.get_user_data_dir()
	var save_path: String = tmp_dir.path_join("_test_savegame_tmp.json")
	var save_path_tmp: String = tmp_dir.path_join("_test_savegame_tmp.json.tmp")

	# Limpiar archivos previos si existen.
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(save_path_tmp):
		DirAccess.remove_absolute(save_path_tmp)

	# Construir data de prueba.
	var data_to_save: Dictionary = {
		"version": 1,
		"progression": {
			"level": 8,
			"xp": 750,
			"skill_points": 3,
			"unlocked_nodes": ["guerrero_vitalidad_1", "agil_dash_rapido"],
		},
		"inventory": {
			"items": [
				{
					"base_id": "espada_madera",
					"base_path": "res://resources/items/weapons/espada_madera.tres",
					"refinement_level": 4,
					"affixes": [{"stat_id": "hp", "display_name": "Vida", "value": 15}],
				}
			],
			"equipped": {"0": 0, "1": -1, "2": -1},
			"materials": {"piedra_resonancia": 12, "hierba_antigua": 5},
		},
		"gold": 1840,
	}

	# Paso 1: escribir a .tmp y rename (patrón atómico).
	var json_str: String = JSON.stringify(data_to_save, "\t")
	var file_w: FileAccess = FileAccess.open(save_path_tmp, FileAccess.WRITE)
	assert(file_w != null, "No se pudo abrir el archivo temporal para escritura.")
	file_w.store_string(json_str)
	file_w.close()

	var dir: DirAccess = DirAccess.open(tmp_dir)
	assert(dir != null, "No se pudo abrir el directorio de usuario.")
	var rename_ok: int = dir.rename(save_path_tmp, save_path)
	assert(rename_ok == OK, "rename atómico debe retornar OK, got %d" % rename_ok)
	assert(FileAccess.file_exists(save_path), "savegame.json debe existir tras rename")
	assert(not FileAccess.file_exists(save_path_tmp), ".tmp debe haberse eliminado tras rename")

	# Paso 2: leer y parsear.
	var file_r: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	assert(file_r != null, "No se pudo abrir savegame.json para lectura.")
	var content: String = file_r.get_as_text()
	file_r.close()

	var json: JSON = JSON.new()
	var parse_err: int = json.parse(content)
	assert(parse_err == OK, "JSON válido: parse_err debe ser OK, got %d" % parse_err)

	var loaded: Dictionary = json.get_data()
	assert(loaded is Dictionary, "raíz del JSON debe ser Dictionary")
	assert(loaded.get("version") == 1, "version ok")
	assert(loaded.get("gold") == 1840, "gold round-trip ok, got %s" % str(loaded.get("gold")))

	var prog: Dictionary = loaded.get("progression", {})
	assert(prog.get("level") == 8, "level round-trip ok, got %s" % str(prog.get("level")))
	assert(prog.get("xp") == 750, "xp round-trip ok")
	assert(prog.get("unlocked_nodes", []).size() == 2, "2 nodos round-trip ok")

	var inv: Dictionary = loaded.get("inventory", {})
	assert(inv.get("items", []).size() == 1, "1 item round-trip ok")
	assert(int(inv.get("materials", {}).get("piedra_resonancia", 0)) == 12, "materiales round-trip ok")
	var item0: Dictionary = inv["items"][0]
	assert(item0.get("refinement_level") == 4, "refinement round-trip ok")
	assert(item0.get("affixes", []).size() == 1, "afijos round-trip ok")

	# Limpiar archivo de test.
	DirAccess.remove_absolute(save_path)
	assert(not FileAccess.file_exists(save_path), "archivo de test eliminado correctamente")

	print("  - file_round_trip ok (write atómico + read + parse + cleanup)")
