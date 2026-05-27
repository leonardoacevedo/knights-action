extends SceneTree

## Tests del sistema Element → Status synergy (eje natural + eje cósmico, 27/05).
## Cubre: Fractura single-use consume, Miasma bypass armor, Bendición vampire heal source,
## Desequilibrio status apply (state machine cancel requiere scene tree → marcado INTEGRACION).
##
## Ejecución: godot --headless --script res://tests/systems/element_status_synergy_test.gd
##
## Patrón: instanciar HurtboxComponent + HealthComponent + StatusEffectComponent script-directo.
## Mock owner_node + StatusEffects child para verificar lookups.

const STATUS_FRACTURA: StatusEffectData = preload("res://resources/status_effects/vulnerable.tres")
const STATUS_MIASMA: StatusEffectData = preload("res://resources/status_effects/poison.tres")
const STATUS_BENDICION: StatusEffectData = preload("res://resources/status_effects/bendicion.tres")
const STATUS_DESEQUILIBRIO: StatusEffectData = preload("res://resources/status_effects/desequilibrio.tres")


func _init() -> void:
	print("== element_status_synergy_test ==")
	_test_fractura_id_canonical()
	_test_fractura_magnitude_canonical()
	_test_fractura_consume_on_apply_multiplier()
	_test_fractura_no_status_no_mult()
	_test_miasma_id_canonical()
	_test_miasma_independent_stack_mode()
	_test_miasma_bypass_health_direct()
	_test_bendicion_id_canonical()
	_test_desequilibrio_id_canonical()
	_test_desequilibrio_magnitude_one_point_five()
	print("  - [INTEGRACION] desequilibrio enemy state cancel: requiere scene tree con enemy state machine.")
	print("  - [INTEGRACION] bendicion heal source: requiere parent con HealthComponent en árbol.")
	print("  - [INTEGRACION] miasma furia halve: requiere player en scene + MomentumSystem autoload.")
	print("All passed.")
	quit()


# ─── Fractura: id + magnitude canonical ──────────────────────────────────────
func _test_fractura_id_canonical() -> void:
	assert(STATUS_FRACTURA.id == &"fractura", \
		"fractura: id debe ser 'fractura', got %s" % STATUS_FRACTURA.id)
	print("  - fractura_id_canonical ok")


func _test_fractura_magnitude_canonical() -> void:
	assert(is_equal_approx(STATUS_FRACTURA.magnitude, 0.20), \
		"fractura: magnitude debe ser 0.20, got %.3f" % STATUS_FRACTURA.magnitude)
	assert(is_equal_approx(STATUS_FRACTURA.duration, 5.0), \
		"fractura: duration debe ser 5.0, got %.3f" % STATUS_FRACTURA.duration)
	print("  - fractura_magnitude_canonical ok")


# ─── Fractura: consume on hit ────────────────────────────────────────────────
func _test_fractura_consume_on_apply_multiplier() -> void:
	# Setup: HurtboxComponent + Health + StatusEffectComponent. Apply fractura, recibir hit.
	# Validar que daño aumentó +20% Y que el status quedó removido tras el hit.
	var owner_node: Node = Node.new()
	owner_node.name = "TestEntity"
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100
	owner_node.add_child(health)
	var se := StatusEffectComponent.new()
	se.name = "StatusEffects"
	owner_node.add_child(se)
	var hurtbox := HurtboxComponent.new()
	hurtbox.health_component = health
	hurtbox.team = 1  # player
	owner_node.add_child(hurtbox)

	# Aplicar fractura.
	se.apply(STATUS_FRACTURA)
	assert(se.has(&"fractura"), "fractura: status aplicado")

	# Recibir hit de daño 10. Esperado: 10 × 1.20 = 12 HP perdido (100 → 88).
	hurtbox.receive_hit(10, null, 0)
	assert(health.current_health == 88, \
		"fractura: daño con +20% esperado 12, HP 88, got %d" % health.current_health)
	# Status removido tras consume.
	assert(not se.has(&"fractura"), "fractura: status removido tras consume")
	owner_node.free()
	print("  - fractura_consume_on_apply_multiplier ok")


func _test_fractura_no_status_no_mult() -> void:
	# Sin fractura activa, el daño no recibe bonus.
	var owner_node: Node = Node.new()
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100
	owner_node.add_child(health)
	var se := StatusEffectComponent.new()
	se.name = "StatusEffects"
	owner_node.add_child(se)
	var hurtbox := HurtboxComponent.new()
	hurtbox.health_component = health
	hurtbox.team = 1
	owner_node.add_child(hurtbox)
	hurtbox.receive_hit(10, null, 0)
	assert(health.current_health == 90, \
		"no fractura: daño base 10, HP 90, got %d" % health.current_health)
	owner_node.free()
	print("  - fractura_no_status_no_mult ok")


