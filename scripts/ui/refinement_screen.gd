extends CanvasLayer
class_name RefinementScreen

## Pantalla de Refinamiento +1 a +10. GDD §5.6 / Pilar #2.
##
## Muestra al jugador — ANTES de confirmar — la probabilidad de éxito,
## la penalización en caso de fallo, y el coste en materiales.
## Nada se esconde. Si la UI oculta datos, viola el Pilar #2.
##
## Flujo:
##   Abrir → seleccionar item → ver datos → (opcional) activar Pergamino →
##   confirmar → animación suspenso (1.5-2s) → reveal resultado → actualizar.
##
## Trigger de apertura: Opción A — el InventoryScreen expone open_refinement(item).
## Fallback de testing: tecla R (sin item seleccionado, abre con primer item refinable).
##
## Conexiones autoload:
##   UpgradeManager — intentos y signals de resultado.
##   InventorySystem — consulta materiales y lista de items.

# ─── Colores compartidos con InventoryScreen ─────────────────────────────────

const COLOR_R1 := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_R2 := Color(0.3, 0.6, 1.0, 0.7)
const COLOR_R3 := Color(0.7, 0.3, 0.9, 0.8)
const COLOR_R4 := Color(1.0, 0.75, 0.2, 0.9)

const COLOR_PANEL_BG   := Color(0.07, 0.07, 0.1,  0.97)
const COLOR_HEADER_BG  := Color(0.05, 0.05, 0.08, 1.0)
const COLOR_SECTION_BG := Color(0.1,  0.1,  0.15, 0.8)
const COLOR_ITEM_BG    := Color(0.1,  0.1,  0.16, 0.9)
const COLOR_ITEM_SEL   := Color(0.15, 0.15, 0.25, 0.95)

# Colores de probabilidad por rangos.
const COLOR_CHANCE_HIGH   := Color(0.3, 0.9, 0.4, 1.0)   # 100-70%  → verde
const COLOR_CHANCE_MID    := Color(0.95, 0.8, 0.2, 1.0)  # 69-30%   → amarillo
const COLOR_CHANCE_LOW    := Color(0.95, 0.35, 0.2, 1.0) # <30%     → rojo

# Colores de resultado en la animación.
const COLOR_RESULT_SUCCESS  := Color(1.0,  0.88, 0.2,  1.0) # dorado
const COLOR_RESULT_FAIL_MAT := Color(0.55, 0.55, 0.6,  1.0) # gris
const COLOR_RESULT_FAIL_LVL := Color(0.9,  0.2,  0.2,  1.0) # rojo
const COLOR_RESULT_SCROLL   := Color(0.4,  0.65, 1.0,  1.0) # azul-dorado

# Fuentes
const FONT_TITLE    := 22
const FONT_SECTION  := 15
const FONT_BODY     := 14
const FONT_SMALL    := 12
const FONT_CHANCE   := 32  # número grande de probabilidad — Pilar #2
const FONT_LEVEL    := 28  # "+5 → +6"

# Duración de la animación de suspenso antes del reveal.
const ANIM_SUSPENSE_DURATION := 1.6  # segundos
# Duración del flash de resultado.
const ANIM_FLASH_DURATION    := 0.35

# ─── Nodos construidos proceduralmente ───────────────────────────────────────

var _panel: PanelContainer
var _close_btn: Button

# Lista de items (columna izquierda o scroll inferior)
var _item_list_vbox: VBoxContainer
var _item_rows: Dictionary = {}  # ItemData → Control (fila)

# Panel central de preview del item seleccionado
var _preview_name: Label
var _preview_level_label: Label       # "+5  →  +6"
var _preview_stat_label: Label        # "ATK: 75  →  80"
var _preview_rarity_bar: ColorRect    # franja de rareza izquierda

# Display de probabilidad
var _chance_bar_fg: ColorRect
var _chance_bar_bg: ColorRect
var _chance_pct_label: Label          # "50%"
var _chance_bar_container: Control

# Display de penalización
var _penalty_label: Label

# Display de coste
var _stones_label: Label
var _stones_status: Label             # verde ok / rojo falta

# Toggle pergamino
var _scroll_toggle_root: Control
var _scroll_checkbox: CheckBox
var _scroll_count_label: Label

# Fila de acción
var _attempt_btn: Button
var _attempt_blocked_label: Label     # razón por la que está bloqueado

# Overlay de animación (fullscreen sobre el panel)
var _anim_overlay: ColorRect
var _anim_label: Label
var _anim_sub_label: Label

# Contador de intentos en la sesión — "anti-rage" (Pilar #2).
var _session_attempts: int = 0
var _session_label: Label

# ─── Estado ──────────────────────────────────────────────────────────────────

var _selected_item: ItemData = null
var _is_open: bool = false
var _is_animating: bool = false
var _use_scroll: bool = false


# ─── Ciclo de vida ───────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 25  # sobre InventoryScreen (layer 20) y HUD (layer 10).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_build_ui()
	_connect_signals()


# ─── API pública ─────────────────────────────────────────────────────────────

## Abre la pantalla. Si item es no-null se preselecciona.
## Llamado desde InventoryScreen cuando el jugador pulsa "Refinar".
func open(item: ItemData = null) -> void:
	if _is_animating:
		return
	_is_open = true
	_session_attempts = 0
	visible = true
	get_tree().paused = true

	_refresh_item_list()

	if item != null and UpgradeManager.can_refine(item):
		_select_item(item)
	elif not _item_rows.is_empty():
		# Preseleccionar el primero disponible.
		var first: ItemData = _item_rows.keys()[0]
		_select_item(first)
	else:
		_select_item(null)


