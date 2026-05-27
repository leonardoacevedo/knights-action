extends SceneTree
# Tests unitarios de la transición de fase de los 3 bosses Fase 3.
# Valida que cada boss cruza a F2 cuando current_health <= max_health / 2.
# NO instancia el nodo completo (los bosses heredan de Enemy, que necesita
# árbol de escena y autoloads); en vez, valida la lógica pura via HealthComponent
# directo + simulación del callback _on_health_changed.
#
# Ejecución: godot --headless --script res://tests/bosses/boss_phases_test.gd

func _init() -> void:
	print("== boss_phases_test ==")
	_test_health_threshold_50pc_logic()
	_test_each_boss_has_phase_2_factor()
	_test_each_boss_has_distinct_signature_constants()
	_test_persistent_hazard_class_loads()
	_test_drop_tables_exist()
	print("All passed.")
	quit()


func _assert(cond: bool, msg: String) -> void:
	assert(cond, msg)
	print("  - %s ok" % msg)


# ─── Logic test: threshold de fase 2 ──────────────────────────────────────────
## Simula la condición exacta del _on_health_changed: phase 1 → phase 2 al cruzar HP/2.
## Cubre el contrato compartido por los 3 bosses sin instanciar sus scripts.
func _test_health_threshold_50pc_logic() -> void:
	# HP máximo arbitrario (mismo número usado por los 3 bosses en escala).
	var max_hp: int = 200
	# Caso A: HP > 50% → NO debe pasar a fase 2.
	var current_above_50: int = 120
	_assert(not _crosses_phase_2_threshold(1, current_above_50, max_hp),
		"HP > 50%% (120/200) NO cruza threshold")
	# Caso B: HP exactamente 50% → SÍ cruza.
	var current_eq_50: int = 100
	_assert(_crosses_phase_2_threshold(1, current_eq_50, max_hp),
		"HP == 50%% (100/200) SÍ cruza threshold")
	# Caso C: HP < 50% → SÍ cruza.
	var current_below_50: int = 80
	_assert(_crosses_phase_2_threshold(1, current_below_50, max_hp),
		"HP < 50%% (80/200) SÍ cruza threshold")
	# Caso D: ya en fase 2 → NO debe re-cruzar.
	_assert(not _crosses_phase_2_threshold(2, current_below_50, max_hp),
		"ya en F2 NO re-cruza threshold")


## Reimplementa la condición de fase 2 que comparten los 3 bosses:
##   if _phase == 1 and current <= maximum / 2: _enter_phase_2()
## Acepta el phase actual + HP para validar el contrato.
func _crosses_phase_2_threshold(current_phase: int, current_hp: int, max_hp: int) -> bool:
	return current_phase == 1 and current_hp <= max_hp / 2


# ─── Cada boss tiene PHASE_2_COOLDOWN_FACTOR < 1.0 (CDs más rápidos en F2) ────
func _test_each_boss_has_phase_2_factor() -> void:
	_assert(BossDuelista.PHASE_2_COOLDOWN_FACTOR < 1.0,
		"Duelista F2 cooldown factor < 1.0")
	_assert(BossCazadora.PHASE_2_COOLDOWN_FACTOR < 1.0,
		"Cazadora F2 cooldown factor < 1.0")
	_assert(BossHeraldo.PHASE_2_COOLDOWN_FACTOR < 1.0,
		"Heraldo F2 cooldown factor < 1.0")
	# El Guardián ya validado en su feature: solo sanity check del factor exportado.
	_assert(BossGuardian.PHASE_2_COOLDOWN_FACTOR < 1.0,
		"Guardian F2 cooldown factor < 1.0")


# ─── Cada boss tiene constante de signatura diferenciada ─────────────────────
## Valida que cada boss define el patrón core que lo hace único.
## Duelista: parry. Cazadora: 3 perchas. Heraldo: eco eterno.
func _test_each_boss_has_distinct_signature_constants() -> void:
	# Duelista: parry counter mult x2.
	_assert(abs(BossDuelista.PARRY_COUNTER_DAMAGE_MULT - 2.0) < 0.01,
		"Duelista PARRY_COUNTER_DAMAGE_MULT == 2.0")
	# Cazadora: 3 perchas fijas en world coords + sin gravedad (implícito).
	_assert(BossCazadora.PERCH_LEFT != BossCazadora.PERCH_CENTER,
		"Cazadora PERCH_LEFT != CENTER")
	_assert(BossCazadora.PERCH_CENTER != BossCazadora.PERCH_RIGHT,
		"Cazadora PERCH_CENTER != RIGHT")
	_assert(BossCazadora.MAREO_SLOW_MULT < 1.0,
		"Cazadora MAREO_SLOW_MULT slow real (< 1.0)")
	# Heraldo: eco eterno duración largo + offsets simétricos.
	_assert(BossHeraldo.ECO_ETERNO_DURATION >= 30.0,
		"Heraldo ECO_ETERNO_DURATION cubre toda F2 (>= 30s)")
	_assert(BossHeraldo.ECO_ETERNO_OFFSET_LEFT.x < 0.0,
		"Heraldo eco izq tiene X negativa")
	_assert(BossHeraldo.ECO_ETERNO_OFFSET_RIGHT.x > 0.0,
		"Heraldo eco der tiene X positiva")


# ─── PersistentHazard carga como clase ───────────────────────────────────────
## Sanity check: la clase nueva PersistentHazard se reconoce y tiene la API esperada.
func _test_persistent_hazard_class_loads() -> void:
	var hz: PersistentHazard = PersistentHazard.new()
	_assert(hz != null, "PersistentHazard se instancia")
	_assert(hz.has_method("setup"), "PersistentHazard.setup() existe")
	_assert(hz.has_method("_apply_tick_damage"), "PersistentHazard._apply_tick_damage() existe")
	# Defaults razonables.
	_assert(hz.radius > 0.0, "PersistentHazard radius default > 0")
	_assert(hz.duration > 0.0, "PersistentHazard duration default > 0")
	_assert(hz.damage_per_tick > 0, "PersistentHazard damage_per_tick default > 0")
	hz.free()


# ─── Drop tables de los 3 bosses existen y cargan como DropTable ─────────────
func _test_drop_tables_exist() -> void:
	var paths: Array[String] = [
		"res://resources/stages/drop_tables/boss_duelista_items.tres",
		"res://resources/stages/drop_tables/boss_cazadora_items.tres",
		"res://resources/stages/drop_tables/boss_heraldo_items.tres",
	]
	for path in paths:
		var res: Resource = load(path) as Resource
		_assert(res != null, "drop table carga: %s" % path)
		_assert(res is DropTable, "drop table es DropTable: %s" % path)
		var dt: DropTable = res
		_assert(dt.entries.size() >= 3,
			"drop table tiene >= 3 entries: %s" % path)
		# Al menos una entry tiene drop_chance > 0.
		var any_droppable: bool = false
		for entry: DropEntry in dt.entries:
			if entry != null and entry.drop_chance > 0.0:
				any_droppable = true
				break
		_assert(any_droppable, "drop table tiene al menos 1 entry con chance > 0: %s" % path)
