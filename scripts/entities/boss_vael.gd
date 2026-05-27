extends Enemy
class_name BossVael

## Vael, el Señor de la Luz Cegadora — Boss R4 Zona 4 (Cumbres de la Tempestad).
## Mage/LUZ. Boss más rápido del juego según GDD. Mezcla burst de luz + gap creator.
##
## Patrones F1:
##  1. Ráfaga Arcana       — 3 proyectiles secuenciales con delay 0.12s.
##  2. Patada Frontal      — hit + knockback fuerte (gap creator).
##  3. Destello Sanador    — heal propio 8% HP + tinte dorado (sustain).
##
## F2 (HP ≤ 50%):
##  4. Salto Cegador       — jump + landing AoE + aplica STUN al player en radio.
##  Cooldowns -25%. Trigger Destello automático cada vez que HP ≤ 30%.
##
## Sin escudo de cargas — defensa via velocidad + sustain (Destello).
## Lanza de Luz Penetrante (laser tracking 2s) DEFERIDO — requiere infra Line2D follow.

# ─── Estados ─────────────────────────────────────────────────────────────────
const BOSS_STATE_RAFAGA_WINDUP: int = 500
const BOSS_STATE_RAFAGA_FIRE: int = 501
const BOSS_STATE_PATADA_WINDUP: int = 510
const BOSS_STATE_PATADA_STRIKE: int = 511
const BOSS_STATE_DESTELLO_WINDUP: int = 520
const BOSS_STATE_DESTELLO_ACTIVE: int = 521
const BOSS_STATE_SALTO_WINDUP: int = 530
const BOSS_STATE_SALTO_JUMP: int = 531
const BOSS_STATE_SALTO_LAND: int = 532
const BOSS_STATE_LANZA_WINDUP: int = 540
const BOSS_STATE_LANZA_ACTIVE: int = 541

# ─── Config patrones ─────────────────────────────────────────────────────────
const RAFAGA_WINDUP_SECONDS: float = 0.5
const RAFAGA_DURATION: float = 0.6
const RAFAGA_SHOT_COUNT: int = 3
const RAFAGA_SHOT_INTERVAL: float = 0.12
const RAFAGA_DAMAGE_MULT: float = 0.7
const RAFAGA_COOLDOWN_MIN: float = 4.5
const RAFAGA_COOLDOWN_MAX: float = 6.0

const PATADA_WINDUP_SECONDS: float = 0.35
const PATADA_STRIKE_SECONDS: float = 0.18
const PATADA_DAMAGE_MULT: float = 1.0
const PATADA_RANGE: float = 110.0
const PATADA_KNOCKBACK_X: float = 300.0
const PATADA_KNOCKBACK_Y: float = -180.0
const PATADA_COOLDOWN_MIN: float = 5.0
const PATADA_COOLDOWN_MAX: float = 7.5

const DESTELLO_WINDUP_SECONDS: float = 0.6
const DESTELLO_HEAL_PCT: float = 0.08
const DESTELLO_COOLDOWN_MIN: float = 14.0
const DESTELLO_COOLDOWN_MAX: float = 18.0
const DESTELLO_F2_LOW_HP_TRIGGER: float = 0.30  ## auto-cast si HP <= 30%

const SALTO_WINDUP_SECONDS: float = 0.55
const SALTO_AIR_SECONDS: float = 0.75
const SALTO_JUMP_VY: float = -1000.0
const SALTO_LANDING_RADIUS: float = 90.0
const SALTO_LANDING_DAMAGE_MULT: float = 1.3
const SALTO_COOLDOWN_MIN: float = 11.0
const SALTO_COOLDOWN_MAX: float = 15.0

