extends CharacterBody2D
class_name Enemy

## Enemy con state machine inline. GDD §7.3:
## - R1: IDLE → CHASE → TELEGRAPH → ATTACK → RECOVERY → IDLE. Sin bloqueo.
## - R2: + estado BLOCK (bloqueo ocasional con cooldown). Obliga a romper guardia.
## - R3: + estado DODGE (dash lateral reactivo) + SKILL (ataque especial con telegrafía larga).
##   Mantiene distancia, fuerza esquivas activas del jugador.

## DEBUG: se setea desde GameConfig.DEBUG_ENEMY_AI en _ready().
## Throttling: imprime cuando cambia algo relevante (dirección, ceiling, salto).
## Para apagar/prender globalmente: editar GameConfig (archivo .env).
var DEBUG_ENABLED: bool = false

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, RECOVERY, HURT, DEAD, BLOCK, DODGE, SKILL_TELEGRAPH, SKILL_ATTACK, R2_SKILL_TELEGRAPH, R2_SKILL_ATTACK }

# Stats variables — seteados en _ready() desde GameConfig según enemy_class.
var speed: float = 400.0                  # paridad base con el player
var attack_range: float = 60.0            # melee/tank: corto. archer/mage: largo (380-420)
var detect_range: float = 500.0           # archer/mage: 900-950, melee/tank: 500
var telegraph_seconds: float = 0.7        # tank usa 1.0 (más lento y pesado)

const ATTACK_DURATION := 0.25
const ATTACK_ACTIVE_START := 0.05
const ATTACK_ACTIVE_END := 0.15
const RECOVERY_SECONDS := 0.6

# Salto reactivo: si target está arriba y cerca horizontalmente.
const JUMP_VELOCITY := -850.0                 # igual al player
## Velocidad horizontal durante el salto, FIJA para todos los enemies (no varía por clase).
## Razón: JUMP_TRIGGER_MAX_DISTANCE=250 está calculado para vx=400; si el tank (vx=260)
## usara su speed en aire, no alcanzaría las plataformas que el threshold dice que sí.
## Caminar sigue usando `speed` (que sí varía por clase, ej. tank 260).
const JUMP_HORIZONTAL_SPEED := 400.0
const JUMP_COOLDOWN := 0.6
const JUMP_TRIGGER_HEIGHT_DIFF := 40.0        # target Y al menos N px más arriba
const JUMP_TRIGGER_MAX_DISTANCE := 290.0      # alcance horizontal real con SPEED=400 + margen antes de entrar al rango ceiling lateral
const CEILING_CHECK_DISTANCE := 100.0         # px arriba de la cabeza para detectar techo
const CEILING_CHECK_SIDE_OFFSET := 100.0      # margen lateral: el enemy DEBE estar a >100px del borde de la plataforma antes de saltar para no chocar con la esquina lateral

# Caída desde plataforma: si target está abajo y enemy sobre plataforma.
const FALLOFF_CHECK_LATERAL := 30.0           # px lateral del raycast hacia abajo. Corto para detectar SOLO el borde de la plataforma actual, NO plataformas vecinas
const FALLOFF_CHECK_DEPTH := 50.0             # px hacia abajo del raycast lateral
const CHASE_DIRECTION_HYSTERESIS := 30.0      # tolerancia anti-oscilación cuando no hay borde detectado

# Multi-hop: si target está más alto que MAX_JUMP_HEIGHT, usar plataforma intermedia como escalón.
const MAX_JUMP_HEIGHT := 145.0                # altura alcanzable con JUMP_VELOCITY actual
const INTERMEDIATE_CHECK_INTERVAL := 0.5      # cada N segundos refresca cálculo de plataforma intermedia
# Histéresis para evitar oscilación entre DIRECT e INTERMEDIATE cuando dy_above está al filo:
const MULTI_HOP_ACTIVATE_DY := MAX_JUMP_HEIGHT * 0.95     # 137.75 → si dy > 138, activa multi-hop
const MULTI_HOP_DEACTIVATE_DY := MAX_JUMP_HEIGHT * 0.80   # 116 → si dy < 116, vuelve a DIRECT
# También activar multi-hop si target está fuera del alcance HORIZONTAL del salto.
const MULTI_HOP_ACTIVATE_DX := JUMP_TRIGGER_MAX_DISTANCE * 1.05  # 263 → si dx > 263, multi-hop
const MULTI_HOP_DEACTIVATE_DX := JUMP_TRIGGER_MAX_DISTANCE * 0.80 # 200 → si dx < 200, vuelve a DIRECT

@export var team: int = 2
@export var target_path: NodePath  ## Asignar desde world.tscn al Player.

## Clase del enemy. Determina HP, daño, velocidad y comportamiento (melee vs ranged).
## Stats finales se leen de GameConfig según este valor.
@export_enum("Melee:0", "Tank:1", "Archer:2", "Mage:3") var enemy_class: int = 0

## Rareza del enemy. Escala HP/daño/telegraph encima de la clase.
## R4 = boss (sprite más grande, telegraph más largo, mucho HP).
## Seteable desde el spawner antes de add_child para que _ready la respete.
@export_enum("R1:0", "R2:1", "R3:2", "R4:3") var rarity: int = 0

## Elemento del enemy. Seteable desde EnemySpawnEntry vía world.gd.
## Afecta el modifier elemental del daño que recibe y del daño que aplica.
## NEUTRO=0 = sin ventaja/desventaja. GDD §5.3.
@export_enum("Neutro:0", "Fuego:1", "Agua:2", "Tierra:3") var element: int = 0

## Escena del proyectil que dispara este enemy. Null para clases melee/tank.
## Asignar en el .tscn variante (archer → projectile_arrow.tscn, mage → projectile_fireball.tscn).
@export var projectile_scene: PackedScene

@onready var sprite: StickFigure = $StickFigure
@onready var health: HealthComponent = $HealthComponent
@onready var hitbox: HitboxComponent = $Hitbox
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var _block_handler: EnemyBlockHandler = $EnemyBlockHandler

var state: State = State.IDLE
var current_facing: int = 1
var _target: Node2D = null

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _state_timer: float = 0.0
var _jump_cooldown_timer: float = 0.0

# Cache de plataforma intermedia para multi-hop (refrescada cada INTERMEDIATE_CHECK_INTERVAL).
var _intermediate_platform: Node2D = null
var _intermediate_check_timer: float = 0.0

# Estado de histéresis del multi-hop: se activa con threshold alto, se desactiva con bajo.
var _multi_hop_active: bool = false

# Multiplicador de velocity.x en aire. Reducido durante saltos laterales para que la trayectoria
# parabólica suba lo suficiente antes de cruzar el lado de la plataforma destino.
var _air_speed_factor: float = 1.0

# Para clases ranged: flag para garantizar UN solo proyectil por ATTACK.
var _projectile_fired_this_attack: bool = false

# ─── R2: bloqueo instintivo ────────────────────────────────────────────────────
## Cooldown restante entre bloqueos. Empieza en 0 para que pueda bloquear enseguida.
var _block_cooldown: float = 0.0
## Duración del bloqueo actual (seteada al entrar al estado BLOCK con RNG).
var _block_duration_current: float = 0.7
## Duración máxima de un bloqueo activo (segundos). Varía por instancia aleatoria.
const BLOCK_DURATION_MIN: float = 0.5
const BLOCK_DURATION_MAX: float = 1.0
## Cooldown entre bloqueos consecutivos (segundos).
const BLOCK_COOLDOWN_SECONDS: float = 2.5
## Probabilidad de entrar a BLOCK cuando el player ataca (0-1). Solo R2+.
const BLOCK_TRIGGER_CHANCE: float = 0.40

# ─── R3: dodge + skill ────────────────────────────────────────────────────────
## Cooldown restante del dash de esquiva.
var _dodge_cooldown: float = 0.0
## Cooldown restante del skill R3 especial.
var _skill_cooldown: float = 0.0
## Flag: el skill disparó el proyectil especial en este ciclo.
var _skill_fired_this_cast: bool = false
## Distancia del dash de esquiva lateral (px).
const DODGE_DISTANCE: float = 120.0
## Velocidad horizontal del dash (px/s). Termina en < 0.25s a esta distancia.
const DODGE_SPEED: float = 600.0
## Destino X del dodge (absoluto en world space).
var _dodge_target_x: float = 0.0
## Cooldown del dash (segundos).
const DODGE_COOLDOWN_SECONDS: float = 4.0
## Probabilidad de esquivar cuando el player ataca (0-1). Solo R3.
const DODGE_TRIGGER_CHANCE: float = 0.25
## Duración de la telegrafía del skill especial (cumple ≥1.5s según spec).
const SKILL_TELEGRAPH_SECONDS: float = 1.5
## Duración del estado SKILL_ATTACK antes de recovery.
const SKILL_ATTACK_DURATION: float = 0.3
## Daño del skill = daño_normal * este multiplicador.
const SKILL_DAMAGE_MULT: float = 1.5
## Cooldown del skill R3 (segundos). Varía +RNG al resetear.
const SKILL_COOLDOWN_MIN: float = 6.0
const SKILL_COOLDOWN_MAX: float = 8.0

# ─── R3 Guerrero: Sed de Sangre (buff propio) ────────────────────────────────
## Cooldown del buff "Sed de Sangre". Solo Guerrero R3.
## 12s base. Cuando llega a 0 en CHASE, activa el buff antes de pelear.
var _skill_r3_buff_cooldown: float = 12.0
## Tiempo restante del buff activo (0 = inactivo).
var _r3_buff_timer: float = 0.0
## Duración del buff (5s).
const R3_BUFF_DURATION: float = 5.0
## Multiplicador de velocidad durante el buff (×1.2).
const R3_BUFF_SPEED_MULT: float = 1.20
## Multiplicador de velocidad de recuperación (×0.83 = ataques más rápidos).
const R3_BUFF_RECOVERY_MULT: float = 0.83
## Duración de telegrafía del buff (1.0s según spec).
const R3_BUFF_TELEGRAPH_SECONDS: float = 1.0
## Cooldown base del buff en segundos.
const R3_BUFF_COOLDOWN: float = 12.0
## True mientras el SKILL_TELEGRAPH/SKILL_ATTACK corresponden al buff (no al proyectil potenciado).
var _r3_buff_casting: bool = false

# ─── R2: skill activo por clase ───────────────────────────────────────────────
## Cooldown restante del skill R2. Independiente del cooldown R3.
var _skill_r2_cooldown: float = 0.0
## Flag: el skill R2 ya ejecutó su acción en este ciclo (proyectil, dash, etc.).
var _skill_r2_fired: bool = false
## Flag: el tank tiene el taunt activo ahora mismo.
var _taunt_active: bool = false
## Tiempo restante del taunt (R2 Tank).
var _taunt_timer: float = 0.0
## Cache de Line2D activos para las líneas del taunt (un Line2D por aliado protegido).
var _taunt_lines: Array[Line2D] = []
## Lista de enemies dentro del radio del taunt (protegidos por el tank).
var _taunt_soakers: Array[Node2D] = []
## Posición destino X del melee-dash R2 (Melee skill).
var _r2_melee_dash_target_x: float = 0.0
## Velocidad del melee dash R2 (px/s).
const R2_MELEE_DASH_SPEED: float = 580.0
## Distancia del dash del skill R2 Melee (px).
const R2_MELEE_DASH_DISTANCE: float = 120.0
## Knockback aplicado al player tras el dash skill (px). Positivo = alejarse.
const R2_MELEE_KNOCKBACK: float = 40.0
## Duración de la telegrafía R2 (reusar SKILL_TELEGRAPH_SECONDS como mínimo — ver tabla).
## Radio del taunt tank (px). Enemies dentro de este radio reciben protección.
## Nerf 26/05: 60 → 45 — cubre 1-2 enemies típicos, no 2-3.
const R2_TANK_TAUNT_RADIUS: float = 45.0
## Duración del taunt (segundos).
const R2_TANK_TAUNT_DURATION: float = 3.0
## Porcentaje de daño redirigido al tank durante el taunt.
## Cambio 27/05: 0.3 → 1.0 — TAUNT MMO clásico. El tank ABSORBE 100% del daño que
## el player intenta hacer a sus aliados dentro del radio. Mecánica clara y firme:
## "romper al tank o no pegarle a nadie en su zona".
const R2_TANK_TAUNT_REDIRECT: float = 1.0

