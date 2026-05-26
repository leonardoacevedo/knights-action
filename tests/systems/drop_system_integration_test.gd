extends SceneTree
# Tests de regresión para los 3 bugs CRITICAL fixeados en DropSystem.
# Requiere autoloads activos (GameConfig, MomentumSystem, InventorySystem,
# StageManager, DropSystem) — se cargan automáticamente del project.godot
# cuando se corre el script con `godot --headless --script`.
#
# Ejecución:
#   godot --headless --script res://tests/systems/drop_system_integration_test.gd
#
# Exit code 0 = todos ok. Exit code 1 = al menos un test falló.
#
# Decisión técnica: Opción A (SceneTree real + autoloads del proyecto).
# Los nodes de enemy son instancias mínimas de Node con un hijo HealthComponent
# añadidas como hijos del root para que tree_exited dispare correctamente
# cuando se llama queue_free(). Esto permite testear Bug #2 sin mockear nada.
#
# Modificación en DropSystem: se agregaron _test_registered_count() y
# _test_is_registered(enemy) — getters de solo-lectura para testabilidad.
# No cambian el comportamiento de producción.

var _failed: bool = false


func _initialize() -> void:
	# Diferir el runner al loop principal para que process_frame y señales funcionen.
	# _initialize() corre antes del loop — call_deferred garantiza que _run_tests()
	# corra dentro del primer frame del engine loop, donde await process_frame es válido.
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("== drop_system_integration_test ==")

	# Verificar que los autoloads están vivos antes de correr tests.
	if not _check_autoloads():
		print("SKIPPED: autoloads no disponibles — corré con 'godot --headless --script res://tests/systems/drop_system_integration_test.gd'")
		quit(0)
		return

	# Limpiar estado de autoloads antes de arrancar (puede haber estado sucio de tests anteriores).
	_reset_all_systems()

	await _test_bug1_double_connect_no_duplicate_drops()
	await _test_bug1_double_connect_preserves_original_table()
	await _test_bug2_ref_colgante_cleanup()
	_test_bug3_reset_clears_enemy_tables()
	await _test_fallback_stage_material_drops()
	await _test_end_to_end_died_adds_to_inventory()

	if _failed:
		print("FALLARON uno o más tests.")
		quit(1)
	else:
		print("All passed.")
		quit(0)


# ─── Verificación de autoloads ────────────────────────────────────────────────

func _check_autoloads() -> bool:
	# Godot 4 registra los autoloads GDScript como hijos directos del root
	# con el nombre del autoload. Verificamos los 3 que más usa este test.
	var ds: Node = root.get_node_or_null("/root/DropSystem")
	var inv: Node = root.get_node_or_null("/root/InventorySystem")
	var sm: Node = root.get_node_or_null("/root/StageManager")
	return ds != null and inv != null and sm != null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _reset_all_systems() -> void:
	# Limpiar todos los autoloads que tienen estado mutable.
	DropSystem.reset()
	InventorySystem.reset()
	MomentumSystem.reset()
	StageManager.reset()


## Crea un enemy mínimo con HealthComponent. El enemy no se agrega al árbol aquí —
## el caller decide cuándo hacerlo para controlar tree_exited.
## _ready() de HealthComponent corre cuando root.add_child(enemy) se llama.
func _make_enemy(name_str: String) -> Node:
	var enemy := Node.new()
	enemy.name = name_str
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_health = 10
	enemy.add_child(hc)
	return enemy


## Crea una DropTable con un material de drop garantizado (chance=1.0).
func _make_guaranteed_table(mat_id: StringName) -> DropTable:
	var mat := MaterialData.new()
	mat.id = mat_id
	mat.display_name = str(mat_id)
	mat.max_stack = 99
	var entry := DropEntry.new()
	entry.drop_type = DropEntry.DropType.MATERIAL
	entry.material_data = mat
	entry.drop_chance = 1.0
	entry.material_count_min = 1
	entry.material_count_max = 1
	var table := DropTable.new()
	table.entries = [entry]
	return table


## Obtiene el HealthComponent del enemy. Asume que se creó con _make_enemy().
func _get_health(enemy: Node) -> HealthComponent:
	return enemy.get_node("HealthComponent") as HealthComponent


func _assert(condition: bool, msg: String) -> void:
	if not condition:
		print("  FAIL: " + msg)
		_failed = true
	else:
		print("  ok: " + msg)


# ─── Test #1a: double-connect NO duplica drops ───────────────────────────────
# Valida BUG #1 FIX: si register_enemy se llama dos veces con el mismo enemy,
# la segunda llamada early-returnea y el enemy solo tiene UNA conexión a died.
# Resultado: cuando el enemy muere, los materiales llegan una sola vez.

