extends SceneTree

## Tests puros del StatusEffectComponent — sin escena, sin _process.
## Ejecución: godot --headless --script res://tests/systems/status_effect_component_test.gd
##
## Cubre: apply / has / get_magnitude / remove / stack modes / magnitude policies / tick.


func _init() -> void:
	print("== status_effect_component_test ==")
	_test_apply_and_has()
	_test_expire_after_duration()
	_test_refresh_stack_mode()
	_test_extend_stack_mode()
	_test_independent_stack_mode()
	_test_ignore_stack_mode()
	_test_magnitude_policy_keep_max()
	_test_magnitude_policy_keep_min()
	_test_magnitude_policy_keep_latest()
	_test_magnitude_policy_sum()
	_test_tick_dot()
	_test_magnitude_override()
	_test_duration_override()
	_test_remove_by_id()
	_test_clear_emits_expired()
	_test_get_remaining()
	_test_get_active_ids()
	_test_zero_duration_ignored()
	print("All passed.")
	quit()


func _make_effect(id: StringName, dur: float = 1.0, mag: float = 0.0, \
		tick: float = 0.0, stack: int = 0, policy: int = 0) -> StatusEffectData:
	var d := StatusEffectData.new()
	d.id = id
	d.duration = dur
	d.magnitude = mag
	d.tick_interval = tick
	d.stack_mode = stack
	d.magnitude_policy = policy
	return d


func _make_component() -> StatusEffectComponent:
	return StatusEffectComponent.new()


# ─── apply + has ──────────────────────────────────────────────────────────────
func _test_apply_and_has() -> void:
	var comp := _make_component()
	var d := _make_effect(&"slow", 2.0, 0.5)
	assert(not comp.has(&"slow"), "apply: default no activo")
	comp.apply(d)
	assert(comp.has(&"slow"), "apply: tras apply debe estar activo")
	assert(is_equal_approx(comp.get_magnitude(&"slow"), 0.5), \
		"apply: magnitude debe ser 0.5 got %.3f" % comp.get_magnitude(&"slow"))
	print("  - apply_and_has ok")


# ─── tick → expiración ────────────────────────────────────────────────────────
func _test_expire_after_duration() -> void:
	var comp := _make_component()
	var d := _make_effect(&"slow", 1.0, 0.5)
	var expired_ids: Array[StringName] = []
	comp.effect_expired.connect(func(id: StringName, _src: Node) -> void:
		expired_ids.append(id))
	comp.apply(d)
	comp.tick(0.5)
	assert(comp.has(&"slow"), "expire: a 0.5s debe seguir activo")
	comp.tick(0.6)
	assert(not comp.has(&"slow"), "expire: a 1.1s debe expirar")
	assert(expired_ids.size() == 1 and expired_ids[0] == &"slow", \
		"expire: signal expired debe emitir 1 vez con id slow")
	print("  - expire_after_duration ok")


# ─── REFRESH stack mode ───────────────────────────────────────────────────────
func _test_refresh_stack_mode() -> void:
	var comp := _make_component()
	var d := _make_effect(&"buff", 2.0, 0.20, 0.0, \
		StatusEffectData.StackMode.REFRESH, StatusEffectData.MagnitudePolicy.KEEP_MAX)
	comp.apply(d)
	comp.tick(1.5)
	assert(is_equal_approx(comp.get_remaining(&"buff"), 0.5), \
		"refresh: a 1.5s remaining debe ser 0.5, got %.3f" % comp.get_remaining(&"buff"))
	comp.apply(d)
	assert(is_equal_approx(comp.get_remaining(&"buff"), 2.0), \
		"refresh: reapply debe resetear a 2.0, got %.3f" % comp.get_remaining(&"buff"))
	assert(comp.get_stack_count(&"buff") == 1, "refresh: solo 1 instancia, no stack")
	print("  - refresh_stack_mode ok")


# ─── EXTEND stack mode ────────────────────────────────────────────────────────
func _test_extend_stack_mode() -> void:
	var comp := _make_component()
	var d := _make_effect(&"buff", 2.0, 0.20, 0.0, \
		StatusEffectData.StackMode.EXTEND, StatusEffectData.MagnitudePolicy.KEEP_MAX)
	comp.apply(d)
	comp.tick(1.0)
	assert(is_equal_approx(comp.get_remaining(&"buff"), 1.0), \
		"extend: a 1s remaining debe ser 1.0")
	comp.apply(d)
	assert(is_equal_approx(comp.get_remaining(&"buff"), 3.0), \
		"extend: reapply debe sumar duration → 3.0, got %.3f" % comp.get_remaining(&"buff"))
	print("  - extend_stack_mode ok")