func close() -> void:
	if _is_animating:
		return
	_is_open = false
	visible = false
	get_tree().paused = false


func toggle(item: ItemData = null) -> void:
	if _is_open:
		close()
	else:
		open(item)


# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event is InputEventKey and event.is_echo():
		return

	# Tecla R — solo para testing rápido. TODO: remover o mover a debug build.
	if event is InputEventKey and event.physical_keycode == KEY_R:
		if not _is_open:
			# Buscar primer item refinable para testing.
			var all: Array[ItemData] = InventorySystem.get_all()
			var target: ItemData = null
			for it in all:
				if UpgradeManager.can_refine(it):
					target = it
					break
			open(target)
			get_viewport().set_input_as_handled()
		elif _is_open and not _is_animating:
			close()
			get_viewport().set_input_as_handled()

	# Escape cierra.
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		if _is_open and not _is_animating:
			close()
			get_viewport().set_input_as_handled()


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo oscuro bloqueante (captura todos los toques fuera del panel).
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		# Tap en el fondo cierra la pantalla (UX natural en mobile).
		if ev is InputEventScreenTouch and ev.pressed:
			close()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(bg)

	# Contenedor raíz (para control de anchors).
	var root_ctrl := Control.new()
	root_ctrl.name = "RootControl"
	root_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# Panel principal — ocupa ~88% ancho, ~92% alto (seguro en notch / punch-hole).
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.anchor_left   = 0.06
	_panel.anchor_right  = 0.94
	_panel.anchor_top    = 0.04
	_panel.anchor_bottom = 0.96
	_panel.offset_left   = 0.0
	_panel.offset_right  = 0.0
	_panel.offset_top    = 0.0
	_panel.offset_bottom = 0.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.corner_radius_top_left     = 14
	panel_style.corner_radius_top_right    = 14
	panel_style.corner_radius_bottom_left  = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.border_color = Color(0.35, 0.35, 0.55, 0.7)
	panel_style.border_width_top    = 1
	panel_style.border_width_right  = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left   = 1
	_panel.add_theme_stylebox_override("panel", panel_style)
	root_ctrl.add_child(_panel)

	# Layout vertical principal dentro del panel.
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(main_vbox)

	_build_header(main_vbox)
	_build_body(main_vbox)
	_build_anim_overlay(root_ctrl)


func _build_header(parent: Control) -> void:
	var header := ColorRect.new()
	header.name = "Header"
	header.color = COLOR_HEADER_BG
	header.custom_minimum_size = Vector2(0, 56)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	hbox.offset_left   = 16.0
	hbox.offset_right  = 0.0
	hbox.offset_top    = 0.0
	hbox.offset_bottom = 0.0
	header.add_child(hbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "REFINAMIENTO"
	title_lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(title_lbl)

	# Sesión de intentos — anti-rage Pilar #2.
	_session_label = Label.new()
	_session_label.name = "SessionLabel"
	_session_label.text = ""
	_session_label.add_theme_font_size_override("font_size", FONT_SMALL)
	_session_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.75))
	_session_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_session_label.add_theme_constant_override("outline_size", 2)
	_session_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_session_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_session_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_session_label)

	# Botón cerrar — hit area 64×56 dp.
	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(64, 56)
	_close_btn.add_theme_font_size_override("font_size", 20)
	_close_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	_close_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_close_btn.add_theme_constant_override("outline_size", 3)
	_close_btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var close_normal := StyleBoxFlat.new()
	close_normal.bg_color = Color(0.2, 0.05, 0.05, 0.0)
	_close_btn.add_theme_stylebox_override("normal", close_normal)
	var close_press := StyleBoxFlat.new()
	close_press.bg_color = Color(0.4, 0.1, 0.1, 0.7)
	close_press.corner_radius_top_right    = 14
	close_press.corner_radius_bottom_right = 14
	_close_btn.add_theme_stylebox_override("hover",   close_press)
	_close_btn.add_theme_stylebox_override("pressed", close_press)
	_close_btn.pressed.connect(close)
	hbox.add_child(_close_btn)

	parent.add_child(header)

	# Separador.
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_body(parent: Control) -> void:
	# Layout horizontal: lista items (izquierda, fija) | central (scroll) | barra separadora invisible.
	var body_hbox := HBoxContainer.new()
	body_hbox.name = "BodyHBox"
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 0)
	parent.add_child(body_hbox)

	_build_item_list_column(body_hbox)

	# Separador vertical.
	var vsep := ColorRect.new()
	vsep.color = Color(0.3, 0.3, 0.5, 0.3)
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(vsep)

	_build_central_column(body_hbox)


func _build_item_list_column(parent: Control) -> void:
	# Columna izquierda — items refinables del inventario.
	# Ancho fijo ~40% del panel para que el central tenga espacio suficiente.
	var col := VBoxContainer.new()
	col.name = "ItemListColumn"
	col.custom_minimum_size = Vector2(170, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	var hdr := _make_section_header("TUS ITEMS")
	col.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.name = "ItemListScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_item_list_vbox = VBoxContainer.new()
	_item_list_vbox.name = "ItemListVBox"
	_item_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_item_list_vbox)