# Lanza de Luz Penetrante (F2 only) — laser tracking lento.
const LANZA_WINDUP_SECONDS: float = 1.0
const LANZA_ACTIVE_SECONDS: float = 2.0
const LANZA_TICK_INTERVAL: float = 0.3
const LANZA_DAMAGE_MULT: float = 0.8  # 0.8× R3 mage damage, multiple ticks = burst si player no esquiva
const LANZA_LENGTH: float = 700.0
const LANZA_WIDTH: float = 16.0
const LANZA_TRACKING_LERP: float = 1.8  # rad/s — lerp lento hacia player (mientras menor, más fácil esquivar)
const LANZA_COOLDOWN_MIN: float = 13.0
const LANZA_COOLDOWN_MAX: float = 18.0

const PHASE_2_COOLDOWN_FACTOR: float = 0.75
const VAEL_BENDICION_HEAL_PCT_3PC: float = 0.08

# ─── Runtime ─────────────────────────────────────────────────────────────────
var _phase: int = 1
var _rafaga_cd: float = 3.0
var _patada_cd: float = 4.5
var _destello_cd: float = 8.0
var _salto_cd: float = 10.0
var _rafaga_shots_fired: int = 0
var _rafaga_next_shot_at: float = 0.0
var _salto_landing_pos: Vector2 = Vector2.ZERO
var _salto_landed: bool = false

# Lanza de Luz state.
var _lanza_cd: float = 8.0
var _lanza_aim_dir: Vector2 = Vector2.RIGHT
var _lanza_tick_accum: float = 0.0
var _lanza_line: Line2D = null


func _ready() -> void:
	enemy_class = GameConfig.EnemyClass.MAGE
	rarity = GameConfig.EnemyRarity.R4
	element = ItemData.Element.LUZ
	super._ready()

	# HP: 0.95× del MAGE R4 base (frágil pero veloz).
	health.max_health = int(round(float(GameConfig.enemy_health_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R4)) * 0.95))
	health.current_health = health.max_health

	# Velocidad alta — el boss más rápido del juego.
	speed = GameConfig.enemy_speed_for(GameConfig.EnemyClass.MAGE) * 1.6

	# Daño base: ×1.2 del R3 mage.
	hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * 1.2))

	if _block_handler != null:
		_block_handler.deactivate()
		hurtbox.shield = null

	# Visual: dorado radiante.
	if sprite != null:
		sprite.body_color = Color(1.0, 0.9, 0.4, 1.0)
		sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity) * 1.05
		sprite.weapon_scale = 1.55

	health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, maximum: int) -> void:
	if _phase == 1 and current <= maximum / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	_phase = 2
	_rafaga_cd *= PHASE_2_COOLDOWN_FACTOR
	_patada_cd *= PHASE_2_COOLDOWN_FACTOR
	_destello_cd *= PHASE_2_COOLDOWN_FACTOR
	_salto_cd = 2.5  # casi disponible
	if sprite != null:
		sprite.body_color = Color(1.15, 1.0, 0.55, 1.0)
	if CameraShake != null:
		CameraShake.shake(0.30, 12.0)


# ─── State machine override ──────────────────────────────────────────────────
func _tick_state(delta: float) -> void:
	if _rafaga_cd > 0.0: _rafaga_cd -= delta
	if _patada_cd > 0.0: _patada_cd -= delta
	if _destello_cd > 0.0: _destello_cd -= delta
	if _salto_cd > 0.0: _salto_cd -= delta
	if _lanza_cd > 0.0: _lanza_cd -= delta

	if state >= BOSS_STATE_RAFAGA_WINDUP:
		_tick_boss_state(delta)
		return

	if state == State.CHASE and _target != null and is_on_floor():
		if _try_start_pattern():
			return

	super._tick_state(delta)


