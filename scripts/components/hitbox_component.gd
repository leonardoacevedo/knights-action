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

func _ready() -> void:
	# Layer 4 = Hitbox. Mask 5 = detecta Hurtbox.
	collision_layer = 0b1000     # bit 4
	collision_mask = 0b10000     # bit 5
	monitoring = true
	monitorable = false           # otros hitbox no nos detectan
	set_active(active_on_start)
	area_entered.connect(_on_area_entered)


func set_active(value: bool) -> void:
	# Toggle por monitoring evita procesar colisiones cuando no corresponde.
	monitoring = value
	# Disable shapes también, defensa en profundidad.
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
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
