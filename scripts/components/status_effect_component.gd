extends Node
class_name StatusEffectComponent

## Componente genérico de status effects. Hijo de cualquier entity (Player/Enemy/Boss).
##
## El componente solo trackea lifecycle (duración + tick). La aplicación de efectos
## concretos (velocity slow, drain HP en BURN, lock input en STUN, dmg buff) vive en
## el owner del componente — el owner consume signals o consulta `has/get_magnitude`.
##
## Wireado típico (Player.gd._ready):
##   status_effects = StatusEffectComponent.new()
##   status_effects.name = "StatusEffects"
##   add_child(status_effects)
##   status_effects.effect_ticked.connect(_on_status_ticked)
##
## API pública: apply / has / get_magnitude / get_remaining / remove / clear.

signal effect_applied(id: StringName, magnitude: float, source: Node)
signal effect_expired(id: StringName, source: Node)
signal effect_ticked(id: StringName, magnitude: float, source: Node)


## Instancia activa de un efecto. No es Resource — pura runtime data.
class ActiveEffect:
	var data: StatusEffectData
	var remaining: float
	var tick_remaining: float
	var magnitude: float
	var source: Node


var _active: Array[ActiveEffect] = []


## Aplica un efecto. Si ya hay uno con el mismo id, sigue stack_mode del data:
##  REFRESH → reset duration · EXTEND → suma · INDEPENDENT → instancia nueva · IGNORE → no-op.
## magnitude_override / duration_override: usar valores ad-hoc en vez del .tres.
## Pasar NAN (o no pasar) para usar el default del data.
func apply(data: StatusEffectData, source: Node = null, \
		magnitude_override: float = NAN, duration_override: float = NAN) -> void:
	if data == null:
		return
	var mag: float = magnitude_override if not is_nan(magnitude_override) else data.magnitude
	var dur: float = duration_override if not is_nan(duration_override) else data.duration
	if dur <= 0.0:
		return

	if data.stack_mode != StatusEffectData.StackMode.INDEPENDENT:
		var existing: ActiveEffect = _find(data.id)
		if existing != null:
			match data.stack_mode:
				StatusEffectData.StackMode.REFRESH:
					existing.remaining = dur
				StatusEffectData.StackMode.EXTEND:
					existing.remaining += dur
				StatusEffectData.StackMode.IGNORE:
					return
			existing.magnitude = _combine_magnitude(existing.magnitude, mag, data.magnitude_policy)
			existing.source = source
			effect_applied.emit(data.id, existing.magnitude, source)
			return

	var inst: ActiveEffect = ActiveEffect.new()
	inst.data = data
	inst.remaining = dur
	inst.magnitude = mag
	inst.tick_remaining = data.tick_interval if data.tick_interval > 0.0 else 0.0
	inst.source = source
	_active.append(inst)
	effect_applied.emit(data.id, mag, source)


func has(id: StringName) -> bool:
	return _find(id) != null


## Retorna magnitud del efecto activo o `default` si no hay. Útil para slow:
##   var mult: float = status_effects.get_magnitude(&"slow", 1.0)
func get_magnitude(id: StringName, default: float = 0.0) -> float:
	var inst: ActiveEffect = _find(id)
	return inst.magnitude if inst != null else default


## Para policies INDEPENDENT — suma magnitud de TODOS los stacks con ese id.
func get_total_magnitude(id: StringName) -> float:
	var total: float = 0.0
	for inst: ActiveEffect in _active:
		if inst.data != null and inst.data.id == id:
			total += inst.magnitude
	return total


func get_remaining(id: StringName) -> float:
	var inst: ActiveEffect = _find(id)
	return inst.remaining if inst != null else 0.0


func get_stack_count(id: StringName) -> int:
	var count: int = 0
	for inst: ActiveEffect in _active:
		if inst.data != null and inst.data.id == id:
			count += 1
	return count


## Elimina TODAS las instancias con ese id (incluso INDEPENDENT stacks).
func remove(id: StringName) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var inst: ActiveEffect = _active[i]
		if inst.data != null and inst.data.id == id:
			_active.remove_at(i)
			effect_expired.emit(id, inst.source)


func clear() -> void:
	if _active.is_empty():
		return
	var copy: Array[ActiveEffect] = _active.duplicate()
	_active.clear()
	for inst: ActiveEffect in copy:
		effect_expired.emit(inst.data.id, inst.source)


## API para tests / HUD — snapshot de efectos activos.
func get_active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for inst: ActiveEffect in _active:
		if inst.data != null and not ids.has(inst.data.id):
			ids.append(inst.data.id)
	return ids


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	for i in range(_active.size() - 1, -1, -1):
		var inst: ActiveEffect = _active[i]
		inst.remaining -= delta
		if inst.data.tick_interval > 0.0:
			inst.tick_remaining -= delta
			if inst.tick_remaining <= 0.0:
				inst.tick_remaining += inst.data.tick_interval
				effect_ticked.emit(inst.data.id, inst.magnitude, inst.source)
		if inst.remaining <= 0.0:
			_active.remove_at(i)
			effect_expired.emit(inst.data.id, inst.source)


## API para tests — avanzar tiempo manualmente sin _process.
func tick(delta: float) -> void:
	_process(delta)


func _find(id: StringName) -> ActiveEffect:
	for inst: ActiveEffect in _active:
		if inst.data != null and inst.data.id == id:
			return inst
	return null


func _combine_magnitude(prev: float, new_mag: float, policy: int) -> float:
	match policy:
		StatusEffectData.MagnitudePolicy.KEEP_MAX:
			return max(prev, new_mag)
		StatusEffectData.MagnitudePolicy.KEEP_MIN:
			return min(prev, new_mag)
		StatusEffectData.MagnitudePolicy.KEEP_LATEST:
			return new_mag
		StatusEffectData.MagnitudePolicy.SUM:
			return prev + new_mag
	return new_mag
