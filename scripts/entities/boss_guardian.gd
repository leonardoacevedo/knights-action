extends Enemy
class_name BossGuardian

## El Guardián de la Maleza — Boss R4 del Valle de los Ecos (GDD §10).
##
## Espejo del jugador (regla R4 §7.3): cargas de bloqueo REALES (EnemyBlockHandler),
## dash de aproximación (gap close), skills telegrafiadas, fases.
##
## Hereda de Enemy para reusar movimiento, salto multi-hop, facing, target detection.
## Override de _tick_state para inyectar lógica boss-specific:
##   - Cargas de escudo via EnemyBlockHandler (mismo patrón que R2/R3) que absorben
##     los primeros N golpes. Decisión Opción A (handoff): unificar block handler.
##   - 2 fases con threshold de HP (100%→50% y 50%→0%).
##   - Patrones F1: Embestida (charge), Raíces (AoE marcada), Gap-Close Dash (cerrar
##     distancia rápido), swing melee normal (heredado).
##   - F2 agrega ultimate "Tormenta de Espinas" (AoE telegrafiada larga).
##   - Slam Aplastante: transición especial al entrar a F2 (1 vez).
##
## Recarga de cargas (mix sugerido por handoff):
##   - Al cruzar a F2: reset a max (visual: "se enfurece, escudo se restaura").
##   - Cada SHIELD_AUTOREGEN_SECONDS si quedó en 0 cargas: reset a max.
##
## Telegrafía obligatoria (GDD §7.3 R4): TODOS los patrones pesados tienen wind-up
## visible (≥0.4s, 1.0s para ultimate). Player puede leer el intent.
##
## Feedback de Leo (playtest): "es un jugador más" — ágil, imponente, no saco de
## boxeo. Cooldowns cortos, partículas grandes, scale 1.4×.

# ─── Estados boss-específicos ────────────────────────────────────────────────
# El enum State del padre cubre IDLE/CHASE/TELEGRAPH/ATTACK/etc. Acá agregamos
# constantes con ints altos (>=100). El match del padre cae a `_:` (nada) cuando
# state está en ese rango — interceptamos en nuestro _tick_state antes de delegar.

const BOSS_STATE_CHARGE_WINDUP: int = 100
const BOSS_STATE_CHARGE_DASH: int = 101
const BOSS_STATE_ROOTS_WINDUP: int = 102
const BOSS_STATE_ROOTS_ACTIVE: int = 103
const BOSS_STATE_SLAM_JUMP: int = 104       ## Transición F1→F2: salto aplastante.
const BOSS_STATE_SLAM_LAND: int = 105
const BOSS_STATE_STORM_WINDUP: int = 106    ## Ultimate F2: tormenta de espinas.
const BOSS_STATE_STORM_ACTIVE: int = 107
const BOSS_STATE_GAP_CLOSE_WINDUP: int = 108  ## Dash de aproximación (telegrafía corta).
const BOSS_STATE_GAP_CLOSE_DASH: int = 109

# ─── Config de cargas de escudo ──────────────────────────────────────────────
## Cargas iniciales del boss (Leo: "mínimo 3-5"). Default 4 — recargables.
@export var shield_charges: int = 4

## Cada cuántos segundos el escudo se reconstruye si quedó en 0 cargas. 12s da
## tiempo al player para presionar antes de la próxima ronda.
const SHIELD_AUTOREGEN_SECONDS: float = 12.0

# ─── Config de patrones (ajustada por feedback de Leo) ──────────────────────
## Embestida pesada (charge): wind-up + dash horizontal rápido. Más corta.
const CHARGE_WINDUP_SECONDS: float = 0.55          # antes 0.8
const CHARGE_DASH_SECONDS: float = 0.55
const CHARGE_SPEED: float = 900.0                   # un poco más rápido
const CHARGE_DAMAGE_MULT: float = 1.4
const CHARGE_TRIGGER_DISTANCE: float = 460.0        ## solo si player está medio lejos
const CHARGE_COOLDOWN_MIN: float = 4.0              # antes 6-9, ahora más agresivo
const CHARGE_COOLDOWN_MAX: float = 6.5