func _build_central_column(parent: Control) -> void:
	# Columna central scrollable — todos los datos del item seleccionado.
	var scroll := ScrollContainer.new()
	scroll.name = "CentralScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var col := VBoxContainer.new()
	col.name = "CentralColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	scroll.add_child(col)

	_build_item_preview(col)
	_build_chance_display(col)
	_build_penalty_display(col)
	_build_cost_display(col)
	_build_scroll_toggle(col)
	_build_action_row(col)


func _build_item_preview(parent: Control) -> void:
	var hdr := _make_section_header("ITEM SELECCIONADO")
	parent.add_child(hdr)

	# Panel de preview.
	var preview := ColorRect.new()
	preview.name = "ItemPreview"
	preview.color = COLOR_ITEM_BG
	preview.custom_minimum_size = Vector2(0, 110)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(preview)

	# Franja de rareza izquierda (coloreada al seleccionar item).
	_preview_rarity_bar = ColorRect.new()
	_preview_rarity_bar.name = "RarityBar"
	_preview_rarity_bar.color = Color(0.5, 0.5, 0.5, 0.5)
	_preview_rarity_bar.anchor_left   = 0.0
	_preview_rarity_bar.anchor_right  = 0.0
	_preview_rarity_bar.anchor_top    = 0.0
	_preview_rarity_bar.anchor_bottom = 1.0
	_preview_rarity_bar.offset_right  = 5.0
	_preview_rarity_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_preview_rarity_bar)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 16.0
	vbox.offset_top    = 10.0
	vbox.offset_right  = -12.0
	vbox.offset_bottom = -10.0
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(vbox)

	_preview_name = _make_label("(seleccioná un item)", FONT_SECTION, Color(0.8, 0.8, 0.85, 0.8))
	_preview_name.clip_text = true
	vbox.add_child(_preview_name)

	_preview_level_label = _make_label("", FONT_LEVEL, Color(1, 1, 1, 1))
	_preview_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_preview_level_label.add_theme_constant_override("outline_size", 5)
	vbox.add_child(_preview_level_label)

	_preview_stat_label = _make_label("", FONT_BODY, Color(0.75, 0.9, 1.0, 0.9))
	vbox.add_child(_preview_stat_label)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_chance_display(parent: Control) -> void:
	# Sección probabilidad — dato más importante, Pilar #2.
	var hdr := _make_section_header("PROBABILIDAD DE EXITO")
	parent.add_child(hdr)

	var container := ColorRect.new()
	container.name = "ChanceContainer"
	container.color = Color(0.08, 0.08, 0.13, 0.9)
	container.custom_minimum_size = Vector2(0, 80)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left   = 14.0
	inner.offset_top    = 10.0
	inner.offset_right  = -14.0
	inner.offset_bottom = -10.0
	inner.add_theme_constant_override("separation", 12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(inner)

	# Número grande de probabilidad.
	_chance_pct_label = Label.new()
	_chance_pct_label.name = "ChancePercent"
	_chance_pct_label.text = "—"
	_chance_pct_label.add_theme_font_size_override("font_size", FONT_CHANCE)
	_chance_pct_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.7))
	_chance_pct_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_chance_pct_label.add_theme_constant_override("outline_size", 5)
	_chance_pct_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chance_pct_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chance_pct_label.custom_minimum_size = Vector2(90, 0)
	_chance_pct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_chance_pct_label)

	# Barra horizontal de probabilidad.
	var bar_vbox := VBoxContainer.new()
	bar_vbox.name = "BarVBox"
	bar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	bar_vbox.add_theme_constant_override("separation", 6)
	bar_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bar_vbox)

	var bar_label := _make_label("chance de subir nivel", FONT_SMALL, Color(0.65, 0.7, 0.85, 0.85))
	bar_vbox.add_child(bar_label)

	# Fondo de la barra.
	_chance_bar_bg = ColorRect.new()
	_chance_bar_bg.name = "ChanceBarBG"
	_chance_bar_bg.color = Color(0.15, 0.15, 0.2, 1.0)
	_chance_bar_bg.custom_minimum_size = Vector2(0, 18)
	_chance_bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chance_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_vbox.add_child(_chance_bar_bg)

	# Relleno de la barra (se escala con clip_contents del padre).
	_chance_bar_fg = ColorRect.new()
	_chance_bar_fg.name = "ChanceBarFG"
	_chance_bar_fg.color = COLOR_CHANCE_HIGH
	_chance_bar_fg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chance_bar_fg.anchor_right = 0.0  # comienza en 0, se actualiza al seleccionar.
	_chance_bar_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chance_bar_bg.clip_contents = true
	_chance_bar_bg.add_child(_chance_bar_fg)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_penalty_display(parent: Control) -> void:
	var hdr := _make_section_header("SI FALLA")
	parent.add_child(hdr)

	var container := ColorRect.new()
	container.name = "PenaltyContainer"
	container.color = Color(0.08, 0.06, 0.06, 0.9)
	container.custom_minimum_size = Vector2(0, 52)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	_penalty_label = Label.new()
	_penalty_label.name = "PenaltyLabel"
	_penalty_label.text = "—"
	_penalty_label.add_theme_font_size_override("font_size", FONT_BODY)
	_penalty_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6, 0.9))
	_penalty_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_penalty_label.add_theme_constant_override("outline_size", 3)
	_penalty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_penalty_label.offset_left   = 14.0
	_penalty_label.offset_right  = -14.0
	_penalty_label.offset_top    = 0.0
	_penalty_label.offset_bottom = 0.0
	_penalty_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_penalty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_penalty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_penalty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_penalty_label)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_cost_display(parent: Control) -> void:
	var hdr := _make_section_header("COSTE")
	parent.add_child(hdr)

	var container := ColorRect.new()
	container.name = "CostContainer"
	container.color = Color(0.07, 0.07, 0.1, 0.9)
	container.custom_minimum_size = Vector2(0, 52)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 14.0
	vbox.offset_right  = -14.0
	vbox.offset_top    = 6.0
	vbox.offset_bottom = -6.0
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(vbox)

	# Fila de Piedras de Resonancia.
	var stones_hbox := HBoxContainer.new()
	stones_hbox.add_theme_constant_override("separation", 8)
	stones_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stones_hbox)

	var stones_icon := ColorRect.new()
	stones_icon.name = "PiedraIcon"
	stones_icon.color = Color(0.45, 0.7, 1.0, 0.9)
	stones_icon.custom_minimum_size = Vector2(14, 14)
	stones_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stones_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stones_hbox.add_child(stones_icon)
	# TODO: reemplazar ColorRect por icono real cuando haya sprites.

	_stones_label = _make_label("Piedras de Resonancia: —", FONT_BODY, Color(0.85, 0.85, 0.9, 0.9))
	_stones_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stones_hbox.add_child(_stones_label)

	_stones_status = _make_label("", FONT_SMALL, Color(0.5, 0.9, 0.5, 1.0))
	stones_hbox.add_child(_stones_status)

	# Fila de Oro — siempre 0 en Fase 2.
	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 8)
	gold_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(gold_hbox)

	var gold_icon := ColorRect.new()
	gold_icon.name = "GoldIcon"
	gold_icon.color = Color(0.95, 0.78, 0.2, 0.5)
	gold_icon.custom_minimum_size = Vector2(14, 14)
	gold_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_hbox.add_child(gold_icon)

	var gold_label := _make_label("Oro: 0  (no implementado en Fase 2)", FONT_SMALL, Color(0.6, 0.6, 0.5, 0.6))
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_hbox.add_child(gold_label)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_scroll_toggle(parent: Control) -> void:
	# Solo visible cuando el target es +8, +9 o +10.
	_scroll_toggle_root = ColorRect.new()
	_scroll_toggle_root.name = "ScrollToggleRoot"
	_scroll_toggle_root.color = Color(0.07, 0.09, 0.14, 0.95)
	_scroll_toggle_root.custom_minimum_size = Vector2(0, 80)
	_scroll_toggle_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_toggle_root.visible = false
	_scroll_toggle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_scroll_toggle_root)

	var border := ColorRect.new()
	border.name = "ScrollBorder"
	border.color = Color(0.4, 0.6, 1.0, 0.35)
	border.anchor_left   = 0.0
	border.anchor_right  = 0.0
	border.anchor_top    = 0.0
	border.anchor_bottom = 1.0
	border.offset_right  = 4.0
	border.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_scroll_toggle_root.add_child(border)

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left   = 16.0
	inner.offset_right  = -14.0
	inner.offset_top    = 8.0
	inner.offset_bottom = -8.0
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_toggle_root.add_child(inner)

	# Fila checkbox + count.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(row)

	_scroll_checkbox = CheckBox.new()
	_scroll_checkbox.name = "ScrollCheckbox"
	_scroll_checkbox.text = "Usar Pergamino de Proteccion"
	_scroll_checkbox.add_theme_font_size_override("font_size", FONT_BODY)
	_scroll_checkbox.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 1.0))
	_scroll_checkbox.custom_minimum_size = Vector2(0, 44)  # hit area touch mínima.
	_scroll_checkbox.process_mode = Node.PROCESS_MODE_ALWAYS
	_scroll_checkbox.toggled.connect(_on_scroll_toggled)
	row.add_child(_scroll_checkbox)

	_scroll_count_label = _make_label("", FONT_SMALL, Color(0.7, 0.8, 1.0, 0.85))
	_scroll_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scroll_count_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_scroll_count_label)

	var scroll_info := _make_label(
		"Evita perder un nivel si el intento falla",
		FONT_SMALL,
		Color(0.65, 0.75, 0.95, 0.8)
	)
	scroll_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(scroll_info)

	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.5, 0.9, 0.3)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_action_row(parent: Control) -> void:
	# Relleno empuja la acción abajo si el contenido es corto.
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(fill)

	var action_bg := ColorRect.new()
	action_bg.name = "ActionBG"
	action_bg.color = Color(0.05, 0.05, 0.08, 1.0)
	action_bg.custom_minimum_size = Vector2(0, 80)
	action_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(action_bg)

	var action_vbox := VBoxContainer.new()
	action_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	action_vbox.offset_left   = 14.0
	action_vbox.offset_right  = -14.0
	action_vbox.offset_top    = 8.0
	action_vbox.offset_bottom = -8.0
	action_vbox.add_theme_constant_override("separation", 4)
	action_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_bg.add_child(action_vbox)

	# Mensaje de bloqueo (visible solo cuando el botón está deshabilitado).
	_attempt_blocked_label = _make_label("", FONT_SMALL, Color(0.9, 0.4, 0.4, 0.9))
	_attempt_blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attempt_blocked_label.visible = false
	action_vbox.add_child(_attempt_blocked_label)

	# Botón principal de intento — hit area mínima 56dp de alto.
	_attempt_btn = Button.new()
	_attempt_btn.name = "AttemptButton"
	_attempt_btn.text = "INTENTAR REFINAR"
	_attempt_btn.custom_minimum_size = Vector2(0, 56)
	_attempt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attempt_btn.add_theme_font_size_override("font_size", 18)
	_attempt_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_attempt_btn.add_theme_constant_override("outline_size", 4)
	_attempt_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_attempt_btn.disabled = true

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.45, 0.18, 1.0)
	btn_normal.corner_radius_top_left     = 8
	btn_normal.corner_radius_top_right    = 8
	btn_normal.corner_radius_bottom_left  = 8
	btn_normal.corner_radius_bottom_right = 8
	_attempt_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.58, 0.25, 1.0)
	btn_hover.corner_radius_top_left     = 8
	btn_hover.corner_radius_top_right    = 8
	btn_hover.corner_radius_bottom_left  = 8
	btn_hover.corner_radius_bottom_right = 8
	_attempt_btn.add_theme_stylebox_override("hover",   btn_hover)
	_attempt_btn.add_theme_stylebox_override("pressed", btn_hover)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.15, 0.15, 0.2, 0.7)
	btn_disabled.corner_radius_top_left     = 8
	btn_disabled.corner_radius_top_right    = 8
	btn_disabled.corner_radius_bottom_left  = 8
	btn_disabled.corner_radius_bottom_right = 8
	_attempt_btn.add_theme_stylebox_override("disabled", btn_disabled)

	_attempt_btn.pressed.connect(_on_attempt_pressed)
	action_vbox.add_child(_attempt_btn)


