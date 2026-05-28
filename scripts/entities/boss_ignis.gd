extends Enemy
class_name BossIgnis

## Ignis, el Martillo Demente — Boss R4 Zona 2 (Fragua Cenicienta).
## Melee/FUEGO. Imponente, lento, devastador. Mezcla hammer overhead + lava persistente.
##
## Patrones F1:
##  1. Hammer Overhead         — golpe pesado frontal, telegraph 0.7s, daño x1.5.
##  2. Salto Sísmico           — salto largo + landing AoE + PersistentHazard (lava 4s).
##  3. Lluvia de Meteoros      — 3 AoeTelegraph en suelo + drop damage + BURN.
##
## F2 (HP ≤ 50%):
##  4. Sed de Sangre           — buff propio +25% velocidad / -25% recovery, 6s.
##  5. Corte Giratorio         — hitbox rotando 1.5s con avance lento (AoE móvil).
##  Cooldowns -25%.
##
## Sin escudo de cargas — defensa via HP alto y telegrafías legibles.
## Reusa AoeTelegraph + PersistentHazard + STATUS_BURN existentes.

# ─── Estados ─────────────────────────────────────────────────────────────────
const BOSS_STATE_HAMMER_WINDUP: int = 300
const BOSS_STATE_HAMMER_STRIKE: int = 301
const BOSS_STATE_SALTO_WINDUP: int = 310
const BOSS_STATE_SALTO_JUMP: int = 311
const BOSS_STATE_SALTO_LAND: int = 312
const BOSS_STATE_METEOROS_WINDUP: int = 320
const BOSS_STATE_METEOROS_DROP: int = 321
const BOSS_STATE_SED_WINDUP: int = 330
const BOSS_STATE_SED_ACTIVE: int = 331
const BOSS_STATE_GIRATORIO_WINDUP: int = 340
const BOSS_STATE_GIRATORIO_ACTIVE: int = 341

# ─── Config patrones ─────────────────────────────────────────────────────────
const HAMMER_WINDUP_SECONDS: float = 0.7
const HAMMER_STRIKE_SECONDS: float = 0.35
const HAMMER_DAMAGE_MULT: float = 1.5
const HAMMER_RANGE: float = 90.0
const HAMMER_COOLDOWN_MIN: float = 3.5
const HAMMER_COOLDOWN_MAX: float = 5.0

const SALTO_WINDUP_SECONDS: float = 0.55
const SALTO_AIR_SECONDS: float = 0.85
const SALTO_JUMP_VY: float = -1100.0
const SALTO_LANDING_RADIUS: float = 100.0
const SALTO_LANDING_DAMAGE_MULT: float = 1.4
const SALTO_LAVA_RADIUS: float = 60.0
const SALTO_LAVA_DURATION: float = 4.0
const SALTO_LAVA_DAMAGE_PER_TICK: int = 4
const SALTO_LAVA_TICK_INTERVAL: float = 0.5
const SALTO_COOLDOWN_MIN: float = 8.0
const SALTO_COOLDOWN_MAX: float = 11.0

const METEOROS_WINDUP_SECONDS: float = 0.9
const METEOROS_DROP_TIME: float = 0.55
const METEOROS_DURATION: float = 1.0
const METEOROS_COUNT: int = 3
const METEOROS_SPREAD: float = 90.0
const METEOROS_RADIUS: float = 48.0
const METEOROS_DAMAGE_MULT: float = 1.2
const METEOROS_COOLDOWN_MIN: float = 9.0
const METEOROS_COOLDOWN_MAX: float = 12.0

const SED_WINDUP_SECONDS: float = 0.6
const SED_DURATION: float = 6.0
const SED_SPEED_MULT: float = 1.25
const SED_COOLDOWN_MIN: float = 15.0
const SED_COOLDOWN_MAX: float = 20.0

const GIRATORIO_WINDUP_SECONDS: float = 0.8
const GIRATORIO_ACTIVE_SECONDS: float = 1.5
const GIRATORIO_RADIUS: float = 75.0
const GIRATORIO_DAMAGE_MULT: float = 1.1
const GIRATORIO_DAMAGE_TICK: float = 0.25
const GIRATORIO_MOVE_SPEED: float = 80.0
const GIRATORIO_COOLDOWN_MIN: float = 11.0
const GIRATORIO_COOLDOWN_MAX: float = 14.0

