extends Area2D
class_name HurtboxComponent

## Area2D que recibe daño de Hitboxes enemigos.
## Requiere HealthComponent en el mismo entity (configurar via @export o setter).

## was_advantage: 1=ventaja elemental, -1=desventaja, 0=neutral. Usado para feedback UI.
signal hit_received(amount: int, source: HitboxComponent, was_advantage: int)
## Emitido cuando el golpe fue absorbido por un ShieldComponent activo con cargas.
## El daño NO se aplicó al HealthComponent. El owner (player) reacciona con
## efectos visuales y congelar Momentum.
signal hit_blocked(amount: int, source: HitboxComponent)

## Team del owner. 1=player, 2=enemy.
@export var team: int = 0
## Referencia al HealthComponent del entity. Asignar en Inspector o setear via código.
@export var health_component: HealthComponent
## Opcional: si está seteado y tiene método try_absorb() -> bool, el golpe se absorbe.
## El player pasa un ShieldComponent; los enemies pasan un EnemyBlockHandler.
## Tipo Node (duck typing) para soportar ambas implementaciones sin herencia.
@export var shield: Node

## Si true, ignora hits (útil durante i-frames de dash).
var invulnerable: bool = false

## Reducción flat de daño por defensa de equipamiento.
## Seteado por PlayerStatsComponent. Daño mínimo garantizado: 1.
var flat_defense: int = 0

## Chance de esquivar daño físico [0.0–1.0]. Seteado por PlayerStatsComponent
## vía skill EVADE_PCT. Solo aplica a hits físicos — el elemental entra igual.
## GDD §6 / skill agil_esquiva_instintiva: +8% chance de esquiva física.
var evade_chance: float = 0.0

## Referencia al árbol de escena para spawnear el floater "MISS!".
## Seteado por player.gd en _ready (igual que el floater de daño).
var scene_root: Node = null

## Elemento de este entity (defensor). Usado por HitboxComponent para calcular
## el modifier elemental antes de llamar receive_hit.
## Usar valores de ItemData.Element: NEUTRO=0, FUEGO=1, AGUA=2, TIERRA=3.
@export_enum("Neutro:0", "Fuego:1", "Agua:2", "Tierra:3") var element: int = 0

func _ready() -> void:
	# Layer 5 = Hurtbox. Mask 4 = detecta Hitbox.
	collision_layer = 0b10000    # bit 5
	collision_mask = 0b1000      # bit 4
	monitoring = false           # nosotros no buscamos, ellos nos encuentran
	monitorable = true


## source puede ser null cuando el daño viene de un Projectile (no Hitbox).
## was_advantage: 1=ventaja elemental, -1=desventaja, 0=neutral. Propagado tal cual a hit_received.
func receive_hit(amount: int, source: HitboxComponent = null, was_advantage: int = 0) -> void:
	if invulnerable:
		return
	if health_component == null:
		push_warning("HurtboxComponent sin health_component asignado: %s" % get_path())
		return
	# Bloqueo: si el shield absorbe, NO descontamos HP y avisamos al owner.
	if shield != null and shield.try_absorb():
		hit_blocked.emit(amount, source)
		return
	# Esquiva física (skill Esquiva Instintiva). Solo aplica al daño base —
	# si fue ventaja elemental (was_advantage != 0), el elemental entra igual.
	# Pilar #1: la build de esquiva evita físico; lo elemental sigue siendo amenaza.
	if evade_chance > 0.0 and was_advantage == 0 and randf() < evade_chance:
		if scene_root != null:
			DamageFloater.spawn_text(scene_root, health_component.get_parent().global_position \
				+ Vector2(0, -70), "MISS!", Color(0.7, 1.0, 0.7, 1.0))
		return  # daño esquivado — no se aplica
	# Defensa flat reduce daño. Mínimo garantizado: 1. Fórmula: formulas.md §Equipamiento.
	var mitigated: int = max(1, amount - flat_defense)
	health_component.take_damage(mitigated)
	hit_received.emit(mitigated, source, was_advantage)


func set_invulnerable(value: bool) -> void:
	invulnerable = value