## Tabla de configuración del skill R2 por clase.
## Keys: interos del enum EnemyClass (MELEE=0, TANK=1, ARCHER=2, MAGE=3).
## Uso directo de enteros para evitar dependencia de parseo estático sobre GameConfig autoload.
## Sub-keys: telegraph_sec, cd_min, cd_max, attack_duration.
## Los valores de telegrafía cumplen GDD §7.3 R2: ≥0.5s ataques pesados.
const R2_SKILL_TABLE: Dictionary = {
	2: {  ## ARCHER
		"telegraph_sec": 0.8,
		"cd_min": 7.0,
		"cd_max": 9.0,
		"attack_duration": 0.35,
	},
	0: {  ## MELEE
		"telegraph_sec": 0.6,
		"cd_min": 5.0,
		"cd_max": 7.0,
		"attack_duration": 0.25,
	},
	3: {  ## MAGE
		"telegraph_sec": 1.2,
		"cd_min": 9.0,
		"cd_max": 11.0,
		"attack_duration": 0.4,
	},
	1: {  ## TANK
		"telegraph_sec": 0.5,
		"cd_min": 11.0,
		"cd_max": 13.0,
		"attack_duration": 0.3,
	},
}

# Debug: cache para imprimir solo cuando cambia algo relevante.
var _dbg_last_facing: int = 0
var _dbg_last_ceiling: bool = false
var _dbg_last_intermediate_name: String = ""


func _ready() -> void:
	# Cargar flag DEBUG global del GameConfig.
	DEBUG_ENABLED = GameConfig.DEBUG_ENEMY_AI

	# Aplicar stats desde GameConfig según la clase + rareza del enemy.
	# Source of truth: scripts/systems/game_config.gd ("archivo .env").
	health.max_health = GameConfig.enemy_health_with_rarity(enemy_class, rarity)
	health.current_health = health.max_health
	hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
	speed = GameConfig.enemy_speed_for(enemy_class)
	attack_range = GameConfig.enemy_range_for(enemy_class)
	detect_range = GameConfig.enemy_detect_range_for(enemy_class)
	telegraph_seconds = GameConfig.enemy_telegraph_with_rarity(enemy_class, rarity)

	# Color por clase + tinte de rareza (multiplicativo).
	# Hecho via script porque el override en inherited .tscn no es confiable en Godot 4
	# sin "editable_children". Esta es la fuente de verdad del color.
	var base_color: Color = _color_for_class(enemy_class)
	var tint: Color = GameConfig.rarity_tint_for(rarity)
	sprite.body_color = Color(
		clamp(base_color.r * tint.r, 0.0, 1.0),
		clamp(base_color.g * tint.g, 0.0, 1.0),
		clamp(base_color.b * tint.b, 0.0, 1.0),
		base_color.a
	)
	# Escala del sprite por rareza (R4 = más grande, bossy).
	# Solo escala el visual; hitbox/hurtbox/velocidad se mantienen consistentes.
	sprite.scale = Vector2.ONE * GameConfig.rarity_scale_for(rarity)

	# Armas visibles según clase: Melee=Sword, Tank=Hammer+Shield, Archer=Bow, Mage=Staff.
	var weapons: Array[int] = _weapons_for_class(enemy_class)
	sprite.set_weapons(weapons[0], weapons[1])
	# Boss R4: arma escalada para verse imponente + aura dorada de partículas.
	if rarity == GameConfig.EnemyRarity.R4:
		sprite.weapon_scale = 1.4
		_spawn_boss_aura()
	# R3: aura violeta tenue persistente en IDLE (pilar #2 — el jugador ve que es distinto).
	if rarity == GameConfig.EnemyRarity.R3:
		_spawn_r3_idle_aura()
	# Inicializar skill cooldown para R3 (empieza con un delay inicial antes del primer cast).
	if rarity == GameConfig.EnemyRarity.R3:
		_skill_cooldown = SKILL_COOLDOWN_MIN
	# Inicializar cooldown R2 skill (R2 y R3 lo usan — R3 hereda la skill R2 de su clase).
	if rarity == GameConfig.EnemyRarity.R2 or rarity == GameConfig.EnemyRarity.R3:
		if R2_SKILL_TABLE.has(enemy_class):
			_skill_r2_cooldown = R2_SKILL_TABLE[enemy_class]["cd_min"]

	hurtbox.health_component = health
	hurtbox.team = team
	hitbox.team = team
	# Propagar elemento al hitbox (daño que aplica) y al hurtbox (daño que recibe).
	# GDD §5.3: el mismo elemento del enemy afecta a ambas partes del triángulo.
	hitbox.element = element
	hurtbox.element = element
	hitbox.set_active(false)

	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	# Floater de daño con feedback elemental (was_advantage). GDD §5.3.
	hurtbox.hit_received.connect(_on_hit_received_elemental)
	# Bloqueo por cargas: cuando hurtbox absorbe un golpe vía EnemyBlockHandler,
	# disparamos burst visual + transición inmediata al contraataque (TELEGRAPH).
	hurtbox.hit_blocked.connect(_on_block_absorbed)

	# Resolución del target: primero NodePath explícito, después fallback por grupo.
	if target_path != NodePath():
		_target = get_node_or_null(target_path)
	if _target == null:
		_target = get_tree().get_first_node_in_group("player")
	if _target == null:
		push_warning("Enemy sin target. No Player en grupo 'player' ni en target_path.")


func _color_for_class(c: int) -> Color:
	match c:
		GameConfig.EnemyClass.MELEE: return Color(1.0, 0.40, 0.40, 1.0)    ## rojo
		GameConfig.EnemyClass.TANK: return Color(0.45, 0.35, 0.25, 1.0)    ## marrón
		GameConfig.EnemyClass.ARCHER: return Color(0.25, 0.65, 0.30, 1.0)  ## verde
		GameConfig.EnemyClass.MAGE: return Color(0.70, 0.30, 0.90, 1.0)    ## violeta
	return Color(1.0, 0.40, 0.40, 1.0)


