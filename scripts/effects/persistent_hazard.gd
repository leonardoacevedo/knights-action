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
## Performance mobile: VFX = Polygon2D + Line2D borde + glyph + tween. Lifetime ≤4s recomendado.
## Cap 4 instancias simultáneas en escena (regla de bosses).
##
## Limpieza automática al expirar `duration` con tween fade-out final.
##
## Identidad por tipo (param `hazard_type` en setup, default GENERIC = look rojo original):
## cada tipo agrega borde animado saturado + glyph central tenue + partículas que suben,
## sobre el relleno. `color` queda como override OPCIONAL del relleno (default por tipo).

## Tipo de hazard — define preset visual (relleno/borde/glyph/partícula).
enum HazardType { GENERIC, LAVA, ICE, POISON, ARCANE }

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
## Tipo de hazard. GENERIC = comportamiento histórico (relleno rojo, borde rojo, glyph ⚠).
@export var hazard_type: int = HazardType.GENERIC

const SIDES: int = 24
## Lados del glyph runa (ARCANE). Hexágono.
const GLYPH_RUNE_SIDES: int = 6

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _polygon: Polygon2D = $Polygon2D

## Borde de peligro animado (striping). Line2D cerrado sobre la elipse.
var _border: Line2D = null
## Glyph central tenue (símbolo por tipo).
var _glyph: Polygon2D = null
## Partículas que suben (señal "activo/emanando"). Opcional.
var _particles: GPUParticles2D = null
## Si el caller pasó un color explícito en setup (override del relleno por tipo).
var _color_overridden: bool = false

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
	_apply_type_fill_default()
	_build_polygon()
	_build_circle_shape()
	_build_border()
	_build_glyph()
	_build_particles()
	_play_appear()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	# Aplicar primer tick al ingresar inmediato — sino el player puede atravesar
	# en menos de tick_interval sin recibir daño.
	_tick_timer = tick_interval


## Configura el hazard antes o después de add_child.
## Si _ready ya corrió, reconstruye polígono y shape con los valores nuevos.
## `p_hazard_type` AL FINAL con default GENERIC = comportamiento histórico (backward-compatible).
## `p_color` queda como override OPCIONAL del relleno: si se omite, se usa el preset del tipo.
func setup(p_radius: float, p_duration: float, p_damage_per_tick: int,
		p_tick_interval: float = 0.5, p_team: int = 2,
		p_color: Color = Color(0.55, 0.05, 0.05, 0.55),
		p_hazard_type: int = HazardType.GENERIC) -> void:
	radius = p_radius
	duration = p_duration
	damage_per_tick = p_damage_per_tick
	tick_interval = p_tick_interval
	team = p_team
	# Detectar si el caller pasó un color explícito (distinto del default rojo histórico).
	# Si lo pasó → override del relleno. Si no → preset por tipo.
	_color_overridden = not p_color.is_equal_approx(Color(0.55, 0.05, 0.05, 0.55))
	color = p_color
	hazard_type = p_hazard_type
	if is_inside_tree():
		_apply_type_fill_default()
		_build_polygon()
		_build_circle_shape()
		_build_border()
		_build_glyph()
		_build_particles()
		_play_appear()


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
	# Borde de peligro animado: width pulsante (striping = "zona caliente").
	# Lo más importante para comunicar peligro a bajo costo.
	if _border != null:
		_border.width = _border_base_width() * (1.0 + 0.35 * sin(_life_timer * 5.0))
	# Glyph: respira en alpha (tenue → un poco menos tenue) sin robar atención.
	if _glyph != null:
		_glyph.modulate.a = 0.22 + 0.10 * (0.5 + 0.5 * sin(_life_timer * 3.0))


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
	# Frenar emisión de partículas para que no queden "colgando" tras el fade.
	if _particles != null:
		_particles.emitting = false
	var tw: Tween = create_tween()
	tw.tween_property(_polygon, "modulate:a", 0.0, 0.4)
	# Desvanecer también las capas extra en paralelo (si existen).
	if _border != null:
		tw.parallel().tween_property(_border, "modulate:a", 0.0, 0.4)
	if _glyph != null:
		tw.parallel().tween_property(_glyph, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


# ─── Sistema de tipos: presets visuales + capas (A) aparición / (B) borde /
#     (C) glyph / (D) partículas ───────────────────────────────────────────────

## Color de relleno por defecto según tipo. Solo aplica si el caller NO pasó `color`
## explícito en setup (`_color_overridden == false`). Mantiene `color` como override.
func _apply_type_fill_default() -> void:
	if _color_overridden:
		return
	match hazard_type:
		HazardType.LAVA:   color = Color(0.55, 0.12, 0.03, 0.55)  # rojo-naranja oscuro
		HazardType.ICE:    color = Color(0.20, 0.55, 0.70, 0.50)  # cyan apagado
		HazardType.POISON: color = Color(0.20, 0.45, 0.10, 0.52)  # verde ácido oscuro
		HazardType.ARCANE: color = Color(0.35, 0.12, 0.55, 0.55)  # violeta oscuro
		_:                 color = Color(0.55, 0.05, 0.05, 0.55)  # GENERIC — rojo histórico


## Color saturado del borde por tipo (la señal de peligro principal).
func _border_color() -> Color:
	match hazard_type:
		HazardType.LAVA:   return Color(1.0, 0.45, 0.10, 0.95)   # rojo-naranja
		HazardType.ICE:    return Color(0.45, 0.90, 1.0, 0.95)    # cyan claro
		HazardType.POISON: return Color(0.55, 1.0, 0.20, 0.95)    # verde ácido
		HazardType.ARCANE: return Color(0.75, 0.45, 1.0, 0.95)    # violeta-cyan
		_:                 return Color(1.0, 0.20, 0.15, 0.95)    # GENERIC — rojo


## Color de la partícula que sube por tipo.
func _particle_color() -> Color:
	match hazard_type:
		HazardType.LAVA:   return Color(1.0, 0.55, 0.15, 0.85)   # brasas
		HazardType.ICE:    return Color(0.70, 0.95, 1.0, 0.75)    # cristales
		HazardType.POISON: return Color(0.60, 1.0, 0.30, 0.75)    # burbujas
		HazardType.ARCANE: return Color(0.80, 0.55, 1.0, 0.80)    # motas
		_:                 return Color(1.0, 0.30, 0.25, 0.75)    # GENERIC


## Grosor base del borde, escalado al radio (legible a tamaño chico sin saturar grande).
func _border_base_width() -> float:
	return clampf(radius * 0.06, 2.0, 5.0)


## (B) Borde de peligro animado: Line2D cerrado sobre la elipse. Width pulsante en _process.
func _build_border() -> void:
	if _border == null:
		_border = Line2D.new()
		_border.closed = true
		_border.joint_mode = Line2D.LINE_JOINT_ROUND
		_border.z_index = 1  ## sobre el relleno
		add_child(_border)
	_border.default_color = _border_color()
	_border.width = _border_base_width()
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(SIDES):
		var angle: float = (float(i) / float(SIDES)) * TAU
		# Mismo achatado 0.45 que el relleno → el borde calza con la elipse.
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.45))
	_border.points = points