## Gap-close dash: cerrar distancia cuando player se aleja mucho. Telegrafía corta.
const GAP_CLOSE_WINDUP_SECONDS: float = 0.3
const GAP_CLOSE_DASH_SECONDS: float = 0.4
const GAP_CLOSE_SPEED: float = 1100.0
const GAP_CLOSE_DAMAGE_MULT: float = 0.9            ## menos daño que el charge pesado
const GAP_CLOSE_COOLDOWN_MIN: float = 3.0
const GAP_CLOSE_COOLDOWN_MAX: float = 4.5

## Invocación de raíces: 3 AoE marcadas en piso, daño después del marker.
const ROOTS_WINDUP_SECONDS: float = 0.7             # antes 1.0
const ROOTS_ACTIVE_SECONDS: float = 0.4             ## ventana de daño
const ROOTS_COUNT: int = 3
const ROOTS_SPREAD_PX: float = 110.0                ## separación lateral
const ROOTS_DAMAGE_MULT: float = 1.1
const ROOTS_AOE_RADIUS: float = 55.0
const ROOTS_COOLDOWN_MIN: float = 5.0               # antes 7-10
const ROOTS_COOLDOWN_MAX: float = 7.5

## Slam Aplastante: única, al cruzar 50% HP. Daño alto + screenshake.
const SLAM_JUMP_DURATION: float = 0.7               # antes 0.85
const SLAM_LAND_RECOVERY: float = 0.6
const SLAM_DAMAGE_MULT: float = 1.8
const SLAM_AOE_RADIUS: float = 140.0
const SLAM_JUMP_HEIGHT_VELOCITY: float = -1100.0

## Tormenta de Espinas (Ultimate F2): AoE grande, telegraph largo para que se mueva.
const STORM_WINDUP_SECONDS: float = 1.0             # antes 1.5 (Leo quiere más ágil)
const STORM_ACTIVE_SECONDS: float = 0.6
const STORM_DAMAGE_MULT: float = 1.6
const STORM_AOE_RADIUS: float = 200.0
const STORM_COOLDOWN_MIN: float = 7.5               # antes 10-13
const STORM_COOLDOWN_MAX: float = 10.5

## Reducción de cooldowns en F2 (boss más agresivo enragado).
const PHASE_2_COOLDOWN_FACTOR: float = 0.75

# ─── Estado runtime ───────────────────────────────────────────────────────────
var _phase: int = 1                              ## 1 o 2
var _charge_cooldown: float = 2.5                ## delay inicial del primer charge
var _roots_cooldown: float = 4.0                 ## delay inicial de la primera invocación
var _storm_cooldown: float = 6.0                 ## delay inicial al entrar F2
var _gap_close_cooldown: float = 1.5             ## delay inicial del gap-close
var _shield_regen_timer: float = 0.0             ## timer de recarga automática (s desde 0 cargas)
var _slam_done: bool = false                     ## flag: ya hizo el slam de transición F1→F2

## Marcadores de raíces activos (Node2D markers en piso). Se liberan al terminar.
var _root_markers: Array[Node2D] = []
## Dirección X del charge actual (-1/1). Se cachea al entrar al windup.
var _charge_direction: int = 1
## Dirección del gap-close (apunta al player en el momento del windup).
var _gap_close_direction: int = 1
## Marcador visual del storm (instanciado en _spawn_storm_marker).
var _storm_marker: Node2D = null


func _ready() -> void:
	# Forzar configuración antes del super._ready (el padre lee class/rarity).
	enemy_class = GameConfig.EnemyClass.TANK
	rarity = GameConfig.EnemyRarity.R4
	super._ready()

	# Setup del bloqueo: el boss tiene escudo SIEMPRE activo con N cargas.
	# A diferencia de R2 (que entra/sale de State.BLOCK), el boss usa el handler
	# como capa de protección permanente. Romper todas las cargas = ventana de daño.
	_setup_shield()

	# Aura imponente — partículas verde-doradas del Valle, scale grande, permanente.
	_apply_boss_visuals()
	_setup_health_thresholds()


