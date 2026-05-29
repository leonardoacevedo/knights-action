extends Enemy
class_name BossDuelista

## Duelista de las Cenizas — Boss R4 Melee/FUEGO.
##
## Fantasía: duelista veloz y elegante. Lee al jugador con su parry stance —
## castiga el botón-mashing devolviendo daño x2. Recompensa al que espera huecos.
##
## Sin escudo de cargas (a diferencia del Guardián). Su defensa ES el parry.
## Hereda de Enemy para movimiento, salto, facing y target detection.
##
## Patrones F1 (4):
##   1. Tajo doble rápido       — 2 hits seguidos, CD 4s, telegraph 0.4s.
##   2. Embestida ígnea         — dash largo con slash trail naranja, telegraph 0.6s.
##   3. Parry Stance            — 1s defensivo. Si lo golpean, contraataque x2.
##   4. Combo Final             — 3 cortes + overhead pesado, telegraph 0.8s.
##
## F2 unlock (HP <= 50%):
##   5. Llamarada en Arco       — AoE cono frontal radio 80px, telegraph 1.0s.
##   Todos los CDs -20%.

# ─── Estados boss-específicos ────────────────────────────────────────────────
const BOSS_STATE_TAJO_DOBLE_WINDUP: int = 200
const BOSS_STATE_TAJO_DOBLE_HIT1: int = 201
const BOSS_STATE_TAJO_DOBLE_GAP: int = 202
const BOSS_STATE_TAJO_DOBLE_HIT2: int = 203
const BOSS_STATE_EMBESTIDA_WINDUP: int = 210
const BOSS_STATE_EMBESTIDA_DASH: int = 211
const BOSS_STATE_PARRY_WINDUP: int = 220
const BOSS_STATE_PARRY_ACTIVE: int = 221
const BOSS_STATE_PARRY_COUNTER: int = 222
const BOSS_STATE_COMBO_WINDUP: int = 230
const BOSS_STATE_COMBO_SLASH1: int = 231
const BOSS_STATE_COMBO_SLASH2: int = 232
const BOSS_STATE_COMBO_SLASH3: int = 233
const BOSS_STATE_COMBO_OVERHEAD: int = 234
const BOSS_STATE_LLAMARADA_WINDUP: int = 240
const BOSS_STATE_LLAMARADA_ACTIVE: int = 241

# ─── Config patrones ─────────────────────────────────────────────────────────
const TAJO_WINDUP_SECONDS: float = 0.4
const TAJO_HIT_DURATION: float = 0.12
const TAJO_GAP_SECONDS: float = 0.10
const TAJO_DAMAGE_MULT: float = 0.9
const TAJO_COOLDOWN_MIN: float = 3.5
const TAJO_COOLDOWN_MAX: float = 4.5

const EMBESTIDA_WINDUP_SECONDS: float = 0.6
const EMBESTIDA_DASH_SECONDS: float = 0.5
const EMBESTIDA_SPEED: float = 950.0
const EMBESTIDA_DAMAGE_MULT: float = 1.3
const EMBESTIDA_TRIGGER_DISTANCE: float = 400.0
const EMBESTIDA_COOLDOWN_MIN: float = 6.5
const EMBESTIDA_COOLDOWN_MAX: float = 8.0

const PARRY_WINDUP_SECONDS: float = 0.5
const PARRY_ACTIVE_SECONDS: float = 1.0
const PARRY_COUNTER_DAMAGE_MULT: float = 2.0
const PARRY_COUNTER_DURATION: float = 0.4
const PARRY_COOLDOWN_MIN: float = 9.0
const PARRY_COOLDOWN_MAX: float = 11.0

const COMBO_WINDUP_SECONDS: float = 0.8
const COMBO_SLASH_DURATION: float = 0.15
const COMBO_SLASH_DAMAGE_MULT: float = 1.0
const COMBO_OVERHEAD_DURATION: float = 0.3
const COMBO_OVERHEAD_DAMAGE_MULT: float = 1.6
const COMBO_COOLDOWN_MIN: float = 11.0
const COMBO_COOLDOWN_MAX: float = 13.0

