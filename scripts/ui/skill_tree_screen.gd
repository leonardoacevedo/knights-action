extends CanvasLayer
class_name SkillTreeScreen

## Pantalla del Árbol de Habilidades. GDD §6 / Pilar #1.
##
## Muestra los 30 nodos del árbol distribuidos en 3 ramas (Guerrero / Mago / Ágil)
## y 5 tiers. El jugador puede invertir puntos de habilidad disponibles y ver el
## efecto exacto de cada nodo antes de confirmar.
##
## Pilar #1: "Mi build importa, mi skill también." — cada nodo muestra su efecto
## completo con números reales antes de desbloquear.
##
## Flujo:
##   Abrir → tab activo (Guerrero default) → tap nodo → DetailPanel se llena →
##   (si puede desbloquear) → DESBLOQUEAR → burst visual → nodo se pone dorado.
##
## Respec:
##   RespecButton → (si hay 10 Hierba y al menos 1 nodo) → diálogo → respec() →
##   todos los nodos vuelven a gris → puntos restaurados.
##
## Trigger de apertura: botón HABILIDADES en header de InventoryScreen.
##
## Conexiones autoload:
##   PlayerProgression — puntos, árbol, unlock, respec, signals.
##   InventorySystem   — consulta de materiales (Hierba Antigua para respec).

# ─── Colores compartidos con pantallas existentes ─────────────────────────────

const COLOR_R1 := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_R2 := Color(0.3, 0.6, 1.0, 0.7)
const COLOR_R3 := Color(0.7, 0.3, 0.9, 0.8)
const COLOR_R4 := Color(1.0, 0.75, 0.2, 0.9)

const COLOR_PANEL_BG   := Color(0.07, 0.07, 0.1,  0.97)
const COLOR_HEADER_BG  := Color(0.05, 0.05, 0.08, 1.0)
const COLOR_SECTION_BG := Color(0.1,  0.1,  0.15, 0.8)
const COLOR_ITEM_BG    := Color(0.1,  0.1,  0.16, 0.9)

# Colores de estado por nodo.
const COLOR_NODE_UNLOCKED := Color(1.0,  0.78, 0.15, 1.0)   # dorado
const COLOR_NODE_AVAILABLE := Color(0.3, 0.88, 0.45, 1.0)   # verde claro
const COLOR_NODE_LOCKED    := Color(0.4, 0.4,  0.45, 0.6)   # gris

# Colores por rama.
const COLOR_BRANCH_GUERRERO := Color(0.9,  0.3,  0.25, 1.0)  # rojo/marrón
const COLOR_BRANCH_MAGO     := Color(0.45, 0.3,  0.95, 1.0)  # azul/violeta
const COLOR_BRANCH_AGIL     := Color(0.3,  0.85, 0.35, 1.0)  # verde/amarillo

# Color del botón DESBLOQUEAR (violeta — distinto a FORJA verde y REFINAR azul).
const COLOR_UNLOCK_BTN  := Color(0.42, 0.18, 0.65, 1.0)
const COLOR_UNLOCK_HOVR := Color(0.55, 0.25, 0.82, 1.0)
const COLOR_UNLOCK_DISA := Color(0.18, 0.15, 0.22, 0.7)

# Fuentes — idénticas a pantallas existentes para coherencia.
const FONT_TITLE   := 22
const FONT_SECTION := 15
const FONT_BODY    := 14
const FONT_SMALL   := 12

# Tamaño mínimo de botón de nodo — mobile-first (>44dp Apple HIG).
const NODE_BTN_SIZE := Vector2(64, 64)

# Duración del burst visual al desbloquear un nodo.
const ANIM_UNLOCK_DURATION := 0.45

# ─── Nodos construidos proceduralmente ───────────────────────────────────────

var _panel: PanelContainer
var _close_btn: Button

# Header info
var _level_info_lbl: Label
var _points_info_lbl: Label
var _respec_btn: Button
var _debug_xp_btn: Button  # solo visible con DEBUG_ENEMY_AI — TODO: remover antes de producción

# Tabs de rama
var _tab_buttons: Array[Button] = []
var _active_branch: int = 0  # SkillNode.Branch enum index

# Grid de nodos
var _node_grid_scroll: ScrollContainer
var _node_grid_vbox: VBoxContainer
# Mapa id → control para poder actualizar estado visual.
var _node_buttons: Dictionary = {}  # StringName → Control (el outer ColorRect de cada nodo)

# Panel de detalle
var _detail_name_lbl: Label
var _detail_desc_lbl: Label
var _detail_effects_vbox: VBoxContainer
var _detail_prereqs_vbox: VBoxContainer
var _unlock_btn: Button
var _unlock_blocked_lbl: Label

# Overlay de burst visual al desbloquear
var _burst_overlay: ColorRect
var _burst_label: Label

# Diálogo de confirmación de respec (reutilizable)
var _respec_dialog: ColorRect
var _respec_dialog_visible: bool = false

# ─── Estado ──────────────────────────────────────────────────────────────────

var _selected_node_id: StringName = &""
var _is_open: bool = false
var _is_animating: bool = false


# ─── Ciclo de vida ───────────────────────────────────────────────────────────

func _ready() -> void:
	# Layer 28 — sobre Refinement (25), Crafting (26), LootCard (27).
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_build_ui()
	_connect_signals()


# ─── API pública ─────────────────────────────────────────────────────────────

## Abre la pantalla del árbol. Llamado desde InventoryScreen.
func open() -> void:
	if _is_animating:
		return
	_is_open = true
	visible = true
	get_tree().paused = true
	_active_branch = 0  # default: Guerrero
	_selected_node_id = &""
	_refresh_header_info()
	_refresh_tabs()
	_refresh_node_grid()
	_clear_detail()


func close() -> void:
	if _is_animating:
		return
	_is_open = false
	_respec_dialog_visible = false
	if _respec_dialog != null:
		_respec_dialog.visible = false
	visible = false
	get_tree().paused = false


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


# ─── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event is InputEventKey and event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		if _respec_dialog_visible:
			_hide_respec_dialog()
			get_viewport().set_input_as_handled()
		elif _is_open and not _is_animating:
			close()
			get_viewport().set_input_as_handled()


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo oscuro bloqueante — tap fuera del panel cierra (mismo patrón que pantallas existentes).
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if _respec_dialog_visible:
			return  # diálogo activo — no cerrar por tap en fondo
		if ev is InputEventScreenTouch and ev.pressed:
			close()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(bg)

	# Contenedor raíz.
	var root_ctrl := Control.new()
	root_ctrl.name = "RootControl"
	root_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# Panel principal — mismo porcentaje que pantallas existentes.
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

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(main_vbox)

	_build_header(main_vbox)
	_build_branch_tabs(main_vbox)
	_build_body(main_vbox)
	_build_burst_overlay(root_ctrl)
	_build_respec_dialog(root_ctrl)