func _setup_shield() -> void:
	# Reset del handler ya presente en enemy.tscn con las cargas del boss.
	# `_block_handler` viene del padre (@onready var). Si por alguna razón el .tscn
	# del boss no tiene el nodo, abortamos con warning para evitar crash silencioso.
	if _block_handler == null:
		push_warning("BossGuardian: EnemyBlockHandler no encontrado en .tscn — sin escudo.")
		return
	_block_handler.reset_charges(shield_charges)
	# Conectar hurtbox al handler permanentemente. Cada golpe del player consume 1 carga.
	hurtbox.shield = _block_handler
	# Señales para feedback visual y trigger de regen.
	_block_handler.charge_absorbed.connect(_on_shield_absorbed)
	_block_handler.broken.connect(_on_shield_broken)


func _apply_boss_visuals() -> void:
	if sprite == null:
		return
	# Color: verde-musgo dorado para identidad del Valle.
	sprite.body_color = Color(0.55, 0.65, 0.35, 1.0)
	# Scale del boss: 1.4× sobre el rarity_scale_for(R4)=1.45 → ~2.0× del normal.
	# Sumar visualmente "imponente" sin tocar hitbox/hurtbox físicos.
	sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity) * 1.40
	sprite.weapon_scale = 1.8
	# Boostear el BossAura del padre: más partículas, persistente, verde-dorado intenso.
	_upgrade_boss_aura()


## Toma el GPUParticles2D "BossAura" creado por Enemy._spawn_boss_aura y lo agranda
## + cambia color a verde-dorado del Valle. Se ejecuta una vez en _ready.
func _upgrade_boss_aura() -> void:
	var aura: GPUParticles2D = get_node_or_null("BossAura") as GPUParticles2D
	if aura == null:
		return
	# Más partículas + lifetime mayor → halo denso continuo.
	aura.amount = 30                                # antes 28
	aura.lifetime = 1.8                             # antes 1.4
	aura.preprocess = 1.0
	aura.position = Vector2(0, -45)

	# Reemplazar el material por uno con color verde-dorado y emission más grande.
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 32.0               # antes 22 — halo más ancho
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.gravity = Vector3(0, -20, 0)
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 28.0
	mat.scale_min = 0.6
	mat.scale_max = 1.4                             # partículas más grandes
	# Verde-dorado del Valle → desvanece a transparente.
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.85, 0.95, 0.45, 0.90))   # verde-dorado intenso
	grad.set_color(1, Color(0.45, 0.70, 0.15, 0.0))    # verde más oscuro fadeout
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	aura.process_material = mat
	aura.emitting = true


func _setup_health_thresholds() -> void:
	# Escucha cambios de HP para detectar threshold 50% (fase 2).
	health.health_changed.connect(_on_health_changed)


# ─── Hooks de combate ────────────────────────────────────────────────────────

## Override del padre. El padre dispara esto al absorber via handler — pero su
## implementación asume State.BLOCK y hace _change_state(State.TELEGRAPH).
## El boss tiene escudo permanente: NO queremos cambiar de estado al absorber.
## Solo feedback visual + reset del timer de regen (lo hace _on_shield_absorbed).
func _on_block_absorbed(_amount: int, _source: HitboxComponent) -> void:
	# Burst doble del normal (Leo: "más impactante").
	if sprite != null:
		sprite.play_block_burst()
	# Pequeño shake al absorber.
	if CameraShake != null:
		CameraShake.shake(0.10, 3.0)


## Disparado por EnemyBlockHandler cuando una carga fue consumida.
## remaining = cargas restantes después del absorb.
func _on_shield_absorbed(remaining: int) -> void:
	# Floater dorado con cargas restantes.
	DamageFloater.spawn(
		get_tree().current_scene,
		global_position + Vector2(0, -150),
		remaining,
		Color(1.0, 0.85, 0.25, 1.0)
	)
	# Reset del timer de regen: empieza a contar desde el último golpe absorbido.
	_shield_regen_timer = 0.0


