extends Enemy
class_name BossLyss

## Lyss, la Sirena de Hielo — Boss R4 Zona 3 (Acueducto del Lamento).
## Mage/AGUA. Castigo de denegación de área + control posicional.
##
## Patrones F1:
##  1. Látigo Helado           — hitbox lineal frontal rápido (rifle congelado), telegraph 0.6s.
##  2. Nova de Hielo           — AoeTelegraph bajo el player + drop AoE + FREEZE.
##  3. Triple Tiro             — 3 proyectiles fireball-style spread (reusa projectile_scene).
##
## F2 (HP ≤ 50%):
##  4. Vórtice de Gravedad     — pulls player hacia el boss durante 1.5s.
##  5. Canto Helado            — aura aplicada al player si está cerca (mareo frío permanente F2).
##
## Decisión Leo (handoff zona 3): vortice habilitado SOLO en boss fights — bloqueado §3 ⛔
## para mobs comunes. Acá es boss, regla flexibilizada. Override de input corto (1.5s máx).
##
## Sin reflejo de proyectiles (REQ-INFRA grande no implementada — Lyss usa Látigo en su lugar).

# ─── Estados ─────────────────────────────────────────────────────────────────
const BOSS_STATE_LATIGO_WINDUP: int = 400
const BOSS_STATE_LATIGO_STRIKE: int = 401
const BOSS_STATE_NOVA_WINDUP: int = 410
const BOSS_STATE_NOVA_ACTIVE: int = 411
const BOSS_STATE_TRIPLE_WINDUP: int = 420
const BOSS_STATE_TRIPLE_FIRE: int = 421
const BOSS_STATE_VORTICE_WINDUP: int = 430
const BOSS_STATE_VORTICE_ACTIVE: int = 431
const BOSS_STATE_MURALLA_WINDUP: int = 440
const BOSS_STATE_MURALLA_ACTIVE: int = 441

# ─── Config patrones ─────────────────────────────────────────────────────────
const LATIGO_WINDUP_SECONDS: float = 0.6
const LATIGO_STRIKE_SECONDS: float = 0.15
const LATIGO_RANGE: float = 220.0
const LATIGO_WIDTH: float = 30.0
const LATIGO_DAMAGE_MULT: float = 1.4
const LATIGO_COOLDOWN_MIN: float = 4.0
const LATIGO_COOLDOWN_MAX: float = 5.5

const NOVA_WINDUP_SECONDS: float = 0.9
const NOVA_ACTIVE_SECONDS: float = 0.8
const NOVA_TELEGRAPH_TIME: float = 0.55
const NOVA_RADIUS: float = 70.0
const NOVA_DAMAGE_MULT: float = 1.3
const NOVA_COOLDOWN_MIN: float = 7.0
const NOVA_COOLDOWN_MAX: float = 9.5

const TRIPLE_WINDUP_SECONDS: float = 0.8
const TRIPLE_DURATION: float = 0.6
const TRIPLE_DAMAGE_MULT: float = 1.0
const TRIPLE_SPREAD_DEG: float = 18.0
const TRIPLE_COOLDOWN_MIN: float = 6.0
const TRIPLE_COOLDOWN_MAX: float = 8.0

const VORTICE_WINDUP_SECONDS: float = 0.7
const VORTICE_ACTIVE_SECONDS: float = 1.5
const VORTICE_PULL_SPEED: float = 280.0
const VORTICE_COOLDOWN_MIN: float = 12.0
const VORTICE_COOLDOWN_MAX: float = 16.0

const CANTO_RADIUS: float = 220.0
const CANTO_SLOW_MULT: float = 0.7
const CANTO_TICK_INTERVAL: float = 0.5

# Muralla Estática (F2) — refleja proyectiles del player dentro del radio.
# Constantes faltantes (bug 28/05): el código las referenciaba pero nunca se declararon,
# crasheaba al entrar fase 2 cuando intentaba activar Muralla. Valor radio 90px
# canónico del handoff 27/05 (1625-completo).
const MURALLA_WINDUP_SECONDS: float = 0.7
const MURALLA_ACTIVE_SECONDS: float = 2.0
const MURALLA_COOLDOWN_MIN: float = 9.0
const MURALLA_COOLDOWN_MAX: float = 13.0
const MURALLA_REFLECT_RADIUS: float = 90.0

const PHASE_2_COOLDOWN_FACTOR: float = 0.80

# ─── Runtime ─────────────────────────────────────────────────────────────────
var _phase: int = 1
var _latigo_cd: float = 2.0
var _nova_cd: float = 3.5
var _triple_cd: float = 5.0
var _vortice_cd: float = 8.0
var _muralla_cd: float = 6.0
var _canto_tick_timer: float = 0.0
## Set de proyectiles ya reflejados este cast (evita reflejar el mismo dos veces).
var _muralla_reflected_set: Array[Projectile] = []
var _latigo_hit_applied: bool = false