func _build_header(parent: Control) -> void:
	var header := ColorRect.new()
	header.name = "Header"
	header.color = COLOR_HEADER_BG
	header.custom_minimum_size = Vector2(0, 80)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.offset_left   = 14.0
	vbox.offset_right  = -0.0
	vbox.offset_top    = 6.0
	vbox.offset_bottom = -6.0
	header.add_child(vbox)

	# Fila 1: título + debug XP + respec + cerrar
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 0)
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row1)

	var title_lbl := Label.new()
	title_lbl.text = "ARBOL DE HABILIDADES"
	title_lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(title_lbl)

	# Botón debug +100 XP — solo visible si DEBUG_ENEMY_AI activo.
	# TODO: remover antes de producción.
	_debug_xp_btn = Button.new()
	_debug_xp_btn.name = "DebugXPButton"
	_debug_xp_btn.text = "+100 XP"
	_debug_xp_btn.custom_minimum_size = Vector2(80, 44)
	_debug_xp_btn.add_theme_font_size_override("font_size", 11)
	_debug_xp_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0, 0.85))
	_debug_xp_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_debug_xp_btn.add_theme_constant_override("outline_size", 2)
	_debug_xp_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var dbg_style := StyleBoxFlat.new()
	dbg_style.bg_color = Color(0.25, 0.15, 0.0, 0.5)
	dbg_style.corner_radius_top_left     = 4
	dbg_style.corner_radius_top_right    = 4
	dbg_style.corner_radius_bottom_left  = 4
	dbg_style.corner_radius_bottom_right = 4
	_debug_xp_btn.add_theme_stylebox_override("normal", dbg_style)
	_debug_xp_btn.pressed.connect(_on_debug_xp_pressed)
	_debug_xp_btn.visible = GameConfig.DEBUG_ENEMY_AI
	row1.add_child(_debug_xp_btn)

	# Botón Respec.
	_respec_btn = Button.new()
	_respec_btn.name = "RespecButton"
	_respec_btn.text = "Respec  10 Hierba"
	_respec_btn.custom_minimum_size = Vector2(130, 44)
	_respec_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_respec_btn.add_theme_font_size_override("font_size", 12)
	_respec_btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2, 1.0))
	_respec_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_respec_btn.add_theme_constant_override("outline_size", 2)
	_respec_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var respec_normal := StyleBoxFlat.new()
	respec_normal.bg_color = Color(0.22, 0.14, 0.03, 0.75)
	respec_normal.corner_radius_top_left     = 5
	respec_normal.corner_radius_top_right    = 5
	respec_normal.corner_radius_bottom_left  = 5
	respec_normal.corner_radius_bottom_right = 5
	respec_normal.border_color = Color(0.6, 0.38, 0.1, 0.5)
	respec_normal.border_width_left   = 1
	respec_normal.border_width_right  = 1
	respec_normal.border_width_top    = 1
	respec_normal.border_width_bottom = 1
	_respec_btn.add_theme_stylebox_override("normal", respec_normal)
	var respec_hover := StyleBoxFlat.new()
	respec_hover.bg_color = Color(0.35, 0.22, 0.05, 0.9)
	_respec_btn.add_theme_stylebox_override("hover",   respec_hover)
	_respec_btn.add_theme_stylebox_override("pressed", respec_hover)
	_respec_btn.pressed.connect(_on_respec_btn_pressed)
	row1.add_child(_respec_btn)

	# Botón cerrar — hit area 64×44 dp.
	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(64, 44)
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
	row1.add_child(_close_btn)

	# Fila 2: level info + puntos disponibles
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row2)

	_level_info_lbl = Label.new()
	_level_info_lbl.name = "LevelInfoLabel"
	_level_info_lbl.text = "Nivel —  XP —/—"
	_level_info_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	_level_info_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.85))
	_level_info_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_level_info_lbl.add_theme_constant_override("outline_size", 2)
	_level_info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(_level_info_lbl)

	_points_info_lbl = Label.new()
	_points_info_lbl.name = "PointsInfoLabel"
	_points_info_lbl.text = "Puntos: —"
	_points_info_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	_points_info_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55, 1.0))
	_points_info_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_points_info_lbl.add_theme_constant_override("outline_size", 2)
	_points_info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(_points_info_lbl)

	parent.add_child(header)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_branch_tabs(parent: Control) -> void:
	# 3 botones de tab — separador de rama activa visual.
	var tabs_row := HBoxContainer.new()
	tabs_row.name = "BranchTabs"
	tabs_row.add_theme_constant_override("separation", 0)
	tabs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.custom_minimum_size = Vector2(0, 46)
	parent.add_child(tabs_row)

	var branch_labels: Array[String] = ["GUERRERO", "MAGO", "AGIL"]
	var branch_colors: Array[Color] = [COLOR_BRANCH_GUERRERO, COLOR_BRANCH_MAGO, COLOR_BRANCH_AGIL]

	_tab_buttons.clear()
	for i in range(3):
		var btn := Button.new()
		btn.name = "Tab_%s" % branch_labels[i]
		btn.text = branch_labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", branch_colors[i])
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		btn.add_theme_constant_override("outline_size", 3)
		btn.process_mode = Node.PROCESS_MODE_ALWAYS

		var tab_inactive := StyleBoxFlat.new()
		tab_inactive.bg_color = Color(branch_colors[i].r, branch_colors[i].g, branch_colors[i].b, 0.08)
		tab_inactive.border_color = Color(branch_colors[i].r, branch_colors[i].g, branch_colors[i].b, 0.25)
		tab_inactive.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", tab_inactive)

		var tab_active := StyleBoxFlat.new()
		tab_active.bg_color = Color(branch_colors[i].r, branch_colors[i].g, branch_colors[i].b, 0.22)
		tab_active.border_color = branch_colors[i]
		tab_active.border_width_bottom = 3
		btn.add_theme_stylebox_override("hover",   tab_active)
		btn.add_theme_stylebox_override("pressed", tab_active)

		var branch_idx := i
		btn.pressed.connect(func() -> void: _on_tab_pressed(branch_idx))
		tabs_row.add_child(btn)
		_tab_buttons.append(btn)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.35)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_body(parent: Control) -> void:
	# Layout horizontal: grid de nodos (izquierda, expandible) | panel de detalle (derecha, fija).
	var body_hbox := HBoxContainer.new()
	body_hbox.name = "BodyHBox"
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 0)
	parent.add_child(body_hbox)

	_build_node_grid_column(body_hbox)

	var vsep := ColorRect.new()
	vsep.color = Color(0.3, 0.3, 0.5, 0.3)
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(vsep)

	_build_detail_panel(body_hbox)


