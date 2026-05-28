extends StickFigure
class_name BossFigure

## Render procedural enriquecido para bosses/mini-bosses. Reemplaza el stick figure
## por una silueta llena (polígonos), con accesorios temáticos toggleables.
## Mantiene 100% del API de StickFigure (set_state, telegraph, block burst, armas)
## para no romper enemy.gd ni los hooks de boss_*.gd.
##
## Cada boss .tscn cambia el script del nodo "StickFigure" a este, y configura
## `figure_style`, `head_style`, `accent_color`, `glow_color`, etc.

## Estilo del cuerpo:
##  KNIGHT = humanoide armado (trapezoide pecho + piernas con botas)
##  BEAST  = hombros más anchos, postura más hunched (Guardian)
##  SIRENA = sin piernas, cola ondulante segmentada (Lyss)
##  GOLEM  = cuerpo rectangular más cuadrado, brazos masivos (golem de luz)
enum FigureStyle { KNIGHT, BEAST, SIRENA, GOLEM }

## Estilo de cabeza/casco:
##  HELMET     = casco con visor (default)
##  HORNS      = casco + cuernos curvos (boss bestial)
##  HALO       = corona/halo iluminado encima
##  HOOD       = capucha cayendo, ojos brillantes en sombra
##  TIARA      = tiara delgada (Lyss)
enum HeadStyle { HELMET, HORNS, HALO, HOOD, TIARA }

## Arma signature del boss. NONE = usa weapon_main heredado de StickFigure.
##  ROOTED_MAUL    = mazo de piedra musgosa (Guardian)
##  DEMENT_HAMMER  = martillo de yunque al rojo + cadenas (Ignis)
##  ICE_SCEPTER    = cetro de cristal con diamante de hielo (Lyss)
##  LIGHT_LANCE    = lanza alargada radiante dorada (Vael)
##  DUAL_RAPIERS   = dos floretes finos cruzados (Duelista)
##  CRESCENT_BOW   = arco luna creciente con flecha dorada (Cazadora)
##  VORTEX_STAFF   = báculo retorcido con orbe vórtice (Heraldo)
enum SignatureWeapon {
	NONE, ROOTED_MAUL, DEMENT_HAMMER, ICE_SCEPTER,
	LIGHT_LANCE, DUAL_RAPIERS, CRESCENT_BOW, VORTEX_STAFF,
}

@export var signature_weapon: SignatureWeapon = SignatureWeapon.NONE

@export var figure_style: FigureStyle = FigureStyle.KNIGHT
@export var head_style: HeadStyle = HeadStyle.HELMET
## Tinte secundario para detalles (pecho, botas, accesorios).
@export var accent_color: Color = Color(0.35, 0.35, 0.42, 1.0)
## Color de glow/aura pulsante boss. Alpha controla intensidad base.
@export var glow_color: Color = Color(0.95, 0.55, 0.15, 0.55)
## Color de ojos (brillantes en sombras de capucha o golem).
@export var eye_glow_color: Color = Color(1.0, 0.85, 0.2, 1.0)
## Capa flotante atrás del cuerpo.
@export var has_cape: bool = false
@export var cape_color: Color = Color(0.25, 0.1, 0.1, 0.95)
## Escala extra del silhouette (1.0 default — bosses suelen estar ya escalados via Node2D.scale).
@export var body_scale_mult: float = 1.0


