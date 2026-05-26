extends Node2D
class_name StickFigure

## Render procedural de figura humana con _draw(). Sprites IA llegan en Fase 3.
## Cabeza (círculo), torso, 2 brazos, 2 piernas como líneas.
## Animaciones por fórmula: idle bob, walk cycle, attack swing.
##
## Coordenadas: origen del Node2D = pies. Y crece hacia arriba en draw.
##
## Armas: dos slots opcionales (`weapon_main`, `weapon_off`).
##   - `weapon_main` se dibuja en la mano frontal (sigue el swing en ATTACK).
##   - `weapon_off` se dibuja en la mano trasera (típicamente Shield).
## Cada arma tiene su _draw_<tipo>() con shapes simples (placeholder hasta sprites IA).

enum State { IDLE, WALK, JUMP, ATTACK, HURT, DEAD, BLOCK }

## Tipos de arma visibles. NONE = sin arma visible (puños).
enum WeaponType { NONE, SWORD, BOW, STAFF, HAMMER, SHIELD }

@export var body_color: Color = Color.WHITE
@export var line_width: float = 3.0
@export var head_radius: float = 8.0
@export var torso_length: float = 22.0
@export var arm_length: float = 18.0
@export var leg_length: float = 22.0

## Arma principal (mano frontal). Sigue el swing en ATTACK.
@export var weapon_main: WeaponType = WeaponType.NONE
## Arma secundaria (mano trasera). Normalmente Shield para tanks o offhand.
@export var weapon_off: WeaponType = WeaponType.NONE
## Color del arma. Si Color(0,0,0,0), usa default por tipo.
@export var weapon_color: Color = Color(0, 0, 0, 0)
## Escala extra del arma. R4 / boss puede usar 1.4× para que se vea imponente.
@export var weapon_scale: float = 1.0

## Dirección de mirada: 1 derecha, -1 izquierda.
var facing: int = 1
var state: State = State.IDLE

# Tiempos internos para anim por fórmula.
var _time: float = 0.0
var _attack_time: float = 0.0
var _hurt_flash: float = 0.0

# ─── Bloqueo (aura sostenida + estallido al absorber) ─────────────────────────
## Si true, dibuja un círculo aura azul translúcido alrededor del personaje
## mientras dura el hold del bloqueo. El player lo controla via start/end_block_aura().
var _block_aura_active: bool = false
## Tiempo restante del estallido (segundos). -1 = sin estallido en curso.
## Lo dispara play_block_burst() cuando una carga se consume.
var _block_burst_time: float = -1.0
const BLOCK_BURST_DURATION: float = 0.35

# ─── Telegrafía de ataque (enemy windup) ──────────────────────────────────────
## Tiempo restante del telegraph (segundos). -1 = sin telegraph activo.
## Lo dispara start_telegraph() del enemy al entrar al estado TELEGRAPH.
var _telegraph_time: float = -1.0
## Duración total del telegraph actual. Usado para calcular progreso 0..1.
var _telegraph_total: float = 0.7


func _process(delta: float) -> void:
	_time += delta
	if state == State.ATTACK:
		_attack_time += delta
		if _attack_time >= 0.3:
			set_state(State.IDLE)
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
	if _block_burst_time > 0.0:
		_block_burst_time -= delta
	if _telegraph_time > 0.0:
		_telegraph_time -= delta
		if _telegraph_time <= 0.0:
			_telegraph_time = -1.0
	queue_redraw()


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	if new_state == State.ATTACK:
		_attack_time = 0.0


func set_facing(dir: int) -> void:
	if dir != 0:
		facing = sign(dir)


func flash_hurt(seconds: float = 0.15) -> void:
	_hurt_flash = seconds


## Activa el círculo aura mientras el player mantiene el bloqueo.
func start_block_aura() -> void:
	_block_aura_active = true


func end_block_aura() -> void:
	_block_aura_active = false


## Dispara el estallido visual del escudo al absorber un golpe.
## Anim corta (~0.35s) con shards radiales saliendo del escudo.
func play_block_burst() -> void:
	_block_burst_time = BLOCK_BURST_DURATION


## Arranca el feedback visual de telegrafía de ataque. Llamar desde el enemy
## al entrar al estado TELEGRAPH. `total` = duración del telegraph.
func start_telegraph(total: float) -> void:
	_telegraph_time = total
	_telegraph_total = max(total, 0.1)


