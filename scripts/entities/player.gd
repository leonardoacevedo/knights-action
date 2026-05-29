extends CharacterBody2D
class_name Player

## Player entity. Orquesta componentes según arquitectura.md.
## Fase 1: movimiento, salto, dash, ataque básico, Furia con decay, Momentum.
## Próximo (Fase 1 backlog): Bloqueo con cargas, feedback de impacto extra.

const SPEED := 400.0
const JUMP_VELOCITY := -850.0     # igual al enemy: paridad base requerida por Leo
const GRAVITY_MULTIPLIER := 2.5

const ATTACK_DURATION := 0.3
const ATTACK_ACTIVE_START := 0.08
const ATTACK_ACTIVE_END := 0.18

## Proyectiles que el player dispara con armas ranged (Arco / Vara).
## Reuse de las mismas escenas que usan Archer / Mage, con team=1.
const PLAYER_ARROW_SCENE: PackedScene = preload("res://scenes/projectiles/projectile_arrow.tscn")
const PLAYER_FIREBALL_SCENE: PackedScene = preload("res://scenes/projectiles/projectile_fireball.tscn")

## Status effects que el player aplica a sí mismo (post-dash buffs + Espíritu Marcial)
## o que enemies aplican vía API pública (slow / stun / burn). El componente
## `status_effects` trackea lifecycle; el player consume vía `has(id) / get_magnitude(id)`.
const STATUS_SLOW: StatusEffectData = preload("res://resources/status_effects/slow.tres")
const STATUS_ESPIRITU_MARCIAL: StatusEffectData = preload("res://resources/status_effects/espiritu_marcial.tres")
const STATUS_POST_DASH_DAMAGE: StatusEffectData = preload("res://resources/status_effects/post_dash_damage.tres")
const STATUS_POST_DASH_INVIS: StatusEffectData = preload("res://resources/status_effects/post_dash_invis.tres")
const STATUS_STUN: StatusEffectData = preload("res://resources/status_effects/stun.tres")
const STATUS_BURN: StatusEffectData = preload("res://resources/status_effects/burn.tres")

@export var team: int = 1

# Referencias a hijos (resueltas en _ready).
@onready var sprite: StickFigure = $StickFigure
@onready var health: HealthComponent = $HealthComponent
@onready var furia: FuriaComponent = $FuriaComponent
@onready var dash: DashComponent = $DashComponent
@onready var hitbox: HitboxComponent = $Hitbox
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var shield: ShieldComponent = $ShieldComponent
@onready var momentum_particles: GPUParticles2D = $MomentumParticles
@onready var player_stats: PlayerStatsComponent = $PlayerStatsComponent

var is_attacking: bool = false
var current_facing: int = 1

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _attack_time: float = 0.0
## Si es true, el ATTACK actual es ranged (arco/vara). No activa hitbox melee;
## el proyectil ya fue spawneado al inicio. Solo dura para la animación visual.
var _is_ranged_attack: bool = false
## Si es true, ya disparamos el proyectil en este attack (evita doble spawn).
var _projectile_fired_this_attack: bool = false
## Timestamp del último screen-shake disparado por recibir daño (ms).
## Rate-limit: con multi-enemy las vibraciones encadenadas marean.
const DAMAGE_SHAKE_COOLDOWN_MS: int = 1000
var _last_damage_shake_ms: int = -DAMAGE_SHAKE_COOLDOWN_MS

## FUEGO 3pc: si true, el próximo golpe hace AoE. Se activa al matar un enemy.
var _fuego_next_attack_aoe: bool = false

## Multiplicador sobre SPEED. Seteado por PlayerStatsComponent vía MOVE_SPEED_PCT
## + bump multiplicativo si VIENTO 2pc set bonus está activo.
var move_speed_mult: float = 1.0

## LUZ 2pc set bonus — regen pasivo HP/segundo. Seteado por PlayerStatsComponent.
## 0 = sin regen. Tickea en _physics_process via accumulator.
var _luz_passive_regen_per_sec: float = 0.0
var _luz_regen_accum: float = 0.0

## Tank R2 que tiene al player en TAUNT. Mientras != null:
## - El facing del player se fuerza hacia el tank (ignora input lateral).
## - La velocidad horizontal del player se fuerza hacia el tank (movimiento atraído).
## - Player puede saltar, atacar, bloquear, dashear normalmente — solo el horizontal
##   movement + facing están forzados.
## Seteado por Enemy._start_taunt() y limpiado en _end_taunt() / muerte del tank.
## Distancia de "pegado" — dentro de este radio el pull se corta para no glitchear.
var _taunt_source: Node2D = null
const TAUNT_PULL_STOP_DISTANCE: float = 35.0

