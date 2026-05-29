extends Node2D
class_name AoeTelegraph

## Marcador visual de AoE en el suelo. PURO visual — sin colisión ni daño.
##
## Uso (orden correcto para que _ready use los valores correctos):
##   var tele = AoeTelegraphScene.instantiate()
##   tele.global_position = hit_point
##   tele.setup(radius, duration, color)   ← ANTES de add_child
##   parent.add_child(tele)                ← _ready() corre con los valores ya seteados
##
## Se auto-destruye al expirar `duration`. El caller no necesita guardar referencia.
##
## Reutilizable por: Orbe Flamígero (Mage R1), Salto de Asalto (Guerrero R2),
##   Nova de Hielo (Mage R2), Erupción Terrestre (Mage R3 set C), etc.
##
## Performance mobile: Polygon2D estático + tween. Sin GPUParticles2D.
## Lifetime máx recomendado: ≤1.5s. z_index=2 (sobre piso, debajo de entidades).
##
## Soporta 3 formas (param `shape_type` en setup, default CIRCLE = comportamiento original):
##   CIRCLE — elipse achatada de suelo (default histórico).
##   CONE   — sector frontal orientado por `facing` con apertura `arc_deg` (Duelista Llamarada).
##   LINE   — franja/rectángulo frontal de largo `length`, orientado por `facing` (Lyss Látigo).

## Formas de telegraph disponibles.
enum TelegraphShape { CIRCLE, CONE, LINE }

## Radio del círculo en píxeles. En CONE = radio del sector. En LINE = semi-ancho de la franja.
@export var radius: float = 40.0
## Duración en segundos antes de auto-destruirse.
@export var duration: float = 0.6
## Color base del marcador. Canal alpha usado para fade.
@export var color: Color = Color(1.0, 0.15, 0.05, 0.55)
## Forma del telegraph. CIRCLE = default histórico (elipse de suelo).
@export var shape_type: int = TelegraphShape.CIRCLE
## Apertura del cono en grados (solo CONE). No afecta CIRCLE ni LINE.
@export var arc_deg: float = 90.0
## Largo de la franja en píxeles (solo LINE). No afecta CIRCLE ni CONE.
@export var length: float = 200.0
## Dirección de encaramiento en radianes (CONE/LINE). 0 = derecha. No afecta CIRCLE.
@export var facing: float = 0.0

@onready var _polygon: Polygon2D = $Polygon2D
## Borde de peligro animado. Se construye por código (no está en el .tscn) y sigue
## el contorno de la forma. Pulsa width+alpha conforme se acerca la detonación → el ojo
## lo lee como "zona caliente". Es lo que más comunica peligro a bajo costo (1 Line2D).
var _danger_edge: Line2D = null

const SIDES: int = 24  # lados del polígono. 24 = look de círculo sin coste de mesh.
const CONE_SEGMENTS: int = 12  # segmentos del arco del cono. Suficiente para look suave.
const EDGE_WIDTH_BASE: float = 2.5  # grosor base del borde de peligro (px).
const EDGE_WIDTH_PULSE: float = 3.5  # grosor pico durante el parpadeo (px). Sumado al base.


func _ready() -> void:
	z_index = 2
	_build_polygon()
	_animate()


## Configura el telegraph después de add_child. Puede llamarse antes o después de _ready.
## Si se llama antes de _ready, las props @export se setean y _ready las usa.
## Params de forma al FINAL con defaults = comportamiento CIRCLE original (backward-compatible):
##   p_shape: CIRCLE (default) / CONE / LINE.
##   p_arc_deg: apertura del cono (solo CONE).
##   p_length: largo de la franja (solo LINE).
##   p_facing: encaramiento en radianes (CONE/LINE).
func setup(p_radius: float, p_duration: float, p_color: Color = Color(1.0, 0.15, 0.05, 0.55),
		p_shape: int = TelegraphShape.CIRCLE, p_arc_deg: float = 90.0,
		p_length: float = 200.0, p_facing: float = 0.0) -> void:
	radius = p_radius
	duration = p_duration
	color = p_color
	shape_type = p_shape
	arc_deg = p_arc_deg
	length = p_length
	facing = p_facing
	# Si _ready ya corrió (add_child antes de setup), reconstruir manualmente.
	if is_inside_tree():
		_build_polygon()
		_animate()


func _build_polygon() -> void:
	if _polygon == null:
		return
	# Puntos del contorno: se calculan UNA vez y se reutilizan para relleno + borde.
	var points: PackedVector2Array
	match shape_type:
		TelegraphShape.CONE:
			points = _build_cone_points()
		TelegraphShape.LINE:
			points = _build_line_points()
		_:
			points = _build_circle_points()
	_polygon.polygon = points
	_polygon.color = color
	_build_danger_edge(points)


## Construye/actualiza el Line2D del borde de peligro reutilizando los mismos puntos
## del relleno. Cierra el contorno (último→primer punto) para que el striping rodee la zona.
## En CONE no se cierra de vuelta al ápice (0,0): solo se marca el frente del arco, que es
## el filo peligroso real — la línea recta hacia el ápice ensuciaría la lectura.
func _build_danger_edge(points: PackedVector2Array) -> void:
	if _polygon == null:
		return
	if _danger_edge == null:
		_danger_edge = Line2D.new()
		_danger_edge.joint_mode = Line2D.LINE_JOINT_ROUND
		_danger_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_danger_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		_danger_edge.z_index = 1  # sobre el relleno del polígono (que va en z_index 0 local).
		add_child(_danger_edge)
	_danger_edge.width = EDGE_WIDTH_BASE
	# Color del borde = matiz del relleno pero saturado y opaco (lee como "filo caliente").
	_danger_edge.default_color = _edge_color_from(color)
	var edge_points: PackedVector2Array = points
	if shape_type == TelegraphShape.CONE:
		# El primer punto es el ápice; saltarlo para marcar solo el arco frontal.
		edge_points = points.slice(1)
	else:
		# CIRCLE/LINE: cerrar el contorno repitiendo el primer punto.
		if edge_points.size() > 0:
			edge_points = edge_points.duplicate()
			edge_points.append(edge_points[0])
	_danger_edge.points = edge_points