func _try_start_pattern() -> bool:
	var dist: float = _distance_to_target()
	var hp_pct: float = float(health.current_health) / float(health.max_health) if health.max_health > 0 else 1.0

	# F2 emergency Destello — auto-cast si HP bajo (sustain).
	if _phase == 2 and hp_pct <= DESTELLO_F2_LOW_HP_TRIGGER and _destello_cd <= 0.0:
		_change_to_boss_state(BOSS_STATE_DESTELLO_WINDUP)
		return true

	# F2: Lanza de Luz — distancia media-larga, sweep tracking. Prioridad alta.
	if _phase == 2 and _lanza_cd <= 0.0 and dist > PATADA_RANGE * 1.5 and dist < detect_range:
		_change_to_boss_state(BOSS_STATE_LANZA_WINDUP)
		return true

	# F2: Salto Cegador — close-mid range con STUN.
	if _phase == 2 and _salto_cd <= 0.0 and dist > PATADA_RANGE and dist < detect_range * 0.75:
		_change_to_boss_state(BOSS_STATE_SALTO_WINDUP)
		return true

	# Destello regular cuando HP < 60% y CD ready.
	if _destello_cd <= 0.0 and hp_pct < 0.6:
		_change_to_boss_state(BOSS_STATE_DESTELLO_WINDUP)
		return true

	# Patada Frontal — close range, gap creator.
	if _patada_cd <= 0.0 and dist < PATADA_RANGE * 1.2:
		_change_to_boss_state(BOSS_STATE_PATADA_WINDUP)
		return true

	# Ráfaga Arcana — distancia media-larga.
	if _rafaga_cd <= 0.0 and dist > PATADA_RANGE * 0.5:
		_change_to_boss_state(BOSS_STATE_RAFAGA_WINDUP)
		return true

	return false


func _change_to_boss_state(new_state: int) -> void:
	state = new_state
	_state_timer = 0.0
	_face_target()
	hitbox.set_active(false)
	match new_state:
		BOSS_STATE_RAFAGA_WINDUP:
			sprite.start_telegraph(RAFAGA_WINDUP_SECONDS)
			_rafaga_shots_fired = 0
			_rafaga_next_shot_at = 0.0
		BOSS_STATE_PATADA_WINDUP:
			sprite.start_telegraph(PATADA_WINDUP_SECONDS)
		BOSS_STATE_DESTELLO_WINDUP:
			sprite.start_telegraph(DESTELLO_WINDUP_SECONDS)
		BOSS_STATE_SALTO_WINDUP:
			sprite.start_telegraph(SALTO_WINDUP_SECONDS)
		BOSS_STATE_LANZA_WINDUP:
			sprite.start_telegraph(LANZA_WINDUP_SECONDS)
			# Aim inicial hacia el player.
			if _target != null:
				_lanza_aim_dir = (_target.global_position - global_position).normalized()


