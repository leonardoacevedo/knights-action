extends SceneTree
# Tests unitarios de PlayerStatsComponent. GDD §5 / formulas.md §Equipamiento.
# Ejecución: godot --headless --script res://tests/systems/player_stats_component_test.gd
#
# Los tests instancian todos los componentes directo en memoria (sin add_child / sin escena).
# PlayerStatsComponent usa _inv override para apuntar a un InventorySystem aislado,
# evitando dependencia del autoload global (no disponible en modo headless sin escena).

func _init() -> void:
	print("== player_stats_component_test ==")
	_test_equip_weapon_sets_hitbox_damage()
	_test_equip_armor_with_hp_affix_sets_max_health()
	_test_unequip_reverts_to_base()
	_test_hp_current_clamped_when_max_decreases()
	_test_hp_current_preserved_absolute_when_max_increases()
	_test_weapon_refinement_applies_to_damage()
	_test_defense_affix_applied_to_hurtbox()
	_test_unknown_affix_does_not_crash()
	_test_armor_element_propagates_to_hurtbox()
	_test_shield_element_used_when_no_armor()
	_test_armor_element_takes_priority_over_shield()
	_test_unequip_resets_hurtbox_element_to_neutro()
	print("All passed.")
	quit()


# ─── Test 1: equipar arma → hitbox.damage = stat_main del arma ────────────────

func _test_equip_weapon_sets_hitbox_damage() -> void:
	var ctx := _make_context()
	var weapon := _make_weapon(12, 0)  # stat_main=12, refinement=0
	ctx.inv.equip(weapon)
	ctx.stats.recalculate()
	assert(ctx.hitbox.damage == 12, \
		"equip_weapon: hitbox.damage debe ser 12, got %d" % ctx.hitbox.damage)
	print("  - equip_weapon_sets_hitbox_damage ok")


# ─── Test 2: equipar armadura con afijo +HP → max_health sube ─────────────────

func _test_equip_armor_with_hp_affix_sets_max_health() -> void:
	var ctx := _make_context()
	# stat_main=5 va a defensa, NO a HP. Afijo &"hp" +10 → max_health = BASE_HEALTH + 10.
	var armor := _make_armor(5, &"hp", 10)
	ctx.inv.equip(armor)
	ctx.stats.recalculate()
	assert(ctx.health.max_health == 110, \
		"equip_armor_hp_affix: max_health debe ser 110, got %d" % ctx.health.max_health)
	print("  - equip_armor_with_hp_affix_sets_max_health ok")


# ─── Test 3: desequipar → vuelve a stats base ─────────────────────────────────

func _test_unequip_reverts_to_base() -> void:
	var ctx := _make_context()
	var weapon := _make_weapon(20, 0)
	ctx.inv.equip(weapon)
	ctx.stats.recalculate()
	assert(ctx.hitbox.damage == 20, "pre-unequip: damage debe ser 20")

	ctx.inv.unequip(ItemData.Slot.ARMA)
	ctx.stats.recalculate()
	assert(ctx.hitbox.damage == GameConfig.PLAYER_BASE_DAMAGE, \
		"unequip_weapon: damage debe volver a PLAYER_BASE_DAMAGE=%d, got %d" \
		% [GameConfig.PLAYER_BASE_DAMAGE, ctx.hitbox.damage])
	assert(ctx.health.max_health == GameConfig.PLAYER_BASE_HEALTH, \
		"unequip: max_health debe ser PLAYER_BASE_HEALTH=%d, got %d" \
		% [GameConfig.PLAYER_BASE_HEALTH, ctx.health.max_health])
	print("  - unequip_reverts_to_base ok")


# ─── Test 4: HP actual se clampea si max_health baja por desequipar ───────────

func _test_hp_current_clamped_when_max_decreases() -> void:
	# Armadura +50 HP → max=150. Player tenía 130 HP.
	# Desequipar → max vuelve a 100. HP actual debe clampear a 100.
	var ctx := _make_context()
	var armor := _make_armor(0, &"hp", 50)
	ctx.inv.equip(armor)
	ctx.stats.recalculate()
	assert(ctx.health.max_health == 150, "setup clamp: max_health debe ser 150")
	ctx.health.current_health = 130  # Simular daño recibido.

	ctx.inv.unequip(ItemData.Slot.ARMADURA)
	ctx.stats.recalculate()
	assert(ctx.health.max_health == 100, \
		"hp_clamp: max_health debe ser 100, got %d" % ctx.health.max_health)
	assert(ctx.health.current_health == 100, \
		"hp_clamp: current_health debe ser 100 (clamped), got %d" % ctx.health.current_health)
	print("  - hp_current_clamped_when_max_decreases ok")


# ─── Test 5: HP actual se preserva absoluto cuando max sube ───────────────────

