extends Area2D
class_name Projectile

## Proyectil lanzado por Archer/Mage o el player (con arco/vara).
## Movimiento lineal en dirección fija. Lifetime para auto-cleanup.
## Choca con HurtboxComponent de team distinto y aplica daño.

## Emitido al conectar contra un HurtboxComponent enemigo (después de aplicar daño).
## El shooter (player con arco/vara) lo escucha para ganar Furia / Momentum.
signal hit_landed(target_hurtbox: HurtboxComponent)

@export var speed: float = 600.0
@export var lifetime: float = 2.0

# Seteados por launch() al instanciar.
var damage: int = 10
var team: int = 0
## Elemento del atacante (del shooter). Propagado al receive_hit para el modifier elemental.
## Usar valores de ItemData.Element: NEUTRO=0, FUEGO=1, AGUA=2, TIERRA=3.
var element: int = 0  # ItemData.Element.NEUTRO

var _direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0

# ── AoE on impact (Mage R1: Orbe Flamígero) ──────────────────────────────────
## Activar con enable_aoe_on_impact() antes de add_child al árbol.
## Al impactar (o expirar lifetime), spawna AoeTelegraph + aplica daño radial.
var aoe_on_impact: bool = false
var aoe_radius: float = 35.0
var aoe_damage_pct: float = 0.6
var aoe_telegraph_duration: float = 0.4
## Escena de AoeTelegraph a instanciar. Se asigna desde el caller vía preload.
var aoe_telegraph_scene: PackedScene = null

# ── Pierce (Archer R1: Flecha Perforante) ────────────────────────────────────
## Si true, el proyectil NO se destruye al impactar enemies hasta que pierce_count llegue a 0.
## Sigue destruyéndose al tocar el piso (WorldBody) o al expirar lifetime.
var pierce_enemies: bool = false
var pierce_count: int = 3
## Set interno para no golpear la misma hurtbox dos veces en el mismo vuelo.
var _pierce_hit_set: Array = []
## Line2D de estela (opcional). Se agrega como child del parent cuando se activa pierce.
var _pierce_trail: Line2D = null


func _ready() -> void:
	# Mismas layers que Hitbox: nosotros somos un "hitbox volador".
	collision_layer = 0b1000     # bit 4 (Hitbox)
	collision_mask = 0b10000     # bit 5 (detecta Hurtbox)
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	# Trail de estela para flechas perforadoras. Se construye después de entrar al árbol
	# porque necesitamos add_child al current_scene (coordenadas globales).
	if pierce_enemies:
		call_deferred("_build_pierce_trail")


## Inicializa el proyectil con dirección, daño, team y elemento del shooter.
## Llamar inmediatamente después de instanciarlo, antes de add_child.
func launch(direction: Vector2, damage_amount: int, team_id: int, attacker_element: int = 0) -> void:
	if direction.length_squared() == 0.0:
		_direction = Vector2.RIGHT
	else:
		_direction = direction.normalized()
	damage = damage_amount
	team = team_id
	element = attacker_element
	rotation = _direction.angle()


## Activa el modo AoE on-impact. Llamar antes de add_child al árbol.
## radius: radio del daño radial (px). damage_pct: fracción del damage original (0-1).
## telegraph_duration: duración del marcador visual antes de que el AoE suceda (s).
## scene: PackedScene del AoeTelegraph. Si null, intenta cargar desde res://.
func enable_aoe_on_impact(p_radius: float, p_damage_pct: float,
		p_telegraph_duration: float, scene: PackedScene = null) -> void:
	aoe_on_impact = true
	aoe_radius = p_radius
	aoe_damage_pct = p_damage_pct
	aoe_telegraph_duration = p_telegraph_duration
	if scene != null:
		aoe_telegraph_scene = scene
	else:
		aoe_telegraph_scene = load("res://scenes/effects/aoe_telegraph.tscn")