const LLAMARADA_WINDUP_SECONDS: float = 1.0
const LLAMARADA_ACTIVE_SECONDS: float = 0.5
const LLAMARADA_RADIUS: float = 80.0
const LLAMARADA_DAMAGE_MULT: float = 1.5
const LLAMARADA_COOLDOWN_MIN: float = 13.0
const LLAMARADA_COOLDOWN_MAX: float = 16.0

const PHASE_2_COOLDOWN_FACTOR: float = 0.80  ## -20% en F2

# ─── Estado runtime ──────────────────────────────────────────────────────────
var _phase: int = 1
var _tajo_cooldown: float = 2.0
var _embestida_cooldown: float = 4.0
var _parry_cooldown: float = 7.0
var _combo_cooldown: float = 9.0
var _llamarada_cooldown: float = 5.0  ## se ignora hasta F2

var _embestida_direction: int = 1
var _parry_trail: Line2D = null
var _parry_triggered: bool = false  ## flag: el player conectó durante parry
var _llamarada_marker: Node2D = null


func _ready() -> void:
	enemy_class = GameConfig.EnemyClass.MELEE
	rarity = GameConfig.EnemyRarity.R4
	element = ItemData.Element.FUEGO
	super._ready()

	# HP override: 60% del MELEE R4 base (frágil, veloz).
	health.max_health = int(round(float(GameConfig.enemy_health_with_rarity(
		GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R4)) * 0.60))
	health.current_health = health.max_health

	# Velocidad 1.5x del melee normal.
	speed = GameConfig.enemy_speed_for(GameConfig.EnemyClass.MELEE) * 1.5

	# Damage base x1.2 sobre el melee R3 (el handoff pidió "1.2× del melee R3").
	hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.2))

	# Sin escudo: desactivar el handler heredado.
	if _block_handler != null:
		_block_handler.deactivate()
		hurtbox.shield = null

	# Visual: tinte naranja-rojizo (fuego). Scale 1.5x sobre rarity_scale R4 (1.45) → ~2.18x.
	# Lectura del handoff: "scale 1.5×" sobre el rarity_scale ya aplicado por enemy.gd.
	if sprite != null:
		sprite.body_color = Color(1.0, 0.45, 0.20, 1.0)
		sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity) * 1.05
		sprite.weapon_scale = 1.6

	# Conectar hurtbox.hit_received para detectar parry trigger.
	hurtbox.hit_received.connect(_on_hit_received_for_parry)

	health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, maximum: int) -> void:
	if _phase == 1 and current <= maximum / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	_phase = 2
	_tajo_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_embestida_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_parry_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_combo_cooldown *= PHASE_2_COOLDOWN_FACTOR
	# Llamarada arranca disponible enseguida en F2.
	_llamarada_cooldown = 2.5
	# Visual feedback de enrage: tinte más rojo intenso + flash de screenshake.
	if sprite != null:
		sprite.body_color = Color(1.15, 0.35, 0.10, 1.0)
	if CameraShake != null:
		CameraShake.shake(12.0, 0.30)


# ─── Detección de parry: si lo golpean durante PARRY_ACTIVE → trigger ────────
func _on_hit_received_for_parry(_amount: int, source: HitboxComponent, _was_advantage: int) -> void:
	# Solo nos importa si estamos en PARRY_ACTIVE Y el source es del player (team 1).
	if state != BOSS_STATE_PARRY_ACTIVE:
		return
	if source == null or source.team == team:
		return
	_parry_triggered = true
	# Transición inmediata al contraataque.
	_change_to_boss_state(BOSS_STATE_PARRY_COUNTER)


# ─── State machine override ──────────────────────────────────────────────────
func _tick_state(delta: float) -> void:
	# Cooldowns.
	if _tajo_cooldown > 0.0: _tajo_cooldown -= delta
	if _embestida_cooldown > 0.0: _embestida_cooldown -= delta
	if _parry_cooldown > 0.0: _parry_cooldown -= delta
	if _combo_cooldown > 0.0: _combo_cooldown -= delta
	if _llamarada_cooldown > 0.0: _llamarada_cooldown -= delta

	if state >= BOSS_STATE_TAJO_DOBLE_WINDUP:
		_tick_boss_state(delta)
		return

	if state == State.CHASE and _target != null and is_on_floor():
		if _try_start_boss_pattern():
			return

	super._tick_state(delta)


