extends Enemy
class_name BossHeraldo

## Heraldo del Vacío — Boss R4 Mage/NEUTRO.
##
## Fantasía: hechicero pesado y lento, mago de denegación de área. El player
## debe moverse SIEMPRE — quedarse parado es muerte. NO invoca minions.
##
## Patrones F1 (4):
##   1. Orbe del Vacío    — fireball grande, alto daño, CD 4s, telegraph 0.7s.
##   2. Campo de Daño     — AoE marker + PersistentHazard 4s, CD 8s, telegraph 1.0s.
##   3. Onda Expansiva    — AoE radial centrada en mage, CD 10s, telegraph 1.2s.
##   4. Mini-Meteoros     — 3 AoeTelegraph + fireballs que caen, CD 12s, telegraph 1.0s.
##
## F2 unlock (HP <= 50%):
##   5. Eco Eterno        — ÚNICA VEZ al cruzar 50% HP, spawna 2 PersistentHazard
##                          permanentes en esquinas fijas que duran toda F2.

# ─── Estados boss-específicos ────────────────────────────────────────────────
const BOSS_STATE_ORBE_WINDUP: int = 400
const BOSS_STATE_ORBE_FIRE: int = 401
const BOSS_STATE_CAMPO_WINDUP: int = 410
const BOSS_STATE_CAMPO_SPAWN: int = 411
const BOSS_STATE_ONDA_WINDUP: int = 420
const BOSS_STATE_ONDA_ACTIVE: int = 421
const BOSS_STATE_METEOROS_WINDUP: int = 430
const BOSS_STATE_METEOROS_FALL: int = 431

# ─── Config patrones ─────────────────────────────────────────────────────────
const ORBE_WINDUP: float = 0.7
const ORBE_DAMAGE_MULT: float = 1.4
const ORBE_COOLDOWN_MIN: float = 3.5
const ORBE_COOLDOWN_MAX: float = 5.0

const CAMPO_WINDUP: float = 1.0
const CAMPO_HAZARD_DURATION: float = 4.0
const CAMPO_HAZARD_RADIUS: float = 50.0
const CAMPO_HAZARD_DAMAGE: int = 5
const CAMPO_HAZARD_TICK: float = 0.5
const CAMPO_COOLDOWN_MIN: float = 7.0
const CAMPO_COOLDOWN_MAX: float = 9.5

const ONDA_WINDUP: float = 1.2
const ONDA_RADIUS: float = 120.0
const ONDA_ACTIVE: float = 0.4
const ONDA_DAMAGE_MULT: float = 1.5
const ONDA_COOLDOWN_MIN: float = 9.0
const ONDA_COOLDOWN_MAX: float = 11.5

const METEOROS_WINDUP: float = 1.0
const METEOROS_FALL_DELAY: float = 0.4
const METEOROS_COUNT: int = 3
const METEOROS_RADIUS: float = 55.0
const METEOROS_DAMAGE_MULT: float = 1.1
const METEOROS_COOLDOWN_MIN: float = 11.0
const METEOROS_COOLDOWN_MAX: float = 13.0

const ECO_ETERNO_RADIUS: float = 70.0
const ECO_ETERNO_DAMAGE: int = 8
const ECO_ETERNO_TICK: float = 0.5
## Posiciones fijas relativas al boss para los hazards permanentes de F2.
const ECO_ETERNO_OFFSET_LEFT: Vector2 = Vector2(-350, 0)
const ECO_ETERNO_OFFSET_RIGHT: Vector2 = Vector2(350, 0)
## Duración "permanente" desde la perspectiva del jugador: cubre toda la F2 esperada.
const ECO_ETERNO_DURATION: float = 120.0

const PHASE_2_COOLDOWN_FACTOR: float = 0.80

# ─── Estado runtime ──────────────────────────────────────────────────────────
var _phase: int = 1
var _orbe_cooldown: float = 2.0
var _campo_cooldown: float = 4.5
var _onda_cooldown: float = 6.5
var _meteoros_cooldown: float = 8.0
var _onda_marker: Node2D = null
var _meteoros_markers: Array[Node2D] = []
var _meteoros_target_positions: Array[Vector2] = []
var _meteoros_falling_timer: float = 0.0
var _meteoros_fired: bool = false
var _eco_eterno_spawned: bool = false