func _build_node_grid_column(parent: Control) -> void:
	# Columna izquierda scrollable — nodos del branch activo en tiers.
	var col := VBoxContainer.new()
	col.name = "NodeGridColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	_node_grid_scroll = ScrollContainer.new()
	_node_grid_scroll.name = "NodeGridScroll"
	_node_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_grid_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_node_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_node_grid_scroll)

	_node_grid_vbox = VBoxContainer.new()
	_node_grid_vbox.name = "NodeGridVBox"
	_node_grid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_grid_vbox.add_theme_constant_override("separation", 6)
	_node_grid_scroll.add_child(_node_grid_vbox)


func _build_detail_panel(parent: Control) -> void:
	# Panel derecho — información del nodo seleccionado + botón desbloquear.
	# Ancho fijo ~42% del panel para que el grid tenga espacio suficiente.
	var outer_vbox := VBoxContainer.new()
	outer_vbox.name = "DetailOuterVBox"
	outer_vbox.custom_minimum_size = Vector2(185, 0)
	outer_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 0)
	parent.add_child(outer_vbox)

	var hdr := _make_section_header("DETALLE")
	outer_vbox.add_child(hdr)

	# Scroll para el contenido del detalle (puede ser largo).
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(detail_scroll)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "DetailVBox"
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 0)
	detail_scroll.add_child(detail_vbox)

	_build_detail_content(detail_vbox)
	_build_detail_action(outer_vbox)


func _build_detail_content(parent: Control) -> void:
	# Nombre del nodo — prominente.
	var name_container := ColorRect.new()
	name_container.name = "NameContainer"
	name_container.color = Color(0.1, 0.08, 0.14, 0.9)
	name_container.custom_minimum_size = Vector2(0, 56)
	name_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(name_container)

	_detail_name_lbl = Label.new()
	_detail_name_lbl.name = "DetailNameLabel"
	_detail_name_lbl.text = "Seleccioná un nodo"
	_detail_name_lbl.add_theme_font_size_override("font_size", FONT_SECTION)
	_detail_name_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 0.6))
	_detail_name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_detail_name_lbl.add_theme_constant_override("outline_size", 3)
	_detail_name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_name_lbl.offset_left   = 10.0
	_detail_name_lbl.offset_right  = -10.0
	_detail_name_lbl.offset_top    = 6.0
	_detail_name_lbl.offset_bottom = -6.0
	_detail_name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_detail_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_container.add_child(_detail_name_lbl)

	var sep1 := ColorRect.new()
	sep1.color = Color(0.3, 0.3, 0.5, 0.25)
	sep1.custom_minimum_size = Vector2(0, 1)
	sep1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep1)

	# Descripción del nodo.
	var desc_hdr := _make_section_header("DESCRIPCION")
	parent.add_child(desc_hdr)

	var desc_container := ColorRect.new()
	desc_container.name = "DescContainer"
	desc_container.color = COLOR_ITEM_BG
	desc_container.custom_minimum_size = Vector2(0, 52)
	desc_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(desc_container)

	_detail_desc_lbl = Label.new()
	_detail_desc_lbl.name = "DetailDescLabel"
	_detail_desc_lbl.text = ""
	_detail_desc_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	_detail_desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 0.9))
	_detail_desc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_detail_desc_lbl.add_theme_constant_override("outline_size", 2)
	_detail_desc_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_desc_lbl.offset_left   = 10.0
	_detail_desc_lbl.offset_right  = -10.0
	_detail_desc_lbl.offset_top    = 6.0
	_detail_desc_lbl.offset_bottom = -6.0
	_detail_desc_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	_detail_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_container.add_child(_detail_desc_lbl)

	var sep2 := ColorRect.new()
	sep2.color = Color(0.3, 0.3, 0.5, 0.25)
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep2)

	# Efectos del nodo — lista de stats modificados.
	var effects_hdr := _make_section_header("EFECTOS")
	parent.add_child(effects_hdr)

	var effects_container := ColorRect.new()
	effects_container.name = "EffectsContainer"
	effects_container.color = Color(0.07, 0.1, 0.07, 0.9)
	effects_container.custom_minimum_size = Vector2(0, 44)
	effects_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(effects_container)

	_detail_effects_vbox = VBoxContainer.new()
	_detail_effects_vbox.name = "EffectsVBox"
	_detail_effects_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_effects_vbox.offset_left   = 10.0
	_detail_effects_vbox.offset_right  = -10.0
	_detail_effects_vbox.offset_top    = 6.0
	_detail_effects_vbox.offset_bottom = -6.0
	_detail_effects_vbox.add_theme_constant_override("separation", 3)
	_detail_effects_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_container.add_child(_detail_effects_vbox)

	var sep3 := ColorRect.new()
	sep3.color = Color(0.3, 0.3, 0.5, 0.25)
	sep3.custom_minimum_size = Vector2(0, 1)
	sep3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep3)

	# Prerrequisitos — qué nodos necesitan estar desbloqueados antes.
	var prereq_hdr := _make_section_header("REQUIERE")
	parent.add_child(prereq_hdr)

	var prereq_container := ColorRect.new()
	prereq_container.name = "PrereqContainer"
	prereq_container.color = Color(0.08, 0.07, 0.07, 0.9)
	prereq_container.custom_minimum_size = Vector2(0, 36)
	prereq_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prereq_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(prereq_container)

	_detail_prereqs_vbox = VBoxContainer.new()
	_detail_prereqs_vbox.name = "PrereqsVBox"
	_detail_prereqs_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_prereqs_vbox.offset_left   = 10.0
	_detail_prereqs_vbox.offset_right  = -10.0
	_detail_prereqs_vbox.offset_top    = 6.0
	_detail_prereqs_vbox.offset_bottom = -6.0
	_detail_prereqs_vbox.add_theme_constant_override("separation", 3)
	_detail_prereqs_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prereq_container.add_child(_detail_prereqs_vbox)

	var sep4 := ColorRect.new()
	sep4.color = Color(0.3, 0.3, 0.5, 0.25)
	sep4.custom_minimum_size = Vector2(0, 1)
	sep4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep4)


