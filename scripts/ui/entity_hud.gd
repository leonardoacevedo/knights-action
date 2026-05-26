extends Node2D
class_name EntityHud

## Mini-HUD que se renderea encima de cualquier entity con HealthComponent.
## Detecta automáticamente FuriaComponent del parent; si no existe, oculta esa barra.
## Pensado para enemies. Para el player se usa el HUD global del CanvasLayer.

@export var width: float = 80.0
@export var hp_height: float = 6.0
@export var furia_height: float = 3.0
@export var spacing: float = 2.0
@export var bg_color: Color = Color(0.08, 0.08, 0.1, 0.85)
@export var hp_color: Color = Color(0.85, 0.2, 0.22, 1)
@export var furia_color: Color = Color(0.55, 0.25, 0.85, 1)
@export var border_color: Color = Color(0, 0, 0, 0.6)

var _hp_pct: float = 1.0
var _furia_pct: float = 0.0
var _has_furia: bool = false


func _ready() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	# HealthComponent obligatorio.
	var health_node: Node = parent.get_node_or_null("HealthComponent")
	if health_node is HealthComponent:
		var hp_comp: HealthComponent = health_node
		_hp_pct = hp_comp.get_health_percent()
		hp_comp.health_changed.connect(_on_health_changed)
	else:
		push_warning("EntityHud sin HealthComponent en parent: %s" % parent.get_path())

	# FuriaComponent opcional (enemies R1 no lo tienen, R2+ podrían).
	var furia_node: Node = parent.get_node_or_null("FuriaComponent")
	if furia_node is FuriaComponent:
		var f_comp: FuriaComponent = furia_node
		_has_furia = true
		_furia_pct = f_comp.get_percent()
		f_comp.furia_changed.connect(_on_furia_changed)

	queue_redraw()


func _draw() -> void:
	var x_start: float = -width / 2.0
	var hp_y: float = 0.0

	# HP: borde + bg + fg.
	draw_rect(Rect2(x_start - 1.0, hp_y - 1.0, width + 2.0, hp_height + 2.0), border_color)
	draw_rect(Rect2(x_start, hp_y, width, hp_height), bg_color)
	draw_rect(Rect2(x_start, hp_y, width * _hp_pct, hp_height), hp_color)

	if _has_furia:
		var furia_y: float = hp_height + spacing
		draw_rect(Rect2(x_start - 1.0, furia_y - 1.0, width + 2.0, furia_height + 2.0), border_color)
		draw_rect(Rect2(x_start, furia_y, width, furia_height), bg_color)
		draw_rect(Rect2(x_start, furia_y, width * _furia_pct, furia_height), furia_color)


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_pct = (float(current) / float(maximum)) if maximum > 0 else 0.0
	queue_redraw()


func _on_furia_changed(current: int, maximum: int) -> void:
	_furia_pct = (float(current) / float(maximum)) if maximum > 0 else 0.0
	queue_redraw()
