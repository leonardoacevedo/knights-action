extends Resource
class_name PlayerSkillData

## Skill activa del jugador. Resource serializable — se asigna a un slot del
## PlayerSkillSystem y se ejecuta gastando Furia. GDD §4.3.
##
## Sistema base — primera implementación 27/05. Cubre:
##  - Lógica completa (cost Furia, CD, signals, execute por effect_type).
##  - 3 skills iniciales en `resources/player_skills/*.tres` (Embestida, Curación, Bola Fuego).
##  - UI / input binding / unlock-tree de skills → pendiente sesión separada (ver §5 doc).
##
## Pool propuesto en `.claude/docs/habilidades_generales.md` §5.

enum EffectType {
	HEAL,              ## Recupera N% de HP del player. params: { heal_pct: float }
	BUFF_DAMAGE,       ## +X% daño físico durante Y segundos. Aplica StatusEffect &"berserker".
	                   ## params: { magnitude: float, duration: float }
	AOE_DAMAGE,        ## Daño radial alrededor del player. Reutiliza Physics2D query.
	                   ## params: { radius: float, damage: int }
	AOE_BURN,          ## AoE + aplica BURN a enemies en radio. params: { radius, dmg, burn_dur, burn_per_tick }
	DASH_FORWARD,      ## Dash extendido + damage. params: { distance: float, damage_mult: float }
	SPAWN_PROJECTILE,  ## Spawnea fireball/arrow hacia el facing. params: { scene_path: String, dmg_mult: float }
	GAIN_SHIELD,       ## +N cargas temporales al ShieldComponent. params: { charges: int, duration: float }
	INVIS,             ## Status &"player_invis" — el próximo golpe garantiza ventaja elemental.
	                   ## params: { duration: float, dmg_mult: float }
	APPLY_SLOW_AOE,    ## AoE de slow a enemies en radio. params: { radius, slow_mult, slow_duration }
}

## ID único — convención snake_case StringName. Usado por SaveSystem y UI.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

## Costo de Furia. 0 = gratis (debería ser raro — GDD §4.3 marca todas las skills con costo).
@export var cost_furia: int = 30

## Cooldown en segundos tras ejecución exitosa.
@export var cooldown: float = 5.0

@export var effect_type: EffectType = EffectType.AOE_DAMAGE

## Params del efecto. Schema en el enum EffectType de arriba. Acceso seguro con
## `params.get("key", default)`.
@export var params: Dictionary = {}

## Visual / UI.
@export var icon: Texture2D
@export var color: Color = Color(1, 0.8, 0.3, 1)