## Corta el telegraph (al salir del estado TELEGRAPH, ya sea por ATTACK o cancel).
func end_telegraph() -> void:
	_telegraph_time = -1.0


## Setea las dos armas visibles. Llamar desde player o enemy cuando cambia equipo/clase.
func set_weapons(main: int, off: int = WeaponType.NONE) -> void:
	weapon_main = main
	weapon_off = off
	queue_redraw()


func _draw() -> void:
	# Aura de bloqueo: SE DIBUJA PRIMERO para quedar atrás del cuerpo.
	if _block_aura_active:
		_draw_block_aura()

	# Color base, modulado por hurt flash > dead. Telegraph NO afecta color del cuerpo
	# (decisión Leo: feedback solo via "!" arriba de la cabeza).
	var col: Color = body_color
	if _hurt_flash > 0.0:
		col = Color.WHITE.lerp(Color.RED, 0.6)
	if state == State.DEAD:
		col = Color(0.4, 0.4, 0.4, 0.7)

	# Origen Node2D = pies. Calculamos posiciones en Y NEGATIVO (arriba).
	var bob: float = sin(_time * 4.0) * 1.5 if state == State.IDLE else 0.0
	if state == State.WALK:
		bob = sin(_time * 12.0) * 2.0
	# Bloqueo: cuerpo levemente agachado (postura defensiva).
	var crouch: float = 4.0 if state == State.BLOCK else 0.0

	var pelvis: Vector2 = Vector2(0, -leg_length + bob + crouch)
	var shoulders: Vector2 = Vector2(0, pelvis.y - torso_length)
	var head_center: Vector2 = Vector2(0, shoulders.y - head_radius - 2.0)

	# Piernas
	var leg_swing: float = 0.0
	if state == State.WALK:
		leg_swing = sin(_time * 12.0) * 0.6
	elif state == State.JUMP:
		leg_swing = 0.3
	var left_foot: Vector2 = Vector2(-cos(leg_swing) * 6.0, 0)
	var right_foot: Vector2 = Vector2(cos(leg_swing) * 6.0, 0)
	draw_line(pelvis, left_foot, col, line_width)
	draw_line(pelvis, right_foot, col, line_width)

	# Torso
	draw_line(pelvis, shoulders, col, line_width)

	# Brazos
	var arm_swing: float = 0.0
	if state == State.WALK:
		arm_swing = -sin(_time * 12.0) * 0.4
	var back_arm: Vector2 = shoulders + Vector2(-arm_length * 0.7 * facing, arm_length * 0.5 + arm_swing * 6.0)
	var front_arm: Vector2 = shoulders + Vector2(arm_length * 0.4 * facing, arm_length * 0.6 - arm_swing * 6.0)

	# Brazo frontal hace swing si attack.
	# Calculamos el ángulo en espacio LOCAL (facing +1) y al final espejamos
	# solo X. Multiplicar `swing_angle * facing` Y luego no espejar X reflejaba
	# verticalmente el swing, dejando el brazo del lado equivocado del cuerpo.
	var swing_progress: float = 0.0
	if state == State.ATTACK:
		swing_progress = clamp(_attack_time / 0.3, 0.0, 1.0)
		var swing_angle: float = lerp(-PI * 0.3, PI * 0.4, swing_progress)
		var swing_local: Vector2 = Vector2(cos(swing_angle), sin(swing_angle))
		front_arm = shoulders + Vector2(swing_local.x * facing, swing_local.y) * arm_length

	# Bloqueo: el brazo trasero (que sostiene el escudo) cruza al frente cubriendo
	# el torso. El brazo frontal (arma) baja relajado al costado.
	if state == State.BLOCK:
		back_arm = shoulders + Vector2(arm_length * 0.7 * facing, arm_length * 0.25)
		front_arm = shoulders + Vector2(arm_length * 0.2 * facing, arm_length * 0.75)

	draw_line(shoulders, back_arm, col, line_width)
	draw_line(shoulders, front_arm, col, line_width)

	# Cabeza
	draw_circle(head_center, head_radius, col)
	# Detalle de cara: un punto chico indicando facing.
	var eye_offset: Vector2 = Vector2(facing * head_radius * 0.4, -2.0)
	draw_circle(head_center + eye_offset, 1.5, Color.BLACK)

	# Armas — siempre siguen facing y se dibujan en la mano correspondiente.
	# La mano frontal (front_arm) sostiene weapon_main. La trasera weapon_off.
	if weapon_main != WeaponType.NONE:
		_draw_weapon(weapon_main, front_arm, true, swing_progress)
	if weapon_off != WeaponType.NONE:
		_draw_weapon(weapon_off, back_arm, false, 0.0)

	# Estallido del escudo: shards radiales saliendo desde el centro de la mano
	# trasera. Se dibuja AL FINAL para quedar al frente de todo.
	if _block_burst_time > 0.0:
		_draw_block_burst(back_arm)

	# Telegraph overlay (halo naranja pulsante + "!" encima de la cabeza).
	# AL FINAL para quedar al frente de armas y cuerpo.
	if _telegraph_time > 0.0:
		_draw_telegraph_overlay(head_center)