func _ready() -> void:
	enemy_class = GameConfig.EnemyClass.MAGE
	rarity = GameConfig.EnemyRarity.R4
	element = ItemData.Element.NEUTRO
	if projectile_scene == null:
		projectile_scene = preload("res://scenes/projectiles/projectile_fireball.tscn")
	super._ready()

	# HP override: 80% del MAGE R4 base — el más tanque de los 3 nuevos bosses.
	health.max_health = int(round(float(GameConfig.enemy_health_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R4)) * 0.80))
	health.current_health = health.max_health

	# Daño base: MAGE R3 × 1.3 (handoff).
	hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MAGE, GameConfig.EnemyRarity.R3)) * 1.3))

	# Velocidad lenta (0.5×).
	speed = GameConfig.enemy_speed_for(GameConfig.EnemyClass.MAGE) * 0.5

	# Sin escudo de cargas.
	if _block_handler != null:
		_block_handler.deactivate()
		hurtbox.shield = null

	# Visual: tinte violeta oscuro vacío, scale 1.8 (tanque).
	if sprite != null:
		sprite.body_color = Color(0.45, 0.20, 0.65, 1.0)
		sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity) * 1.24  ## ~1.8
		sprite.weapon_scale = 1.7

	health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, maximum: int) -> void:
	if _phase == 1 and current <= maximum / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	_phase = 2
	_orbe_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_campo_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_onda_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_meteoros_cooldown *= PHASE_2_COOLDOWN_FACTOR
	if sprite != null:
		sprite.body_color = Color(0.55, 0.10, 0.85, 1.0)
	if CameraShake != null:
		CameraShake.shake(0.35, 14.0)
	# Eco Eterno: spawn de los 2 hazards permanentes.
	if not _eco_eterno_spawned:
		_spawn_eco_eterno()
		_eco_eterno_spawned = true


# ─── State machine ───────────────────────────────────────────────────────────
func _tick_state(delta: float) -> void:
	if _orbe_cooldown > 0.0: _orbe_cooldown -= delta
	if _campo_cooldown > 0.0: _campo_cooldown -= delta
	if _onda_cooldown > 0.0: _onda_cooldown -= delta
	if _meteoros_cooldown > 0.0: _meteoros_cooldown -= delta

	if state >= BOSS_STATE_ORBE_WINDUP:
		_tick_boss_state(delta)
		return

	if state == State.CHASE and _target != null and is_on_floor():
		if _try_start_boss_pattern():
			return

	super._tick_state(delta)


func _try_start_boss_pattern() -> bool:
	var dist: float = _distance_to_target()

	# Onda Expansiva — si player muy cerca (lo aleja).
	if _onda_cooldown <= 0.0 and dist < ONDA_RADIUS * 1.2:
		_change_to_boss_state(BOSS_STATE_ONDA_WINDUP)
		return true

	# Mini-Meteoros — zonal multi-spot.
	if _meteoros_cooldown <= 0.0:
		_change_to_boss_state(BOSS_STATE_METEOROS_WINDUP)
		return true

	# Campo de Daño — denegación de zona donde está el player.
	if _campo_cooldown <= 0.0 and dist < 500.0:
		_change_to_boss_state(BOSS_STATE_CAMPO_WINDUP)
		return true

	# Orbe del Vacío — filler ranged.
	if _orbe_cooldown <= 0.0:
		_change_to_boss_state(BOSS_STATE_ORBE_WINDUP)
		return true

	return false


func _change_to_boss_state(new_state: int) -> void:
	if state == State.TELEGRAPH or state == State.SKILL_TELEGRAPH:
		sprite.end_telegraph()

	state = new_state
	_state_timer = 0.0

	match new_state:
		BOSS_STATE_ORBE_WINDUP:
			sprite.start_telegraph(ORBE_WINDUP)
			_face_target()

		BOSS_STATE_ORBE_FIRE:
			_spawn_orbe_vacio()

		BOSS_STATE_CAMPO_WINDUP:
			sprite.start_telegraph(CAMPO_WINDUP)
			_face_target()
			_spawn_campo_marker()

		BOSS_STATE_CAMPO_SPAWN:
			_spawn_campo_hazard()

		BOSS_STATE_ONDA_WINDUP:
			sprite.start_telegraph(ONDA_WINDUP)
			_spawn_onda_marker()

		BOSS_STATE_ONDA_ACTIVE:
			_apply_onda_damage()
			if CameraShake != null:
				CameraShake.shake(0.30, 12.0)

		BOSS_STATE_METEOROS_WINDUP:
			sprite.start_telegraph(METEOROS_WINDUP)
			_face_target()
			_spawn_meteoros_markers()

		BOSS_STATE_METEOROS_FALL:
			_meteoros_falling_timer = 0.0
			_meteoros_fired = false


