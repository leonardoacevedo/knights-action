extends SceneTree
# Tests unitarios para PlayerProgression. GDD §6.
# No requiere escena — instancia las clases directamente.
# Los autoloads no cargan en headless, así que inyectamos FakeInventory.
#
# Ejecución: godot --headless --script res://tests/systems/player_progression_test.gd

# ─── Stub de InventorySystem ──────────────────────────────────────────────────

class FakeInventory:
	var _stock: Dictionary = {}

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

var _prog: PlayerProgression
var _inv: FakeInventory


func _init() -> void:
	print("== player_progression_test ==")
	_setup()
	_test_xp_formula_level_1()
	_test_xp_formula_level_10()
	_test_xp_formula_level_30()
	_test_add_xp_no_levelup()
	_test_add_xp_single_levelup()
	_test_add_xp_multi_levelup()
	_test_cap_at_level_30()
	_test_unlock_invalid_id()
	_test_unlock_no_points()
	_test_unlock_prereq_not_met()
	_test_unlock_happy_path()
	_test_is_unlocked()
	_test_can_unlock()
	_test_skill_bonus_flat()
	_test_respec_no_materials()
	_test_respec_happy_path()
	_test_determinism()
	print("All passed.")
	quit()


func _setup() -> void:
	_prog = PlayerProgression.new()
	_inv = FakeInventory.new()
	_prog._inventory_override = _inv
	# Sin árbol cargado (headless no tiene res://). Creamos árbol mínimo en memoria.
	_prog._tree = _make_minimal_tree()


# ─── Árbol mínimo para tests ──────────────────────────────────────────────────
# No carga desde disco — headless no puede acceder a res://.
# Suficiente para probar unlock, prereqs, y bonus de stats.

func _make_minimal_tree() -> SkillTree:
	var tree := SkillTree.new()

	# Efecto: +10 HP flat
	var eff_hp := SkillEffect.new()
	eff_hp.stat = SkillEffect.Stat.HEALTH_MAX
	eff_hp.mode = SkillEffect.Mode.FLAT
	eff_hp.amount = 10.0

	# Nodo raíz: sin prereqs
	var root_node := SkillNode.new()
	root_node.id = &"test_raiz"
	root_node.display_name = "Test Raíz"
	root_node.branch = SkillNode.Branch.GUERRERO
	root_node.point_cost = 1
	root_node.prerequisites = []
	root_node.tier = 1
	root_node.effects = [eff_hp]

	# Nodo con prereq
	var child_node := SkillNode.new()
	child_node.id = &"test_hijo"
	child_node.display_name = "Test Hijo"
	child_node.branch = SkillNode.Branch.GUERRERO
	child_node.point_cost = 1
	child_node.prerequisites = [&"test_raiz"]
	child_node.tier = 2
	child_node.effects = []

	tree.nodes = [root_node, child_node]
	return tree


func _reset_prog() -> void:
	_prog.reset(true)
	_inv.clear_all()


# ─── Caso 1: Fórmula XP nivel 1 ──────────────────────────────────────────────

func _test_xp_formula_level_1() -> void:
	# xp_for_level(1) = 100 × 1^1.5 = 100
	var result: int = PlayerProgression.xp_for_level(1)
	assert(result == 100, "xp_for_level(1) debe ser 100, obtuvo %d" % result)
	print("  - xp_formula_level_1 ok")


# ─── Caso 2: Fórmula XP nivel 10 ─────────────────────────────────────────────

func _test_xp_formula_level_10() -> void:
	# xp_for_level(10) = 100 × 10^1.5 = 3162
	var result: int = PlayerProgression.xp_for_level(10)
	assert(result == 3162, "xp_for_level(10) debe ser 3162, obtuvo %d" % result)
	print("  - xp_formula_level_10 ok")


# ─── Caso 3: Fórmula XP nivel 30 ─────────────────────────────────────────────

func _test_xp_formula_level_30() -> void:
	# xp_for_level(30) = 100 × 30^1.5 = 16432
	var result: int = PlayerProgression.xp_for_level(30)
	# 30^1.5 = 30 * sqrt(30) = 30 * 5.4772... = 164.317... → 100 * 164.317 = 16432 (redondeado)
	assert(result == 16432, "xp_for_level(30) debe ser 16432, obtuvo %d" % result)
	print("  - xp_formula_level_30 ok")


# ─── Caso 4: add_xp sin level-up ─────────────────────────────────────────────

func _test_add_xp_no_levelup() -> void:
	_reset_prog()
	_prog.add_xp(50)
	assert(_prog.get_level() == 1, "nivel debe seguir en 1")
	assert(_prog.get_xp() == 50, "xp debe ser 50, obtuvo %d" % _prog.get_xp())
	assert(_prog.get_skill_points_available() == 0, "sin puntos nuevos")
	print("  - add_xp_no_levelup ok")


# ─── Caso 5: add_xp con un solo level-up ─────────────────────────────────────

