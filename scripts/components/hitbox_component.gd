extends Area2D
class_name HitboxComponent

## Area2D que aplica daño al entrar a un HurtboxComponent.
## Activable/desactivable. Sistema de teams previene friendly fire.

## Synergy elemento → status. Cada golpe de elemento no-NEUTRO tiene chance
## (`ELEMENT_STATUS_CHANCE`) de aplicar el efecto correspondiente. Diseño 27/05:
##  - Eje natural (control + daño elemental puro):
##    FUEGO → Quemadura DOT · AGUA → Congelación slow 30% · TIERRA → Fractura +20% next hit ·
##    VIENTO → Desequilibrio (interrupt + CD penalty).
##  - Eje cósmico (alteración de stats + supervivencia + maldiciones):
##    LUZ → Bendición (vampire heal al atacante, no aplica status al defender) ·
##    SOMBRA → Miasma (DOT bypass armor + halve furia gain del defender).
const STATUS_BURN: StatusEffectData = preload("res://resources/status_effects/burn.tres")
const STATUS_FREEZE: StatusEffectData = preload("res://resources/status_effects/freeze.tres")
const STATUS_FRACTURA: StatusEffectData = preload("res://resources/status_effects/vulnerable.tres")
const STATUS_DESEQUILIBRIO: StatusEffectData = preload("res://resources/status_effects/desequilibrio.tres")
const STATUS_BENDICION: StatusEffectData = preload("res://resources/status_effects/bendicion.tres")
const STATUS_MIASMA: StatusEffectData = preload("res://resources/status_effects/poison.tres")
## Base 30% chance — modificada por SetBonus 3pc del player atacante via `_get_element_status_chance`.
const ELEMENT_STATUS_CHANCE_BASE: float = 0.30
## % HP máximo curado al atacante por golpe LUZ (vampire heal). Base, ajustado por LUZ 3pc set.
const BENDICION_HEAL_PCT_BASE: float = 0.05

signal hit_landed(target_hurtbox: HurtboxComponent)

@export var damage: int = 5
## Team del owner. 1=player, 2=enemy. Solo daña a Hurtbox de team distinto.
@export var team: int = 0
## Si true, hitbox arranca activo. Default false (combate usa toggle).
@export var active_on_start: bool = false

## Multiplicador runtime aplicado al damage final. Lo setea el entity (player desde Momentum).
## Default 1.0 = sin cambio.
var damage_multiplier: float = 1.0

## Multiplicador de set bonus. Lo setea PlayerStatsComponent en recalculate().
## FUEGO 2pc = 1.10. Default 1.0.
var damage_set_bonus_multiplier: float = 1.0

## Elemento del atacante. Player.gd lo setea desde el arma equipada antes de atacar.
## Enemy.gd lo setea en _ready desde su propio campo element.
## Usar valores de ItemData.Element: NEUTRO=0, FUEGO=1, AGUA=2, TIERRA=3.
var element: int = 0  # ItemData.Element.NEUTRO

## Bonus adicional al multiplicador de ventaja elemental.
## Skill "Ventaja Aguzada" agrega +0.15 → ventaja pasa de 1.5 a 1.65.
## Seteado por PlayerStatsComponent.recalculate() vía ELEMENTAL_ADV_MULT.
var elemental_adv_skill_bonus: float = 0.0

## Si true, el próximo hit fuerza ventaja elemental (ignora triángulo, usa ×1.5 + bonus).
## Seteado por player.gd cuando Sombra del Valle activa el buff post-dash.
## Se consume en el primer hit que conecta (flag se limpia en _on_area_entered).
var force_elem_advantage: bool = false

## Si true, el hit ignora ShieldComponent.try_absorb del defensor (pool §4 Arma Imbuida).
## HurtboxComponent.receive_hit chequea source.ignore_shield antes de llamar shield.try_absorb.
## Setear desde el enemy.gd al activar el buff Arma Imbuida + restaurar al expirar.
var ignore_shield: bool = false