## Crea un GPUParticles2D dorado alrededor del boss (R4). Aura sutil pero notoria.
## Es creado on-demand y agregado como hijo del enemy. Se libera junto al enemy.
func _spawn_boss_aura() -> void:
	var aura: GPUParticles2D = GPUParticles2D.new()
	aura.name = "BossAura"
	aura.position = Vector2(0, -35)  # centro del cuerpo
	aura.amount = 28
	aura.lifetime = 1.4
	aura.preprocess = 0.6
	aura.explosiveness = 0.0
	aura.z_index = -1  # detrás del cuerpo

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 22.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.gravity = Vector3(0, -25, 0)  # flotan hacia arriba lentamente
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	# Color: dorado intenso → desvanece a transparente.
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.35, 0.85))
	grad.set_color(1, Color(1.0, 0.7, 0.2, 0.0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	aura.process_material = mat
	aura.emitting = true
	add_child(aura)


## Devuelve [main_weapon, off_weapon] según la clase del enemy.
## Usa los valores numéricos del enum StickFigure.WeaponType:
##   NONE=0, SWORD=1, BOW=2, STAFF=3, HAMMER=4, SHIELD=5.
func _weapons_for_class(c: int) -> Array[int]:
	match c:
		GameConfig.EnemyClass.MELEE: return [1, 0]        ## sword, nada
		GameConfig.EnemyClass.TANK: return [4, 5]         ## hammer + shield
		GameConfig.EnemyClass.ARCHER: return [2, 0]       ## bow, nada
		GameConfig.EnemyClass.MAGE: return [3, 0]         ## staff, nada
	return [0, 0]


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_apply_gravity(delta)
		move_and_slide()
		return

	if _jump_cooldown_timer > 0.0:
		_jump_cooldown_timer -= delta
	if _intermediate_check_timer > 0.0:
		_intermediate_check_timer -= delta
	# Cooldowns de rareza (R2 block + skill, R3 dodge + skill R3).
	if _block_cooldown > 0.0:
		_block_cooldown -= delta
	if _dodge_cooldown > 0.0:
		_dodge_cooldown -= delta
	if _skill_cooldown > 0.0:
		_skill_cooldown -= delta
	if _skill_r2_cooldown > 0.0:
		_skill_r2_cooldown -= delta
	# Guerrero R3: Sed de Sangre — cooldown y timer del buff activo.
	if enemy_class == GameConfig.EnemyClass.MELEE and rarity == GameConfig.EnemyRarity.R3:
		if _skill_r3_buff_cooldown > 0.0:
			_skill_r3_buff_cooldown -= delta
		if _r3_buff_timer > 0.0:
			_r3_buff_timer -= delta
			if _r3_buff_timer <= 0.0:
				_end_sed_de_sangre()
	# Taunt tank: desactivar al expirar.
	if _taunt_active:
		_taunt_timer -= delta
		_update_taunt_lines()
		if _taunt_timer <= 0.0:
			_end_taunt()

	_apply_gravity(delta)
	if DEBUG_ENABLED and state == State.CHASE:
		_dbg_tick_ceiling()
	_tick_state(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * 2.5 * delta


func _tick_state(delta: float) -> void:
	_state_timer += delta

	match state:
		State.IDLE:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _distance_to_target() < detect_range:
				# Inicializar facing hacia el target al entrar a CHASE.
				# Esto evita que el enemy empiece persiguiendo al lado opuesto del target.
				if _target != null:
					var initial_dx: float = _target.global_position.x - global_position.x
					if abs(initial_dx) > 5.0:
						_apply_facing(int(sign(initial_dx)))
				_change_state(State.CHASE)

		State.CHASE:
			var dist: float = _distance_to_target()
			if dist > detect_range * 1.5:
				_change_state(State.IDLE)
				return

			# Guerrero R3: Sed de Sangre — buff propio. Prioridad máxima (se buffea antes de pelear).
			# Solo activo para Melee R3. No consume SKILL_TELEGRAPH — se reutiliza la misma telegrafía
			# con _r3_buff_casting=true para distinguir que el SKILL_ATTACK activa buff (no proyectil).
			if enemy_class == GameConfig.EnemyClass.MELEE and rarity == GameConfig.EnemyRarity.R3:
				if _skill_r3_buff_cooldown <= 0.0 and _r3_buff_timer <= 0.0 and is_on_floor():
					if dist < detect_range * 0.6:
						_r3_buff_casting = true
						_change_state(State.SKILL_TELEGRAPH)
						return

			# R3 exacto: skill especial R3. R4 excluido (boss-designer lo maneja).
			# dist < detect_range * 0.6 evita telegrafía desde lejos.
			# Si ambos cooldowns R3 y R2 están listos: prioridad R3 (más poderoso).
			# MELEE R3 excluido: tiene Embestida (R2) + Sed de Sangre (R3 propia) = 3 skills.
			# La skill genérica R3 (hitbox ampliada) era redundante con ataque básico.
			if rarity == GameConfig.EnemyRarity.R3 and _skill_cooldown <= 0.0 \
					and enemy_class != GameConfig.EnemyClass.MELEE:
				if dist < detect_range * 0.6 and is_on_floor():
					_change_state(State.SKILL_TELEGRAPH)
					return

			# R2 y R3: skill activo por clase. Cooldown independiente del skill R3.
			# R4 excluido. Tank: puede usarlo desde distancia (taunt es area, no necesita contact).
			if (rarity == GameConfig.EnemyRarity.R2 or rarity == GameConfig.EnemyRarity.R3) \
					and _skill_r2_cooldown <= 0.0 and is_on_floor():
				var r2_range_ok: bool = dist < detect_range * 0.6
				# Tank usa rango más amplio (el taunt es area, no proyectil).
				if enemy_class == GameConfig.EnemyClass.TANK:
					r2_range_ok = dist < detect_range * 0.8
				if r2_range_ok:
					_change_state(State.R2_SKILL_TELEGRAPH)
					return

			# R2/R3: reaccionar al ataque del player — bloqueo o dodge.
			# R4 excluido deliberadamente (bosses tienen comportamiento propio).
			if rarity == GameConfig.EnemyRarity.R2 or rarity == GameConfig.EnemyRarity.R3:
				if _target != null and dist < attack_range * 2.5 and is_on_floor():
					var player_attacking: bool = _target.get("is_attacking") == true
					if player_attacking:
						if rarity == GameConfig.EnemyRarity.R3 and _dodge_cooldown <= 0.0:
							# R3: dodge lateral (prioridad sobre bloqueo).
							if randf() < DODGE_TRIGGER_CHANCE:
								_change_state(State.DODGE)
								return
						if _block_cooldown <= 0.0:
							# R2 y R3: bloqueo instintivo (R3 puede bloquear si no dodgeó).
							if randf() < BLOCK_TRIGGER_CHANCE:
								_change_state(State.BLOCK)
								return

			# Para ranged (archer/mage): atacar a distancia, no requiere altura similar.
			# Para melee/tank: requiere altura similar para no atacar al aire.
			var can_attack_now: bool = dist < attack_range
			if can_attack_now and not _is_ranged():
				can_attack_now = _target_at_similar_height()
			if can_attack_now:
				_change_state(State.TELEGRAPH)
				return

			# Reset del factor de velocidad en aire cuando aterrizamos.
			if is_on_floor():
				_air_speed_factor = 1.0
				# Solo recalcular dirección si estamos en piso. En aire,
				# el facing se mantiene como estaba al despegar (evita oscilación
				# que rompe la trayectoria parabólica del salto).
				_apply_facing(_decide_chase_direction())

			# En aire usa JUMP_HORIZONTAL_SPEED (fijo) — el tank salta tan lejos como melee.
			# En piso usa speed (varía por clase: tank 260, melee 400, etc.).
			var speed_now: float = speed if is_on_floor() else JUMP_HORIZONTAL_SPEED * _air_speed_factor
			velocity.x = current_facing * speed_now
			sprite.set_state(StickFigure.State.JUMP if not is_on_floor() else StickFigure.State.WALK)
			_try_reactive_jump()

		State.TELEGRAPH:
			velocity.x = 0.0
			# Feedback visual del telegraph se dispara en _change_state (start_telegraph).
			# Cancelar TELEGRAPH si el target se aleja mucho durante la espera.
			# Crítico para melee/tank con telegrafía larga: si el player corre,
			# no queremos atacar al aire. Solo aplica a melee (ranged disparan
			# proyectiles que viajan, no necesitan estar cerca al disparar).
			if not _is_ranged() and _distance_to_target() > attack_range * 1.8:
				_change_state(State.CHASE)
				return
			if _state_timer >= telegraph_seconds:
				_change_state(State.ATTACK)

		State.ATTACK:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.ATTACK)
			if _is_ranged():
				# Archer/Mage: dispara UN proyectil al inicio del ATTACK, luego espera RECOVERY.
				if _state_timer >= ATTACK_ACTIVE_START and not _projectile_fired_this_attack:
					_spawn_projectile()
					_projectile_fired_this_attack = true
			else:
				# Melee/Tank: hitbox activo en ventana corta.
				var should_active: bool = _state_timer >= ATTACK_ACTIVE_START and _state_timer <= ATTACK_ACTIVE_END
				if hitbox.monitoring != should_active:
					hitbox.set_active(should_active)
			if _state_timer >= ATTACK_DURATION:
				hitbox.set_active(false)
				_projectile_fired_this_attack = false
				_change_state(State.RECOVERY)

		State.RECOVERY:
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.IDLE)
			if _state_timer >= RECOVERY_SECONDS:
				_change_state(State.IDLE)

		State.BLOCK:
			# R2+: postura defensiva con 1 carga de bloqueo.
			# Si el player golpea: hurtbox absorbe via EnemyBlockHandler → _on_block_absorbed → TELEGRAPH.
			# Si expira el timer sin golpe: salir limpiamente (sin burst, sin contraataque).
			# El cleanup del aura y del shield en hurtbox lo maneja _change_state (prev == BLOCK).
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.BLOCK)
			if _state_timer >= _block_duration_current:
				# El bloqueo expiró sin ser golpeado: desactivar cargas antes de salir.
				_block_handler.deactivate()
				_block_cooldown = BLOCK_COOLDOWN_SECONDS
				_change_state(State.TELEGRAPH)

		State.DODGE:
			# R3: dash lateral. Mueve al enemy hasta _dodge_target_x, luego vuelve a CHASE.
			var dx: float = _dodge_target_x - global_position.x
			if abs(dx) < 8.0 or not is_on_floor():
				# Llegó al destino o cayó en aire — cortar el dash.
				velocity.x = 0.0
				_dodge_cooldown = DODGE_COOLDOWN_SECONDS
				_change_state(State.CHASE)
			else:
				velocity.x = sign(dx) * DODGE_SPEED
				sprite.set_state(StickFigure.State.WALK)

		State.SKILL_TELEGRAPH:
			# R3: telegrafía del skill (1.5s normal, 1.0s para buff Sed de Sangre).
			velocity.x = 0.0
			var tele_thresh: float = R3_BUFF_TELEGRAPH_SECONDS if _r3_buff_casting else SKILL_TELEGRAPH_SECONDS
			if _state_timer >= tele_thresh:
				_change_state(State.SKILL_ATTACK)

		State.SKILL_ATTACK:
			# R3: ejecución del skill. Si _r3_buff_casting → activa Sed de Sangre y vuelve a CHASE.
			velocity.x = 0.0
			sprite.set_state(StickFigure.State.ATTACK)
			if _r3_buff_casting:
				# Buff Sed de Sangre: se activa instantáneamente en el primer frame de SKILL_ATTACK.
				if not _skill_fired_this_cast:
					_activate_sed_de_sangre()
					_skill_fired_this_cast = true
				# Duración corta: el "ataque" del buff es solo visualmente; vuelve a CHASE rápido.
				if _state_timer >= SKILL_ATTACK_DURATION:
					_skill_fired_this_cast = false
					_r3_buff_casting = false
					_skill_r3_buff_cooldown = R3_BUFF_COOLDOWN
					_change_state(State.RECOVERY)
				return
			# Skill normal R3 (proyectil potenciado para ranged, hitbox ampliada para melee).
			if _is_ranged():
				if _state_timer >= ATTACK_ACTIVE_START and not _skill_fired_this_cast:
					_spawn_skill_projectile()
					_skill_fired_this_cast = true
			else:
				# Melee: hitbox activo más tiempo que ataque normal (ventana más peligrosa).
				var should_active: bool = _state_timer >= ATTACK_ACTIVE_START \
					and _state_timer <= ATTACK_ACTIVE_END * 2.0
				if hitbox.monitoring != should_active:
					hitbox.set_active(should_active)
			if _state_timer >= SKILL_ATTACK_DURATION:
				hitbox.set_active(false)
				_skill_fired_this_cast = false
				_skill_cooldown = randf_range(SKILL_COOLDOWN_MIN, SKILL_COOLDOWN_MAX)
				_change_state(State.RECOVERY)

		# ── R2 Skill: telegrafía ──────────────────────────────────────────────
		State.R2_SKILL_TELEGRAPH:
			velocity.x = 0.0
			var r2_data: Dictionary = R2_SKILL_TABLE.get(enemy_class, {})
			var r2_tele: float = r2_data.get("telegraph_sec", 0.6)
			if _state_timer >= r2_tele:
				_change_state(State.R2_SKILL_ATTACK)

		# ── R2 Skill: ejecución ───────────────────────────────────────────────
		State.R2_SKILL_ATTACK:
			_tick_r2_skill_attack()


func _change_state(new_state: State) -> void:
	var prev: State = state
	state = new_state
	_state_timer = 0.0

	# Cleanup de efectos al salir de estados especiales.
	if prev == State.TELEGRAPH or prev == State.SKILL_TELEGRAPH or prev == State.R2_SKILL_TELEGRAPH:
		sprite.end_telegraph()
	# Si salimos de SKILL_TELEGRAPH/SKILL_ATTACK de forma inesperada, limpiar flag del buff.
	if prev == State.SKILL_TELEGRAPH or prev == State.SKILL_ATTACK:
		if _r3_buff_casting and new_state != State.SKILL_ATTACK:
			_r3_buff_casting = false
			# Limpiar VFX de telegrafía del buff si quedó activo.
			var buff_vfx: Node = get_node_or_null("SedDeSangreTelegraphVFX")
			if buff_vfx != null:
				buff_vfx.queue_free()
	if prev == State.BLOCK:
		# Desconectar el handler del hurtbox y apagar el aura.
		# deactivate() ya fue llamado antes de _change_state (timeout) o el bloqueo
		# fue roto por golpe (_on_block_absorbed antes de este cambio de estado).
		hurtbox.shield = null
		sprite.end_block_aura()
	# Cleanup del melee-dash R2 si sale de SKILL_ATTACK por interrupción.
	if prev == State.R2_SKILL_ATTACK:
		hitbox.set_active(false)
		_skill_r2_fired = false
		# Restaurar daño normal si era skill melee (que sube hitbox.damage).
		if enemy_class == GameConfig.EnemyClass.MELEE:
			hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)

	match new_state:
		State.TELEGRAPH:
			# Telegraph normal del ataque base.
			sprite.start_telegraph(telegraph_seconds)

		State.BLOCK:
			# R2: entrar al bloqueo — 1 carga real, aura azul, duración aleatoria.
			# NO usar invulnerable: el golpe ENTRA, EnemyBlockHandler decide si absorber.
			_block_duration_current = randf_range(BLOCK_DURATION_MIN, BLOCK_DURATION_MAX)
			_block_handler.reset_charges(1)
			hurtbox.shield = _block_handler  # duck typing: misma API que ShieldComponent
			sprite.start_block_aura()
			_face_target()

		State.DODGE:
			# R3: calcular destino lateral (opuesto al facing actual para alejarse del player).
			# Si el player está a la derecha, dashea a la izquierda y viceversa.
			var dodge_dir: int = -current_facing
			if _target != null:
				var dx_to_player: float = _target.global_position.x - global_position.x
				dodge_dir = -int(sign(dx_to_player))  # alejarse del player
			_dodge_target_x = global_position.x + dodge_dir * DODGE_DISTANCE
			_apply_facing(-dodge_dir)  # mirar hacia el player mientras escapa

		State.SKILL_TELEGRAPH:
			# R3: telegrafía del skill. Si _r3_buff_casting, es la telegrafía del buff (1.0s).
			# Si no, es la del proyectil potenciado (SKILL_TELEGRAPH_SECONDS=1.5s).
			var tele_dur: float = R3_BUFF_TELEGRAPH_SECONDS if _r3_buff_casting else SKILL_TELEGRAPH_SECONDS
			sprite.start_telegraph(tele_dur)
			_face_target()
			# VFX buff: aura roja pulsante durante la telegrafía del buff.
			if _r3_buff_casting:
				_spawn_sed_de_sangre_telegraph_vfx()

		State.SKILL_ATTACK:
			# R3: daño aumentado para el skill — temporalmente sobreescribimos el hitbox.
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity)) \
				* SKILL_DAMAGE_MULT))

		State.RECOVERY:
			# Restaurar daño normal si salimos de un skill attack R3 o R2 melee.
			if prev == State.SKILL_ATTACK or prev == State.R2_SKILL_ATTACK:
				hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)

		# ── R2 Skill: enter ───────────────────────────────────────────────────
		State.R2_SKILL_TELEGRAPH:
			# Telegrafía visible con duración según la tabla de la clase.
			var r2_data: Dictionary = R2_SKILL_TABLE.get(enemy_class, {})
			var r2_tele: float = r2_data.get("telegraph_sec", 0.6)
			sprite.start_telegraph(r2_tele)
			_face_target()
			# VFX: partícula de "carga" específica por clase.
			_spawn_r2_telegraph_vfx()

		State.R2_SKILL_ATTACK:
			# Preparar la ejecución según la clase.
			_enter_r2_skill_attack()