## Status effects (slow, espiritu_marcial, post_dash_*, burn, stun, etc).
## Instanciado en _ready(). Lifecycle (tick + expiración) lo maneja el componente.
## Side effects (modificar velocity, alpha, hitbox.force_elem_advantage, take_damage)
## se aplican acá en player.gd vía signals `effect_applied/expired/ticked` o queries.
## Migrado 27/05: reemplaza _external_speed_*, _espiritu_marcial_*, _post_dash_*.
var status_effects: StatusEffectComponent


func _ready() -> void:
	# Wireo cruzado entre componentes (inyección, no get_parent).
	hurtbox.health_component = health
	hurtbox.team = team
	hurtbox.shield = shield
	hurtbox.scene_root = get_tree().current_scene  # para floater "MISS!"
	hitbox.team = team
	dash.hurtbox = hurtbox
	# AGUA 3pc: usar la hitbox del player como area de detección durante el dash.
	# La hitbox ya cubre el cuerpo del player, suficiente para detectar solapamiento.
	dash.detection_area = hitbox

	# StatusEffectComponent: hijo runtime para no tocar player.tscn.
	# Maneja slow, espiritu_marcial, post_dash_*, burn, stun, etc.
	status_effects = StatusEffectComponent.new()
	status_effects.name = "StatusEffects"
	add_child(status_effects)
	status_effects.effect_applied.connect(_on_status_applied)
	status_effects.effect_expired.connect(_on_status_expired)
	status_effects.effect_ticked.connect(_on_status_ticked)

	# Inyectar referencias en PlayerStatsComponent antes de recalcular.
	player_stats.health = health
	player_stats.hitbox = hitbox
	player_stats.hurtbox = hurtbox
	# Estado inicial: aplicar stats del equipo actual (si ya hay algo equipado).
	player_stats.recalculate()
	# Suscribirse a cambios de equipo para refrescar el visual de armas en el StickFigure.
	InventorySystem.equipped_changed.connect(_on_equipped_changed)
	_refresh_weapon_visuals()
	# Actualizar flags de set bonus 3pc al inicio (estado inicial del equipo).
	_refresh_set_bonus_flags()

	# Señales.
	hitbox.hit_landed.connect(_on_hit_landed)
	hurtbox.hit_received.connect(_on_hit_received)
	hurtbox.hit_blocked.connect(_on_hit_blocked)
	health.died.connect(_on_died)
	dash.dash_ended.connect(_on_dash_ended)

	# Bloqueo: feedback visual del aura sostenida (se activa con block_started).
	shield.block_started.connect(_on_block_started)
	shield.block_ended.connect(_on_block_ended)

	# Recarga de cargas al completar etapa (PvE). GDD §4.3.
	StageManager.stage_cleared.connect(_on_stage_cleared)

	# Feedback visual de Momentum a partir de 5x.
	MomentumSystem.threshold_5x_reached.connect(_on_momentum_threshold_reached)
	MomentumSystem.threshold_5x_lost.connect(_on_momentum_threshold_lost)
	MomentumSystem.momentum_reset.connect(_on_momentum_threshold_lost)

	# Demo: agregar items al inventario SIN equipar.
	# Player arranca sin equipo para playtest balance base; equipa desde la UI in-game.
	call_deferred("_add_default_items_to_inventory")

	# Sistema de skills activas (Furia → habilidad). Loadout default 3 slots:
	# 1=Embestida (gap closer + buff swing), 2=Bola de Fuego (proyectil), 3=Onda Sísmica (AoE + BURN).
	# Si SaveSystem ya restauró slots (loaded from disk), respetamos esa selección.
	# Equip default solo si el slot quedó vacío tras load (primera sesión o save sin loadout).
	PlayerSkillSystem.register_player(self)
	if PlayerSkillSystem.get_equipped(0) == null:
		PlayerSkillSystem.equip(0, preload("res://resources/player_skills/embestida.tres"))
	if PlayerSkillSystem.get_equipped(1) == null:
		PlayerSkillSystem.equip(1, preload("res://resources/player_skills/bola_fuego.tres"))
	if PlayerSkillSystem.get_equipped(2) == null:
		PlayerSkillSystem.equip(2, preload("res://resources/player_skills/onda_sismica.tres"))


