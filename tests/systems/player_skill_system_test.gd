extends SceneTree

## Tests del PlayerSkillSystem (autoload de skills activas del jugador).
## Cubre: equip/unequip, can_use, try_use (cost Furia + CD), execute por effect_type.
##
## Ejecución: godot --headless --script res://tests/systems/player_skill_system_test.gd
##
## Patrón: instanciar el sistema script-directo (no como autoload) + player mock
## con FuriaComponent / HealthComponent reales. Aislado del árbol de escena.

const PlayerSkillSystemScript: Script = preload("res://scripts/systems/player_skill_system.gd")


# ─── Mock player ─────────────────────────────────────────────────────────────
class MockPlayer:
	extends Node
	var furia: FuriaComponent
	var health: HealthComponent
	var status_effects: StatusEffectComponent
	var current_facing: int = 1

	func _init() -> void:
		furia = FuriaComponent.new()
		furia.name = "FuriaComponent"
		furia.max_furia = 100
		furia.gain_per_hit = 10
		add_child(furia)

		health = HealthComponent.new()
		health.name = "HealthComponent"
		health.max_health = 100
		add_child(health)
		health.current_health = 50  # mid-HP para validar heal

		status_effects = StatusEffectComponent.new()
		status_effects.name = "StatusEffects"
		add_child(status_effects)

	func apply_external_velocity(_push: Vector2) -> void:
		pass  # no-op para tests


func _init() -> void:
	print("== player_skill_system_test ==")
	_test_max_slots_constant()
	_test_equip_unequip()
	_test_can_use_empty_slot()
	_test_can_use_no_furia()
	_test_try_use_consumes_furia_and_starts_cooldown()
	_test_try_use_blocked_by_cooldown()
	_test_cooldown_decreases_with_process()
	_test_force_execute_skips_validation()
	_test_heal_effect()
	_test_buff_damage_effect()
	_test_aoe_damage_signal()
	_test_signal_skill_failed_reasons()
	_test_unregister_clears_state()
	print("All passed.")
	quit()


func _make_system() -> Node:
	var sys: Node = PlayerSkillSystemScript.new()
	sys.name = "PlayerSkillSystem"
	# Trigger _ready manualmente — no está en árbol.
	sys._ready()
	return sys


func _make_skill(id: StringName, effect_type: int, cost: int = 30, cd: float = 5.0, \
		params: Dictionary = {}) -> PlayerSkillData:
	var d: PlayerSkillData = PlayerSkillData.new()
	d.id = id
	d.effect_type = effect_type
	d.cost_furia = cost
	d.cooldown = cd
	d.params = params
	return d


# ─── tests ────────────────────────────────────────────────────────────────────

func _test_max_slots_constant() -> void:
	var sys: Node = _make_system()
	assert(sys.MAX_SLOTS == 3, "MAX_SLOTS debe ser 3, got %d" % sys.MAX_SLOTS)
	print("  - max_slots_constant ok")


func _test_equip_unequip() -> void:
	var sys: Node = _make_system()
	var skill: PlayerSkillData = _make_skill(&"heal", PlayerSkillData.EffectType.HEAL)
	assert(sys.get_equipped(0) == null, "equip: slot 0 inicial debe ser null")
	sys.equip(0, skill)
	assert(sys.get_equipped(0) == skill, "equip: slot 0 debe tener skill")
	sys.unequip(0)
	assert(sys.get_equipped(0) == null, "unequip: slot 0 vuelve a null")
	print("  - equip_unequip ok")


func _test_can_use_empty_slot() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	assert(not sys.can_use(0), "can_use: slot vacío debe ser false")
	p.free()
	print("  - can_use_empty_slot ok")


