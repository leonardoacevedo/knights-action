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
	## VFX procedural attacheado al owner. Free en expire/remove. Pilar #2.
	var vfx_node: Node2D


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
	# Spawn VFX procedural si el id tiene visual asignado.
	inst.vfx_node = _spawn_status_vfx(data.id)
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
			_free_vfx(inst)
			effect_expired.emit(id, inst.source)


func clear() -> void:
	if _active.is_empty():
		return
	var copy: Array[ActiveEffect] = _active.duplicate()
	_active.clear()
	for inst: ActiveEffect in copy:
		_free_vfx(inst)
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
			_free_vfx(inst)
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


# ─── VFX status procedural (Pilar #2) ──────────────────────────────────────
# Atacheado al parent (owner del componente). Free en remove/expire.
# Diseño: VFX persistentes (no one-shot) que duran lo que el status.

func _spawn_status_vfx(id: StringName) -> Node2D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var vfx: Node2D = null
	match id:
		&"burn":
			vfx = _build_burn_vfx()
		&"freeze":
			vfx = _build_freeze_vfx()
		&"fractura":
			vfx = _build_fractura_vfx()
		&"desequilibrio":
			vfx = _build_desequilibrio_vfx()
		&"bendicion":
			vfx = _build_bendicion_vfx()
		&"miasma":
			vfx = _build_miasma_vfx()
		_:
			return null
	if vfx != null:
		parent.add_child(vfx)
	return vfx


func _free_vfx(inst: ActiveEffect) -> void:
	if inst.vfx_node != null and is_instance_valid(inst.vfx_node):
		inst.vfx_node.queue_free()
	inst.vfx_node = null


# ── Helpers de construcción por status ─────────────────────────────────────

func _build_particles(color_start: Color, color_end: Color, amount: int, lifetime: float,
		spread: float, vel_min: float, vel_max: float, gravity_y: float,
		emit_radius: float, scale_min: float, scale_max: float,
		direction: Vector3 = Vector3(0, -1, 0)) -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = 0.1
	p.explosiveness = 0.0
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = emit_radius
	mat.direction = direction
	mat.spread = spread
	mat.gravity = Vector3(0, gravity_y, 0)
	mat.initial_velocity_min = vel_min
	mat.initial_velocity_max = vel_max
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	var grad: Gradient = Gradient.new()
	grad.set_color(0, color_start)
	grad.set_color(1, color_end)
	var gtex: GradientTexture1D = GradientTexture1D.new()
	gtex.gradient = grad
	mat.color_ramp = gtex
	p.process_material = mat
	p.emitting = true
	return p


## Quemadura — llamas naranjas ascendentes alrededor del torso.
func _build_burn_vfx() -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.name = "BurnVFX"
	holder.position = Vector2(0, -30)
	holder.z_index = 2
	holder.add_child(_build_particles(
		Color(1.0, 0.65, 0.15, 0.95), Color(1.0, 0.20, 0.05, 0.0),
		20, 0.6, 30.0, 30.0, 90.0, -120.0, 12.0, 0.4, 1.2))
	return holder


## Congelación — cristales cyan flotando + caer lento.
func _build_freeze_vfx() -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.name = "FreezeVFX"
	holder.position = Vector2(0, -30)
	holder.z_index = 2
	holder.add_child(_build_particles(
		Color(0.60, 0.92, 1.0, 0.95), Color(0.30, 0.65, 1.0, 0.0),
		16, 0.9, 60.0, 8.0, 35.0, 25.0, 14.0, 0.6, 1.4))
	return holder


## Fractura — crack rojizo + glow pulsante sobre torso.
func _build_fractura_vfx() -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.name = "FracturaVFX"
	holder.position = Vector2(0, -28)
	holder.z_index = 3
	# Línea zigzag horizontal simulando crack
	var crack: Line2D = Line2D.new()
	crack.width = 2.5
	crack.default_color = Color(1.0, 0.35, 0.20, 0.95)
	var pts: PackedVector2Array = PackedVector2Array()
	var xs: Array = [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]
	var ys: Array = [0.0, -3.0, 2.0, -2.0, 3.0, 0.0]
	for i in range(xs.size()):
		pts.append(Vector2(xs[i], ys[i]))
	crack.points = pts
	holder.add_child(crack)
	# Glow particles cortas
	holder.add_child(_build_particles(
		Color(1.0, 0.5, 0.25, 0.85), Color(0.85, 0.15, 0.05, 0.0),
		8, 0.5, 180.0, 15.0, 40.0, -10.0, 8.0, 0.4, 0.9))
	return holder


## Desequilibrio — swirl blanco rápido alrededor de cabeza.
func _build_desequilibrio_vfx() -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.name = "DesequilibrioVFX"
	holder.position = Vector2(0, -55)
	holder.z_index = 4
	holder.add_child(_build_particles(
		Color(0.95, 0.95, 1.0, 0.85), Color(0.6, 0.6, 0.95, 0.0),
		18, 0.45, 360.0, 60.0, 120.0, 0.0, 14.0, 0.4, 0.9,
		Vector3(1, 0, 0)))
	return holder


## Bendición Divina — halo dorado pulsante encima cabeza.
func _build_bendicion_vfx() -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.name = "BendicionVFX"
	holder.position = Vector2(0, -65)
	holder.z_index = 4
	# Halo anillo Line2D
	var ring: Line2D = Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(1.0, 0.95, 0.45, 0.85)
	ring.closed = true
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var ang: float = i * TAU / 24.0
		pts.append(Vector2(cos(ang) * 12.0, sin(ang) * 4.0))
	ring.points = pts
	holder.add_child(ring)
	# Sparkles dorados
	holder.add_child(_build_particles(
		Color(1.0, 0.95, 0.5, 0.9), Color(0.95, 0.75, 0.20, 0.0),
		10, 0.7, 90.0, 15.0, 35.0, -20.0, 14.0, 0.4, 1.0))
	return holder


## Miasma — aura verde oscura pulsante envolviendo cuerpo.
func _build_miasma_vfx() -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.name = "MiasmaVFX"
	holder.position = Vector2(0, -30)
	holder.z_index = 1
	holder.add_child(_build_particles(
		Color(0.35, 0.75, 0.25, 0.85), Color(0.10, 0.30, 0.10, 0.0),
		18, 0.9, 180.0, 8.0, 25.0, -5.0, 18.0, 1.2, 2.4))
	return holder