func _add_default_items_to_inventory() -> void:
	# Items demo de Fase 1 disponibles en la mochila desde el inicio.
	# Set completo para testeo: 1 R1 por slot + R2 surtidos + R3 + R4 boss-tier.
	# Path: resources/items/<slot>/<id>.tres.
	var paths: Array[String] = [
		# R1 (común) — set de partida
		"res://resources/items/weapons/espada_madera.tres",
		"res://resources/items/armor/tunica_aprendiz.tres",
		"res://resources/items/shields/escudo_tablones.tres",
		# R2 (raro)
		"res://resources/items/weapons/espada_hierro.tres",
		"res://resources/items/weapons/arco_corto.tres",
		"res://resources/items/armor/cota_cuero.tres",
		"res://resources/items/shields/escudo_hierro.tres",
		# R3 (épico)
		"res://resources/items/weapons/espada_runica.tres",
		"res://resources/items/weapons/vara_cristal.tres",
		"res://resources/items/armor/coraza_placas.tres",
		"res://resources/items/shields/escudo_torre.tres",
		# R4 (legendario / boss drop)
		"res://resources/items/weapons/martillo_guardian.tres",
	]
	for path: String in paths:
		var item: ItemData = load(path) as ItemData
		if item == null:
			push_warning("Player: no se pudo cargar item demo en '%s'" % path)
			continue
		InventorySystem.add_item(item)


## API para PlayerStatsComponent: multiplica SPEED por bonus de skill MOVE_SPEED_PCT.
func set_move_speed_mult(mult: float) -> void:
	move_speed_mult = mult


## API para PlayerStatsComponent: LUZ 2pc set bonus regen pasivo HP/segundo.
## 0 = sin regen (default). Player.gd tickea en _physics_process via _luz_regen_accum.
func set_luz_passive_regen(rate_per_sec: float) -> void:
	_luz_passive_regen_per_sec = max(0.0, rate_per_sec)
	if _luz_passive_regen_per_sec <= 0.0:
		_luz_regen_accum = 0.0


## API para Enemy (tank R2) cuando inicia/termina su Taunt MMO clásico.
## Mientras el tank tenga taunt activo, el player es arrastrado físicamente hacia él.
## Decisión Leo: aunque se sienta "roto" en feel, el taunt DEBE ser así para que cumpla
## su rol — atrae al player obligatoriamente. Liberar pasando null.
func set_taunt_source(tank: Node2D) -> void:
	_taunt_source = tank


## API para skills de bosses que aplican slow temporal al player.
## mult: multiplicador sobre SPEED (0.5 = 50% velocidad).
## duration: segundos del efecto. Si ya hay slow activo, gana el más restrictivo
## (magnitude_policy KEEP_MIN) y la duración mayor (REFRESH).
func apply_slow(mult: float, duration: float) -> void:
	if mult <= 0.0 or duration <= 0.0:
		return
	if status_effects == null:
		return  # _ready aún no corrió — caso edge (boss spawn antes que el player)
	# Si ya hay slow, refrescar a la duration mayor — REFRESH usa la pasada,
	# pero si la actual remaining es mayor preservamos eso manualmente.
	var current_remaining: float = status_effects.get_remaining(&"slow")
	var final_dur: float = max(duration, current_remaining)
	status_effects.apply(STATUS_SLOW, null, mult, final_dur)


## API genérica para aplicar cualquier status effect al player (skills, AoEs, DOTs).
## Equivalente a llamar status_effects.apply(...) — wrap para API consistente.
func apply_status_effect(data: StatusEffectData, source: Node = null, \
		magnitude_override: float = NAN, duration_override: float = NAN) -> void:
	if status_effects == null:
		return
	status_effects.apply(data, source, magnitude_override, duration_override)


## API para skills de enemies que aplican knockback (ej. R2 melee embestida).
## Suma el vector a velocity actual — se consume al siguiente _physics_process
## via fricción + gravedad. El dash sigue teniendo prioridad (override total).
func apply_external_velocity(push: Vector2) -> void:
	velocity += push


func _physics_process(delta: float) -> void:
	# Dash tiene prioridad sobre todo.
	if dash.is_dashing:
		velocity.x = dash.get_dash_velocity_x()
		velocity.y = 0.0
		move_and_slide()
		return

	# StatusEffectComponent tickea solo (lifecycle + tick signals). Lo único que
	# resta es expirar post_dash_invis residual si no llegó a atacar — eso lo
	# manejamos en _on_status_expired.
	_tick_luz_passive_regen(delta)
	_apply_gravity(delta)
	_handle_input()
	_tick_attack(delta)
	move_and_slide()


## LUZ 2pc set bonus — regen pasivo HP cada 1.0s. Accumulator-based.
func _tick_luz_passive_regen(delta: float) -> void:
	if _luz_passive_regen_per_sec <= 0.0:
		return
	if health == null or not health.is_alive():
		return
	if health.current_health >= health.max_health:
		return
	_luz_regen_accum += delta
	if _luz_regen_accum >= 1.0:
		_luz_regen_accum -= 1.0
		health.heal(int(round(_luz_passive_regen_per_sec)))


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * GRAVITY_MULTIPLIER * delta