func _draw() -> void:
	# Aura de bloqueo PRIMERO (atrás de todo).
	if _block_aura_active:
		_draw_block_aura()

	var col: Color = body_color
	if _hurt_flash > 0.0:
		col = Color.WHITE.lerp(Color.RED, 0.6)
	if state == State.DEAD:
		col = Color(0.4, 0.4, 0.4, 0.7)

	# Anim: bob idle y walk, crouch en bloqueo
	var bob: float = 0.0
	if state == State.IDLE:
		bob = sin(_time * 3.5) * 1.5
	elif state == State.WALK:
		bob = sin(_time * 10.0) * 2.2
	var crouch: float = 6.0 if state == State.BLOCK else 0.0

	var s: float = body_scale_mult
	var pelvis: Vector2 = Vector2(0, -leg_length * s + bob + crouch)
	var shoulders: Vector2 = Vector2(0, pelvis.y - torso_length * s)
	var head_center: Vector2 = Vector2(0, shoulders.y - head_radius * s - 4.0)

	# Glow outline pulse — refuerza el "feel boss"
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.2)
	var glow_a: float = clamp(glow_color.a * (0.55 + 0.45 * pulse), 0.0, 1.0)
	var glow: Color = Color(glow_color.r, glow_color.g, glow_color.b, glow_a)

	# Capa atrás
	if has_cape:
		_draw_cape(shoulders, pelvis, s)

	# Halo de glow alrededor del torso (atrás del cuerpo, frente de la capa)
	_draw_body_glow(pelvis, shoulders, head_center, glow, s)

	# Cuerpo silhouette según estilo
	match figure_style:
		FigureStyle.SIRENA:
			_draw_sirena_tail(pelvis, col, s)
			_draw_torso_filled(pelvis, shoulders, col, s, 0.7)
		FigureStyle.GOLEM:
			_draw_armored_legs(pelvis, col, s, 1.1)
			_draw_torso_filled(pelvis, shoulders, col, s, 1.15)
		FigureStyle.BEAST:
			_draw_armored_legs(pelvis, col, s, 0.95)
			_draw_torso_filled(pelvis, shoulders, col, s, 1.1)
		_:
			_draw_armored_legs(pelvis, col, s, 1.0)
			_draw_torso_filled(pelvis, shoulders, col, s, 1.0)

	# Brazos (siguen lógica StickFigure pero con grosor de boss)
	var swing_progress: float = 0.0
	if state == State.ATTACK:
		swing_progress = clamp(_attack_time / 0.3, 0.0, 1.0)
	var arm_swing: float = 0.0
	if state == State.WALK:
		arm_swing = -sin(_time * 10.0) * 0.4
	var arm_thick: float = 6.0 * s
	if figure_style == FigureStyle.GOLEM:
		arm_thick = 9.0 * s
	var back_arm: Vector2 = shoulders + Vector2(-arm_length * 0.75 * facing * s, arm_length * 0.5 * s + arm_swing * 5.0)
	var front_arm: Vector2 = shoulders + Vector2(arm_length * 0.45 * facing * s, arm_length * 0.6 * s - arm_swing * 5.0)
	if state == State.ATTACK:
		var swing_angle: float = lerp(-PI * 0.3, PI * 0.4, swing_progress)
		var local_dir: Vector2 = Vector2(cos(swing_angle), sin(swing_angle))
		front_arm = shoulders + Vector2(local_dir.x * facing, local_dir.y) * arm_length * s
	if state == State.BLOCK:
		back_arm = shoulders + Vector2(arm_length * 0.7 * facing * s, arm_length * 0.25 * s)
		front_arm = shoulders + Vector2(arm_length * 0.2 * facing * s, arm_length * 0.75 * s)
	draw_line(shoulders, back_arm, col, arm_thick)
	draw_line(shoulders, front_arm, col, arm_thick)
	# "Manopla" — círculo pequeño en cada mano para volumen
	draw_circle(back_arm, arm_thick * 0.6, accent_color)
	draw_circle(front_arm, arm_thick * 0.6, accent_color)

	# Cabeza (según head_style)
	_draw_head(head_center, col, s)

	# Armas: si hay signature, dispatch a draw específico del boss.
	# Sino, cae al render heredado de StickFigure.
	if signature_weapon != SignatureWeapon.NONE:
		_draw_signature_weapon(front_arm, back_arm, swing_progress, s)
		# weapon_off (escudo) sigue dibujándose normal si el boss lo trae
		if weapon_off != WeaponType.NONE and signature_weapon != SignatureWeapon.DUAL_RAPIERS:
			_draw_weapon(weapon_off, back_arm, false, 0.0)
	else:
		if weapon_main != WeaponType.NONE:
			_draw_weapon(weapon_main, front_arm, true, swing_progress)
		if weapon_off != WeaponType.NONE:
			_draw_weapon(weapon_off, back_arm, false, 0.0)

	# Block burst + telegraph overlay (heredados, AL FINAL)
	if _block_burst_time > 0.0:
		_draw_block_burst(back_arm)
	if _telegraph_time > 0.0:
		_draw_telegraph_overlay(head_center)


# ─── Partes del cuerpo ───────────────────────────────────────────────────────

## Torso filled como trapezoide (pecho ancho hombros + accent stripe central).
## width_mult escala el ancho de hombros/cadera para variar entre figure styles.
func _draw_torso_filled(pelvis: Vector2, shoulders: Vector2, col: Color, s: float, width_mult: float) -> void:
	var hip_w: float = 11.0 * s * width_mult
	var sh_w: float = 17.0 * s * width_mult
	var torso_poly: PackedVector2Array = PackedVector2Array([
		pelvis + Vector2(-hip_w, 0),
		pelvis + Vector2(hip_w, 0),
		shoulders + Vector2(sh_w, 2.0),
		shoulders + Vector2(-sh_w, 2.0),
	])
	draw_colored_polygon(torso_poly, col)
	# Stripe central tipo armadura (accent)
	var stripe_top_w: float = sh_w * 0.45
	var stripe_bot_w: float = hip_w * 0.55
	var stripe_poly: PackedVector2Array = PackedVector2Array([
		pelvis + Vector2(-stripe_bot_w, -1.0),
		pelvis + Vector2(stripe_bot_w, -1.0),
		shoulders + Vector2(stripe_top_w, 4.0),
		shoulders + Vector2(-stripe_top_w, 4.0),
	])
	draw_colored_polygon(stripe_poly, accent_color)
	# Cuello/gorguera
	draw_line(shoulders, shoulders + Vector2(0, -5.0 * s), col, 8.0 * s)


