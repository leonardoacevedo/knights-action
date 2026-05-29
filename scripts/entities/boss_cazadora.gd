extends Enemy
class_name BossCazadora

## Cazadora del Crepúsculo — Boss R4 Archer/AGUA.
##
## Fantasía: francotirador zonal. Domina el aire desde 3 posiciones elevadas.
## NO baja al piso. El player la fuerza a moverse cubriendo su posición —
## o muere lluvia tras lluvia.
##
## Hereda de Enemy pero anula la gravedad (vía override `_apply_gravity`).
## También skipea la lógica heredada de CHASE: la posición se decide por el
## sistema interno de "perchas" elevadas.
##
## Patrones F1 (4):
##   1. Flecha Pesada     — single arrow x2 daño, CD 3s, telegraph 0.5s.
##   2. Lluvia Vertical   — 5 flechas spread ±20°, CD 6s, telegraph 0.7s.
##   3. Lluvia AoE        — 3 AoeTelegraph + caen 3 flechas, CD 10s, telegraph 1.2s.
##   4. Tele-shot         — teleporta opuesto al player + dispara, CD 8s, telegraph 0.5s.
##
## F2 unlock (HP <= 50%):
##   5. Mareo Frío        — proyectil grande azul que aplica slow al player.
##   En cada teleport: dispara 2 flechas seguidas.

# ─── Posiciones elevadas (constantes en world space) ─────────────────────────
## 3 perchas fijas. La cazadora teleporta entre ellas cada 8-12s random.
## Coordenadas en world space asumen una arena centrada en (0, 0) con piso a Y=0.
## La Y negativa = arriba (Godot 2D).
const PERCH_LEFT: Vector2 = Vector2(-500, -300)
const PERCH_CENTER: Vector2 = Vector2(0, -350)
const PERCH_RIGHT: Vector2 = Vector2(500, -300)

const TELEPORT_INTERVAL_MIN: float = 8.0
const TELEPORT_INTERVAL_MAX: float = 12.0
const TELEPORT_FADE_DURATION: float = 0.35

# ─── Estados boss-específicos ────────────────────────────────────────────────
const BOSS_STATE_FLECHA_PESADA_WINDUP: int = 300
const BOSS_STATE_FLECHA_PESADA_FIRE: int = 301
const BOSS_STATE_LLUVIA_VERT_WINDUP: int = 310
const BOSS_STATE_LLUVIA_VERT_FIRE: int = 311
const BOSS_STATE_LLUVIA_AOE_WINDUP: int = 320
const BOSS_STATE_LLUVIA_AOE_FALL: int = 321
const BOSS_STATE_TELESHOT_WINDUP: int = 330
const BOSS_STATE_TELESHOT_FIRE: int = 331
const BOSS_STATE_MAREO_WINDUP: int = 340
const BOSS_STATE_MAREO_FIRE: int = 341
const BOSS_STATE_TELEPORT: int = 350

# ─── Config patrones ─────────────────────────────────────────────────────────
const FLECHA_PESADA_WINDUP: float = 0.5
const FLECHA_PESADA_DAMAGE_MULT: float = 2.0
const FLECHA_PESADA_COOLDOWN_MIN: float = 2.5
const FLECHA_PESADA_COOLDOWN_MAX: float = 3.5

const LLUVIA_VERT_WINDUP: float = 0.7
const LLUVIA_VERT_COUNT: int = 5
const LLUVIA_VERT_SPREAD_DEG: float = 20.0
const LLUVIA_VERT_COOLDOWN_MIN: float = 5.5
const LLUVIA_VERT_COOLDOWN_MAX: float = 7.0

const LLUVIA_AOE_WINDUP: float = 1.2
const LLUVIA_AOE_FALL_DELAY: float = 0.5
const LLUVIA_AOE_COUNT: int = 3
const LLUVIA_AOE_RADIUS: float = 60.0
const LLUVIA_AOE_DAMAGE_MULT: float = 1.4
const LLUVIA_AOE_COOLDOWN_MIN: float = 9.0
const LLUVIA_AOE_COOLDOWN_MAX: float = 11.0