func _distance_to_target() -> float:
	if _target == null:
		return 99999.0
	return global_position.distance_to(_target.global_position)


func _face_target() -> void:
	if _target == null:
		return
	var dir: float = _target.global_position.x - global_position.x
	if abs(dir) > 5.0:
		current_facing = sign(dir)
		sprite.set_facing(current_facing)
		hitbox.position.x = abs(hitbox.position.x) * current_facing


func _on_damaged(_amount: int) -> void:
	# Si el bloqueo absorbió el golpe, HurtboxComponent emite hit_blocked en vez de
	# hit_received, y health.take_damage no se llama → este callback no dispara.
	# Si el bloqueo está roto o no hay bloqueo activo, el daño llega normalmente.
	sprite.flash_hurt(0.15)
	# El floater ahora se maneja en _on_hit_received_elemental (tiene was_advantage).


## Floater de daño con feedback elemental. Separado de _on_damaged para tener was_advantage.
## was_advantage: 1=ventaja (player tiene ventaja sobre enemy), -1=desventaja, 0=neutral.
func _on_hit_received_elemental(amount: int, _source: HitboxComponent, was_advantage: int) -> void:
	var color: Color
	var font_size: int = 26
	match was_advantage:
		1:
			# El player tiene ventaja — golpe fuerte: dorado brillante, texto grande.
			color = Color(1.0, 0.80, 0.15, 1.0)
			font_size = 32
		-1:
			# El player tiene desventaja — golpe débil: gris azulado, texto chico.
			color = Color(0.55, 0.70, 0.90, 1.0)
			font_size = 20
		_:
			# Neutral: amarillo estándar.
			color = Color(1.0, 0.95, 0.35, 1.0)
	DamageFloater.spawn_with_size(get_tree().current_scene,
		global_position + Vector2(0, -90), amount, color, font_size)


func _on_died() -> void:
	state = State.DEAD
	sprite.set_state(StickFigure.State.DEAD)
	# Cortar telegraph si moría justo cuando cargaba un ataque.
	sprite.end_telegraph()
	# Limpiar efectos de rareza al morir.
	sprite.end_block_aura()
	hurtbox.set_invulnerable(false)
	hitbox.set_active(false)
	# Limpiar taunt si el tank muere con él activo.
	if _taunt_active:
		_end_taunt()
	# Limpiar Sed de Sangre si el guerrero R3 muere con buff activo.
	if _r3_buff_timer > 0.0:
		_end_sed_de_sangre()
	# Si este enemy era soaker de otro tank, limpiar referencia.
	if hurtbox.taunt_soaker != null:
		hurtbox.taunt_soaker = null
	# Apagar aura si era boss R4.
	var aura: GPUParticles2D = get_node_or_null("BossAura") as GPUParticles2D
	if aura != null:
		aura.emitting = false
	# Desactivar TODA colisión: el cadáver no debe bloquear proyectiles ni recibir
	# más hits, y no debe colisionar con el player o plataformas.
	hurtbox.monitorable = false
	hurtbox.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	# Fade-out + queue_free. Tween corto, no bloqueante. StageManager ya recibió
	# el `died` signal antes de esto, así que el conteo avanza igual.
	var tween: Tween = create_tween()
	tween.tween_interval(0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.40)
	tween.tween_callback(queue_free)


func _try_reactive_jump() -> void:
	# Salto si: en piso, fuera de cooldown, effective target arriba y cerca horizontalmente.
	# Usa effective target para multi-hop (salta hacia plataforma intermedia, no target final).
	if _target == null:
		return
	if not is_on_floor():
		return
	if _jump_cooldown_timer > 0.0:
		return
	var effective: Vector2 = _get_effective_target_position()
	var dx: float = abs(effective.x - global_position.x)
	var dy: float = global_position.y - effective.y

	# GAP JUMP CHECK PRIMERO: target a nivel similar + cerca del borde + dx mediano.
	# Threshold de dx más permisivo (hasta 1.5x del regular) porque el salto cubre más
	# distancia cuando es lateral con misma altura inicial.
	if abs(dy) < 50.0 and dx > 100.0 and dx <= JUMP_TRIGGER_MAX_DISTANCE * 1.5:
		var near_edge: int = _get_falloff_direction()
		var target_dir: int = int(sign(effective.x - global_position.x))
		if near_edge != 0 and near_edge == target_dir:
			# CRITICAL: forzar facing hacia el target ANTES de saltar.
			# En aire el enemy mantiene current_facing y se mueve en esa dirección.
			# Si commit_edge dejó facing al lado opuesto, el salto va al vacío.
			_apply_facing(target_dir)
			velocity.y = JUMP_VELOCITY
			velocity.x = 0.0
			_jump_cooldown_timer = JUMP_COOLDOWN
			_air_speed_factor = 1.0
			if DEBUG_ENABLED:
				_dbg("JUMP_GAP", "lateral gap, dx=%.0f dy=%.1f edge_dir=%d" % [dx, dy, near_edge])
			return

	# Regular jump checks.
	if dx > JUMP_TRIGGER_MAX_DISTANCE:
		if DEBUG_ENABLED:
			_dbg("no_jump", "dx=%.1f > %.0f" % [dx, JUMP_TRIGGER_MAX_DISTANCE])
		return
	if dy < JUMP_TRIGGER_HEIGHT_DIFF:
		if DEBUG_ENABLED:
			_dbg("no_jump", "dy=%.1f facing=%d vel=(%.0f,%.0f) onfloor=%s factor=%.1f" \
				% [dy, current_facing, velocity.x, velocity.y, str(is_on_floor()), _air_speed_factor])
		return
	# Salto físicamente imposible: dy mayor que la altura máxima alcanzable del salto.
	# Sin este filtro, el enemy intenta saltos infinitos a plataformas inalcanzables.
	if dy > MAX_JUMP_HEIGHT * 1.05:
		if DEBUG_ENABLED:
			_dbg("no_jump", "dy=%.1f > MAX_JUMP_HEIGHT*1.05 (físicamente imposible)" % dy)
		return
	# Ceiling check: si hay techo encima, normalmente NO saltar.
	# Excepción: si el effective target ES la plataforma encima (alcanzable directo Y
	# dx lateral suficiente para que el salto diagonal aterrize sobre ella sin chocar con bottom).
	if _has_ceiling_above():
		var target_within_jump_reach: bool = effective.y >= global_position.y - MAX_JUMP_HEIGHT \
			and effective.y < global_position.y - JUMP_TRIGGER_HEIGHT_DIFF
		# dx > 50 garantiza salto diagonal (no vertical bajo el centro de la plataforma).
		if not target_within_jump_reach or dx < 50.0:
			if DEBUG_ENABLED:
				_dbg("no_jump", "has_ceiling_above (target_reach=%s dx=%.0f)" % [str(target_within_jump_reach), dx])
			return
	# CRITICAL: forzar facing hacia el effective target ANTES de saltar.
	# En aire el enemy mantiene current_facing. Si _decide_chase_direction o
	# commit_edge dejó facing al lado opuesto del target (caso común cuando
	# escape ceiling apunta a un borde y el salto necesita ir al borde opuesto),
	# el enemy vuela al vacío. Acá lo corregimos justo antes del salto.
	var jump_facing: int = int(sign(effective.x - global_position.x))
	if jump_facing != 0 and jump_facing != current_facing:
		_apply_facing(jump_facing)
	velocity.y = JUMP_VELOCITY
	velocity.x = 0.0                       # salto vertical limpio
	_jump_cooldown_timer = JUMP_COOLDOWN
	# Air speed factor por tipo de salto:
	# - dx ≤ 30: target casi directamente encima → factor 0.0 (salto vertical puro)
	# - dx ≤ 100: salto medio lateral → factor 0.5 (sube vertical antes de avanzar)
	# - dx > 100: salto lateral largo → factor 1.0 (vel.x full para cubrir distancia)
	if dx <= 30.0:
		_air_speed_factor = 0.0
	elif dx <= 100.0:
		_air_speed_factor = 0.5
	else:
		_air_speed_factor = 1.0
	if DEBUG_ENABLED:
		_dbg("JUMP!", "from=(%.0f,%.0f) target=(%.0f,%.0f) dx=%.0f dy=%.0f air_factor=%.1f" \
			% [global_position.x, global_position.y, effective.x, effective.y, dx, dy, _air_speed_factor])


func _has_ceiling_above() -> bool:
	# 3 raycasts verticales: centro + ambos laterales (margen para esquinas).
	# Si cualquiera detecta techo, NO es seguro saltar (chocaría con esquina).
	var space_state := get_world_2d().direct_space_state
	var head_y: float = global_position.y - 55.0
	var offsets: Array[float] = [0.0, -CEILING_CHECK_SIDE_OFFSET, CEILING_CHECK_SIDE_OFFSET]

	for off in offsets:
		var from: Vector2 = Vector2(global_position.x + off, head_y)
		var to: Vector2 = from + Vector2(0, -CEILING_CHECK_DISTANCE)
		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.collision_mask = 0b1  # layer 1 = World
		query.exclude = [self]
		if not space_state.intersect_ray(query).is_empty():
			return true
	return false


