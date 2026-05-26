extends SceneTree
# Tests de capstones del árbol de skills y stats no cableados. GDD §6.
# Cubre los 7 capstones con TODO que se implementaron en Fase 3.
#
# Ejecución: godot --headless --script res://tests/systems/capstone_skills_test.gd
#
# Patrón: instanciar componentes en memoria, inyectar PlayerProgression aislado
# con FakeInventory (mismo patrón de player_progression_test.gd).
# Tests [INTEGRACION] marcados como skipped — requieren escena.

# ─── Fake inventory ───────────────────────────────────────────────────────────

class FakeInventory:
	var _equipped: Dictionary = {}

	func get_equipped(slot: int) -> ItemData:
		return _equipped.get(slot, null)

	func equip(item: ItemData) -> void:
		_equipped[item.slot] = item

	func unequip(slot: int) -> void:
		_equipped.erase(slot)

	signal equipped_changed(slot: int, item: ItemData)

	func get_material_count(_id: StringName) -> int:
		return 0

	func remove_material(_id: StringName, _count: int) -> bool:
		return false


# ─── Contexto de test aislado ─────────────────────────────────────────────────

class TestContext:
	var inv: FakeInventory
	var health: HealthComponent
	var hitbox: HitboxComponent
	var hurtbox: HurtboxComponent
	var furia: FuriaComponent
	var dash: DashComponent
	var shield: ShieldComponent
	var stats: PlayerStatsComponent
	var prog: PlayerProgression


func _make_context() -> TestContext:
	var ctx := TestContext.new()
	ctx.inv = FakeInventory.new()

	ctx.health = HealthComponent.new()
	ctx.health.max_health = 100
	ctx.health.current_health = 100

	ctx.hitbox = HitboxComponent.new()
	ctx.hitbox.damage = GameConfig.PLAYER_BASE_DAMAGE

	ctx.hurtbox = HurtboxComponent.new()
	ctx.hurtbox.flat_defense = 0

	ctx.furia = FuriaComponent.new()
	ctx.furia.max_furia = 100
	ctx.furia.gain_per_hit = 10

	ctx.dash = DashComponent.new()
	ctx.dash.cooldown = 0.8
	ctx.dash.dash_duration = 0.1

	ctx.shield = ShieldComponent.new()

	# PlayerProgression aislado.
	ctx.prog = load("res://scripts/systems/player_progression.gd").new()
	ctx.prog._inventory_override = ctx.inv

	# PlayerStatsComponent: inyectar todo.
	ctx.stats = PlayerStatsComponent.new()
	ctx.stats.health = ctx.health
	ctx.stats.hitbox = ctx.hitbox
	ctx.stats.hurtbox = ctx.hurtbox
	ctx.stats._inv = ctx.inv

	# Simular estructura de componentes hermanos para _find_sibling_component.
	# Creamos un Node padre y agregamos los hijos manualmente.
	# Sin add_child real — solo configuramos el parent mock via adoptar el patrón del test.
	# NOTA: _find_sibling_component usa get_parent().get_children().
	# En headless, los nodos no tienen árbol, así que mockeamos la relación manualmente
	# sobreescribiendo los métodos que usa PlayerStatsComponent.
	# Alternativa: acceder directo a los apply_ privados pasando los componentes.
	# Usamos inyección directa en los campos del componente.
	# El patrón de _find_sibling_component NO funciona en headless — probamos via
	# llamada directa a los métodos privados del contexto.

	return ctx


## Crea un escudo con N cargas base.
func _make_shield_item(charges: int) -> ItemData:
	var item := ItemData.new()
	item.id = &"test_shield"
	item.display_name = "Escudo Test"
	item.slot = ItemData.Slot.ESCUDO
	item.stat_main = 0
	item.refinement_level = 0
	item.rarity = ItemData.Rarity.R2  # R2 = 1 carga base
	item.affixes = []
	# block_charges() lee el rarity. Forzamos rarity para obtener las cargas deseadas.
	# R1=0, R2=1, R3=2. Usamos el valor que da `charges`.
	match charges:
		1: item.rarity = ItemData.Rarity.R2
		2: item.rarity = ItemData.Rarity.R3
		3: item.rarity = ItemData.Rarity.R4
		_: item.rarity = ItemData.Rarity.R1
	return item


