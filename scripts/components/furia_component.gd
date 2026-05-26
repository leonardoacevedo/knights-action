extends Node
class_name FuriaComponent

## Furia: recurso para skills. GDD §4.3.
## No regenera pasivamente. Solo sube por golpes (+10/hit).
## Decay: tras 5s sin atacar, pierde 5 Furia/s. Refuerza agresividad.

signal furia_changed(current: int, maximum: int)
signal furia_full
signal furia_empty

@export var max_furia: int = 100
@export var gain_per_hit: int = 10
@export var decay_per_second: float = 5.0
@export var decay_starts_after_seconds: float = 5.0

var current_furia: float = 0.0   # float para decay suave
var _seconds_since_last_attack: float = 0.0

## Regeneración pasiva por segundo. Seteado por PlayerStatsComponent — suma
## de set bonus AGUA 2pc + skill FURIA_REGEN_FLAT (ej. mago_resonancia_arcana).
## 0.0 = sin regen pasiva (estado default GDD §4.3: Furia no regenera pasivamente).
var _passive_regen_per_sec: float = 0.0

## Furia máxima base del @export + bonus de nivel + bonus de skill FURIA_MAX.
## Seteado por PlayerStatsComponent.recalculate(). Sobrescribe max_furia en runtime.
var _skill_max_furia: int = -1  # -1 = no seteado, usar @export max_furia

## Multiplicador sobre gain_per_hit. 1.0 = sin cambio. Seteado por
## PlayerStatsComponent vía FURIA_GAIN_PCT (ej. mago_flujo_constante).
var _gain_multiplier: float = 1.0


## API para PlayerStatsComponent: regen pasiva (set bonus AGUA 2pc + skills).
func set_passive_regen(regen_per_sec: float) -> void:
	_passive_regen_per_sec = regen_per_sec


## Retorna la regen pasiva activa. Usado por PlayerStatsComponent para sumar set + skill.
func get_passive_regen() -> float:
	return _passive_regen_per_sec


## API para PlayerStatsComponent: Furia máxima efectiva (nivel + skills).
func set_max_furia_override(new_max: int) -> void:
	_skill_max_furia = new_max
	# Clampear Furia actual si cayó por encima del nuevo máximo (caso borde respec).
	if current_furia > float(get_max()) :
		current_furia = float(get_max())
		furia_changed.emit(int(current_furia), get_max())


## Retorna el máximo efectivo (override de skill si está seteado, sino @export).
func get_max() -> int:
	return _skill_max_furia if _skill_max_furia >= 0 else max_furia


## API para PlayerStatsComponent: multiplicador de ganancia por golpe (FURIA_GAIN_PCT).
func set_gain_multiplier(mult: float) -> void:
	_gain_multiplier = mult


func _process(delta: float) -> void:
	_seconds_since_last_attack += delta
	if _seconds_since_last_attack >= decay_starts_after_seconds:
		_apply_decay(delta)
	# Regen pasiva AGUA 2pc — independiente del decay (se aplica siempre que esté activo).
	if _passive_regen_per_sec > 0.0:
		_apply_passive_regen(delta)


func add_on_hit(multiplier: float = 1.0) -> void:
	# Llamar desde HitboxComponent.hit_landed (entity orquesta).
	# multiplier: escala la ganancia. Player lo usa para aplicar Momentum.furia_multiplier().
	_seconds_since_last_attack = 0.0
	var old: int = int(current_furia)
	var gain: float = float(gain_per_hit) * multiplier * _gain_multiplier
	current_furia = min(float(get_max()), current_furia + gain)
	if int(current_furia) != old:
		furia_changed.emit(int(current_furia), get_max())
	if int(current_furia) >= get_max():
		furia_full.emit()


func try_spend(amount: int) -> bool:
	if int(current_furia) < amount:
		return false
	current_furia -= float(amount)
	furia_changed.emit(int(current_furia), get_max())
	if int(current_furia) <= 0:
		furia_empty.emit()
	return true


func get_current() -> int:
	return int(current_furia)


func get_percent() -> float:
	if get_max() <= 0:
		return 0.0
	return current_furia / float(get_max())


func _apply_decay(delta: float) -> void:
	if current_furia <= 0.0:
		return
	var old: int = int(current_furia)
	current_furia = max(0.0, current_furia - decay_per_second * delta)
	if int(current_furia) != old:
		furia_changed.emit(int(current_furia), get_max())
	if current_furia <= 0.0:
		furia_empty.emit()


## Regen pasiva del set bonus AGUA 2pc. No resetea el timer de decay.
func _apply_passive_regen(delta: float) -> void:
	if current_furia >= float(get_max()):
		return
	var old: int = int(current_furia)
	current_furia = min(float(get_max()), current_furia + _passive_regen_per_sec * delta)
	if int(current_furia) != old:
		furia_changed.emit(int(current_furia), get_max())
	if int(current_furia) >= get_max():
		furia_full.emit()