func _build_anim_overlay(parent: Control) -> void:
	# Overlay de animación — fullscreen dentro del panel, visible solo durante intento.
	_anim_overlay = ColorRect.new()
	_anim_overlay.name = "AnimOverlay"
	_anim_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_anim_overlay.anchor_left   = 0.06
	_anim_overlay.anchor_right  = 0.94
	_anim_overlay.anchor_top    = 0.04
	_anim_overlay.anchor_bottom = 0.96
	_anim_overlay.mouse_filter  = Control.MOUSE_FILTER_STOP
	_anim_overlay.visible = false
	parent.add_child(_anim_overlay)

	var center_vbox := VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_CENTER)
	center_vbox.anchor_left   = 0.1
	center_vbox.anchor_right  = 0.9
	center_vbox.anchor_top    = 0.3
	center_vbox.anchor_bottom = 0.7
	center_vbox.add_theme_constant_override("separation", 12)
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_overlay.add_child(center_vbox)

	_anim_label = Label.new()
	_anim_label.name = "AnimLabel"
	_anim_label.text = ""
	_anim_label.add_theme_font_size_override("font_size", 28)
	_anim_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_anim_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_anim_label.add_theme_constant_override("outline_size", 6)
	_anim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(_anim_label)

	_anim_sub_label = Label.new()
	_anim_sub_label.name = "AnimSubLabel"
	_anim_sub_label.text = ""
	_anim_sub_label.add_theme_font_size_override("font_size", FONT_BODY)
	_anim_sub_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.9))
	_anim_sub_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_anim_sub_label.add_theme_constant_override("outline_size", 3)
	_anim_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anim_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anim_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(_anim_sub_label)