func _handle_input() -> void:
	# STUN: bloquea TODO input mientras esté activo. Velocidad horizontal va a 0,
	# vertical sigue gravedad. Cap canónico 0.3s (ver habilidades_generales.md §3 ⛔).
	if status_effects.has(&"stun"):
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 2.0)
		shield.set_blocking(false)
		if not is_attacking:
			sprite.set_state(StickFigure.State.IDLE)
		return

	# is_action_pressed (no just_pressed) → joystick "arriba" mantiene salto al
	# tocar el suelo. Funciona idéntico para teclado: si mantenés Space, también
	# saltás de nuevo apenas aterrizás. Comportamiento de plataformero mobile.
	if Input.is_action_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Bloqueo: hold mientras no estés en attack/dash. Si no hay cargas, set_blocking ignora.
	var can_block: bool = not is_attacking and not dash.is_dashing
	var wants_block: bool = Input.is_action_pressed("block") and can_block
	shield.set_blocking(wants_block)

	# Slow externo (Mareo Frío, AoE de fuego/agua, etc.) leído del componente.
	# Default 1.0 = sin slow. KEEP_MIN policy → más restrictivo gana.
	# FREEZE se multiplica encima (slow + congelado stackean).
	var slow_mult: float = status_effects.get_magnitude(&"slow", 1.0) \
		* status_effects.get_magnitude(&"freeze", 1.0)

	# TAUNT MMO: si hay tank tauntando, forzar facing + movement horizontal hacia él.
	# Override total sobre el input lateral. Player puede saltar/atacar/bloquear/dashear.
	if _taunt_source != null and is_instance_valid(_taunt_source):
		var dx: float = _taunt_source.global_position.x - global_position.x
		var taunt_facing: int = int(sign(dx)) if abs(dx) > 1.0 else current_facing
		if taunt_facing != current_facing and taunt_facing != 0:
			_apply_facing(taunt_facing)
		# Pull horizontal a SPEED completa (no se puede contrarrestar).
		# Si está pegado al tank (dentro de TAUNT_PULL_STOP_DISTANCE), no se mueve.
		if abs(dx) <= TAUNT_PULL_STOP_DISTANCE:
			velocity.x = 0.0
		else:
			var speed_mult_t: float = 0.5 if shield.is_blocking else 1.0
			velocity.x = float(taunt_facing) * SPEED * speed_mult_t * move_speed_mult * slow_mult
	else:
		var dir: float = Input.get_axis("ui_left", "ui_right")
		if dir != 0.0:
			var new_facing: int = int(sign(dir))
			if new_facing != current_facing:
				_apply_facing(new_facing)
			# Velocidad reducida al 50% mientras bloqueás (decisión Leo).
			# move_speed_mult aplica bonus de skill MOVE_SPEED_PCT encima.
			# slow_mult aplica slow de skills enemigas (ej. Mareo Frío).
			var speed_mult: float = 0.5 if shield.is_blocking else 1.0
			velocity.x = dir * SPEED * speed_mult * move_speed_mult * slow_mult
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	if Input.is_action_just_pressed("dash"):
		# Dash cancela el bloqueo (suelta y dasha).
		if shield.is_blocking:
			shield.set_blocking(false)
		dash.try_dash(current_facing)

	if Input.is_action_just_pressed("attack") and not is_attacking:
		# Attack cancela el bloqueo (suelta y golpea).
		if shield.is_blocking:
			shield.set_blocking(false)
		_start_attack()

	# Skills activas — slots 0/1/2 mapeados a teclas 1/2/3 (ver project.godot input map).
	# `Input.is_action_just_pressed` retorna false si la acción no existe (Godot 4).
	if InputMap.has_action("skill_1") and Input.is_action_just_pressed("skill_1"):
		PlayerSkillSystem.try_use(0)
	if InputMap.has_action("skill_2") and Input.is_action_just_pressed("skill_2"):
		PlayerSkillSystem.try_use(1)
	if InputMap.has_action("skill_3") and Input.is_action_just_pressed("skill_3"):
		PlayerSkillSystem.try_use(2)

	# Estado visual.
	if not is_attacking:
		if shield.is_blocking:
			sprite.set_state(StickFigure.State.BLOCK)
		elif not is_on_floor():
			sprite.set_state(StickFigure.State.JUMP)
		elif abs(velocity.x) > 10.0:
			sprite.set_state(StickFigure.State.WALK)
		else:
			sprite.set_state(StickFigure.State.IDLE)


