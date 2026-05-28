extends StickFigure
class_name EnemyFigure

## Render para mobs normales (R1/R2/R3). Mantiene el body skeleton + armas
## heredados de StickFigure, pero dibuja accesorios temáticos por clase ENCIMA
## (casco, hombreras, capucha+carcaj, sombrero de mago) para distinguir
## visualmente cada tipo sin tener que crear sprites IA.
##
## La rarity (R1/R2/R3) ya tiene tint+scale aplicado por enemy.gd → no tocamos.

enum ClassStyle { NONE, MELEE, TANK, ARCHER, MAGE }

@export var class_style: ClassStyle = ClassStyle.NONE
## Tinte secundario para metales/cuero (más oscuro que body_color).
@export var accent_color: Color = Color(0.18, 0.16, 0.20, 1.0)
## Color del cinturón/strap (cuero típico).
@export var leather_color: Color = Color(0.32, 0.20, 0.10, 1.0)


func _draw() -> void:
	# Base: skeleton + armas + telegraph overlay
	super._draw()
	if state == State.DEAD:
		return

	# Recalcular posiciones igual que StickFigure._draw para anclar accesorios
	var bob: float = 0.0
	if state == State.IDLE:
		bob = sin(_time * 4.0) * 1.5
	elif state == State.WALK:
		bob = sin(_time * 12.0) * 2.0
	var crouch: float = 4.0 if state == State.BLOCK else 0.0
	var pelvis: Vector2 = Vector2(0, -leg_length + bob + crouch)
	var shoulders: Vector2 = Vector2(0, pelvis.y - torso_length)
	var head_center: Vector2 = Vector2(0, shoulders.y - head_radius - 2.0)

	# Hurt flash afecta también accesorios para coherencia
	var hurt_mix: float = clamp(_hurt_flash * 4.0, 0.0, 1.0)

	match class_style:
		ClassStyle.MELEE:
			_draw_melee_kit(head_center, shoulders, pelvis, hurt_mix)
		ClassStyle.TANK:
			_draw_tank_kit(head_center, shoulders, pelvis, hurt_mix)
		ClassStyle.ARCHER:
			_draw_archer_kit(head_center, shoulders, pelvis, hurt_mix)
		ClassStyle.MAGE:
			_draw_mage_kit(head_center, shoulders, hurt_mix)


# ─── Accesorios por clase ────────────────────────────────────────────────────

## MELEE: casco con visor + chestplate stripe + cinturón.
## Fantasía: soldado raso, espadachín ligero.
func _draw_melee_kit(head_center: Vector2, shoulders: Vector2, pelvis: Vector2, hurt: float) -> void:
	var col: Color = accent_color.lerp(Color.RED, hurt * 0.6)
	# Casco: media-luna superior cubriendo la mitad de arriba de la cabeza
	var helm_pts: PackedVector2Array = PackedVector2Array()
	var segments: int = 14
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var ang: float = PI + t * PI  # PI a 2*PI = mitad superior
		helm_pts.append(head_center + Vector2(cos(ang) * head_radius * 1.05,
			sin(ang) * head_radius * 1.05))
	# Cerrar polygon con línea horizontal a la altura del centro
	helm_pts.append(head_center + Vector2(head_radius * 1.05, 0))
	helm_pts.append(head_center + Vector2(-head_radius * 1.05, 0))
	draw_colored_polygon(helm_pts, col)
	# Visor: banda horizontal oscura justo abajo del casco
	draw_rect(Rect2(head_center.x - head_radius, head_center.y - 2.0,
		head_radius * 2.0, 3.0), Color(0.05, 0.05, 0.08, 1.0), true)
	# Pequeño rojo (ojo)
	draw_circle(head_center + Vector2(facing * head_radius * 0.4, -0.5),
		1.3, Color(1.0, 0.4, 0.2, 1.0))
	# Chestplate: trapezoide accent en el torso
	var chest_top: Vector2 = shoulders + Vector2(0, 3.0)
	var chest_bot: Vector2 = pelvis + Vector2(0, -4.0)
	var ct_w: float = 6.0
	var cb_w: float = 4.0
	var chest_poly: PackedVector2Array = PackedVector2Array([
		chest_top + Vector2(-ct_w, 0),
		chest_top + Vector2(ct_w, 0),
		chest_bot + Vector2(cb_w, 0),
		chest_bot + Vector2(-cb_w, 0),
	])
	draw_colored_polygon(chest_poly, col)
	# Cinturón
	draw_rect(Rect2(pelvis.x - 7.0, pelvis.y - 3.0, 14.0, 2.5), leather_color, true)