# ─── INDEPENDENT stack mode ───────────────────────────────────────────────────
func _test_independent_stack_mode() -> void:
	var comp := _make_component()
	var d := _make_effect(&"dot", 3.0, 5.0, 0.5, \
		StatusEffectData.StackMode.INDEPENDENT)
	comp.apply(d)
	comp.apply(d)
	comp.apply(d)
	assert(comp.get_stack_count(&"dot") == 3, \
		"independent: debe tener 3 stacks, got %d" % comp.get_stack_count(&"dot"))
	assert(is_equal_approx(comp.get_total_magnitude(&"dot"), 15.0), \
		"independent: total_magnitude debe ser 15, got %.1f" % comp.get_total_magnitude(&"dot"))
	print("  - independent_stack_mode ok")


# ─── IGNORE stack mode ────────────────────────────────────────────────────────
func _test_ignore_stack_mode() -> void:
	var comp := _make_component()
	var d := _make_effect(&"once", 5.0, 0.5, 0.0, \
		StatusEffectData.StackMode.IGNORE)
	comp.apply(d)
	comp.tick(2.0)
	assert(is_equal_approx(comp.get_remaining(&"once"), 3.0), \
		"ignore: a 2s remaining debe ser 3, got %.3f" % comp.get_remaining(&"once"))
	comp.apply(d)
	assert(is_equal_approx(comp.get_remaining(&"once"), 3.0), \
		"ignore: reapply NO debe resetear duration, got %.3f" % comp.get_remaining(&"once"))
	print("  - ignore_stack_mode ok")


# ─── KEEP_MAX magnitude ───────────────────────────────────────────────────────
func _test_magnitude_policy_keep_max() -> void:
	var comp := _make_component()
	var d := _make_effect(&"buff", 2.0, 0.20, 0.0, \
		StatusEffectData.StackMode.REFRESH, StatusEffectData.MagnitudePolicy.KEEP_MAX)
	comp.apply(d)
	comp.apply(d, null, 0.10)  # menor — debe ignorar
	assert(is_equal_approx(comp.get_magnitude(&"buff"), 0.20), \
		"keep_max: debe conservar 0.20")
	comp.apply(d, null, 0.50)  # mayor — debe sobreescribir
	assert(is_equal_approx(comp.get_magnitude(&"buff"), 0.50), \
		"keep_max: debe actualizar a 0.50")
	print("  - magnitude_policy_keep_max ok")


# ─── KEEP_MIN magnitude (slow más restrictivo) ────────────────────────────────
func _test_magnitude_policy_keep_min() -> void:
	var comp := _make_component()
	var d := _make_effect(&"slow", 2.0, 0.5, 0.0, \
		StatusEffectData.StackMode.REFRESH, StatusEffectData.MagnitudePolicy.KEEP_MIN)
	comp.apply(d)
	comp.apply(d, null, 0.7)  # mayor (menos restrictivo) — debe ignorar
	assert(is_equal_approx(comp.get_magnitude(&"slow"), 0.5), \
		"keep_min: debe conservar 0.5")
	comp.apply(d, null, 0.3)  # menor (más restrictivo) — debe sobreescribir
	assert(is_equal_approx(comp.get_magnitude(&"slow"), 0.3), \
		"keep_min: debe actualizar a 0.3")
	print("  - magnitude_policy_keep_min ok")


# ─── KEEP_LATEST magnitude ────────────────────────────────────────────────────
func _test_magnitude_policy_keep_latest() -> void:
	var comp := _make_component()
	var d := _make_effect(&"x", 2.0, 0.20, 0.0, \
		StatusEffectData.StackMode.REFRESH, StatusEffectData.MagnitudePolicy.KEEP_LATEST)
	comp.apply(d)
	comp.apply(d, null, 0.50)
	assert(is_equal_approx(comp.get_magnitude(&"x"), 0.50), "keep_latest: debe sobrescribir")
	comp.apply(d, null, 0.10)
	assert(is_equal_approx(comp.get_magnitude(&"x"), 0.10), "keep_latest: debe sobrescribir aún menor")
	print("  - magnitude_policy_keep_latest ok")


# ─── SUM magnitude ────────────────────────────────────────────────────────────
func _test_magnitude_policy_sum() -> void:
	var comp := _make_component()
	var d := _make_effect(&"x", 2.0, 1.0, 0.0, \
		StatusEffectData.StackMode.REFRESH, StatusEffectData.MagnitudePolicy.SUM)
	comp.apply(d)
	comp.apply(d, null, 2.0)
	comp.apply(d, null, 3.0)
	assert(is_equal_approx(comp.get_magnitude(&"x"), 6.0), \
		"sum: debe ser 6, got %.1f" % comp.get_magnitude(&"x"))
	print("  - magnitude_policy_sum ok")


