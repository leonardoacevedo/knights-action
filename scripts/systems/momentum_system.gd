extends Node
## MomentumSystem — autoload. GDD §4.3.
##
## Multiplicador de combate del player. Sube +1 por golpe (cap 10),
## resetea al recibir daño. Bloqueo (cuando exista) congela 1s sin resetear.
## Escala daño, drops y ganancia de Furia.
##
## Acoplamiento: player.gd llama a on_hit_landed / on_damage_taken.
## El HUD escucha momentum_changed y los threshold_*.

const MAX_LEVEL := 10
const BLOCK_FREEZE_SECONDS := 1.0
const THRESHOLD_VISUAL := 5   # nivel a partir del cual hay feedback visual

signal momentum_changed(new_level: int)
signal momentum_reset
signal threshold_5x_reached
signal threshold_5x_lost

var current_level: int = 0
var _frozen: bool = false
var _freeze_timer: float = 0.0


func _process(delta: float) -> void:
	if not _frozen:
		return
	_freeze_timer -= delta
	if _freeze_timer <= 0.0:
		_frozen = false


func on_hit_landed() -> void:
	if current_level >= MAX_LEVEL:
		return
	var was_below_threshold := current_level < THRESHOLD_VISUAL
	current_level += 1
	momentum_changed.emit(current_level)
	if was_below_threshold and current_level >= THRESHOLD_VISUAL:
		threshold_5x_reached.emit()


func on_damage_taken() -> void:
	# Bloqueo congela, no resetea. Si está congelado, ignoramos el reset.
	if _frozen:
		return
	if current_level == 0:
		return
	var was_at_threshold := current_level >= THRESHOLD_VISUAL
	current_level = 0
	momentum_changed.emit(0)
	momentum_reset.emit()
	if was_at_threshold:
		threshold_5x_lost.emit()


func on_block_absorbed() -> void:
	# Lo llama la lógica de Bloqueo cuando exista. Por ahora reservado.
	_frozen = true
	_freeze_timer = BLOCK_FREEZE_SECONDS


func damage_multiplier() -> float:
	return 1.0 + 0.05 * float(current_level)


func drop_multiplier() -> float:
	return 1.0 + 0.1 * float(current_level)


func furia_multiplier() -> float:
	return 1.0 + 0.05 * float(current_level)


func reset() -> void:
	# Helper para tests o cambios de escena.
	current_level = 0
	_frozen = false
	_freeze_timer = 0.0
	momentum_changed.emit(0)
