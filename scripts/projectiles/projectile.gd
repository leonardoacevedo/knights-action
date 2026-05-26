extends Area2D
class_name Projectile

## Proyectil lanzado por Archer/Mage o el player (con arco/vara).
## Movimiento lineal en dirección fija. Lifetime para auto-cleanup.
## Choca con HurtboxComponent de team distinto y aplica daño.

## Emitido al conectar contra un HurtboxComponent enemigo (después de aplicar daño).
## El shooter (player con arco/vara) lo escucha para ganar Furia / Momentum.
signal hit_landed(target_hurtbox: HurtboxComponent)

@export var speed: float = 600.0
@export var lifetime: float = 2.0

# Seteados por launch() al instanciar.
var damage: int = 10
var team: int = 0
## Elemento del atacante (del shooter). Propagado al receive_hit para el modifier elemental.
## Usar valores de ItemData.Element: NEUTRO=0, FUEGO=1, AGUA=2, TIERRA=3.
var element: int = 0  # ItemData.Element.NEUTRO

var _direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0


func _ready() -> void:
	# Mismas layers que Hitbox: nosotros somos un "hitbox volador".
	collision_layer = 0b1000     # bit 4 (Hitbox)
	collision_mask = 0b10000     # bit 5 (detecta Hurtbox)
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


## Inicializa el proyectil con dirección, daño, team y elemento del shooter.
## Llamar inmediatamente después de instanciarlo, antes de add_child.
func launch(direction: Vector2, damage_amount: int, team_id: int, attacker_element: int = 0) -> void:
	if direction.length_squared() == 0.0:
		_direction = Vector2.RIGHT
	else:
		_direction = direction.normalized()
	damage = damage_amount
	team = team_id
	element = attacker_element
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox: HurtboxComponent = area
	if hurtbox.team == team:
		return  # mismo team, no daño
	# Cálculo elemental: modifier según triángulo GDD §5.3.
	var elem_mult: float = GameConfig.element_modifier(element, hurtbox.element)
	var final_damage: int = int(round(float(damage) * elem_mult))
	var was_advantage: int = 0
	if elem_mult > 1.0:
		was_advantage = 1
	elif elem_mult < 1.0:
		was_advantage = -1
	hurtbox.receive_hit(final_damage, null, was_advantage)
	hit_landed.emit(hurtbox)
	queue_free()