# ─── Render de armas ─────────────────────────────────────────────────────────

func _draw_weapon(wtype: int, hand_pos: Vector2, is_main: bool, swing_progress: float) -> void:
	# Dispatch por tipo. Cada función dibuja desde la mano hacia afuera siguiendo facing.
	match wtype:
		WeaponType.SWORD:  _draw_sword(hand_pos, is_main, swing_progress)
		WeaponType.BOW:    _draw_bow(hand_pos, is_main, swing_progress)
		WeaponType.STAFF:  _draw_staff(hand_pos, is_main, swing_progress)
		WeaponType.HAMMER: _draw_hammer(hand_pos, is_main, swing_progress)
		WeaponType.SHIELD: _draw_shield(hand_pos)


func _default_weapon_color() -> Color:
	if weapon_color.a > 0.0:
		return weapon_color
	return Color(0.85, 0.85, 0.95, 1.0)


## Espada: hoja larga + guarda. En ATTACK sigue el swing del brazo (la hoja
## apunta perpendicular al brazo hacia el lado de avance).
func _draw_sword(hand_pos: Vector2, _is_main: bool, swing_progress: float) -> void:
	var col: Color = _default_weapon_color()
	var s: float = weapon_scale
	# Mismo patrón que el martillo: ángulo en espacio LOCAL (facing +1)
	# y espejamos solo X al final. Evita que el swing quede invertido en facing=-1.
	var local_angle: float = 0.0
	if state == State.ATTACK:
		local_angle = lerp(-PI * 0.55, PI * 0.55, swing_progress)
	else:
		local_angle = 0.1  # leve inclinación hacia adelante
	var local_dir: Vector2 = Vector2(cos(local_angle), sin(local_angle))
	var dir: Vector2 = Vector2(local_dir.x * facing, local_dir.y)
	var blade_len: float = 22.0 * s
	var blade_tip: Vector2 = hand_pos + dir * blade_len
	# Hoja (línea gruesa)
	draw_line(hand_pos, blade_tip, col, 3.0 * s)
	# Punta resaltada
	draw_circle(blade_tip, 1.8 * s, col)
	# Guarda (perpendicular)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var guard_h: float = 5.0 * s
	draw_line(hand_pos - perp * guard_h, hand_pos + perp * guard_h, Color(0.55, 0.4, 0.2, 1), 2.5 * s)
	# Empuñadura corta hacia atrás del brazo
	draw_line(hand_pos, hand_pos - dir * (4.0 * s), Color(0.35, 0.22, 0.12, 1), 2.5 * s)


## Arco: arco curvo + cuerda. En ATTACK, la cuerda se tensa hacia atrás.
func _draw_bow(hand_pos: Vector2, _is_main: bool, swing_progress: float) -> void:
	var col: Color = Color(0.55, 0.35, 0.18, 1.0)
	var s: float = weapon_scale
	# El arco se orienta vertical, la cuerda apunta hacia atrás cuando dispara.
	var bow_top: Vector2 = hand_pos + Vector2(0, -10.0 * s)
	var bow_bottom: Vector2 = hand_pos + Vector2(0, 10.0 * s)
	var bow_curve_offset: float = 8.0 * s * facing
	var mid_curve: Vector2 = hand_pos + Vector2(bow_curve_offset, 0)
	# Arco como 2 segmentos para simular curva.
	draw_line(bow_top, mid_curve, col, 2.5 * s)
	draw_line(mid_curve, bow_bottom, col, 2.5 * s)
	# Cuerda
	var string_pullback: float = -6.0 * s * facing * swing_progress
	var string_anchor: Vector2 = hand_pos + Vector2(string_pullback, 0)
	draw_line(bow_top, string_anchor, Color(0.95, 0.95, 0.9, 0.85), 1.0)
	draw_line(string_anchor, bow_bottom, Color(0.95, 0.95, 0.9, 0.85), 1.0)