## Piernas armadas como 2 trapezoides + botas en accent_color.
## width_mult permite golems más anchos.
func _draw_armored_legs(pelvis: Vector2, col: Color, s: float, width_mult: float) -> void:
	var leg_swing: float = 0.0
	if state == State.WALK:
		leg_swing = sin(_time * 10.0) * 0.5
	elif state == State.JUMP:
		leg_swing = 0.3
	var foot_offset: float = 7.0 * s * width_mult
	var thigh_w: float = 5.5 * s * width_mult
	var shin_w: float = 4.0 * s * width_mult
	var leg_h: float = leg_length * s
	# Pierna izquierda
	var lf: Vector2 = Vector2(-foot_offset - cos(leg_swing) * 4.0, 0)
	_draw_leg_trapezoid(pelvis + Vector2(-2.0 * width_mult, -1.0), lf, thigh_w, shin_w, col)
	# Pierna derecha
	var rf: Vector2 = Vector2(foot_offset + cos(leg_swing) * 4.0, 0)
	_draw_leg_trapezoid(pelvis + Vector2(2.0 * width_mult, -1.0), rf, thigh_w, shin_w, col)
	# Botas (accent)
	var boot_h: float = 4.0 * s
	draw_rect(Rect2(lf.x - shin_w, -boot_h, shin_w * 2.0, boot_h), accent_color, true)
	draw_rect(Rect2(rf.x - shin_w, -boot_h, shin_w * 2.0, boot_h), accent_color, true)


func _draw_leg_trapezoid(top: Vector2, bottom: Vector2, top_w: float, bot_w: float, col: Color) -> void:
	var poly: PackedVector2Array = PackedVector2Array([
		top + Vector2(-top_w, 0),
		top + Vector2(top_w, 0),
		bottom + Vector2(bot_w, 0),
		bottom + Vector2(-bot_w, 0),
	])
	draw_colored_polygon(poly, col)


## Cola de sirena ondulante (3 segmentos). Reemplaza piernas en Lyss.
func _draw_sirena_tail(pelvis: Vector2, col: Color, s: float) -> void:
	var wave: float = sin(_time * 3.0)
	var seg_h: float = leg_length * 0.4 * s
	var top: Vector2 = pelvis
	var mid: Vector2 = top + Vector2(wave * 4.0 * s, seg_h)
	var low: Vector2 = mid + Vector2(-wave * 6.0 * s, seg_h)
	# Segmento alto (más ancho)
	_draw_leg_trapezoid(top, mid, 10.0 * s, 7.0 * s, col)
	# Segmento medio
	_draw_leg_trapezoid(mid, low, 7.0 * s, 4.0 * s, col)
	# Aleta caudal — 2 puntos a los costados del extremo bajo
	var fin_color: Color = accent_color
	var fin_w: float = 12.0 * s
	var fin_h: float = 6.0 * s
	var fin_poly: PackedVector2Array = PackedVector2Array([
		low + Vector2(-2.0 * s, -1.0),
		low + Vector2(2.0 * s, -1.0),
		low + Vector2(fin_w + wave * 2.0 * s, fin_h),
		low + Vector2(-fin_w - wave * 2.0 * s, fin_h),
	])
	draw_colored_polygon(fin_poly, fin_color)


## Capa atrás del cuerpo (ondula con _time).
func _draw_cape(shoulders: Vector2, pelvis: Vector2, s: float) -> void:
	var wave: float = sin(_time * 1.8) * 3.0 * s
	var cape_top_w: float = 16.0 * s
	var cape_bot_w: float = 24.0 * s + abs(wave)
	var cape_bottom_y: float = pelvis.y + 8.0 * s
	# Capa se desplaza al lado contrario al facing (efecto "ondea atrás")
	var cape_sway: float = -facing * 4.0 * s
	var cape_poly: PackedVector2Array = PackedVector2Array([
		shoulders + Vector2(-cape_top_w, 4.0),
		shoulders + Vector2(cape_top_w, 4.0),
		Vector2(cape_sway + cape_bot_w, cape_bottom_y),
		Vector2(cape_sway + wave, cape_bottom_y + 4.0 * s),
		Vector2(cape_sway - cape_bot_w, cape_bottom_y),
	])
	draw_colored_polygon(cape_poly, cape_color)


## Glow ovalado pulsante atrás del cuerpo. Realza el "presence" del boss.
func _draw_body_glow(pelvis: Vector2, _shoulders: Vector2, head_center: Vector2, glow: Color, s: float) -> void:
	if glow.a < 0.02:
		return
	var mid_y: float = (pelvis.y + head_center.y) * 0.5
	var center: Vector2 = Vector2(0, mid_y)
	var rx: float = 28.0 * s
	var ry: float = abs(head_center.y - pelvis.y) * 0.65
	var pts: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for i in range(segments):
		var ang: float = i * TAU / float(segments)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, glow)