func _build_detail_action(parent: Control) -> void:
	# Área de acción fija en la parte inferior del panel de detalle.
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(fill)

	var action_bg := ColorRect.new()
	action_bg.name = "ActionBG"
	action_bg.color = Color(0.05, 0.05, 0.08, 1.0)
	action_bg.custom_minimum_size = Vector2(0, 88)
	action_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(action_bg)

	var action_vbox := VBoxContainer.new()
	action_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	action_vbox.offset_left   = 10.0
	action_vbox.offset_right  = -10.0
	action_vbox.offset_top    = 8.0
	action_vbox.offset_bottom = -8.0
	action_vbox.add_theme_constant_override("separation", 4)
	action_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_bg.add_child(action_vbox)

	# Texto de bloqueo visible solo cuando el botón está deshabilitado.
	_unlock_blocked_lbl = _make_label("", FONT_SMALL, Color(0.9, 0.45, 0.45, 0.9))
	_unlock_blocked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_blocked_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unlock_blocked_lbl.visible = false
	action_vbox.add_child(_unlock_blocked_lbl)

	# Botón DESBLOQUEAR — hit area mínima 56dp. Violeta para diferenciar de FORJA (verde) y REFINAR (azul).
	_unlock_btn = Button.new()
	_unlock_btn.name = "UnlockButton"
	_unlock_btn.text = "DESBLOQUEAR"
	_unlock_btn.custom_minimum_size = Vector2(0, 56)
	_unlock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unlock_btn.add_theme_font_size_override("font_size", 16)
	_unlock_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_unlock_btn.add_theme_constant_override("outline_size", 4)
	_unlock_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_unlock_btn.disabled = true

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = COLOR_UNLOCK_BTN
	btn_normal.corner_radius_top_left     = 8
	btn_normal.corner_radius_top_right    = 8
	btn_normal.corner_radius_bottom_left  = 8
	btn_normal.corner_radius_bottom_right = 8
	_unlock_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = COLOR_UNLOCK_HOVR
	btn_hover.corner_radius_top_left     = 8
	btn_hover.corner_radius_top_right    = 8
	btn_hover.corner_radius_bottom_left  = 8
	btn_hover.corner_radius_bottom_right = 8
	_unlock_btn.add_theme_stylebox_override("hover",   btn_hover)
	_unlock_btn.add_theme_stylebox_override("pressed", btn_hover)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = COLOR_UNLOCK_DISA
	btn_disabled.corner_radius_top_left     = 8
	btn_disabled.corner_radius_top_right    = 8
	btn_disabled.corner_radius_bottom_left  = 8
	btn_disabled.corner_radius_bottom_right = 8
	_unlock_btn.add_theme_stylebox_override("disabled", btn_disabled)

	_unlock_btn.pressed.connect(_on_unlock_btn_pressed)
	action_vbox.add_child(_unlock_btn)


func _build_burst_overlay(parent: Control) -> void:
	# Overlay de burst visual al desbloquear — mismo patrón que overlays de animación existentes.
	_burst_overlay = ColorRect.new()
	_burst_overlay.name = "BurstOverlay"
	_burst_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_burst_overlay.anchor_left   = 0.06
	_burst_overlay.anchor_right  = 0.94
	_burst_overlay.anchor_top    = 0.04
	_burst_overlay.anchor_bottom = 0.96
	_burst_overlay.mouse_filter  = Control.MOUSE_FILTER_STOP
	_burst_overlay.visible = false
	parent.add_child(_burst_overlay)

	var center_vbox := VBoxContainer.new()
	center_vbox.anchor_left   = 0.1
	center_vbox.anchor_right  = 0.9
	center_vbox.anchor_top    = 0.3
	center_vbox.anchor_bottom = 0.7
	center_vbox.add_theme_constant_override("separation", 12)
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_overlay.add_child(center_vbox)

	_burst_label = Label.new()
	_burst_label.name = "BurstLabel"
	_burst_label.text = ""
	_burst_label.add_theme_font_size_override("font_size", 28)
	_burst_label.add_theme_color_override("font_color", COLOR_NODE_UNLOCKED)
	_burst_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_burst_label.add_theme_constant_override("outline_size", 6)
	_burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_burst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(_burst_label)


func _build_respec_dialog(parent: Control) -> void:
	# Diálogo de confirmación de respec — panel flotante centrado.
	_respec_dialog = ColorRect.new()
	_respec_dialog.name = "RespecDialog"
	_respec_dialog.color = Color(0.03, 0.03, 0.06, 0.96)
	_respec_dialog.anchor_left   = 0.12
	_respec_dialog.anchor_right  = 0.88
	_respec_dialog.anchor_top    = 0.3
	_respec_dialog.anchor_bottom = 0.72
	_respec_dialog.mouse_filter  = Control.MOUSE_FILTER_STOP
	_respec_dialog.visible = false

	# Borde del diálogo.
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.09, 0.07, 0.12, 0.98)
	dialog_style.corner_radius_top_left     = 12
	dialog_style.corner_radius_top_right    = 12
	dialog_style.corner_radius_bottom_left  = 12
	dialog_style.corner_radius_bottom_right = 12
	dialog_style.border_color = Color(0.5, 0.35, 0.1, 0.8)
	dialog_style.border_width_top    = 1
	dialog_style.border_width_right  = 1
	dialog_style.border_width_bottom = 1
	dialog_style.border_width_left   = 1

	var dialog_panel := PanelContainer.new()
	dialog_panel.name = "RespecDialogPanel"
	dialog_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_panel.add_theme_stylebox_override("panel", dialog_style)
	_respec_dialog.add_child(dialog_panel)

	var dialog_vbox := VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 10)
	dialog_panel.add_child(dialog_vbox)

	var warn_lbl := Label.new()
	warn_lbl.text = "RESPEC DE HABILIDADES"
	warn_lbl.add_theme_font_size_override("font_size", FONT_SECTION)
	warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2, 1.0))
	warn_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	warn_lbl.add_theme_constant_override("outline_size", 3)
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_vbox.add_child(warn_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "Se consumiran 10 Hierba Antigua.\nTodos los puntos seran devueltos.\nEsta accion no se puede deshacer."
	info_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	info_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.9))
	info_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	info_lbl.add_theme_constant_override("outline_size", 2)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_vbox.add_child(info_lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_vbox.add_child(btn_hbox)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelRespecButton"
	cancel_btn.text = "CANCELAR"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, 52)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1.0))
	cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.18, 0.18, 0.22, 0.9)
	cancel_style.corner_radius_top_left     = 7
	cancel_style.corner_radius_top_right    = 7
	cancel_style.corner_radius_bottom_left  = 7
	cancel_style.corner_radius_bottom_right = 7
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.pressed.connect(_hide_respec_dialog)
	btn_hbox.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmRespecButton"
	confirm_btn.text = "CONFIRMAR RESPEC"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size = Vector2(0, 52)
	confirm_btn.add_theme_font_size_override("font_size", 14)
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2, 1.0))
	confirm_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	confirm_btn.add_theme_constant_override("outline_size", 3)
	confirm_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.28, 0.16, 0.03, 0.9)
	confirm_style.corner_radius_top_left     = 7
	confirm_style.corner_radius_top_right    = 7
	confirm_style.corner_radius_bottom_left  = 7
	confirm_style.corner_radius_bottom_right = 7
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.pressed.connect(_on_respec_confirmed)
	btn_hbox.add_child(confirm_btn)

	parent.add_child(_respec_dialog)


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