## Defaults de hitbox por visual_type cuando ItemData no override-a.
## Format: { visual_type: {reach, width, arc_deg, damage_zone} }.
## visual_type 2 (Bow) y 3 (Staff) excluidos: son ranged, no usan hitbox melee.
const WEAPON_HITBOX_DEFAULTS: Dictionary = {
	0: {"reach": 24.0, "width": 14.0, "arc_deg": 100.0, "damage_zone": 1.0},  # NONE (puños)
	1: {"reach": 40.0, "width": 12.0, "arc_deg": 130.0, "damage_zone": 1.0},  # SWORD (reach 50→40 honesto vs hoja visible — tunable in-editor)
	4: {"reach": 36.0, "width": 26.0, "arc_deg": 110.0, "damage_zone": 0.35}, # HAMMER (solo cabeza)
}

## ConvexPolygonShape2D usado para forma de swing. Lazy-inicializado.
var _swing_shape: ConvexPolygonShape2D = null
var _swing_collision: CollisionShape2D = null
var _swing_reach: float = 0.0
var _swing_width: float = 0.0
var _swing_arc_rad: float = 0.0
var _swing_damage_zone: float = 1.0


func _ready() -> void:
	# Layer 4 = Hitbox. Mask 5 = detecta Hurtbox.
	collision_layer = 0b1000     # bit 4
	collision_mask = 0b10000     # bit 5
	monitoring = true
	monitorable = false           # otros hitbox no nos detectan
	set_active(active_on_start)
	area_entered.connect(_on_area_entered)


## Configura el hitbox para usar shape de swing (polígono que rota con el arc).
## Llamar al iniciar attack. Devuelve true si visual_type soporta melee, false si ranged.
## Si reach/width/arc/damage_zone vienen en 0 desde ItemData, usa defaults del visual_type.
## `scale_mult` multiplica reach + width (no arc ni damage_zone). Coincide con sprite.scale
## * weapon_scale para que el hitbox crezca igual que el render. Default 1.0 = sin cambio.
func setup_weapon_swing(visual_type: int, reach: float, width: float,
		arc_deg: float, damage_zone: float, scale_mult: float = 1.0) -> bool:
	if not WEAPON_HITBOX_DEFAULTS.has(visual_type):
		return false  # Bow/Staff/Shield → ranged o no-arma
	var d: Dictionary = WEAPON_HITBOX_DEFAULTS[visual_type]
	var base_reach: float = reach if reach > 0.0 else float(d["reach"])
	var base_width: float = width if width > 0.0 else float(d["width"])
	_swing_reach = base_reach * scale_mult
	_swing_width = base_width * scale_mult
	var arc: float = arc_deg if arc_deg > 0.0 else float(d["arc_deg"])
	_swing_arc_rad = deg_to_rad(arc)
	_swing_damage_zone = damage_zone if damage_zone > 0.0 else float(d["damage_zone"])
	# Inicializar (lazy) el ConvexPolygonShape2D + CollisionShape2D dedicado.
	if _swing_collision == null:
		_swing_collision = CollisionShape2D.new()
		_swing_collision.name = "SwingShape"
		_swing_shape = ConvexPolygonShape2D.new()
		_swing_collision.shape = _swing_shape
		add_child(_swing_collision)
	# Ocultar el shape rectangular original (HitboxShape) mientras swing está activo.
	_set_legacy_shape_enabled(false)
	_swing_collision.disabled = not monitoring
	# Estado inicial: progress=0 → polígono al inicio del arco.
	update_swing_arc(0.0, 1)
	return true