# ─── DOT tick ─────────────────────────────────────────────────────────────────
func _test_tick_dot() -> void:
	var comp := _make_component()
	var d := _make_effect(&"burn", 2.0, 5.0, 0.5)
	var tick_count: int = 0
	var tick_total: float = 0.0
	comp.effect_ticked.connect(func(id: StringName, mag: float, _src: Node) -> void:
		if id == &"burn":
			tick_count += 1
			tick_total += mag)
	comp.apply(d)
	# 2.0s con tick cada 0.5s → 4 ticks esperados.
	for i in range(20):
		comp.tick(0.1)
	# Tolerancia: float jitter puede dar 4 ticks exactos.
	assert(tick_count >= 3 and tick_count <= 4, \
		"dot: ticks esperados 3-4, got %d" % tick_count)
	assert(tick_total >= 15.0 and tick_total <= 20.0, \
		"dot: damage total 15-20, got %.1f" % tick_total)
	print("  - tick_dot ok")


# ─── magnitude_override ───────────────────────────────────────────────────────
func _test_magnitude_override() -> void:
	var comp := _make_component()
	var d := _make_effect(&"slow", 2.0, 0.5)
	comp.apply(d, null, 0.25)
	assert(is_equal_approx(comp.get_magnitude(&"slow"), 0.25), \
		"override: magnitude debe ser 0.25, got %.3f" % comp.get_magnitude(&"slow"))
	print("  - magnitude_override ok")


# ─── duration_override ────────────────────────────────────────────────────────
func _test_duration_override() -> void:
	var comp := _make_component()
	var d := _make_effect(&"buff", 2.0, 0.20)
	comp.apply(d, null, NAN, 5.0)
	assert(is_equal_approx(comp.get_remaining(&"buff"), 5.0), \
		"override: duration debe ser 5, got %.3f" % comp.get_remaining(&"buff"))
	print("  - duration_override ok")


# ─── remove by id ─────────────────────────────────────────────────────────────
func _test_remove_by_id() -> void:
	var comp := _make_component()
	var d := _make_effect(&"slow", 5.0, 0.5)
	comp.apply(d)
	assert(comp.has(&"slow"), "remove: pre-condition apply ok")
	comp.remove(&"slow")
	assert(not comp.has(&"slow"), "remove: tras remove no debe estar activo")
	print("  - remove_by_id ok")


# ─── clear() emite expired ────────────────────────────────────────────────────
func _test_clear_emits_expired() -> void:
	var comp := _make_component()
	var d1 := _make_effect(&"a", 5.0, 1.0)
	var d2 := _make_effect(&"b", 5.0, 2.0)
	comp.apply(d1)
	comp.apply(d2)
	var expired: Array[StringName] = []
	comp.effect_expired.connect(func(id: StringName, _src: Node) -> void:
		expired.append(id))
	comp.clear()
	assert(expired.size() == 2, "clear: debe emitir expired x2, got %d" % expired.size())
	assert(not comp.has(&"a") and not comp.has(&"b"), "clear: ningún efecto activo")
	print("  - clear_emits_expired ok")


# ─── get_remaining ────────────────────────────────────────────────────────────
func _test_get_remaining() -> void:
	var comp := _make_component()
	var d := _make_effect(&"x", 4.0, 0.5)
	assert(is_equal_approx(comp.get_remaining(&"x"), 0.0), "remaining: sin efecto = 0")
	comp.apply(d)
	assert(is_equal_approx(comp.get_remaining(&"x"), 4.0), "remaining: apply = duration")
	comp.tick(1.5)
	assert(is_equal_approx(comp.get_remaining(&"x"), 2.5), \
		"remaining: tras 1.5s = 2.5, got %.3f" % comp.get_remaining(&"x"))
	print("  - get_remaining ok")


# ─── get_active_ids ───────────────────────────────────────────────────────────
func _test_get_active_ids() -> void:
	var comp := _make_component()
	var d1 := _make_effect(&"a", 5.0, 1.0)
	var d2 := _make_effect(&"b", 5.0, 2.0)
	comp.apply(d1)
	comp.apply(d2)
	var ids := comp.get_active_ids()
	assert(ids.size() == 2, "active_ids: debe haber 2, got %d" % ids.size())
	assert(ids.has(&"a") and ids.has(&"b"), "active_ids: debe contener a y b")
	print("  - get_active_ids ok")


# ─── duration <= 0 ignored ────────────────────────────────────────────────────
func _test_zero_duration_ignored() -> void:
	var comp := _make_component()
	var d := _make_effect(&"x", 2.0, 1.0)
	comp.apply(d, null, NAN, 0.0)
	assert(not comp.has(&"x"), "zero_duration: no debe aplicar con duration 0")
	comp.apply(d, null, NAN, -1.0)
	assert(not comp.has(&"x"), "zero_duration: no debe aplicar con duration negativa")
	print("  - zero_duration_ignored ok")