## Deriva el color del borde a partir del color de relleno: empuja saturación/brillo y
## fuerza alpha alto. Mantiene el matiz (hielo cyan / fuego naranja / arcano violeta…)
## pero lo vuelve un filo nítido en vez de una mancha translúcida.
func _edge_color_from(fill: Color) -> Color:
	var edge: Color = fill
	edge.s = clampf(fill.s * 1.25 + 0.15, 0.0, 1.0)
	edge.v = clampf(fill.v * 1.1 + 0.2, 0.0, 1.0)
	edge.a = 1.0
	return edge


## Elipse de suelo achatada (forma histórica). Vértice por lado en TAU.
func _build_circle_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(SIDES):
		var angle: float = (float(i) / float(SIDES)) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.45))
	return points


## Sector frontal: ápice en (0,0) + arco de `arc_deg` centrado en `facing`.
## Achatado vertical 0.45 igual que el círculo para mantener look "de suelo".
func _build_cone_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)  # ápice del cono (origen del lanzador)
	var half: float = deg_to_rad(arc_deg) * 0.5
	var start: float = facing - half
	for i in range(CONE_SEGMENTS + 1):
		var t: float = float(i) / float(CONE_SEGMENTS)
		var a: float = start + t * deg_to_rad(arc_deg)
		points.append(Vector2(cos(a) * radius, sin(a) * radius * 0.45))
	return points


## Franja/rectángulo frontal de `length` de largo y `radius` de semi-ancho,
## orientado según `facing`. Pensado para hitbox lineal (Lyss Látigo, Vael Lanza).
func _build_line_points() -> PackedVector2Array:
	var fwd: Vector2 = Vector2(cos(facing), sin(facing))
	# Perpendicular achatada en Y (look de suelo, consistente con círculo/cono).
	var perp: Vector2 = Vector2(-fwd.y, fwd.x * 0.45) * radius
	var tip: Vector2 = fwd * length
	var points: PackedVector2Array = PackedVector2Array()
	points.append(-perp)        # esquina trasera-izq
	points.append(tip - perp)   # esquina delantera-izq
	points.append(tip + perp)   # esquina delantera-der
	points.append(perp)         # esquina trasera-der
	return points


func _animate() -> void:
	# Pulso sutil: crece 5% y luego fade-out en el último 30% del lifetime.
	_polygon.scale = Vector2.ONE
	_polygon.modulate.a = 1.0

	var tween: Tween = create_tween()
	# Crece levemente durante el telegraph (feedback de "carga").
	tween.tween_property(_polygon, "scale", Vector2(1.06, 1.06), duration * 0.7)
	# Intensificación temporal del relleno: de tenue → saturado durante el windup.
	# Comunica "ya va a pasar" sin tocar la forma. Corre en paralelo al crecimiento.
	# Conserva el alpha original del relleno (sigue siendo un tinte de suelo, no opaco):
	# el filo opaco lo aporta el borde de peligro, no el relleno.
	var intense: Color = _edge_color_from(color)
	intense.a = color.a
	tween.parallel().tween_property(_polygon, "color", intense, duration * 0.7) \
		.from(color)
	# Fade-out en el último 30%.
	tween.parallel().tween_property(_polygon, "modulate:a", 0.0, duration * 0.3) \
		.set_delay(duration * 0.7)
	# Auto-destruir al expirar.
	tween.tween_callback(queue_free)

	_animate_danger_edge()


## Anima el borde de peligro: parpadeo creciente (width+alpha) que se ACELERA conforme
## se acerca la detonación. Pocos pulsos lentos al inicio → muchos rápidos e intensos al
## final = striping que el ojo lee como "peligro inminente acá". Liviano: tween sobre 1 Line2D.
func _animate_danger_edge() -> void:
	if _danger_edge == null:
		return
	_danger_edge.modulate.a = 0.5  # arranca tenue
	# Cantidad de parpadeos en función del lifetime (acotado para mobile: ≤7).
	var pulses: int = clampi(int(round(duration / 0.12)), 2, 7)
	var tween: Tween = create_tween()
	for i in range(pulses):
		# t avanza 0→1 a lo largo del windup; cada pulso es más corto (acelera) y más fuerte.
		var t: float = float(i) / float(pulses)
		var seg: float = (duration * 0.85) / float(pulses) * (1.0 - t * 0.5)
		var intensity: float = 0.4 + t * 0.6  # 0.4 → 1.0
		var up: float = seg * 0.55
		var down: float = seg - up
		# Subida del pulso: engorda y se opaca.
		tween.tween_property(_danger_edge, "width",
			EDGE_WIDTH_BASE + EDGE_WIDTH_PULSE * intensity, up).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(_danger_edge, "modulate:a",
			0.6 + 0.4 * intensity, up)
		# Bajada del pulso (no baja del todo al final → queda encendido).
		tween.tween_property(_danger_edge, "width",
			EDGE_WIDTH_BASE + EDGE_WIDTH_PULSE * t * 0.4, down).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(_danger_edge, "modulate:a",
			0.5 + 0.3 * t, down)
	# Acompaña el fade-out del relleno en el cierre.
	tween.tween_property(_danger_edge, "modulate:a", 0.0, duration * 0.15)