## Actualizar forma del swing en función del progreso (0..1) y facing (1 o -1).
## Llamar cada frame durante la ventana ATTACK_ACTIVE.
func update_swing_arc(progress: float, facing: int) -> void:
	if _swing_shape == null or _swing_reach <= 0.0:
		return
	# Ángulo: -arc/2 al inicio, +arc/2 al final. Movimiento descendente del filo.
	var angle: float = lerp(-_swing_arc_rad * 0.5, _swing_arc_rad * 0.5, clamp(progress, 0.0, 1.0))
	# Construir polígono en frame "facing=+1" (extiende +X), luego espejar X por facing.
	var start_x: float = _swing_reach * (1.0 - _swing_damage_zone)
	var end_x: float = _swing_reach
	var half_w: float = _swing_width * 0.5
	var taper: float = 0.7  # punta levemente más fina que la base
	var local_pts: PackedVector2Array = PackedVector2Array([
		Vector2(start_x, -half_w),
		Vector2(end_x, -half_w * taper),
		Vector2(end_x, half_w * taper),
		Vector2(start_x, half_w),
	])
	# Rotar por angle (en frame facing=+1) y luego espejar X si facing=-1.
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var rotated: PackedVector2Array = PackedVector2Array()
	rotated.resize(local_pts.size())
	for i in range(local_pts.size()):
		var p: Vector2 = local_pts[i]
		var rx: float = p.x * cos_a - p.y * sin_a
		var ry: float = p.x * sin_a + p.y * cos_a
		rotated[i] = Vector2(rx * float(facing), ry)
	_swing_shape.points = rotated


## Vuelve al hitbox rectangular original (escenas con CollisionShape2D fijo).
## Llamar al terminar attack (finalize) o si la entity no usa swing.
func clear_swing_shape() -> void:
	if _swing_collision != null:
		_swing_collision.disabled = true
	_set_legacy_shape_enabled(true)
	_swing_reach = 0.0


func _set_legacy_shape_enabled(enabled: bool) -> void:
	for child in get_children():
		if child == _swing_collision:
			continue
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", not enabled)


func set_active(value: bool) -> void:
	# Toggle por monitoring evita procesar colisiones cuando no corresponde.
	monitoring = value
	# Disable shapes también, defensa en profundidad.
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			# Si el swing está activo, deshabilitar el legacy shape independiente del toggle.
			if _swing_reach > 0.0 and child != _swing_collision:
				child.set_deferred("disabled", true)
				continue
			child.set_deferred("disabled", not value)


func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox: HurtboxComponent = area
	if hurtbox.team == team:
		return  # mismo team, no daño
	# Cálculo elemental: modifier según triángulo GDD §5.3.
	# force_elem_advantage (Sombra del Valle): bypassar triángulo, usar ventaja directa.
	var elem_mult: float
	var was_advantage: int = 0
	if force_elem_advantage:
		force_elem_advantage = false  # consumir flag — solo un hit garantizado
		elem_mult = GameConfig.ELEMENT_ADVANTAGE_MULT + elemental_adv_skill_bonus
		was_advantage = 1
	else:
		elem_mult = GameConfig.element_modifier(element, hurtbox.element)
		# Ventaja Aguzada: si hay ventaja natural, añadir bonus de skill.
		if elem_mult > 1.0:
			elem_mult += elemental_adv_skill_bonus
			was_advantage = 1
		elif elem_mult < 1.0:
			was_advantage = -1
	var final_damage: int = int(round(float(damage) * damage_multiplier * damage_set_bonus_multiplier * elem_mult))
	hurtbox.receive_hit(final_damage, self, was_advantage)
	hit_landed.emit(hurtbox)
	_try_apply_element_status(hurtbox)


