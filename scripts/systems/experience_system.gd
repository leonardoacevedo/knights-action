extends Node
# Autoload "ExperienceSystem"
#
# Otorga XP al player cuando un enemy registrado muere.
# Patrón calcado de DropSystem: World llama register_enemy(enemy, rarity)
# al spawnear. Al morir, sumamos XP a PlayerProgression. GDD §6.1.
#
# Sin multiplicador de Momentum (decisión de diseño — nivel es progresión
# del personaje, no recompensa de farmeo). Ver GameConfig.XP_PER_RARITY.


# ─── Estado interno ───────────────────────────────────────────────────────────

# Mapea enemy (Node) → XP que otorga al morir.
# Calculamos el monto al registrar y lo guardamos para defensividad:
# si la rareza del enemy cambia en runtime (no debería), el monto sigue siendo
# el del momento del spawn.
var _enemy_xp: Dictionary = {}  # Node → int


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	StageManager.stage_cleared.connect(_on_stage_cleared)


# ─── API pública ─────────────────────────────────────────────────────────────

## El World llama esto por cada enemy spawneado, junto a DropSystem.register_enemy.
## `rarity`: valor de GameConfig.EnemyRarity.
func register_enemy(enemy: Node, rarity: int) -> void:
	if enemy == null:
		push_warning("ExperienceSystem.register_enemy: enemy null, ignorado.")
		return
	# Mismo fix que DropSystem Bug #1: no registrar dos veces el mismo enemy.
	if _enemy_xp.has(enemy):
		push_warning("ExperienceSystem.register_enemy: %s ya registrado, ignorado." % enemy.name)
		return
	var health: Node = enemy.get_node_or_null("HealthComponent")
	if health == null:
		push_warning("ExperienceSystem.register_enemy: %s sin HealthComponent, sin XP." % enemy.name)
		return
	var xp: int = GameConfig.xp_for_kill(rarity)
	_enemy_xp[enemy] = xp
	health.died.connect(_on_enemy_died.bind(enemy))
	# Mismo fix que DropSystem Bug #2: limpiar si el enemy es freed sin morir.
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))


# ─── Callbacks ────────────────────────────────────────────────────────────────

func _on_enemy_died(enemy: Node) -> void:
	var xp: int = _enemy_xp.get(enemy, 0)
	# Limpiar antes de otorgar (defensivo: si add_xp emite señales síncronas
	# que referencian este dict, ya está limpio).
	_enemy_xp.erase(enemy)
	if xp > 0:
		PlayerProgression.add_xp(xp)


func _on_enemy_tree_exited(enemy: Node) -> void:
	# Enemy freed sin pasar por died (caída al vacío, reload, etc.).
	# Si died corrió primero, erase es no-op — orden garantizado por Godot.
	_enemy_xp.erase(enemy)


func _on_stage_cleared(_index: int) -> void:
	# Limpiar referencias que quedaron tras el stage.
	_enemy_xp.clear()


# ─── API pública (reset) ──────────────────────────────────────────────────────

## Limpieza total. Llamar al reiniciar run / Game Over / cambio de escena.
func reset() -> void:
	_enemy_xp.clear()


# ─── API de testabilidad (NO usar en código de juego) ────────────────────────

## Cantidad de enemies registrados actualmente. Solo para tests.
func _test_registered_count() -> int:
	return _enemy_xp.size()

## True si el enemy está registrado. Solo para tests.
func _test_is_registered(enemy: Node) -> bool:
	return _enemy_xp.has(enemy)

## XP guardada para un enemy. Solo para tests.
func _test_xp_for(enemy: Node) -> int:
	return _enemy_xp.get(enemy, -1)
