extends Node

## Autoload — gestiona las skills activas del jugador. GDD §4.3.
##
## Slots equipados (3) + ejecución validada (Furia ≥ costo, CD listo).
## Wireado:
##  - Player.gd._ready() → PlayerSkillSystem.register_player(self)
##  - Input binding (slot 1/2/3) → PlayerSkillSystem.try_use(slot) [pendiente input action en project.godot]
##  - UI: connect a `skill_used / cooldown_started / slot_equipped` para chips.
##
## Persistencia: equipped IDs en SaveSystem (pendiente — wire en sesión UI).

signal skill_used(slot: int, data: PlayerSkillData)
signal cooldown_started(slot: int, cooldown: float)
signal slot_equipped(slot: int, data: PlayerSkillData)
signal skill_failed(slot: int, reason: StringName)  ## &"no_furia", &"cooldown", &"empty_slot"

const MAX_SLOTS: int = 3

var _slots: Array[PlayerSkillData] = [null, null, null]
var _cooldowns: Array[float] = [0.0, 0.0, 0.0]
var _player: Node = null

## Status berserker para BUFF_DAMAGE. Preload en _ready para no acoplar con player.gd.
var _status_berserker: StatusEffectData


func _ready() -> void:
	# Crear un StatusEffectData berserker en runtime (no merece .tres separada hasta
	# que haya múltiples skills BUFF_DAMAGE). Magnitude/duration vienen del PlayerSkillData.
	_status_berserker = StatusEffectData.new()
	_status_berserker.id = &"berserker"
	_status_berserker.duration = 5.0
	_status_berserker.magnitude = 0.30
	_status_berserker.stack_mode = StatusEffectData.StackMode.REFRESH
	_status_berserker.magnitude_policy = StatusEffectData.MagnitudePolicy.KEEP_MAX
	_status_berserker.display_name = "Berserker"


func _process(delta: float) -> void:
	for i in range(MAX_SLOTS):
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = max(0.0, _cooldowns[i] - delta)


## API para Player.gd. Inyección — no buscamos por grupo para tests aislados.
func register_player(player: Node) -> void:
	_player = player


func unregister_player(player: Node) -> void:
	if _player == player:
		_player = null
		_reset_state()


func equip(slot: int, data: PlayerSkillData) -> void:
	if not _is_valid_slot(slot):
		return
	_slots[slot] = data
	_cooldowns[slot] = 0.0
	slot_equipped.emit(slot, data)


func unequip(slot: int) -> void:
	if not _is_valid_slot(slot):
		return
	_slots[slot] = null
	_cooldowns[slot] = 0.0
	slot_equipped.emit(slot, null)


func get_equipped(slot: int) -> PlayerSkillData:
	if not _is_valid_slot(slot):
		return null
	return _slots[slot]


func get_cooldown(slot: int) -> float:
	if not _is_valid_slot(slot):
		return 0.0
	return _cooldowns[slot]