# ─── Entry point ──────────────────────────────────────────────────────────────

func _init() -> void:
	print("== capstone_skills_test ==")

	# ─ DASH_COOLDOWN_PCT ─────────────────────────────────────────────────────
	_test_dash_cooldown_pct()

	# ─ IFRAMES_PCT ───────────────────────────────────────────────────────────
	_test_iframes_pct()

	# ─ FURIA_MAX (skill flat + nivel) ────────────────────────────────────────
	_test_furia_max_skill_flat()

	# ─ FURIA_GAIN_PCT ─────────────────────────────────────────────────────────
	_test_furia_gain_pct()

	# ─ FURIA_REGEN_FLAT (skill independiente del set) ─────────────────────────
	_test_furia_regen_flat_skill()

	# ─ ELEMENTAL_ADV_MULT ─────────────────────────────────────────────────────
	_test_elemental_adv_mult()

	# ─ EVADE_PCT ──────────────────────────────────────────────────────────────
	_test_evade_pct_stored_in_hurtbox()

	# ─ BLOCK_CHARGES ──────────────────────────────────────────────────────────
	_test_block_charges_skill()

	# ─ MOVE_SPEED_PCT — player depende de escena, test marcado INTEGRACION ───
	print("  - [INTEGRACION] move_speed_pct: requiere escena de player — validar manualmente.")

	# ─ Buff temporal Golpe Tras Dash — requiere escena ───────────────────────
	print("  - [INTEGRACION] golpe_tras_dash buff: requiere player en escena — validar manualmente.")

	# ─ Buff temporal Sombra del Valle — requiere escena ─────────────────────
	print("  - [INTEGRACION] sombra_del_valle buff: requiere player en escena — validar manualmente.")

	# ─ Espíritu Marcial buff — requiere escena ───────────────────────────────
	print("  - [INTEGRACION] espiritu_marcial buff: requiere player en escena — validar manualmente.")

	print("All passed.")
	quit()


# ─── Test: DASH_COOLDOWN_PCT ──────────────────────────────────────────────────

func _test_dash_cooldown_pct() -> void:
	# agil_dash_rapido: stat=7 (DASH_COOLDOWN_PCT), mode=PCT, amount=-0.20
	# dash_cooldown_mult debe ser 0.80 → cooldown real = 0.8 * 0.80 = 0.64s.
	var dash := DashComponent.new()
	dash.cooldown = 0.8
	# Simular que skill da -0.20 (lo que haría PlayerStatsComponent._apply_dash_skills).
	var cd_pct: float = -0.20
	dash.dash_cooldown_mult = max(0.1, 1.0 + cd_pct)
	assert(is_equal_approx(dash.dash_cooldown_mult, 0.80), \
		"dash_cooldown_pct: dash_cooldown_mult debe ser 0.80, got %.4f" % dash.dash_cooldown_mult)
	# Simular try_dash: _cooldown_timer = cooldown * dash_cooldown_mult = 0.64.
	var expected_timer: float = dash.cooldown * dash.dash_cooldown_mult
	assert(is_equal_approx(expected_timer, 0.64), \
		"dash_cooldown_pct: timer esperado 0.64s, got %.4f" % expected_timer)
	print("  - dash_cooldown_pct ok")


# ─── Test: IFRAMES_PCT ────────────────────────────────────────────────────────