func _ready() -> void:
	enemy_class = GameConfig.EnemyClass.MAGE
	rarity = GameConfig.EnemyRarity.R4
	element = ItemData.Element.AGUA
	super._ready()

	# HP: 1.0× del MAGE R4 base.
	health.max_health = int(round(float(GameConfig.enemy_health_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R4)) * 1.0))
	health.current_health = health.max_health

	# Velocidad normal mage (lenta).
	speed = GameConfig.enemy_speed_for(GameConfig.EnemyClass.MAGE)

	# Daño base: ×1.25 del R3 mage.
	hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * 1.25))

	if _block_handler != null:
		_block_handler.deactivate()
		hurtbox.shield = null

	# Visual: azul hielo.
	if sprite != null:
		sprite.body_color = Color(0.55, 0.80, 1.0, 1.0)
		sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity) * 1.08
		sprite.weapon_scale = 1.5

	health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, maximum: int) -> void:
	if _phase == 1 and current <= maximum / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	_phase = 2
	_latigo_cd *= PHASE_2_COOLDOWN_FACTOR
	_nova_cd *= PHASE_2_COOLDOWN_FACTOR
	_triple_cd *= PHASE_2_COOLDOWN_FACTOR
	_vortice_cd = 2.0  # casi disponible
	if sprite != null:
		sprite.body_color = Color(0.35, 0.65, 1.10, 1.0)
	if CameraShake != null:
		CameraShake.shake(12.0, 0.30)


# ─── State machine override ──────────────────────────────────────────────────
func _tick_state(delta: float) -> void:
	if _latigo_cd > 0.0: _latigo_cd -= delta
	if _nova_cd > 0.0: _nova_cd -= delta
	if _triple_cd > 0.0: _triple_cd -= delta
	if _vortice_cd > 0.0: _vortice_cd -= delta
	if _muralla_cd > 0.0: _muralla_cd -= delta

	# Canto Helado: aura permanente F2 que aplica SLOW periódicamente al player si está cerca.
	if _phase == 2 and _target != null:
		_canto_tick_timer -= delta
		if _canto_tick_timer <= 0.0:
			_canto_tick_timer = CANTO_TICK_INTERVAL
			_apply_canto_helado()

	if state >= BOSS_STATE_LATIGO_WINDUP:
		_tick_boss_state(delta)
		return

	if state == State.CHASE and _target != null and is_on_floor():
		if _try_start_pattern():
			return

	super._tick_state(delta)


func _try_start_pattern() -> bool:
	var dist: float = _distance_to_target()

	# F2: Muralla Estática — refleja proyectiles del player. Prioridad alta si player apunta lejos.
	if _phase == 2 and _muralla_cd <= 0.0 and dist > LATIGO_RANGE * 0.8:
		_change_to_boss_state(BOSS_STATE_MURALLA_WINDUP)
		return true

	# F2: Vórtice de Gravedad — close-mid, pull player.
	if _phase == 2 and _vortice_cd <= 0.0 and dist > LATIGO_RANGE * 0.4 and dist < detect_range * 0.7:
		_change_to_boss_state(BOSS_STATE_VORTICE_WINDUP)
		return true

	# Triple Tiro — distancia media-larga.
	if _triple_cd <= 0.0 and dist > LATIGO_RANGE * 0.5:
		_change_to_boss_state(BOSS_STATE_TRIPLE_WINDUP)
		return true

	# Nova de Hielo — cualquier distancia.
	if _nova_cd <= 0.0:
		_change_to_boss_state(BOSS_STATE_NOVA_WINDUP)
		return true

	# Látigo Helado — front-facing, hitbox lineal corto.
	if _latigo_cd <= 0.0 and dist < LATIGO_RANGE * 1.2:
		_change_to_boss_state(BOSS_STATE_LATIGO_WINDUP)
		return true

	return false


func _change_to_boss_state(new_state: int) -> void:
	state = new_state
	_state_timer = 0.0
	_face_target()
	hitbox.set_active(false)
	_latigo_hit_applied = false
	match new_state:
		BOSS_STATE_LATIGO_WINDUP:
			sprite.start_telegraph(LATIGO_WINDUP_SECONDS)
		BOSS_STATE_NOVA_WINDUP:
			sprite.start_telegraph(NOVA_WINDUP_SECONDS)
			_spawn_nova_telegraph()
		BOSS_STATE_TRIPLE_WINDUP:
			sprite.start_telegraph(TRIPLE_WINDUP_SECONDS)
		BOSS_STATE_VORTICE_WINDUP:
			sprite.start_telegraph(VORTICE_WINDUP_SECONDS)
		BOSS_STATE_MURALLA_WINDUP:
			sprite.start_telegraph(MURALLA_WINDUP_SECONDS)
			_muralla_reflected_set.clear()