func _tick_boss_state(delta: float) -> void:
	match state:
		BOSS_STATE_RAFAGA_WINDUP:
			velocity.x = 0.0
			if _state_timer >= RAFAGA_WINDUP_SECONDS:
				state = BOSS_STATE_RAFAGA_FIRE
				_state_timer = 0.0
		BOSS_STATE_RAFAGA_FIRE:
			velocity.x = 0.0
			if _rafaga_shots_fired < RAFAGA_SHOT_COUNT and _state_timer >= _rafaga_next_shot_at:
				_spawn_rafaga_projectile()
				_rafaga_shots_fired += 1
				_rafaga_next_shot_at = _state_timer + RAFAGA_SHOT_INTERVAL
			if _state_timer >= RAFAGA_DURATION:
				_rafaga_cd = randf_range(RAFAGA_COOLDOWN_MIN, RAFAGA_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_PATADA_WINDUP:
			velocity.x = 0.0
			if _state_timer >= PATADA_WINDUP_SECONDS:
				state = BOSS_STATE_PATADA_STRIKE
				_state_timer = 0.0
				hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
					GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * PATADA_DAMAGE_MULT))
				hitbox.set_active(true)
				_apply_patada_knockback()
		BOSS_STATE_PATADA_STRIKE:
			velocity.x = 0.0
			if _state_timer >= PATADA_STRIKE_SECONDS:
				hitbox.set_active(false)
				_patada_cd = randf_range(PATADA_COOLDOWN_MIN, PATADA_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_DESTELLO_WINDUP:
			velocity.x = 0.0
			if _state_timer >= DESTELLO_WINDUP_SECONDS:
				state = BOSS_STATE_DESTELLO_ACTIVE
				_state_timer = 0.0
				_apply_destello_heal()
		BOSS_STATE_DESTELLO_ACTIVE:
			velocity.x = 0.0
			if _state_timer >= 0.3:
				_destello_cd = randf_range(DESTELLO_COOLDOWN_MIN, DESTELLO_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_SALTO_WINDUP:
			velocity.x = 0.0
			if _state_timer >= SALTO_WINDUP_SECONDS:
				_salto_landing_pos = _target.global_position if _target != null else global_position
				_salto_landed = false
				velocity.y = SALTO_JUMP_VY
				var dx: float = _salto_landing_pos.x - global_position.x
				velocity.x = dx / SALTO_AIR_SECONDS
				state = BOSS_STATE_SALTO_JUMP
				_state_timer = 0.0
				# Spawn telegraph on landing position.
				var scene: PackedScene = load("res://scenes/effects/aoe_telegraph.tscn") as PackedScene
				if scene != null:
					var tele: AoeTelegraph = scene.instantiate() as AoeTelegraph
					if tele != null:
						tele.global_position = _salto_landing_pos
						tele.setup(SALTO_LANDING_RADIUS, SALTO_AIR_SECONDS + 0.1, \
							Color(1.0, 0.95, 0.5, 0.6))
						get_tree().current_scene.add_child(tele)
		BOSS_STATE_SALTO_JUMP:
			if not _salto_landed and (_state_timer >= SALTO_AIR_SECONDS or (is_on_floor() and _state_timer > 0.2)):
				_salto_landed = true
				velocity.x = 0.0
				_apply_salto_landing()
				state = BOSS_STATE_SALTO_LAND
				_state_timer = 0.0
		BOSS_STATE_SALTO_LAND:
			velocity.x = 0.0
			if _state_timer >= 0.25:
				_salto_cd = randf_range(SALTO_COOLDOWN_MIN, SALTO_COOLDOWN_MAX)
				_change_state(State.RECOVERY)

		BOSS_STATE_LANZA_WINDUP:
			velocity.x = 0.0
			if _state_timer >= LANZA_WINDUP_SECONDS:
				state = BOSS_STATE_LANZA_ACTIVE
				_state_timer = 0.0
				_lanza_tick_accum = 0.0
				_spawn_lanza_line()
		BOSS_STATE_LANZA_ACTIVE:
			velocity.x = 0.0
			# Lerp aim slow toward player — player puede esquivar saliendo del cono.
			if _target != null:
				var desired: Vector2 = (_target.global_position - global_position).normalized()
				var current_angle: float = _lanza_aim_dir.angle()
				var desired_angle: float = desired.angle()
				var new_angle: float = lerp_angle(current_angle, desired_angle, LANZA_TRACKING_LERP * delta)
				_lanza_aim_dir = Vector2.from_angle(new_angle)
			_update_lanza_line()
			# Tick damage si laser intersecta player.
			_lanza_tick_accum += delta
			if _lanza_tick_accum >= LANZA_TICK_INTERVAL:
				_lanza_tick_accum -= LANZA_TICK_INTERVAL
				_apply_lanza_tick_damage()
			if _state_timer >= LANZA_ACTIVE_SECONDS:
				_despawn_lanza_line()
				_lanza_cd = randf_range(LANZA_COOLDOWN_MIN, LANZA_COOLDOWN_MAX)
				_change_state(State.RECOVERY)


# ─── Skill implementations ────────────────────────────────────────────────────

func _spawn_rafaga_projectile() -> void:
	if projectile_scene == null or _target == null:
		return
	var proj: Projectile = projectile_scene.instantiate() as Projectile
	if proj == null:
		return
	proj.global_position = global_position + Vector2(0, -45)
	var aim: Vector2 = _target.global_position + Vector2(0, -30)
	var dir: Vector2 = (aim - proj.global_position).normalized()
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * RAFAGA_DAMAGE_MULT))
	proj.launch(dir, dmg, team, element)
	proj.set_source(self)
	get_tree().current_scene.add_child(proj)