func _get_escape_direction_from_ceiling() -> int:
	# Raycasts VERTICALES en posiciones laterales para detectar de qué lado está la plataforma encima.
	# Prioridad nueva: si el target está EN la dirección del techo (la plataforma encima coincide
	# con el destino del enemy), IR hacia él (no escapar). Sino, escape al lado libre.
	var space_state := get_world_2d().direct_space_state
	var head_y: float = global_position.y - 55.0

	var left_query := PhysicsRayQueryParameters2D.create(
		Vector2(global_position.x - 100.0, head_y),
		Vector2(global_position.x - 100.0, head_y - CEILING_CHECK_DISTANCE)
	)
	left_query.collision_mask = 0b1
	left_query.exclude = [self]
	var left_blocked: bool = not space_state.intersect_ray(left_query).is_empty()

	var right_query := PhysicsRayQueryParameters2D.create(
		Vector2(global_position.x + 100.0, head_y),
		Vector2(global_position.x + 100.0, head_y - CEILING_CHECK_DISTANCE)
	)
	right_query.collision_mask = 0b1
	right_query.exclude = [self]
	var right_blocked: bool = not space_state.intersect_ray(right_query).is_empty()

	# Prioridad: si el target está del lado del techo detectado, ir HACIA él.
	if _target != null:
		var effective: Vector2 = _get_effective_target_position()
		var dx_to_eff: float = effective.x - global_position.x
		if abs(dx_to_eff) > 5.0:
			var target_side: int = int(sign(dx_to_eff))
			var target_side_blocked: bool = (left_blocked if target_side == -1 else right_blocked)
			if target_side_blocked:
				# El techo es del lado del target → ese es el destino, ir hacia él.
				return target_side

	# Fallback: lado libre (escape clásico).
	if not left_blocked and right_blocked:
		return -1
	if not right_blocked and left_blocked:
		return 1
	# Ambos iguales: usar posición del target como tiebreaker.
	if _target != null:
		var target_dx: float = _target.global_position.x - global_position.x
		if abs(target_dx) > 5.0:
			return int(sign(target_dx))
	return current_facing


func _get_falloff_direction() -> int:
	# Simétrico de escape: detecta de qué lado hay borde de plataforma sin piso debajo.
	# Devuelve -1 (caer izquierda), 1 (caer derecha), 0 (sin decisión clara).
	var space_state := get_world_2d().direct_space_state
	var feet: Vector2 = global_position + Vector2(0, -2)

	var left_query := PhysicsRayQueryParameters2D.create(
		feet + Vector2(-FALLOFF_CHECK_LATERAL, 0),
		feet + Vector2(-FALLOFF_CHECK_LATERAL, FALLOFF_CHECK_DEPTH)
	)
	left_query.collision_mask = 0b1
	left_query.exclude = [self]
	var left_has_floor: bool = not space_state.intersect_ray(left_query).is_empty()

	var right_query := PhysicsRayQueryParameters2D.create(
		feet + Vector2(FALLOFF_CHECK_LATERAL, 0),
		feet + Vector2(FALLOFF_CHECK_LATERAL, FALLOFF_CHECK_DEPTH)
	)
	right_query.collision_mask = 0b1
	right_query.exclude = [self]
	var right_has_floor: bool = not space_state.intersect_ray(right_query).is_empty()

	if not left_has_floor and right_has_floor:
		return -1
	if not right_has_floor and left_has_floor:
		return 1
	return 0  # ambos con piso (estamos en medio) o ambos sin piso (estamos en el aire)


func _should_commit_to_edge() -> int:
	# Detecta 2 casos donde _get_escape_direction_from_ceiling() falla por oscilación:
	#   A) Multi-hop: enemy debajo de la INTERMEDIA, lógica de escape lo empuja al centro
	#      y no puede saltar diagonal (dx<50 bloquea).
	#   B) Target encima directo: target está parado en la plataforma que hace de ceiling,
	#      dx_to_target chico. Escape oscila entre "ir hacia target" (+1) y "lado libre" (-1).
	# En ambos casos, va al borde correcto. Devuelve -1/1 o 0 (no aplica).
	if _target == null:
		return 0
	if not is_on_floor():
		return 0
	if not _has_ceiling_above():
		return 0
	# Identificar la plataforma encima: multi-hop usa la intermedia cacheada,
	# sino raycast vertical para detectar el ceiling.
	var ceiling_platform: Node2D = null
	if _multi_hop_active and _intermediate_platform != null \
			and is_instance_valid(_intermediate_platform):
		ceiling_platform = _intermediate_platform
	else:
		ceiling_platform = _find_ceiling_platform()
	if ceiling_platform == null:
		return 0
	var inter_pos: Vector2 = ceiling_platform.global_position
	var dy_to_inter: float = global_position.y - inter_pos.y
	if dy_to_inter < JUMP_TRIGGER_HEIGHT_DIFF:
		return 0
	# Solo aplica si el enemy está dentro del shadow de la plataforma encima.
	# Threshold = half_width(100) + CEILING_CHECK_SIDE_OFFSET(100) + margen(30) = 230.
	var dx_to_inter: float = abs(inter_pos.x - global_position.x)
	if dx_to_inter > 230.0:
		return 0
	# Filtro: si el target está abajo del ceiling, no nos importa la plat encima.
	var target_pos: Vector2 = _target.global_position
	if target_pos.y > inter_pos.y + 30.0:
		return 0

	# CASO B (non-multi-hop): target parado en la plat encima.
	# Escape oscila porque "ir hacia target" lo lleva al centro del shadow.
	# Fix: ir al borde de plat que está DEL LADO del target dentro de la plat.
	# Esto fuerza al enemy a cruzar la plat hasta salir por el lado correcto.
	# Si target en el centro exacto, fallback al borde más cercano al enemy.
	var target_at_ceiling_level: bool = abs(target_pos.y - inter_pos.y) < 30.0
	var target_in_plat_range: bool = abs(target_pos.x - inter_pos.x) < 120.0
	if target_at_ceiling_level and target_in_plat_range:
		var target_side_of_plat: float = target_pos.x - inter_pos.x
		if abs(target_side_of_plat) < 5.0:
			# Target en el centro exacto. Borde más cercano AL ENEMY como tiebreaker.
			var dist_to_left: float = abs(global_position.x - (inter_pos.x - 100.0))
			var dist_to_right: float = abs(global_position.x - (inter_pos.x + 100.0))
			return -1 if dist_to_left < dist_to_right else 1
		return int(sign(target_side_of_plat))

	# CASO A (multi-hop original): borde según target REAL (no effective).
	if _multi_hop_active:
		var inter_to_target: float = target_pos.x - inter_pos.x
		if abs(inter_to_target) < 5.0:
			return current_facing
		return int(sign(inter_to_target))

	return 0


func _find_ceiling_platform() -> Node2D:
	# Igual lógica que _has_ceiling_above: 3 raycasts (centro + ±CEILING_CHECK_SIDE_OFFSET).
	# Devuelve el primer StaticBody2D que detecte cualquier raycast. Consistente con
	# _has_ceiling_above para evitar casos donde uno dice "hay ceiling" y el otro null.
	var space_state := get_world_2d().direct_space_state
	var head_y: float = global_position.y - 55.0
	var offsets: Array[float] = [0.0, -CEILING_CHECK_SIDE_OFFSET, CEILING_CHECK_SIDE_OFFSET]
	for off in offsets:
		var from: Vector2 = Vector2(global_position.x + off, head_y)
		var to: Vector2 = from + Vector2(0, -200.0)
		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.collision_mask = 0b1
		query.exclude = [self]
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var collider: Object = result.collider
		if collider is Node2D:
			return collider
	return null


func _decide_chase_direction() -> int:
	# Decisión unificada de movimiento horizontal en CHASE, por prioridad:
	# 0. Commit to edge: debajo de la plataforma intermedia → borde correcto según target real.
	# 1. Target arriba + techo bloqueando → escape al borde exterior.
	# 2. Target abajo + en plataforma → buscar borde para caer; sin borde, histéresis.
	# 3. Persecución normal con tolerancia chica.
	if _target == null:
		return current_facing

	# Prioridad 0: corta la oscilación bajo la plataforma intermedia antes del escape-ceiling.
	var commit: int = _should_commit_to_edge()
	if commit != 0:
		if DEBUG_ENABLED and commit != _dbg_last_facing:
			# _intermediate_platform puede ser null en el caso B (non-multi-hop) — usar fallback.
			var inter_x: float = _intermediate_platform.global_position.x \
				if _intermediate_platform != null and is_instance_valid(_intermediate_platform) \
				else NAN
			var inter_y: float = _intermediate_platform.global_position.y \
				if _intermediate_platform != null and is_instance_valid(_intermediate_platform) \
				else NAN
			_dbg("commit_edge", "dir=%d (inter=(%.0f,%.0f) real_target=(%.0f,%.0f))" \
				% [commit, inter_x, inter_y,
				   _target.global_position.x, _target.global_position.y])
			_dbg_last_facing = commit
		return commit

	var effective: Vector2 = _get_effective_target_position()
	var dx: float = effective.x - global_position.x
	var dy_above: float = global_position.y - effective.y
	var dy_below: float = -dy_above

	# Target arriba + en piso + techo encima → escape al borde lateral.
	# Aplica siempre que hay techo (sea el target intermedio o un obstáculo).
	# El escape vertical lateral con tiebreaker hacia target real lleva al enemy
	# al lado correcto del borde, donde puede saltar diagonal hacia el destino.
	if dy_above >= JUMP_TRIGGER_HEIGHT_DIFF and is_on_floor() and _has_ceiling_above():
		var escape: int = _get_escape_direction_from_ceiling()
		if escape != 0:
			if DEBUG_ENABLED and escape != _dbg_last_facing:
				_dbg("escape", "dir=%d (target effective=(%.0f,%.0f))" % [escape, effective.x, effective.y])
				_dbg_last_facing = escape
			return escape

	# Target abajo + en piso:
	# Orden: fall-off PRIMERO (borde de plataforma actual con raycast corto).
	# Si no detecta borde (estoy en medio), MANTENER current_facing.
	# Solo flippear si target está MUY lejos horizontalmente (>100px), no por estar al filo.
	# Esto fuerza al enemy a comprometerse con una dirección de descenso, sin oscilar.
	if dy_below >= JUMP_TRIGGER_HEIGHT_DIFF and is_on_floor():
		var fall: int = _get_falloff_direction()
		if fall != 0:
			if DEBUG_ENABLED and fall != _dbg_last_facing:
				_dbg("falloff", "dir=%d" % fall)
				_dbg_last_facing = fall
			return fall
		# Sin borde detectado. Flippear SOLO si target muy lejos lateralmente (umbral grande, no al filo).
		if abs(dx) > 100.0:
			return int(sign(dx))
		# Histéresis grande: mantener current_facing hasta llegar al borde.
		return current_facing

	# Persecución horizontal normal
	if abs(dx) > 5.0:
		var chase_dir: int = int(sign(dx))
		if DEBUG_ENABLED and chase_dir != _dbg_last_facing:
			_dbg("chase", "dir=%d effective=(%.0f,%.0f) dx=%.0f dy_above=%.0f" \
				% [chase_dir, effective.x, effective.y, dx, dy_above])
			_dbg_last_facing = chase_dir
		return chase_dir
	return current_facing


func _apply_facing(dir: int) -> void:
	if dir == 0:
		return
	current_facing = dir
	sprite.set_facing(current_facing)
	hitbox.position.x = abs(hitbox.position.x) * current_facing