func _test_can_use_no_furia() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	var skill: PlayerSkillData = _make_skill(&"x", PlayerSkillData.EffectType.HEAL, 50)
	sys.equip(0, skill)
	# Furia inicial 0 → no alcanza 50.
	assert(not sys.can_use(0), "can_use: sin Furia debe ser false")
	# Con Furia exacta → can_use true.
	p.furia.current_furia = 50.0
	assert(sys.can_use(0), "can_use: con Furia ≥ costo debe ser true")
	p.free()
	print("  - can_use_no_furia ok")


func _test_try_use_consumes_furia_and_starts_cooldown() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	p.furia.current_furia = 80.0
	var skill: PlayerSkillData = _make_skill(&"x", PlayerSkillData.EffectType.HEAL, 30, 5.0, \
		{"heal_pct": 0.20})
	sys.equip(0, skill)
	var ok: bool = sys.try_use(0)
	assert(ok, "try_use: debe retornar true")
	assert(p.furia.get_current() == 50, "try_use: consume 30 Furia (80→50), got %d" % p.furia.get_current())
	assert(is_equal_approx(sys.get_cooldown(0), 5.0), \
		"try_use: cooldown inicia a 5.0, got %.3f" % sys.get_cooldown(0))
	p.free()
	print("  - try_use_consumes_furia_and_starts_cooldown ok")


func _test_try_use_blocked_by_cooldown() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	p.furia.current_furia = 100.0
	var skill: PlayerSkillData = _make_skill(&"x", PlayerSkillData.EffectType.HEAL, 10, 5.0)
	sys.equip(0, skill)
	sys.try_use(0)
	# Segundo try_use con CD activo → debe fallar.
	assert(not sys.try_use(0), "try_use: con CD activo debe fallar")
	# Furia no debe consumirse en intento fallido.
	assert(p.furia.get_current() == 90, "try_use: failed no consume Furia, got %d" % p.furia.get_current())
	p.free()
	print("  - try_use_blocked_by_cooldown ok")


func _test_cooldown_decreases_with_process() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	p.furia.current_furia = 100.0
	var skill: PlayerSkillData = _make_skill(&"x", PlayerSkillData.EffectType.HEAL, 10, 2.0)
	sys.equip(0, skill)
	sys.try_use(0)
	assert(is_equal_approx(sys.get_cooldown(0), 2.0), "cooldown inicial 2.0")
	sys._process(1.0)
	assert(is_equal_approx(sys.get_cooldown(0), 1.0), \
		"cooldown tras 1s debe ser 1.0, got %.3f" % sys.get_cooldown(0))
	sys._process(2.0)
	assert(is_equal_approx(sys.get_cooldown(0), 0.0), \
		"cooldown sobrante clampea a 0, got %.3f" % sys.get_cooldown(0))
	p.free()
	print("  - cooldown_decreases_with_process ok")


func _test_force_execute_skips_validation() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	# Sin Furia y sin slot — force_execute igual debería ejecutar.
	var skill: PlayerSkillData = _make_skill(&"heal", PlayerSkillData.EffectType.HEAL, 999, 5.0, \
		{"heal_pct": 0.50})
	# HP inicial 50/100 — heal 50% → +50 HP capped a 100.
	sys.force_execute(skill)
	assert(p.health.current_health == 100, \
		"force_execute: heal 50% lleva a 100/100, got %d" % p.health.current_health)
	p.free()
	print("  - force_execute_skips_validation ok")


func _test_heal_effect() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	p.furia.current_furia = 100.0
	p.health.current_health = 30  # baja HP para heal observable
	var skill: PlayerSkillData = _make_skill(&"heal", PlayerSkillData.EffectType.HEAL, 30, 5.0, \
		{"heal_pct": 0.25})
	sys.equip(0, skill)
	sys.try_use(0)
	# 25% de 100 = 25 → 30+25 = 55.
	assert(p.health.current_health == 55, \
		"heal: tras try_use HP debe ser 55, got %d" % p.health.current_health)
	p.free()
	print("  - heal_effect ok")