# ─── Helpers de construcción ─────────────────────────────────────────────────

func _make_section_header(title: String) -> ColorRect:
	var bg := ColorRect.new()
	bg.name = "SectionHeader_" + title
	bg.color = COLOR_SECTION_BG
	bg.custom_minimum_size = Vector2(0, 30)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 1.0, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(lbl)

	return bg


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _rarity_color(rarity: ItemData.Rarity) -> Color:
	match rarity:
		ItemData.Rarity.R1: return COLOR_R1
		ItemData.Rarity.R2: return COLOR_R2
		ItemData.Rarity.R3: return COLOR_R3
		ItemData.Rarity.R4: return COLOR_R4
	return COLOR_R1


func _chance_color(chance: float) -> Color:
	# Verde para 100-70%, amarillo para 69-30%, rojo para <30%.
	if chance >= 0.70:
		return COLOR_CHANCE_HIGH
	elif chance >= 0.30:
		return COLOR_CHANCE_MID
	else:
		return COLOR_CHANCE_LOW


func _slot_stat_prefix(slot: ItemData.Slot) -> String:
	match slot:
		ItemData.Slot.ARMA:     return "ATK"
		ItemData.Slot.ARMADURA: return "DEF"
		ItemData.Slot.ESCUDO:   return "BLQ"
	return "STAT"


# ─── Lógica de selección y refresco ─────────────────────────────────────────

func _select_item(item: ItemData) -> void:
	_selected_item = item
	_use_scroll = false
	if _scroll_checkbox != null:
		_scroll_checkbox.button_pressed = false
	_refresh_preview()
	_refresh_chance()
	_refresh_penalty()
	_refresh_cost()
	_refresh_scroll_toggle()
	_refresh_attempt_button()
	_highlight_selected_row()