const PHASE_2_COOLDOWN_FACTOR: float = 0.75

# ─── Runtime ─────────────────────────────────────────────────────────────────
var _phase: int = 1
var _hammer_cd: float = 2.0
var _salto_cd: float = 4.0
var _meteoros_cd: float = 6.0
var _sed_cd: float = 5.0
var _giratorio_cd: float = 8.0
var _sed_active_timer: float = 0.0
var _orig_speed: float = 0.0
var _salto_landing_x: float = 0.0
var _giratorio_damage_accum: float = 0.0


func _ready() -> void:
	enemy_class = GameConfig.EnemyClass.MELEE
	rarity = GameConfig.EnemyRarity.R4
	element = ItemData.Element.FUEGO
	super._ready()

	# HP: 1.1× del MELEE R4 base (boss imponente, no frágil).
	health.max_health = int(round(float(GameConfig.enemy_health_with_rarity(
		GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R4)) * 1.10))
	health.current_health = health.max_health

	# Velocidad lenta, 0.85× normal.
	speed = GameConfig.enemy_speed_for(GameConfig.EnemyClass.MELEE) * 0.85
	_orig_speed = speed

	# Daño base: x1.3 del R3 melee.
	hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.3))

	# Sin escudo de cargas.
	if _block_handler != null:
		_block_handler.deactivate()
		hurtbox.shield = null

	# Visual: tinte rojo brasa intenso, scale más grande.
	if sprite != null:
		sprite.body_color = Color(1.0, 0.30, 0.10, 1.0)
		sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity) * 1.15
		sprite.weapon_scale = 1.8

	health.health_changed.connect(_on_health_changed)


## Override: Ignis es MELEE class pero blande un martillo. Hitbox tipo HAMMER.
func _implicit_weapon_visual_type() -> int:
	return 4  # HAMMER


func _on_health_changed(current: int, maximum: int) -> void:
	if _phase == 1 and current <= maximum / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	_phase = 2
	_hammer_cd *= PHASE_2_COOLDOWN_FACTOR
	_salto_cd *= PHASE_2_COOLDOWN_FACTOR
	_meteoros_cd *= PHASE_2_COOLDOWN_FACTOR
	_sed_cd = 1.5  # casi disponible
	_giratorio_cd = 3.0
	if sprite != null:
		sprite.body_color = Color(1.2, 0.20, 0.05, 1.0)
	if CameraShake != null:
		CameraShake.shake(0.35, 14.0)


# ─── State machine override ──────────────────────────────────────────────────
func _tick_state(delta: float) -> void:
	# Cooldowns y timers globales.
	if _hammer_cd > 0.0: _hammer_cd -= delta
	if _salto_cd > 0.0: _salto_cd -= delta
	if _meteoros_cd > 0.0: _meteoros_cd -= delta
	if _sed_cd > 0.0: _sed_cd -= delta
	if _giratorio_cd > 0.0: _giratorio_cd -= delta

	# Tick del buff Sed de Sangre (boss-side).
	if _sed_active_timer > 0.0:
		_sed_active_timer -= delta
		if _sed_active_timer <= 0.0:
			_end_sed_de_sangre_boss()

	# Branch en estado boss-específico.
	if state >= BOSS_STATE_HAMMER_WINDUP:
		_tick_boss_state(delta)
		return

	# En CHASE, intentar arrancar patrón.
	if state == State.CHASE and _target != null and is_on_floor():
		if _try_start_pattern():
			return

	super._tick_state(delta)


func _try_start_pattern() -> bool:
	var dist: float = _distance_to_target()

	# F2 only: Sed de Sangre prioridad alta (auto-buff).
	if _phase == 2 and _sed_cd <= 0.0 and _sed_active_timer <= 0.0:
		_change_to_boss_state(BOSS_STATE_SED_WINDUP)
		return true

	# F2 only: Corte Giratorio — close-mid range.
	if _phase == 2 and _giratorio_cd <= 0.0 and dist < GIRATORIO_RADIUS * 2.0:
		_change_to_boss_state(BOSS_STATE_GIRATORIO_WINDUP)
		return true

	# Lluvia de Meteoros — cualquier distancia (AoE en suelo bajo player).
	if _meteoros_cd <= 0.0 and dist < detect_range:
		_change_to_boss_state(BOSS_STATE_METEOROS_WINDUP)
		return true

	# Salto Sísmico — distancia media-larga (gap closer + lava).
	if _salto_cd <= 0.0 and dist > HAMMER_RANGE * 1.2 and dist < detect_range * 0.85:
		_change_to_boss_state(BOSS_STATE_SALTO_WINDUP)
		return true

	# Hammer Overhead — close range.
	if _hammer_cd <= 0.0 and dist < HAMMER_RANGE * 1.2:
		_change_to_boss_state(BOSS_STATE_HAMMER_WINDUP)
		return true

	return false


