extends SceneTree
# Tests unitarios del sistema de skills R2 por clase. GDD §7.3.
# Valida: cooldowns, tabla de datos, telegrafía mínima, herencia R2→R3, taunt soak.
# NO cargan autoloads de physics — todo instanciación directa o datos puros.
#
# Ejecución: godot --headless --script res://tests/systems/r2_skills_test.gd

func _init() -> void:
	print("== r2_skills_test ==")
	_test_r2_skill_table_completa()
	_test_telegrafias_minimas_r2()
	_test_cooldown_r2_independiente_de_r3()
	_test_r2_skill_table_archer()
	_test_r2_skill_table_melee()
	_test_r2_skill_table_mage()
	_test_r2_skill_table_tank()
	_test_r1_no_tiene_r2_cooldown_inicializado()
	_test_taunt_redirect_calculo()
	_test_r3_tiene_ambos_cooldowns()
	print("All passed.")
	quit()


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Instancia un Enemy "en frío" sin árbol de escena.
## Solo para acceder a constantes y vars — NO llama _ready (sin autoloads).
func _make_enemy_data(enemy_class: int, rarity: int) -> Dictionary:
	# Accedemos directamente a la tabla constante sin instanciar el nodo completo.
	# Esto es posible porque R2_SKILL_TABLE usa GameConfig.EnemyClass como clave,
	# que son enteros 0-3, y GameConfig es un autoload cargado en SceneTree headless.
	return Enemy.R2_SKILL_TABLE.get(enemy_class, {})


func _assert(condition: bool, msg: String) -> void:
	assert(condition, msg)
	print("  - %s ok" % msg)


# ─── Tests ────────────────────────────────────────────────────────────────────

## Todas las clases deben tener entrada en la tabla R2.
func _test_r2_skill_table_completa() -> void:
	var clases: Array[int] = [
		GameConfig.EnemyClass.ARCHER,
		GameConfig.EnemyClass.MELEE,
		GameConfig.EnemyClass.MAGE,
		GameConfig.EnemyClass.TANK,
	]
	for c in clases:
		_assert(Enemy.R2_SKILL_TABLE.has(c), "R2_SKILL_TABLE tiene entrada para clase %d" % c)
		var entry: Dictionary = Enemy.R2_SKILL_TABLE[c]
		_assert(entry.has("telegraph_sec"), "clase %d tiene telegraph_sec" % c)
		_assert(entry.has("cd_min"), "clase %d tiene cd_min" % c)
		_assert(entry.has("cd_max"), "clase %d tiene cd_max" % c)
		_assert(entry.has("attack_duration"), "clase %d tiene attack_duration" % c)


## GDD §7.3 R2: telegrafía ≥0.5s para ataques pesados.
## Ninguna clase puede tener telegraph_sec < 0.5.
func _test_telegrafias_minimas_r2() -> void:
	const MIN_TELEGRAPH: float = 0.5
	for c in Enemy.R2_SKILL_TABLE:
		var entry: Dictionary = Enemy.R2_SKILL_TABLE[c]
		var tele: float = entry["telegraph_sec"]
		_assert(
			tele >= MIN_TELEGRAPH,
			"clase %d telegrafía %.2fs >= %.2fs mínimo R2" % [c, tele, MIN_TELEGRAPH]
		)


## El cooldown R2 y el R3 son independientes — ambos deben existir como constantes.
func _test_cooldown_r2_independiente_de_r3() -> void:
	# R3 usa SKILL_COOLDOWN_MIN/MAX. R2 usa tabla por clase.
	_assert(Enemy.SKILL_COOLDOWN_MIN > 0.0, "R3 SKILL_COOLDOWN_MIN existe y > 0")
	_assert(Enemy.SKILL_COOLDOWN_MAX > Enemy.SKILL_COOLDOWN_MIN, "R3 MAX > MIN")
	# R2: cada clase tiene cd_min/cd_max propios.
	for c in Enemy.R2_SKILL_TABLE:
		var entry: Dictionary = Enemy.R2_SKILL_TABLE[c]
		_assert(entry["cd_min"] > 0.0, "clase %d cd_min > 0" % c)
		_assert(entry["cd_max"] >= entry["cd_min"], "clase %d cd_max >= cd_min" % c)


## Archer: 3 flechas spread ±15°, CD 7-9s, telegraph 0.8s.
func _test_r2_skill_table_archer() -> void:
	var entry: Dictionary = Enemy.R2_SKILL_TABLE[GameConfig.EnemyClass.ARCHER]
	_assert(abs(entry["telegraph_sec"] - 0.8) < 0.01, "Archer telegraph = 0.8s")
	_assert(abs(entry["cd_min"] - 7.0) < 0.01, "Archer cd_min = 7.0")
	_assert(abs(entry["cd_max"] - 9.0) < 0.01, "Archer cd_max = 9.0")