func _tick_boss_state(delta: float) -> void:
	_state_timer += delta  # fix C2: el timer no avanzaba en estados boss (early-return evita super)
	match state:
		BOSS_STATE_LATIGO_WINDUP:
			velocity.x = 0.0
			if _state_timer >= LATIGO_WINDUP_SECONDS:
				state = BOSS_STATE_LATIGO_STRIKE
				_state_timer = 0.0
		BOSS_STATE_LATIGO_STRIKE:
			velocity.x = 0.0
			if not _latigo_hit_applied:
				_apply_latigo_damage()
				_latigo_hit_applied = true
			if _state_timer >= LATIGO_STRIKE_SECONDS:
				_latigo_cd = randf_range(LATIGO_COOLDOWN_MIN, LATIGO_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_NOVA_WINDUP:
			velocity.x = 0.0
			if _state_timer >= NOVA_WINDUP_SECONDS:
				state = BOSS_STATE_NOVA_ACTIVE
				_state_timer = 0.0
				_apply_nova_damage()
		BOSS_STATE_NOVA_ACTIVE:
			velocity.x = 0.0
			if _state_timer >= NOVA_ACTIVE_SECONDS:
				_nova_cd = randf_range(NOVA_COOLDOWN_MIN, NOVA_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_TRIPLE_WINDUP:
			velocity.x = 0.0
			if _state_timer >= TRIPLE_WINDUP_SECONDS:
				state = BOSS_STATE_TRIPLE_FIRE
				_state_timer = 0.0
				_fire_triple_shot()
		BOSS_STATE_TRIPLE_FIRE:
			velocity.x = 0.0
			if _state_timer >= TRIPLE_DURATION:
				_triple_cd = randf_range(TRIPLE_COOLDOWN_MIN, TRIPLE_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_VORTICE_WINDUP:
			velocity.x = 0.0
			if _state_timer >= VORTICE_WINDUP_SECONDS:
				state = BOSS_STATE_VORTICE_ACTIVE
				_state_timer = 0.0
		BOSS_STATE_VORTICE_ACTIVE:
			velocity.x = 0.0
			_apply_vortice_pull(delta)
			if _state_timer >= VORTICE_ACTIVE_SECONDS:
				_vortice_cd = randf_range(VORTICE_COOLDOWN_MIN, VORTICE_COOLDOWN_MAX)
				_change_state(State.RECOVERY)

		BOSS_STATE_MURALLA_WINDUP:
			velocity.x = 0.0
			if _state_timer >= MURALLA_WINDUP_SECONDS:
				state = BOSS_STATE_MURALLA_ACTIVE
				_state_timer = 0.0
				_spawn_muralla_aura()
		BOSS_STATE_MURALLA_ACTIVE:
			velocity.x = 0.0
			_check_muralla_reflect()
			if _state_timer >= MURALLA_ACTIVE_SECONDS:
				_despawn_muralla_aura()
				_muralla_cd = randf_range(MURALLA_COOLDOWN_MIN, MURALLA_COOLDOWN_MAX)
				_change_state(State.RECOVERY)


# ─── Skills implementations ───────────────────────────────────────────────────

func _apply_latigo_damage() -> void:
	# Hitbox rectangular lineal — query rectangular en frente del boss.
	if _target == null:
		return
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(LATIGO_RANGE, LATIGO_WIDTH)
	query.shape = rect
	var origin: Vector2 = global_position + Vector2(current_facing * LATIGO_RANGE * 0.5, -50.0)
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = 0b10000
	query.collide_with_areas = true
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * LATIGO_DAMAGE_MULT))
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 8)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is HurtboxComponent:
			var hb: HurtboxComponent = collider
			if hb.team == team:
				continue
			hb.receive_hit(dmg, null, 0)


func _spawn_nova_telegraph() -> void:
	if _target == null:
		return
	var scene: PackedScene = load("res://scenes/effects/aoe_telegraph.tscn") as PackedScene
	if scene == null:
		return
	var pos: Vector2 = _target.global_position + Vector2(0, 20)
	var tele: AoeTelegraph = scene.instantiate() as AoeTelegraph
	if tele == null:
		return
	tele.global_position = pos
	tele.setup(NOVA_RADIUS, NOVA_WINDUP_SECONDS + 0.1, Color(0.4, 0.85, 1.0, 0.6))
	get_tree().current_scene.add_child(tele)