func _change_to_boss_state(new_state: int) -> void:
	# Match patrón de boss_duelista — no extiende _change_state del padre,
	# solo setea state + timer + facing + telegraph visual.
	state = new_state
	_state_timer = 0.0
	_face_target()
	hitbox.set_active(false)
	match new_state:
		BOSS_STATE_HAMMER_WINDUP:
			sprite.start_telegraph(HAMMER_WINDUP_SECONDS)
		BOSS_STATE_SALTO_WINDUP:
			sprite.start_telegraph(SALTO_WINDUP_SECONDS)
		BOSS_STATE_METEOROS_WINDUP:
			sprite.start_telegraph(METEOROS_WINDUP_SECONDS)
			_spawn_meteoros_telegraphs()
		BOSS_STATE_SED_WINDUP:
			sprite.start_telegraph(SED_WINDUP_SECONDS)
		BOSS_STATE_GIRATORIO_WINDUP:
			sprite.start_telegraph(GIRATORIO_WINDUP_SECONDS)


func _tick_boss_state(delta: float) -> void:
	match state:
		BOSS_STATE_HAMMER_WINDUP:
			velocity.x = 0.0
			if _state_timer >= HAMMER_WINDUP_SECONDS:
				_enter_hammer_strike()
		BOSS_STATE_HAMMER_STRIKE:
			velocity.x = 0.0
			if _state_timer >= HAMMER_STRIKE_SECONDS:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, GameConfig.EnemyRarity.R3)
				_hammer_cd = randf_range(HAMMER_COOLDOWN_MIN, HAMMER_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_SALTO_WINDUP:
			velocity.x = 0.0
			if _state_timer >= SALTO_WINDUP_SECONDS:
				_salto_landing_x = _target.global_position.x if _target != null else global_position.x
				velocity.y = SALTO_JUMP_VY
				velocity.x = signf(_salto_landing_x - global_position.x) * 300.0
				state = BOSS_STATE_SALTO_JUMP
				_state_timer = 0.0
		BOSS_STATE_SALTO_JUMP:
			# Manteniendo arco — el _apply_gravity del padre se aplica por estar en aire.
			if _target != null:
				velocity.x = signf(_salto_landing_x - global_position.x) * 300.0
			if _state_timer >= SALTO_AIR_SECONDS or is_on_floor():
				_enter_salto_land()
		BOSS_STATE_SALTO_LAND:
			velocity.x = 0.0
			if _state_timer >= 0.25:
				_salto_cd = randf_range(SALTO_COOLDOWN_MIN, SALTO_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_change_state(State.RECOVERY)

		BOSS_STATE_METEOROS_WINDUP:
			velocity.x = 0.0
			if _state_timer >= METEOROS_WINDUP_SECONDS:
				state = BOSS_STATE_METEOROS_DROP
				_state_timer = 0.0
		BOSS_STATE_METEOROS_DROP:
			velocity.x = 0.0
			if _state_timer >= METEOROS_DROP_TIME and not _r3_drop_damage_applied:
				_r3_drop_damage_applied = true
				_r3_apply_lluvia_damage(true)
			if _state_timer >= METEOROS_DURATION:
				_meteoros_cd = randf_range(METEOROS_COOLDOWN_MIN, METEOROS_COOLDOWN_MAX) \
					* (PHASE_2_COOLDOWN_FACTOR if _phase == 2 else 1.0)
				_r3_drop_damage_applied = false
				_change_state(State.RECOVERY)

		BOSS_STATE_SED_WINDUP:
			velocity.x = 0.0
			if _state_timer >= SED_WINDUP_SECONDS:
				_activate_sed_de_sangre_boss()
				_sed_cd = randf_range(SED_COOLDOWN_MIN, SED_COOLDOWN_MAX)
				_change_state(State.RECOVERY)

		BOSS_STATE_GIRATORIO_WINDUP:
			velocity.x = 0.0
			if _state_timer >= GIRATORIO_WINDUP_SECONDS:
				state = BOSS_STATE_GIRATORIO_ACTIVE
				_state_timer = 0.0
				_giratorio_damage_accum = 0.0
				hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
					GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * GIRATORIO_DAMAGE_MULT))
				hitbox.set_active(true)
		BOSS_STATE_GIRATORIO_ACTIVE:
			# Avance lento hacia el player.
			if _target != null:
				velocity.x = signf(_target.global_position.x - global_position.x) * GIRATORIO_MOVE_SPEED
			# Tick damage manual via hitbox monitoring (ya activo).
			if _state_timer >= GIRATORIO_ACTIVE_SECONDS:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, GameConfig.EnemyRarity.R3)
				_giratorio_cd = randf_range(GIRATORIO_COOLDOWN_MIN, GIRATORIO_COOLDOWN_MAX)
				_change_state(State.RECOVERY)