# ─── Cabeza ──────────────────────────────────────────────────────────────────

func _draw_head(head_center: Vector2, col: Color, s: float) -> void:
	var hr: float = head_radius * s * 1.1
	match head_style:
		HeadStyle.HELMET:
			_draw_helmet(head_center, col, hr, s)
		HeadStyle.HORNS:
			_draw_helmet(head_center, col, hr, s)
			_draw_horns(head_center, accent_color.darkened(0.25), hr, s)
		HeadStyle.HALO:
			_draw_helmet(head_center, col, hr, s)
			_draw_halo(head_center, glow_color, hr, s)
		HeadStyle.HOOD:
			_draw_hood(head_center, col, hr, s)
		HeadStyle.TIARA:
			_draw_helmet(head_center, col, hr * 0.95, s)
			_draw_tiara(head_center, accent_color, hr, s)


func _draw_helmet(head_center: Vector2, col: Color, hr: float, _s: float) -> void:
	# Casco = óvalo levemente alargado
	var pts: PackedVector2Array = PackedVector2Array()
	var segments: int = 16
	for i in range(segments):
		var ang: float = i * TAU / float(segments)
		pts.append(head_center + Vector2(cos(ang) * hr * 0.95, sin(ang) * hr * 1.1))
	draw_colored_polygon(pts, col)
	# Visor — banda horizontal oscura con un punto rojo (ojo)
	var visor_h: float = hr * 0.32
	var visor_y: float = head_center.y - hr * 0.05
	draw_rect(Rect2(head_center.x - hr * 0.85, visor_y - visor_h * 0.5, hr * 1.7, visor_h),
		Color(0.05, 0.05, 0.08, 1.0), true)
	# Ojo brillante
	var eye_pos: Vector2 = Vector2(head_center.x + facing * hr * 0.35, visor_y)
	draw_circle(eye_pos, hr * 0.13, eye_glow_color)


func _draw_horns(head_center: Vector2, horn_col: Color, hr: float, _s: float) -> void:
	# Dos cuernos curvos saliendo de la parte superior, hacia arriba+afuera
	var base_l: Vector2 = head_center + Vector2(-hr * 0.55, -hr * 0.85)
	var tip_l: Vector2 = base_l + Vector2(-hr * 0.8, -hr * 0.9)
	var mid_l: Vector2 = base_l + Vector2(-hr * 0.55, -hr * 0.35)
	var horn_l: PackedVector2Array = PackedVector2Array([
		base_l + Vector2(hr * 0.25, 0),
		mid_l,
		tip_l,
		base_l + Vector2(-hr * 0.1, 0),
	])
	draw_colored_polygon(horn_l, horn_col)
	var base_r: Vector2 = head_center + Vector2(hr * 0.55, -hr * 0.85)
	var tip_r: Vector2 = base_r + Vector2(hr * 0.8, -hr * 0.9)
	var mid_r: Vector2 = base_r + Vector2(hr * 0.55, -hr * 0.35)
	var horn_r: PackedVector2Array = PackedVector2Array([
		base_r + Vector2(-hr * 0.25, 0),
		mid_r,
		tip_r,
		base_r + Vector2(hr * 0.1, 0),
	])
	draw_colored_polygon(horn_r, horn_col)


func _draw_halo(head_center: Vector2, halo_col: Color, hr: float, _s: float) -> void:
	# Anillo dorado pulsante encima del casco. Outline grueso (no relleno).
	var pulse: float = 0.7 + 0.3 * sin(_time * 3.5)
	var halo_y: float = head_center.y - hr * 1.5
	var halo_rx: float = hr * 1.6
	var halo_ry: float = hr * 0.45
	var c: Color = Color(halo_col.r, halo_col.g, halo_col.b, clamp(halo_col.a * pulse + 0.25, 0.0, 1.0))
	var segments: int = 24
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var ang: float = i * TAU / float(segments)
		pts.append(Vector2(head_center.x + cos(ang) * halo_rx, halo_y + sin(ang) * halo_ry))
	for i in range(segments):
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % segments]
		draw_line(p0, p1, c, 3.0)


