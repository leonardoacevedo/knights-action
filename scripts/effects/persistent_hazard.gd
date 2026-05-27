extends Area2D
class_name PersistentHazard

## Zona de daño persistente en piso. Permanece visible durante `duration` segundos
## y aplica `damage_per_tick` al player cada `tick_interval` mientras esté solapado.
##
## A diferencia de AoeTelegraph (puro visual sin daño), este SÍ tiene colisión.
## Usado por bosses Mage para denegación de área (Campo de Daño, Eco Eterno).
##
## Uso típico:
##   var hz: PersistentHazard = HAZARD_SCENE.instantiate()
##   hz.global_position = pos
##   hz.setup(radius=50.0, duration=4.0, damage_per_tick=5, tick_interval=0.5, team=2)
##   parent.add_child(hz)
##
## Performance mobile: VFX = Polygon2D + tween pulso. Lifetime ≤4s recomendado.
## Cap 4 instancias simultáneas en escena (regla de bosses).
##
## Limpieza automática al expirar `duration` con tween fade-out final.

## Radio del círculo de daño en píxeles.
@export var radius: float = 50.0
## Duración total en segundos antes de auto-destruirse.
@export var duration: float = 4.0
## Daño aplicado por cada tick mientras player esté dentro.
@export var damage_per_tick: int = 5
## Intervalo entre ticks de daño (segundos). Default 0.5s.
@export var tick_interval: float = 0.5
## Team del owner del hazard. 2=enemy → no daña a otros enemies.
@export var team: int = 2
## Color base del polígono (RGBA). Rojo oscuro pulsante por default.
@export var color: Color = Color(0.55, 0.05, 0.05, 0.55)

const SIDES: int = 24

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _polygon: Polygon2D = $Polygon2D

## Tiempo desde el último tick aplicado.
var _tick_timer: float = 0.0
## Tiempo total transcurrido.
var _life_timer: float = 0.0
## Set de hurtboxes actualmente solapadas (para multi-tick sin re-entrada).
var _overlapping: Array[HurtboxComponent] = []
## Flag para evitar dañar después de iniciar el fade-out.
var _expired: bool = false


func _ready() -> void:
	# Layer 4 = Hitbox (igual al hitbox de enemies). Mask 5 = detecta Hurtbox.
	# Si el caller seteó team via setup() antes de add_child, ya está OK.
	collision_layer = 0b1000
	collision_mask = 0b10000
	monitoring = true
	monitorable = false
	z_index = 1  ## sobre el piso, debajo de entidades visuales
	_build_polygon()
	_build_circle_shape()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	# Aplicar primer tick al ingresar inmediato — sino el player puede atravesar
	# en menos de tick_interval sin recibir daño.
	_tick_timer = tick_interval


## Configura el hazard antes o después de add_child.
## Si _ready ya corrió, reconstruye polígono y shape con los valores nuevos.
func setup(p_radius: float, p_duration: float, p_damage_per_tick: int,
		p_tick_interval: float = 0.5, p_team: int = 2,
		p_color: Color = Color(0.55, 0.05, 0.05, 0.55)) -> void:
	radius = p_radius
	duration = p_duration
	damage_per_tick = p_damage_per_tick
	tick_interval = p_tick_interval
	team = p_team
	color = p_color
	if is_inside_tree():
		_build_polygon()
		_build_circle_shape()


func _process(delta: float) -> void:
	if _expired:
		return
	_life_timer += delta
	if _life_timer >= duration:
		_expired = true
		_start_fadeout()
		return
	# Tick de daño: aplicar a todas las hurtboxes solapadas cada tick_interval.
	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_apply_tick_damage()
	# Pulso visual sutil (escala leve para "vivacidad").
	if _polygon != null:
		var pulse: float = 1.0 + 0.04 * sin(_life_timer * 6.0)
		_polygon.scale = Vector2(pulse, pulse)


func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hb: HurtboxComponent = area
	if hb.team == team:
		return  ## mismo team, no daño
	if _overlapping.has(hb):
		return
	_overlapping.append(hb)


func _on_area_exited(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hb: HurtboxComponent = area
	_overlapping.erase(hb)


func _apply_tick_damage() -> void:
	# Limpiar hurtboxes inválidas (entity muerta) antes de iterar.
	for i in range(_overlapping.size() - 1, -1, -1):
		var hb: HurtboxComponent = _overlapping[i]
		if not is_instance_valid(hb):
			_overlapping.remove_at(i)
			continue
		if hb.team == team:
			continue
		# Aplicar daño directo sin source HitboxComponent (es ambiental).
		# was_advantage=0 → neutral (sin tinte elemental, los hazards no tienen elemento).
		hb.receive_hit(damage_per_tick, null, 0)


## Construye el polígono visual circular.
func _build_polygon() -> void:
	if _polygon == null:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(SIDES):
		var angle: float = (float(i) / float(SIDES)) * TAU
		# Achatado vertical 0.45 igual que AoeTelegraph — mantiene look "elipse de suelo".
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.45))
	_polygon.polygon = points
	_polygon.color = color


## Construye el CircleShape2D del Area2D. La elipse visual achatada es solo cosmética;
## la colisión es un círculo real con `radius`.
func _build_circle_shape() -> void:
	if _shape == null:
		return
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle


## Fade-out final + queue_free. 0.4s para que el player vea que se desactivó.
func _start_fadeout() -> void:
	monitoring = false  ## ya no daña
	var tw: Tween = create_tween()
	tw.tween_property(_polygon, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