func _test_add_xp_single_levelup() -> void:
	_reset_prog()
	# Level 1→2 requiere 100 XP. Damos 150.
	var leveled_up: bool = false
	var points_given: int = 0
	_prog.level_up.connect(func(new_lvl: int, pts: int) -> void:
		leveled_up = true
		points_given = pts, CONNECT_ONE_SHOT)

	_prog.add_xp(150)

	assert(_prog.get_level() == 2, "nivel debe ser 2, obtuvo %d" % _prog.get_level())
	assert(_prog.get_xp() == 50, "xp restante debe ser 50, obtuvo %d" % _prog.get_xp())
	assert(_prog.get_skill_points_available() == 1, "debe tener 1 punto, obtuvo %d" % _prog.get_skill_points_available())
	assert(leveled_up, "señal level_up debe haberse emitido")
	assert(points_given == 1, "level_up debe emitir 1 punto")
	print("  - add_xp_single_levelup ok")


# ─── Caso 6: add_xp con múltiples level-ups ──────────────────────────────────

func _test_add_xp_multi_levelup() -> void:
	_reset_prog()
	# Dar mucha XP: nivel 1 (100) + nivel 2 (283) + nivel 3 (520) ≈ 903 XP para llegar a nivel 4.
	# Con 1000 XP deberíamos llegar a nivel 4.
	_prog.add_xp(1000)
	assert(_prog.get_level() >= 4,
		"con 1000 XP debe llegar al menos al nivel 4, obtuvo nivel %d" % _prog.get_level())
	# Puntos deben coincidir exactamente con (nivel - 1) — uno por cada level-up.
	assert(_prog.get_skill_points_available() == _prog.get_level() - 1,
		"puntos deben ser (nivel-1)=%d, obtuvo %d" % [_prog.get_level() - 1, _prog.get_skill_points_available()])
	print("  - add_xp_multi_levelup ok (nivel %d)" % _prog.get_level())


# ─── Caso 7: no supera el cap de nivel 30 ────────────────────────────────────

func _test_cap_at_level_30() -> void:
	_reset_prog()
	# Dar XP masiva para intentar superar el cap.
	_prog.add_xp(9_999_999)
	assert(_prog.get_level() == 30, "nivel no debe superar 30, obtuvo %d" % _prog.get_level())
	assert(_prog.get_xp() == 0, "XP extra no se acumula en cap, obtuvo %d" % _prog.get_xp())
	print("  - cap_at_level_30 ok")


# ─── Caso 8: unlock_node con id inexistente ───────────────────────────────────

func _test_unlock_invalid_id() -> void:
	_reset_prog()
	# Dar un punto para que no falle por puntos.
	_prog.add_xp(100)
	var ok: bool = _prog.unlock_node(&"nodo_que_no_existe")
	assert(ok == false, "unlock de id inexistente debe retornar false")
	print("  - unlock_invalid_id ok")


# ─── Caso 9: unlock_node sin puntos disponibles ──────────────────────────────

func _test_unlock_no_points() -> void:
	_reset_prog()
	# Sin xp → sin puntos.
	var ok: bool = _prog.unlock_node(&"test_raiz")
	assert(ok == false, "unlock sin puntos debe retornar false")
	print("  - unlock_no_points ok")


# ─── Caso 10: unlock_node con prereq no cumplido ─────────────────────────────

func _test_unlock_prereq_not_met() -> void:
	_reset_prog()
	_prog.add_xp(100)  # 1 punto
	# test_hijo requiere test_raiz, que no está desbloqueado.
	var ok: bool = _prog.unlock_node(&"test_hijo")
	assert(ok == false, "unlock con prereq no cumplido debe retornar false")
	print("  - unlock_prereq_not_met ok")


# ─── Caso 11: unlock_node happy path ─────────────────────────────────────────

func _test_unlock_happy_path() -> void:
	_reset_prog()
	_prog.add_xp(100)  # 1 punto

	var unlocked_node: SkillNode = null
	_prog.skill_unlocked.connect(func(node: SkillNode) -> void:
		unlocked_node = node, CONNECT_ONE_SHOT)

	var ok: bool = _prog.unlock_node(&"test_raiz")

	assert(ok == true, "unlock happy path debe retornar true")
	assert(_prog.get_skill_points_available() == 0, "punto debe haberse consumido")
	assert(_prog.is_unlocked(&"test_raiz"), "nodo debe estar en _unlocked_nodes")
	assert(unlocked_node != null, "señal skill_unlocked debe haberse emitido")
	assert(unlocked_node.id == &"test_raiz", "señal debe traer el nodo correcto")
	print("  - unlock_happy_path ok")


# ─── Caso 12: is_unlocked después de unlock ──────────────────────────────────

func _test_is_unlocked() -> void:
	_reset_prog()
	_prog.add_xp(100)
	assert(_prog.is_unlocked(&"test_raiz") == false, "antes de unlock debe ser false")
	_prog.unlock_node(&"test_raiz")
	assert(_prog.is_unlocked(&"test_raiz") == true, "después de unlock debe ser true")
	print("  - is_unlocked ok")