func _branch_color(branch: int) -> Color:
	match branch:
		0: return COLOR_BRANCH_GUERRERO  # SkillNode.Branch.GUERRERO
		1: return COLOR_BRANCH_MAGO
		2: return COLOR_BRANCH_AGIL
	return Color(0.7, 0.7, 0.75, 0.8)


# ─── Refresco de UI ──────────────────────────────────────────────────────────

func _refresh_header_info() -> void:
	var lvl: int  = PlayerProgression.get_level()
	var xp: int   = PlayerProgression.get_xp()
	var xp_next: int = PlayerProgression.get_xp_for_next_level()
	var pts: int  = PlayerProgression.get_skill_points_available()

	_level_info_lbl.text = "Nivel %d  ·  XP %d / %d" % [lvl, xp, xp_next]
	_points_info_lbl.text = "Puntos: %d" % pts

	if pts > 0:
		_points_info_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55, 1.0))
	else:
		_points_info_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 0.8))

	# Respec — actualizar texto con count de hierba actual.
	var hierba_count: int = InventorySystem.get_material_count(PlayerProgression.RESPEC_MATERIAL_ID)
	_respec_btn.text = "Respec  %d/%d Hierba" % [hierba_count, PlayerProgression.RESPEC_MATERIAL_COUNT]


func _refresh_tabs() -> void:
	# Resalta el tab activo con borde inferior más grueso y fondo más brillante.
	var branch_colors: Array[Color] = [COLOR_BRANCH_GUERRERO, COLOR_BRANCH_MAGO, COLOR_BRANCH_AGIL]
	for i in range(3):
		var btn: Button = _tab_buttons[i]
		var col: Color = branch_colors[i]

		if i == _active_branch:
			var tab_active := StyleBoxFlat.new()
			tab_active.bg_color = Color(col.r, col.g, col.b, 0.28)
			tab_active.border_color = col
			tab_active.border_width_bottom = 3
			btn.add_theme_stylebox_override("normal", tab_active)
			btn.add_theme_stylebox_override("hover",  tab_active)
		else:
			var tab_inactive := StyleBoxFlat.new()
			tab_inactive.bg_color = Color(col.r, col.g, col.b, 0.07)
			tab_inactive.border_color = Color(col.r, col.g, col.b, 0.22)
			tab_inactive.border_width_bottom = 2
			btn.add_theme_stylebox_override("normal", tab_inactive)
			var tab_hover := StyleBoxFlat.new()
			tab_hover.bg_color = Color(col.r, col.g, col.b, 0.16)
			tab_hover.border_color = Color(col.r, col.g, col.b, 0.5)
			tab_hover.border_width_bottom = 2
			btn.add_theme_stylebox_override("hover", tab_hover)


func _refresh_node_grid() -> void:
	# Limpia el grid y reconstruye con los nodos del branch activo, agrupados por tier.
	for child in _node_grid_vbox.get_children():
		child.queue_free()
	_node_buttons.clear()

	var skill_tree: SkillTree = PlayerProgression.get_skill_tree()
	if skill_tree == null:
		var empty := _make_label("(árbol no cargado)", FONT_BODY, Color(0.5, 0.5, 0.55, 0.7))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_node_grid_vbox.add_child(empty)
		return

	# Obtener nodos del branch activo.
	var branch_enum := _active_branch as SkillNode.Branch
	var nodes: Array[SkillNode] = skill_tree.get_nodes_by_branch(branch_enum)

	if nodes.is_empty():
		var empty := _make_label("(sin nodos en esta rama)", FONT_BODY, Color(0.5, 0.5, 0.55, 0.7))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_node_grid_vbox.add_child(empty)
		return

	# Agrupar por tier 1-5.
	var tiers: Dictionary = {}
	for node in nodes:
		if not tiers.has(node.tier):
			tiers[node.tier] = []
		tiers[node.tier].append(node)

	# Tier labels para orientar al jugador.
	var tier_names := {1: "NIVEL BASICO", 2: "INTERMEDIO", 3: "AVANZADO", 4: "EXPERTO", 5: "MAESTRIA"}

	var branch_col := _branch_color(_active_branch)

	for tier in range(1, 6):
		if not tiers.has(tier):
			continue

		# Header del tier.
		var tier_hdr := ColorRect.new()
		tier_hdr.name = "TierHdr_%d" % tier
		tier_hdr.color = Color(branch_col.r, branch_col.g, branch_col.b, 0.12)
		tier_hdr.custom_minimum_size = Vector2(0, 28)
		tier_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var tier_lbl := Label.new()
		tier_lbl.text = "TIER %d  —  %s" % [tier, tier_names.get(tier, "")]
		tier_lbl.add_theme_font_size_override("font_size", 10)
		tier_lbl.add_theme_color_override("font_color", Color(branch_col.r, branch_col.g, branch_col.b, 0.7))
		tier_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tier_lbl.add_theme_constant_override("outline_size", 2)
		tier_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		tier_lbl.offset_left = 10.0
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tier_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tier_hdr.add_child(tier_lbl)
		_node_grid_vbox.add_child(tier_hdr)

		# HBox con los nodos del tier.
		var tier_hbox := HBoxContainer.new()
		tier_hbox.name = "TierHBox_%d" % tier
		tier_hbox.add_theme_constant_override("separation", 8)
		tier_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Padding horizontal para que los nodos no peguen al borde.
		var hbox_ctrl := Control.new()
		hbox_ctrl.name = "TierRow_%d" % tier
		hbox_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox_ctrl.custom_minimum_size = Vector2(0, NODE_BTN_SIZE.y + 16)
		hbox_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_node_grid_vbox.add_child(hbox_ctrl)

		tier_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		tier_hbox.offset_left   = 8.0
		tier_hbox.offset_right  = -8.0
		tier_hbox.offset_top    = 8.0
		tier_hbox.offset_bottom = -8.0
		hbox_ctrl.add_child(tier_hbox)

		for node_data: SkillNode in tiers[tier]:
			var node_ctrl := _make_node_button(node_data)
			tier_hbox.add_child(node_ctrl)
			_node_buttons[node_data.id] = node_ctrl

		# Separador entre tiers.
		var tier_sep := ColorRect.new()
		tier_sep.color = Color(branch_col.r, branch_col.g, branch_col.b, 0.18)
		tier_sep.custom_minimum_size = Vector2(0, 1)
		tier_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_node_grid_vbox.add_child(tier_sep)


