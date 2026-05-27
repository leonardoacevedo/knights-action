extends Resource
class_name StatusEffectData

## Datos de un status effect aplicable a cualquier entity con StatusEffectComponent.
## Resource serializable — se asigna al spawn de skill / proyectil / hitbox.
##
## Catálogo canon en `resources/status_effects/*.tres`. Crear nuevo:
##   1. Sumar entry en `.claude/docs/habilidades_generales.md` §3.
##   2. Crear .tres con id único (StringName, snake_case).
##   3. Wire en owner (Player/Enemy) si necesita side effect propio.
##
## El componente solo trackea lifecycle. La aplicación del efecto (mover slow al
## velocity, drenar HP en BURN, bloquear inputs en STUN) vive en el owner que
## consume signals `effect_applied / effect_expired / effect_ticked` o consulta
## `has(id) / get_magnitude(id)`.

enum StackMode {
	REFRESH,      ## reaplicar resetea duration al máximo (default — buffs/debuffs)
	EXTEND,       ## reaplicar suma duration (espíritu marcial style)
	INDEPENDENT,  ## cada apply crea instancia separada (DOT stackeable)
	IGNORE,       ## si ya está activo, ignorar el nuevo apply
}

enum MagnitudePolicy {
	KEEP_MAX,     ## conserva la magnitud mayor (buffs apilados — default)
	KEEP_MIN,     ## conserva la menor (slows: 0.3 más restrictivo que 0.5)
	KEEP_LATEST,  ## siempre sobrescribe con el nuevo
	SUM,          ## suma magnitudes (DOT stack)
}

## ID único del efecto. Usado para `has(id)`, `get_magnitude(id)`, `remove(id)`.
## Convención snake_case StringName. Ej: &"slow", &"burn", &"espiritu_marcial".
@export var id: StringName = &""

## Duración total en segundos. Si 0 o negativa, el apply se ignora.
@export var duration: float = 1.0

## Magnitud genérica. Interpretación depende del efecto:
##  - slow: multiplicador final sobre SPEED (0.5 = 50%).
##  - burn / dot: daño por tick.
##  - damage_buff: bonus % (0.20 = +20%).
##  - stun: ignorado (basta `has(id)`).
@export var magnitude: float = 0.0

## Intervalo de tick para DOTs. 0 = sin tick (efecto pasivo durante toda la duración).
@export var tick_interval: float = 0.0

@export var stack_mode: StackMode = StackMode.REFRESH
@export var magnitude_policy: MagnitudePolicy = MagnitudePolicy.KEEP_MAX

## Visual / icono opcionales — para HUD del jugador (chips de buffs activos).
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var icon: Texture2D
