extends Node
class_name HealthComponent

## HP del entity. Emite señales en cambio y muerte.
## Reset Momentum por daño físico va en MomentumSystem (no acá).

signal died
signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)

@export var max_health: int = 100

var current_health: int

func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = max(0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = min(max_health, current_health + amount)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func is_alive() -> bool:
	return current_health > 0


func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)