func _refresh_item_list() -> void:
	# Limpia y reconstruye la lista de items refinables.
	for child in _item_list_vbox.get_children():
		child.queue_free()
	_item_rows.clear()

	var all: Array[ItemData] = InventorySystem.get_all()
	var found_any: bool = false

	for item in all:
		if not UpgradeManager.can_refine(item):
			continue  # +10 ya maxeado, no aparece.
		found_any = true
		var row := _make_item_row(item)
		_item_list_vbox.add_child(row)
		_item_rows[item] = row

	if not found_any:
		var empty := _make_label("(ninguno refinable)", FONT_SMALL, Color(0.55, 0.55, 0.6, 0.7))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_item_list_vbox.add_child(empty)


func _make_item_row(item: ItemData) -> Control:
	# Fila de item en la lista — hit area mínima 56dp de alto.
	var rarity_col := _rarity_color(item.rarity)

	var outer := ColorRect.new()
	outer.name = "Row_" + str(item.id)
	outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.1)
	outer.custom_minimum_size = Vector2(0, 56)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_STOP

	# Franja de rareza.
	var rarity_bar := ColorRect.new()
	rarity_bar.color = rarity_col
	rarity_bar.anchor_left   = 0.0
	rarity_bar.anchor_right  = 0.0
	rarity_bar.anchor_top    = 0.0
	rarity_bar.anchor_bottom = 1.0
	rarity_bar.offset_right  = 4.0
	rarity_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rarity_bar)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 12.0
	vbox.offset_top    = 5.0
	vbox.offset_right  = -6.0
	vbox.offset_bottom = -5.0
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(vbox)

	var name_lbl := _make_label(item.display_name, FONT_SMALL, Color(1, 1, 1, 0.9))
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var level_txt: String = "+%d" % item.refinement_level if item.refinement_level > 0 else "sin refinar"
	var stat_txt: String = "%s %d" % [_slot_stat_prefix(item.slot), item.stat_main]
	var info_lbl := _make_label("%s  %s" % [level_txt, stat_txt], FONT_SMALL - 1, rarity_col)
	vbox.add_child(info_lbl)

	# Separador.
	var sep := ColorRect.new()
	sep.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.12)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var wrapper := VBoxContainer.new()
	wrapper.name = "Wrapper_" + str(item.id)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 0)
	wrapper.add_child(outer)
	wrapper.add_child(sep)

	# Tap en la fila selecciona el item.
	outer.gui_input.connect(func(event: InputEvent) -> void:
		if _is_animating:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_item(item)
		elif event is InputEventScreenTouch and event.pressed:
			_select_item(item)
	)

	return wrapper


func _highlight_selected_row() -> void:
	# Recolorea todas las filas; la seleccionada destaca.
	for item in _item_rows:
		var wrapper: Control = _item_rows[item]
		if wrapper == null or not is_instance_valid(wrapper):
			continue
		# El primer hijo del wrapper es el ColorRect exterior de la fila.
		var outer: ColorRect = wrapper.get_child(0) as ColorRect
		if outer == null:
			continue
		var rarity_col := _rarity_color(item.rarity)
		if item == _selected_item:
			outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.28)
		else:
			outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.1)


func _refresh_preview() -> void:
	if _selected_item == null:
		_preview_name.text = "(selecciona un item)"
		_preview_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.7))
		_preview_rarity_bar.color = Color(0.35, 0.35, 0.4, 0.4)
		_preview_level_label.text = ""
		_preview_stat_label.text  = ""
		return

	var item := _selected_item
	var rarity_col := _rarity_color(item.rarity)
	_preview_rarity_bar.color = rarity_col

	_preview_name.text = item.display_name
	_preview_name.add_theme_color_override("font_color", rarity_col)

	var target := UpgradeManager.get_target_level(item)
	var cur_lv := item.refinement_level
	var cur_stat := item.refined_stat()
	# Simulamos el stat futuro sin mutar el item.
	var fut_stat := float(item.stat_main) * (1.0 + 0.05 * float(target))

	_preview_level_label.text = "+%d  →  +%d" % [cur_lv, target]
	var prefix := _slot_stat_prefix(item.slot)
	_preview_stat_label.text = "%s: %d  →  %d" % [prefix, int(cur_stat), int(fut_stat)]


func _refresh_chance() -> void:
	if _selected_item == null:
		_chance_pct_label.text = "—"
		_chance_pct_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.7))
		_chance_bar_fg.anchor_right = 0.0
		return

	var target := UpgradeManager.get_target_level(_selected_item)
	var chance := UpgradeManager.get_success_chance(target)
	var col := _chance_color(chance)
	var pct_int := int(chance * 100.0)

	_chance_pct_label.text = "%d%%" % pct_int
	_chance_pct_label.add_theme_color_override("font_color", col)

	# La barra usa anchor_right para proporcionar el relleno (dentro de clip_contents).
	# Necesita un frame para que el bg tenga tamaño; usamos deferred set.
	_chance_bar_fg.color = col
	_chance_bar_fg.set_deferred("anchor_right", chance)