func _start_attack() -> void:
	is_attacking = true
	_attack_time = 0.0
	_projectile_fired_this_attack = false
	sprite.set_state(StickFigure.State.ATTACK)
	# Garantizar facing al iniciar (defensivo — _apply_facing ya lo hace en cada cambio).
	_apply_facing(current_facing)
	# Multiplicador base: Momentum.
	var dmg_mult: float = MomentumSystem.damage_multiplier()
	# Buff temporal Golpe Tras Dash: +X% daño si está activo. Se consume al atacar.
	if status_effects.has(&"post_dash_damage"):
		dmg_mult *= (1.0 + status_effects.get_magnitude(&"post_dash_damage"))
		status_effects.remove(&"post_dash_damage")
	# Buff temporal Espíritu Marcial: +X% daño físico tras absorber bloqueo.
	if status_effects.has(&"espiritu_marcial"):
		dmg_mult *= (1.0 + status_effects.get_magnitude(&"espiritu_marcial"))
	hitbox.damage_multiplier = dmg_mult
	# Sombra del Valle: si invis está activo, forzar ventaja elemental en este swing.
	# Flag de hitbox se consume en hitbox._on_area_entered al primer impacto.
	# Removemos el efecto acá — el visual modulate.a se restaura en _on_status_expired.
	if status_effects.has(&"post_dash_invis"):
		hitbox.force_elem_advantage = true
		status_effects.remove(&"post_dash_invis")

	# Detectar tipo de arma equipada para elegir entre melee y ranged.
	# Sword/Hammer/None → melee (hitbox toggle clásico).
	# Bow/Staff → ranged: spawn proyectil al inicio del swing, sin hitbox melee.
	var weapon: ItemData = InventorySystem.get_equipped(ItemData.Slot.ARMA)
	var visual: int = weapon.visual_type if weapon != null else StickFigure.WeaponType.NONE
	_is_ranged_attack = (visual == StickFigure.WeaponType.BOW \
		or visual == StickFigure.WeaponType.STAFF)
	# Setear elemento del arma en el hitbox para el cálculo elemental. GDD §5.3.
	# Si no hay arma equipada, NEUTRO (sin modifier).
	hitbox.element = weapon.element if weapon != null else ItemData.Element.NEUTRO
	# Hitbox de swing: configurar polígono según arma equipada. Si ranged, clear.
	if not _is_ranged_attack:
		var reach: float = weapon.weapon_reach if weapon != null else 0.0
		var width: float = weapon.weapon_width if weapon != null else 0.0
		var arc: float = weapon.weapon_arc_deg if weapon != null else 0.0
		var dz: float = weapon.weapon_damage_zone if weapon != null else 0.0
		# Scale: sprite.scale * sprite.weapon_scale para coincidir con render del arma.
		var scale_mult: float = 1.0
		if sprite != null:
			scale_mult = sprite.scale.x * sprite.weapon_scale
		hitbox.setup_weapon_swing(visual, reach, width, arc, dz, scale_mult)
	else:
		hitbox.clear_swing_shape()


## Aplica un facing nuevo: actualiza sprite, hitbox y arma visible.
## Llamarlo cada vez que cambia la dirección — no solo al atacar.
func _apply_facing(dir: int) -> void:
	if dir == 0:
		return
	current_facing = dir
	sprite.set_facing(current_facing)
	# La hitbox sigue al facing siempre: si girás sin atacar, queda del lado correcto
	# para cuando ataques. Si la hitbox ya está activa (mid-swing), tampoco se rompe.
	hitbox.position.x = abs(hitbox.position.x) * current_facing


func _tick_attack(delta: float) -> void:
	if not is_attacking:
		return
	_attack_time += delta

	if _is_ranged_attack:
		# Disparar el proyectil al inicio de la ventana activa, una sola vez por attack.
		if _attack_time >= ATTACK_ACTIVE_START and not _projectile_fired_this_attack:
			_spawn_player_projectile()
			_projectile_fired_this_attack = true
			# FUEGO 3pc: AoE también al disparar proyectil si el flag está activo.
			if _fuego_next_attack_aoe:
				_trigger_fuego_aoe()
	else:
		# Melee: hitbox activo solo en ventana ATTACK_ACTIVE_*.
		var should_be_active: bool = _attack_time >= ATTACK_ACTIVE_START and _attack_time <= ATTACK_ACTIVE_END
		if hitbox.monitoring != should_be_active:
			hitbox.set_active(should_be_active)
		# Animar polígono del swing durante la ventana activa. Progreso 0..1.
		if should_be_active:
			var win: float = max(ATTACK_ACTIVE_END - ATTACK_ACTIVE_START, 0.001)
			var p: float = clamp((_attack_time - ATTACK_ACTIVE_START) / win, 0.0, 1.0)
			hitbox.update_swing_arc(p, current_facing)
		# FUEGO 3pc: AoE al inicio de la ventana activa melee (una vez por swing).
		if _attack_time >= ATTACK_ACTIVE_START and _fuego_next_attack_aoe:
			_trigger_fuego_aoe()

	if _attack_time >= ATTACK_DURATION:
		is_attacking = false
		_is_ranged_attack = false
		_projectile_fired_this_attack = false
		hitbox.set_active(false)
		hitbox.clear_swing_shape()