func _test_hp_current_preserved_absolute_when_max_increases() -> void:
	# Player tiene 80/100 HP. Equipa armadura +20 HP → max=120.
	# HP actual debe quedar 80/120 (absoluto, no 96/120 por ratio).
	var ctx := _make_context()
	ctx.health.current_health = 80

	var armor := _make_armor(0, &"hp", 20)
	ctx.inv.equip(armor)
	ctx.stats.recalculate()

	assert(ctx.health.max_health == 120, \
		"hp_absolute: max_health debe ser 120, got %d" % ctx.health.max_health)
	assert(ctx.health.current_health == 80, \
		"hp_absolute: current_health debe conservarse en 80, got %d" % ctx.health.current_health)
	print("  - hp_current_preserved_absolute_when_max_increases ok")


# ─── Test 6: refinamiento del arma aplica fórmula GDD §5.6 ───────────────────

func _test_weapon_refinement_applies_to_damage() -> void:
	# stat_main=10, refinement=4 → refined_stat = 10 * (1 + 0.05*4) = 12.0 → 12.
	var ctx := _make_context()
	var weapon := _make_weapon(10, 4)
	ctx.inv.equip(weapon)
	ctx.stats.recalculate()
	assert(ctx.hitbox.damage == 12, \
		"refinement: hitbox.damage debe ser 12 (10*1.2), got %d" % ctx.hitbox.damage)
	print("  - weapon_refinement_applies_to_damage ok")


# ─── Test 7: afijo defense en escudo se aplica al hurtbox ────────────────────

func _test_defense_affix_applied_to_hurtbox() -> void:
	# Escudo stat_main=6, afijo defense +4 → flat_defense = 6 + 4 = 10.
	var ctx := _make_context()
	var shield := _make_shield(6, &"defense", 4)
	ctx.inv.equip(shield)
	ctx.stats.recalculate()
	assert(ctx.hurtbox.flat_defense == 10, \
		"defense_affix: flat_defense debe ser 10 (6+4), got %d" % ctx.hurtbox.flat_defense)
	print("  - defense_affix_applied_to_hurtbox ok")


# ─── Test 8: afijo desconocido no crashea ────────────────────────────────────

func _test_unknown_affix_does_not_crash() -> void:
	var ctx := _make_context()
	# fire_res no es conocido por PlayerStatsComponent → warning, no crash.
	var armor := _make_armor(5, &"fire_res", 15)
	ctx.inv.equip(armor)
	ctx.stats.recalculate()
	# Solo la armadura stat_main=5 agrega a defensa. HP base se mantiene.
	assert(ctx.health.max_health == GameConfig.PLAYER_BASE_HEALTH, \
		"unknown_affix: max_health debe ser PLAYER_BASE_HEALTH=%d (afijo ignorado), got %d" \
		% [GameConfig.PLAYER_BASE_HEALTH, ctx.health.max_health])
	assert(ctx.hurtbox.flat_defense == 5, \
		"unknown_affix: flat_defense debe ser 5 (solo stat_main armadura), got %d" \
		% ctx.hurtbox.flat_defense)
	print("  - unknown_affix_does_not_crash ok")


# ─── Test 9: element de armadura se propaga al hurtbox (defensa elemental) ───

func _test_armor_element_propagates_to_hurtbox() -> void:
	# Armadura FUEGO → hurtbox.element = FUEGO. Enemy con elemento AGUA
	# leerá esto para aplicar ×1.5 al daño contra player. GDD §5.3.
	var ctx := _make_context()
	var armor := _make_armor_with_element(5, ItemData.Element.FUEGO)
	ctx.inv.equip(armor)
	ctx.stats.recalculate()
	assert(ctx.hurtbox.element == ItemData.Element.FUEGO, \
		"armor_element: hurtbox.element debe ser FUEGO=%d, got %d" \
		% [ItemData.Element.FUEGO, ctx.hurtbox.element])
	print("  - armor_element_propagates_to_hurtbox ok")


# ─── Test 10: shield define element si no hay armor ──────────────────────────

func _test_shield_element_used_when_no_armor() -> void:
	# Solo escudo equipado, sin armor. hurtbox.element debe ser el del escudo.
	var ctx := _make_context()
	var shield := _make_shield_with_element(6, ItemData.Element.AGUA)
	ctx.inv.equip(shield)
	ctx.stats.recalculate()
	assert(ctx.hurtbox.element == ItemData.Element.AGUA, \
		"shield_element_no_armor: hurtbox.element debe ser AGUA=%d, got %d" \
		% [ItemData.Element.AGUA, ctx.hurtbox.element])
	print("  - shield_element_used_when_no_armor ok")


# ─── Test 11: armor manda si difiere del shield ──────────────────────────────