## Disparado por EnemyBlockHandler cuando todas las cargas se rompieron.
## El boss queda EXPUESTO: aura se apaga, el player tiene ventana.
func _on_shield_broken() -> void:
	# Apagar el aura visualmente para señalar exposición.
	var aura: GPUParticles2D = get_node_or_null("BossAura") as GPUParticles2D
	if aura != null:
		aura.emitting = false
	# Hurtbox queda sin shield útil (el handler está vacío, try_absorb retorna false).
	# NO seteamos hurtbox.shield = null para evitar pisar la referencia — al regen
	# las cargas vuelven sobre el mismo handler. Big burst y screenshake.
	if sprite != null:
		sprite.play_block_burst()
	if CameraShake != null:
		CameraShake.shake(0.25, 8.0)
	# Arrancar el timer de regen (se completa en SHIELD_AUTOREGEN_SECONDS).
	_shield_regen_timer = 0.0


## Reactivar el escudo con cargas full. Se llama desde _tick_state (regen) o
## desde _enter_phase_2 (recarga al cambiar de fase).
func _restore_shield() -> void:
	if _block_handler == null:
		return
	_block_handler.reset_charges(shield_charges)
	hurtbox.shield = _block_handler
	# Reactivar el aura visual.
	var aura: GPUParticles2D = get_node_or_null("BossAura") as GPUParticles2D
	if aura != null:
		aura.emitting = true
	# Feedback: pequeño burst dorado al restaurar.
	if sprite != null:
		sprite.play_block_burst()


func _on_health_changed(current: int, maximum: int) -> void:
	# Trigger fase 2 cuando HP cae <50%. Solo una vez.
	if _phase == 1 and current <= maximum / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	_phase = 2
	# Recarga del escudo al cambiar de fase (señal de "se enfurece").
	_restore_shield()
	# Cooldowns -25% en F2 (boss más agresivo).
	_charge_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_roots_cooldown *= PHASE_2_COOLDOWN_FACTOR
	_gap_close_cooldown *= PHASE_2_COOLDOWN_FACTOR
	# Si no estaba en estado especial, lanzar el slam aplastante de transición.
	if _is_in_boss_state() or state == State.HURT or state == State.DEAD:
		return
	if _slam_done:
		return
	_change_to_boss_state(BOSS_STATE_SLAM_JUMP)


# ─── Override del state machine ──────────────────────────────────────────────

## Override de _tick_state. Si estamos en un estado boss-extra, lo procesamos acá.
## Sino, interceptamos CHASE para inyectar patrones boss, y delegamos al padre.
func _tick_state(delta: float) -> void:
	# Cooldowns boss-específicos.
	if _charge_cooldown > 0.0:
		_charge_cooldown -= delta
	if _roots_cooldown > 0.0:
		_roots_cooldown -= delta
	if _storm_cooldown > 0.0:
		_storm_cooldown -= delta
	if _gap_close_cooldown > 0.0:
		_gap_close_cooldown -= delta

	# Regen del escudo: si quedó en 0 cargas, contar hasta SHIELD_AUTOREGEN_SECONDS.
	if _block_handler != null and not _block_handler.has_charges():
		_shield_regen_timer += delta
		if _shield_regen_timer >= SHIELD_AUTOREGEN_SECONDS:
			_shield_regen_timer = 0.0
			_restore_shield()

	# Estados boss-específicos: procesar antes de tocar el padre.
	if state >= BOSS_STATE_CHARGE_WINDUP:
		_tick_boss_state(delta)
		return

	# Interceptar CHASE para inyectar patrones boss.
	if state == State.CHASE and _target != null and is_on_floor():
		if _try_start_boss_pattern():
			return

	# Default: comportamiento heredado.
	super._tick_state(delta)


