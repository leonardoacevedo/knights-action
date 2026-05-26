extends Control
class_name ShieldChargesDisplay

## Iconos de cargas de bloqueo disponibles. Hijo del HUD.
## Se redibuja al recibir set_charges(current, max). El HUD se encarga de
## conectarlo al ShieldComponent del player.
##
## Llenos = cargas listas. Vacíos = ya gastadas. Sin escudo (max=0) = no dibuja nada.

const ICON_SIZE: float = 22.0
const ICON_GAP: float = 6.0

const COLOR_FILLED: Color = Color(0.45, 0.75, 1.0, 1.0)
const COLOR_FILLED_RIM: Color = Color(0.95, 0.85, 0.4, 1.0)
const COLOR_EMPTY: Color = Color(0.18, 0.18, 0.22, 0.7)
const COLOR_EMPTY_RIM: Color = Color(0.4, 0.4, 0.45, 0.8)
const COLOR_BOSS: Color = Color(0.98, 0.95, 0.7, 1.0)

var current: int = 0
var maximum: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)


func set_charges(p_current: int, p_max: int) -> void:
	current = p_current
	maximum = p_max
	var total_w: float = 0.0
	if maximum > 0:
		total_w = ICON_SIZE * float(maximum) + ICON_GAP * float(maximum - 1)
	custom_minimum_size = Vector2(max(ICON_SIZE, total_w), ICON_SIZE)
	queue_redraw()


func _draw() -> void:
	if maximum <= 0:
		return
	for i in maximum:
		var cx: float = float(i) * (ICON_SIZE + ICON_GAP) + ICON_SIZE * 0.5
		var cy: float = ICON_SIZE * 0.5
		var center: Vector2 = Vector2(cx, cy)
		_draw_shield_icon(center, i < current)


func _draw_shield_icon(center: Vector2, filled: bool) -> void:
	var face_col: Color = COLOR_FILLED if filled else COLOR_EMPTY
	var rim_col: Color = COLOR_FILLED_RIM if filled else COLOR_EMPTY_RIM
	var rx: float = ICON_SIZE * 0.38
	var ry: float = ICON_SIZE * 0.46
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 14
	for i in steps:
		var t: float = float(i) / float(steps) * TAU
		pts.append(center + Vector2(cos(t) * rx, sin(t) * ry))
	draw_polygon(pts, [face_col])
	var loop: PackedVector2Array = pts + PackedVector2Array([pts[0]])
	draw_polyline(loop, rim_col, 1.6)
	if filled:
		# Boss central tipo escudo medieval.
		draw_circle(center, 2.0, COLOR_BOSS)