const TELESHOT_WINDUP: float = 0.5
const TELESHOT_DAMAGE_MULT: float = 1.2
const TELESHOT_COOLDOWN_MIN: float = 7.5
const TELESHOT_COOLDOWN_MAX: float = 9.0

const MAREO_WINDUP: float = 1.0
const MAREO_SLOW_MULT: float = 0.45
const MAREO_SLOW_DURATION: float = 2.5
const MAREO_DAMAGE_MULT: float = 1.0
const MAREO_COOLDOWN_MIN: float = 11.0
const MAREO_COOLDOWN_MAX: float = 13.0

const TELEPORT_WINDUP: float = 0.35
const TELEPORT_RECOVERY: float = 0.35

const PHASE_2_COOLDOWN_FACTOR: float = 0.80

# ─── Estado runtime ──────────────────────────────────────────────────────────
var _phase: int = 1
var _flecha_pesada_cooldown: float = 1.5
var _lluvia_vert_cooldown: float = 3.5
var _lluvia_aoe_cooldown: float = 6.0
var _teleshot_cooldown: float = 4.5
var _mareo_cooldown: float = 5.0
var _teleport_cooldown: float = 0.0  ## reseteado al setup() inicial
var _teleport_target: Vector2 = PERCH_CENTER
var _current_perch_index: int = 1  ## 0=left, 1=center, 2=right
var _aoe_markers: Array[Node2D] = []
var _aoe_target_positions: Array[Vector2] = []
var _aoe_falling_timer: float = 0.0
var _aoe_fired: bool = false


func _ready() -> void:
	enemy_class = GameConfig.EnemyClass.ARCHER
	rarity = GameConfig.EnemyRarity.R4
	element = ItemData.Element.AGUA
	# Asignar projectile scene (arrow). Si no estaba seteado en el .tscn.
	if projectile_scene == null:
		projectile_scene = preload("res://scenes/projectiles/projectile_arrow.tscn")
	super._ready()

	# HP override: 70% del ARCHER R4 base.
	health.max_health = int(round(float(GameConfig.enemy_health_with_rarity(
		GameConfig.EnemyClass.ARCHER, GameConfig.EnemyRarity.R4)) * 0.70))
	health.current_health = health.max_health

	# Daño base: ARCHER R3 (handoff: "1.0× del archer R3").
	hitbox.damage = GameConfig.enemy_damage_with_rarity(
		GameConfig.EnemyClass.ARCHER, GameConfig.EnemyRarity.R3)

	# Sin escudo de cargas — la cazadora se defiende con distancia/teleport.
	if _block_handler != null:
		_block_handler.deactivate()
		hurtbox.shield = null

	# Visual: tinte azul-violeta crepuscular.
	if sprite != null:
		sprite.body_color = Color(0.35, 0.55, 0.95, 1.0)
		sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity) * 0.97  ## ~1.4
		sprite.weapon_scale = 1.4

	# Inicializar primer teleport cooldown.
	_teleport_cooldown = randf_range(TELEPORT_INTERVAL_MIN, TELEPORT_INTERVAL_MAX)

	# Posicionar a la cazadora en la percha center inicialmente.
	global_position = PERCH_CENTER
	_current_perch_index = 1

	health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, maximum: int) -> void:
	if _phase == 1 and current <= maximum / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	_phase = 2
	_flecha_pesada_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_lluvia_vert_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_lluvia_aoe_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_teleshot_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_mareo_cooldown = 2.0  ## disponible enseguida
	if sprite != null:
		sprite.body_color = Color(0.20, 0.40, 1.0, 1.0)
	if CameraShake != null:
		CameraShake.shake(10.0, 0.25)


# ─── Override de gravedad: la cazadora flota, sin caída ──────────────────────
func _apply_gravity(_delta: float) -> void:
	# No-op: la cazadora se queda en su Y de percha. Override del enemy.gd:_apply_gravity.
	velocity.y = 0.0


