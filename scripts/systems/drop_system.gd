extends Node
# Autoload "DropSystem"
#
# Responsable de convertir la muerte de un enemy en materiales en el inventario,
# y de convertir un stage_cleared en items equipables en el inventario (Milestone B).
#
# Wiring con el world:
#   El World llama DropSystem.register_enemy(enemy, drop_table) en paralelo
#   a StageManager.register_enemy(enemy). Así cada enemy conoce su tabla
#   sin acoplamiento entre StageManager y DropSystem.
#
#   Si drop_table es null, DropSystem busca la tabla fallback de la stage actual
#   via StageManager.current_stage().material_drops.
#
# GDD §5.5 — materiales por zona; items por stage cleared.
# GDD §111 — drop_rate = base * (1 + 0.1 * momentum).


# ─── Signals ─────────────────────────────────────────────────────────────────

## Emitido al completar una stage. items puede ser [] si no dropea nada.
## La UI escucha esto para mostrar la loot card (T21, ux-mobile).
signal items_dropped(items: Array[ItemData])


# ─── Estado interno ───────────────────────────────────────────────────────────

# Mapea enemy (Node) → DropTable asignada. Limpiado entre stages.
var _enemy_tables: Dictionary = {}


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Conectar a stage_cleared para limpiar referencias internas de la stage vieja.
	StageManager.stage_cleared.connect(_on_stage_cleared)


# ─── API pública ─────────────────────────────────────────────────────────────

## El World llama esto por cada enemy spawneado, justo después de (o junto a)
## StageManager.register_enemy(enemy).
##
## `drop_table` puede ser null: en ese caso se usará el material_drops de
## StageData como fallback en el momento del kill.
func register_enemy(enemy: Node, drop_table: DropTable = null) -> void:
	if enemy == null:
		push_warning("DropSystem.register_enemy: enemy null, ignorado.")
		return
	# BUG #1 FIX: si el enemy ya está registrado, ignorar el segundo llamado.
	# No sobrescribimos la tabla — el world no debería registrar el mismo enemy dos veces.
	if _enemy_tables.has(enemy):
		push_warning("DropSystem.register_enemy: enemy ya registrado, ignorado.")
		return
	var health: Node = enemy.get_node_or_null("HealthComponent")
	if health == null:
		push_warning("DropSystem.register_enemy: %s sin HealthComponent, sin drops." % enemy.name)
		return
	_enemy_tables[enemy] = drop_table
	# Usamos Callable.bind para pasar el enemy a la callback (necesitamos su tabla).
	health.died.connect(_on_enemy_died.bind(enemy))
	# BUG #2 FIX: limpiar la entrada si el enemy es freed sin emitir died
	# (caída al vacío, exit de scene, queue_free directo desde debug, etc.).
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))


# ─── Callbacks ───────────────────────────────────────────────────────────────

func _on_enemy_died(enemy: Node) -> void:
	var table: DropTable = _resolve_table(enemy)
	# Limpiar entrada antes de procesar — el enemy ya está muerto.
	_enemy_tables.erase(enemy)

	if table == null:
		# Sin tabla configurada: kill sin drops. Normal en stages sin loot todavía.
		return

	var momentum: int = MomentumSystem.current_level
	var results: Array = table.roll_materials_only(momentum)
	for result in results:
		var material: MaterialData = result["data"]
		var count: int = result["count"]
		InventorySystem.add_material(material, count)


func _on_enemy_tree_exited(enemy: Node) -> void:
	# BUG #2 FIX: enemy freed sin pasar por died (caída al vacío, reload, etc.).
	# Si died corrió primero, erase es no-op. Orden garantizado por Godot:
	# died se emite antes de queue_free, así que _on_enemy_died corre primero.
	_enemy_tables.erase(enemy)


func _on_stage_cleared(_index: int) -> void:
	# Limpiar referencias que quedaron (enemies que el stage_manager ya descartó).
	_enemy_tables.clear()

	# Milestone B: rolear item_drops de la stage y agregarlos al inventario.
	var items_list: Array[ItemData] = []
	var stage: StageData = StageManager.current_stage()
	if stage != null and stage.item_drops != null:
		var momentum: int = MomentumSystem.current_level
		var results: Array = stage.item_drops.roll_items_only(momentum)
		for result in results:
			var item: ItemData = result["data"]
			# add_item devuelve la instancia duplicada — usarla para la loot card.
			var instance: ItemData = InventorySystem.add_item(item)
			if instance != null:
				items_list.append(instance)

	# Emitir siempre — la UI decide qué mostrar (loot card futura T21, ux-mobile).
	items_dropped.emit(items_list)


# ─── API pública (reset) ──────────────────────────────────────────────────────

## Limpieza total. Usar al reiniciar run / Game Over / cambio de escena no orquestado.
## BUG #3 FIX: el autoload no se destruye al reload, así que el state sucio persiste
## si solo se hace get_tree().reload_current_scene() sin limpiar antes.
func reset() -> void:
	_enemy_tables.clear()


# ─── API de testabilidad (NO usar en código de juego) ────────────────────────

## Cantidad de enemies actualmente registrados. Solo para tests de regresión.
func _test_registered_count() -> int:
	return _enemy_tables.size()

## True si el enemy está en el dictionary interno. Solo para tests de regresión.
func _test_is_registered(enemy: Node) -> bool:
	return _enemy_tables.has(enemy)


# ─── Privado ─────────────────────────────────────────────────────────────────

## Resuelve qué DropTable usar para este enemy.
## Prioridad: tabla propia del enemy → tabla fallback de la StageData actual → null.
func _resolve_table(enemy: Node) -> DropTable:
	var own_table: DropTable = _enemy_tables.get(enemy, null)
	if own_table != null:
		return own_table
	var stage: StageData = StageManager.current_stage()
	if stage != null:
		return stage.material_drops
	return null