func _test_armor_element_takes_priority_over_shield() -> void:
	# Armor FUEGO + Shield TIERRA → hurtbox.element = FUEGO.
	# Cobertura mayor del cuerpo decide prioridad.
	var ctx := _make_context()
	var armor := _make_armor_with_element(5, ItemData.Element.FUEGO)
	var shield := _make_shield_with_element(6, ItemData.Element.TIERRA)
	ctx.inv.equip(armor)
	ctx.inv.equip(shield)
	ctx.stats.recalculate()
	assert(ctx.hurtbox.element == ItemData.Element.FUEGO, \
		"armor_priority: hurtbox.element debe ser FUEGO=%d (armor manda), got %d" \
		% [ItemData.Element.FUEGO, ctx.hurtbox.element])
	print("  - armor_element_takes_priority_over_shield ok")


# ─── Test 12: desequipar todo → hurtbox.element vuelve a NEUTRO ──────────────

func _test_unequip_resets_hurtbox_element_to_neutro() -> void:
	var ctx := _make_context()
	var armor := _make_armor_with_element(5, ItemData.Element.TIERRA)
	ctx.inv.equip(armor)
	ctx.stats.recalculate()
	assert(ctx.hurtbox.element == ItemData.Element.TIERRA, "setup: armor TIERRA equipada")

	ctx.inv.unequip(ItemData.Slot.ARMADURA)
	ctx.stats.recalculate()
	assert(ctx.hurtbox.element == ItemData.Element.NEUTRO, \
		"unequip_element: hurtbox.element debe volver a NEUTRO=0, got %d" % ctx.hurtbox.element)
	print("  - unequip_resets_hurtbox_element_to_neutro ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Contexto aislado por test: componentes + inventario independiente del autoload.
class TestContext:
	var inv: Node
	var health: HealthComponent
	var hitbox: HitboxComponent
	var hurtbox: HurtboxComponent
	var stats: PlayerStatsComponent


func _make_context() -> TestContext:
	var ctx := TestContext.new()

	# InventorySystem aislado — instancia directa, sin autoload.
	ctx.inv = load("res://scripts/systems/inventory_system.gd").new()

	ctx.health = HealthComponent.new()
	ctx.health.max_health = 100
	ctx.health.current_health = 100

	ctx.hitbox = HitboxComponent.new()
	ctx.hitbox.damage = GameConfig.PLAYER_BASE_DAMAGE

	ctx.hurtbox = HurtboxComponent.new()
	ctx.hurtbox.flat_defense = 0

	ctx.stats = PlayerStatsComponent.new()
	ctx.stats.health = ctx.health
	ctx.stats.hitbox = ctx.hitbox
	ctx.stats.hurtbox = ctx.hurtbox
	# Inyectar inventario aislado en lugar del autoload global.
	ctx.stats._inv = ctx.inv

	return ctx


func _make_weapon(stat_main: int, refinement: int) -> ItemData:
	var item := ItemData.new()
	item.id = &"test_weapon"
	item.display_name = "Arma de Test"
	item.slot = ItemData.Slot.ARMA
	item.stat_main = stat_main
	item.refinement_level = refinement
	item.affixes = []
	return item


func _make_armor(stat_main: int, affix_stat_id: StringName, affix_value: int) -> ItemData:
	var item := ItemData.new()
	item.id = &"test_armor"
	item.display_name = "Armadura de Test"
	item.slot = ItemData.Slot.ARMADURA
	item.stat_main = stat_main
	item.refinement_level = 0
	var affix := AffixData.new()
	affix.stat_id = affix_stat_id
	affix.display_name = str(affix_stat_id)
	affix.value = affix_value
	item.affixes = [affix]
	return item


func _make_shield(stat_main: int, affix_stat_id: StringName, affix_value: int) -> ItemData:
	var item := ItemData.new()
	item.id = &"test_shield"
	item.display_name = "Escudo de Test"
	item.slot = ItemData.Slot.ESCUDO
	item.stat_main = stat_main
	item.refinement_level = 0
	var affix := AffixData.new()
	affix.stat_id = affix_stat_id
	affix.display_name = str(affix_stat_id)
	affix.value = affix_value
	item.affixes = [affix]
	return item


func _make_armor_with_element(stat_main: int, element: ItemData.Element) -> ItemData:
	var item := ItemData.new()
	item.id = &"test_armor_elem"
	item.display_name = "Armadura Elemental de Test"
	item.slot = ItemData.Slot.ARMADURA
	item.stat_main = stat_main
	item.refinement_level = 0
	item.element = element
	item.affixes = []
	return item


func _make_shield_with_element(stat_main: int, element: ItemData.Element) -> ItemData:
	var item := ItemData.new()
	item.id = &"test_shield_elem"
	item.display_name = "Escudo Elemental de Test"
	item.slot = ItemData.Slot.ESCUDO
	item.stat_main = stat_main
	item.refinement_level = 0
	item.element = element
	item.affixes = []
	return item
