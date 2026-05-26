extends Node
## HitStop — autoload. Pequeño freeze global al impactar/recibir golpe.
##
## Da peso al combate: el frame del hit se "clava" un instante (50-80ms típico).
## Usar: HitStop.freeze(seconds). Si llaman varias veces overlap, prevalece el
## end_time más lejano (lo más largo gana, no se acumula).
##
## Implementación: setea Engine.time_scale a un valor muy bajo (no 0 para que el
## input siga respondiendo) y restaura a 1.0 cuando expira. Usa Time.get_ticks_msec()
## en lugar de delta para no depender del time_scale del propio congelado.

## Time scale durante el freeze. Casi cero pero no exactamente para mantener
## responsividad del input/render.
const FREEZE_SCALE: float = 0.02

var _end_time_ms: int = 0
var _frozen: bool = false


func _ready() -> void:
	# ALWAYS para que corra aunque el árbol esté pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not _frozen:
		return
	if Time.get_ticks_msec() >= _end_time_ms:
		_frozen = false
		Engine.time_scale = 1.0


## Congela el juego por `seconds`. Si ya hay un freeze activo, prevalece
## el final más lejano (no se reinicia el contador hacia atrás).
func freeze(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var new_end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	if new_end > _end_time_ms:
		_end_time_ms = new_end
	if not _frozen:
		_frozen = true
		Engine.time_scale = FREEZE_SCALE


## Cortar el freeze inmediatamente (útil al cambiar de escena / reset).
func clear() -> void:
	_frozen = false
	_end_time_ms = 0
	Engine.time_scale = 1.0