## Decide si iniciar un patrón boss desde CHASE. Retorna true si lanzó algo.
## Prioridad (Leo: "espejo del jugador, agresivo"):
##   1. Gap-close dash si player muy lejos (cerrar distancia ya).
##   2. Tormenta de Espinas (F2 only, distancia media-larga).
##   3. Embestida pesada (distancia media, no cubierta por gap-close).
##   4. Invocación de raíces (cualquier rango cercano).
func _try_start_boss_pattern() -> bool:
	var dist: float = _distance_to_target()

	# GAP-CLOSE: si player se alejó >2.5× attack_range, dasheá hacia él.
	# Prioridad alta para evitar "saco de boxeo" — boss persigue activamente.
	if _gap_close_cooldown <= 0.0 and dist > attack_range * 2.5 and dist < CHARGE_TRIGGER_DISTANCE * 1.5:
		_change_to_boss_state(BOSS_STATE_GAP_CLOSE_WINDUP)
		return true

	# F2 ultimate: tormenta de espinas. Prefer a media-larga distancia.
	if _phase == 2 and _storm_cooldown <= 0.0 and dist > 180.0:
		_change_to_boss_state(BOSS_STATE_STORM_WINDUP)
		return true

	# Embestida: player a media distancia, fuera del melee normal.
	if _charge_cooldown <= 0.0 and dist > attack_range * 1.8 and dist < CHARGE_TRIGGER_DISTANCE:
		_change_to_boss_state(BOSS_STATE_CHARGE_WINDUP)
		return true

	# Raíces: cualquier distancia razonable, control de espacio.
	if _roots_cooldown <= 0.0 and dist < CHARGE_TRIGGER_DISTANCE:
		_change_to_boss_state(BOSS_STATE_ROOTS_WINDUP)
		return true

	return false


## Cambio de estado a uno boss-extra. Maneja entry side-effects (telegraph, etc.).
func _change_to_boss_state(new_state: int) -> void:
	# Cleanup del estado actual heredado, replicando _change_state del padre.
	if state == State.TELEGRAPH or state == State.SKILL_TELEGRAPH:
		sprite.end_telegraph()
	# No tocar hurtbox.shield — el boss usa shield permanente, no se entra a BLOCK.

	state = new_state
	_state_timer = 0.0

	match new_state:
		BOSS_STATE_CHARGE_WINDUP:
			sprite.start_telegraph(CHARGE_WINDUP_SECONDS)
			_face_target()
			_charge_direction = current_facing

		BOSS_STATE_CHARGE_DASH:
			# Hitbox activo durante todo el dash + daño aumentado.
			hitbox.damage = int(round(
				float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity))
				* CHARGE_DAMAGE_MULT
			))
			hitbox.set_active(true)

		BOSS_STATE_GAP_CLOSE_WINDUP:
			# Telegrafía corta (0.3s) — "voy a saltar hacia vos".
			sprite.start_telegraph(GAP_CLOSE_WINDUP_SECONDS)
			_face_target()
			_gap_close_direction = current_facing

		BOSS_STATE_GAP_CLOSE_DASH:
			# Hitbox activo con daño moderado durante el cierre de gap.
			hitbox.damage = int(round(
				float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity))
				* GAP_CLOSE_DAMAGE_MULT
			))
			hitbox.set_active(true)
			# Pequeño shake para sentir el "empujón".
			if CameraShake != null:
				CameraShake.shake(0.08, 3.5)

		BOSS_STATE_ROOTS_WINDUP:
			sprite.start_telegraph(ROOTS_WINDUP_SECONDS)
			_face_target()
			_spawn_root_markers()

		BOSS_STATE_ROOTS_ACTIVE:
			_activate_root_aoe()

		BOSS_STATE_SLAM_JUMP:
			sprite.start_telegraph(SLAM_JUMP_DURATION)
			velocity.y = SLAM_JUMP_HEIGHT_VELOCITY
			if CameraShake != null:
				CameraShake.shake(0.15, 4.0)

		BOSS_STATE_SLAM_LAND:
			_apply_slam_damage()
			if CameraShake != null:
				CameraShake.shake(0.35, 14.0)

		BOSS_STATE_STORM_WINDUP:
			sprite.start_telegraph(STORM_WINDUP_SECONDS)
			_face_target()
			_spawn_storm_marker()

		BOSS_STATE_STORM_ACTIVE:
			_apply_storm_damage()
			if CameraShake != null:
				CameraShake.shake(0.45, 18.0)