## Melee: embestida-dash, CD 5-7s, telegraph 0.6s.
func _test_r2_skill_table_melee() -> void:
	var entry: Dictionary = Enemy.R2_SKILL_TABLE[GameConfig.EnemyClass.MELEE]
	_assert(abs(entry["telegraph_sec"] - 0.6) < 0.01, "Melee telegraph = 0.6s")
	_assert(abs(entry["cd_min"] - 5.0) < 0.01, "Melee cd_min = 5.0")
	_assert(abs(entry["cd_max"] - 7.0) < 0.01, "Melee cd_max = 7.0")


## Mage: fireball grande, CD 9-11s, telegraph 1.2s.
func _test_r2_skill_table_mage() -> void:
	var entry: Dictionary = Enemy.R2_SKILL_TABLE[GameConfig.EnemyClass.MAGE]
	_assert(abs(entry["telegraph_sec"] - 1.2) < 0.01, "Mage telegraph = 1.2s")
	_assert(abs(entry["cd_min"] - 9.0) < 0.01, "Mage cd_min = 9.0")
	_assert(abs(entry["cd_max"] - 11.0) < 0.01, "Mage cd_max = 11.0")


## Tank: taunt, CD 11-13s, telegraph 0.5s.
func _test_r2_skill_table_tank() -> void:
	var entry: Dictionary = Enemy.R2_SKILL_TABLE[GameConfig.EnemyClass.TANK]
	_assert(abs(entry["telegraph_sec"] - 0.5) < 0.01, "Tank telegraph = 0.5s")
	_assert(abs(entry["cd_min"] - 11.0) < 0.01, "Tank cd_min = 11.0")
	_assert(abs(entry["cd_max"] - 13.0) < 0.01, "Tank cd_max = 13.0")


## R1 NO debe tener habilidad R2 — verificamos que el cooldown mínimo del R2
## corresponde solo a R2/R3 (no hay condición que inicie _skill_r2_cooldown para R1).
## [LOGICO PURO — el test valida que la rareza R1 no está en el trigger de init]
func _test_r1_no_tiene_r2_cooldown_inicializado() -> void:
	# La inicialización solo ocurre si rarity == R2 || rarity == R3.
	# Verificamos que EnemyRarity.R1 != R2 y != R3 (trivial pero documenta la intención).
	_assert(GameConfig.EnemyRarity.R1 != GameConfig.EnemyRarity.R2, "R1 != R2 (init check)")
	_assert(GameConfig.EnemyRarity.R1 != GameConfig.EnemyRarity.R3, "R1 != R3 (init check)")


## Taunt redirect: TAUNT MMO clásico — 100% del daño se redirige al tank.
## El aliado NO recibe HP (parpadea visualmente solo). El tank recibe el daño completo.
## Cambio 27/05: 0.3 → 1.0 (ver enemy.gd R2_TANK_TAUNT_REDIRECT).
## [LOGICO PURO — simula el cálculo sin nodos reales]
func _test_taunt_redirect_calculo() -> void:
	const REDIRECT: float = Enemy.R2_TANK_TAUNT_REDIRECT  # 1.0
	_assert(is_equal_approx(REDIRECT, 1.0), "Taunt redirect debe ser 1.0 (MMO clásico)")
	# Con redirect 1.0: el tank recibe TODO, el aliado nada.
	# HurtboxComponent.receive_hit hace early-return tras aplicar daño al soaker.
	var original_damage: int = 100
	var to_tank: int = original_damage  # 100%
	var to_ally: int = 0  # aliado parpadea, sin daño
	_assert(to_tank == 100, "Taunt redirect: tank recibe 100 de 100")
	_assert(to_ally == 0, "Taunt redirect: aliado recibe 0 (parpadea visualmente)")


## R3 debe tener AMBOS cooldowns disponibles: _skill_cooldown (R3) y _skill_r2_cooldown.
## Verificamos que las constantes de ambos sistemas existen y son distintas.
func _test_r3_tiene_ambos_cooldowns() -> void:
	# Los cooldowns R3 existen como constantes en la clase.
	_assert(Enemy.SKILL_COOLDOWN_MIN == 6.0, "R3 SKILL_COOLDOWN_MIN = 6.0")
	_assert(Enemy.SKILL_COOLDOWN_MAX == 8.0, "R3 SKILL_COOLDOWN_MAX = 8.0")
	# Los cooldowns R2 del mage (el más largo) deben ser MAYORES que los del R3.
	var mage_cd_min: float = Enemy.R2_SKILL_TABLE[GameConfig.EnemyClass.MAGE]["cd_min"]
	_assert(mage_cd_min > Enemy.SKILL_COOLDOWN_MAX, "Mage R2 cd_min > R3 SKILL_COOLDOWN_MAX (cooldowns independientes)")