func _get_effective_target_position() -> Vector2:
	# Devuelve la posición que el enemy debería perseguir AHORA:
	# - Si target está alcanzable de un salto (con margen estricto) → posición del target directa
	# - Si no → posición de la mejor plataforma intermedia (multi-hop)
	# Usa histéresis para no oscilar entre DIRECT e INTERMEDIATE cuando dy_above está al filo.
	if _target == null:
		return global_position
	var target_pos: Vector2 = _target.global_position
	var dy_above: float = global_position.y - target_pos.y

	# Histéresis: cambiar de estado solo al cruzar threshold (dy O dx).
	var dx_to_target: float = abs(target_pos.x - global_position.x)
	if _multi_hop_active:
		# Deactivate solo si AMBOS dy Y dx son chicos.
		if dy_above < MULTI_HOP_DEACTIVATE_DY and dx_to_target < MULTI_HOP_DEACTIVATE_DX:
			_multi_hop_active = false
	else:
		# Activate si dy O dx superan threshold.
		if dy_above > MULTI_HOP_ACTIVATE_DY or dx_to_target > MULTI_HOP_ACTIVATE_DX:
			_multi_hop_active = true

	if not _multi_hop_active:
		if DEBUG_ENABLED and _dbg_last_intermediate_name != "DIRECT":
			_dbg("target", "DIRECT (dy=%.0f, hist deactivate=%.0f)" % [dy_above, MULTI_HOP_DEACTIVATE_DY])
			_dbg_last_intermediate_name = "DIRECT"
		return target_pos

	# Refresh del cache periódicamente para no buscar plataformas cada frame.
	if _intermediate_check_timer <= 0.0:
		_intermediate_platform = _find_intermediate_platform()
		_intermediate_check_timer = INTERMEDIATE_CHECK_INTERVAL
	if _intermediate_platform != null and is_instance_valid(_intermediate_platform):
		var inter_name: String = _intermediate_platform.name
		if DEBUG_ENABLED and _dbg_last_intermediate_name != inter_name:
			_dbg("target", "INTERMEDIATE=%s pos=(%.0f,%.0f) dy_total=%.0f" \
				% [inter_name, _intermediate_platform.global_position.x, _intermediate_platform.global_position.y, dy_above])
			_dbg_last_intermediate_name = inter_name
		return _intermediate_platform.global_position
	if DEBUG_ENABLED and _dbg_last_intermediate_name != "NULL":
		_dbg("target", "NO_INTERMEDIATE_FOUND fallback=player_real (dy_total=%.0f)" % dy_above)
		_dbg_last_intermediate_name = "NULL"
	return target_pos


func _find_intermediate_platform() -> Node2D:
	# Busca la mejor plataforma intermedia (escalón) entre el enemy y el target.
	# Dos pasadas:
	#   1) ESTRICTA: la intermedia DEBE permitir saltar directo al target después.
	#      Usada cuando hay una sola plat entre el enemy y el target.
	#   2) RELAJADA: si la estricta no encontró nada, acepta cualquier plat
	#      alcanzable aunque no llegue al target directo. Permite "gradual climb"
	#      (suelo → plat A → plat B → plat C → target) cuando hay >1 hop.
	if _target == null:
		return null
	var strict: Node2D = _find_intermediate_internal(true)
	if strict != null:
		return strict
	return _find_intermediate_internal(false)


## Implementación de la búsqueda con filtros parametrizables.
## strict_chain=true → exige que la plat conecte directo al target (filtros 3 y 4).
## strict_chain=false → solo exige que la plat sea alcanzable desde el enemy
##                      (modo "gradual climb" — el algoritmo iterará en siguiente frame).
func _find_intermediate_internal(strict_chain: bool) -> Node2D:
	var candidates: Array = get_tree().get_nodes_in_group("platform")
	var best: Node2D = null
	var best_cost: float = INF
	for plat in candidates:
		if not plat is Node2D:
			continue
		var p2d: Node2D = plat
		# Filtro: ignorar plataformas ocultas (defaults que el stage override silenció).
		if not p2d.visible:
			continue
		var plat_dy_above: float = global_position.y - p2d.global_position.y
		# Filtro 1: alcanzable desde donde estoy (ambos modos).
		if plat_dy_above < 40.0 or plat_dy_above > MAX_JUMP_HEIGHT:
			continue
		# Filtro 2: no más alta que el target (ambos modos — sino el enemy se aleja).
		if p2d.global_position.y < _target.global_position.y - 30.0:
			continue
		var jump_to_target: float = p2d.global_position.y - _target.global_position.y
		if strict_chain:
			# Filtro 3: target debe ser alcanzable desde esta plataforma (modo estricto).
			if jump_to_target > MAX_JUMP_HEIGHT * 1.1:
				continue
			# Filtro 4: si target está casi al mismo nivel que la plat, posiblemente
			# está parado sobre ella — descartar SALVO que target esté lateralmente lejos.
			if jump_to_target < 30.0:
				var dx_target: float = abs(_target.global_position.x - global_position.x)
				if dx_target <= JUMP_TRIGGER_MAX_DISTANCE:
					continue
		# Filtro 5: si estoy SOBRE una plataforma elevada (no en suelo), la intermedia
		# debe ser alcanzable de un salto desde donde estoy (no puedo caminar sin caer).
		var on_elevated: bool = global_position.y < -50.0
		if on_elevated:
			var dx_to_plat: float = abs(p2d.global_position.x - global_position.x)
			if dx_to_plat > JUMP_TRIGGER_MAX_DISTANCE:
				continue
		# Costo: dist(enemy → plat) + dist(plat → target).
		# En modo relajado eso prefiere plats más altas (más cerca verticalmente del target).
		var cost: float = global_position.distance_to(p2d.global_position) \
			+ p2d.global_position.distance_to(_target.global_position)
		if cost < best_cost:
			best_cost = cost
			best = p2d
	return best


func _target_at_similar_height() -> bool:
	# Evita atacar al aire cuando target está mucho más arriba/abajo.
	if _target == null:
		return false
	return abs(_target.global_position.y - global_position.y) < 80.0


func _is_ranged() -> bool:
	# Archer y Mage usan proyectiles; Melee y Tank van cuerpo a cuerpo.
	return enemy_class == GameConfig.EnemyClass.ARCHER \
		or enemy_class == GameConfig.EnemyClass.MAGE


func _spawn_projectile() -> void:
	# Instancia el proyectil asignado en @export y lo lanza hacia el target.
	if projectile_scene == null:
		push_warning("Enemy %s sin projectile_scene asignada — sin disparo." % name)
		return
	if _target == null:
		return
	var projectile: Node2D = projectile_scene.instantiate()
	if projectile == null or not projectile is Projectile:
		push_warning("projectile_scene no instancia un Projectile válido.")
		return
	var proj: Projectile = projectile
	# Spawn point: posición del enemy a la altura de la "mano" (~Y -30 relativo).
	proj.global_position = global_position + Vector2(0, -30)
	# Apuntar al CENTRO del cuerpo del target (offset Y=-30 sobre origin).
	# El origin del CharacterBody2D está a los pies; el body shape va de Y=-60 a Y=0,
	# así que el centro está en Y=-30 relativo.
	var aim_point: Vector2 = _target.global_position + Vector2(0, -30)
	var direction: Vector2 = (aim_point - proj.global_position).normalized()
	# Elemento del enemy propagado al proyectil para el modifier elemental. GDD §5.3.
	proj.launch(direction, hitbox.damage, team, element)

	# ── Mage R1+: Orbe Flamígero — AoE radial post-impacto ──────────────────
	# Regla R1→R2→R3: la mejora del ataque básico se hereda a rarezas superiores.
	# Solo aplica al ATAQUE BÁSICO. La skill R2 (fireball grande) va por path
	# separado `_spawn_r2_mage_fireball` — ahí NO se aplica (ya es ×1.5/×1.8 overkill).
	# R4 excluido (boss tiene script propio).
	if enemy_class == GameConfig.EnemyClass.MAGE and rarity != GameConfig.EnemyRarity.R4:
		proj.enable_aoe_on_impact(35.0, 0.6, 0.4)

	# ── Archer R1+: Flecha Perforante — atraviesa hasta 3 enemies ───────────
	# Regla R1→R2→R3: idem. La ráfaga R2 va por path separado y NO perfora
	# (3 flechas × 3 pierce = 9 hits — demasiado).
	if enemy_class == GameConfig.EnemyClass.ARCHER and rarity != GameConfig.EnemyRarity.R4:
		proj.pierce_enemies = true
		proj.pierce_count = 3

	# Agregar al árbol raíz del world para que sobreviva al move del enemy.
	get_tree().current_scene.add_child(proj)


