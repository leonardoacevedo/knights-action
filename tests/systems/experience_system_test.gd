extends SceneTree
# Tests unitarios para ExperienceSystem + GameConfig.xp_for_kill. GDD §6.1.
#
# ExperienceSystem depende de autoloads (PlayerProgression, StageManager,
# GameConfig). En headless no cargan automáticamente → tests de integración
# marcados con [INTEGRACION] requieren el editor.
# Los tests de GameConfig.xp_for_kill son puramente estáticos y funcionan en
# headless sin autoloads.
#
# Ejecución: godot --headless --script res://tests/systems/experience_system_test.gd


# ─── Stubs para tests de integración (cuando autoloads están disponibles) ─────

## Enemy falso con HealthComponent que emite señal died.
class FakeHealthComponent extends Node:
	signal died()
	func kill() -> void:
		died.emit()


class FakeEnemy extends Node:
	var health: FakeHealthComponent

	func _init() -> void:
		health = FakeHealthComponent.new()
		health.name = "HealthComponent"
		add_child(health)


# ─── Setup ────────────────────────────────────────────────────────────────────

func _init() -> void:
	print("== experience_system_test ==")
	_test_xp_for_kill_r1()
	_test_xp_for_kill_r4()
	_test_xp_for_kill_invalid_rarity()
	_test_xp_dict_completeness()
	print("--- Tests de integración (requieren SceneTree con autoloads) ---")
	print("  [INTEGRACION] register_enemy + died → PlayerProgression gana XP")
	print("  [INTEGRACION] register_enemy dos veces → warning + sin XP duplicado")
	print("  [INTEGRACION] tree_exited sin died → erase sin XP")
	print("  [INTEGRACION] reset() limpia _enemy_xp")
	print("  Ejecutar manualmente desde el editor para tests de integración.")
	print("All static tests passed.")
	quit()


# ─── Caso 1: xp_for_kill(R1) → 10 ───────────────────────────────────────────

func _test_xp_for_kill_r1() -> void:
	var result: int = GameConfig.xp_for_kill(GameConfig.EnemyRarity.R1)
	assert(result == 10, "xp_for_kill(R1) debe ser 10, obtuvo %d" % result)
	print("  - xp_for_kill_r1 ok (%d XP)" % result)


# ─── Caso 2: xp_for_kill(R4) → 300 ──────────────────────────────────────────

func _test_xp_for_kill_r4() -> void:
	var result: int = GameConfig.xp_for_kill(GameConfig.EnemyRarity.R4)
	assert(result == 300, "xp_for_kill(R4) debe ser 300, obtuvo %d" % result)
	print("  - xp_for_kill_r4 ok (%d XP)" % result)


# ─── Caso 3: xp_for_kill(rareza inválida) → 0 ────────────────────────────────

func _test_xp_for_kill_invalid_rarity() -> void:
	var result: int = GameConfig.xp_for_kill(999)
	assert(result == 0, "xp_for_kill(invalid) debe retornar 0, obtuvo %d" % result)
	print("  - xp_for_kill_invalid_rarity ok")


# ─── Caso 4: todas las rarezas están en el dict ──────────────────────────────

func _test_xp_dict_completeness() -> void:
	# Verifica que no haya rareza sin entrada (saltarse una daría 0 silencioso).
	var rarezas: Array[int] = [
		GameConfig.EnemyRarity.R1,
		GameConfig.EnemyRarity.R2,
		GameConfig.EnemyRarity.R3,
		GameConfig.EnemyRarity.R4,
	]
	for r: int in rarezas:
		var xp: int = GameConfig.xp_for_kill(r)
		assert(xp > 0, "xp_for_kill(R%d) debe ser >0, obtuvo %d" % [r + 1, xp])
	print("  - xp_dict_completeness ok (R1=%d R2=%d R3=%d R4=%d)" % [
		GameConfig.xp_for_kill(GameConfig.EnemyRarity.R1),
		GameConfig.xp_for_kill(GameConfig.EnemyRarity.R2),
		GameConfig.xp_for_kill(GameConfig.EnemyRarity.R3),
		GameConfig.xp_for_kill(GameConfig.EnemyRarity.R4),
	])


# ─── Tests de integración (no automáticos — documentados para corrida manual) ─

## [INTEGRACION] register_enemy + died → PlayerProgression.add_xp(25) se llama.
## Requiere autoloads GameConfig, PlayerProgression, StageManager activos.
## Pasos:
##   1. Instanciar ExperienceSystem + FakeEnemy con FakeHealthComponent.
##   2. Llamar ExperienceSystem.register_enemy(enemy, EnemyRarity.R2).
##   3. Registrar xp_before = PlayerProgression.get_xp().
##   4. Llamar enemy.health.kill() → died se emite.
##   5. Afirmar PlayerProgression.get_xp() >= xp_before + 25.
##   6. Afirmar ExperienceSystem._test_is_registered(enemy) == false (limpiado).

## [INTEGRACION] register_enemy dos veces → segunda llamada emite warning, no duplica XP.
## Pasos:
##   1. register_enemy(enemy, R1) dos veces.
##   2. ExperienceSystem._test_registered_count() == 1.
##   3. enemy.health.kill() → PlayerProgression gana solo 10 XP (no 20).

## [INTEGRACION] tree_exited sin died → enemy limpiado, sin XP otorgada.
## Pasos:
##   1. register_enemy(enemy, R3).
##   2. enemy.queue_free() → tree_exited se emite.
##   3. ExperienceSystem._test_registered_count() == 0.
##   4. PlayerProgression.get_xp() sin cambio.

## [INTEGRACION] reset() limpia _enemy_xp.
## Pasos:
##   1. register_enemy(enemy, R1) sin matar.
##   2. ExperienceSystem.reset().
##   3. ExperienceSystem._test_registered_count() == 0.