func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	_time_alive += delta
	# Actualizar trail de estela (pierce). Trail vive en current_scene — usa global_position.
	if pierce_enemies and _pierce_trail != null and is_instance_valid(_pierce_trail):
		_pierce_trail.add_point(global_position)
		# Máximo 12 puntos — rastro corto, suficiente para feel visual.
		if _pierce_trail.get_point_count() > 12:
			_pierce_trail.remove_point(0)
	if _time_alive >= lifetime:
		if aoe_on_impact:
			_trigger_aoe(global_position)
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox: HurtboxComponent = area
	if hurtbox.team == team:
		return  # mismo team, no daño
	# Pierce: evitar re-golpear la misma hurtbox.
	if pierce_enemies and _pierce_hit_set.has(hurtbox):
		return
	# Cálculo elemental: modifier según triángulo GDD §5.3.
	var elem_mult: float = GameConfig.element_modifier(element, hurtbox.element)
	var final_damage: int = int(round(float(damage) * elem_mult))
	var was_advantage: int = 0
	if elem_mult > 1.0:
		was_advantage = 1
	elif elem_mult < 1.0:
		was_advantage = -1
	hurtbox.receive_hit(final_damage, null, was_advantage)
	hit_landed.emit(hurtbox)

	# ── Modo Pierce ─────────────────────────────────────────────────────────
	if pierce_enemies:
		_pierce_hit_set.append(hurtbox)
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()
		# Si quedan penetraciones, NO queue_free — el proyectil sigue.
		return

	# ── Impacto normal ───────────────────────────────────────────────────────
	if aoe_on_impact:
		_trigger_aoe(global_position)
	queue_free()


## Spawna el AoeTelegraph en `pos` y programa el daño radial tras `aoe_telegraph_duration`.
func _trigger_aoe(pos: Vector2) -> void:
	if aoe_telegraph_scene == null:
		aoe_telegraph_scene = load("res://scenes/effects/aoe_telegraph.tscn")
	if aoe_telegraph_scene == null:
		return
	# Necesitamos un parent válido para agregar el telegraph.
	var parent: Node = get_tree().current_scene if is_inside_tree() else null
	if parent == null:
		return
	var tele: Node2D = aoe_telegraph_scene.instantiate()
	tele.global_position = pos
	# Setear props ANTES de add_child para que _ready() los use directamente.
	if tele.has_method("setup"):
		tele.call("setup", aoe_radius, aoe_telegraph_duration, Color(1.0, 0.45, 0.05, 0.6))
	else:
		tele.set("radius", aoe_radius)
		tele.set("duration", aoe_telegraph_duration)
	parent.add_child(tele)
	# Daño radial se aplica después del telegraph (Timer de un solo uso).
	var aoe_dmg: int = int(round(float(damage) * aoe_damage_pct))
	var aoe_team: int = team
	var aoe_elem: int = element
	var aoe_r: float = aoe_radius
	var aoe_pos: Vector2 = pos
	var timer: SceneTreeTimer = get_tree().create_timer(aoe_telegraph_duration)
	# Llama al static via clase explícita para no capturar self (el proyectil puede destruirse antes).
	timer.timeout.connect(func() -> void:
		Projectile._apply_aoe_damage(aoe_pos, aoe_r, aoe_dmg, aoe_team, aoe_elem)
	)


## Aplica daño radial a todos los hurtboxes del equipo contrario dentro de `radius`.
## Usa distance_to (más liviano que intersect_shape para radio tan chico).
static func _apply_aoe_damage(pos: Vector2, radius: float, dmg: int,
		src_team: int, src_elem: int) -> void:
	var scene: SceneTree = Engine.get_main_loop() as SceneTree
	if scene == null:
		return
	var hurtboxes: Array = scene.get_nodes_in_group("hurtbox")
	for h in hurtboxes:
		if not h is HurtboxComponent:
			continue
		var hb: HurtboxComponent = h as HurtboxComponent
		if hb.team == src_team:
			continue  # no dañar aliados
		if not is_instance_valid(hb):
			continue
		if hb.global_position.distance_to(pos) <= radius:
			var elem_mult: float = GameConfig.element_modifier(src_elem, hb.element)
			var final_dmg: int = int(round(float(dmg) * elem_mult))
			hb.receive_hit(final_dmg, null, 0)


## Construye la Line2D del trail para flechas perforadoras.
## Se agrega a current_scene (no al proyectil) para que los puntos sean en global space.
## La Line2D se limpia cuando el proyectil muere (en queue_free via tree_exiting).
func _build_pierce_trail() -> void:
	if not is_inside_tree():
		return
	_pierce_trail = Line2D.new()
	_pierce_trail.width = 2.5
	_pierce_trail.default_color = Color(0.85, 0.95, 0.4, 0.75)
	_pierce_trail.z_index = 1
	get_tree().current_scene.add_child(_pierce_trail)
	# Limpiar trail cuando el proyectil se destruye.
	tree_exiting.connect(_on_trail_cleanup)


## Fade-out y cleanup del trail al destruir el proyectil.
func _on_trail_cleanup() -> void:
	if _pierce_trail == null or not is_instance_valid(_pierce_trail):
		return
	var tween: Tween = _pierce_trail.create_tween()
	tween.tween_property(_pierce_trail, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_pierce_trail.queue_free)
