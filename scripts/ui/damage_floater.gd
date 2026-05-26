extends Label
class_name DamageFloater

## Texto numérico que aparece al recibir daño y se desvanece subiendo.
## Spawnear con DamageFloater.spawn(parent, world_pos, damage, color).

## Duración total de la animación (segundos).
@export var duration: float = 0.9
## Distancia vertical que sube el texto (px).
@export var rise_distance: float = 70.0
## Offset horizontal aleatorio para evitar overlap visual.
@export var random_x_jitter: float = 24.0

var _time: float = 0.0
var _start_pos: Vector2


func _ready() -> void:
	# Estilo: fuente grande, outline negro para legibilidad sobre cualquier fondo.
	add_theme_font_size_override("font_size", 26)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	add_theme_constant_override("outline_size", 5)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	z_index = 100  # encima de casi todo
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Helper estático: instancia el floater y lo agrega al world.
## Usar desde cualquier entity al recibir daño.
static func spawn(parent: Node, world_pos: Vector2, damage: int, color: Color) -> void:
	spawn_text(parent, world_pos, str(damage), color)


## Spawn con tamaño de fuente variable. Usar para feedback elemental:
## ventaja → font_size grande (32), desventaja → chico (20), neutral → 26.
static func spawn_with_size(parent: Node, world_pos: Vector2, damage: int, color: Color, font_size: int) -> void:
	var floater: DamageFloater = preload("res://scenes/ui/damage_floater.tscn").instantiate()
	floater.text = str(damage)
	floater.add_theme_color_override("font_color", color)
	floater.add_theme_font_size_override("font_size", font_size)
	floater.size = Vector2(110, 30)
	floater.pivot_offset = floater.size / 2.0
	floater.global_position = world_pos - floater.size / 2.0
	floater._start_pos = floater.global_position + Vector2(randf_range(-floater.random_x_jitter, floater.random_x_jitter), 0)
	floater.global_position = floater._start_pos
	parent.add_child(floater)


## Igual que spawn() pero acepta cualquier string (ej. "BLOCK!", "MISS", "CRIT").
static func spawn_text(parent: Node, world_pos: Vector2, label: String, color: Color) -> void:
	var floater: DamageFloater = preload("res://scenes/ui/damage_floater.tscn").instantiate()
	floater.text = label
	floater.add_theme_color_override("font_color", color)
	# Tamaño aproximado del Label para centrarlo en la posición indicada.
	floater.size = Vector2(110, 30)
	floater.pivot_offset = floater.size / 2.0
	floater.global_position = world_pos - floater.size / 2.0
	floater._start_pos = floater.global_position + Vector2(randf_range(-floater.random_x_jitter, floater.random_x_jitter), 0)
	floater.global_position = floater._start_pos
	parent.add_child(floater)


func _process(delta: float) -> void:
	_time += delta
	var t: float = clamp(_time / duration, 0.0, 1.0)
	# Curva ease-out: sube rápido al principio, frena.
	var ease_t: float = 1.0 - pow(1.0 - t, 2.0)
	global_position = _start_pos + Vector2(0, -rise_distance * ease_t)
	# Fade out en la segunda mitad.
	modulate.a = 1.0 if t < 0.5 else 1.0 - (t - 0.5) * 2.0
	if _time >= duration:
		queue_free()