func _tick_boss_state(delta: float) -> void:
	_state_timer += delta

	match state:
		BOSS_STATE_ORBE_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= ORBE_WINDUP:
				_change_to_boss_state(BOSS_STATE_ORBE_FIRE)

		BOSS_STATE_ORBE_FIRE:
			velocity.x = 0.0
			if _state_timer >= 0.3:
				_orbe_cooldown = randf_range(ORBE_COOLDOWN_MIN, ORBE_COOLDOWN_MAX)
				if _phase == 2:
					_orbe_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_CAMPO_WINDUP:
			velocity.x = 0.0
			if _state_timer >= CAMPO_WINDUP:
				_change_to_boss_state(BOSS_STATE_CAMPO_SPAWN)

		BOSS_STATE_CAMPO_SPAWN:
			velocity.x = 0.0
			if _state_timer >= 0.2:
				_campo_cooldown = randf_range(CAMPO_COOLDOWN_MIN, CAMPO_COOLDOWN_MAX)
				if _phase == 2:
					_campo_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_ONDA_WINDUP:
			velocity.x = 0.0
			if _state_timer >= ONDA_WINDUP:
				_change_to_boss_state(BOSS_STATE_ONDA_ACTIVE)

		BOSS_STATE_ONDA_ACTIVE:
			velocity.x = 0.0
			if _state_timer >= ONDA_ACTIVE:
				_cleanup_onda_marker()
				_onda_cooldown = randf_range(ONDA_COOLDOWN_MIN, ONDA_COOLDOWN_MAX)
				if _phase == 2:
					_onda_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_METEOROS_WINDUP:
			velocity.x = 0.0
			if _state_timer >= METEOROS_WINDUP:
				_change_to_boss_state(BOSS_STATE_METEOROS_FALL)

		BOSS_STATE_METEOROS_FALL:
			velocity.x = 0.0
			_meteoros_falling_timer += delta
			if not _meteoros_fired and _meteoros_falling_timer >= METEOROS_FALL_DELAY:
				_apply_meteoros_damage()
				_meteoros_fired = true
			if _meteoros_falling_timer >= METEOROS_FALL_DELAY + 0.3:
				_cleanup_meteoros_markers()
				_meteoros_cooldown = randf_range(METEOROS_COOLDOWN_MIN, METEOROS_COOLDOWN_MAX)
				if _phase == 2:
					_meteoros_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0


# ─── Patrones: implementación ────────────────────────────────────────────────

## Orbe del Vacío — fireball escalado 1.5× con daño alto.
func _spawn_orbe_vacio() -> void:
	if projectile_scene == null or _target == null:
		return
	var proj_node: Node2D = projectile_scene.instantiate()
	if not proj_node is Projectile:
		proj_node.queue_free()
		return
	var proj: Projectile = proj_node
	proj.global_position = global_position + Vector2(0, -50)
	var aim: Vector2 = _target.global_position + Vector2(0, -30)
	var dir: Vector2 = (aim - proj.global_position).normalized()
	var dmg: int = int(round(float(hitbox.damage) * ORBE_DAMAGE_MULT))
	proj.launch(dir, dmg, team, element)
	proj.set_source(self)
	proj.scale = Vector2(1.5, 1.5)
	proj.modulate = Color(0.7, 0.3, 1.0, 1.0)
	get_tree().current_scene.add_child(proj)


func _spawn_campo_marker() -> void:
	if _target == null:
		return
	var tele_scene: PackedScene = preload("res://scenes/effects/aoe_telegraph.tscn")
	if tele_scene == null:
		return
	var tele: AoeTelegraph = tele_scene.instantiate() as AoeTelegraph
	tele.global_position = _target.global_position
	tele.setup(CAMPO_HAZARD_RADIUS, CAMPO_WINDUP, Color(0.65, 0.15, 0.65, 0.55))
	get_tree().current_scene.add_child(tele)