# ─── State machine ───────────────────────────────────────────────────────────
func _tick_state(delta: float) -> void:
	# Cooldowns.
	if _flecha_pesada_cooldown > 0.0: _flecha_pesada_cooldown -= delta
	if _lluvia_vert_cooldown > 0.0: _lluvia_vert_cooldown -= delta
	if _lluvia_aoe_cooldown > 0.0: _lluvia_aoe_cooldown -= delta
	if _teleshot_cooldown > 0.0: _teleshot_cooldown -= delta
	if _mareo_cooldown > 0.0: _mareo_cooldown -= delta
	if _teleport_cooldown > 0.0: _teleport_cooldown -= delta

	# Estados boss-específicos primero.
	if state >= BOSS_STATE_FLECHA_PESADA_WINDUP:
		_tick_boss_state(delta)
		return

	# La cazadora no usa CHASE: anula movimiento horizontal y se queda en su percha.
	# Solo decide qué patrón lanzar.
	velocity.x = 0.0

	if state == State.IDLE:
		if _target != null and _distance_to_target() < detect_range:
			state = State.CHASE
			_state_timer = 0.0
		return

	if state == State.CHASE:
		# Forzar facing hacia el player en cada tick para que las flechas apunten bien.
		_face_target()
		# Teleport tick: prioridad máxima si está listo.
		if _teleport_cooldown <= 0.0:
			_change_to_boss_state(BOSS_STATE_TELEPORT)
			return
		if _try_start_boss_pattern():
			return
		return

	# Otros estados heredados (RECOVERY, TELEGRAPH, etc.) → delegar al padre.
	super._tick_state(delta)


func _try_start_boss_pattern() -> bool:
	# F2: Mareo Frío — prioridad alta para forzar reposición del player.
	if _phase == 2 and _mareo_cooldown <= 0.0:
		_change_to_boss_state(BOSS_STATE_MAREO_WINDUP)
		return true

	# Lluvia AoE — zonal grande.
	if _lluvia_aoe_cooldown <= 0.0:
		_change_to_boss_state(BOSS_STATE_LLUVIA_AOE_WINDUP)
		return true

	# Tele-shot — teleporta al opuesto + dispara.
	if _teleshot_cooldown <= 0.0:
		_change_to_boss_state(BOSS_STATE_TELESHOT_WINDUP)
		return true

	# Lluvia vertical — spread de flechas.
	if _lluvia_vert_cooldown <= 0.0:
		_change_to_boss_state(BOSS_STATE_LLUVIA_VERT_WINDUP)
		return true

	# Flecha pesada — filler.
	if _flecha_pesada_cooldown <= 0.0:
		_change_to_boss_state(BOSS_STATE_FLECHA_PESADA_WINDUP)
		return true

	return false


func _change_to_boss_state(new_state: int) -> void:
	if state == State.TELEGRAPH or state == State.SKILL_TELEGRAPH:
		sprite.end_telegraph()

	state = new_state
	_state_timer = 0.0

	match new_state:
		BOSS_STATE_FLECHA_PESADA_WINDUP:
			sprite.start_telegraph(FLECHA_PESADA_WINDUP)
			_face_target()

		BOSS_STATE_FLECHA_PESADA_FIRE:
			_spawn_flecha_pesada()

		BOSS_STATE_LLUVIA_VERT_WINDUP:
			sprite.start_telegraph(LLUVIA_VERT_WINDUP)
			_face_target()

		BOSS_STATE_LLUVIA_VERT_FIRE:
			_spawn_lluvia_vertical()

		BOSS_STATE_LLUVIA_AOE_WINDUP:
			sprite.start_telegraph(LLUVIA_AOE_WINDUP)
			_face_target()
			_spawn_lluvia_aoe_markers()

		BOSS_STATE_LLUVIA_AOE_FALL:
			_aoe_fired = false
			_aoe_falling_timer = 0.0

		BOSS_STATE_TELESHOT_WINDUP:
			sprite.start_telegraph(TELESHOT_WINDUP)

		BOSS_STATE_TELESHOT_FIRE:
			_perform_teleshot()

		BOSS_STATE_MAREO_WINDUP:
			sprite.start_telegraph(MAREO_WINDUP)
			_face_target()

		BOSS_STATE_MAREO_FIRE:
			_spawn_mareo_proyectil()

		BOSS_STATE_TELEPORT:
			# Fade-out azul, recolocar en nueva percha, fade-in. Sin daño durante.
			_start_teleport()