func _refresh_penalty() -> void:
	if _selected_item == null:
		_penalty_label.text = "—"
		_penalty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.7))
		return

	var target := UpgradeManager.get_target_level(_selected_item)
	var penalty := UpgradeManager.get_penalty_type(target)

	match penalty:
		"none":
			_penalty_label.text = "Nada. Este nivel es seguro."
			_penalty_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 0.95))
		"materials_only":
			_penalty_label.text = "Se pierden los materiales usados (1 Piedra de Resonancia)."
			_penalty_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3, 0.95))
		"level_loss":
			_penalty_label.text = "El item baja 1 nivel de refinamiento.\nUsa un Pergamino para protegerlo."
			_penalty_label.add_theme_color_override("font_color", Color(0.95, 0.38, 0.38, 0.95))
		_:
			_penalty_label.text = "—"


func _refresh_cost() -> void:
	if _selected_item == null:
		_stones_label.text = "Piedras de Resonancia: —"
		_stones_status.text = ""
		return

	var target := UpgradeManager.get_target_level(_selected_item)
	var cost := UpgradeManager.get_cost(target)
	var stones_needed: int = cost.get("stones", 1)
	var stones_have: int = InventorySystem.get_material_count(UpgradeManager.ID_PIEDRA)

	_stones_label.text = "Piedras: %d  /  %d necesaria(s)" % [stones_have, stones_needed]

	if stones_have >= stones_needed:
		_stones_status.text = "OK"
		_stones_status.add_theme_color_override("font_color", Color(0.4, 0.92, 0.4, 1.0))
	else:
		var falta: int = stones_needed - stones_have
		_stones_status.text = "Falta %d" % falta
		_stones_status.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))


func _refresh_scroll_toggle() -> void:
	if _selected_item == null:
		_scroll_toggle_root.visible = false
		return

	var target := UpgradeManager.get_target_level(_selected_item)
	var requires := UpgradeManager.requires_scroll_to_protect(target)
	_scroll_toggle_root.visible = requires

	if not requires:
		return

	var can_use := UpgradeManager.can_use_scroll(_selected_item)
	var scroll_count: int = InventorySystem.get_material_count(UpgradeManager.ID_PERGAMINO)

	_scroll_checkbox.disabled = not can_use
	_scroll_count_label.text = "Tenés: %d" % scroll_count

	if not can_use:
		# Sin pergaminos — desmarcar y mostrar hint.
		_scroll_checkbox.button_pressed = false
		_use_scroll = false
		_scroll_count_label.text = "Tenés: 0  (necesitás 1)"
		_scroll_count_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 0.9))
	else:
		_scroll_count_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 0.85))


func _refresh_attempt_button() -> void:
	if _selected_item == null:
		_attempt_btn.disabled = true
		_attempt_btn.text = "INTENTAR REFINAR"
		_attempt_blocked_label.text = "Seleccioná un item primero."
		_attempt_blocked_label.visible = true
		return

	var target := UpgradeManager.get_target_level(_selected_item)
	var cost := UpgradeManager.get_cost(target)
	var stones_needed: int = cost.get("stones", 1)
	var stones_have: int = InventorySystem.get_material_count(UpgradeManager.ID_PIEDRA)

	if stones_have < stones_needed:
		_attempt_btn.disabled = true
		_attempt_blocked_label.text = "Faltan Piedras de Resonancia."
		_attempt_blocked_label.visible = true
		return

	if _use_scroll and not UpgradeManager.can_use_scroll(_selected_item):
		_attempt_btn.disabled = true
		_attempt_blocked_label.text = "No tenés Pergamino de Proteccion."
		_attempt_blocked_label.visible = true
		return

	# Todo ok.
	_attempt_btn.disabled = false
	_attempt_blocked_label.visible = false
	var lv_str: String = "+%d" % UpgradeManager.get_target_level(_selected_item)
	_attempt_btn.text = "INTENTAR REFINAR  %s" % lv_str


func _refresh_session_label() -> void:
	if _session_attempts == 0:
		_session_label.text = ""
	else:
		_session_label.text = "  intentos: %d" % _session_attempts


# ─── Handlers de interacción ─────────────────────────────────────────────────

func _on_scroll_toggled(pressed: bool) -> void:
	_use_scroll = pressed
	_refresh_attempt_button()


func _on_attempt_pressed() -> void:
	if _selected_item == null or _is_animating:
		return
	_start_refine_attempt()


# ─── Flujo de intento y animación ────────────────────────────────────────────

func _start_refine_attempt() -> void:
	_is_animating = true
	_attempt_btn.disabled = true
	_close_btn.disabled = true
	_scroll_checkbox.disabled = true

	# Mostrar overlay de suspenso.
	_anim_overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	_anim_label.text    = "Refinando..."
	_anim_sub_label.text = ""
	_anim_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1.0))
	_anim_overlay.visible = true

	# Animación de puntos suspensivos usando Tween.
	var dots_tween := create_tween()
	dots_tween.set_loops(3)
	dots_tween.tween_callback(func() -> void:
		if _anim_label != null and is_instance_valid(_anim_label):
			_anim_label.text = "Refinando."
	).set_delay(0.0)
	dots_tween.tween_callback(func() -> void:
		if _anim_label != null and is_instance_valid(_anim_label):
			_anim_label.text = "Refinando.."
	).set_delay(ANIM_SUSPENSE_DURATION / 6.0)
	dots_tween.tween_callback(func() -> void:
		if _anim_label != null and is_instance_valid(_anim_label):
			_anim_label.text = "Refinando..."
	).set_delay(ANIM_SUSPENSE_DURATION / 6.0)

	# Después del suspenso, ejecutar el intento real.
	var timer := get_tree().create_timer(ANIM_SUSPENSE_DURATION)
	timer.timeout.connect(_execute_refine)


