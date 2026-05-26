extends Control
class_name XpToast

## Toast de XP ganada. Muestra "+N XP" en dorado cuando el player mata un enemy.
## Nodo "tonto": recibe datos del XpToastContainer y se anima a sí mismo.
## Patrón idéntico a MaterialToast — misma lógica de slide-in / stacking / fadeout.

# ─── Configuración ────────────────────────────────────────────────────────────

@export var count_font_size: int = 26
@export var label_font_size: int = 20
## Tiempo visible antes del fadeout.
@export var lifetime: float = 2.0
@export var fadeout_duration: float = 0.4
## Slide-in desde la izquierda (posición de entrada).
@export var slide_in_distance: float = 80.0
@export var slide_in_duration: float = 0.2

## Color dorado del XP.
const COLOR_XP := Color(1.0, 0.88, 0.18, 1.0)
const COLOR_BG := Color(0.05, 0.05, 0.1, 0.78)

# ─── Nodos internos ───────────────────────────────────────────────────────────

var _count_label: Label   # "+N XP"
var _tween: Tween = null
var _timer: float = 0.0
var _fading: bool = false

signal toast_finished(toast: XpToast)


# ─── Setup ────────────────────────────────────────────────────────────────────

## Llamar justo después de instanciar. Construye el árbol y arranca la animación.
func setup(amount: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_nodes(amount)
	_play_slide_in()


## Acumula XP en el toast existente (stacking) y resetea el lifetime.
func add_amount(extra: int) -> void:
	_timer = 0.0
	_fading = false
	modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var current: int = _parse_amount()
	_count_label.text = "+%d XP" % (current + extra)
	_play_pulse()


## Cantidad de XP actual parseada del label.
func get_amount() -> int:
	return _parse_amount()


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _fading:
		return
	_timer += delta
	if _timer >= lifetime:
		_start_fadeout()


# ─── Privados ─────────────────────────────────────────────────────────────────

func _build_nodes(amount: int) -> void:
	# Fondo semitransparente.
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	# HBox dentro del panel.
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)

	# Icono XP — pequeño rectángulo dorado como placeholder visual.
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.color = COLOR_XP
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Label "+N XP".
	_count_label = Label.new()
	_count_label.text = "+%d XP" % amount
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_font_size_override("font_size", count_font_size)
	_count_label.add_theme_color_override("font_color", COLOR_XP)
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_count_label.add_theme_constant_override("outline_size", 4)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	hbox.add_child(icon)
	hbox.add_child(_count_label)
	panel.add_child(hbox)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _parse_amount() -> int:
	if _count_label == null:
		return 0
	# Texto: "+N XP" → N
	var s: String = _count_label.text.lstrip("+").split(" ")[0]
	return s.to_int()


func _play_slide_in() -> void:
	# Entra desde la izquierda con fade-in.
	modulate.a = 0.0
	position.x -= slide_in_distance
	var target_x: float = position.x + slide_in_distance
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:x", target_x, slide_in_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(self, "modulate:a", 1.0, slide_in_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)


func _play_pulse() -> void:
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