func _apply_nova_damage() -> void:
	if _target == null:
		return
	var pos: Vector2 = _target.global_position + Vector2(0, 20)
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * NOVA_DAMAGE_MULT))
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = NOVA_RADIUS
	query.shape = circle
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 0b10000
	query.collide_with_areas = true
	var freeze_data: StatusEffectData = load("res://resources/status_effects/freeze.tres") as StatusEffectData
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is HurtboxComponent:
			var hb: HurtboxComponent = collider
			if hb.team == team:
				continue
			hb.receive_hit(dmg, null, 0)
			if freeze_data != null:
				var owner_node: Node = hb.get_parent()
				var se: StatusEffectComponent = owner_node.get_node_or_null("StatusEffects") as StatusEffectComponent
				if se != null:
					se.apply(freeze_data, self)
	# Burst de impacto cyan — sin esto Nova de Hielo no muestra explosión visible (solo el círculo telegraph).
	_spawn_aoe_impact_burst(pos, Color(0.55, 0.9, 1.0, 0.95), 1.3)


func _fire_triple_shot() -> void:
	if projectile_scene == null or _target == null:
		return
	var aim_point: Vector2 = _target.global_position + Vector2(0, -30)
	var origin: Vector2 = global_position + Vector2(0, -45)
	var base_dir: Vector2 = (aim_point - origin).normalized()
	var angles: Array[float] = [0.0, -TRIPLE_SPREAD_DEG, TRIPLE_SPREAD_DEG]
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * TRIPLE_DAMAGE_MULT))
	for angle_deg: float in angles:
		var dir: Vector2 = base_dir.rotated(deg_to_rad(angle_deg))
		var proj: Projectile = projectile_scene.instantiate() as Projectile
		if proj == null:
			continue
		proj.global_position = origin
		proj.launch(dir, dmg, team, element)
		proj.set_source(self)
		get_tree().current_scene.add_child(proj)


func _apply_vortice_pull(delta: float) -> void:
	if _target == null or not _target.has_method("apply_external_velocity"):
		return
	var to_boss: Vector2 = global_position - _target.global_position
	var dist: float = to_boss.length()
	if dist < 30.0:
		return
	var pull: Vector2 = to_boss.normalized() * VORTICE_PULL_SPEED * delta * 60.0
	_target.apply_external_velocity(pull)


func _apply_canto_helado() -> void:
	if _target == null:
		return
	var dist: float = global_position.distance_to(_target.global_position)
	if dist > CANTO_RADIUS:
		return
	if not _target.has_method("apply_slow"):
		return
	_target.apply_slow(CANTO_SLOW_MULT, CANTO_TICK_INTERVAL + 0.05)


# ─── Muralla Estática (F2): refleja proyectiles del player ────────────────

func _spawn_muralla_aura() -> void:
	# VFX: aura azul/cian alrededor de Lyss.
	var old: Node = get_node_or_null("MurallaAuraLyss")
	if old != null:
		old.queue_free()
	var aura: GPUParticles2D = GPUParticles2D.new()
	aura.name = "MurallaAuraLyss"
	aura.position = Vector2(0, -45)
	aura.amount = 12
	aura.lifetime = 0.6
	aura.preprocess = 0.2
	aura.explosiveness = 0.0
	aura.z_index = -1
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = MURALLA_REFLECT_RADIUS * 0.7
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 30.0
	mat.scale_min = 1.5
	mat.scale_max = 2.4
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.5, 0.8, 1.0, 0.85))
	grad.set_color(1, Color(0.2, 0.5, 1.0, 0.0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	aura.process_material = mat
	aura.emitting = true
	add_child(aura)


func _despawn_muralla_aura() -> void:
	var aura: Node = get_node_or_null("MurallaAuraLyss")
	if aura == null:
		return
	if aura is GPUParticles2D:
		(aura as GPUParticles2D).emitting = false
	var t: Timer = Timer.new()
	t.wait_time = 0.4
	t.one_shot = true
	t.timeout.connect(func() -> void:
		if aura != null and is_instance_valid(aura):
			aura.queue_free()
		t.queue_free())
	add_child(t)
	t.start()


## Cada frame durante MURALLA_ACTIVE: busca proyectiles team=1 (player) dentro del radio
## y los refleja (team→2, source→Lyss, direction→hacia player).
func _check_muralla_reflect() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = MURALLA_REFLECT_RADIUS
	query.shape = circle
	query.transform = Transform2D(0.0, global_position + Vector2(0, -45))
	# Layer 4 = Hitbox (Projectile uses bit 4).
	query.collision_mask = 0b1000
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 8)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is Projectile:
			var proj: Projectile = collider
			if proj.team != 1:  # solo proyectiles del player
				continue
			if _muralla_reflected_set.has(proj):
				continue
			# Calcular nueva dirección hacia el player.
			var new_dir: Vector2 = Vector2.RIGHT
			if _target != null:
				new_dir = (_target.global_position - proj.global_position).normalized()
			proj.reflect(2, self, new_dir)
			_muralla_reflected_set.append(proj)
			if CameraShake != null:
				CameraShake.shake(4.0, 0.06)
