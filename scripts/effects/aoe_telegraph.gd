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

const SIDES: int = 24  # lados del polígono. 24 = look de círculo sin coste de mesh.
const CONE_SEGMENTS: int = 12  # segmentos del arco del cono. Suficiente para look suave.


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
	match shape_type:
		TelegraphShape.CONE:
			_polygon.polygon = _build_cone_points()
		TelegraphShape.LINE:
			_polygon.polygon = _build_line_points()
		_:
			_polygon.polygon = _build_circle_points()
	_polygon.color = color


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
	# Fade-out en el último 30%.
	tween.parallel().tween_property(_polygon, "modulate:a", 0.0, duration * 0.3) \
		.set_delay(duration * 0.7)
	# Auto-destruir al expirar.
	tween.tween_callback(queue_free)