func _draw_hood(head_center: Vector2, col: Color, hr: float, _s: float) -> void:
	# Capucha = trapezoide curvo cubriendo el frente de la cabeza. Cara en sombra con ojos.
	var hood_top_w: float = hr * 0.5
	var hood_bot_w: float = hr * 1.25
	var hood_top: Vector2 = head_center + Vector2(0, -hr * 1.0)
	var hood_bot_y: float = head_center.y + hr * 0.6
	var hood_poly: PackedVector2Array = PackedVector2Array([
		hood_top + Vector2(-hood_top_w * 0.6, 0),
		hood_top + Vector2(hood_top_w * 0.6, 0),
		Vector2(head_center.x + hood_bot_w, hood_bot_y),
		Vector2(head_center.x + hood_bot_w * 0.5, hood_bot_y + hr * 0.3),
		Vector2(head_center.x - hood_bot_w * 0.5, hood_bot_y + hr * 0.3),
		Vector2(head_center.x - hood_bot_w, hood_bot_y),
	])
	draw_colored_polygon(hood_poly, col)
	# Sombra interior (más oscuro)
	var shadow_poly: PackedVector2Array = PackedVector2Array([
		head_center + Vector2(-hr * 0.5, -hr * 0.4),
		head_center + Vector2(hr * 0.5, -hr * 0.4),
		head_center + Vector2(hr * 0.4, hr * 0.5),
		head_center + Vector2(-hr * 0.4, hr * 0.5),
	])
	draw_colored_polygon(shadow_poly, Color(0.04, 0.04, 0.06, 0.95))
	# Dos ojos brillantes en la sombra
	var eye_y: float = head_center.y - hr * 0.05
	draw_circle(Vector2(head_center.x - hr * 0.22, eye_y), hr * 0.12, eye_glow_color)
	draw_circle(Vector2(head_center.x + hr * 0.22, eye_y), hr * 0.12, eye_glow_color)


func _draw_tiara(head_center: Vector2, tiara_col: Color, hr: float, _s: float) -> void:
	# Tiara fina con 3 picos (la del medio más alto). Lyss.
	var base_y: float = head_center.y - hr * 0.7
	var span: float = hr * 1.1
	var base_l: Vector2 = Vector2(head_center.x - span, base_y)
	var base_r: Vector2 = Vector2(head_center.x + span, base_y)
	# Banda inferior
	draw_line(base_l, base_r, tiara_col, 2.5)
	# 3 picos
	var p_l: Vector2 = base_l + Vector2(span * 0.4, -hr * 0.45)
	var p_c: Vector2 = head_center + Vector2(0, -hr * 1.35)
	var p_r: Vector2 = base_r + Vector2(-span * 0.4, -hr * 0.45)
	draw_line(base_l + Vector2(span * 0.15, 0), p_l, tiara_col, 2.0)
	draw_line(p_l, base_l + Vector2(span * 0.65, 0), tiara_col, 2.0)
	draw_line(base_l + Vector2(span * 0.7, 0), p_c, tiara_col, 2.5)
	draw_line(p_c, base_r - Vector2(span * 0.7, 0), tiara_col, 2.5)
	draw_line(base_r - Vector2(span * 0.65, 0), p_r, tiara_col, 2.0)
	draw_line(p_r, base_r - Vector2(span * 0.15, 0), tiara_col, 2.0)
	# Gema central brillante
	draw_circle(p_c + Vector2(0, hr * 0.15), 2.5, eye_glow_color)


# ─── Armas signature ─────────────────────────────────────────────────────────

## Dispatch a la draw específica del boss.
func _draw_signature_weapon(front_arm: Vector2, back_arm: Vector2, swing: float, s: float) -> void:
	match signature_weapon:
		SignatureWeapon.ROOTED_MAUL:
			_draw_rooted_maul(front_arm, swing, s)
		SignatureWeapon.DEMENT_HAMMER:
			_draw_dement_hammer(front_arm, swing, s)
		SignatureWeapon.ICE_SCEPTER:
			_draw_ice_scepter(front_arm, swing, s)
		SignatureWeapon.LIGHT_LANCE:
			_draw_light_lance(front_arm, swing, s)
		SignatureWeapon.DUAL_RAPIERS:
			_draw_dual_rapiers(front_arm, back_arm, swing, s)
		SignatureWeapon.CRESCENT_BOW:
			_draw_crescent_bow(front_arm, swing, s)
		SignatureWeapon.VORTEX_STAFF:
			_draw_vortex_staff(front_arm, swing, s)