func _make_node_button(node_data: SkillNode) -> Control:
	# Contenedor del nodo — hit area mínima 64×64 dp.
	var is_unlocked: bool  = PlayerProgression.is_unlocked(node_data.id)
	var can_unlock: bool   = PlayerProgression.can_unlock(node_data.id)

	var border_col: Color
	var bg_col: Color
	var icon_alpha: float

	if is_unlocked:
		border_col = COLOR_NODE_UNLOCKED
		bg_col     = Color(COLOR_NODE_UNLOCKED.r, COLOR_NODE_UNLOCKED.g, COLOR_NODE_UNLOCKED.b, 0.18)
		icon_alpha = 1.0
	elif can_unlock:
		border_col = COLOR_NODE_AVAILABLE
		bg_col     = Color(COLOR_NODE_AVAILABLE.r, COLOR_NODE_AVAILABLE.g, COLOR_NODE_AVAILABLE.b, 0.12)
		icon_alpha = 1.0
	else:
		border_col = COLOR_NODE_LOCKED
		bg_col     = Color(0.1, 0.1, 0.12, 0.6)
		icon_alpha = 0.4

	var outer := ColorRect.new()
	outer.name = "NodeBtn_%s" % str(node_data.id)
	outer.color = bg_col
	outer.custom_minimum_size = NODE_BTN_SIZE
	outer.mouse_filter = Control.MOUSE_FILTER_STOP

	# Borde del nodo (franja superior coloreada según estado).
	var border_top := ColorRect.new()
	border_top.color = border_col
	border_top.anchor_left   = 0.0
	border_top.anchor_right  = 1.0
	border_top.anchor_top    = 0.0
	border_top.anchor_bottom = 0.0
	border_top.offset_bottom = 3.0
	border_top.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(border_top)

	# Ícono del nodo (ColorRect coloreado por rama — placeholder hasta sprites).
	# TODO: reemplazar por TextureRect cuando haya sprites de skills.
	var branch_col := _branch_color(node_data.branch as int)
	var icon := ColorRect.new()
	icon.name = "NodeIcon"
	icon.color = Color(branch_col.r, branch_col.g, branch_col.b, icon_alpha * 0.7)
	icon.anchor_left   = 0.15
	icon.anchor_right  = 0.85
	icon.anchor_top    = 0.12
	icon.anchor_bottom = 0.62
	icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(icon)

	# Nombre del nodo (corto, cabe en 2 líneas max).
	var name_lbl := Label.new()
	name_lbl.text = node_data.display_name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, icon_alpha))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.anchor_left   = 0.0
	name_lbl.anchor_right  = 1.0
	name_lbl.anchor_top    = 0.62
	name_lbl.anchor_bottom = 1.0
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(name_lbl)

	# Badge de estado — dorado si desbloqueado, verde si disponible, invisible si bloqueado.
	if is_unlocked:
		var badge := Label.new()
		badge.name = "UnlockedBadge"
		badge.text = "OK"
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", COLOR_NODE_UNLOCKED)
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		badge.add_theme_constant_override("outline_size", 2)
		badge.anchor_left   = 0.0
		badge.anchor_right  = 0.0
		badge.anchor_top    = 0.0
		badge.anchor_bottom = 0.0
		badge.offset_right  = 28.0
		badge.offset_bottom = 14.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(badge)
	elif can_unlock:
		var badge := Label.new()
		badge.name = "AvailableBadge"
		badge.text = "+"
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", COLOR_NODE_AVAILABLE)
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		badge.add_theme_constant_override("outline_size", 3)
		badge.anchor_left   = 0.0
		badge.anchor_right  = 0.0
		badge.anchor_top    = 0.0
		badge.anchor_bottom = 0.0
		badge.offset_right  = 20.0
		badge.offset_bottom = 20.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer.add_child(badge)

	# Tap en el nodo → seleccionar y llenar DetailPanel.
	outer.gui_input.connect(func(event: InputEvent) -> void:
		if _is_animating or _respec_dialog_visible:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_node(node_data.id)
		elif event is InputEventScreenTouch and event.pressed:
			_select_node(node_data.id)
	)

	return outer


func _refresh_node_visual(node_id: StringName) -> void:
	# Actualiza el visual de un nodo específico sin reconstruir el grid completo.
	var ctrl: Control = _node_buttons.get(node_id)
	if ctrl == null or not is_instance_valid(ctrl):
		return

	var skill_tree: SkillTree = PlayerProgression.get_skill_tree()
	if skill_tree == null:
		return
	var node_data: SkillNode = skill_tree.get_node_by_id(node_id)
	if node_data == null:
		return

	var is_unlocked: bool = PlayerProgression.is_unlocked(node_id)
	var can_unlock: bool  = PlayerProgression.can_unlock(node_id)

	var border_col: Color
	var bg_col: Color
	var icon_alpha: float

	if is_unlocked:
		border_col = COLOR_NODE_UNLOCKED
		bg_col     = Color(COLOR_NODE_UNLOCKED.r, COLOR_NODE_UNLOCKED.g, COLOR_NODE_UNLOCKED.b, 0.18)
		icon_alpha = 1.0
	elif can_unlock:
		border_col = COLOR_NODE_AVAILABLE
		bg_col     = Color(COLOR_NODE_AVAILABLE.r, COLOR_NODE_AVAILABLE.g, COLOR_NODE_AVAILABLE.b, 0.12)
		icon_alpha = 1.0
	else:
		border_col = COLOR_NODE_LOCKED
		bg_col     = Color(0.1, 0.1, 0.12, 0.6)
		icon_alpha = 0.4

	(ctrl as ColorRect).color = bg_col

	var border_top: ColorRect = ctrl.get_node_or_null("NodeBtn_%s/..." % str(node_id))
	# Actualizar el borde superior — es el primer hijo ColorRect.
	if ctrl.get_child_count() > 0:
		var brd := ctrl.get_child(0) as ColorRect
		if brd != null:
			brd.color = border_col

	# Actualizar ícono (segundo hijo).
	if ctrl.get_child_count() > 1:
		var icon_node := ctrl.get_child(1) as ColorRect
		if icon_node != null:
			var branch_col := _branch_color(node_data.branch as int)
			icon_node.color = Color(branch_col.r, branch_col.g, branch_col.b, icon_alpha * 0.7)

	# Actualizar nombre (tercer hijo).
	if ctrl.get_child_count() > 2:
		var lbl := ctrl.get_child(2) as Label
		if lbl != null:
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, icon_alpha))


func _select_node(node_id: StringName) -> void:
	_selected_node_id = node_id
	_refresh_detail(node_id)
	_refresh_unlock_button()


