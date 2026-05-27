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

## Radio del círculo en píxeles.
@export var radius: float = 40.0
## Duración en segundos antes de auto-destruirse.
@export var duration: float = 0.6
## Color base del marcador. Canal alpha usado para fade.
@export var color: Color = Color(1.0, 0.15, 0.05, 0.55)

@onready var _polygon: Polygon2D = $Polygon2D

const SIDES: int = 24  # lados del polígono. 24 = look de círculo sin coste de mesh.


func _ready() -> void:
	z_index = 2
	_build_polygon()
	_animate()


## Configura el telegraph después de add_child. Puede llamarse antes o después de _ready.
## Si se llama antes de _ready, las props @export se setean y _ready las usa.
func setup(p_radius: float, p_duration: float, p_color: Color = Color(1.0, 0.15, 0.05, 0.55)) -> void:
	radius = p_radius
	duration = p_duration
	color = p_color
	# Si _ready ya corrió (add_child antes de setup), reconstruir manualmente.
	if is_inside_tree():
		_build_polygon()
		_animate()


func _build_polygon() -> void:
	if _polygon == null:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(SIDES):
		var angle: float = (float(i) / float(SIDES)) * TAU
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.45))
	_polygon.polygon = points
	_polygon.color = color


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