func _test_bug1_double_connect_no_duplicate_drops() -> void:
	print("TEST #1a — double-connect no duplica drops")
	_reset_all_systems()

	var enemy := _make_enemy("enemy_double_connect")
	root.add_child(enemy)

	var table := _make_guaranteed_table(&"mat_doble")
	# Registrar dos veces el mismo enemy con la misma tabla.
	DropSystem.register_enemy(enemy, table)
	DropSystem.register_enemy(enemy, table)  # debe ser ignorado (BUG #1 FIX)

	# Verificar que el enemy solo está una vez en _enemy_tables.
	_assert(DropSystem._test_registered_count() == 1,
		"después de doble registro, _enemy_tables debe tener 1 entrada, no 2")

	# Matar el enemy y verificar que el material llega exactamente 1 vez.
	var before_count: int = InventorySystem.get_material_count(&"mat_doble")
	_get_health(enemy).take_damage(9999)  # Mata el enemy via HealthComponent

	# Esperar un frame para que las señales propaguen.
	await process_frame

	var after_count: int = InventorySystem.get_material_count(&"mat_doble")
	var added: int = after_count - before_count
	_assert(added == 1,
		"drop debe llegar exactamente 1 vez (esperado 1, obtuvo %d)" % added)

	enemy.queue_free()
	await process_frame
	_reset_all_systems()


# ─── Test #1b: double-connect NO sobrescribe tabla original ──────────────────
# Valida BUG #1 FIX: la segunda llamada con tabla DIFERENTE debe ser ignorada.
# La tabla que queda activa debe ser la PRIMERA registrada.

func _test_bug1_double_connect_preserves_original_table() -> void:
	print("TEST #1b — double-connect preserva tabla original")
	_reset_all_systems()

	var enemy := _make_enemy("enemy_preserve_table")
	root.add_child(enemy)

	var table_original := _make_guaranteed_table(&"mat_original")
	var table_impostor := _make_guaranteed_table(&"mat_impostor")

	# Registrar con tabla original, luego intentar sobrescribir con impostor.
	DropSystem.register_enemy(enemy, table_original)
	DropSystem.register_enemy(enemy, table_impostor)  # debe ser ignorado

	# Matar el enemy.
	_get_health(enemy).take_damage(9999)
	await process_frame

	# Solo "mat_original" debe haber dropeado. "mat_impostor" nunca.
	_assert(InventorySystem.get_material_count(&"mat_original") == 1,
		"mat_original debe estar en inventario (tabla original se preservó)")
	_assert(InventorySystem.get_material_count(&"mat_impostor") == 0,
		"mat_impostor NO debe estar en inventario (segunda tabla ignorada)")

	enemy.queue_free()
	await process_frame
	_reset_all_systems()


# ─── Test #2: ref colgante — queue_free sin morir limpia _enemy_tables ────────
# Valida BUG #2 FIX: al hacer queue_free() directo sin que HealthComponent.died
# emita, el hook tree_exited debe limpiar la entrada del Dictionary.

func _test_bug2_ref_colgante_cleanup() -> void:
	print("TEST #2 — ref colgante: queue_free sin died limpia _enemy_tables")
	_reset_all_systems()

	var enemy := _make_enemy("enemy_ref_colgante")
	root.add_child(enemy)

	var table := _make_guaranteed_table(&"mat_ref")
	DropSystem.register_enemy(enemy, table)

	# Verificar que está registrado.
	_assert(DropSystem._test_is_registered(enemy),
		"enemy debe estar registrado antes de queue_free")
	_assert(DropSystem._test_registered_count() == 1,
		"_enemy_tables debe tener 1 entrada antes de queue_free")

	# Liberar sin matar (sin emitir died).
	enemy.queue_free()

	# Esperar UN frame para que el SceneTree procese tree_exited.
	await process_frame

	# Verificar que el Dictionary fue limpiado por el hook tree_exited (BUG #2 FIX).
	_assert(DropSystem._test_registered_count() == 0,
		"_enemy_tables debe estar vacío después de queue_free (tree_exited hook)")

	# Verificar que no se dropeó nada (el enemy nunca murió).
	_assert(InventorySystem.get_material_count(&"mat_ref") == 0,
		"no debe haber drops si el enemy fue freed sin morir")

	_reset_all_systems()


# ─── Test #3: reset() limpia _enemy_tables ───────────────────────────────────
# Valida BUG #3 FIX: DropSystem.reset() debe vaciar _enemy_tables completamente.