func _tick_boss_state(delta: float) -> void:
	_state_timer += delta

	match state:
		BOSS_STATE_FLECHA_PESADA_WINDUP:
			if _state_timer >= FLECHA_PESADA_WINDUP:
				_change_to_boss_state(BOSS_STATE_FLECHA_PESADA_FIRE)

		BOSS_STATE_FLECHA_PESADA_FIRE:
			# Disparo instantáneo + recovery corta.
			if _state_timer >= 0.2:
				_flecha_pesada_cooldown = randf_range(
					FLECHA_PESADA_COOLDOWN_MIN, FLECHA_PESADA_COOLDOWN_MAX)
				if _phase == 2:
					_flecha_pesada_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.CHASE
				_state_timer = 0.0

		BOSS_STATE_LLUVIA_VERT_WINDUP:
			if _state_timer >= LLUVIA_VERT_WINDUP:
				_change_to_boss_state(BOSS_STATE_LLUVIA_VERT_FIRE)

		BOSS_STATE_LLUVIA_VERT_FIRE:
			if _state_timer >= 0.25:
				_lluvia_vert_cooldown = randf_range(
					LLUVIA_VERT_COOLDOWN_MIN, LLUVIA_VERT_COOLDOWN_MAX)
				if _phase == 2:
					_lluvia_vert_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.CHASE
				_state_timer = 0.0

		BOSS_STATE_LLUVIA_AOE_WINDUP:
			if _state_timer >= LLUVIA_AOE_WINDUP:
				_change_to_boss_state(BOSS_STATE_LLUVIA_AOE_FALL)

		BOSS_STATE_LLUVIA_AOE_FALL:
			_aoe_falling_timer += delta
			# A los LLUVIA_AOE_FALL_DELAY segundos, aplicar daño en cada marker.
			if not _aoe_fired and _aoe_falling_timer >= LLUVIA_AOE_FALL_DELAY:
				_apply_lluvia_aoe_damage()
				_aoe_fired = true
			# Cleanup tras 0.5s extra de feedback.
			if _aoe_falling_timer >= LLUVIA_AOE_FALL_DELAY + 0.3:
				_cleanup_aoe_markers()
				_lluvia_aoe_cooldown = randf_range(
					LLUVIA_AOE_COOLDOWN_MIN, LLUVIA_AOE_COOLDOWN_MAX)
				if _phase == 2:
					_lluvia_aoe_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.CHASE
				_state_timer = 0.0

		BOSS_STATE_TELESHOT_WINDUP:
			if _state_timer >= TELESHOT_WINDUP:
				_change_to_boss_state(BOSS_STATE_TELESHOT_FIRE)

		BOSS_STATE_TELESHOT_FIRE:
			if _state_timer >= 0.25:
				_teleshot_cooldown = randf_range(
					TELESHOT_COOLDOWN_MIN, TELESHOT_COOLDOWN_MAX)
				if _phase == 2:
					_teleshot_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.CHASE
				_state_timer = 0.0

		BOSS_STATE_MAREO_WINDUP:
			if _state_timer >= MAREO_WINDUP:
				_change_to_boss_state(BOSS_STATE_MAREO_FIRE)

		BOSS_STATE_MAREO_FIRE:
			if _state_timer >= 0.25:
				_mareo_cooldown = randf_range(MAREO_COOLDOWN_MIN, MAREO_COOLDOWN_MAX)
				if _phase == 2:
					_mareo_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.CHASE
				_state_timer = 0.0

		BOSS_STATE_TELEPORT:
			# Esperar fade-out + recolocar + fade-in. La animación está en tween,
			# acá solo controlamos el timer total y el reset del cooldown.
			if _state_timer >= TELEPORT_FADE_DURATION * 2.0 + TELEPORT_RECOVERY:
				_teleport_cooldown = randf_range(
					TELEPORT_INTERVAL_MIN, TELEPORT_INTERVAL_MAX)
				state = State.CHASE
				_state_timer = 0.0


# ─── Patrones: implementación ────────────────────────────────────────────────

