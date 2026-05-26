extends Node
# Autoload "GoldSystem"
#
# Gestiona el Oro del jugador en runtime. GDD §5.5-5.6.
# Persiste entre stages y entre Game Over → Continue (es del personaje, no del run).
# SaveSystem (próximo task) leerá/escribirá _gold directamente.
#
# API de consumo es atómica: consume() valida antes de modificar.
# Cualquier sistema que necesite gastar Oro debe llamar can_afford() primero
# O simplemente llamar consume() y verificar el retorno bool.
#
# Patrón de uso en sistemas externos:
#   if not GoldSystem.consume(costo): return  # abortar sin tocar otros materiales
#
# Drop de Oro por kill: se conecta en GoldSystem.register_enemy (patrón DropSystem/ExperienceSystem).
# El multiplicador de Momentum SÍ aplica (≠ XP — Oro es recompensa de farmeo, nivel no).


# ─── Signals ─────────────────────────────────────────────────────────────────

## Emitido cuando el saldo cambia (add o consume exitoso).
## delta: positivo = ganancia, negativo = gasto.
signal gold_changed(new_total: int, delta: int)

## Emitido cuando se intenta gastar más oro del disponible.
signal not_enough_gold(required: int, available: int)


# ─── Estado interno ───────────────────────────────────────────────────────────

# Setteable directamente por SaveSystem para restaurar estado guardado.
var _gold: int = 0

# Mapea enemy (Node) → oro que otorga al morir. Patrón ExperienceSystem.
var _enemy_gold: Dictionary = {}  # Node → int


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	StageManager.stage_cleared.connect(_on_stage_cleared)


# ─── API pública — Consulta ───────────────────────────────────────────────────

func get_gold() -> int:
	return _gold


func can_afford(amount: int) -> bool:
	if amount <= 0:
		return true  # costo 0 siempre se puede pagar
	return _gold >= amount


# ─── API pública — Mutación ───────────────────────────────────────────────────

## Agrega Oro al saldo. Cantidad negativa es ignorada con warning.
## Retorna true siempre (no puede fallar).
func add(amount: int) -> bool:
	if amount <= 0:
		if amount < 0:
			push_warning("GoldSystem.add: cantidad negativa (%d) ignorada. Usar consume()." % amount)
		return true
	_gold += amount
	gold_changed.emit(_gold, amount)
	return true


## Consume Oro del saldo. Atómico: solo descuenta si hay suficiente.
## Retorna true si el consumo fue exitoso, false si no alcanza.
func consume(amount: int) -> bool:
	if amount <= 0:
		return true  # consumo de 0 es no-op exitoso
	if _gold < amount:
		not_enough_gold.emit(amount, _gold)
		return false
	_gold -= amount
	gold_changed.emit(_gold, -amount)
	return true


## Resetea el saldo a 0. Llamar en nueva partida si se decide no persistir.
## Entre Game Over → Continue NO se llama (persistencia de personaje).
func reset() -> void:
	_gold = 0
	gold_changed.emit(0, 0)


# ─── API de registro de enemies (patrón ExperienceSystem) ────────────────────

## El World llama esto por cada enemy spawneado, junto a ExperienceSystem.register_enemy.
## `rarity`: valor de GameConfig.EnemyRarity.
func register_enemy(enemy: Node, rarity: int) -> void:
	if enemy == null:
		push_warning("GoldSystem.register_enemy: enemy null, ignorado.")
		return
	if _enemy_gold.has(enemy):
		push_warning("GoldSystem.register_enemy: %s ya registrado, ignorado." % enemy.name)
		return
	var health: Node = enemy.get_node_or_null("HealthComponent")
	if health == null:
		push_warning("GoldSystem.register_enemy: %s sin HealthComponent, sin oro." % enemy.name)
		return
	var base_gold: int = GameConfig.gold_for_kill(rarity)
	_enemy_gold[enemy] = base_gold
	health.died.connect(_on_enemy_died.bind(enemy))
	# Mismo fix que DropSystem Bug #2: limpiar si el enemy es freed sin morir.
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))


# ─── Callbacks ────────────────────────────────────────────────────────────────

func _on_enemy_died(enemy: Node) -> void:
	var base_gold: int = _enemy_gold.get(enemy, 0)
	_enemy_gold.erase(enemy)
	if base_gold <= 0:
		return
	# Multiplicador de Momentum: Oro sí escala (es recompensa de farmeo).
	# Fórmula: gold_final = base × (1 + 0.1 × momentum). Cap momentum=10 → ×2.
	var momentum: int = MomentumSystem.current_level
	var mult: float = 1.0 + 0.1 * float(momentum)
	var final_gold: int = int(round(float(base_gold) * mult))
	add(final_gold)


func _on_enemy_tree_exited(enemy: Node) -> void:
	# Enemy freed sin morir (caída al vacío, reload, etc.).
	_enemy_gold.erase(enemy)


func _on_stage_cleared(_index: int) -> void:
	_enemy_gold.clear()


# ─── API pública (reset) ──────────────────────────────────────────────────────

## Limpieza total del tracking. Llamar al reiniciar run / Game Over / cambio de escena.
func reset_tracking() -> void:
	_enemy_gold.clear()


# ─── Serialización para SaveSystem ───────────────────────────────────────────

## Retorna el saldo actual para persistencia. Llamado por SaveSystem.
func _serialize_state() -> int:
	return _gold


## Restaura el saldo desde un valor guardado. Llamado por SaveSystem en _ready.
## No emite gold_changed — los listeners aún no existen al arrancar.
func _restore_state(saved_gold: int) -> void:
	_gold = maxi(0, saved_gold)


# ─── API de testabilidad (NO usar en código de juego) ────────────────────────

func _test_registered_count() -> int:
	return _enemy_gold.size()


func _test_is_registered(enemy: Node) -> bool:
	return _enemy_gold.has(enemy)


func _test_gold_for(enemy: Node) -> int:
	return _enemy_gold.get(enemy, -1)