## Aura violeta tenue persistente para R3 en IDLE.
## Señal visual al jugador: este enemy es diferente — fuerza esquivas activas.
## Usa GPUParticles2D con poca cantidad para performance mobile.
func _spawn_r3_idle_aura() -> void:
	var aura: GPUParticles2D = GPUParticles2D.new()
	aura.name = "R3Aura"
	aura.position = Vector2(0, -35)
	aura.amount = 14
	aura.lifetime = 1.8
	aura.preprocess = 0.8
	aura.explosiveness = 0.0
	aura.z_index = -1

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 18.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 40.0
	mat.gravity = Vector3(0, -15, 0)
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 18.0
	mat.scale_min = 0.3
	mat.scale_max = 0.7
	# Violeta suave → transparente.
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.75, 0.45, 1.0, 0.55))
	grad.set_color(1, Color(0.55, 0.25, 0.85, 0.0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	aura.process_material = mat
	aura.emitting = true
	add_child(aura)


## Proyectil potenciado del skill especial R3.
## Para no crear nueva escena, reutilizamos projectile_scene si existe,
## o disparamos el hitbox potenciado si es melee (ya manejado en SKILL_ATTACK state).
## Esta función solo es relevante para clases ranged (Archer/Mage).
func _spawn_skill_projectile() -> void:
	if projectile_scene == null:
		push_warning("Enemy R3 sin projectile_scene — skill no puede disparar proyectil.")
		return
	if _target == null:
		return
	var projectile: Node2D = projectile_scene.instantiate()
	if projectile == null or not projectile is Projectile:
		push_warning("projectile_scene no instancia un Projectile válido (skill R3).")
		return
	var proj: Projectile = projectile
	proj.global_position = global_position + Vector2(0, -30)
	var aim_point: Vector2 = _target.global_position + Vector2(0, -30)
	var direction: Vector2 = (aim_point - proj.global_position).normalized()
	# Daño ya fue seteado en SKILL_ATTACK enter via hitbox.damage — usar ese valor.
	# Elemento del enemy propagado al proyectil. GDD §5.3.
	proj.launch(direction, hitbox.damage, team, element)
	get_tree().current_scene.add_child(proj)


## Callback: hurtbox absorbió un golpe vía EnemyBlockHandler (hit_blocked signal).
## Pilar #2: el jugador VE que el bloqueo se rompió (burst), y el enemy contraataca
## de inmediato (TELEGRAPH) → "romper guardia tiene consecuencias, pero es posible".
func _on_block_absorbed(_amount: int, _source: HitboxComponent) -> void:
	# Solo reaccionar si realmente estamos en BLOCK.
	# hit_blocked puede dispararse tarde si el frame del golpe y el exit del state se solapan.
	if state != State.BLOCK:
		return
	# Burst visual: shards azules desde el escudo (mismo efecto que el player).
	sprite.play_block_burst()
	# El aura ya se apaga en _change_state (prev == BLOCK).
	# Contraataque inmediato: telegrafía normal como señal de punish.
	_block_cooldown = BLOCK_COOLDOWN_SECONDS
	_change_state(State.TELEGRAPH)


# ══════════════════════════════════════════════════════════════════════════════
# ─── R2 Skill: métodos de implementación ─────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

## VFX de telegrafía R2. Partícula de "carga" visual diferente por clase.
## Dura mientras el enemy está en R2_SKILL_TELEGRAPH (se limpia con queue_free
## del nodo padre al cambiar de estado, o al destruir el enemy).
func _spawn_r2_telegraph_vfx() -> void:
	# Limpiar VFX anterior si existe (previene doble-spawn si algo fuerza re-enter).
	var old: Node = get_node_or_null("R2TelegraphVFX")
	if old != null:
		old.queue_free()

	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "R2TelegraphVFX"
	particles.amount = 6   # mobile: máximo 6 partículas simultáneas
	particles.lifetime = 0.5
	particles.preprocess = 0.0
	particles.explosiveness = 0.3
	particles.z_index = 1  # delante del cuerpo para que sea legible

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 12.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.scale_min = 0.5
	mat.scale_max = 1.2

	# Color por clase: archer=amarillo dorado, melee=rojo-naranja, mage=azul eléctrico, tank=naranja.
	var grad: Gradient = Gradient.new()
	match enemy_class:
		GameConfig.EnemyClass.ARCHER:
			particles.position = Vector2(0, -55)  # sobre el arco
			mat.emission_sphere_radius = 10.0
			grad.set_color(0, Color(1.0, 0.9, 0.2, 1.0))
			grad.set_color(1, Color(1.0, 0.7, 0.0, 0.0))
		GameConfig.EnemyClass.MELEE:
			particles.position = Vector2(current_facing * 20.0, -30)  # lado de la espada
			grad.set_color(0, Color(1.0, 0.35, 0.1, 1.0))
			grad.set_color(1, Color(0.9, 0.1, 0.0, 0.0))
		GameConfig.EnemyClass.MAGE:
			particles.position = Vector2(0, -50)  # punta del staff
			mat.emission_sphere_radius = 16.0
			particles.amount = 6
			grad.set_color(0, Color(0.3, 0.6, 1.0, 1.0))
			grad.set_color(1, Color(0.1, 0.3, 1.0, 0.0))
		GameConfig.EnemyClass.TANK:
			particles.position = Vector2(0, -40)  # cuerpo del tank
			mat.emission_sphere_radius = 20.0
			grad.set_color(0, Color(1.0, 0.55, 0.0, 0.9))
			grad.set_color(1, Color(1.0, 0.3, 0.0, 0.0))

	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	particles.process_material = mat
	particles.emitting = true
	add_child(particles)


## Enter del estado R2_SKILL_ATTACK. Prepara la ejecución por clase.
func _enter_r2_skill_attack() -> void:
	_skill_r2_fired = false
	_face_target()
	# Limpiar VFX de telegrafía al ejecutar.
	var vfx: Node = get_node_or_null("R2TelegraphVFX")
	if vfx != null:
		vfx.queue_free()

	match enemy_class:
		GameConfig.EnemyClass.MELEE:
			# ── R2 Skill MELEE: Embestida-dash ────────────────────────────────
			# Calcula destino: 120px hacia el player.
			var dash_dir: int = current_facing
			_r2_melee_dash_target_x = global_position.x + dash_dir * R2_MELEE_DASH_DISTANCE
			# Daño con multiplicador (reutiliza SKILL_DAMAGE_MULT).
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity)) \
				* SKILL_DAMAGE_MULT))
			hitbox.set_active(true)  # hitbox activo todo el dash

		GameConfig.EnemyClass.ARCHER:
			# ── R2 Skill ARCHER: carga en enter, disparo en _tick ─────────────
			# Daño normal (3 flechas = 3× daño), se disparan en _tick.
			pass

		GameConfig.EnemyClass.MAGE:
			# ── R2 Skill MAGE: fireball grande ────────────────────────────────
			# Daño amplificado: SKILL_DAMAGE_MULT.
			hitbox.damage = int(round(float(GameConfig.enemy_damage_with_rarity(enemy_class, rarity)) \
				* SKILL_DAMAGE_MULT))

		GameConfig.EnemyClass.TANK:
			# ── R2 Skill TANK: Taunt + aura ───────────────────────────────────
			_start_taunt()


## Tick del estado R2_SKILL_ATTACK. Comportamiento por clase.
func _tick_r2_skill_attack() -> void:
	var r2_data: Dictionary = R2_SKILL_TABLE.get(enemy_class, {})
	var r2_duration: float = r2_data.get("attack_duration", 0.3)
	sprite.set_state(StickFigure.State.ATTACK)

	match enemy_class:
		# ── R2 Skill MELEE: Embestida-dash ────────────────────────────────────
		GameConfig.EnemyClass.MELEE:
			var dx: float = _r2_melee_dash_target_x - global_position.x
			if abs(dx) < 6.0 or not is_on_floor():
				# Llegó o cayó — cortar el dash y aplicar knockback si alcanzó al player.
				velocity.x = 0.0
				hitbox.set_active(false)
				if not _skill_r2_fired:
					# Knockback al player si está cerca.
					_apply_r2_melee_knockback()
					_skill_r2_fired = true
				_finish_r2_skill()
			else:
				velocity.x = sign(dx) * R2_MELEE_DASH_SPEED
			return  # el melee dash controla su propio timer por posición

		# ── R2 Skill ARCHER: ráfaga 3 flechas spread ──────────────────────────
		GameConfig.EnemyClass.ARCHER:
			velocity.x = 0.0
			if _state_timer >= ATTACK_ACTIVE_START and not _skill_r2_fired:
				_spawn_r2_archer_burst()
				_skill_r2_fired = true

		# ── R2 Skill MAGE: fireball grande ────────────────────────────────────
		GameConfig.EnemyClass.MAGE:
			velocity.x = 0.0
			if _state_timer >= ATTACK_ACTIVE_START and not _skill_r2_fired:
				_spawn_r2_mage_fireball()
				_skill_r2_fired = true

		# ── R2 Skill TANK: el taunt se gestiona via timer en _physics_process ─
		GameConfig.EnemyClass.TANK:
			velocity.x = 0.0
			if _state_timer >= r2_duration and not _skill_r2_fired:
				_skill_r2_fired = true  # el taunt YA fue activado en enter

	# Salir del estado por timer (excepto melee que sale por posición).
	if enemy_class != GameConfig.EnemyClass.MELEE and _state_timer >= r2_duration:
		_finish_r2_skill()


## Termina el ciclo R2 skill: resetea cooldown y vuelve a RECOVERY.
func _finish_r2_skill() -> void:
	hitbox.set_active(false)
	_skill_r2_fired = false
	var r2_data: Dictionary = R2_SKILL_TABLE.get(enemy_class, {})
	_skill_r2_cooldown = randf_range(r2_data.get("cd_min", 7.0), r2_data.get("cd_max", 9.0))
	# Restaurar daño normal si clase melee o mage lo modificó.
	if enemy_class == GameConfig.EnemyClass.MELEE or enemy_class == GameConfig.EnemyClass.MAGE:
		hitbox.damage = GameConfig.enemy_damage_with_rarity(enemy_class, rarity)
	_change_state(State.RECOVERY)


## ── R2 Skill ARCHER: 3 flechas en spread vertical ±15° ──────────────────────
func _spawn_r2_archer_burst() -> void:
	if projectile_scene == null or _target == null:
		return
	var aim_point: Vector2 = _target.global_position + Vector2(0, -30)
	var base_dir: Vector2 = (aim_point - (global_position + Vector2(0, -30))).normalized()
	# 3 flechas: central + ±15° spread vertical.
	var angles_deg: Array[float] = [0.0, -15.0, 15.0]
	for angle_deg in angles_deg:
		var proj_node: Node2D = projectile_scene.instantiate()
		if not proj_node is Projectile:
			proj_node.queue_free()
			continue
		var proj: Projectile = proj_node
		proj.global_position = global_position + Vector2(0, -30)
		# Rotar la dirección base en el eje vertical (spread vertical = cambio en Y, no rotación 2D).
		# Para spread vertical: desplazar la Y del target según el ángulo.
		var spread_dir: Vector2 = base_dir.rotated(deg_to_rad(angle_deg))
		proj.launch(spread_dir, hitbox.damage, team, element)
		get_tree().current_scene.add_child(proj)


## ── R2 Skill MAGE: fireball grande (hitbox ×1.8, daño ×SKILL_DAMAGE_MULT) ───
func _spawn_r2_mage_fireball() -> void:
	if projectile_scene == null or _target == null:
		return
	var proj_node: Node2D = projectile_scene.instantiate()
	if not proj_node is Projectile:
		proj_node.queue_free()
		return
	var proj: Projectile = proj_node
	proj.global_position = global_position + Vector2(0, -30)
	var aim_point: Vector2 = _target.global_position + Vector2(0, -30)
	var direction: Vector2 = (aim_point - proj.global_position).normalized()
	# Escalar visual y hitbox del fireball: tamaño ×1.8.
	proj.scale = Vector2(1.8, 1.8)
	# Daño ya fue aumentado en enter (SKILL_DAMAGE_MULT).
	proj.launch(direction, hitbox.damage, team, element)
	get_tree().current_scene.add_child(proj)


## ── R2 Skill MELEE: knockback al player si quedó dentro de rango tras el dash ─
func _apply_r2_melee_knockback() -> void:
	if _target == null:
		return
	var dist: float = global_position.distance_to(_target.global_position)
	# Solo aplicar si el player está cerca (el dash lo alcanzó).
	if dist > attack_range * 1.5:
		return
	# Empujar al player en la dirección opuesta al facing del enemy.
	var knockback_dir: float = float(current_facing)
	if _target.has_method("apply_external_velocity"):
		_target.apply_external_velocity(Vector2(knockback_dir * R2_MELEE_KNOCKBACK * 12.0, -80.0))
	# VFX slash trail: Line2D rápida que se desvanece.
	_spawn_melee_slash_trail()


## Slash trail visual del dash melee R2. Line2D que se desvanece con tween.
func _spawn_melee_slash_trail() -> void:
	var line: Line2D = Line2D.new()
	line.width = 4.0
	line.default_color = Color(1.0, 0.8, 0.4, 0.9)
	# Trazar el rastro desde la posición inicial del dash hasta la actual.
	var start: Vector2 = Vector2(-current_facing * R2_MELEE_DASH_DISTANCE, -30)
	var end: Vector2 = Vector2(0, -30)
	line.add_point(start)
	line.add_point(end)
	line.z_index = 2
	add_child(line)
	# Fade-out en 0.3s y luego limpiar.
	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)


## ── R2 Skill TANK: Taunt ─────────────────────────────────────────────────────

