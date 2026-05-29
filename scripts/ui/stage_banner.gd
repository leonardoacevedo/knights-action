extends CanvasLayer
class_name StageBanner

## Banner de transición entre etapas.
##
## Estados:
##   - `stage_pending` → muestra título + subtítulo + botón START (modal, espera input).
##   - `stage_started` → fade out rápido (el banner desaparece, empieza el combate).
##   - `stage_cleared` → mini-banner verde "ETAPA COMPLETADA" con fade auto.
##   - `run_completed` → banner dorado "VICTORIA" con fade más largo.
##
## El botón START llama a StageManager.request_combat_start(), que dispara
## stage_started y cierra el banner.

# ─── Configuración visual ─────────────────────────────────────────────────────

const CLEAR_FADE_IN: float = 0.30
const CLEAR_HOLD: float = 0.7
const CLEAR_FADE_OUT: float = 0.45

const COLOR_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_BOSS   := Color(1.0, 0.78, 0.30, 1.0)
const COLOR_CLEAR  := Color(0.50, 1.0, 0.55, 1.0)

const FONT_SIZE_TITLE_NORMAL := 36
const FONT_SIZE_TITLE_BOSS   := 46
const FONT_SIZE_SUBTITLE     := 18
const FONT_SIZE_INDEX        := 14

# ─── Nodos internos ───────────────────────────────────────────────────────────

var _root: Control
var _bg: ColorRect
var _index_label: Label
var _title_label: Label
var _subtitle_label: Label
var _hint_label: Label
var _start_button: Button


func _ready() -> void:
	layer = 25  # encima del HUD (10) y del inventario (20).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_set_alpha(0.0)
	# Conectar a StageManager.
	StageManager.stage_pending.connect(_on_stage_pending)
	StageManager.stage_started.connect(_on_stage_started)
	StageManager.stage_cleared.connect(_on_stage_cleared)
	StageManager.run_completed.connect(_on_run_completed)


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "BannerRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Fondo semitransparente (banda horizontal centrada vertical).
	_bg = ColorRect.new()
	_bg.name = "Band"
	_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	_bg.anchor_left = 0.0
	_bg.anchor_right = 1.0
	_bg.anchor_top = 0.22
	_bg.anchor_bottom = 0.66
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	# VBox centrado dentro del root.
	var vbox := VBoxContainer.new()
	vbox.name = "TextVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vbox)

	_index_label = _make_label("", FONT_SIZE_INDEX, Color(0.85, 0.85, 1.0, 0.85))
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_index_label)

	_title_label = _make_label("", FONT_SIZE_TITLE_NORMAL, COLOR_NORMAL)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_subtitle_label = _make_label("", FONT_SIZE_SUBTITLE, Color(0.95, 0.95, 0.95, 0.9))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_subtitle_label)

	# Hint: pequeña indicación "abrí inventario para equipar antes".
	_hint_label = _make_label("", FONT_SIZE_INDEX, Color(0.85, 0.95, 0.85, 0.8))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# Botón START (centrado).
	var btn_holder := HBoxContainer.new()
	btn_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_holder)

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "▶  EMPEZAR ETAPA"
	_start_button.custom_minimum_size = Vector2(280, 64)
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_start_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_start_button.add_theme_constant_override("outline_size", 5)
	_start_button.process_mode = Node.PROCESS_MODE_ALWAYS

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.18, 0.45, 0.22, 0.95)
	style_normal.border_color = Color(0.30, 0.70, 0.35, 1.0)
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_left = 10
	style_normal.corner_radius_bottom_right = 10
	_start_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.25, 0.60, 0.30, 1.0)
	_start_button.add_theme_stylebox_override("hover", style_hover)
	_start_button.add_theme_stylebox_override("pressed", style_hover)

	_start_button.pressed.connect(_on_start_pressed)
	btn_holder.add_child(_start_button)
	_start_button.visible = false


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# ─── Hooks de StageManager ────────────────────────────────────────────────────

func _on_stage_pending(data: StageData, index: int) -> void:
	if data == null:
		return
	_index_label.text = "ETAPA %d / %d" % [index + 1, StageManager.total_stages()]
	_title_label.text = data.display_name.to_upper()
	_subtitle_label.text = data.subtitle
	_hint_label.text = "Equipá desde la mochila (tecla I) antes de empezar."

	# Mini-boss tiene prioridad de label sobre boss: si un stage marcara ambos flags
	# en true, debe ganar "MINI-BOSS". Por eso se chequea is_mini_boss primero.
	if data.is_mini_boss:
		# Mini-boss tier (R3 elite intermedio). Tamaño + color entre normal y boss.
		_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE_BOSS - 8)
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
		_index_label.text = "MINI-BOSS — ETAPA %d / %d" % [index + 1, StageManager.total_stages()]
	elif data.is_boss:
		_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE_BOSS)
		_title_label.add_theme_color_override("font_color", COLOR_BOSS)
		_index_label.text = "BOSS — ETAPA %d / %d" % [index + 1, StageManager.total_stages()]
	else:
		_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE_NORMAL)
		_title_label.add_theme_color_override("font_color", COLOR_NORMAL)

	# Mostrar botón START y mantener banner visible hasta que se apriete.
	_start_button.visible = true
	_show_full()


func _on_stage_started(_data: StageData, _index: int) -> void:
	# Combate empezó: ocultar botón y fade out rápido.
	_start_button.visible = false
	_hint_label.text = ""
	_fade_out(0.35)


func _on_stage_cleared(_index: int) -> void:
	_start_button.visible = false
	_index_label.text = ""
	_title_label.text = "ETAPA COMPLETADA"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE_NORMAL)
	_title_label.add_theme_color_override("font_color", COLOR_CLEAR)
	_subtitle_label.text = ""
	_hint_label.text = ""
	_play_quick_banner(CLEAR_FADE_IN, CLEAR_HOLD, CLEAR_FADE_OUT)


func _on_run_completed() -> void:
	_start_button.visible = false
	_index_label.text = "VICTORIA"
	_title_label.text = "ZONA COMPLETADA"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE_BOSS)
	_title_label.add_theme_color_override("font_color", COLOR_BOSS)
	_subtitle_label.text = "Más pruebas te esperan."
	_hint_label.text = ""
	_play_quick_banner(0.6, 3.0, 0.8)


# ─── Botón START ──────────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	StageManager.request_combat_start()


# ─── Animación ────────────────────────────────────────────────────────────────

func _show_full() -> void:
	# Mostrar banner instantáneo y MANTENERLO (sin fade out automático).
	# Usado para pending — se ocultará cuando el jugador apriete START.
	var tween: Tween = create_tween()
	tween.tween_method(_set_alpha, 0.0, 1.0, 0.45)


func _fade_out(seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_alpha, 1.0, 0.0, seconds)


func _play_quick_banner(fade_in: float, hold: float, fade_out: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_alpha, 0.0, 1.0, fade_in)
	tween.tween_interval(hold)
	tween.tween_method(_set_alpha, 1.0, 0.0, fade_out)


func _set_alpha(a: float) -> void:
	_root.modulate = Color(1, 1, 1, a)