func _refresh_detail(node_id: StringName) -> void:
	if node_id == &"":
		_clear_detail()
		return

	var skill_tree: SkillTree = PlayerProgression.get_skill_tree()
	if skill_tree == null:
		return
	var node_data: SkillNode = skill_tree.get_node_by_id(node_id)
	if node_data == null:
		return

	var branch_col := _branch_color(node_data.branch as int)

	# Nombre con color de rama.
	_detail_name_lbl.text = node_data.display_name
	_detail_name_lbl.add_theme_color_override("font_color", branch_col)

	# Descripción.
	_detail_desc_lbl.text = node_data.description if node_data.description != "" else "(sin descripción)"

	# Efectos — reconstruir lista.
	for child in _detail_effects_vbox.get_children():
		child.queue_free()

	if node_data.effects.is_empty():
		var no_fx := _make_label("(sin efectos definidos)", FONT_SMALL, Color(0.55, 0.55, 0.6, 0.7))
		_detail_effects_vbox.add_child(no_fx)
	else:
		for effect: SkillEffect in node_data.effects:
			var effect_text := _format_effect(effect)
			var is_unlocked := PlayerProgression.is_unlocked(node_id)
			var fx_col: Color = Color(0.5, 0.95, 0.6, 0.9) if is_unlocked else Color(0.75, 0.9, 1.0, 0.85)
			var fx_lbl := _make_label(effect_text, FONT_BODY, fx_col)
			_detail_effects_vbox.add_child(fx_lbl)

	# Prerrequisitos — reconstruir lista.
	for child in _detail_prereqs_vbox.get_children():
		child.queue_free()

	if node_data.prerequisites.is_empty():
		var no_prereq := _make_label("Ninguno (nodo raíz)", FONT_SMALL, Color(0.5, 0.85, 0.5, 0.8))
		_detail_prereqs_vbox.add_child(no_prereq)
	else:
		var skill_tree_ref: SkillTree = PlayerProgression.get_skill_tree()
		for prereq_id: StringName in node_data.prerequisites:
			var prereq_node: SkillNode = null
			if skill_tree_ref != null:
				prereq_node = skill_tree_ref.get_node_by_id(prereq_id)
			var prereq_name: String = prereq_node.display_name if prereq_node != null else str(prereq_id)
			var is_met: bool = PlayerProgression.is_unlocked(prereq_id)
			var prereq_col: Color = Color(0.5, 0.9, 0.5, 0.9) if is_met else Color(0.95, 0.35, 0.35, 0.95)
			var prefix: String = "OK  " if is_met else "FALTA  "
			var req_lbl := _make_label("%s%s" % [prefix, prereq_name], FONT_SMALL, prereq_col)
			_detail_prereqs_vbox.add_child(req_lbl)


func _format_effect(effect: SkillEffect) -> String:
	# Formatea un SkillEffect a texto legible para el jugador.
	# Todos los Stat del enum SkillEffect — actualizar si se agregan más.
	var stat_names := {
		SkillEffect.Stat.HEALTH_MAX:          "HP Maximo",
		SkillEffect.Stat.DAMAGE_FLAT:         "Daño Fisico",
		SkillEffect.Stat.DAMAGE_PCT:          "Daño",
		SkillEffect.Stat.DEFENSE_FLAT:        "Defensa",
		SkillEffect.Stat.DEFENSE_PCT:         "Defensa",
		SkillEffect.Stat.FURIA_MAX:           "Furia Maxima",
		SkillEffect.Stat.FURIA_GAIN_PCT:      "Furia por Golpe",
		SkillEffect.Stat.FURIA_REGEN_FLAT:    "Regen Furia/s",
		SkillEffect.Stat.DASH_COOLDOWN_PCT:   "CD Dash",
		SkillEffect.Stat.MOVE_SPEED_PCT:      "Velocidad",
		SkillEffect.Stat.ELEMENTAL_DAMAGE_PCT:"Daño Elemental",
		SkillEffect.Stat.IFRAMES_PCT:         "I-Frames",
		SkillEffect.Stat.BLOCK_CHARGES:       "Cargas de Escudo",
		SkillEffect.Stat.CRIT_PCT:            "Critico (futuro)",
		SkillEffect.Stat.ELEMENTAL_ADV_MULT:  "Bonus Elemental (futuro)",
		SkillEffect.Stat.EVADE_PCT:           "Esquiva (futuro)",
		SkillEffect.Stat.POST_DASH_DAMAGE_PCT:"Daño Tras Dash",
	}
	var stat_name: String = stat_names.get(effect.stat, "Stat (%d)" % effect.stat)
	var amount_str: String
	if effect.mode == SkillEffect.Mode.PCT:
		# DASH_COOLDOWN_PCT suele ser negativo — mostrar signo correcto.
		var pct_val: float = effect.amount * 100.0
		if pct_val >= 0.0:
			amount_str = "+%.0f%%" % pct_val
		else:
			amount_str = "%.0f%%" % pct_val
	else:
		if effect.amount >= 0.0:
			amount_str = "+%.0f" % effect.amount
		else:
			amount_str = "%.0f" % effect.amount

	return "%s  %s" % [amount_str, stat_name]


func _clear_detail() -> void:
	_detail_name_lbl.text = "Seleccioná un nodo"
	_detail_name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.6))
	_detail_desc_lbl.text = ""
	for child in _detail_effects_vbox.get_children():
		child.queue_free()
	for child in _detail_prereqs_vbox.get_children():
		child.queue_free()
	_unlock_btn.text = "DESBLOQUEAR"
	_unlock_btn.disabled = true
	_unlock_blocked_lbl.visible = false


func _refresh_unlock_button() -> void:
	if _selected_node_id == &"":
		_unlock_btn.text = "DESBLOQUEAR"
		_unlock_btn.disabled = true
		_unlock_blocked_lbl.visible = false
		return

	var is_unlocked: bool = PlayerProgression.is_unlocked(_selected_node_id)

	if is_unlocked:
		_unlock_btn.text = "YA DESBLOQUEADO"
		_unlock_btn.disabled = true
		_unlock_blocked_lbl.visible = false
		return

	var can_unlock: bool = PlayerProgression.can_unlock(_selected_node_id)
	var pts: int = PlayerProgression.get_skill_points_available()

	# Obtener costo del nodo.
	var skill_tree: SkillTree = PlayerProgression.get_skill_tree()
	var point_cost: int = 1
	if skill_tree != null:
		var node_data: SkillNode = skill_tree.get_node_by_id(_selected_node_id)
		if node_data != null:
			point_cost = node_data.point_cost

	if can_unlock:
		_unlock_btn.text = "DESBLOQUEAR  ·  %d punto%s" % [point_cost, "s" if point_cost != 1 else ""]
		_unlock_btn.disabled = false
		_unlock_blocked_lbl.visible = false
	elif pts < point_cost:
		_unlock_btn.text = "DESBLOQUEAR"
		_unlock_btn.disabled = true
		_unlock_blocked_lbl.text = "Necesitás %d punto%s (tenés %d)." % [point_cost, "s" if point_cost != 1 else "", pts]
		_unlock_blocked_lbl.visible = true
	else:
		# can_unlock falla por prereqs.
		_unlock_btn.text = "DESBLOQUEAR"
		_unlock_btn.disabled = true
		_unlock_blocked_lbl.text = "Prerrequisito no cumplido."
		_unlock_blocked_lbl.visible = true