## Inicia el taunt: activa aura naranja, detecta aliados cercanos y los registra.
func _start_taunt() -> void:
	if _taunt_active:
		return
	_taunt_active = true
	_taunt_timer = R2_TANK_TAUNT_DURATION
	_taunt_soakers = []

	# Detectar enemies aliados (mismo team) dentro del radio R2_TANK_TAUNT_RADIUS.
	# El tank actúa de "soaker": recibe R2_TANK_TAUNT_REDIRECT del daño de sus aliados.
	var all_enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e in all_enemies:
		if e == self:
			continue
		if not e is Node2D:
			continue
		var e_node: Node2D = e as Node2D
		if global_position.distance_to(e_node.global_position) <= R2_TANK_TAUNT_RADIUS:
			# Registrar al tank como soaker en el hurtbox del aliado.
			var ally_hurtbox: HurtboxComponent = e_node.get_node_or_null("Hurtbox") as HurtboxComponent
			if ally_hurtbox != null:
				ally_hurtbox.taunt_soaker = self
				_taunt_soakers.append(e_node)

	# VFX: aura naranja sobre el tank.
	_spawn_taunt_aura()
	# Líneas conectando a aliados protegidos.
	_create_taunt_lines()
	# Marker pulsante "PROVOCADO" arriba de la cabeza del tank.
	_spawn_taunt_marker()
	# Flash rojo de pantalla — el player no puede ignorarlo.
	_spawn_taunt_screen_flash()
	# TAUNT MMO real: arrastrar al player hacia el tank. Override de input.
	# Decisión Leo: feel "roto" pero necesario para que el taunt cumpla su rol.
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("set_taunt_source"):
		player_node.set_taunt_source(self)


## Desactiva el taunt: limpia soakers, aura y líneas.
func _end_taunt() -> void:
	_taunt_active = false
	_taunt_timer = 0.0

	# Quitar referencia del soaker en todos los aliados.
	for e in _taunt_soakers:
		if is_instance_valid(e):
			var ally_hurtbox: HurtboxComponent = e.get_node_or_null("Hurtbox") as HurtboxComponent
			if ally_hurtbox != null:
				ally_hurtbox.taunt_soaker = null
	_taunt_soakers.clear()

	# Limpiar aura.
	var aura: Node = get_node_or_null("TauntAura")
	if aura != null:
		aura.queue_free()

	# Limpiar marker pulsante "PROVOCADO".
	var marker: Node = get_node_or_null("TauntMarker")
	if marker != null:
		marker.queue_free()

	# Liberar al player del taunt (vuelve a controlar movimiento + facing normal).
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("set_taunt_source"):
		player_node.set_taunt_source(null)

	# Restaurar tinte normal del sprite (revertir el modulate naranja del taunt).
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Limpiar líneas.
	for line in _taunt_lines:
		if is_instance_valid(line):
			line.queue_free()
	_taunt_lines.clear()


## Spawna aura naranja sobre el tank durante el taunt.
## Buff visual 26/05: amount 6→18, sphere_radius 25→38, lifetime 1.0→1.5, scale_max 1.0→1.5.
## Pluss tinta naranja sobre el sprite del tank durante el taunt (modulate cambia
## en _physics_process via _update_taunt_visual_pulse).
func _spawn_taunt_aura() -> void:
	var old: Node = get_node_or_null("TauntAura")
	if old != null:
		old.queue_free()

	var aura: GPUParticles2D = GPUParticles2D.new()
	aura.name = "TauntAura"
	aura.position = Vector2(0, -40)
	aura.amount = 18
	aura.lifetime = 1.5
	aura.preprocess = 0.3
	aura.explosiveness = 0.0
	aura.z_index = 2

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 38.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.gravity = Vector3(0, -20, 0)
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 45.0
	mat.scale_min = 0.5
	mat.scale_max = 1.5

	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.6, 0.05, 1.0))
	grad.set_color(1, Color(1.0, 0.25, 0.0, 0.0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	aura.process_material = mat
	aura.emitting = true
	add_child(aura)

	# Tinte naranja sobre el sprite del tank — refuerza visibilidad.
	if sprite != null:
		sprite.modulate = Color(1.3, 0.85, 0.7, 1.0)


## Marker pulsante "PROVOCADO" sobre la cabeza del tank. Visible para que el player
## NO pueda ignorar que hay un tank activo en taunt.
func _spawn_taunt_marker() -> void:
	var old: Node = get_node_or_null("TauntMarker")
	if old != null:
		old.queue_free()

	# Contenedor Node2D para poder tweenar scale sin afectar al tank.
	var marker: Node2D = Node2D.new()
	marker.name = "TauntMarker"
	marker.position = Vector2(0, -110)  # arriba de la cabeza del tank
	marker.z_index = 5

	# Glow rojo translúcido (círculo grande detrás del ícono).
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(1.0, 0.15, 0.1, 0.55)
	glow.size = Vector2(36, 36)
	glow.position = Vector2(-18, -18)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(glow)

	# Ícono "!" — Label grande rojo brillante con outline blanco.
	var icon: Label = Label.new()
	icon.text = "!"
	icon.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
	icon.add_theme_color_override("font_outline_color", Color(0.9, 0.05, 0.05, 1.0))
	icon.add_theme_constant_override("outline_size", 6)
	icon.add_theme_font_size_override("font_size", 36)
	icon.size = Vector2(24, 36)
	icon.position = Vector2(-12, -22)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(icon)

	add_child(marker)

	# Tween de pulse continuo durante la duración del taunt.
	# scale 1.0 → 1.35 → 1.0, ciclo ~0.5s.
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(marker, "scale", Vector2(1.35, 1.35), 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(marker, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Flash rojo de pantalla — overlay corto al iniciar el taunt. Imposible de ignorar.
## Self-contained: crea CanvasLayer + ColorRect + Tween auto-destructivo.
func _spawn_taunt_screen_flash() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "TauntScreenFlash"
	canvas.layer = 50  # encima del HUD pero compatible
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(1.0, 0.1, 0.1, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	scene_root.add_child(canvas)

	# Fade in rápido a alpha 0.35 → fade out a 0.0 → auto-free.
	var tween: Tween = create_tween()
	tween.tween_property(rect, "color", Color(1.0, 0.1, 0.1, 0.35), 0.06)
	tween.tween_property(rect, "color", Color(1.0, 0.1, 0.1, 0.0), 0.20)
	tween.tween_callback(func() -> void:
		if is_instance_valid(canvas):
			canvas.queue_free()
	)


## Crea Line2D por aliado protegido. Muestra visualmente qué enemies están bajo taunt.
func _create_taunt_lines() -> void:
	for line in _taunt_lines:
		if is_instance_valid(line):
			line.queue_free()
	_taunt_lines.clear()

	for e in _taunt_soakers:
		if not is_instance_valid(e):
			continue
		var line: Line2D = Line2D.new()
		line.width = 4.0
		line.default_color = Color(1.0, 0.55, 0.0, 0.9)
		line.add_point(Vector2.ZERO)  # posición del tank (relativa)
		line.add_point(Vector2.ZERO)  # posición del aliado (se actualiza en _update_taunt_lines)
		line.z_index = 0
		get_tree().current_scene.add_child(line)
		_taunt_lines.append(line)


## Actualiza posiciones globales de las líneas del taunt (llamada en _physics_process).
func _update_taunt_lines() -> void:
	for i in range(min(_taunt_lines.size(), _taunt_soakers.size())):
		var line: Line2D = _taunt_lines[i]
		var ally: Node2D = _taunt_soakers[i]
		if not is_instance_valid(line) or not is_instance_valid(ally):
			continue
		# Line2D en la escena raíz: puntos en coordenadas globales.
		line.set_point_position(0, global_position + Vector2(0, -40))
		line.set_point_position(1, ally.global_position + Vector2(0, -30))


# ─── Fin R2 Skills ────────────────────────────────────────────────────────────

# ══════════════════════════════════════════════════════════════════════════════
# ─── R3 Guerrero: Sed de Sangre ───────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

## VFX de telegrafía: aura roja pulsante + partículas mientras el guerrero "carga" el buff.
func _spawn_sed_de_sangre_telegraph_vfx() -> void:
	var old: Node = get_node_or_null("SedDeSangreTelegraphVFX")
	if old != null:
		old.queue_free()

	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "SedDeSangreTelegraphVFX"
	particles.amount = 6
	particles.lifetime = 0.4
	particles.preprocess = 0.0
	particles.explosiveness = 0.4
	particles.z_index = 2
	particles.position = Vector2(0, -40)

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 20.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 80.0
	mat.gravity = Vector3(0, -30, 0)
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 60.0
	mat.scale_min = 0.5
	mat.scale_max = 1.3

	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.95, 0.1, 0.1, 1.0))   # rojo intenso
	grad.set_color(1, Color(1.0, 0.4, 0.0, 0.0))     # fade a naranja transparente
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	particles.process_material = mat
	particles.emitting = true
	add_child(particles)


## Activa el buff: +20% speed y +20% atk speed (recovery más corto).
## Aplica tinte rojizo al sprite para feedback visual durante los 5s.
func _activate_sed_de_sangre() -> void:
	_r3_buff_timer = R3_BUFF_DURATION
	# Multiplicar speed.
	speed *= R3_BUFF_SPEED_MULT
	# Tinte rojizo sobre el sprite del enemy.
	sprite.modulate = Color(1.5, 0.75, 0.75, 1.0)
	# Aura roja persistente durante el buff.
	_spawn_sed_de_sangre_buff_aura()
	# Limpiar VFX de telegrafía (ya cumplió su función).
	var tele_vfx: Node = get_node_or_null("SedDeSangreTelegraphVFX")
	if tele_vfx != null:
		tele_vfx.queue_free()


## Desactiva el buff al expirar: revierte speed y tinte.
func _end_sed_de_sangre() -> void:
	# Revertir speed (dividir por el multiplicador para volver al valor original).
	speed /= R3_BUFF_SPEED_MULT
	# Restaurar tinte al color de rareza original.
	sprite.modulate = Color.WHITE
	# Apagar aura del buff.
	var aura: Node = get_node_or_null("SedDeSangreBuffAura")
	if aura != null:
		aura.queue_free()


## Aura roja persistente mientras el buff está activo.
func _spawn_sed_de_sangre_buff_aura() -> void:
	var old: Node = get_node_or_null("SedDeSangreBuffAura")
	if old != null:
		old.queue_free()

	var aura: GPUParticles2D = GPUParticles2D.new()
	aura.name = "SedDeSangreBuffAura"
	aura.position = Vector2(0, -35)
	aura.amount = 6
	aura.lifetime = 0.8
	aura.preprocess = 0.2
	aura.explosiveness = 0.0
	aura.z_index = 1

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 16.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.gravity = Vector3(0, -20, 0)
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 28.0
	mat.scale_min = 0.3
	mat.scale_max = 0.8

	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.15, 0.15, 0.8))
	grad.set_color(1, Color(0.9, 0.1, 0.0, 0.0))
	var grad_tex: GradientTexture1D = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	aura.process_material = mat
	aura.emitting = true
	add_child(aura)

# ─── Fin R3 Guerrero: Sed de Sangre ──────────────────────────────────────────

func _dbg(tag: String, msg: String) -> void:
	# Helper de print con tag consistente. Solo se llama desde DEBUG_ENABLED branches.
	print("[ENEMY @%.0f,%.0f] %s: %s" % [global_position.x, global_position.y, tag, msg])


func _dbg_tick_ceiling() -> void:
	# Llamar desde _physics_process si quieres ver cuando cambia has_ceiling_above.
	# (No conectado por default. Conectar en _physics_process si hace falta más telemetría.)
	if not DEBUG_ENABLED:
		return
	var c: bool = _has_ceiling_above()
	if c != _dbg_last_ceiling:
		_dbg("ceiling", "%s -> %s" % [str(_dbg_last_ceiling), str(c)])
		_dbg_last_ceiling = c