func _apply_patada_knockback() -> void:
	if _target == null or not _target.has_method("apply_external_velocity"):
		return
	var dist: float = global_position.distance_to(_target.global_position)
	if dist > PATADA_RANGE:
		return
	var kb_dir: int = -1 if _target.global_position.x < global_position.x else 1
	_target.apply_external_velocity(Vector2(float(kb_dir) * PATADA_KNOCKBACK_X, PATADA_KNOCKBACK_Y))


func _apply_destello_heal() -> void:
	var heal_amt: int = int(round(float(health.max_health) * DESTELLO_HEAL_PCT))
	if heal_amt > 0:
		health.heal(heal_amt)
	# VFX flash dorado.
	if sprite != null:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 1.8, 1.0, 1.0), 0.1)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)


func _apply_salto_landing() -> void:
	# AoE landing damage + STUN al player.
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * SALTO_LANDING_DAMAGE_MULT))
	var stun_data: StatusEffectData = load("res://resources/status_effects/stun.tres") as StatusEffectData
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = SALTO_LANDING_RADIUS
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 0b10000
	query.collide_with_areas = true
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is HurtboxComponent:
			var hb: HurtboxComponent = collider
			if hb.team == team:
				continue
			hb.receive_hit(dmg, null, 0)
			if stun_data != null:
				var defender: Node = hb.get_parent()
				if defender == null:
					continue
				var se: StatusEffectComponent = defender.get_node_or_null("StatusEffects") as StatusEffectComponent
				if se != null:
					se.apply(stun_data, self)
	if CameraShake != null:
		CameraShake.shake(0.20, 10.0)


# ─── Lanza de Luz Penetrante (F2) ───────────────────────────────────────────

func _spawn_lanza_line() -> void:
	if _lanza_line != null and is_instance_valid(_lanza_line):
		_lanza_line.queue_free()
	_lanza_line = Line2D.new()
	_lanza_line.width = LANZA_WIDTH
	_lanza_line.default_color = Color(1.0, 0.95, 0.55, 0.8)
	_lanza_line.z_index = 5
	get_tree().current_scene.add_child(_lanza_line)
	_update_lanza_line()


func _update_lanza_line() -> void:
	if _lanza_line == null or not is_instance_valid(_lanza_line):
		return
	var origin: Vector2 = global_position + Vector2(0, -45)
	var endp: Vector2 = origin + _lanza_aim_dir * LANZA_LENGTH
	_lanza_line.points = PackedVector2Array([origin, endp])


func _despawn_lanza_line() -> void:
	if _lanza_line == null or not is_instance_valid(_lanza_line):
		return
	var tween: Tween = _lanza_line.create_tween()
	tween.tween_property(_lanza_line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_lanza_line.queue_free)
	_lanza_line = null


## Tick damage: PhysicsShapeQuery con rectángulo angosto a lo largo del laser.
## Aplica damage a HurtboxComponents intersectados.
func _apply_lanza_tick_damage() -> void:
	if _target == null:
		return
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return
	var origin: Vector2 = global_position + Vector2(0, -45)
	var midpoint: Vector2 = origin + _lanza_aim_dir * (LANZA_LENGTH * 0.5)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(LANZA_LENGTH, LANZA_WIDTH * 1.5)
	query.shape = rect
	query.transform = Transform2D(_lanza_aim_dir.angle(), midpoint)
	query.collision_mask = 0b10000
	query.collide_with_areas = true
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * LANZA_DAMAGE_MULT))
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 8)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is HurtboxComponent:
			var hb: HurtboxComponent = collider
			if hb.team == team:
				continue
			hb.receive_hit(dmg, null, 0)