func can_use(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	var data: PlayerSkillData = _slots[slot]
	if data == null:
		return false
	if _cooldowns[slot] > 0.0:
		return false
	if _player == null:
		return false
	if _player.has_node("FuriaComponent"):
		var f: FuriaComponent = _player.get_node("FuriaComponent")
		return f.get_current() >= data.cost_furia
	return false


## Intenta ejecutar la skill del slot. Retorna true si se ejecutó, false si falló.
## Emite `skill_failed` con razón si no procede.
func try_use(slot: int) -> bool:
	if not _is_valid_slot(slot):
		skill_failed.emit(slot, &"invalid_slot")
		return false
	var data: PlayerSkillData = _slots[slot]
	if data == null:
		skill_failed.emit(slot, &"empty_slot")
		return false
	if _cooldowns[slot] > 0.0:
		skill_failed.emit(slot, &"cooldown")
		return false
	if _player == null:
		skill_failed.emit(slot, &"no_player")
		return false
	var f: FuriaComponent = _player.get_node_or_null("FuriaComponent") as FuriaComponent
	if f == null or not f.try_spend(data.cost_furia):
		skill_failed.emit(slot, &"no_furia")
		return false

	_execute(data)
	_cooldowns[slot] = data.cooldown
	skill_used.emit(slot, data)
	cooldown_started.emit(slot, data.cooldown)
	return true


## API para tests / debug — saltea validación de furia/CD.
func force_execute(data: PlayerSkillData) -> void:
	if data == null:
		return
	_execute(data)


# ─── Ejecución por tipo de efecto ─────────────────────────────────────────────

func _execute(data: PlayerSkillData) -> void:
	match data.effect_type:
		PlayerSkillData.EffectType.HEAL:
			_execute_heal(data)
		PlayerSkillData.EffectType.BUFF_DAMAGE:
			_execute_buff_damage(data)
		PlayerSkillData.EffectType.AOE_DAMAGE:
			_execute_aoe_damage(data)
		PlayerSkillData.EffectType.AOE_BURN:
			_execute_aoe_burn(data)
		PlayerSkillData.EffectType.DASH_FORWARD:
			_execute_dash_forward(data)
		PlayerSkillData.EffectType.SPAWN_PROJECTILE:
			_execute_spawn_projectile(data)
		PlayerSkillData.EffectType.GAIN_SHIELD:
			_execute_gain_shield(data)
		PlayerSkillData.EffectType.INVIS:
			_execute_invis(data)
		PlayerSkillData.EffectType.APPLY_SLOW_AOE:
			_execute_apply_slow_aoe(data)


func _execute_heal(data: PlayerSkillData) -> void:
	var h: HealthComponent = _player.get_node_or_null("HealthComponent") as HealthComponent
	if h == null:
		return
	var pct: float = float(data.params.get("heal_pct", 0.30))
	var amount: int = int(round(float(h.max_health) * pct))
	h.heal(amount)
	_spawn_skill_vfx_heal()


func _execute_buff_damage(data: PlayerSkillData) -> void:
	if _player == null or _player.get("status_effects") == null:
		return
	var mag: float = float(data.params.get("magnitude", 0.30))
	var dur: float = float(data.params.get("duration", 5.0))
	_player.status_effects.apply(_status_berserker, _player, mag, dur)
	_spawn_skill_vfx_buff_damage(dur)


func _execute_aoe_damage(data: PlayerSkillData) -> void:
	var radius: float = float(data.params.get("radius", 100.0))
	var damage: int = int(data.params.get("damage", 25))
	_apply_aoe(radius, damage, null, 0.0, 0.0)
	_spawn_skill_vfx_aoe(radius, Color(1.0, 0.85, 0.3, 0.9), false)


func _execute_aoe_burn(data: PlayerSkillData) -> void:
	var radius: float = float(data.params.get("radius", 100.0))
	var damage: int = int(data.params.get("damage", 15))
	var burn_dur: float = float(data.params.get("burn_duration", 3.0))
	var burn_tick: float = float(data.params.get("burn_damage", 3.0))
	# BURN data lo cargamos del catálogo común del player.
	var burn_data: StatusEffectData = _get_burn_data()
	_apply_aoe(radius, damage, burn_data, burn_tick, burn_dur)
	_spawn_skill_vfx_aoe(radius, Color(1.0, 0.45, 0.15, 0.95), true)


func _execute_dash_forward(data: PlayerSkillData) -> void:
	# Reutilizar DashComponent del player si está disponible. Sin DashComponent
	# directo, push de velocity como fallback. Damage mult va al status temporal.
	var dist: float = float(data.params.get("distance", 200.0))
	var mult: float = float(data.params.get("damage_mult", 1.5))
	var facing: int = _player.get("current_facing") if _player.get("current_facing") != null else 1
	if _player.has_method("apply_external_velocity"):
		var push: float = dist * 4.0  # impulso instantáneo, se decae con friction
		_player.apply_external_velocity(Vector2(float(facing) * push, 0.0))
	# Buff de daño temporal para el próximo swing.
	if _player.get("status_effects") != null:
		_player.status_effects.apply(_status_berserker, _player, mult - 1.0, 0.4)
	_spawn_skill_vfx_dash(facing, dist)


func _execute_spawn_projectile(data: PlayerSkillData) -> void:
	var scene_path: String = String(data.params.get("scene_path", \
		"res://scenes/projectiles/projectile_fireball.tscn"))
	var dmg_mult: float = float(data.params.get("damage_mult", 1.5))
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		return
	var proj: Projectile = scene.instantiate() as Projectile
	if proj == null:
		return
	var facing: int = _player.get("current_facing") if _player.get("current_facing") != null else 1
	proj.global_position = _player.global_position + Vector2(20.0 * facing, -45.0)
	var hb: HitboxComponent = _player.get_node_or_null("Hitbox") as HitboxComponent
	var base_dmg: int = hb.damage if hb != null else 10
	var final_dmg: int = int(round(float(base_dmg) * dmg_mult))
	var elem: int = hb.element if hb != null else 0
	proj.launch(Vector2(facing, 0.0), final_dmg, 1, elem)
	proj.set_source(_player)  # LUZ vampire heal tracking
	_player.get_tree().current_scene.add_child(proj)
	_spawn_skill_vfx_muzzle_flash(facing)


func _execute_gain_shield(data: PlayerSkillData) -> void:
	var s: ShieldComponent = _player.get_node_or_null("ShieldComponent") as ShieldComponent
	if s == null:
		return
	var charges: int = int(data.params.get("charges", 2))
	var duration: float = float(data.params.get("duration", 8.0))
	if s.has_method("add_temporary_charges"):
		s.add_temporary_charges(charges, duration)
	else:
		s.restore_all()  # fallback defensivo
	_spawn_skill_vfx_shield(duration)


func _execute_invis(data: PlayerSkillData) -> void:
	# Reutiliza el status &"post_dash_invis" del player — mismas mecánicas.
	if _player == null or _player.get("status_effects") == null:
		return
	var dur: float = float(data.params.get("duration", 2.0))
	# Carga el .tres directo para que stack_mode/policy queden idénticos a Sombra del Valle.
	var invis: StatusEffectData = load("res://resources/status_effects/post_dash_invis.tres")
	if invis != null:
		_player.status_effects.apply(invis, _player, NAN, dur)
	_spawn_skill_vfx_shadow_wisp()


func _execute_apply_slow_aoe(data: PlayerSkillData) -> void:
	var radius: float = float(data.params.get("radius", 120.0))
	var slow_mult: float = float(data.params.get("slow_mult", 0.5))
	var slow_dur: float = float(data.params.get("slow_duration", 2.0))
	var slow_data: StatusEffectData = load("res://resources/status_effects/slow.tres")
	if slow_data == null:
		return
	for hb: HurtboxComponent in _iter_hurtboxes_in_radius(radius):
		var owner_node: Node = hb.get_parent()
		if owner_node == null:
			continue
		# Solo enemies (team != player).
		if hb.team == 1:
			continue
		# Buscar status_effects en el enemy (instanciado en enemy._ready).
		var se: StatusEffectComponent = owner_node.get("status_effects") as StatusEffectComponent
		if se != null:
			se.apply(slow_data, _player, slow_mult, slow_dur)
	_spawn_skill_vfx_aoe(radius, Color(0.5, 0.85, 1.0, 0.85), false)


# ─── Helpers compartidos ──────────────────────────────────────────────────────

## AoE radial: aplica `damage` directo + opcionalmente status DOT (burn/poison).
func _apply_aoe(radius: float, damage: int, status_data: StatusEffectData, \
		status_magnitude: float, status_duration: float) -> void:
	for hb: HurtboxComponent in _iter_hurtboxes_in_radius(radius):
		if hb.team == 1:
			continue
		if damage > 0:
			hb.receive_hit(damage, null, 0)
		if status_data != null and status_duration > 0.0:
			var se: StatusEffectComponent = hb.get_parent().get("status_effects") as StatusEffectComponent
			if se != null:
				se.apply(status_data, _player, status_magnitude, status_duration)


func _iter_hurtboxes_in_radius(radius: float) -> Array[HurtboxComponent]:
	var found: Array[HurtboxComponent] = []
	if _player == null:
		return found
	var space_state: PhysicsDirectSpaceState2D = _player.get_world_2d().direct_space_state
	if space_state == null:
		return found
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	query.shape = circle
	query.transform = Transform2D(0.0, _player.global_position)
	query.collision_mask = 0b10000  # bit 5 = HurtboxComponent layer
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 32)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is HurtboxComponent:
			found.append(collider as HurtboxComponent)
	return found


