extends Control
class_name MaterialToast

## Un toast individual que muestra un material recogido en el HUD.
## Nodo "tonto": solo recibe datos del container y se anima a sí mismo.
## El container (MaterialToastContainer) es dueño del estado y del stacking.

# ─── Exports tunables ────────────────────────────────────────────────────────

## Tamaño del icono placeholder (px). Ajustable en Inspector.
@export var icon_size: int = 48
## Tamaño de fuente del count ("+N"). Ajustable en Inspector.
@export var count_font_size: int = 24
## Tamaño de fuente del nombre del material. Ajustable en Inspector.
@export var name_font_size: int = 22
## Tiempo visible antes de iniciar fadeout (segundos).
@export var lifetime: float = 2.5
## Duración del fadeout (segundos).
@export var fadeout_duration: float = 0.4
## Distancia del slide-in desde la derecha (px).
@export var slide_in_distance: float = 80.0
## Duración del slide-in + fadein (segundos).
@export var slide_in_duration: float = 0.2

# ─── Colores de rareza por placeholder ───────────────────────────────────────

const RARITY_COLORS: Array[Color] = [
	Color(0.7, 0.7, 0.7),   # R1 común — gris
	Color(0.4, 0.6, 0.9),   # R2 raro — azul
	Color(0.7, 0.4, 0.9),   # R3 épico — violeta
	Color(0.95, 0.75, 0.2), # R4 legendario — dorado
]

# ─── Nodos internos (asignados en setup()) ───────────────────────────────────

var _icon_rect: ColorRect      # placeholder de color hasta que llegue el sprite
var _count_label: Label        # "+N"
var _name_label: Label         # display_name del material

# ─── Estado ──────────────────────────────────────────────────────────────────

var _timer: float = 0.0        # acumulador desde el último reset
var _fading: bool = false      # true cuando está en la fase de fadeout
var _tween: Tween = null       # tween activo (slide-in o fadeout)

## Señal emitida cuando el toast termina su ciclo completo y se puede liberar.
signal toast_finished(toast: MaterialToast)


# ─── Construcción ────────────────────────────────────────────────────────────

## Llamar justo después de instanciar. Construye el árbol de nodos del toast.
func setup(material: MaterialData, count: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_nodes(material, count)
	_play_slide_in()


## Actualiza el count cuando llega más del mismo material dentro de la ventana.
## Resetea el lifetime y reproduce un pulso en el count.
func add_count(extra: int) -> void:
	_timer = 0.0
	_fading = false
	modulate.a = 1.0  # cancela cualquier fadeout en progreso
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var current_count: int = _parse_count()
	_count_label.text = "+%d" % (current_count + extra)
	_play_pulse_count()


## Cantidad actual parseada del label (para sumar al recibir más drops).
func get_count() -> int:
	return _parse_count()


# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _fading:
		return
	_timer += delta
	if _timer >= lifetime:
		_start_fadeout()


# ─── Privados ────────────────────────────────────────────────────────────────

func _build_nodes(material: MaterialData, count: int) -> void:
	# Panel de fondo semitransparente.
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.78)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	# Contenedor horizontal dentro del panel.
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)

	# Icono placeholder (ColorRect del color de rareza).
	_icon_rect = ColorRect.new()
	_icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon_rect.color = _rarity_color(material.rarity)
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Label "+N".
	_count_label = Label.new()
	_count_label.text = "+%d" % count
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_font_size_override("font_size", count_font_size)
	_count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_count_label.add_theme_constant_override("outline_size", 4)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Label nombre del material.
	_name_label = Label.new()
	_name_label.text = material.display_name if material.display_name != "" else str(material.id)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", name_font_size)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Armar árbol.
	hbox.add_child(_icon_rect)
	hbox.add_child(_count_label)
	hbox.add_child(_name_label)
	panel.add_child(hbox)
	add_child(panel)

	# El panel se expande para envolver el HBox (layout manual — CanvasLayer).
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _rarity_color(rarity: int) -> Color:
	if rarity >= 0 and rarity < RARITY_COLORS.size():
		return RARITY_COLORS[rarity]
	return RARITY_COLORS[0]


func _parse_count() -> int:
	# Parsea "+N" del label al int N.
	if _count_label == null:
		return 0
	var s: String = _count_label.text.lstrip("+")
	return s.to_int()


func _play_slide_in() -> void:
	# Empieza fuera de pantalla (a la derecha) con alpha 0.
	modulate.a = 0.0
	position.x += slide_in_distance
	var target_x: float = position.x - slide_in_distance
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:x", target_x, slide_in_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(self, "modulate:a", 1.0, slide_in_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)


func _play_pulse_count() -> void:
	# Pulso suave en el label de count al acumular más drops.
	if _count_label == null:
		return
	_count_label.pivot_offset = _count_label.size / 2.0
	_tween = create_tween()
	_tween.tween_property(_count_label, "scale", Vector2(1.3, 1.3), 0.1)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(_count_label, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)


func _start_fadeout() -> void:
	_fading = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fadeout_duration)
	_tween.tween_callback(_on_fadeout_done)


func _on_fadeout_done() -> void:
	toast_finished.emit(self)
	queue_free()