func _try_start_boss_pattern() -> bool:
	var dist: float = _distance_to_target()

	# F2: Llamarada en arco — mid-close range, contra player apegado.
	if _phase == 2 and _llamarada_cooldown <= 0.0 and dist < LLAMARADA_RADIUS * 1.3:
		_change_to_boss_state(BOSS_STATE_LLAMARADA_WINDUP)
		return true

	# Combo Final — close range, sequence largo.
	if _combo_cooldown <= 0.0 and dist < attack_range * 1.5:
		_change_to_boss_state(BOSS_STATE_COMBO_WINDUP)
		return true

	# Parry Stance — defensa proactiva, mid-close.
	if _parry_cooldown <= 0.0 and dist < attack_range * 2.5:
		_change_to_boss_state(BOSS_STATE_PARRY_WINDUP)
		return true

	# Embestida ígnea — mid-far range.
	if _embestida_cooldown <= 0.0 and dist > attack_range * 1.8 and dist < EMBESTIDA_TRIGGER_DISTANCE:
		_change_to_boss_state(BOSS_STATE_EMBESTIDA_WINDUP)
		return true

	# Tajo doble — close range filler.
	if _tajo_cooldown <= 0.0 and dist < attack_range * 1.4:
		_change_to_boss_state(BOSS_STATE_TAJO_DOBLE_WINDUP)
		return true

	return false


func _change_to_boss_state(new_state: int) -> void:
	# Cleanup heredado para telegraph.
	if state == State.TELEGRAPH or state == State.SKILL_TELEGRAPH:
		sprite.end_telegraph()

	state = new_state
	_state_timer = 0.0

	match new_state:
		BOSS_STATE_TAJO_DOBLE_WINDUP:
			sprite.start_telegraph(TAJO_WINDUP_SECONDS)
			_face_target()

		BOSS_STATE_TAJO_DOBLE_HIT1, BOSS_STATE_TAJO_DOBLE_HIT2:
			_face_target()
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
				GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.2 * TAJO_DAMAGE_MULT))
			hitbox.set_active(true)

		BOSS_STATE_TAJO_DOBLE_GAP:
			hitbox.set_active(false)

		BOSS_STATE_EMBESTIDA_WINDUP:
			sprite.start_telegraph(EMBESTIDA_WINDUP_SECONDS)
			_face_target()
			_embestida_direction = current_facing

		BOSS_STATE_EMBESTIDA_DASH:
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
				GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.2 * EMBESTIDA_DAMAGE_MULT))
			hitbox.set_active(true)
			_spawn_embestida_trail()
			if CameraShake != null:
				CameraShake.shake(4.0, 0.10)

		BOSS_STATE_PARRY_WINDUP:
			sprite.start_telegraph(PARRY_WINDUP_SECONDS)
			_face_target()

		BOSS_STATE_PARRY_ACTIVE:
			# Pose defensiva (BLOCK aura azul) + tinte rojo (parry).
			sprite.set_state(StickFigure.State.BLOCK)
			sprite.start_block_aura()
			if sprite != null:
				sprite.modulate = Color(1.5, 0.7, 0.7, 1.0)
			_parry_triggered = false

		BOSS_STATE_PARRY_COUNTER:
			# Contraataque inmediato con daño x2. Hitbox activa breve.
			sprite.end_block_aura()
			if sprite != null:
				sprite.modulate = Color.WHITE
			sprite.set_state(StickFigure.State.ATTACK)
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
				GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.2 * PARRY_COUNTER_DAMAGE_MULT))
			hitbox.set_active(true)
			if CameraShake != null:
				CameraShake.shake(8.0, 0.20)

		BOSS_STATE_COMBO_WINDUP:
			sprite.start_telegraph(COMBO_WINDUP_SECONDS)
			_face_target()

		BOSS_STATE_COMBO_SLASH1, BOSS_STATE_COMBO_SLASH2, BOSS_STATE_COMBO_SLASH3:
			_face_target()
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
				GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.2 * COMBO_SLASH_DAMAGE_MULT))
			hitbox.set_active(true)
			sprite.set_state(StickFigure.State.ATTACK)

		BOSS_STATE_COMBO_OVERHEAD:
			_face_target()
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(
				GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.2 * COMBO_OVERHEAD_DAMAGE_MULT))
			hitbox.set_active(true)
			sprite.set_state(StickFigure.State.ATTACK)
			if CameraShake != null:
				CameraShake.shake(6.0, 0.18)

		BOSS_STATE_LLAMARADA_WINDUP:
			sprite.start_telegraph(LLAMARADA_WINDUP_SECONDS)
			_face_target()
			_spawn_llamarada_marker()

		BOSS_STATE_LLAMARADA_ACTIVE:
			_apply_llamarada_damage()
			if CameraShake != null:
				CameraShake.shake(12.0, 0.30)


