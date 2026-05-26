extends Area2D
class_name HitboxComponent

## Area2D que aplica daño al entrar a un HurtboxComponent.
## Activable/desactivable. Sistema de teams previene friendly fire.

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