## Bastón / Vara: línea vertical larga con cristal en la punta superior.
func _draw_staff(hand_pos: Vector2, _is_main: bool, swing_progress: float) -> void:
	var col_stick: Color = Color(0.45, 0.30, 0.18, 1.0)
	var col_gem: Color = Color(0.45, 0.85, 1.0, 1.0)
	var s: float = weapon_scale
	# Bastón se inclina ligeramente hacia adelante en attack.
	var lean: float = 0.0
	if state == State.ATTACK:
		lean = lerp(0.1, 0.45, swing_progress) * facing
	else:
		lean = 0.1 * facing
	var top: Vector2 = hand_pos + Vector2(sin(lean) * 28.0 * s, -cos(lean) * 28.0 * s)
	var bottom: Vector2 = hand_pos + Vector2(-sin(lean) * 8.0 * s, cos(lean) * 8.0 * s)
	draw_line(bottom, top, col_stick, 2.5 * s)
	# Cristal en la punta — brilla un poco más en attack.
	var gem_radius: float = 3.5 * s
	if state == State.ATTACK:
		gem_radius += 1.5 * s * swing_progress
	draw_circle(top, gem_radius, col_gem)
	draw_circle(top, gem_radius * 0.5, Color(0.95, 0.98, 1.0, 1.0))


## Martillo de guerra: mango grueso + cabezal rectangular. Imponente.
func _draw_hammer(hand_pos: Vector2, _is_main: bool, swing_progress: float) -> void:
	var col_head: Color = Color(0.55, 0.55, 0.6, 1.0)
	var col_handle: Color = Color(0.35, 0.22, 0.12, 1.0)
	var s: float = weapon_scale
	# Calculamos el ángulo en espacio LOCAL (asumiendo facing +1) y al final
	# espejamos solo el componente X según facing. Si multiplicáramos el angle
	# por facing y además X por facing, rotaríamos el swing 180° en vez de
	# espejarlo, dejando el martillo apuntando al suelo cuando mirás a la izquierda.
	var local_angle: float = 0.0
	if state == State.ATTACK:
		local_angle = lerp(-PI * 0.6, PI * 0.45, swing_progress)
	else:
		local_angle = -0.3  # levantado al hombro
	var local_dir: Vector2 = Vector2(cos(local_angle), sin(local_angle))
	var dir: Vector2 = Vector2(local_dir.x * facing, local_dir.y)
	var handle_len: float = 22.0 * s
	var head_pos: Vector2 = hand_pos + dir * handle_len
	# Mango grueso
	draw_line(hand_pos, head_pos, col_handle, 3.5 * s)
	# Cabezal: caja perpendicular al mango.
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var head_w: float = 9.0 * s
	var head_h: float = 7.0 * s
	var p1: Vector2 = head_pos + perp * head_w + dir * head_h
	var p2: Vector2 = head_pos + perp * head_w - dir * head_h
	var p3: Vector2 = head_pos - perp * head_w - dir * head_h
	var p4: Vector2 = head_pos - perp * head_w + dir * head_h
	draw_polygon([p1, p2, p3, p4], [col_head])
	# Bordes oscuros del cabezal
	draw_polyline([p1, p2, p3, p4, p1], Color(0.25, 0.25, 0.30, 1), 1.5 * s)


# ─── Efectos visuales de bloqueo ──────────────────────────────────────────────