## (C) Glyph central tenue: símbolo chico por tipo, alpha bajo, escala con radio.
## LAVA=gota · ICE=copo · POISON=calavera (rombo) · ARCANE=runa (hexágono) · GENERIC=⚠ (triángulo).
func _build_glyph() -> void:
	if _glyph == null:
		_glyph = Polygon2D.new()
		_glyph.z_index = 1  ## sobre el relleno, debajo del borde grueso
		add_child(_glyph)
	var col: Color = _border_color()
	col.a = 0.25  ## tenue — no debe competir con el borde
	_glyph.color = col
	_glyph.polygon = _build_glyph_points()


## Construye los puntos del glyph según tipo. Escala = ~28% del radio (legible chico).
func _build_glyph_points() -> PackedVector2Array:
	var s: float = radius * 0.28
	var pts: PackedVector2Array = PackedVector2Array()
	match hazard_type:
		HazardType.LAVA:
			# Gota: punta arriba + lóbulo abajo (triángulo + base redondeada simplificada).
			pts.append(Vector2(0.0, -s))
			pts.append(Vector2(s * 0.7, s * 0.4))
			pts.append(Vector2(0.0, s))
			pts.append(Vector2(-s * 0.7, s * 0.4))
		HazardType.ICE:
			# Copo: estrella de 6 puntas (hexagrama simplificado a rombo alargado vertical/horizontal).
			pts.append(Vector2(0.0, -s))
			pts.append(Vector2(s * 0.35, -s * 0.35))
			pts.append(Vector2(s, 0.0))
			pts.append(Vector2(s * 0.35, s * 0.35))
			pts.append(Vector2(0.0, s))
			pts.append(Vector2(-s * 0.35, s * 0.35))
			pts.append(Vector2(-s, 0.0))
			pts.append(Vector2(-s * 0.35, -s * 0.35))
		HazardType.POISON:
			# Calavera simplificada: rombo (lee como "tóxico/peligro" a tamaño chico).
			pts.append(Vector2(0.0, -s))
			pts.append(Vector2(s, 0.0))
			pts.append(Vector2(0.0, s))
			pts.append(Vector2(-s, 0.0))
		HazardType.ARCANE:
			# Runa: hexágono.
			for i in range(GLYPH_RUNE_SIDES):
				var a: float = (float(i) / float(GLYPH_RUNE_SIDES)) * TAU - PI * 0.5
				pts.append(Vector2(cos(a) * s, sin(a) * s))
		_:
			# GENERIC ⚠: triángulo de advertencia (punta arriba).
			pts.append(Vector2(0.0, -s))
			pts.append(Vector2(s * 0.9, s * 0.8))
			pts.append(Vector2(-s * 0.9, s * 0.8))
	return pts


## (D) Partículas que SUBEN (gravity negativa) — señal universal de "activo/emanando".
## GPUParticles2D amount ≤8 (mobile-friendly). Color por tipo.
func _build_particles() -> void:
	if _particles == null:
		_particles = GPUParticles2D.new()
		_particles.z_index = 2  ## sobre todo lo demás del hazard
		add_child(_particles)
	_particles.amount = 8  ## cap mobile
	_particles.lifetime = 1.2
	_particles.preprocess = 0.3
	_particles.local_coords = false
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = radius * 0.6
	mat.direction = Vector3(0.0, -1.0, 0.0)  ## hacia arriba
	mat.spread = 15.0
	mat.gravity = Vector3(0.0, -40.0, 0.0)   ## gravedad negativa = suben
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 28.0
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = _particle_color()
	_particles.process_material = mat
	_particles.emitting = true


## (A) Aparición animada ~0.3s: escala 0.2→1.0 + alpha 0→target. Nunca instantáneo.
## Anima el nodo entero (afecta relleno, borde, glyph y partículas a la vez).
func _play_appear() -> void:
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