## Mazo de Piedra Musgosa (Guardian). Cabeza ovalada gris + parches musgo + 4 púas cortas.
func _draw_rooted_maul(hand: Vector2, swing: float, s: float) -> void:
	var local_angle: float = 0.0
	if state == State.ATTACK:
		local_angle = lerp(-PI * 0.45, PI * 0.55, swing)
	else:
		local_angle = 0.15
	var dir: Vector2 = Vector2(cos(local_angle) * facing, sin(local_angle))
	var handle_len: float = 26.0 * weapon_scale
	var head_pos: Vector2 = hand + dir * handle_len
	# Mango (madera gruesa)
	draw_line(hand, head_pos, Color(0.32, 0.20, 0.10, 1.0), 4.5 * s)
	# Cabeza de piedra (óvalo)
	var stone_pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 14
	var stone_rx: float = 12.0 * weapon_scale
	var stone_ry: float = 14.0 * weapon_scale
	for i in range(segs):
		var ang: float = i * TAU / float(segs)
		stone_pts.append(head_pos + Vector2(cos(ang) * stone_rx, sin(ang) * stone_ry))
	draw_colored_polygon(stone_pts, Color(0.45, 0.42, 0.38, 1.0))
	# Parches musgo (3 círculos verdes superpuestos)
	draw_circle(head_pos + Vector2(-3.0 * weapon_scale, -4.0 * weapon_scale), 4.0 * weapon_scale, Color(0.30, 0.55, 0.20, 0.9))
	draw_circle(head_pos + Vector2(4.0 * weapon_scale, 2.0 * weapon_scale), 3.0 * weapon_scale, Color(0.35, 0.60, 0.22, 0.85))
	draw_circle(head_pos + Vector2(-1.0 * weapon_scale, 5.0 * weapon_scale), 2.5 * weapon_scale, Color(0.28, 0.50, 0.18, 0.9))
	# 4 púas cortas alrededor
	var spike_dirs: Array = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]
	for d: Vector2 in spike_dirs:
		var tip: Vector2 = head_pos + d * (stone_rx + 5.0 * weapon_scale)
		var base_perp: Vector2 = Vector2(-d.y, d.x) * 2.5 * weapon_scale
		var spike_poly: PackedVector2Array = PackedVector2Array([
			head_pos + d * stone_rx * 0.85 + base_perp,
			head_pos + d * stone_rx * 0.85 - base_perp,
			tip,
		])
		draw_colored_polygon(spike_poly, Color(0.55, 0.50, 0.45, 1.0))


## Martillo Demente (Ignis). Yunque al rojo + cadenas.
func _draw_dement_hammer(hand: Vector2, swing: float, s: float) -> void:
	var local_angle: float = 0.0
	if state == State.ATTACK:
		local_angle = lerp(-PI * 0.5, PI * 0.55, swing)
	else:
		local_angle = 0.15
	var dir: Vector2 = Vector2(cos(local_angle) * facing, sin(local_angle))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var handle_len: float = 28.0 * weapon_scale
	var head_pos: Vector2 = hand + dir * handle_len
	# Mango (hierro oscuro)
	draw_line(hand, head_pos, Color(0.22, 0.18, 0.16, 1.0), 5.0 * s)
	# Yunque/cabeza rectangular grande (rojo brasa)
	var head_w: float = 22.0 * weapon_scale
	var head_h: float = 12.0 * weapon_scale
	var head_poly: PackedVector2Array = PackedVector2Array([
		head_pos + dir * (-head_w * 0.4) + perp * head_h,
		head_pos + dir * head_w + perp * head_h,
		head_pos + dir * head_w - perp * head_h,
		head_pos + dir * (-head_w * 0.4) - perp * head_h,
	])
	draw_colored_polygon(head_poly, Color(0.55, 0.18, 0.10, 1.0))
	# Brasa brillante en el centro de la cabeza (pulsante)
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	draw_circle(head_pos + dir * (head_w * 0.3), 5.5 * weapon_scale,
		Color(1.0, 0.55 + pulse * 0.35, 0.15, 0.95))
	draw_circle(head_pos + dir * (head_w * 0.3), 3.0 * weapon_scale,
		Color(1.0, 0.95, 0.55, 1.0))
	# Cadenas: 3 eslabones desde el mango bajo hacia el cuerpo
	var chain_col: Color = Color(0.35, 0.32, 0.30, 1.0)
	var anchor: Vector2 = hand + dir * (handle_len * 0.3)
	for i in range(4):
		var t: float = float(i) / 3.0
		var seg_pos: Vector2 = anchor.lerp(anchor + Vector2(-facing * 18.0 * s, 16.0 * s), t)
		seg_pos.y += sin(_time * 3.0 + float(i)) * 1.5 * s
		draw_circle(seg_pos, 2.5 * s, chain_col)


## Cetro de Hielo (Lyss). Mango cian + diamante en la punta + chispas.
func _draw_ice_scepter(hand: Vector2, swing: float, s: float) -> void:
	var lean: float = 0.0
	if state == State.ATTACK:
		lean = lerp(0.1, 0.5, swing) * facing
	else:
		lean = 0.08 * facing
	var top: Vector2 = hand + Vector2(sin(lean) * 32.0 * weapon_scale, -cos(lean) * 32.0 * weapon_scale)
	var bottom: Vector2 = hand + Vector2(-sin(lean) * 6.0 * weapon_scale, cos(lean) * 6.0 * weapon_scale)
	# Mango cristal claro
	draw_line(bottom, top, Color(0.75, 0.92, 1.0, 0.95), 3.0 * s)
	# Diamante en la punta (4 puntas)
	var dpts: PackedVector2Array = PackedVector2Array([
		top + Vector2(0, -8.0 * weapon_scale),
		top + Vector2(5.0 * weapon_scale, 0),
		top + Vector2(0, 7.0 * weapon_scale),
		top + Vector2(-5.0 * weapon_scale, 0),
	])
	draw_colored_polygon(dpts, Color(0.80, 0.97, 1.0, 1.0))
	# Núcleo brillante
	draw_circle(top, 2.2 * weapon_scale, Color(1.0, 1.0, 1.0, 1.0))
	# Chispas/escarcha cayendo (3 puntos alrededor)
	for i in range(3):
		var off_x: float = (sin(_time * 2.0 + float(i) * 2.1) * 8.0 - 4.0) * weapon_scale
		var off_y: float = (fmod(_time * 8.0 + float(i) * 4.0, 16.0)) * weapon_scale
		draw_circle(top + Vector2(off_x, off_y), 1.2 * weapon_scale,
			Color(0.85, 0.95, 1.0, 0.85))