func _spawn_flecha_pesada() -> void:
	if projectile_scene == null or _target == null:
		return
	var proj_node: Node2D = projectile_scene.instantiate()
	if not proj_node is Projectile:
		proj_node.queue_free()
		return
	var proj: Projectile = proj_node
	proj.global_position = global_position + Vector2(0, 10)
	var aim: Vector2 = _target.global_position + Vector2(0, -30)
	var dir: Vector2 = (aim - proj.global_position).normalized()
	# Daño x2.
	var dmg: int = int(round(float(hitbox.damage) * FLECHA_PESADA_DAMAGE_MULT))
	proj.launch(dir, dmg, team, element)
	proj.set_source(self)
	# Escalar visualmente para distinguir.
	proj.scale = Vector2(1.4, 1.4)
	get_tree().current_scene.add_child(proj)


func _spawn_lluvia_vertical() -> void:
	if projectile_scene == null or _target == null:
		return
	var aim: Vector2 = _target.global_position + Vector2(0, -30)
	var base_dir: Vector2 = (aim - (global_position + Vector2(0, 10))).normalized()
	# Spread: 5 flechas distribuidas ±20°.
	for i in LLUVIA_VERT_COUNT:
		var t: float = float(i) / float(LLUVIA_VERT_COUNT - 1)  ## 0..1
		var angle_offset: float = lerp(-LLUVIA_VERT_SPREAD_DEG, LLUVIA_VERT_SPREAD_DEG, t)
		var proj_node: Node2D = projectile_scene.instantiate()
		if not proj_node is Projectile:
			proj_node.queue_free()
			continue
		var proj: Projectile = proj_node
		proj.global_position = global_position + Vector2(0, 10)
		var dir: Vector2 = base_dir.rotated(deg_to_rad(angle_offset))
		proj.launch(dir, hitbox.damage, team, element)
		proj.set_source(self)
		get_tree().current_scene.add_child(proj)


func _spawn_lluvia_aoe_markers() -> void:
	_cleanup_aoe_markers()
	if _target == null:
		return
	var tele_scene: PackedScene = preload("res://scenes/effects/aoe_telegraph.tscn")
	if tele_scene == null:
		return
	_aoe_target_positions.clear()
	# 3 posiciones aleatorias alrededor del player (±150px horizontal).
	for i in LLUVIA_AOE_COUNT:
		var offset_x: float = randf_range(-150.0, 150.0)
		var ground_y: float = _target.global_position.y
		var pos: Vector2 = Vector2(_target.global_position.x + offset_x, ground_y)
		_aoe_target_positions.append(pos)
		var tele: AoeTelegraph = tele_scene.instantiate() as AoeTelegraph
		tele.global_position = pos
		tele.setup(LLUVIA_AOE_RADIUS, LLUVIA_AOE_WINDUP + LLUVIA_AOE_FALL_DELAY,
			Color(0.25, 0.55, 1.0, 0.55))
		get_tree().current_scene.add_child(tele)
		_aoe_markers.append(tele)


func _apply_lluvia_aoe_damage() -> void:
	if _target == null:
		return
	var target_hb: HurtboxComponent = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if target_hb == null:
		return
	var dmg: int = int(round(float(hitbox.damage) * LLUVIA_AOE_DAMAGE_MULT))
	for pos in _aoe_target_positions:
		if pos.distance_to(_target.global_position) <= LLUVIA_AOE_RADIUS:
			target_hb.receive_hit(dmg, hitbox, 0)
			return  ## solo un hit aunque el player esté en múltiples zonas


func _cleanup_aoe_markers() -> void:
	for m in _aoe_markers:
		if is_instance_valid(m):
			m.queue_free()
	_aoe_markers.clear()
	_aoe_target_positions.clear()