# ─── Hammer Strike ────────────────────────────────────────────────────────────
func _enter_hammer_strike() -> void:
	state = BOSS_STATE_HAMMER_STRIKE
	_state_timer = 0.0
	hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * HAMMER_DAMAGE_MULT))
	hitbox.set_active(true)


# ─── Salto Sísmico ────────────────────────────────────────────────────────────
func _enter_salto_land() -> void:
	state = BOSS_STATE_SALTO_LAND
	_state_timer = 0.0
	velocity.x = 0.0
	# AoE landing damage.
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * SALTO_LANDING_DAMAGE_MULT))
	_apply_radial_damage(global_position, SALTO_LANDING_RADIUS, dmg)
	# Spawn lava PersistentHazard donde aterrizó.
	_spawn_lava_at(global_position)
	# Screen shake.
	if CameraShake != null:
		CameraShake.shake(0.25, 10.0)


func _spawn_lava_at(pos: Vector2) -> void:
	var scene: PackedScene = load("res://scenes/effects/persistent_hazard.tscn") as PackedScene
	if scene == null:
		return
	var hz: PersistentHazard = scene.instantiate() as PersistentHazard
	if hz == null:
		return
	hz.global_position = pos
	hz.setup(SALTO_LAVA_RADIUS, SALTO_LAVA_DURATION, SALTO_LAVA_DAMAGE_PER_TICK, \
		SALTO_LAVA_TICK_INTERVAL, team, Color(1.0, 0.35, 0.05, 0.65))
	get_tree().current_scene.add_child(hz)


# ─── Meteoros (reusa pipeline R3 Mage existente) ──────────────────────────────
func _spawn_meteoros_telegraphs() -> void:
	# Setup _r3_drop_positions con METEOROS_COUNT en spread propio.
	if _target == null:
		_r3_drop_positions.clear()
		return
	var center: Vector2 = _target.global_position
	var y_impact: float = center.y + 20.0
	_r3_drop_positions = [
		Vector2(center.x - METEOROS_SPREAD, y_impact),
		Vector2(center.x, y_impact),
		Vector2(center.x + METEOROS_SPREAD, y_impact),
	]
	var scene: PackedScene = load("res://scenes/effects/aoe_telegraph.tscn") as PackedScene
	if scene == null:
		return
	for pos: Vector2 in _r3_drop_positions:
		var tele: AoeTelegraph = scene.instantiate() as AoeTelegraph
		if tele == null:
			continue
		tele.global_position = pos
		tele.setup(METEOROS_RADIUS, METEOROS_DROP_TIME + 0.1, Color(1.0, 0.3, 0.1, 0.55))
		get_tree().current_scene.add_child(tele)


# ─── Sed de Sangre (boss variant) ─────────────────────────────────────────────
func _activate_sed_de_sangre_boss() -> void:
	_sed_active_timer = SED_DURATION
	speed = _orig_speed * SED_SPEED_MULT
	if sprite != null:
		sprite.modulate = Color(1.3, 0.6, 0.4, 1.0)


func _end_sed_de_sangre_boss() -> void:
	speed = _orig_speed
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)


# ─── Helpers ──────────────────────────────────────────────────────────────────
func _apply_radial_damage(pos: Vector2, radius: float, damage: int) -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	query.shape = circle
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 0b10000
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is HurtboxComponent:
			var hb: HurtboxComponent = collider
			if hb.team == team:
				continue
			hb.receive_hit(damage, null, 0)