func _tick_boss_state(delta: float) -> void:
	_state_timer += delta

	match state:
		# ─── Tajo doble ──────────────────────────────────────────────────────
		BOSS_STATE_TAJO_DOBLE_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= TAJO_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_TAJO_DOBLE_HIT1)

		BOSS_STATE_TAJO_DOBLE_HIT1:
			velocity.x = 0.0
			if _state_timer >= TAJO_HIT_DURATION:
				_change_to_boss_state(BOSS_STATE_TAJO_DOBLE_GAP)

		BOSS_STATE_TAJO_DOBLE_GAP:
			velocity.x = 0.0
			if _state_timer >= TAJO_GAP_SECONDS:
				_change_to_boss_state(BOSS_STATE_TAJO_DOBLE_HIT2)

		BOSS_STATE_TAJO_DOBLE_HIT2:
			velocity.x = 0.0
			if _state_timer >= TAJO_HIT_DURATION:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
				_tajo_cooldown = randf_range(TAJO_COOLDOWN_MIN, TAJO_COOLDOWN_MAX)
				if _phase == 2:
					_tajo_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		# ─── Embestida ígnea ─────────────────────────────────────────────────
		BOSS_STATE_EMBESTIDA_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= EMBESTIDA_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_EMBESTIDA_DASH)

		BOSS_STATE_EMBESTIDA_DASH:
			velocity.x = _embestida_direction * EMBESTIDA_SPEED
			sprite.set_state(StickFigure.State.WALK)
			if _state_timer >= EMBESTIDA_DASH_SECONDS:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
				_embestida_cooldown = randf_range(EMBESTIDA_COOLDOWN_MIN, EMBESTIDA_COOLDOWN_MAX)
				if _phase == 2:
					_embestida_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		# ─── Parry Stance ────────────────────────────────────────────────────
		BOSS_STATE_PARRY_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= PARRY_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_PARRY_ACTIVE)

		BOSS_STATE_PARRY_ACTIVE:
			velocity.x = 0.0
			# Si expira sin trigger: salir sin counter, cooldown normal.
			if _state_timer >= PARRY_ACTIVE_SECONDS:
				sprite.end_block_aura()
				if sprite != null:
					sprite.modulate = Color.WHITE
				_parry_cooldown = randf_range(PARRY_COOLDOWN_MIN, PARRY_COOLDOWN_MAX)
				if _phase == 2:
					_parry_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_PARRY_COUNTER:
			velocity.x = 0.0
			if _state_timer >= PARRY_COUNTER_DURATION:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
				_parry_cooldown = randf_range(PARRY_COOLDOWN_MIN, PARRY_COOLDOWN_MAX)
				if _phase == 2:
					_parry_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		# ─── Combo Final ─────────────────────────────────────────────────────
		BOSS_STATE_COMBO_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= COMBO_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_COMBO_SLASH1)

		BOSS_STATE_COMBO_SLASH1:
			velocity.x = 0.0
			if _state_timer >= COMBO_SLASH_DURATION:
				hitbox.set_active(false)
				_change_to_boss_state(BOSS_STATE_COMBO_SLASH2)

		BOSS_STATE_COMBO_SLASH2:
			velocity.x = 0.0
			if _state_timer >= COMBO_SLASH_DURATION:
				hitbox.set_active(false)
				_change_to_boss_state(BOSS_STATE_COMBO_SLASH3)

		BOSS_STATE_COMBO_SLASH3:
			velocity.x = 0.0
			if _state_timer >= COMBO_SLASH_DURATION:
				hitbox.set_active(false)
				_change_to_boss_state(BOSS_STATE_COMBO_OVERHEAD)

		BOSS_STATE_COMBO_OVERHEAD:
			velocity.x = 0.0
			if _state_timer >= COMBO_OVERHEAD_DURATION:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
				_combo_cooldown = randf_range(COMBO_COOLDOWN_MIN, COMBO_COOLDOWN_MAX)
				if _phase == 2:
					_combo_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		# ─── Llamarada (F2) ──────────────────────────────────────────────────
		BOSS_STATE_LLAMARADA_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= LLAMARADA_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_LLAMARADA_ACTIVE)

		BOSS_STATE_LLAMARADA_ACTIVE:
			velocity.x = 0.0
			if _state_timer >= LLAMARADA_ACTIVE_SECONDS:
				_cleanup_llamarada_marker()
				_llamarada_cooldown = randf_range(LLAMARADA_COOLDOWN_MIN, LLAMARADA_COOLDOWN_MAX)
				state = State.RECOVERY
				_state_timer = 0.0