## Tick de estados boss-específicos. Maneja transiciones y physics.
func _tick_boss_state(delta: float) -> void:
	_state_timer += delta

	match state:
		BOSS_STATE_CHARGE_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= CHARGE_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_CHARGE_DASH)

		BOSS_STATE_CHARGE_DASH:
			velocity.x = _charge_direction * CHARGE_SPEED
			sprite.set_state(StickFigure.State.WALK)
			if _state_timer >= CHARGE_DASH_SECONDS:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
				_charge_cooldown = randf_range(CHARGE_COOLDOWN_MIN, CHARGE_COOLDOWN_MAX)
				if _phase == 2:
					_charge_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_GAP_CLOSE_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= GAP_CLOSE_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_GAP_CLOSE_DASH)

		BOSS_STATE_GAP_CLOSE_DASH:
			velocity.x = _gap_close_direction * GAP_CLOSE_SPEED
			sprite.set_state(StickFigure.State.WALK)
			# Cortar si ya alcanzó al player (entró al rango melee) o se acabó el tiempo.
			var dist_now: float = _distance_to_target()
			var time_up: bool = _state_timer >= GAP_CLOSE_DASH_SECONDS
			var reached: bool = dist_now <= attack_range * 1.1
			if time_up or reached:
				hitbox.set_active(false)
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
				_gap_close_cooldown = randf_range(GAP_CLOSE_COOLDOWN_MIN, GAP_CLOSE_COOLDOWN_MAX)
				if _phase == 2:
					_gap_close_cooldown *= PHASE_2_COOLDOWN_FACTOR
				# Recovery corto para encadenar con melee normal o raíces.
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_ROOTS_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= ROOTS_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_ROOTS_ACTIVE)

		BOSS_STATE_ROOTS_ACTIVE:
			velocity.x = 0.0
			if _state_timer >= ROOTS_ACTIVE_SECONDS:
				_cleanup_root_markers()
				_roots_cooldown = randf_range(ROOTS_COOLDOWN_MIN, ROOTS_COOLDOWN_MAX)
				if _phase == 2:
					_roots_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_SLAM_JUMP:
			# Gravity ya se aplica en padre. Cuando aterriza Y pasó el tiempo mínimo
			# de telegraph, transicionar a SLAM_LAND.
			if _state_timer >= SLAM_JUMP_DURATION * 0.5 and is_on_floor():
				_change_to_boss_state(BOSS_STATE_SLAM_LAND)

		BOSS_STATE_SLAM_LAND:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= SLAM_LAND_RECOVERY:
				_slam_done = true
				state = State.RECOVERY
				_state_timer = 0.0

		BOSS_STATE_STORM_WINDUP:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= STORM_WINDUP_SECONDS:
				_change_to_boss_state(BOSS_STATE_STORM_ACTIVE)

		BOSS_STATE_STORM_ACTIVE:
			velocity.x = 0.0
			if _state_timer >= STORM_ACTIVE_SECONDS:
				_cleanup_storm_marker()
				_storm_cooldown = randf_range(STORM_COOLDOWN_MIN, STORM_COOLDOWN_MAX)
				if _phase == 2:
					_storm_cooldown *= PHASE_2_COOLDOWN_FACTOR
				state = State.RECOVERY
				_state_timer = 0.0


func _is_in_boss_state() -> bool:
	return state >= BOSS_STATE_CHARGE_WINDUP


# ─── Patrones: implementación ────────────────────────────────────────────────

## Crea 3 markers visuales en el piso para anticipar la invocación de raíces.
## Posiciones: centrada en el target + 2 a los lados (±ROOTS_SPREAD_PX).
func _spawn_root_markers() -> void:
	_cleanup_root_markers()
	if _target == null:
		return
	var center_x: float = _target.global_position.x
	# Aproximamos Y de piso con la del target (asumimos same-ground).
	var floor_y: float = _target.global_position.y
	for i in ROOTS_COUNT:
		var offset_index: int = i - int(ROOTS_COUNT / 2.0)
		var mx: float = center_x + float(offset_index) * ROOTS_SPREAD_PX
		var marker: Node2D = _build_marker(
			Vector2(mx, floor_y),
			Color(0.85, 0.25, 0.25, 0.65),
			ROOTS_AOE_RADIUS
		)
		get_tree().current_scene.add_child(marker)
		_root_markers.append(marker)