func _test_bug3_reset_clears_enemy_tables() -> void:
	print("TEST #3 — reset() limpia _enemy_tables")
	_reset_all_systems()

	# Registrar 2 enemies. Los agregamos al árbol para que register_enemy
	# pueda conectar tree_exited (necesita que el node tenga SceneTree).
	# El reset se llama ANTES de que queue_free procese tree_exited, así que
	# el erase posterior en tree_exited es no-op — sin efecto colateral.
	var enemy_a := _make_enemy("enemy_reset_a")
	var enemy_b := _make_enemy("enemy_reset_b")
	root.add_child(enemy_a)
	root.add_child(enemy_b)

	var table := _make_guaranteed_table(&"mat_reset")
	DropSystem.register_enemy(enemy_a, table)
	DropSystem.register_enemy(enemy_b, table)

	_assert(DropSystem._test_registered_count() == 2,
		"antes de reset: _enemy_tables debe tener 2 entradas")

	# Llamar reset (BUG #3 FIX).
	DropSystem.reset()

	_assert(DropSystem._test_registered_count() == 0,
		"después de reset: _enemy_tables debe estar vacío")

	# Cleanup manual — los nodes quedaron en árbol pero DropSystem ya no los trackea.
	enemy_a.queue_free()
	enemy_b.queue_free()
	_reset_all_systems()


# ─── Test #4: fallback a StageData.material_drops ────────────────────────────
# Cuando register_enemy se llama con drop_table=null, _resolve_table debe
# retornar StageManager.current_stage().material_drops como fallback.

func _test_fallback_stage_material_drops() -> void:
	print("TEST #4 — fallback a StageData.material_drops")
	_reset_all_systems()

	# Configurar StageManager con un StageData que tiene material_drops.
	var fallback_table := _make_guaranteed_table(&"mat_fallback")
	var stage := StageData.new()
	stage.stage_index = 1
	stage.display_name = "Stage Test"
	stage.material_drops = fallback_table

	# configure() + avanzar al primer stage manualmente para que current_stage() != null.
	StageManager.configure([stage])
	# current_index empieza en -1 hasta start_run(). Llamar start_run() lo avanza a 0
	# y emite stage_pending. No necesitamos el banner — solo el estado.
	StageManager.start_run()
	# Ahora current_stage() debe devolver `stage`.
	_assert(StageManager.current_stage() != null,
		"StageManager.current_stage() debe ser no-null después de start_run")
	_assert(StageManager.current_stage() == stage,
		"current_stage() debe ser el StageData que configuramos")

	# Registrar enemy SIN tabla propia (null → debe usar fallback).
	var enemy := _make_enemy("enemy_fallback")
	root.add_child(enemy)
	DropSystem.register_enemy(enemy, null)  # drop_table = null

	# Matar el enemy → _resolve_table debe caer al fallback.
	_get_health(enemy).take_damage(9999)
	await process_frame

	_assert(InventorySystem.get_material_count(&"mat_fallback") == 1,
		"material del fallback de StageData debe llegar al inventario")

	enemy.queue_free()
	await process_frame
	_reset_all_systems()


# ─── Test #5: end-to-end — died → roll → InventorySystem ─────────────────────
# Verifica el flujo completo: enemy registrado con tabla propia → muere →
# DropTable.roll_materials_only() corre → InventorySystem.add_material() recibe el resultado.

func _test_end_to_end_died_adds_to_inventory() -> void:
	print("TEST #5 — end-to-end: died → roll → inventario")
	_reset_all_systems()

	# Momentum en 0 para drop determinístico (chance=1.0 → siempre dropea).
	MomentumSystem.reset()
	_assert(MomentumSystem.current_level == 0, "momentum debe ser 0 al inicio del test")

	var enemy := _make_enemy("enemy_e2e")
	root.add_child(enemy)

	var table := _make_guaranteed_table(&"mat_e2e")
	DropSystem.register_enemy(enemy, table)

	# El enemy no debe estar en el inventario todavía.
	_assert(InventorySystem.get_material_count(&"mat_e2e") == 0,
		"inventario vacío antes del kill")

	# Matar el enemy.
	_get_health(enemy).take_damage(9999)
	await process_frame

	# Verificar que el material llegó al inventario.
	_assert(InventorySystem.get_material_count(&"mat_e2e") == 1,
		"material debe estar en inventario después del kill (count=1)")

	# Verificar que _enemy_tables fue limpiado después del died.
	_assert(DropSystem._test_registered_count() == 0,
		"_enemy_tables debe estar vacío después de que el enemy murió")

	enemy.queue_free()
	await process_frame
	_reset_all_systems()