func _execute_refine() -> void:
	_session_attempts += 1
	_refresh_session_label()

	# attempt_refine muta el item y emite signals (connected en _connect_signals).
	var result: RefineResult = UpgradeManager.attempt_refine(_selected_item, _use_scroll)

	if result == null:
		# attempt_refine emitió refine_aborted (condición de carrera rara — materiales
		# cambiaron entre el chequeo del botón y la ejecución).
		_show_result_aborted()
		return

	if result.success:
		_show_result_success(result)
	else:
		_show_result_fail(result)


func _show_result_success(result: RefineResult) -> void:
	_anim_overlay.color = Color(0.1, 0.12, 0.04, 0.88)
	_anim_label.text    = "+%d  EXITO" % result.new_level
	_anim_label.add_theme_color_override("font_color", COLOR_RESULT_SUCCESS)
	_anim_sub_label.text = "El item subio a refinamiento +%d" % result.new_level
	_anim_sub_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7, 0.9))

	# Flash dorado.
	var tween := create_tween()
	tween.tween_property(_anim_overlay, "color", Color(0.25, 0.22, 0.0, 0.88), ANIM_FLASH_DURATION)
	tween.tween_property(_anim_overlay, "color", Color(0.1, 0.12, 0.04, 0.88), ANIM_FLASH_DURATION)
	tween.tween_callback(_finish_animation)


func _show_result_fail(result: RefineResult) -> void:
	if result.dropped_to_level:
		# Pérdida de nivel sin pergamino.
		_anim_overlay.color = Color(0.12, 0.02, 0.02, 0.9)
		_anim_label.text    = "FALLO"
		_anim_label.add_theme_color_override("font_color", COLOR_RESULT_FAIL_LVL)
		_anim_sub_label.text = "El item bajo a +%d.\nLa Piedra de Resonancia fue consumida." % result.new_level
		_anim_sub_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.55, 0.9))
	elif result.protected_by_scroll:
		# Fallo protegido por pergamino.
		_anim_overlay.color = Color(0.04, 0.06, 0.14, 0.9)
		_anim_label.text    = "FALLO — Pergamino activo"
		_anim_label.add_theme_color_override("font_color", COLOR_RESULT_SCROLL)
		_anim_sub_label.text = "El Pergamino de Proteccion absorbio el fallo.\nEl item se mantiene en +%d." % result.new_level
		_anim_sub_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	else:
		# Fallo sin pérdida de nivel.
		_anim_overlay.color = Color(0.08, 0.08, 0.1, 0.9)
		_anim_label.text    = "FALLO"
		_anim_label.add_theme_color_override("font_color", COLOR_RESULT_FAIL_MAT)
		_anim_sub_label.text = "Los materiales fueron consumidos. El item queda en +%d." % result.new_level
		_anim_sub_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 0.9))

	# Flash del color correspondiente.
	var flash_col: Color = COLOR_RESULT_FAIL_LVL if result.dropped_to_level else (COLOR_RESULT_SCROLL if result.protected_by_scroll else COLOR_RESULT_FAIL_MAT)
	var tween := create_tween()
	tween.tween_property(_anim_overlay, "color:a", 0.95, ANIM_FLASH_DURATION * 0.5)
	tween.tween_property(_anim_overlay, "color:a", 0.88, ANIM_FLASH_DURATION * 0.5)
	tween.tween_callback(_finish_animation)


func _show_result_aborted() -> void:
	_anim_label.text = "Intento cancelado"
	_anim_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 0.9))
	_anim_sub_label.text = "Materiales insuficientes al momento del intento."
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(_finish_animation)


func _finish_animation() -> void:
	# Mantener resultado visible 1.2s adicionales para que el jugador lo lea.
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(func() -> void:
		_anim_overlay.visible = false
		_is_animating = false
		_close_btn.disabled = false
		# Refrescar toda la UI con el nuevo estado del item.
		_refresh_item_list()
		if _selected_item != null and UpgradeManager.can_refine(_selected_item):
			_select_item(_selected_item)
		elif _selected_item != null and not UpgradeManager.can_refine(_selected_item):
			# Item llegó a +10 — seleccionar el próximo si hay.
			var next: ItemData = null
			for it in InventorySystem.get_all():
				if UpgradeManager.can_refine(it):
					next = it
					break
			_select_item(next)
		else:
			_select_item(null)
		_refresh_session_label()
	)


# ─── Conexiones de signals ────────────────────────────────────────────────────

func _connect_signals() -> void:
	# Refrescar coste y botón si los materiales cambian mientras la pantalla está abierta.
	InventorySystem.materials_changed.connect(_on_materials_changed)
	# Refrescar lista si el inventario de items cambia.
	InventorySystem.item_added.connect(_on_items_changed)
	InventorySystem.item_removed.connect(_on_items_changed)


func _on_materials_changed() -> void:
	if not _is_open:
		return
	_refresh_cost()
	_refresh_scroll_toggle()
	_refresh_attempt_button()


func _on_items_changed(_item: ItemData) -> void:
	if not _is_open:
		return
	_refresh_item_list()
	# Si el item seleccionado desapareció del inventario, limpiar selección.
	if _selected_item != null and not InventorySystem.get_all().has(_selected_item):
		_select_item(null)
