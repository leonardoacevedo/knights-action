extends Control
class_name TouchButton

## Botón touch para controles móviles.
## @export action_name: nombre de la action a simular (attack, dash, ui_accept).
## Press en touch/click adentro del rect; release puede ocurrir fuera (drag out).
## Soporta multitouch (varios dedos sobre el botón en distintos índices).

signal button_pressed
signal button_released

## Action de Godot Input que activa este botón.
@export var action_name: StringName = &"attack"
## Etiqueta visible dentro del botón (1 carácter recomendado: A, D, J).
@export var label_text: String = "A"
## Color de fondo del botón en reposo.
@export var color_normal: Color = Color(0.85, 0.15, 0.15, 0.75)
## Color cuando está presionado.
@export var color_pressed: Color = Color(1.0, 0.45, 0.15, 0.95)
## Radio visual del botón.
@export var visual_radius: float = 38.0

var _is_pressed: bool = false
# Track de touches activos sobre el botón. -2 = mouse (índice sintético).
var _touch_indices: Array[int] = []

@onready var _label: Label = $Label


func _ready() -> void:
	if _label != null:
		_label.text = label_text
	# Asegurar mouse_filter STOP para que _gui_input se dispare.
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	# ALWAYS para que el poll de auto-release siga funcionando incluso si el
	# árbol queda pausado por un menú modal (ej. inventario abierto).
	process_mode = Node.PROCESS_MODE_ALWAYS


## Poll defensivo: si quedamos pressed pero el mouse/touch ya no está activo
## (porque un CanvasLayer modal consumió el evento release), auto-soltamos.
## Sin esto, los botones INV/EQUIP quedan stuck cuando el InventoryScreen abre
## y captura el release antes de propagarlo a este Control.
func _process(_delta: float) -> void:
	if not _is_pressed:
		return
	# Caso mouse (incluye PC con mouse-as-touch): si el botón izquierdo ya no
	# está apretado, sacar el índice sintético y release.
	if _touch_indices.has(-2) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_touch_indices.erase(-2)
		if _touch_indices.is_empty():
			_release()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var col: Color = color_pressed if _is_pressed else color_normal
	# Círculo de fondo.
	draw_circle(center, visual_radius, col)
	# Borde sutil más claro.
	draw_arc(center, visual_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 2.0)


## _gui_input se llama cuando el cursor/touch está sobre el rect del Control
## (con mouse_filter != IGNORE). Filtra por bounding box automáticamente.
## Usado para detectar PRESS adentro del botón.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _touch_indices.has(event.index):
				_touch_indices.append(event.index)
			_press()
			accept_event()
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if not _touch_indices.has(-2):
				_touch_indices.append(-2)
			_press()
			accept_event()


## _input se llama para TODOS los eventos del juego.
## Usado para detectar RELEASE incluso cuando el dedo/mouse salió del rect.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		if _touch_indices.has(event.index):
			_touch_indices.erase(event.index)
			if _touch_indices.is_empty():
				_release()
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch_indices.has(-2):
			_touch_indices.erase(-2)
			if _touch_indices.is_empty():
				_release()


func _press() -> void:
	if _is_pressed:
		return
	_is_pressed = true
	# Si la action ya estaba activa (tecla física, o touch emulado desde mouse con
	# emulate_touch_from_mouse=true que dispara mouse + touch a la vez), NO re-inyectar
	# el InputEventAction sintético: evita el doble disparo (A11).
	var already_active: bool = Input.is_action_pressed(action_name)
	Input.action_press(action_name)
	# Solo parsear un InputEventAction sintético si no había otra fuente activa, para
	# que listeners que usan _input() con event.is_action_pressed() reciban el toggle.
	if not already_active:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action_name
		ev.pressed = true
		Input.parse_input_event(ev)
	button_pressed.emit()
	queue_redraw()


func _release() -> void:
	if not _is_pressed:
		return
	_is_pressed = false
	Input.action_release(action_name)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action_name
	ev.pressed = false
	Input.parse_input_event(ev)
	button_released.emit()
	queue_redraw()
