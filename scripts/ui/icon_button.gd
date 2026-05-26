extends "res://scripts/ui/touch_button.gd"
class_name IconButton

## Botón touch con icono procedural en lugar del label de texto.
## Hereda toda la lógica de touch/press/release de TouchButton.
## Setear icon_id en el .tscn para elegir qué dibujar.

## Identificador del icono a renderizar.
@export_enum("Mochila:bag", "Casco:helmet") var icon_id: String = "bag"

## Color del icono (por encima del círculo de fondo).
@export var icon_color: Color = Color(1.0, 1.0, 1.0, 0.95)


func _ready() -> void:
	super()
	# Ocultamos el Label heredado — el icono lo reemplaza.
	if _label != null:
		_label.visible = false


func _draw() -> void:
	# Primero dibuja el círculo de fondo del TouchButton base.
	super()
	# Luego superpone el icono.
	var center: Vector2 = size / 2.0
	match icon_id:
		"bag":
			_draw_bag(center)
		"helmet":
			_draw_helmet(center)


# ─── Iconos procedurales ──────────────────────────────────────────────────────

func _draw_bag(c: Vector2) -> void:
	# Mochila: cuerpo trapecio + tapa curva + 2 correas verticales.
	var s: float = visual_radius * 0.55  # escala del icono relativo al botón.
	# Cuerpo principal (trapecio aproximado por rect levemente curvado).
	var body := PackedVector2Array([
		c + Vector2(-s * 0.85, -s * 0.30),  # top-left
		c + Vector2( s * 0.85, -s * 0.30),  # top-right
		c + Vector2( s * 1.00,  s * 0.95),  # bot-right
		c + Vector2(-s * 1.00,  s * 0.95),  # bot-left
	])
	draw_colored_polygon(body, icon_color)
	# Tapa curva arriba.
	var flap := PackedVector2Array([
		c + Vector2(-s * 0.75, -s * 0.55),
		c + Vector2( s * 0.75, -s * 0.55),
		c + Vector2( s * 0.85, -s * 0.10),
		c + Vector2(-s * 0.85, -s * 0.10),
	])
	draw_colored_polygon(flap, icon_color.darkened(0.2))
	# Hebilla / botón central.
	draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.25), Vector2(s * 0.30, s * 0.20)),
		icon_color.darkened(0.4))
	# Correas verticales (asas).
	draw_rect(Rect2(c + Vector2(-s * 0.65, -s * 0.85), Vector2(s * 0.18, s * 0.35)),
		icon_color.darkened(0.3))
	draw_rect(Rect2(c + Vector2( s * 0.47, -s * 0.85), Vector2(s * 0.18, s * 0.35)),
		icon_color.darkened(0.3))


func _draw_helmet(c: Vector2) -> void:
	# Casco: domo superior + visera + cresta opcional.
	var s: float = visual_radius * 0.60
	# Domo (semicírculo): aproximado con polígono.
	var dome_points: PackedVector2Array = PackedVector2Array()
	var segments: int = 18
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerp(PI, 0.0, t)  # de izquierda a derecha por arriba.
		var p: Vector2 = c + Vector2(cos(angle) * s, sin(angle) * s * -0.95)
		dome_points.append(p)
	# Cerrar polígono con base inferior.
	dome_points.append(c + Vector2( s, s * 0.15))
	dome_points.append(c + Vector2(-s, s * 0.15))
	draw_colored_polygon(dome_points, icon_color)

	# Visera (rectángulo horizontal grueso debajo del domo).
	draw_rect(Rect2(c + Vector2(-s * 1.05, s * 0.10), Vector2(s * 2.10, s * 0.25)),
		icon_color.darkened(0.3))

	# Cresta vertical (línea más oscura arriba del domo).
	draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.95), Vector2(s * 0.16, s * 0.55)),
		icon_color.darkened(0.45))
