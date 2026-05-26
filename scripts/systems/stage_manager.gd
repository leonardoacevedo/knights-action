extends Node
## StageManager — autoload que orquesta la progresión de etapas en una run.
##
## Una "run" es una secuencia ordenada de StageData. El world spawnea los enemies
## de cada stage; cuando todos mueren, StageManager avanza al siguiente.
##
## Flujo típico (lo invoca World en _ready):
##   1. StageManager.configure([stage1, stage2, stage3, boss_stage])
##   2. StageManager.start_run()           → emite stage_started(stage1, 0)
##   3. World escucha stage_started → spawnea los enemies del stage actual,
##      y para cada uno llama StageManager.register_enemy(enemy).
##   4. Cuando todos los registrados mueren → emite stage_cleared(idx).
##   5. Tras ADVANCE_DELAY_SECONDS, emite stage_started del siguiente
##      (o run_completed si era el último).
##
## El World es responsable del spawn físico y del cleanup entre stages.
## StageManager solo trackea estado y emite eventos.

# ─── Signals ──────────────────────────────────────────────────────────────────

## Se dispara cuando una stage queda lista para empezar pero ESPERA confirmación.
## El World ya puede preparar el layout (tint, plataformas) pero NO spawnear.
## El Banner debe mostrar el botón START aquí.
signal stage_pending(data: StageData, index: int)

## Se dispara cuando el jugador confirma el inicio del combate de la stage.
## El World debe spawnear los enemies de `data` aquí.
signal stage_started(data: StageData, index: int)

## Se dispara cuando todos los enemies registrados de la stage actual murieron.
## El World puede mostrar un "etapa completada", limpiar partículas, etc.
signal stage_cleared(index: int)

## Se dispara cuando la última stage fue completada (toda la run terminó).
signal run_completed()

## Emitido al inicio de start_run() para que la UI sepa que arrancó una corrida.
signal run_started()

# ─── Config ───────────────────────────────────────────────────────────────────

## Pausa entre stage_cleared y stage_started del siguiente. Da tiempo a respirar
## y ver el banner de transición.
const ADVANCE_DELAY_SECONDS: float = 1.5

# ─── Estado ───────────────────────────────────────────────────────────────────

var _stages: Array[StageData] = []
var _current_index: int = -1
var _alive_count: int = 0
var _is_transitioning: bool = false
var _registered_enemies: Array[Node] = []
## True desde stage_pending hasta request_combat_start.
## Mientras está en true, el world no spawnea y el banner muestra START.
var _is_pending: bool = false


# ─── API pública ──────────────────────────────────────────────────────────────

## Cargar la lista de stages para esta run. Reemplaza la anterior.
## Llamar ANTES de start_run().
func configure(p_stages: Array[StageData]) -> void:
	_stages = p_stages
	_current_index = -1
	_alive_count = 0
	_is_transitioning = false
	_registered_enemies.clear()


## Inicia la run desde la primera stage. Emite run_started() y stage_pending(0).
## El combate real arranca cuando el jugador llama request_combat_start().
func start_run() -> void:
	if _stages.is_empty():
		push_warning("StageManager.start_run: sin stages configurados.")
		return
	_current_index = -1
	_alive_count = 0
	_registered_enemies.clear()
	run_started.emit()
	_enter_stage_pending(0)


## El jugador confirma que está listo para pelear esta stage.
## Emite stage_started → world spawnea.
func request_combat_start() -> void:
	if not _is_pending:
		push_warning("StageManager.request_combat_start: no hay stage en pending.")
		return
	if _current_index < 0 or _current_index >= _stages.size():
		return
	_is_pending = false
	stage_started.emit(_stages[_current_index], _current_index)


## True mientras esperamos que el jugador apriete START.
func is_pending() -> bool:
	return _is_pending


## Stage actual o null si no hay run activa.
func current_stage() -> StageData:
	if _current_index < 0 or _current_index >= _stages.size():
		return null
	return _stages[_current_index]


## Índice 0-based de la stage actual. -1 si no hay run.
func current_index() -> int:
	return _current_index


## Total de stages configurados.
func total_stages() -> int:
	return _stages.size()


## Enemies vivos en la stage actual.
func alive_count() -> int:
	return _alive_count


## El World llama esto por cada enemy que spawneó para que el manager lo trackee.
## Se conecta automáticamente al HealthComponent.died del enemy.
func register_enemy(enemy: Node) -> void:
	if enemy == null:
		push_warning("StageManager.register_enemy: enemy null.")
		return
	var health: Node = enemy.get_node_or_null("HealthComponent")
	if health == null:
		push_warning("StageManager.register_enemy: %s sin HealthComponent." % enemy.name)
		return
	_registered_enemies.append(enemy)
	_alive_count += 1
	# Bind del enemy para identificar quién murió (no usado todavía, futuro).
	if not health.died.is_connected(_on_enemy_died):
		health.died.connect(_on_enemy_died)


## Reset total. Útil para "volver al menú" o "reintentar run".
func reset() -> void:
	_stages.clear()
	_current_index = -1
	_alive_count = 0
	_is_transitioning = false
	_is_pending = false
	_registered_enemies.clear()


# ─── Privado ──────────────────────────────────────────────────────────────────

func _enter_stage_pending(index: int) -> void:
	if index < 0 or index >= _stages.size():
		push_warning("StageManager._enter_stage_pending: index %d fuera de rango." % index)
		return
	_current_index = index
	_alive_count = 0
	_registered_enemies.clear()
	_is_transitioning = false
	_is_pending = true
	stage_pending.emit(_stages[index], index)


func _on_enemy_died() -> void:
	# El signal no nos pasa quién — pero como solo contamos, alcanza.
	if _is_transitioning:
		# Edge case: un proyectil hace daño cero después de stage_cleared.
		# No debería pasar (los enemies ya están muertos), pero por las dudas.
		return
	_alive_count = max(0, _alive_count - 1)
	if _alive_count == 0:
		_handle_stage_cleared()


func _handle_stage_cleared() -> void:
	_is_transitioning = true
	stage_cleared.emit(_current_index)

	# Si es el último stage, terminar la run.
	if _current_index >= _stages.size() - 1:
		# Pequeña pausa para que el "boss muerto" se vea antes del run_completed.
		await get_tree().create_timer(ADVANCE_DELAY_SECONDS).timeout
		run_completed.emit()
		return

	# Pausa antes del siguiente stage. Entra a pending (espera START de nuevo).
	await get_tree().create_timer(ADVANCE_DELAY_SECONDS).timeout
	_enter_stage_pending(_current_index + 1)