## Damage tick para las raíces. Aplica daño si el player está dentro del radio
## de cualquiera de los markers.
func _activate_root_aoe() -> void:
	if _target == null:
		return
	var target_hurtbox: HurtboxComponent = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if target_hurtbox == null:
		return
	# Cambiar markers a "active" (color más intenso) para feedback visual.
	for marker in _root_markers:
		if not is_instance_valid(marker):
			continue
		var rect: ColorRect = marker.get_node_or_null("Ring") as ColorRect
		if rect != null:
			rect.color = Color(1.0, 0.5, 0.1, 0.95)
	# Check overlap: si el target está dentro de alguna AoE, daño (un solo hit).
	var dmg_total: int = int(round(
		float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity)) * ROOTS_DAMAGE_MULT
	))
	for marker in _root_markers:
		if not is_instance_valid(marker):
			continue
		if marker.global_position.distance_to(_target.global_position) <= ROOTS_AOE_RADIUS:
			target_hurtbox.receive_hit(dmg_total, null)
			return


func _cleanup_root_markers() -> void:
	for marker in _root_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_root_markers.clear()


## Daño AoE al aterrizar del slam. Si el player está dentro del radio, golpe pesado.
func _apply_slam_damage() -> void:
	if _target == null:
		return
	var target_hurtbox: HurtboxComponent = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if target_hurtbox == null:
		return
	if global_position.distance_to(_target.global_position) <= SLAM_AOE_RADIUS:
		var dmg: int = int(round(
			float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity)) * SLAM_DAMAGE_MULT
		))
		target_hurtbox.receive_hit(dmg, null)


func _spawn_storm_marker() -> void:
	_cleanup_storm_marker()
	if _target == null:
		return
	var floor_y: float = _target.global_position.y
	var marker_x: float = _target.global_position.x
	_storm_marker = _build_marker(
		Vector2(marker_x, floor_y),
		Color(0.7, 0.25, 0.85, 0.55),
		STORM_AOE_RADIUS
	)
	get_tree().current_scene.add_child(_storm_marker)


func _apply_storm_damage() -> void:
	if _target == null or _storm_marker == null:
		return
	var target_hurtbox: HurtboxComponent = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if target_hurtbox == null:
		return
	# Activar visual del storm: alpha alto, color pico.
	var rect: ColorRect = _storm_marker.get_node_or_null("Ring") as ColorRect
	if rect != null:
		rect.color = Color(0.95, 0.4, 1.0, 0.9)
	if _storm_marker.global_position.distance_to(_target.global_position) <= STORM_AOE_RADIUS:
		var dmg: int = int(round(
			float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity)) * STORM_DAMAGE_MULT
		))
		target_hurtbox.receive_hit(dmg, null)


func _cleanup_storm_marker() -> void:
	if is_instance_valid(_storm_marker):
		_storm_marker.queue_free()
	_storm_marker = null


## Construye un Node2D con un ColorRect (placeholder visual). Marker de AoE.
func _build_marker(pos: Vector2, color: Color, radius: float) -> Node2D:
	var root: Node2D = Node2D.new()
	root.global_position = pos
	root.z_index = -5

	var rect: ColorRect = ColorRect.new()
	rect.name = "Ring"
	rect.color = color
	rect.offset_left = -radius
	rect.offset_top = -radius * 0.4
	rect.offset_right = radius
	rect.offset_bottom = radius * 0.4
	root.add_child(rect)
	return root


## Override de _on_died para limpiar markers activos.
func _on_died() -> void:
	_cleanup_root_markers()
	_cleanup_storm_marker()
	super._on_died()
