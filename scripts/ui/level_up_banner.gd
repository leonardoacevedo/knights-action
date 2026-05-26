extends Control
class_name LevelUpBanner

## Banner central de "¡NIVEL N!" que aparece al subir de nivel.
##
## NO bloquea input ni pausa el juego — mouse_filter IGNORE en todo.
## Animación: scale overshoot (0.5 → 1.1 → 1.0) + permanece 1.5s + fade 0.5s.
## Pilar #4: feedback visual sin interrumpir el combate.

const COLOR_LEVEL := Color(1.0, 0.88, 0.18, 1.0)   # dorado
const COLOR_SUB   := Color(1.0, 1.0, 1.0, 1.0)      # blanco
const COLOR_BG    := Color(0.0, 0.0, 0.0, 0.65)

const HOLD_DURATION: float = 1.5
const FADE_DURATION: float = 0.5

# ─── Nodos internos ───────────────────────────────────────────────────────────

var _root: Control
var _bg: ColorRect
var _level_label: Label
var _sub_label: Label
var _tween: Tween = null


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	modulate.a = 0.0
	PlayerProgression.level_up.connect(_on_level_up)


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	# Raíz del banner: ocupa todo el control padre.
	_root = Control.new()
	_root.name = "BannerRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Banda de fondo centrada vertical — misma altura que stage_banner.
	_bg = ColorRect.new()
	_bg.name = "Band"
	_bg.color = COLOR_BG
	_bg.anchor_left = 0.0
	_bg.anchor_right = 1.0
	_bg.anchor_top = 0.30
	_bg.anchor_bottom = 0.72
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	# VBox centrado para los textos.
	var vbox := VBoxContainer.new()
	vbox.name = "TextVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vbox)

	# "¡NIVEL N!" — grande, dorado.
	_level_label = _make_label("¡NIVEL 1!", 52, COLOR_LEVEL)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_level_label)

	# "+1 punto de habilidad" — más pequeño, blanco.
	_sub_label = _make_label("+1 punto de habilidad", 22, COLOR_SUB)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_sub_label)


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 6)
	return lbl


# ─── Handler ─────────────────────────────────────────────────────────────────

func _on_level_up(new_level: int, points_awarded: int) -> void:
	_level_label.text = "¡NIVEL %d!" % new_level
	if points_awarded == 1:
		_sub_label.text = "+1 punto de habilidad"
	else:
		_sub_label.text = "+%d puntos de habilidad" % points_awarded

	_play_banner()


# ─── Animación ────────────────────────────────────────────────────────────────

func _play_banner() -> void:
	# Matar tween anterior si había un level-up en cadena.
	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Reset de estado para que el overshoot parta de 0.5 siempre.
	modulate.a = 1.0
	_root.scale = Vector2(0.5, 0.5)
	_root.pivot_offset = _root.size / 2.0

	_tween = create_tween()
	# Fase 1: scale overshoot 0.5 → 1.1 en 0.12s.
	_tween.tween_property(_root, "scale", Vector2(1.1, 1.1), 0.12)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	# Fase 2: scale overshoot 1.1 → 1.0 en 0.10s.
	_tween.tween_property(_root, "scale", Vector2(1.0, 1.0), 0.10)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
	# Fase 3: hold.
	_tween.tween_interval(HOLD_DURATION)
	# Fase 4: fade out.
	_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUINT)