func _spawn_campo_hazard() -> void:
	if _target == null:
		return
	var hz_scene: PackedScene = preload("res://scenes/effects/persistent_hazard.tscn")
	if hz_scene == null:
		return
	var hz: PersistentHazard = hz_scene.instantiate() as PersistentHazard
	hz.global_position = _target.global_position
	hz.setup(CAMPO_HAZARD_RADIUS, CAMPO_HAZARD_DURATION, CAMPO_HAZARD_DAMAGE,
		CAMPO_HAZARD_TICK, team, Color(0.65, 0.15, 0.85, 0.55))
	get_tree().current_scene.add_child(hz)


func _spawn_onda_marker() -> void:
	_cleanup_onda_marker()
	var tele_scene: PackedScene = preload("res://scenes/effects/aoe_telegraph.tscn")
	if tele_scene == null:
		return
	var tele: AoeTelegraph = tele_scene.instantiate() as AoeTelegraph
	tele.global_position = global_position
	tele.setup(ONDA_RADIUS, ONDA_WINDUP, Color(0.85, 0.25, 1.0, 0.55))
	get_tree().current_scene.add_child(tele)
	_onda_marker = tele


func _cleanup_onda_marker() -> void:
	if is_instance_valid(_onda_marker):
		_onda_marker.queue_free()
	_onda_marker = null


func _apply_onda_damage() -> void:
	if _target == null:
		return
	var target_hb: HurtboxComponent = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if target_hb == null:
		return
	if global_position.distance_to(_target.global_position) <= ONDA_RADIUS:
		var dmg: int = int(round(float(hitbox.damage) * ONDA_DAMAGE_MULT))
		target_hb.receive_hit(dmg, hitbox, 0)


func _spawn_meteoros_markers() -> void:
	_cleanup_meteoros_markers()
	if _target == null:
		return
	var tele_scene: PackedScene = preload("res://scenes/effects/aoe_telegraph.tscn")
	if tele_scene == null:
		return
	_meteoros_target_positions.clear()
	for i in METEOROS_COUNT:
		var offset_x: float = randf_range(-200.0, 200.0)
		var pos: Vector2 = Vector2(_target.global_position.x + offset_x, _target.global_position.y)
		_meteoros_target_positions.append(pos)
		var tele: AoeTelegraph = tele_scene.instantiate() as AoeTelegraph
		tele.global_position = pos
		tele.setup(METEOROS_RADIUS, METEOROS_WINDUP + METEOROS_FALL_DELAY,
			Color(1.0, 0.35, 0.15, 0.55))
		get_tree().current_scene.add_child(tele)
		_meteoros_markers.append(tele)


func _apply_meteoros_damage() -> void:
	if _target == null:
		return
	var target_hb: HurtboxComponent = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if target_hb == null:
		return
	var dmg: int = int(round(float(hitbox.damage) * METEOROS_DAMAGE_MULT))
	for pos in _meteoros_target_positions:
		if pos.distance_to(_target.global_position) <= METEOROS_RADIUS:
			target_hb.receive_hit(dmg, hitbox, 0)
			return


func _cleanup_meteoros_markers() -> void:
	for m in _meteoros_markers:
		if is_instance_valid(m):
			m.queue_free()
	_meteoros_markers.clear()
	_meteoros_target_positions.clear()


## Eco Eterno: 2 PersistentHazard permanentes al entrar a F2.
## Permanecen hasta que el boss muera (o expire ECO_ETERNO_DURATION).
func _spawn_eco_eterno() -> void:
	var hz_scene: PackedScene = preload("res://scenes/effects/persistent_hazard.tscn")
	if hz_scene == null:
		return
	for offset: Vector2 in [ECO_ETERNO_OFFSET_LEFT, ECO_ETERNO_OFFSET_RIGHT]:
		var hz: PersistentHazard = hz_scene.instantiate() as PersistentHazard
		hz.global_position = global_position + offset
		hz.setup(ECO_ETERNO_RADIUS, ECO_ETERNO_DURATION, ECO_ETERNO_DAMAGE,
			ECO_ETERNO_TICK, team, Color(0.45, 0.10, 0.85, 0.65))
		get_tree().current_scene.add_child(hz)


func _on_died() -> void:
	_cleanup_onda_marker()
	_cleanup_meteoros_markers()
	super._on_died()