func _get_burn_data() -> StatusEffectData:
	return load("res://resources/status_effects/burn.tres") as StatusEffectData


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < MAX_SLOTS


func _reset_state() -> void:
	for i in range(MAX_SLOTS):
		_cooldowns[i] = 0.0


# ─── Persistencia (SaveSystem) ────────────────────────────────────────────────

## Estructura: { "slots": [id_str | null × MAX_SLOTS] }. CDs no se persisten —
## arrancar con CDs en 0 al cargar tiene mejor feel que "ya gasté".
func _serialize_state() -> Dictionary:
	var slots: Array = []
	for i in range(MAX_SLOTS):
		var d: PlayerSkillData = _slots[i]
		slots.append(String(d.id) if d != null else null)
	return {"slots": slots}


## Restaura loadout desde Dictionary serializado. IDs missing → slot null.
func _restore_state(data: Dictionary) -> void:
	var slots: Array = data.get("slots", [])
	for i in range(MAX_SLOTS):
		if i >= slots.size():
			break
		var entry = slots[i]
		if entry == null or String(entry).is_empty():
			unequip(i)
			continue
		var path: String = "res://resources/player_skills/%s.tres" % String(entry)
		var skill: PlayerSkillData = load(path) as PlayerSkillData
		if skill != null:
			equip(i, skill)
		else:
			push_warning("PlayerSkillSystem._restore_state: skill '%s' no encontrada en '%s'" % [entry, path])
			unequip(i)