## Aplica status según elemento del atacante. Chance ajustada por SetBonus 3pc del player.
## Eje natural: FUEGO/AGUA/TIERRA/VIENTO → apply status al defender.
## Eje cósmico: LUZ → vampire heal source · SOMBRA → Miasma DOT al defender.
func _try_apply_element_status(hurtbox: HurtboxComponent) -> void:
	if element == 0:  # NEUTRO
		return
	if randf() > _get_element_status_chance(element):
		return
	# LUZ (eje cósmico): no aplica status al defender — cura al atacante.
	if element == 5:
		_apply_bendicion_heal_to_source()
		return
	var defender: Node = hurtbox.get_parent()
	if defender == null:
		return
	var se: StatusEffectComponent = defender.get_node_or_null("StatusEffects") as StatusEffectComponent
	if se == null:
		return
	var data: StatusEffectData = null
	var duration_override: float = NAN
	match element:
		1: data = STATUS_BURN          # FUEGO — Quemadura DOT 3s
		2: data = STATUS_FREEZE        # AGUA — Congelación slow 30%/2s
		3: data = STATUS_FRACTURA      # TIERRA — Fractura próximo hit +20%, single-use
		4: data = STATUS_DESEQUILIBRIO # VIENTO — Desequilibrio interrupt + CD penalty
		6:
			data = STATUS_MIASMA        # SOMBRA — Miasma DOT bypass armor + -50% Furia
			# SOMBRA 2pc: multiplicador de duración del Miasma aplicado.
			var dur_mult: float = _get_miasma_duration_mult()
			if dur_mult != 1.0:
				duration_override = data.duration * dur_mult
	if data != null:
		se.apply(data, self, NAN, duration_override)


## LUZ vampire heal: cura % HP máx al atacante. Mult ajustado por LUZ 3pc set bonus.
func _apply_bendicion_heal_to_source() -> void:
	var source_entity: Node = get_parent()
	if source_entity == null:
		return
	var hp: HealthComponent = source_entity.get_node_or_null("HealthComponent") as HealthComponent
	if hp == null or not hp.is_alive():
		return
	var heal_amt: int = int(round(float(hp.max_health) * _get_bendicion_heal_pct()))
	if heal_amt > 0:
		hp.heal(heal_amt)


# ─── SetBonus query helpers ──────────────────────────────────────────────────

## Chance de aplicar status on-hit. Solo player (team=1) lee SetBonusSystem.
## VIENTO 3pc bump chance Desequilibrio. SOMBRA 3pc bump chance Miasma.
func _get_element_status_chance(elem: int) -> float:
	var base: float = ELEMENT_STATUS_CHANCE_BASE
	if team != 1:
		return base
	var sbs: Node = get_node_or_null("/root/SetBonusSystem")
	if sbs == null:
		return base
	var data: SetBonusData = sbs.get_active_bonus_data() if sbs.has_method("get_active_bonus_data") else null
	if data == null:
		return base
	if elem == 4 and sbs.is_active(4, 3):
		return base * data.viento_desequilibrio_chance_mult_3pc
	if elem == 6 and sbs.is_active(6, 3):
		return base * data.sombra_miasma_chance_mult_3pc
	return base


## % HP curado por vampire heal LUZ. LUZ 3pc multiplica.
func _get_bendicion_heal_pct() -> float:
	var base: float = BENDICION_HEAL_PCT_BASE
	if team != 1:
		return base
	var sbs: Node = get_node_or_null("/root/SetBonusSystem")
	if sbs == null:
		return base
	var data: SetBonusData = sbs.get_active_bonus_data() if sbs.has_method("get_active_bonus_data") else null
	if data == null:
		return base
	if sbs.is_active(5, 3):
		return base * data.luz_bendicion_heal_mult_3pc
	return base


## SOMBRA 2pc: multiplicador de duración del Miasma aplicado. Default 1.0.
func _get_miasma_duration_mult() -> float:
	if team != 1:
		return 1.0
	var sbs: Node = get_node_or_null("/root/SetBonusSystem")
	if sbs == null:
		return 1.0
	var data: SetBonusData = sbs.get_active_bonus_data() if sbs.has_method("get_active_bonus_data") else null
	if data == null:
		return 1.0
	if sbs.is_active(6, 2):
		return data.sombra_miasma_duration_mult_2pc
	return 1.0