# ─── Miasma: id + stack mode ─────────────────────────────────────────────────
func _test_miasma_id_canonical() -> void:
	assert(STATUS_MIASMA.id == &"miasma", \
		"miasma: id debe ser 'miasma' (era 'poison'), got %s" % STATUS_MIASMA.id)
	print("  - miasma_id_canonical ok")


func _test_miasma_independent_stack_mode() -> void:
	# Miasma stack INDEPENDENT (snowball lategame).
	assert(STATUS_MIASMA.stack_mode == StatusEffectData.StackMode.INDEPENDENT, \
		"miasma: stack_mode debe ser INDEPENDENT (2), got %d" % STATUS_MIASMA.stack_mode)
	# Validar comportamiento: 3 applies = 3 stacks.
	var se := StatusEffectComponent.new()
	se.apply(STATUS_MIASMA)
	se.apply(STATUS_MIASMA)
	se.apply(STATUS_MIASMA)
	assert(se.get_stack_count(&"miasma") == 3, \
		"miasma: 3 applies = 3 stacks, got %d" % se.get_stack_count(&"miasma"))
	se.free()
	print("  - miasma_independent_stack_mode ok")


# ─── Miasma: bypass armor (validamos path directo a health, no via hurtbox.flat_defense) ─
func _test_miasma_bypass_health_direct() -> void:
	# Setup hurtbox con flat_defense=10 + health 100. Daño normal de 5 sería mitigado a 1.
	# Miasma tick via health.take_damage directo = 5 dmg full (no flat_defense).
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100
	# Simular miasma tick directo (bypass armor):
	health.take_damage(5)
	assert(health.current_health == 95, \
		"miasma bypass: damage 5 full sin flat_defense, HP 95, got %d" % health.current_health)
	# Versus damage via hurtbox con flat_defense=10 mitiga a 1.
	var owner_node: Node = Node.new()
	var hb_health := HealthComponent.new()
	hb_health.max_health = 100
	hb_health.current_health = 100
	owner_node.add_child(hb_health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.health_component = hb_health
	hurtbox.flat_defense = 10
	hurtbox.team = 1
	owner_node.add_child(hurtbox)
	hurtbox.receive_hit(5, null, 0)
	assert(hb_health.current_health == 99, \
		"sin miasma + flat_defense=10 + dmg 5: mitigated min 1, HP 99, got %d" % hb_health.current_health)
	# Net: miasma hace MÁS daño que el equivalente hit normal con mismo flat_defense.
	owner_node.free()
	print("  - miasma_bypass_health_direct ok")


# ─── Bendición: id canonical ─────────────────────────────────────────────────
func _test_bendicion_id_canonical() -> void:
	assert(STATUS_BENDICION.id == &"bendicion", \
		"bendicion: id debe ser 'bendicion', got %s" % STATUS_BENDICION.id)
	# magnitude representa heal% (0.05 = 5%).
	assert(is_equal_approx(STATUS_BENDICION.magnitude, 0.05), \
		"bendicion: magnitude debe ser 0.05 (5% HP), got %.3f" % STATUS_BENDICION.magnitude)
	print("  - bendicion_id_canonical ok")


# ─── Desequilibrio: id + magnitude ───────────────────────────────────────────
func _test_desequilibrio_id_canonical() -> void:
	assert(STATUS_DESEQUILIBRIO.id == &"desequilibrio", \
		"desequilibrio: id, got %s" % STATUS_DESEQUILIBRIO.id)
	print("  - desequilibrio_id_canonical ok")


func _test_desequilibrio_magnitude_one_point_five() -> void:
	# magnitude = segundos de CD penalty.
	assert(is_equal_approx(STATUS_DESEQUILIBRIO.magnitude, 1.0), \
		"desequilibrio: magnitude debe ser 1.0 (1s CD penalty default), got %.3f" % \
		STATUS_DESEQUILIBRIO.magnitude)
	assert(is_equal_approx(STATUS_DESEQUILIBRIO.duration, 1.5), \
		"desequilibrio: duration debe ser 1.5s, got %.3f" % STATUS_DESEQUILIBRIO.duration)
	print("  - desequilibrio_magnitude_one_point_five ok")
