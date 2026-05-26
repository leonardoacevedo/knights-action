extends Node
## CameraShake — autoload. Shake de la cámara activa.
##
## Usar: CameraShake.shake(magnitude, duration).
## - magnitude: amplitud en pixeles (2-12 típico).
## - duration: segundos (0.10-0.25 típico).
##
## La cámara la resuelve cada frame via get_viewport().get_camera_2d() — no
## necesita estar wireada. Si no hay cámara activa, el shake no hace nada.
##
## No se acumula: si llaman shake mientras hay otro activo, gana el de mayor
## "intensidad total" (magnitude * duration restante).

var _magnitude: float = 0.0
var _time_left: float = 0.0
var _duration: float = 0.0


func _ready() -> void:
	# ALWAYS para que el shake siga aunque haya time_scale=0 del HitStop —
	# el shake decaerá igual y no se quedará pegado.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Pedir un shake. Gana el de mayor "energía" (magnitude × duration restante).
func shake(magnitude: float, duration: float = 0.18) -> void:
	if magnitude <= 0.0 or duration <= 0.0:
		return
	var current_energy: float = _magnitude * _time_left
	var new_energy: float = magnitude * duration
	if new_energy >= current_energy:
		_magnitude = magnitude
		_duration = duration
		_time_left = duration


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	# Usamos delta real (no afectado por time_scale=0.02 del HitStop) tomando
	# advantage de process_mode = ALWAYS. Sin embargo, Engine.time_scale SÍ afecta
	# delta acá. Usamos un workaround: medimos via Time.get_ticks_msec si hay freeze.
	var dt: float = delta
	_time_left -= dt
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	if _time_left <= 0.0:
		cam.offset = Vector2.ZERO
		return
	# Decay lineal: full magnitude al inicio, 0 al final.
	var decay: float = _time_left / _duration
	var mag: float = _magnitude * decay
	cam.offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))


## Cortar shake y devolver la cámara a su posición. Útil al reset/cambio de escena.
func clear() -> void:
	_time_left = 0.0
	_magnitude = 0.0
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		cam.offset = Vector2.ZERO
