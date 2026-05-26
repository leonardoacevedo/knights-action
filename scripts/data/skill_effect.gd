extends Resource
class_name SkillEffect

## Efecto de un nodo del árbol de habilidades. GDD §6.
##
## Cada efecto modifica un stat específico del player, de forma flat o porcentual.
## PlayerProgression.get_skill_bonus_flat/pct() suma todos los efectos activos
## y los pasa a PlayerStatsComponent.recalculate() para aplicar la fórmula §6.4.
##
## Crear: sub_resource inline en un SkillNode.tres o separado.
## NUNCA hardcodear valores de efectos en código — todo va en .tres.

enum Stat {
	HEALTH_MAX,           # +HP máximo flat
	DAMAGE_FLAT,          # +daño físico flat
	DAMAGE_PCT,           # +daño físico %
	DEFENSE_FLAT,         # +defensa flat
	DEFENSE_PCT,          # +defensa %
	FURIA_MAX,            # +Furia máxima flat
	FURIA_GAIN_PCT,       # +Furia ganada por golpe %
	FURIA_REGEN_FLAT,     # +Furia regenerada por segundo (en stages no boss)
	DASH_COOLDOWN_PCT,    # -cooldown dash (negativo = más rápido)
	MOVE_SPEED_PCT,       # +velocidad de movimiento %
	ELEMENTAL_DAMAGE_PCT, # +daño elemental %
	IFRAMES_PCT,          # +duración i-frames %
	BLOCK_CHARGES,        # +cargas de escudo al equipado (flat)
	# Stats adicionales — algunos cableados, algunos placeholder para features futuras.
	CRIT_PCT,             # TODO: sistema de crit (Fase 4+). Nodo desbloqueado, efecto ignorado.
	ELEMENTAL_ADV_MULT,   # Bonus sobre multiplicador de ventaja elemental (×1.5 base → puede ser mayor).
	EVADE_PCT,            # Chance de esquivar daño físico. RNG en HurtboxComponent.receive_hit.
}

enum Mode {
	FLAT,  # amount es número directo (ej. +10 HP)
	PCT,   # amount es fracción (0.10 = +10%)
}

@export var stat: Stat = Stat.HEALTH_MAX
@export var mode: Mode = Mode.FLAT
@export var amount: float = 0.0