func _perform_teleshot() -> void:
	if _target == null:
		return
	# Teleport a la percha OPUESTA al player.
	var player_x: float = _target.global_position.x
	var opposite_perch: Vector2
	if player_x < 0.0:
		opposite_perch = PERCH_RIGHT
		_current_perch_index = 2
	else:
		opposite_perch = PERCH_LEFT
		_current_perch_index = 0
	# Tween fade rápido para visual.
	modulate.a = 0.3
	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", opposite_perch, 0.1)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	# Disparo inmediato post-teleport.
	if projectile_scene != null:
		var proj_node: Node2D = projectile_scene.instantiate()
		if proj_node is Projectile:
			var proj: Projectile = proj_node
			proj.global_position = opposite_perch + Vector2(0, 10)
			var aim: Vector2 = _target.global_position + Vector2(0, -30)
			var dir: Vector2 = (aim - proj.global_position).normalized()
			var dmg: int = int(round(float(hitbox.damage) * TELESHOT_DAMAGE_MULT))
			proj.launch(dir, dmg, team, element)
			proj.set_source(self)
			get_tree().current_scene.add_child(proj)


func _spawn_mareo_proyectil() -> void:
	if projectile_scene == null or _target == null:
		return
	var proj_node: Node2D = projectile_scene.instantiate()
	if not proj_node is Projectile:
		proj_node.queue_free()
		return
	var proj: Projectile = proj_node
	proj.global_position = global_position + Vector2(0, 10)
	var aim: Vector2 = _target.global_position + Vector2(0, -30)
	var dir: Vector2 = (aim - proj.global_position).normalized()
	var dmg: int = int(round(float(hitbox.damage) * MAREO_DAMAGE_MULT))
	proj.launch(dir, dmg, team, element)
	proj.set_source(self)
	# Visual grande y azul intenso.
	proj.scale = Vector2(1.7, 1.7)
	proj.modulate = Color(0.4, 0.6, 1.2, 1.0)
	# Hook al hit_landed para aplicar slow al player al impactar.
	# Nota: si el proyectil pasa de largo, no aplica slow (intencional — la zonal mechanic).
	if proj.has_signal("hit_landed"):
		proj.hit_landed.connect(_on_mareo_hit_landed)
	get_tree().current_scene.add_child(proj)


func _on_mareo_hit_landed(target_hurtbox: HurtboxComponent) -> void:
	# Aplicar slow solo si el target es el player (team 1).
	if target_hurtbox == null or target_hurtbox.team == team:
		return
	var parent: Node = target_hurtbox.get_parent()
	if parent != null and parent.has_method("apply_slow"):
		parent.apply_slow(MAREO_SLOW_MULT, MAREO_SLOW_DURATION)


func _start_teleport() -> void:
	# Elegir percha al azar distinta a la actual.
	var perches: Array[Vector2] = [PERCH_LEFT, PERCH_CENTER, PERCH_RIGHT]
	var candidate_indices: Array[int] = [0, 1, 2]
	candidate_indices.erase(_current_perch_index)
	var new_idx: int = candidate_indices[randi() % candidate_indices.size()]
	_teleport_target = perches[new_idx]
	# Tween: fade-out → reposicionar → fade-in.
	modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.2, TELEPORT_FADE_DURATION)
	tw.tween_callback(func() -> void:
		global_position = _teleport_target
		_current_perch_index = new_idx
		# F2 bonus: en cada teleport, dispara 2 flechas al aparecer.
		if _phase == 2:
			_fire_teleport_bonus_arrows()
	)
	tw.tween_property(self, "modulate:a", 1.0, TELEPORT_FADE_DURATION)


func _fire_teleport_bonus_arrows() -> void:
	# F2 only: 2 flechas seguidas al aparecer en la nueva percha.
	if projectile_scene == null or _target == null:
		return
	for i in 2:
		var proj_node: Node2D = projectile_scene.instantiate()
		if not proj_node is Projectile:
			proj_node.queue_free()
			continue
		var proj: Projectile = proj_node
		proj.global_position = global_position + Vector2(0, 10)
		var aim: Vector2 = _target.global_position + Vector2(0, -30)
		var dir: Vector2 = (aim - proj.global_position).normalized()
		# Pequeño spread para evitar overlap perfecto.
		dir = dir.rotated(deg_to_rad(-10.0 + 20.0 * float(i)))
		proj.launch(dir, hitbox.damage, team, element)
		proj.set_source(self)
		get_tree().current_scene.add_child(proj)


func _on_died() -> void:
	_cleanup_aoe_markers()
	super._on_died()
