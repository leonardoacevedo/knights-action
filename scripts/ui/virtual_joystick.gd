extends Control
class_name VirtualJoystick

## Joystick virtual para controles touch.
## Maneja InputEventScreenTouch + InputEventScreenDrag (y mouse como fallback en PC).
## Traduce dirección a actions: ui_left, ui_right, ui_accept (salto al push arriba).

signal direction_changed(direction: Vector2)

## Radio visual del círculo base (dp).
@export var base_radius: float = 80.0
## Radio visual del knob (dp).
@export var knob_radius: float = 40.0
## Umbral horizontal para activar ui_left / ui_right (0–1).
@export var horizontal_threshold: float = 0.3
## Umbral vertical (negativo = arriba) para activar ui_accept / salto.
@export var vertical_threshold: float = 0.5
## Color del círculo base. Alpha alto para que contraste con fondos oscuros.
@export var color_base: Color = Color(1.0, 1.0, 1.0, 0.35)
## Color del knob.
@export var color_knob: Color = Color(1.0, 1.0, 1.0, 0.85)

# Estado interno.
var _touch_index: int = -1       # índice del dedo que capturó el joystick; -1 = libre
var _base_center: Vector2        # posición del centro del joystick en pantalla
var _knob_offset: Vector2        # offset del knob relativo al centro (-base_radius..+base_radius)
var _direction: Vector2          # dirección normalizada actual (Vector2.ZERO si idle)

# Acciones que estaban activas en el frame anterior (para release correcto).
var _action_right_active: bool = false
var _action_left_active: bool = false
var _action_jump_active: bool = false


func _ready() -> void:
	# hit area cubre toda la zona izquierda inferior; se define en la escena
	# con un Control de tamaño adecuado (≥ 160×160 dp).
	_base_center = _get_default_center()


func _get_default_center() -> Vector2:
	# Devuelve el centro visual del joystick basado en tamaño del nodo.
	return size / 2.0


func _draw() -> void:
	# Círculo base translúcido.
	draw_circle(size / 2.0, base_radius, color_base)
	# Knob más opaco, desplazado según input.
	draw_circle(size / 2.0 + _knob_offset, knob_radius, color_knob)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Solo captura si ningún dedo tiene el joystick y el toque cae en la zona.
		if _touch_index == -1 and _is_inside_zone(event.position):
			_touch_index = event.index
			_base_center = event.position
			_knob_offset = Vector2.ZERO
			queue_redraw()
	else:
		if event.index == _touch_index:
			_release_joystick()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	_update_knob(event.position)


# Fallback mouse para test en PC (Godot no emula touch por defecto sin project settings).
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if _touch_index == -1 and _is_inside_zone(event.position):
			# Usamos índice sintético -2 para mouse (distinto de touch real).
			_touch_index = -2
			_base_center = event.position
			_knob_offset = Vector2.ZERO
			queue_redraw()
	else:
		if _touch_index == -2:
			_release_joystick()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _touch_index != -2:
		return
	_update_knob(event.position)


func _update_knob(touch_pos: Vector2) -> void:
	var offset: Vector2 = touch_pos - _base_center
	# Clamp al radio máximo del base.
	if offset.length() > base_radius:
		offset = offset.normalized() * base_radius
	_knob_offset = offset
	_direction = offset / base_radius if base_radius > 0.0 else Vector2.ZERO
	direction_changed.emit(_direction)
	_sync_actions()
	queue_redraw()


func _release_joystick() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	_direction = Vector2.ZERO
	_base_center = _get_default_center()
	_release_all_actions()
	direction_changed.emit(_direction)
	queue_redraw()


func _sync_actions() -> void:
	# Horizontal: ui_right / ui_left.
	var want_right: bool = _direction.x > horizontal_threshold
	var want_left: bool = _direction.x < -horizontal_threshold
	# Vertical: ui_accept (salto) si push arriba supera umbral.
	# Y negativo = arriba en coordenadas Godot.
	var want_jump: bool = _direction.y < -vertical_threshold

	_set_action(&"ui_right", want_right, _action_right_active)
	_set_action(&"ui_left", want_left, _action_left_active)
	_set_action(&"ui_accept", want_jump, _action_jump_active)

	_action_right_active = want_right
	_action_left_active = want_left
	_action_jump_active = want_jump


func _set_action(action: StringName, want: bool, was_active: bool) -> void:
	if want and not was_active:
		Input.action_press(action)
	elif not want and was_active:
		Input.action_release(action)


func _release_all_actions() -> void:
	if _action_right_active:
		Input.action_release(&"ui_right")
	if _action_left_active:
		Input.action_release(&"ui_left")
	if _action_jump_active:
		Input.action_release(&"ui_accept")
	_action_right_active = false
	_action_left_active = false
	_action_jump_active = false


func _is_inside_zone(pos: Vector2) -> bool:
	# Comprueba que el toque cae dentro del rect global de este Control.
	var rect: Rect2 = Rect2(global_position, size)
	return rect.has_point(pos)


## Devuelve la dirección normalizada actual. Útil para polling externo opcional.
func get_direction() -> Vector2:
	return _direction