func _refresh_all() -> void:
	_refresh_header_info()
	_refresh_tabs()
	_refresh_node_grid()
	if _selected_node_id != &"":
		_refresh_detail(_selected_node_id)
	_refresh_unlock_button()


# ─── Handlers de interacción ─────────────────────────────────────────────────

func _on_tab_pressed(branch_idx: int) -> void:
	if _is_animating or _respec_dialog_visible:
		return
	_active_branch = branch_idx
	_selected_node_id = &""
	_refresh_tabs()
	_refresh_node_grid()
	_clear_detail()


func _on_unlock_btn_pressed() -> void:
	if _selected_node_id == &"" or _is_animating or _respec_dialog_visible:
		return

	var success: bool = PlayerProgression.unlock_node(_selected_node_id)
	if success:
		_play_unlock_burst(_selected_node_id)
	else:
		# Caso raro (condición de carrera entre chequeo y acción).
		_unlock_blocked_lbl.text = "No se pudo desbloquear."
		_unlock_blocked_lbl.visible = true


func _on_respec_btn_pressed() -> void:
	if _is_animating:
		return

	var unlocked_ids: Array[StringName] = PlayerProgression.get_unlocked_node_ids()
	var hierba: int = InventorySystem.get_material_count(PlayerProgression.RESPEC_MATERIAL_ID)

	if unlocked_ids.is_empty():
		_show_toast("No hay nada que respecar.")
		return

	if hierba < PlayerProgression.RESPEC_MATERIAL_COUNT:
		var falta: int = PlayerProgression.RESPEC_MATERIAL_COUNT - hierba
		_show_toast("Necesitás %d Hierba Antigua más (tenés %d)." % [PlayerProgression.RESPEC_MATERIAL_COUNT, hierba])
		return

	_show_respec_dialog()


func _on_respec_confirmed() -> void:
	_hide_respec_dialog()
	_is_animating = true

	# Flash de "reset" — todos los nodos parpadean brevemente y luego vuelven a gris.
	var tween := create_tween()
	tween.tween_property(_node_grid_vbox, "modulate:a", 0.15, 0.18)
	tween.tween_property(_node_grid_vbox, "modulate:a", 1.0, 0.18)
	tween.tween_callback(func() -> void:
		var success: bool = PlayerProgression.respec()
		if success:
			# Señal respec_done se dispara y refrescará en _on_respec_done.
			pass
		else:
			_is_animating = false
			_show_toast("No se pudo respecar.")
	)


func _on_debug_xp_pressed() -> void:
	# TODO: remover antes de producción.
	PlayerProgression.add_xp(100)
	_refresh_header_info()


func _show_respec_dialog() -> void:
	_respec_dialog_visible = true
	_respec_dialog.visible = true


func _hide_respec_dialog() -> void:
	_respec_dialog_visible = false
	_respec_dialog.visible = false


func _show_toast(msg: String) -> void:
	# Mensaje breve en el label de bloqueo del botón unlock — reutilizamos el label existente.
	_unlock_blocked_lbl.text = msg
	_unlock_blocked_lbl.visible = true
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_unlock_blocked_lbl):
			_unlock_blocked_lbl.visible = false
	)


# ─── Animación de desbloqueo ─────────────────────────────────────────────────

func _play_unlock_burst(node_id: StringName) -> void:
	# Burst visual: flash dorado sobre el overlay por 0.45s, luego refrescar UI.
	_is_animating = true
	_burst_label.text = "DESBLOQUEADO"
	_burst_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_burst_overlay.visible = true

	var tween := create_tween()
	tween.tween_property(_burst_overlay, "color", Color(0.12, 0.1, 0.02, 0.82), 0.08)
	tween.tween_property(_burst_overlay, "color", Color(0.25, 0.2, 0.0, 0.72), ANIM_UNLOCK_DURATION * 0.4)
	tween.tween_property(_burst_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), ANIM_UNLOCK_DURATION * 0.4)
	tween.tween_callback(func() -> void:
		_burst_overlay.visible = false
		_is_animating = false
		# Refrescar nodo visual y header sin reconstruir el grid completo.
		_refresh_node_visual(node_id)
		_refresh_header_info()
		_refresh_detail(node_id)
		_refresh_unlock_button()
		# Puede que otros nodos ahora sean disponibles (prereqs cumplidos).
		_refresh_all_node_visuals()
	)


func _refresh_all_node_visuals() -> void:
	# Refresca el estado visual de todos los nodos en el grid actual.
	for node_id in _node_buttons:
		_refresh_node_visual(node_id)


# ─── Conexiones de signals ────────────────────────────────────────────────────

func _connect_signals() -> void:
	PlayerProgression.level_up.connect(_on_level_up)
	PlayerProgression.skill_unlocked.connect(_on_skill_unlocked)
	PlayerProgression.respec_done.connect(_on_respec_done)
	PlayerProgression.stats_changed.connect(_on_stats_changed)
	PlayerProgression.xp_gained.connect(_on_xp_gained)


func _on_level_up(new_level: int, points_awarded: int) -> void:
	if not _is_open:
		return
	_refresh_header_info()
	# Badge de puntos ganados visible en el label de puntos.
	_points_info_lbl.text = "Puntos: %d  (+%d)" % [PlayerProgression.get_skill_points_available(), points_awarded]
	# Animar el label para llamar atención.
	var tween := create_tween()
	tween.tween_property(_points_info_lbl, "modulate", Color(1.5, 1.5, 0.5, 1.0), 0.15)
	tween.tween_property(_points_info_lbl, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
	# Refrescar grid (pueden haber nodos disponibles nuevos).
	_refresh_node_grid()


func _on_skill_unlocked(_node: SkillNode) -> void:
	if not _is_open:
		return
	# El burst ya se disparó antes desde _on_unlock_btn_pressed —
	# este signal llega después. Solo necesitamos asegurar consistencia si
	# el unlock vino de otra fuente.
	_refresh_header_info()


func _on_respec_done(_refunded_points: int) -> void:
	_is_animating = false
	if not _is_open:
		return
	# Reconstruir todo — todos los nodos vuelven a estado inicial.
	_selected_node_id = &""
	_refresh_all()
	_show_toast("Puntos restaurados. Respec completado.")


func _on_stats_changed() -> void:
	if not _is_open:
		return
	_refresh_header_info()


func _on_xp_gained(_amount: int, _total_xp: int) -> void:
	if not _is_open:
		return
	_refresh_header_info()
