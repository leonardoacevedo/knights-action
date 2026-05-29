extends Node2D
class_name SlashArc

## Arco de tajo reusable para melee (Corte Giratorio, Tajo Doble, combos, Patada/Gancho).
## VFX liviano: una Line2D curva que "barre" un arco ~0.15-0.2s y hace fade-out.
##
## Construido 100% por código — no necesita .tscn. Mobile-cheap: 1 Line2D, 0 partículas.
##
## Uso típico (helper estático, no requiere guardar referencia):
##   SlashArc.spawn(self, global_position, facing, reach, Color(1, 0.5, 0.15), 120.0)
##
## El arco aparece centrado en `pos`, orientado por `facing` (+1 derecha / -1 izquierda),
## a distancia `reach` del origen, con apertura `arc_deg` y color `color`.

## Cantidad de puntos del arco. 10 = curva suave a coste casi nulo.
const ARC_POINTS: int = 10
## Duración del barrido (segundos). Corto = sensación de tajo rápido.
const SWEEP_TIME: float = 0.18
## Grosor de la línea del arco en px.
const ARC_WIDTH: float = 6.0

var _line: Line2D = null
## Parámetros del arco (seteados por spawn antes de _ready vía configure()).
var _reach: float = 60.0
var _facing: int = 1
var _arc_deg: float = 120.0
var _color: Color = Color(1.0, 1.0, 1.0, 0.9)


## Helper estático de spawn. Instancia un SlashArc, lo configura y lo agrega a `parent`.
## - parent: nodo al que se agrega (típicamente la entidad o current_scene).
## - pos: posición global del centro del barrido (origen del atacante).
## - facing: +1 mira derecha, -1 mira izquierda.
## - reach: distancia del arco al origen (px). Aproximá al alcance del hitbox melee.
## - color: color del tajo (usá el del elemento del arma para legibilidad).
## - arc_deg: apertura del arco en grados (default 120° = swing amplio).
static func spawn(parent: Node, pos: Vector2, facing: int, reach: float,
		color: Color, arc_deg: float = 120.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var node: SlashArc = SlashArc.new()
	node.global_position = pos
	node.configure(reach, facing, color, arc_deg)
	parent.add_child(node)


## Setea los parámetros antes de add_child. _ready() los usa para construir + animar.
func configure(p_reach: float, p_facing: int, p_color: Color, p_arc_deg: float = 120.0) -> void:
	_reach = p_reach
	_facing = -1 if p_facing < 0 else 1
	_color = p_color
	_arc_deg = p_arc_deg


func _ready() -> void:
	z_index = 3  ## sobre piso/telegraphs, a la altura del feedback de golpe
	_line = Line2D.new()
	_line.width = ARC_WIDTH
	_line.default_color = _color
	# Punta afinada para look de filo (el arco se adelgaza en las puntas).
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.width_curve = _build_taper_curve()
	add_child(_line)
	_animate()


## Curva de grosor: fina en las puntas, gruesa al medio → look de hoja.
func _build_taper_curve() -> Curve:
	var c: Curve = Curve.new()
	c.add_point(Vector2(0.0, 0.25))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1.0, 0.25))
	return c


## Animación del barrido: el arco se dibuja progresivamente (sweep) y luego hace fade.
func _animate() -> void:
	var tw: Tween = create_tween()
	# Fase 1 — barrido: interpolamos el progreso del arco de 0 a 1.
	tw.tween_method(_set_arc_progress, 0.0, 1.0, SWEEP_TIME)
	# Fase 2 — fade-out rápido tras completar el barrido.
	tw.tween_property(_line, "modulate:a", 0.0, SWEEP_TIME * 0.6)
	tw.tween_callback(queue_free)


## Reconstruye los puntos del arco hasta el progreso `t` (0..1).
## El arco va de -arc/2 a +arc/2 alrededor del eje de `facing`.
## Eje frontal: 0 rad si facing>0, PI si facing<0.
func _set_arc_progress(t: float) -> void:
	if _line == null:
		return
	var base_angle: float = 0.0 if _facing > 0 else PI
	var half: float = deg_to_rad(_arc_deg) * 0.5
	# El barrido empieza arriba (-half) y baja hasta el ángulo actual.
	var sweep_to: float = -half + t * deg_to_rad(_arc_deg)
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(ARC_POINTS):
		var frac: float = float(i) / float(ARC_POINTS - 1)
		var a: float = -half + frac * (sweep_to + half)
		var ang: float = base_angle + a
		# Achatado vertical 0.6 — el tajo se ve en perspectiva de suelo sin ser plano.
		points.append(Vector2(cos(ang) * _reach, sin(ang) * _reach * 0.6))
	_line.points = points