## TANK: yelmo con cresta + hombreras grandes + cinturón ancho. Cuerpo robusto.
## Fantasía: caballero pesado, escudero del frente.
func _draw_tank_kit(head_center: Vector2, shoulders: Vector2, pelvis: Vector2, hurt: float) -> void:
	var col: Color = accent_color.lerp(Color.RED, hurt * 0.6)
	# Hombreras: 2 óvalos grandes sobre los hombros
	var pad_rx: float = 9.0
	var pad_ry: float = 5.5
	_draw_oval(shoulders + Vector2(-7.0, -1.0), pad_rx, pad_ry, col)
	_draw_oval(shoulders + Vector2(7.0, -1.0), pad_rx, pad_ry, col)
	# Yelmo: óvalo cubriendo toda la cabeza (más grande que el círculo base)
	_draw_oval(head_center, head_radius * 1.25, head_radius * 1.35, col)
	# Visor T (vertical + horizontal banda)
	draw_rect(Rect2(head_center.x - 1.2, head_center.y - head_radius * 0.8,
		2.4, head_radius * 1.0), Color(0.05, 0.05, 0.08, 1.0), true)
	draw_rect(Rect2(head_center.x - head_radius * 0.9, head_center.y - 1.5,
		head_radius * 1.8, 2.5), Color(0.05, 0.05, 0.08, 1.0), true)
	# Cresta arriba del yelmo (penacho)
	var crest_top: Vector2 = head_center + Vector2(0, -head_radius * 1.7)
	var crest_l: Vector2 = head_center + Vector2(-3.0, -head_radius * 1.3)
	var crest_r: Vector2 = head_center + Vector2(3.0, -head_radius * 1.3)
	draw_colored_polygon(PackedVector2Array([crest_l, crest_top, crest_r]), leather_color)
	# Chestplate más ancho que melee
	var ct_w: float = 7.5
	var cb_w: float = 6.0
	var chest_top: Vector2 = shoulders + Vector2(0, 3.0)
	var chest_bot: Vector2 = pelvis + Vector2(0, -3.0)
	var chest_poly: PackedVector2Array = PackedVector2Array([
		chest_top + Vector2(-ct_w, 0),
		chest_top + Vector2(ct_w, 0),
		chest_bot + Vector2(cb_w, 0),
		chest_bot + Vector2(-cb_w, 0),
	])
	draw_colored_polygon(chest_poly, col)
	# Cinturón ancho con hebilla
	draw_rect(Rect2(pelvis.x - 8.0, pelvis.y - 3.5, 16.0, 3.5), leather_color, true)
	draw_rect(Rect2(pelvis.x - 1.8, pelvis.y - 3.0, 3.6, 2.5),
		Color(0.85, 0.70, 0.25, 1.0), true)