## Lanza de Luz Penetrante (Vael). Larga y delgada con halo radiante.
func _draw_light_lance(hand: Vector2, swing: float, s: float) -> void:
	var local_angle: float = 0.0
	if state == State.ATTACK:
		local_angle = lerp(-PI * 0.2, PI * 0.15, swing)
	else:
		local_angle = -0.05
	var dir: Vector2 = Vector2(cos(local_angle) * facing, sin(local_angle))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var lance_len: float = 42.0 * weapon_scale
	var tip: Vector2 = hand + dir * lance_len
	# Mango blanco-dorado
	draw_line(hand, hand + dir * (lance_len * 0.7), Color(0.85, 0.78, 0.45, 1.0), 3.5 * s)
	# Cuchilla larga (triángulo alargado)
	var blade_base: Vector2 = hand + dir * (lance_len * 0.7)
	var blade_w: float = 3.0 * weapon_scale
	var blade_poly: PackedVector2Array = PackedVector2Array([
		blade_base + perp * blade_w,
		tip,
		blade_base - perp * blade_w,
	])
	draw_colored_polygon(blade_poly, Color(1.0, 0.98, 0.65, 1.0))
	# Halo radiante a lo largo de la hoja
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.5)
	draw_line(blade_base, tip, Color(1.0, 1.0, 0.85, 0.35 + pulse * 0.30), 7.0 * s)
	# Punta brillante
	draw_circle(tip, 2.8 * weapon_scale, Color(1.0, 1.0, 0.95, 0.95))
	# Pomo dorado
	draw_circle(hand - dir * (3.0 * weapon_scale), 2.5 * weapon_scale,
		Color(0.95, 0.78, 0.30, 1.0))


## Dos floretes finos (Duelista). Uno en cada mano. Ambos siguen swing en attack.
func _draw_dual_rapiers(front_hand: Vector2, back_hand: Vector2, swing: float, s: float) -> void:
	_draw_rapier(front_hand, swing, s, true)
	# El back rapier hace counter-swing leve (swing en sentido opuesto, más recogido)
	var back_swing: float = clamp(1.0 - swing, 0.0, 1.0) * 0.5
	_draw_rapier(back_hand, back_swing, s, false)


func _draw_rapier(hand: Vector2, swing: float, s: float, is_main: bool) -> void:
	var local_angle: float = 0.0
	if state == State.ATTACK:
		local_angle = lerp(-PI * 0.5, PI * 0.5, swing)
	else:
		local_angle = -0.1 if is_main else 0.2
	var dir: Vector2 = Vector2(cos(local_angle) * facing, sin(local_angle))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var blade_len: float = 30.0 * weapon_scale
	var tip: Vector2 = hand + dir * blade_len
	# Hoja fina plateada
	draw_line(hand, tip, Color(0.92, 0.92, 0.98, 1.0), 1.8 * s)
	# Guarda circular tipo cazoleta
	draw_circle(hand, 4.0 * weapon_scale, Color(0.70, 0.50, 0.20, 1.0))
	draw_circle(hand, 3.0 * weapon_scale, Color(0.30, 0.20, 0.10, 1.0))
	# Punta resaltada
	draw_circle(tip, 1.5 * weapon_scale, Color(1.0, 1.0, 1.0, 1.0))
	# Pomo
	draw_circle(hand - dir * (3.0 * weapon_scale), 2.0 * weapon_scale,
		Color(0.80, 0.60, 0.25, 1.0))
	# Reflejo: línea más clara a lo largo de la hoja
	var refl_off: Vector2 = perp * 0.5 * s
	draw_line(hand + refl_off, tip + refl_off,
		Color(1.0, 1.0, 1.0, 0.45), 0.8 * s)