func _on_hit_landed(target: HurtboxComponent) -> void:
	# Furia escala con Momentum (mismo multiplicador que daño).
	# MIASMA (SOMBRA synergy): reduce -50% generación de Furia mientras esté activo.
	var furia_mult: float = MomentumSystem.furia_multiplier()
	if status_effects != null and status_effects.has(&"miasma"):
		furia_mult *= 0.5
	furia.add_on_hit(furia_mult)
	MomentumSystem.on_hit_landed()
	# Feedback "weight": mini freeze + shake leve al conectar.
	HitStop.freeze(0.05)
	CameraShake.shake(1.5, 0.08)
	# FUEGO 3pc: si el golpe mató al enemy, activar flag para el próximo ataque.
	_check_fuego_kill(target)


func _on_hit_received(amount: int, _source: HitboxComponent, _was_advantage: int) -> void:
	# Recibir daño resetea Momentum (salvo bloqueo activo, manejado dentro del sistema).
	MomentumSystem.on_damage_taken()
	# El player siempre recibe en ROJO: no hay feedback elemental del lado del defensor (player).
	# El player es NEUTRO por defecto → todos los hits son ×1.0 por ahora.
	DamageFloater.spawn(get_tree().current_scene, global_position + Vector2(0, -70),
		amount, Color(1.0, 0.25, 0.25, 1.0))
	# Sin hit-stop al recibir daño: en multi-enemy se sentía como lag.
	# Solo screen-shake con cooldown (1/seg) para indicar el golpe sin marear.
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_damage_shake_ms >= DAMAGE_SHAKE_COOLDOWN_MS:
		_last_damage_shake_ms = now_ms
		var intensity: float = clamp(float(amount) / 30.0, 0.0, 1.0)
		CameraShake.shake(lerp(3.0, 10.0, intensity), 0.20)


func _on_momentum_threshold_reached() -> void:
	if momentum_particles != null:
		momentum_particles.emitting = true


func _on_momentum_threshold_lost() -> void:
	if momentum_particles != null:
		momentum_particles.emitting = false


# ─── Bloqueo: handlers ────────────────────────────────────────────────────────

func _on_block_started() -> void:
	sprite.start_block_aura()


func _on_block_ended() -> void:
	sprite.end_block_aura()


## Disparado por hurtbox cuando un golpe fue absorbido por el shield.
## Hace burst visual + floater "BLOCK!" + congela Momentum 1s (no resetea).
## Espíritu Marcial: si el skill está desbloqueado, activa +20% daño por 2s.
func _on_hit_blocked(_amount: int, _source: HitboxComponent) -> void:
	sprite.play_block_burst()
	MomentumSystem.on_block_absorbed()
	DamageFloater.spawn_text(get_tree().current_scene,
		global_position + Vector2(0, -70),
		"BLOCK!", Color(0.55, 0.85, 1.0, 1.0))
	# Feedback "absorb": mini freeze + shake leve (más sutil que recibir daño).
	HitStop.freeze(0.06)
	CameraShake.shake(2.0, 0.10)
	# Espíritu Marcial: buff temporal de contraataque. StackMode EXTEND en el .tres
	# acumula duración (stack ilimitado contra runs largos de bloqueos seguidos).
	var prog: Node = get_node_or_null("/root/PlayerProgression")
	if prog != null and prog.is_unlocked(&"guerrero_espiritu_marcial"):
		status_effects.apply(STATUS_ESPIRITU_MARCIAL)


## Recarga de cargas al completar etapa. GDD §4.3 (PvE).
func _on_stage_cleared(_index: int) -> void:
	shield.restore_all()


func _on_died() -> void:
	sprite.set_state(StickFigure.State.DEAD)
	set_physics_process(false)
	# Soltar bloqueo si estaba activo (evita aura/postura colgada tras morir).
	if shield != null and shield.is_blocking:
		shield.set_blocking(false)
	# Desregistrar del PlayerSkillSystem para que no quede referencia colgada.
	if PlayerSkillSystem != null:
		PlayerSkillSystem.unregister_player(self)
	# Mostrar pantalla de Game Over con botón Reintentar.
	_spawn_game_over_screen()


## Instancia la UI de Game Over como hija del root para que sobreviva al
## set_physics_process(false) del player.
func _spawn_game_over_screen() -> void:
	var scene: PackedScene = preload("res://scenes/ui/game_over_screen.tscn")
	if scene == null:
		push_warning("Player: game_over_screen.tscn no encontrado.")
		return
	var screen: CanvasLayer = scene.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(screen)


# ─── Refresh visual de armas según equipo ─────────────────────────────────────

func _on_equipped_changed(_slot: ItemData.Slot, _item: ItemData) -> void:
	_refresh_weapon_visuals()
	# recalculate() ya fue llamado por PlayerStatsComponent (que también escucha equipped_changed).
	# Acá solo propagamos los flags de 3pc a los componentes que los usan en runtime.
	_refresh_set_bonus_flags()