## Aura translúcida azul-cian alrededor del torso mientras el bloqueo está activo.
## Pulso suave en radio y alpha para indicar "shield activo".
func _draw_block_aura() -> void:
	var center: Vector2 = Vector2(0, -leg_length - torso_length * 0.5)
	var base_radius: float = 34.0
	var pulse: float = sin(_time * 6.5) * 0.5 + 0.5  # 0..1
	var radius: float = base_radius + pulse * 3.0
	# Halo interno semitransparente.
	var fill_col: Color = Color(0.35, 0.7, 1.0, 0.18 + pulse * 0.10)
	draw_circle(center, radius, fill_col)
	# Borde más opaco y nítido.
	var rim_col: Color = Color(0.55, 0.88, 1.0, 0.55 + pulse * 0.25)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 28
	for i in steps + 1:
		var t: float = float(i) / float(steps) * TAU
		pts.append(center + Vector2(cos(t), sin(t)) * radius)
	draw_polyline(pts, rim_col, 1.8)


## Estallido del escudo: shards radiales que salen desde la posición del escudo
## y se desvanecen. Dispara al absorber una carga.
func _draw_block_burst(hand_pos: Vector2) -> void:
	var t: float = 1.0 - clamp(_block_burst_time / BLOCK_BURST_DURATION, 0.0, 1.0)
	# Centro del escudo: ligeramente al frente del brazo (mismo offset que _draw_shield).
	var center: Vector2 = hand_pos + Vector2(2.0 * facing, 0)
	var shard_count: int = 8
	var inner: float = 6.0 + t * 10.0
	var outer: float = 10.0 + t * 26.0
	var alpha: float = 1.0 - t
	var col: Color = Color(1.0, 0.9, 0.55, alpha)
	for i in shard_count:
		var ang: float = TAU * (float(i) / float(shard_count)) + t * 0.3
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var p1: Vector2 = center + dir * inner
		var p2: Vector2 = center + dir * outer
		draw_line(p1, p2, col, 2.2)
	# Anillo de impacto que se expande.
	var ring_radius: float = 8.0 + t * 22.0
	var ring_col: Color = Color(0.95, 0.95, 1.0, alpha * 0.6)
	var ring_pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 20
	for i in steps + 1:
		var a: float = float(i) / float(steps) * TAU
		ring_pts.append(center + Vector2(cos(a), sin(a)) * ring_radius)
	draw_polyline(ring_pts, ring_col, 1.5)


# ─── Telegrafía de ataque (overlay) ───────────────────────────────────────────

## Indicador "!" encima de la cabeza durante el telegraph.
## El tinte naranja del cuerpo lo hace el _draw principal; acá solo el cartel.
func _draw_telegraph_overlay(head_center: Vector2) -> void:
	var progress: float = 1.0 - clamp(_telegraph_time / _telegraph_total, 0.0, 1.0)
	# Exclamación "!" encima de la cabeza en el último 40% del telegraph.
	# Bounce vertical suave para llamar la atención.
	if progress >= 0.6:
		var bounce: float = sin(_time * 18.0) * 2.5
		var excl_pos: Vector2 = head_center + Vector2(0, -head_radius - 14.0 + bounce)
		var alert_col: Color = Color(1.0, 0.95, 0.25, 1.0)
		# Cuerpo del "!"
		draw_line(excl_pos, excl_pos + Vector2(0, 9.0), alert_col, 3.5)
		# Punto del "!"
		draw_circle(excl_pos + Vector2(0, 13.0), 2.2, alert_col)


## Escudo: ovalo grande en el brazo trasero. Color base más opaco.
func _draw_shield(hand_pos: Vector2) -> void:
	var col_face: Color = Color(0.45, 0.32, 0.20, 1.0)
	var col_rim: Color = Color(0.25, 0.18, 0.12, 1.0)
	var col_boss: Color = Color(0.7, 0.6, 0.3, 1.0)
	var s: float = weapon_scale
	# Centro del escudo desplazado un poco al frente del cuerpo.
	var center: Vector2 = hand_pos + Vector2(2.0 * facing, 0)
	var radius_x: float = 8.0 * s
	var radius_y: float = 12.0 * s
	# Ovalo construido con polygon (más barato que arc segments para placeholder).
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 14
	for i in steps:
		var t: float = float(i) / float(steps) * TAU
		pts.append(center + Vector2(cos(t) * radius_x, sin(t) * radius_y))
	draw_polygon(pts, [col_face])
	draw_polyline(pts + PackedVector2Array([pts[0]]), col_rim, 1.5 * s)
	# Boss central del escudo
	draw_circle(center, 2.5 * s, col_boss)