func _test_buff_damage_effect() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	p.furia.current_furia = 100.0
	var skill: PlayerSkillData = _make_skill(&"berserker", PlayerSkillData.EffectType.BUFF_DAMAGE, \
		20, 5.0, {"magnitude": 0.50, "duration": 4.0})
	sys.equip(0, skill)
	sys.try_use(0)
	assert(p.status_effects.has(&"berserker"), \
		"buff_damage: status berserker debe estar activo tras try_use")
	assert(is_equal_approx(p.status_effects.get_magnitude(&"berserker"), 0.50), \
		"buff_damage: magnitude 0.50, got %.3f" % p.status_effects.get_magnitude(&"berserker"))
	p.free()
	print("  - buff_damage_effect ok")


func _test_aoe_damage_signal() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	p.furia.current_furia = 100.0
	var skill: PlayerSkillData = _make_skill(&"aoe", PlayerSkillData.EffectType.AOE_DAMAGE, \
		25, 5.0, {"radius": 100.0, "damage": 30})
	sys.equip(0, skill)
	var used_emits: int = 0
	var cd_emits: int = 0
	sys.skill_used.connect(func(_slot: int, _data: PlayerSkillData) -> void: used_emits += 1)
	sys.cooldown_started.connect(func(_slot: int, _cd: float) -> void: cd_emits += 1)
	# Sin enemies en scene tree, AoE no afecta a nadie — pero el emit y cooldown deben pasar.
	# Nota: el query Physics2D NO se ejecuta en SceneTree headless sin physics world,
	# por eso no podemos validar el daño aplicado — solo que el ejecutor no crashea.
	sys.try_use(0)
	assert(used_emits == 1, "aoe: skill_used emit 1 vez, got %d" % used_emits)
	assert(cd_emits == 1, "aoe: cooldown_started emit 1 vez, got %d" % cd_emits)
	p.free()
	print("  - aoe_damage_signal ok")


func _test_signal_skill_failed_reasons() -> void:
	var sys: Node = _make_system()
	var failures: Array[StringName] = []
	sys.skill_failed.connect(func(_slot: int, reason: StringName) -> void: failures.append(reason))
	# Sin player registrado → no_player.
	var skill: PlayerSkillData = _make_skill(&"heal", PlayerSkillData.EffectType.HEAL, 10, 5.0)
	sys.equip(0, skill)
	sys.try_use(0)
	assert(failures.size() >= 1 and failures[0] == &"no_player", \
		"failed: sin player debe emitir no_player, got %s" % [failures])
	# Con player pero sin Furia → no_furia.
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	sys.try_use(0)
	assert(failures.has(&"no_furia"), "failed: sin Furia debe emitir no_furia, got %s" % [failures])
	# Slot vacío → empty_slot.
	sys.unequip(0)
	sys.try_use(0)
	assert(failures.has(&"empty_slot"), "failed: slot vacío emite empty_slot, got %s" % [failures])
	# Slot inválido → invalid_slot.
	sys.try_use(99)
	assert(failures.has(&"invalid_slot"), "failed: slot fuera de rango emite invalid_slot")
	p.free()
	print("  - signal_skill_failed_reasons ok")


func _test_unregister_clears_state() -> void:
	var sys: Node = _make_system()
	var p: MockPlayer = MockPlayer.new()
	sys.register_player(p)
	p.furia.current_furia = 100.0
	var skill: PlayerSkillData = _make_skill(&"x", PlayerSkillData.EffectType.HEAL, 10, 5.0)
	sys.equip(0, skill)
	sys.try_use(0)
	sys.unregister_player(p)
	assert(is_equal_approx(sys.get_cooldown(0), 0.0), \
		"unregister: cooldowns deben resetear, got %.3f" % sys.get_cooldown(0))
	assert(not sys.can_use(0), "unregister: can_use sin player debe ser false")
	p.free()
	print("  - unregister_clears_state ok")