# ─── Helpers visuales / daño ─────────────────────────────────────────────────

## Slash trail naranja para la Embestida ígnea. Línea fugaz de fuego.
func _spawn_embestida_trail() -> void:
	var line: Line2D = Line2D.new()
	line.width = 6.0
	line.default_color = Color(1.0, 0.55, 0.15, 0.85)
	var start: Vector2 = Vector2(-_embestida_direction * EMBESTIDA_SPEED * EMBESTIDA_DASH_SECONDS, -40)
	var endp: Vector2 = Vector2(0, -40)
	line.add_point(start)
	line.add_point(endp)
	line.z_index = 2
	add_child(line)
	var tw: Tween = create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.4)
	tw.tween_callback(line.queue_free)


## Spawnea AoeTelegraph para la Llamarada en arco frontal.
func _spawn_llamarada_marker() -> void:
	_cleanup_llamarada_marker()
	var tele_scene: PackedScene = preload("res://scenes/effects/aoe_telegraph.tscn")
	if tele_scene == null:
		return
	var tele: AoeTelegraph = tele_scene.instantiate() as AoeTelegraph
	tele.global_position = global_position + Vector2(current_facing * 50.0, 0)
	tele.setup(LLAMARADA_RADIUS, LLAMARADA_WINDUP_SECONDS, Color(1.0, 0.45, 0.10, 0.55))
	get_tree().current_scene.add_child(tele)
	_llamarada_marker = tele


func _cleanup_llamarada_marker() -> void:
	if is_instance_valid(_llamarada_marker):
		_llamarada_marker.queue_free()
	_llamarada_marker = null


## Aplica daño AoE de la Llamarada: cono frontal radio LLAMARADA_RADIUS.
func _apply_llamarada_damage() -> void:
	if _target == null:
		return
	var target_hb: HurtboxComponent = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if target_hb == null:
		return
	# Verificar que player esté en cono frontal: dx en dirección del facing + dentro del radio.
	var to_target: Vector2 = _target.global_position - (global_position + Vector2(current_facing * 50.0, 0))
	if to_target.length() > LLAMARADA_RADIUS:
		return
	# Cono: el target debe estar del lado frontal (signo igual al facing).
	if sign(to_target.x) != current_facing and abs(to_target.x) > 20.0:
		return
	var dmg: int = int(round(float(GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.MELEE, GameConfig.EnemyRarity.R3)) * 1.2 * LLAMARADA_DAMAGE_MULT))
	target_hb.receive_hit(dmg, hitbox, 0)


func _on_died() -> void:
	_cleanup_llamarada_marker()
	if is_instance_valid(_parry_trail):
		_parry_trail.queue_free()
	super._on_died()
