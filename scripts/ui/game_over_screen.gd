extends CanvasLayer
class_name GameOverScreen

## Pantalla de Game Over. Se instancia desde Player._on_died.
##
## Muestra "HAS CAÍDO" + botón Reintentar. Al click:
## - Limpia autoloads stateful (HitStop, CameraShake, MomentumSystem, InventorySystem)
## - Reload de la escena actual (recrea world + player desde cero)
##
## process_mode = ALWAYS para que el botón siga respondiendo aunque el árbol esté
## pausado o haya un HitStop pegado.

@onready var _retry_button: Button = $Panel/VBox/RetryButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # arriba de HUD (que es CanvasLayer default).
	if _retry_button != null:
		_retry_button.pressed.connect(_on_retry_pressed)
		_retry_button.grab_focus()


func _on_retry_pressed() -> void:
	# Reset de autoloads stateful antes del reload.
	HitStop.clear()
	CameraShake.clear()
	MomentumSystem.reset()
	InventorySystem.reset()
	DropSystem.reset()  # BUG #3 FIX: limpiar refs de la run anterior antes del reload.
	ExperienceSystem.reset()  # limpiar refs de enemies de la run anterior.
	# NOTA: PlayerProgression NO se resetea — nivel y puntos persisten entre runs.
	# Asegurar time_scale normal (defensivo: si quedó pegado por algún edge case).
	Engine.time_scale = 1.0
	# Reload limpia el árbol y vuelve a instanciar world.tscn → player.tscn nuevo.
	get_tree().reload_current_scene()