## Arco luna creciente (Cazadora). Curva más pronunciada que el arco base + flecha dorada.
func _draw_crescent_bow(hand: Vector2, swing: float, s: float) -> void:
	var bow_h: float = 18.0 * weapon_scale
	# Arco curvado en 3 segmentos (luna creciente)
	var bow_top: Vector2 = hand + Vector2(0, -bow_h)
	var bow_bot: Vector2 = hand + Vector2(0, bow_h)
	var curve_off: float = 14.0 * weapon_scale * facing
	var top_mid: Vector2 = hand + Vector2(curve_off * 0.55, -bow_h * 0.55)
	var bot_mid: Vector2 = hand + Vector2(curve_off * 0.55, bow_h * 0.55)
	var col_bow: Color = Color(0.55, 0.35, 0.18, 1.0)
	draw_line(bow_top, top_mid, col_bow, 3.0 * s)
	draw_line(top_mid, hand + Vector2(curve_off, 0), col_bow, 3.5 * s)
	draw_line(hand + Vector2(curve_off, 0), bot_mid, col_bow, 3.5 * s)
	draw_line(bot_mid, bow_bot, col_bow, 3.0 * s)
	# Puntas de la luna (afiladas)
	var tip_a: Vector2 = bow_top + Vector2(-curve_off * 0.15, -3.0 * weapon_scale)
	var tip_b: Vector2 = bow_bot + Vector2(-curve_off * 0.15, 3.0 * weapon_scale)
	draw_line(bow_top, tip_a, Color(0.85, 0.85, 0.95, 1.0), 2.0 * s)
	draw_line(bow_bot, tip_b, Color(0.85, 0.85, 0.95, 1.0), 2.0 * s)
	# Cuerda tensada cuando attack
	var pullback: float = -8.0 * weapon_scale * facing * swing
	var anchor: Vector2 = hand + Vector2(pullback, 0)
	draw_line(bow_top, anchor, Color(0.95, 0.95, 0.9, 0.85), 1.0)
	draw_line(anchor, bow_bot, Color(0.95, 0.95, 0.9, 0.85), 1.0)
	# Flecha dorada lista
	var arrow_len: float = (20.0 + swing * 8.0) * weapon_scale
	var arrow_tip: Vector2 = anchor + Vector2(facing * arrow_len, 0)
	draw_line(anchor, arrow_tip, Color(0.85, 0.65, 0.20, 1.0), 1.8 * s)
	# Punta triángulo
	var head_poly: PackedVector2Array = PackedVector2Array([
		arrow_tip,
		arrow_tip + Vector2(-facing * 4.0 * weapon_scale, -2.5 * weapon_scale),
		arrow_tip + Vector2(-facing * 4.0 * weapon_scale, 2.5 * weapon_scale),
	])
	draw_colored_polygon(head_poly, Color(0.98, 0.80, 0.30, 1.0))


## Báculo Vórtice (Heraldo). Mango retorcido + orbe púrpura con espirales.
func _draw_vortex_staff(hand: Vector2, swing: float, s: float) -> void:
	var lean: float = 0.0
	if state == State.ATTACK:
		lean = lerp(0.15, 0.55, swing) * facing
	else:
		lean = 0.1 * facing
	var top: Vector2 = hand + Vector2(sin(lean) * 34.0 * weapon_scale, -cos(lean) * 34.0 * weapon_scale)
	var bottom: Vector2 = hand + Vector2(-sin(lean) * 8.0 * weapon_scale, cos(lean) * 8.0 * weapon_scale)
	# Mango oscuro retorcido (2 líneas paralelas onduladas)
	var col_staff: Color = Color(0.20, 0.10, 0.28, 1.0)
	var staff_dir: Vector2 = (top - bottom).normalized()
	var staff_perp: Vector2 = Vector2(-staff_dir.y, staff_dir.x)
	var twist_off: float = 1.5 * sin(_time * 4.0) * s
	draw_line(bottom + staff_perp * twist_off, top - staff_perp * twist_off, col_staff, 3.0 * s)
	draw_line(bottom - staff_perp * twist_off, top + staff_perp * twist_off,
		Color(0.40, 0.22, 0.50, 0.9), 2.0 * s)
	# 3 brazos curvos abrazando el orbe (cuernos de hechicería)
	var orb_pos: Vector2 = top
	for i in range(3):
		var ang_off: float = float(i) * TAU / 3.0 + _time * 1.5
		var arm_start: Vector2 = orb_pos + Vector2(cos(ang_off), sin(ang_off)) * 7.0 * weapon_scale
		var arm_end: Vector2 = orb_pos + Vector2(cos(ang_off), sin(ang_off)) * 11.0 * weapon_scale
		draw_line(arm_start, arm_end, col_staff, 2.0 * s)
	# Orbe púrpura pulsante (radial gradient simulado con 3 círculos)
	var pulse: float = 0.6 + 0.4 * sin(_time * 4.0)
	draw_circle(orb_pos, 9.0 * weapon_scale, Color(0.45, 0.20, 0.65, 0.55))
	draw_circle(orb_pos, 6.5 * weapon_scale, Color(0.65, 0.35, 0.90, 0.85))
	draw_circle(orb_pos, 3.5 * weapon_scale * pulse, Color(0.95, 0.65, 1.0, 1.0))
	# Espiral en el orbe (2 puntos orbitando)
	for i in range(2):
		var spin: float = _time * 3.0 + float(i) * PI
		var sp_pos: Vector2 = orb_pos + Vector2(cos(spin), sin(spin)) * 4.0 * weapon_scale
		draw_circle(sp_pos, 1.2 * weapon_scale, Color(1.0, 0.85, 1.0, 0.95))