# ─── VFX spawners ────────────────────────────────────────────────────────────
# Cada VFX se ancla a la posición global del player en el momento del cast.
# Se libera solo via Tween + queue_free para no requerir cleanup externo.

func _vfx_scene_root() -> Node:
	if _player == null:
		return null
	return _player.get_tree().current_scene


## Helper: anillo expansivo (Line2D cerrado) que escala y fade.
func _spawn_expanding_ring(pos: Vector2, color: Color, target_radius: float, duration: float, width: float = 4.0) -> void:
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var holder: Node2D = Node2D.new()
	holder.global_position = pos
	holder.z_index = 5
	root.add_child(holder)
	var ring: Line2D = Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.closed = true
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 32
	var base_r: float = 8.0
	for i in range(segs):
		var ang: float = i * TAU / float(segs)
		pts.append(Vector2(cos(ang), sin(ang)) * base_r)
	ring.points = pts
	holder.add_child(ring)
	var scale_target: float = target_radius / base_r
	var tween: Tween = root.create_tween().set_parallel(true)
	tween.tween_property(holder, "scale", Vector2(scale_target, scale_target), duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(holder):
			holder.queue_free()
	)


## Helper: burst de GPUParticles2D one-shot. Se auto-destruye tras lifetime.
func _spawn_particle_burst(pos: Vector2, color: Color, amount: int, lifetime: float,
		velocity_min: float, velocity_max: float, gravity_y: float, spread: float = 180.0,
		direction: Vector3 = Vector3(0, -1, 0), z_idx: int = 5) -> void:
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var holder: Node2D = Node2D.new()
	holder.global_position = pos
	holder.z_index = z_idx
	root.add_child(holder)
	var burst: GPUParticles2D = GPUParticles2D.new()
	burst.amount = amount
	burst.lifetime = lifetime
	burst.explosiveness = 1.0
	burst.one_shot = true
	burst.emitting = true
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = direction
	mat.spread = spread
	mat.gravity = Vector3(0, gravity_y, 0)
	mat.initial_velocity_min = velocity_min
	mat.initial_velocity_max = velocity_max
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	var grad: Gradient = Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gtex: GradientTexture1D = GradientTexture1D.new()
	gtex.gradient = grad
	mat.color_ramp = gtex
	burst.process_material = mat
	holder.add_child(burst)
	# Free tras lifetime + margen
	var t: Timer = Timer.new()
	t.wait_time = lifetime + 0.3
	t.one_shot = true
	t.timeout.connect(func() -> void:
		if is_instance_valid(holder):
			holder.queue_free()
	)
	holder.add_child(t)
	t.start()