## ARCHER: capucha + carcaj con 3 flechas sobre la espalda.
## Fantasía: ranger / cazador ligero.
func _draw_archer_kit(head_center: Vector2, shoulders: Vector2, pelvis: Vector2, hurt: float) -> void:
	var col: Color = accent_color.lerp(Color.RED, hurt * 0.6)
	# Capucha: trapezoide que cae sobre cabeza+hombros
	var hood_top: Vector2 = head_center + Vector2(0, -head_radius * 1.0)
	var hood_top_w: float = head_radius * 0.45
	var hood_bot_w: float = head_radius * 1.25
	var hood_bot_y: float = head_center.y + head_radius * 0.45
	var hood_poly: PackedVector2Array = PackedVector2Array([
		hood_top + Vector2(-hood_top_w, 2.0),
		hood_top + Vector2(hood_top_w, 2.0),
		Vector2(head_center.x + hood_bot_w, hood_bot_y),
		Vector2(head_center.x + hood_bot_w * 0.5, hood_bot_y + head_radius * 0.35),
		Vector2(head_center.x - hood_bot_w * 0.5, hood_bot_y + head_radius * 0.35),
		Vector2(head_center.x - hood_bot_w, hood_bot_y),
	])
	draw_colored_polygon(hood_poly, col)
	# Sombra interior (ojos en oscuro)
	var face_shadow: PackedVector2Array = PackedVector2Array([
		head_center + Vector2(-head_radius * 0.55, -head_radius * 0.3),
		head_center + Vector2(head_radius * 0.55, -head_radius * 0.3),
		head_center + Vector2(head_radius * 0.4, head_radius * 0.4),
		head_center + Vector2(-head_radius * 0.4, head_radius * 0.4),
	])
	draw_colored_polygon(face_shadow, Color(0.05, 0.05, 0.08, 0.95))
	# Ojo brillante apuntando al facing
	draw_circle(head_center + Vector2(facing * head_radius * 0.3, head_radius * 0.05),
		1.5, Color(0.85, 1.0, 0.4, 1.0))
	# Carcaj sobre la espalda (rectángulo inclinado, atrás del facing)
	var quiver_x: float = -facing * 7.0
	var quiver_poly: PackedVector2Array = PackedVector2Array([
		shoulders + Vector2(quiver_x - 3.0, -2.0),
		shoulders + Vector2(quiver_x + 3.0, -2.0),
		shoulders + Vector2(quiver_x + 3.5, 12.0),
		shoulders + Vector2(quiver_x - 3.5, 12.0),
	])
	draw_colored_polygon(quiver_poly, leather_color)
	# 3 flechas sobresaliendo del carcaj
	for i in range(3):
		var ax: float = quiver_x + (i - 1) * 1.8
		var feather_top: Vector2 = shoulders + Vector2(ax, -10.0)
		var shaft_bot: Vector2 = shoulders + Vector2(ax, -2.5)
		draw_line(feather_top, shaft_bot, Color(0.85, 0.7, 0.45, 1.0), 1.0)
		# Plumas (puntito rojo arriba)
		draw_circle(feather_top, 1.3, Color(0.85, 0.25, 0.20, 1.0))


## MAGE: sombrero cónico con ala + cinturón con frasco.
## Fantasía: hechicero/druida.
func _draw_mage_kit(head_center: Vector2, shoulders: Vector2, hurt: float) -> void:
	var hat_col: Color = accent_color.lerp(Color.RED, hurt * 0.6)
	# Ala del sombrero: óvalo achatado encima de la cabeza
	var brim_y: float = head_center.y - head_radius * 0.9
	_draw_oval(Vector2(head_center.x, brim_y), head_radius * 1.5, head_radius * 0.32, hat_col)
	# Cono del sombrero: triángulo inclinado levemente hacia atrás del facing
	var lean: float = -facing * 2.0
	var hat_tip: Vector2 = Vector2(head_center.x + lean,
		brim_y - head_radius * 1.9)
	var hat_base_l: Vector2 = Vector2(head_center.x - head_radius * 0.85, brim_y - 1.0)
	var hat_base_r: Vector2 = Vector2(head_center.x + head_radius * 0.85, brim_y - 1.0)
	draw_colored_polygon(PackedVector2Array([hat_base_l, hat_tip, hat_base_r]), hat_col)
	# Estrella/gema en el frente del cono
	var star_pos: Vector2 = hat_tip.lerp(Vector2(head_center.x, brim_y), 0.5) + \
		Vector2(facing * 2.0, 0)
	draw_circle(star_pos, 2.0, Color(0.95, 0.85, 0.30, 1.0))
	# Banda dorada en el borde del ala
	draw_rect(Rect2(head_center.x - head_radius * 1.5, brim_y - 0.5,
		head_radius * 3.0, 1.2), Color(0.85, 0.70, 0.25, 0.9), true)
	# Barba/melena bajo la cabeza (sombra/línea corta)
	draw_line(head_center + Vector2(-head_radius * 0.5, head_radius * 0.6),
		head_center + Vector2(head_radius * 0.5, head_radius * 0.6),
		Color(0.85, 0.85, 0.95, 0.85), 1.5)
	# Frasco/colgante en el cinturón (justo abajo de torso, ~mid de shoulders→pelvis)
	var amulet_y: float = shoulders.y + 18.0
	draw_circle(Vector2(0, amulet_y), 2.5, Color(0.50, 0.85, 1.0, 0.9))
	draw_line(shoulders + Vector2(0, 2.0), Vector2(0, amulet_y - 1.0),
		Color(0.85, 0.70, 0.25, 0.8), 1.0)


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _draw_oval(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var segments: int = 16
	for i in range(segments):
		var ang: float = i * TAU / float(segments)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)
