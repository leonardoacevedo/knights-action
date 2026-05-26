extends CanvasLayer
class_name TouchControlsLayer

## Capa de controles touch (joystick virtual + botones de acción).
##
## Se auto-oculta si GameConfig.PLATFORM_MODE = PC, asumiendo teclado.
## En MOBILE muestra todo. Cambiar la flag en GameConfig.gd.
##
## NO desactiva el procesamiento — `visible=false` en CanvasLayer también
## suprime input handling de los hijos Control, así que en PC los botones
## no consumen toques accidentales del mouse en su zona.


func _ready() -> void:
	if GameConfig.is_pc():
		visible = false