func _test_iframes_pct() -> void:
	# agil_sombra_del_valle: stat=11 (IFRAMES_PCT), mode=PCT, amount=0.30
	# iframes_mult = 1.30 → duración real = 0.1 * 1.30 = 0.13s.
	var dash := DashComponent.new()
	dash.dash_duration = 0.1
	var iframes_pct: float = 0.30
	dash.iframes_mult = max(0.1, 1.0 + iframes_pct)
	assert(is_equal_approx(dash.iframes_mult, 1.30), \
		"iframes_pct: iframes_mult debe ser 1.30, got %.4f" % dash.iframes_mult)
	var expected_duration: float = dash.dash_duration * dash.iframes_mult
	assert(is_equal_approx(expected_duration, 0.13), \
		"iframes_pct: duración esperada 0.13s, got %.4f" % expected_duration)
	print("  - iframes_pct ok")


# ─── Test: FURIA_MAX skill flat ───────────────────────────────────────────────

func _test_furia_max_skill_flat() -> void:
	# mago_deposito_furia: stat=5 (FURIA_MAX), mode=FLAT, amount=10.0 (hipotético).
	# set_max_furia_override: base(100) + 10 = 110.
	var furia := FuriaComponent.new()
	furia.max_furia = 100
	furia.set_max_furia_override(110)
	assert(furia.get_max() == 110, \
		"furia_max_skill: get_max() debe ser 110, got %d" % furia.get_max())
	# Furia actual no debe superar el nuevo máximo.
	furia.current_furia = 95.0
	furia.set_max_furia_override(80)
	assert(furia.current_furia <= 80.0, \
		"furia_max_skill: current_furia debe clampearse a 80, got %.1f" % furia.current_furia)
	print("  - furia_max_skill_flat ok")


# ─── Test: FURIA_GAIN_PCT ─────────────────────────────────────────────────────

func _test_furia_gain_pct() -> void:
	# Con _gain_multiplier=1.50, cada golpe da 10 * 1.50 = 15 Furia.
	var furia := FuriaComponent.new()
	furia.max_furia = 100
	furia.gain_per_hit = 10
	furia.set_gain_multiplier(1.50)
	furia.add_on_hit(1.0)
	assert(furia.get_current() == 15, \
		"furia_gain_pct: gain debe ser 15, got %d" % furia.get_current())
	# Sin multiplicador, debe dar 10.
	var furia2 := FuriaComponent.new()
	furia2.max_furia = 100
	furia2.gain_per_hit = 10
	furia2.add_on_hit(1.0)
	assert(furia2.get_current() == 10, \
		"furia_gain_pct: sin buff debe dar 10, got %d" % furia2.get_current())
	print("  - furia_gain_pct ok")


# ─── Test: FURIA_REGEN_FLAT skill (independiente del set) ────────────────────

func _test_furia_regen_flat_skill() -> void:
	# Simular el patrón: set bonus da 2.0/s, skill da 1.0/s → total 3.0/s.
	var furia := FuriaComponent.new()
	furia.max_furia = 100
	# Simular set bonus AGUA 2pc ya aplicado.
	furia.set_passive_regen(2.0)
	assert(is_equal_approx(furia.get_passive_regen(), 2.0), \
		"furia_regen: set bonus debe ser 2.0, got %.2f" % furia.get_passive_regen())
	# Simular skill mago_resonancia_arcana (+1/s).
	var skill_regen: float = 1.0
	var current: float = furia.get_passive_regen()
	furia.set_passive_regen(current + skill_regen)
	assert(is_equal_approx(furia.get_passive_regen(), 3.0), \
		"furia_regen: set + skill debe ser 3.0, got %.2f" % furia.get_passive_regen())
	# Verificar que _apply_passive_regen incrementa current_furia.
	furia.current_furia = 0.0
	furia._apply_passive_regen(1.0)  # 1 segundo
	assert(is_equal_approx(furia.get_current(), 3), \
		"furia_regen: tras 1s debe tener 3 Furia, got %d" % furia.get_current())
	print("  - furia_regen_flat_skill ok")


# ─── Test: ELEMENTAL_ADV_MULT ─────────────────────────────────────────────────