## Curación: chispas verdes ascendentes + cruz roja flotando arriba del player.
func _spawn_skill_vfx_heal() -> void:
	if _player == null:
		return
	var pos: Vector2 = _player.global_position + Vector2(0, -30)
	_spawn_particle_burst(pos, Color(0.40, 1.0, 0.50, 0.95), 30, 0.8,
		60.0, 120.0, -120.0, 40.0, Vector3(0, -1, 0), 6)
	# Cruz roja flotante
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var cross: Node2D = Node2D.new()
	cross.global_position = pos + Vector2(0, -10)
	cross.z_index = 7
	root.add_child(cross)
	var vbar: Polygon2D = Polygon2D.new()
	vbar.color = Color(0.95, 0.20, 0.25, 1.0)
	vbar.polygon = PackedVector2Array([
		Vector2(-3, -14), Vector2(3, -14), Vector2(3, 14), Vector2(-3, 14),
	])
	cross.add_child(vbar)
	var hbar: Polygon2D = Polygon2D.new()
	hbar.color = Color(0.95, 0.20, 0.25, 1.0)
	hbar.polygon = PackedVector2Array([
		Vector2(-12, -3), Vector2(12, -3), Vector2(12, 3), Vector2(-12, 3),
	])
	cross.add_child(hbar)
	cross.scale = Vector2(0.4, 0.4)
	var tween: Tween = root.create_tween().set_parallel(true)
	tween.tween_property(cross, "scale", Vector2(1.2, 1.2), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cross, "position:y", cross.position.y - 40.0, 0.9)
	tween.tween_property(cross, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(cross):
			cross.queue_free()
	)


## Buff de daño (status berserker): aura roja sostenida + 6 chispas iniciales.
func _spawn_skill_vfx_buff_damage(duration: float) -> void:
	if _player == null:
		return
	var pos: Vector2 = _player.global_position + Vector2(0, -30)
	_spawn_particle_burst(pos, Color(1.0, 0.30, 0.15, 0.95), 18, 0.45,
		90.0, 180.0, 60.0, 180.0, Vector3(0, -1, 0), 6)
	# Aura sostenida (anillo pulsante en el suelo durante toda la duración)
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var aura: Node2D = Node2D.new()
	aura.z_index = 0
	root.add_child(aura)
	var ring: Line2D = Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.20, 0.10, 0.85)
	ring.closed = true
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(28):
		var ang: float = i * TAU / 28.0
		pts.append(Vector2(cos(ang) * 26.0, sin(ang) * 8.0))
	ring.points = pts
	aura.add_child(ring)
	# Follow player
	var follow_timer: float = duration
	var poll: Timer = Timer.new()
	poll.wait_time = 0.05
	poll.timeout.connect(func() -> void:
		if not is_instance_valid(aura) or not is_instance_valid(_player):
			return
		aura.global_position = _player.global_position + Vector2(0, -2)
		follow_timer -= 0.05
		if follow_timer <= 0.0:
			aura.queue_free()
	)
	aura.add_child(poll)
	poll.start()


## AoE radial: shockwave ring + (opcional) chispas de fuego para Onda Sísmica.
func _spawn_skill_vfx_aoe(radius: float, color: Color, with_embers: bool) -> void:
	if _player == null:
		return
	var pos: Vector2 = _player.global_position + Vector2(0, -10)
	# Anillo expansivo
	_spawn_expanding_ring(pos, color, radius, 0.45, 5.0)
	# Segundo anillo más interno (doble shockwave)
	_spawn_expanding_ring(pos, Color(color.r, color.g, color.b, color.a * 0.65),
		radius * 0.75, 0.35, 3.0)
	# Burst central
	_spawn_particle_burst(pos, color, 24, 0.55,
		120.0 + radius * 0.4, 200.0 + radius * 0.6, 220.0)
	# Brasas para skills BURN
	if with_embers:
		_spawn_particle_burst(pos, Color(1.0, 0.65, 0.15, 0.95), 30, 0.7,
			60.0, 150.0, -80.0, 180.0, Vector3(0, -1, 0), 6)


## Dash forward (Embestida): trail naranja + flash de impulso.
func _spawn_skill_vfx_dash(facing: int, distance: float) -> void:
	if _player == null:
		return
	var pos: Vector2 = _player.global_position + Vector2(0, -30)
	# Burst en el origen — chispas hacia atrás del facing
	_spawn_particle_burst(pos, Color(1.0, 0.55, 0.18, 0.95), 24, 0.5,
		80.0, 180.0, 60.0, 60.0,
		Vector3(-float(facing), 0, 0), 5)
	# Trail: línea naranja que se desvanece detrás del player en la dirección opuesta
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var trail: Line2D = Line2D.new()
	trail.width = 14.0
	trail.default_color = Color(1.0, 0.50, 0.15, 0.7)
	trail.z_index = 3
	# 4 puntos en la línea del dash (atrás del facing)
	for i in range(5):
		var off: float = -float(facing) * float(i) * (distance * 0.25)
		trail.add_point(pos + Vector2(off, 0))
	root.add_child(trail)
	var tween: Tween = root.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(trail):
			trail.queue_free()
	)


