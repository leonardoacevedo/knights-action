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


func _execute_buff_damage(data: PlayerSkillData) -> void:
	if _player == null or _player.get("status_effects") == null:
		return
	var mag: float = float(data.params.get("magnitude", 0.30))
	var dur: float = float(data.params.get("duration", 5.0))
	_player.status_effects.apply(_status_berserker, _player, mag, dur)


func _execute_aoe_damage(data: PlayerSkillData) -> void:
	var radius: float = float(data.params.get("radius", 100.0))
	var damage: int = int(data.params.get("damage", 25))
	_apply_aoe(radius, damage, null, 0.0, 0.0)


func _execute_aoe_burn(data: PlayerSkillData) -> void:
	var radius: float = float(data.params.get("radius", 100.0))
	var damage: int = int(data.params.get("damage", 15))
	var burn_dur: float = float(data.params.get("burn_duration", 3.0))
	var burn_tick: float = float(data.params.get("burn_damage", 3.0))
	# BURN data lo cargamos del catálogo común del player.
	var burn_data: StatusEffectData = _get_burn_data()
	_apply_aoe(radius, damage, burn_data, burn_tick, burn_dur)


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


func _execute_invis(data: PlayerSkillData) -> void:
	# Reutiliza el status &"post_dash_invis" del player — mismas mecánicas.
	if _player == null or _player.get("status_effects") == null:
		return
	var dur: float = float(data.params.get("duration", 2.0))
	# Carga el .tres directo para que stack_mode/policy queden idénticos a Sombra del Valle.
	var invis: StatusEffectData = load("res://resources/status_effects/post_dash_invis.tres")
	if invis != null:
		_player.status_effects.apply(invis, _player, NAN, dur)


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