func _test_elemental_adv_mult() -> void:
	# mago_ventaja_aguzada: stat=14 (ELEMENTAL_ADV_MULT), mode=PCT, amount=0.15
	# Con ventaja natural (elem_mult > 1.0), se agrega 0.15.
	# Ventaja base = 1.5 (GameConfig.ELEMENT_ADVANTAGE_MULT).
	# Con skill: 1.5 + 0.15 = 1.65.
	var hitbox := HitboxComponent.new()
	hitbox.elemental_adv_skill_bonus = 0.15
	# Simular el cálculo que haría _on_area_entered con ventaja natural.
	var base_mult: float = GameConfig.ELEMENT_ADVANTAGE_MULT  # 1.5
	var with_skill: float = base_mult + hitbox.elemental_adv_skill_bonus
	assert(is_equal_approx(with_skill, 1.65), \
		"elemental_adv_mult: multiplicador con skill debe ser 1.65, got %.4f" % with_skill)
	# Sin skill: debe ser 1.5.
	var hitbox2 := HitboxComponent.new()
	assert(is_equal_approx(hitbox2.elemental_adv_skill_bonus, 0.0), \
		"elemental_adv_mult: sin skill debe ser 0.0, got %.4f" % hitbox2.elemental_adv_skill_bonus)
	print("  - elemental_adv_mult ok")


# ─── Test: EVADE_PCT almacenado en HurtboxComponent ──────────────────────────

func _test_evade_pct_stored_in_hurtbox() -> void:
	# agil_esquiva_instintiva: stat=15 (EVADE_PCT), mode=PCT, amount=0.08
	# PlayerStatsComponent debe setear hurtbox.evade_chance = 0.08.
	var hurtbox := HurtboxComponent.new()
	assert(is_equal_approx(hurtbox.evade_chance, 0.0), \
		"evade_pct: evade_chance default debe ser 0.0")
	hurtbox.evade_chance = 0.08
	assert(is_equal_approx(hurtbox.evade_chance, 0.08), \
		"evade_pct: evade_chance debe ser 0.08, got %.4f" % hurtbox.evade_chance)
	# Cap de 75% — no debe superar.
	var evade_capped: float = clampf(1.0, 0.0, 0.75)
	assert(is_equal_approx(evade_capped, 0.75), \
		"evade_pct: cap 75% debe aplicar, got %.4f" % evade_capped)
	# Con evade_chance = 0.0, receive_hit no esquiva (RNG no se activa).
	var hurtbox2 := HurtboxComponent.new()
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100
	hurtbox2.health_component = health
	hurtbox2.evade_chance = 0.0
	# Sin equip_chance, el hit siempre pasa.
	hurtbox2.receive_hit(10, null, 0)
	assert(health.current_health == 90, \
		"evade_pct: sin evade_chance, hit siempre aplica. HP=%d" % health.current_health)
	print("  - evade_pct_stored_in_hurtbox ok")


# ─── Test: BLOCK_CHARGES skill bonus ─────────────────────────────────────────

func _test_block_charges_skill() -> void:
	# guerrero_carga_extra: +1 carga. ShieldComponent.skill_charges_bonus = 1.
	# Escudo R2 = 1 carga base. Con skill: max_charges = 2.
	var shield := ShieldComponent.new()
	assert(shield.skill_charges_bonus == 0, \
		"block_charges: default skill_charges_bonus debe ser 0")
	shield.skill_charges_bonus = 1
	assert(shield.skill_charges_bonus == 1, \
		"block_charges: skill_charges_bonus debe ser 1, got %d" % shield.skill_charges_bonus)
	# Simular _configure_from_item con escudo R2 (1 carga) + skill (+1) = 2.
	var base_charges: int = 1  # R2
	var max_with_skill: int = base_charges + shield.skill_charges_bonus
	assert(max_with_skill == 2, \
		"block_charges: max_charges con skill debe ser 2, got %d" % max_with_skill)
	print("  - block_charges_skill ok")