## Muzzle flash (Bola de Fuego): flash naranja en el frente del player.
func _spawn_skill_vfx_muzzle_flash(facing: int) -> void:
	if _player == null:
		return
	var pos: Vector2 = _player.global_position + Vector2(20.0 * float(facing), -45.0)
	_spawn_particle_burst(pos, Color(1.0, 0.65, 0.15, 0.95), 20, 0.35,
		120.0, 240.0, -40.0, 80.0,
		Vector3(float(facing), -0.3, 0), 6)
	# Flash redondo brillante
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var flash: Node2D = Node2D.new()
	flash.global_position = pos
	flash.z_index = 6
	root.add_child(flash)
	var circle: Polygon2D = Polygon2D.new()
	circle.color = Color(1.0, 0.9, 0.5, 0.95)
	var fpts: PackedVector2Array = PackedVector2Array()
	for i in range(20):
		var ang: float = i * TAU / 20.0
		fpts.append(Vector2(cos(ang), sin(ang)) * 10.0)
	circle.polygon = fpts
	flash.add_child(circle)
	var tween: Tween = root.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.2, 2.2), 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(circle, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
	)


## Escudo Mágico: hexágono cyan orbitando al player + chispas iniciales.
func _spawn_skill_vfx_shield(duration: float) -> void:
	if _player == null:
		return
	var pos: Vector2 = _player.global_position + Vector2(0, -30)
	_spawn_particle_burst(pos, Color(0.55, 0.85, 1.0, 0.95), 22, 0.5,
		60.0, 140.0, -40.0, 180.0, Vector3(0, -1, 0), 6)
	# Hexágono sostenido orbitando
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var hex_holder: Node2D = Node2D.new()
	hex_holder.z_index = 4
	root.add_child(hex_holder)
	var hex: Line2D = Line2D.new()
	hex.width = 2.5
	hex.default_color = Color(0.65, 0.92, 1.0, 0.85)
	hex.closed = true
	for i in range(6):
		var ang: float = i * TAU / 6.0 + PI / 6.0
		hex.add_point(Vector2(cos(ang), sin(ang)) * 28.0)
	hex_holder.add_child(hex)
	# Spin + follow
	var elapsed: float = 0.0
	var spin_timer: Timer = Timer.new()
	spin_timer.wait_time = 0.05
	spin_timer.timeout.connect(func() -> void:
		if not is_instance_valid(hex_holder) or not is_instance_valid(_player):
			return
		hex_holder.global_position = _player.global_position + Vector2(0, -30)
		hex_holder.rotation += 0.18
		elapsed += 0.05
		if elapsed >= duration:
			hex_holder.queue_free()
	)
	hex_holder.add_child(spin_timer)
	spin_timer.start()


## Sombra: voluta púrpura/negra envuelve al player + fade rápido.
func _spawn_skill_vfx_shadow_wisp() -> void:
	if _player == null:
		return
	var pos: Vector2 = _player.global_position + Vector2(0, -25)
	# Burst púrpura denso radial
	_spawn_particle_burst(pos, Color(0.55, 0.25, 0.75, 0.9), 28, 0.7,
		40.0, 100.0, -20.0, 180.0, Vector3(0, -1, 0), 5)
	# Anillo de humo descendente
	var root: Node = _vfx_scene_root()
	if root == null:
		return
	var smoke: GPUParticles2D = GPUParticles2D.new()
	smoke.amount = 18
	smoke.lifetime = 1.0
	smoke.explosiveness = 0.8
	smoke.one_shot = true
	smoke.emitting = true
	smoke.global_position = pos
	smoke.z_index = 4
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 18.0
	mat.direction = Vector3(0, -0.3, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.scale_min = 1.5
	mat.scale_max = 3.5
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.25, 0.10, 0.40, 0.95))
	grad.set_color(1, Color(0.05, 0.02, 0.10, 0.0))
	var gtex: GradientTexture1D = GradientTexture1D.new()
	gtex.gradient = grad
	mat.color_ramp = gtex
	smoke.process_material = mat
	root.add_child(smoke)
	var t: Timer = Timer.new()
	t.wait_time = 1.4
	t.one_shot = true
	t.timeout.connect(func() -> void:
		if is_instance_valid(smoke):
			smoke.queue_free()
	)
	smoke.add_child(t)
	t.start()