# ─── Caso 13: can_unlock ─────────────────────────────────────────────────────

func _test_can_unlock() -> void:
	_reset_prog()
	# Sin puntos.
	assert(_prog.can_unlock(&"test_raiz") == false, "sin puntos, can_unlock debe ser false")
	_prog.add_xp(100)
	assert(_prog.can_unlock(&"test_raiz") == true, "con punto, can_unlock debe ser true")
	_prog.unlock_node(&"test_raiz")
	assert(_prog.can_unlock(&"test_raiz") == false, "ya desbloqueado, can_unlock debe ser false")
	# Sin puntos ahora, hijo con prereq cumplido tampoco.
	assert(_prog.can_unlock(&"test_hijo") == false, "sin puntos, hijo no es desbloqueable")
	_prog.add_xp(283)  # nivel 2 → +1 punto
	assert(_prog.can_unlock(&"test_hijo") == true, "con punto y prereq cumplido, debe ser true")
	print("  - can_unlock ok")


# ─── Caso 14: get_skill_bonus_flat con nodo +10 HP ───────────────────────────

func _test_skill_bonus_flat() -> void:
	_reset_prog()
	_prog.add_xp(100)

	# Sin nodo desbloqueado: bonus 0.
	var bonus_antes: float = _prog.get_skill_bonus_flat(SkillEffect.Stat.HEALTH_MAX)
	assert(bonus_antes == 0.0, "sin nodos, bonus HP debe ser 0.0, obtuvo %.1f" % bonus_antes)

	_prog.unlock_node(&"test_raiz")

	# Con test_raiz (eff_hp amount=10) desbloqueado: bonus 10.
	var bonus_despues: float = _prog.get_skill_bonus_flat(SkillEffect.Stat.HEALTH_MAX)
	assert(abs(bonus_despues - 10.0) < 0.001,
		"con test_raiz, bonus HP debe ser 10.0, obtuvo %.2f" % bonus_despues)
	print("  - skill_bonus_flat ok")


# ─── Caso 15: respec sin materiales → false ───────────────────────────────────

func _test_respec_no_materials() -> void:
	_reset_prog()
	_prog.add_xp(100)
	_prog.unlock_node(&"test_raiz")
	# Sin hierba_antigua en inventario.
	var ok: bool = _prog.respec()
	assert(ok == false, "respec sin materiales debe retornar false")
	assert(_prog.is_unlocked(&"test_raiz"), "nodo no debe resetearse si respec falló")
	assert(_prog.get_skill_points_available() == 0, "puntos no deben volver si respec falló")
	print("  - respec_no_materials ok")


# ─── Caso 16: respec con materiales → puntos vuelven, nodos limpian ──────────

func _test_respec_happy_path() -> void:
	_reset_prog()
	_prog.add_xp(100)
	_prog.unlock_node(&"test_raiz")
	# Dar materiales suficientes.
	_inv.add(PlayerProgression.RESPEC_MATERIAL_ID, PlayerProgression.RESPEC_MATERIAL_COUNT)

	var refunded: int = 0
	_prog.respec_done.connect(func(pts: int) -> void:
		refunded = pts, CONNECT_ONE_SHOT)

	var ok: bool = _prog.respec()

	assert(ok == true, "respec con materiales debe retornar true")
	assert(refunded == 1, "respec debe devolver 1 punto (1 nodo × 1 costo), obtuvo %d" % refunded)
	assert(_prog.get_skill_points_available() == 1,
		"puntos disponibles deben ser 1, obtuvo %d" % _prog.get_skill_points_available())
	assert(_prog.get_unlocked_node_ids().is_empty(), "nodos desbloqueados deben quedar vacíos")
	assert(not _prog.is_unlocked(&"test_raiz"), "test_raiz debe estar desbloqueado=false tras respec")
	assert(_inv.get_material_count(PlayerProgression.RESPEC_MATERIAL_ID) == 0,
		"materiales deben haberse consumido")
	print("  - respec_happy_path ok")


# ─── Caso 17: determinismo de get_skill_bonus_flat ───────────────────────────

func _test_determinism() -> void:
	_reset_prog()
	_prog.add_xp(100)
	_prog.unlock_node(&"test_raiz")

	var result_a: float = _prog.get_skill_bonus_flat(SkillEffect.Stat.HEALTH_MAX)
	var result_b: float = _prog.get_skill_bonus_flat(SkillEffect.Stat.HEALTH_MAX)
	var result_c: float = _prog.get_skill_bonus_flat(SkillEffect.Stat.HEALTH_MAX)

	assert(result_a == result_b and result_b == result_c,
		"get_skill_bonus_flat debe ser determinista: %.2f, %.2f, %.2f" % [result_a, result_b, result_c])
	print("  - determinism ok")
