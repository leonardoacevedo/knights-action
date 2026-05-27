extends Node
# Autoload "TestArenaConfig"
#
# Estado del modo prueba. Por defecto inactivo.
# Cuando está activo, ExperienceSystem / GoldSystem / DropSystem
# saltean sus callbacks de muerte para no contaminar el save.
# World._ready lo consulta para construir el StageData runtime.

var is_test_mode: bool = false
var pending_spawns: Array[EnemySpawnEntry] = []


func enter_test_mode(spawns: Array[EnemySpawnEntry]) -> void:
	is_test_mode = true
	pending_spawns = spawns.duplicate()


func exit_test_mode() -> void:
	is_test_mode = false
	pending_spawns.clear()