## Lee InventorySystem.get_equipped() y actualiza weapon_main/off del StickFigure.
## Arma → main hand. Escudo → off hand. Si no hay arma, fists (NONE).
func _refresh_weapon_visuals() -> void:
	var weapon: ItemData = InventorySystem.get_equipped(ItemData.Slot.ARMA)
	# shield_item (no shield) para no shadowear @onready var shield: ShieldComponent.
	var shield_item: ItemData = InventorySystem.get_equipped(ItemData.Slot.ESCUDO)
	var main_type: int = StickFigure.WeaponType.NONE
	var off_type: int = StickFigure.WeaponType.NONE
	if weapon != null:
		main_type = weapon.visual_type
	if shield_item != null:
		# Si el escudo no tiene visual_type seteado, asumir SHIELD por slot.
		off_type = shield_item.visual_type if shield_item.visual_type != 0 else StickFigure.WeaponType.SHIELD
	sprite.set_weapons(main_type, off_type)


# ─── Ranged attacks (arco / vara) ─────────────────────────────────────────────

## Spawnea el proyectil según el visual_type del arma equipada.
## - Bow → arrow.
## - Staff → fireball.
## El daño usa el del hitbox (que ya tiene los stats del arma aplicados por
## PlayerStatsComponent) × multiplicador de Momentum.
func _spawn_player_projectile() -> void:
	var weapon: ItemData = InventorySystem.get_equipped(ItemData.Slot.ARMA)
	if weapon == null:
		return
	var scene: PackedScene
	match weapon.visual_type:
		StickFigure.WeaponType.BOW:   scene = PLAYER_ARROW_SCENE
		StickFigure.WeaponType.STAFF: scene = PLAYER_FIREBALL_SCENE
		_:
			return  # No es ranged, no debería estar acá.
	if scene == null:
		return
	var proj: Projectile = scene.instantiate() as Projectile
	if proj == null:
		push_warning("Player: projectile scene no instancia un Projectile.")
		return
	# Spawn point: a la altura del torso/mano frontal, offset hacia el facing.
	proj.global_position = global_position + Vector2(20.0 * current_facing, -45.0)
	# Daño final = hitbox.damage × los mismos multiplicadores que el melee.
	# fix C3: hitbox.damage_multiplier ya incluye Momentum + post-dash + Espíritu Marcial
	# (seteado en _start_attack), y damage_set_bonus_multiplier el set bonus (FUEGO 2pc).
	# El ranged los ignoraba (solo aplicaba Momentum). El modifier elemental lo calcula
	# el propio proyectil en su _on_area_entered, igual que el melee con elem_mult.
	var final_damage: int = int(round(float(hitbox.damage) \
		* hitbox.damage_multiplier * hitbox.damage_set_bonus_multiplier))
	# Elemento del arma: ya está en hitbox.element (seteado en _start_attack).
	proj.launch(Vector2(current_facing, 0.0), final_damage, team, hitbox.element)
	proj.set_source(self)  # LUZ vampire heal tracking
	# Suscribirse al hit del proyectil para ganar Furia + Momentum al impactar.
	proj.hit_landed.connect(_on_projectile_hit_landed)
	get_tree().current_scene.add_child(proj)


func _on_projectile_hit_landed(target: HurtboxComponent) -> void:
	# Mismo efecto que un hit melee: gana Furia + sube Momentum.
	_on_hit_landed(target)


# ─── Set Bonus FUEGO 3pc ──────────────────────────────────────────────────────

## Activa el flag de AoE si el target murió con este golpe y FUEGO 3pc está activo.
func _check_fuego_kill(target: HurtboxComponent) -> void:
	if not _is_fuego_3pc_active():
		return
	# Verificar que el target tiene HealthComponent y está muerto.
	if target == null:
		return
	var hc: HealthComponent = target.health_component
	if hc != null and not hc.is_alive():
		_fuego_next_attack_aoe = true


## Dispara el AoE de FUEGO 3pc desde la posición actual del player.
## Radio y % de daño vienen del SetBonusData para respetar datos en .tres.
func _trigger_fuego_aoe() -> void:
	_fuego_next_attack_aoe = false
	var sbs: Node = get_node_or_null("/root/SetBonusSystem")
	if sbs == null:
		return
	var data: SetBonusData = sbs.get_active_bonus_data()
	if data == null or data.fuego_aoe_radius <= 0.0:
		return

	# Daño del AoE = damage final del hitbox × fuego_aoe_damage_pct.
	var aoe_damage: int = int(round(float(hitbox.damage) * \
		hitbox.damage_multiplier * hitbox.damage_set_bonus_multiplier * data.fuego_aoe_damage_pct))
	if aoe_damage <= 0:
		return

	# Iterar sobre todos los hurtboxes de enemy en el radio usando Physics2DServer.
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = data.fuego_aoe_radius
	query.shape = circle_shape
	query.transform = Transform2D(0.0, global_position)
	# Mask: bit 5 (layer de Hurtbox). Coincidir con HurtboxComponent._ready().
	query.collision_mask = 0b10000
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is HurtboxComponent:
			var hb: HurtboxComponent = collider
			if hb.team == team:
				continue  # no dañar al propio player
			# Aplicar elemental modifier (usa elemento del arma equipada).
			var elem_mult: float = GameConfig.element_modifier(hitbox.element, hb.element)
			var final_dmg: int = int(round(float(aoe_damage) * elem_mult))
			hb.receive_hit(final_dmg, hitbox, 0)


## Retorna true si el set bonus FUEGO 3pc está activo en este momento.
func _is_fuego_3pc_active() -> bool:
	var sbs: Node = get_node_or_null("/root/SetBonusSystem")
	if sbs == null:
		return false
	return sbs.is_active(ItemData.Element.FUEGO, 3)


# ─── Buffs temporales post-dash ──────────────────────────────────────────────

## Activado por DashComponent.dash_ended. Si el player tiene el skill desbloqueado,
## aplica buffs post-dash via StatusEffectComponent.
## Golpe Tras Dash (+X% daño / 0.5s) y Sombra del Valle (invis + ventaja elemental).
func _on_dash_ended() -> void:
	var prog: Node = get_node_or_null("/root/PlayerProgression")
	if prog == null:
		return
	# Golpe Tras Dash: la magnitud viene del skill_pct del nodo (POST_DASH_DAMAGE_PCT).
	# NO suma DAMAGE_PCT global (evita double-count con espiritu_marcial / sombra_del_valle).
	if prog.is_unlocked(&"agil_golpe_tras_dash"):
		var dmg_pct: float = prog.get_skill_bonus_pct(SkillEffect.Stat.POST_DASH_DAMAGE_PCT)
		status_effects.apply(STATUS_POST_DASH_DAMAGE, null, dmg_pct)
	# Sombra del Valle: invis + garantía ventaja elemental al próximo swing.
	# Side effect visual (modulate.a) lo aplica _on_status_applied.
	if prog.is_unlocked(&"agil_sombra_del_valle"):
		status_effects.apply(STATUS_POST_DASH_INVIS)


## Side effects visuales / lógicos al aplicarse un status effect.
func _on_status_applied(id: StringName, _magnitude: float, _source: Node) -> void:
	if id == &"post_dash_invis":
		modulate.a = 0.35
	elif id == &"desequilibrio":
		# VIENTO synergy: interrumpe swing actual si el player está atacando.
		# No bloquea inputs futuros — solo el ataque en curso se cancela.
		if is_attacking:
			is_attacking = false
			_is_ranged_attack = false
			_projectile_fired_this_attack = false
			if hitbox != null:
				hitbox.set_active(false)


## Side effects visuales / lógicos al expirar un status effect.
## Restaura alpha, limpia force_elem_advantage si nunca llegó a atacar, etc.
func _on_status_expired(id: StringName, _source: Node) -> void:
	if id == &"post_dash_invis":
		modulate.a = 1.0
		if hitbox != null:
			hitbox.force_elem_advantage = false


## Tick de DOTs (BURN/MIASMA aplican daño cada N segundos). Magnitud = damage por tick.
## MIASMA (SOMBRA): bypass armor — no pasa por hurtbox.flat_defense, daño directo a HP.
func _on_status_ticked(id: StringName, magnitude: float, _source: Node) -> void:
	match id:
		&"burn":
			var dmg_b: int = int(round(magnitude))
			if dmg_b > 0:
				hurtbox.receive_hit(dmg_b, null, 0)
		&"miasma":
			var dmg_m: int = int(round(magnitude))
			if dmg_m > 0 and health != null:
				health.take_damage(dmg_m)  # bypass armor (eje cósmico)


# ─── Flags de 3pc — actualizados al cambiar equipo ───────────────────────────

## Refresca tierra_3pc_active en ShieldComponent y agua_3pc_active en DashComponent.
## Se llama desde _ready (estado inicial) y _on_equipped_changed.
func _refresh_set_bonus_flags() -> void:
	var sbs: Node = get_node_or_null("/root/SetBonusSystem")
	if sbs == null:
		return
	# Los flags de SetBonusSystem se actualizan en recalculate() de PlayerStatsComponent.
	# Acá solo propagamos los flags a los componentes que los necesitan en _process.
	shield.tierra_3pc_active  = sbs.is_active(ItemData.Element.TIERRA, 3)
	dash.agua_3pc_active      = sbs.is_active(ItemData.Element.AGUA, 3)
