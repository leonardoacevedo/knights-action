extends CanvasLayer
class_name CraftingScreen

## Pantalla de Crafteo (Forja). GDD §5.5 / Pilar #1 y #2.
##
## Muestra todas las recetas disponibles en una lista. Al seleccionar una,
## el panel derecho muestra el output esperado, los materiales requeridos con
## estado de disponibilidad y el botón FORJAR.
##
## El crafteo en MVP es 100% determinístico — si tenés los materiales, funciona.
## Pilar #2: el jugador siempre sabe exactamente qué falta y por qué.
##
## Flujo:
##   Abrir → lista de recetas → seleccionar → ver detalle →
##   FORJAR → animación (0.8-1.2s) → reveal resultado → UI se refresca.
##
## Trigger de apertura: InventoryScreen expone open_crafting().
## Fallback de testing: tecla C (sin selección previa).
##
## Conexiones autoload:
##   CraftingSystem — recetas y acción de crafteo.
##   InventorySystem — consulta de materiales y signals de cambio.


# ─── Colores compartidos con RefinementScreen / InventoryScreen ───────────────

const COLOR_R1 := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_R2 := Color(0.3, 0.6, 1.0, 0.7)
const COLOR_R3 := Color(0.7, 0.3, 0.9, 0.8)
const COLOR_R4 := Color(1.0, 0.75, 0.2, 0.9)

const COLOR_PANEL_BG   := Color(0.07, 0.07, 0.1,  0.97)
const COLOR_HEADER_BG  := Color(0.05, 0.05, 0.08, 1.0)
const COLOR_SECTION_BG := Color(0.1,  0.1,  0.15, 0.8)
const COLOR_ITEM_BG    := Color(0.1,  0.1,  0.16, 0.9)
const COLOR_ITEM_SEL   := Color(0.15, 0.15, 0.25, 0.95)

# Verde / rojo para estado de materiales.
const COLOR_MAT_OK  := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_MAT_MISS := Color(0.95, 0.35, 0.2, 1.0)

# Resultado de animación.
const COLOR_RESULT_SUCCESS := Color(1.0, 0.88, 0.2, 1.0)  # dorado
const COLOR_RESULT_FAIL    := Color(0.9, 0.25, 0.25, 1.0)  # rojo

# Fuentes — idénticas a RefinementScreen para coherencia visual.
const FONT_TITLE   := 22
const FONT_SECTION := 15
const FONT_BODY    := 14
const FONT_SMALL   := 12

# Duración de animación de forja — suspenso corto, determinístico.
const ANIM_FORGE_DURATION  := 1.0  # segundos
const ANIM_FLASH_DURATION  := 0.3


# ─── Nodos construidos proceduralmente ───────────────────────────────────────

var _panel: PanelContainer
var _close_btn: Button

# Columna izquierda — lista de recetas.
var _recipe_list_vbox: VBoxContainer
var _recipe_rows: Dictionary = {}  # CraftRecipe → Control (wrapper)

# Panel de detalle — receta seleccionada.
var _detail_output_icon: ColorRect
var _detail_output_name: Label
var _detail_output_rarity: Label
var _detail_output_stat: Label
var _detail_description: Label
var _detail_inputs_vbox: VBoxContainer  # filas de materiales
var _detail_gold_label: Label
var _detail_empty_label: Label  # placeholder "seleccioná una receta"

# Fila de acción.
var _craft_btn: Button
var _craft_blocked_label: Label

# Overlay de animación (fullscreen dentro del panel).
var _anim_overlay: ColorRect
var _anim_label: Label
var _anim_sub_label: Label


# ─── Estado ──────────────────────────────────────────────────────────────────

var _selected_recipe: CraftRecipe = null
var _is_open: bool = false
var _is_animating: bool = false


# ─── Ciclo de vida ───────────────────────────────────────────────────────────

func _ready() -> void:
	# Layer 26 — sobre InventoryScreen (20) y RefinementScreen (25), debajo de Game Over.
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_build_ui()
	_connect_signals()


# ─── API pública ─────────────────────────────────────────────────────────────

## Abre la pantalla de crafteo.
## Llamado desde InventoryScreen al pulsar el botón FORJA.
func open() -> void:
	if _is_animating:
		return
	_is_open = true
	visible = true
	get_tree().paused = true
	_refresh_recipe_list()
	# Preseleccionar la primera receta crafteable, o la primera de la lista.
	var recipes := CraftingSystem.get_all_recipes()
	if not recipes.is_empty():
		# Preferir una crafteable como preselección.
		var presel: CraftRecipe = null
		for r in recipes:
			if CraftingSystem.can_craft(r):
				presel = r
				break
		if presel == null:
			presel = recipes[0]
		_select_recipe(presel)
	else:
		_select_recipe(null)


func close() -> void:
	if _is_animating:
		return
	_is_open = false
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

	# Tecla C — solo para testing rápido. TODO: remover o mover a debug build.
	if event is InputEventKey and event.physical_keycode == KEY_C:
		if not _is_open:
			open()
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
	# Fondo oscuro bloqueante — tap fuera del panel cierra.
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(ev: InputEvent) -> void:
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

	# Panel principal — mismo porcentaje que RefinementScreen.
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

	# Layout vertical principal.
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
	hbox.offset_left  = 16.0
	hbox.offset_right = 0.0
	header.add_child(hbox)

	var title_lbl := Label.new()
	title_lbl.text = "FORJA"
	title_lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(title_lbl)

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

	# Separador debajo del header.
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_body(parent: Control) -> void:
	# Cuerpo: lista de recetas (izquierda fija) | detalle + acción (derecha expandible).
	var body_hbox := HBoxContainer.new()
	body_hbox.name = "BodyHBox"
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 0)
	parent.add_child(body_hbox)

	_build_recipe_list_column(body_hbox)

	# Separador vertical.
	var vsep := ColorRect.new()
	vsep.color = Color(0.3, 0.3, 0.5, 0.3)
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(vsep)

	_build_detail_column(body_hbox)


func _build_recipe_list_column(parent: Control) -> void:
	# Columna izquierda — ~38% del ancho del panel.
	var col := VBoxContainer.new()
	col.name = "RecipeListColumn"
	col.custom_minimum_size = Vector2(165, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	var hdr := _make_section_header("RECETAS")
	col.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.name = "RecipeListScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_recipe_list_vbox = VBoxContainer.new()
	_recipe_list_vbox.name = "RecipeListVBox"
	_recipe_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_recipe_list_vbox)


func _build_detail_column(parent: Control) -> void:
	# Columna derecha — scrollable para mobile (contenido largo posible).
	var outer_vbox := VBoxContainer.new()
	outer_vbox.name = "DetailOuterVBox"
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 0)
	parent.add_child(outer_vbox)

	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var col := VBoxContainer.new()
	col.name = "DetailColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	scroll.add_child(col)

	_build_output_preview(col)
	_build_description_section(col)
	_build_inputs_section(col)
	_build_gold_row(col)
	_build_action_row(outer_vbox)


func _build_output_preview(parent: Control) -> void:
	var hdr := _make_section_header("RESULTADO")
	parent.add_child(hdr)

	# Placeholder "seleccioná una receta" cuando nada está seleccionado.
	_detail_empty_label = _make_label(
		"Seleccioná una receta de la lista.",
		FONT_BODY,
		Color(0.55, 0.55, 0.6, 0.7)
	)
	_detail_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_empty_label.custom_minimum_size = Vector2(0, 80)
	_detail_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_detail_empty_label)

	# Panel de preview del output — visible al seleccionar receta.
	var preview := ColorRect.new()
	preview.name = "OutputPreview"
	preview.color = COLOR_ITEM_BG
	preview.custom_minimum_size = Vector2(0, 110)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(preview)

	# Icono de output — ColorRect coloreado por rareza (placeholder hasta sprites).
	# Posición: izquierda del preview, 72×72.
	_detail_output_icon = ColorRect.new()
	_detail_output_icon.name = "OutputIcon"
	_detail_output_icon.color = COLOR_R1
	_detail_output_icon.anchor_left   = 0.0
	_detail_output_icon.anchor_right  = 0.0
	_detail_output_icon.anchor_top    = 0.5
	_detail_output_icon.anchor_bottom = 0.5
	_detail_output_icon.offset_left   = 12.0
	_detail_output_icon.offset_right  = 76.0
	_detail_output_icon.offset_top    = -36.0
	_detail_output_icon.offset_bottom = 36.0
	_detail_output_icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_detail_output_icon)
	# TODO: reemplazar por TextureRect cuando haya sprites de items.

	# Info del output — nombre, rareza, stat.
	var info_vbox := VBoxContainer.new()
	info_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_vbox.offset_left   = 90.0
	info_vbox.offset_top    = 10.0
	info_vbox.offset_right  = -12.0
	info_vbox.offset_bottom = -10.0
	info_vbox.add_theme_constant_override("separation", 4)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(info_vbox)

	_detail_output_name = _make_label("", FONT_SECTION, Color(1, 1, 1, 1))
	_detail_output_name.clip_text = true
	info_vbox.add_child(_detail_output_name)

	_detail_output_rarity = _make_label("", FONT_SMALL, Color(0.7, 0.7, 0.8, 0.85))
	info_vbox.add_child(_detail_output_rarity)

	_detail_output_stat = _make_label("", FONT_BODY, Color(0.75, 0.9, 1.0, 0.9))
	info_vbox.add_child(_detail_output_stat)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_description_section(parent: Control) -> void:
	var hdr := _make_section_header("DESCRIPCION")
	parent.add_child(hdr)

	var container := ColorRect.new()
	container.name = "DescriptionContainer"
	container.color = Color(0.08, 0.08, 0.12, 0.85)
	container.custom_minimum_size = Vector2(0, 52)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	_detail_description = Label.new()
	_detail_description.name = "DescriptionLabel"
	_detail_description.text = ""
	_detail_description.add_theme_font_size_override("font_size", FONT_BODY)
	_detail_description.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 0.9))
	_detail_description.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_detail_description.add_theme_constant_override("outline_size", 2)
	_detail_description.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_description.offset_left   = 14.0
	_detail_description.offset_right  = -14.0
	_detail_description.offset_top    = 6.0
	_detail_description.offset_bottom = -6.0
	_detail_description.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	_detail_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_detail_description)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_inputs_section(parent: Control) -> void:
	var hdr := _make_section_header("MATERIALES REQUERIDOS")
	parent.add_child(hdr)

	var container := ColorRect.new()
	container.name = "InputsContainer"
	container.color = Color(0.07, 0.07, 0.11, 0.9)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)

	_detail_inputs_vbox = VBoxContainer.new()
	_detail_inputs_vbox.name = "InputsVBox"
	_detail_inputs_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_inputs_vbox.offset_left   = 14.0
	_detail_inputs_vbox.offset_right  = -14.0
	_detail_inputs_vbox.offset_top    = 8.0
	_detail_inputs_vbox.offset_bottom = -8.0
	_detail_inputs_vbox.add_theme_constant_override("separation", 6)
	_detail_inputs_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_detail_inputs_vbox)

	# Altura mínima para que el contenedor no colapse cuando esté vacío.
	container.custom_minimum_size = Vector2(0, 60)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_gold_row(parent: Control) -> void:
	# Fila de oro — siempre 0 en Fase 2, mostrada en gris para indicar que existe.
	var gold_container := ColorRect.new()
	gold_container.name = "GoldContainer"
	gold_container.color = Color(0.06, 0.06, 0.09, 0.85)
	gold_container.custom_minimum_size = Vector2(0, 38)
	gold_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gold_container)

	var gold_hbox := HBoxContainer.new()
	gold_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	gold_hbox.offset_left   = 14.0
	gold_hbox.offset_right  = -14.0
	gold_hbox.add_theme_constant_override("separation", 8)
	gold_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_container.add_child(gold_hbox)

	var gold_icon := ColorRect.new()
	gold_icon.color = Color(0.95, 0.78, 0.2, 0.4)
	gold_icon.custom_minimum_size = Vector2(12, 12)
	gold_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_hbox.add_child(gold_icon)
	# TODO: reemplazar por icono real de oro cuando haya sprites.

	_detail_gold_label = _make_label("Oro: 0  (no implementado en Fase 2)", FONT_SMALL, Color(0.55, 0.55, 0.5, 0.6))
	_detail_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_gold_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gold_hbox.add_child(_detail_gold_label)

	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.25)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_action_row(parent: Control) -> void:
	# Relleno para que la acción empuje hacia abajo cuando el contenido es corto.
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
	_craft_blocked_label = _make_label("", FONT_SMALL, Color(0.9, 0.4, 0.4, 0.9))
	_craft_blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_craft_blocked_label.visible = false
	action_vbox.add_child(_craft_blocked_label)

	# Botón FORJAR — hit area mínima 56dp, verde para diferenciarlo del REFINAR (azul).
	_craft_btn = Button.new()
	_craft_btn.name = "CraftButton"
	_craft_btn.text = "FORJAR"
	_craft_btn.custom_minimum_size = Vector2(0, 56)
	_craft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_btn.add_theme_font_size_override("font_size", 18)
	_craft_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_craft_btn.add_theme_constant_override("outline_size", 4)
	_craft_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_craft_btn.disabled = true

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.42, 0.15, 1.0)
	btn_normal.corner_radius_top_left     = 8
	btn_normal.corner_radius_top_right    = 8
	btn_normal.corner_radius_bottom_left  = 8
	btn_normal.corner_radius_bottom_right = 8
	_craft_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.22, 0.56, 0.22, 1.0)
	btn_hover.corner_radius_top_left     = 8
	btn_hover.corner_radius_top_right    = 8
	btn_hover.corner_radius_bottom_left  = 8
	btn_hover.corner_radius_bottom_right = 8
	_craft_btn.add_theme_stylebox_override("hover",   btn_hover)
	_craft_btn.add_theme_stylebox_override("pressed", btn_hover)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.15, 0.15, 0.2, 0.7)
	btn_disabled.corner_radius_top_left     = 8
	btn_disabled.corner_radius_top_right    = 8
	btn_disabled.corner_radius_bottom_left  = 8
	btn_disabled.corner_radius_bottom_right = 8
	_craft_btn.add_theme_stylebox_override("disabled", btn_disabled)

	_craft_btn.pressed.connect(_on_craft_pressed)
	action_vbox.add_child(_craft_btn)


func _build_anim_overlay(parent: Control) -> void:
	# Overlay de animación — cubre el panel durante la forja.
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


func _rarity_label(rarity: ItemData.Rarity) -> String:
	match rarity:
		ItemData.Rarity.R1: return "Comun"
		ItemData.Rarity.R2: return "Raro"
		ItemData.Rarity.R3: return "Epico"
		ItemData.Rarity.R4: return "Legendario"
	return "?"


func _slot_stat_prefix(slot: ItemData.Slot) -> String:
	match slot:
		ItemData.Slot.ARMA:     return "ATK"
		ItemData.Slot.ARMADURA: return "DEF"
		ItemData.Slot.ESCUDO:   return "BLQ"
	return "STAT"


# ─── Lógica de selección y refresco ──────────────────────────────────────────

func _select_recipe(recipe: CraftRecipe) -> void:
	_selected_recipe = recipe
	_refresh_detail_panel()
	_refresh_craft_button()
	_highlight_selected_recipe_row()


func _refresh_recipe_list() -> void:
	# Limpia y reconstruye la lista completa de recetas.
	for child in _recipe_list_vbox.get_children():
		child.queue_free()
	_recipe_rows.clear()

	var recipes := CraftingSystem.get_all_recipes()

	if recipes.is_empty():
		var empty := _make_label("(sin recetas disponibles)", FONT_SMALL, Color(0.55, 0.55, 0.6, 0.7))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_recipe_list_vbox.add_child(empty)
		return

	for recipe in recipes:
		var row := _make_recipe_row(recipe)
		_recipe_list_vbox.add_child(row)
		_recipe_rows[recipe] = row


func _make_recipe_row(recipe: CraftRecipe) -> Control:
	# Fila de receta — hit area mínima 64dp (mobile). Muestra nombre, rareza del output
	# y un indicador visual de si puede craftearse.
	var can_craft: bool = CraftingSystem.can_craft(recipe)
	var rarity_col: Color = COLOR_R1
	if recipe.output_item != null:
		rarity_col = _rarity_color(recipe.output_item.rarity)

	var outer := ColorRect.new()
	outer.name = "RecipeRow_" + str(recipe.id)
	outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.08)
	outer.custom_minimum_size = Vector2(0, 64)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_STOP

	# Franja de rareza izquierda.
	var rarity_bar := ColorRect.new()
	rarity_bar.color = rarity_col
	rarity_bar.anchor_left   = 0.0
	rarity_bar.anchor_right  = 0.0
	rarity_bar.anchor_top    = 0.0
	rarity_bar.anchor_bottom = 1.0
	rarity_bar.offset_right  = 4.0
	rarity_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rarity_bar)

	# Contenido interno.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 12.0
	vbox.offset_top    = 6.0
	vbox.offset_right  = -30.0  # espacio para el indicador de estado.
	vbox.offset_bottom = -6.0
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(vbox)

	# Nombre de la receta.
	var name_lbl := _make_label(
		recipe.display_name if recipe.display_name != "" else str(recipe.id),
		FONT_SMALL,
		Color(1, 1, 1, 0.92)
	)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	# Rareza del output.
	var rarity_str: String = "R?"
	if recipe.output_item != null:
		rarity_str = _rarity_label(recipe.output_item.rarity)
	var rarity_lbl := _make_label(rarity_str, FONT_SMALL - 1, rarity_col)
	vbox.add_child(rarity_lbl)

	# Indicador de estado — esquina derecha (tick verde / X rojo).
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.text = "OK" if can_craft else "X"
	status_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	status_lbl.add_theme_color_override("font_color", COLOR_MAT_OK if can_craft else COLOR_MAT_MISS)
	status_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	status_lbl.add_theme_constant_override("outline_size", 3)
	status_lbl.anchor_left   = 1.0
	status_lbl.anchor_right  = 1.0
	status_lbl.anchor_top    = 0.5
	status_lbl.anchor_bottom = 0.5
	status_lbl.offset_left   = -26.0
	status_lbl.offset_right  = -4.0
	status_lbl.offset_top    = -10.0
	status_lbl.offset_bottom = 10.0
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(status_lbl)

	# Separador.
	var sep := ColorRect.new()
	sep.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.12)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var wrapper := VBoxContainer.new()
	wrapper.name = "RecipeWrapper_" + str(recipe.id)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 0)
	wrapper.add_child(outer)
	wrapper.add_child(sep)

	# Tap en la fila selecciona la receta.
	outer.gui_input.connect(func(event: InputEvent) -> void:
		if _is_animating:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_recipe(recipe)
		elif event is InputEventScreenTouch and event.pressed:
			_select_recipe(recipe)
	)

	return wrapper


func _highlight_selected_recipe_row() -> void:
	for recipe in _recipe_rows:
		var wrapper: Control = _recipe_rows[recipe]
		if wrapper == null or not is_instance_valid(wrapper):
			continue
		var outer: ColorRect = wrapper.get_child(0) as ColorRect
		if outer == null:
			continue
		var rarity_col: Color = COLOR_R1
		if recipe.output_item != null:
			rarity_col = _rarity_color(recipe.output_item.rarity)
		if recipe == _selected_recipe:
			outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.28)
		else:
			outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.08)


func _refresh_detail_panel() -> void:
	if _selected_recipe == null:
		_detail_empty_label.visible = true
		_detail_output_icon.visible     = false
		_detail_output_name.text        = ""
		_detail_output_rarity.text      = ""
		_detail_output_stat.text        = ""
		_detail_description.text        = ""
		for child in _detail_inputs_vbox.get_children():
			child.queue_free()
		return

	var recipe := _selected_recipe
	_detail_empty_label.visible = false
	_detail_output_icon.visible = true

	# Datos del output.
	if recipe.output_item != null:
		var item := recipe.output_item
		var rarity_col := _rarity_color(item.rarity)
		_detail_output_icon.color = rarity_col
		_detail_output_name.text  = item.display_name
		_detail_output_name.add_theme_color_override("font_color", rarity_col)
		_detail_output_rarity.text = _rarity_label(item.rarity)
		var prefix := _slot_stat_prefix(item.slot)
		_detail_output_stat.text = "%s: %d" % [prefix, item.stat_main]
	else:
		_detail_output_icon.color = COLOR_R1
		_detail_output_name.text  = "(output indefinido)"
		_detail_output_rarity.text = ""
		_detail_output_stat.text   = ""

	# Descripción.
	_detail_description.text = recipe.description if recipe.description != "" else "(sin descripción)"

	# Materiales — reconstruir lista.
	for child in _detail_inputs_vbox.get_children():
		child.queue_free()

	var missing := CraftingSystem.get_missing_materials(recipe)

	for input: CraftRecipeInput in recipe.inputs:
		if input == null or input.material == null:
			continue
		var available: int = InventorySystem.get_material_count(input.material.id)
		var needed: int    = input.count
		var is_ok: bool    = available >= needed

		var row := _make_material_row(input, available, needed, is_ok)
		_detail_inputs_vbox.add_child(row)

	# Si no hay inputs (receta inválida), mostrar aviso.
	if recipe.inputs.is_empty():
		var warn := _make_label("(receta sin materiales definidos)", FONT_SMALL, Color(0.7, 0.5, 0.5, 0.8))
		_detail_inputs_vbox.add_child(warn)


func _make_material_row(
		input: CraftRecipeInput,
		available: int,
		needed: int,
		is_ok: bool
) -> Control:
	# Fila de material requerido. Muestra icono, nombre, y "disponible / necesario".
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 30)

	# Icono de material (ColorRect coloreado por rareza del material).
	var mat_icon := ColorRect.new()
	mat_icon.color = _material_rarity_color(input.material)
	mat_icon.custom_minimum_size = Vector2(14, 14)
	mat_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mat_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mat_icon)
	# TODO: reemplazar por TextureRect con icono del material cuando haya sprites.

	# Nombre del material.
	var name_text: String = input.material.display_name if input.material.display_name != "" else str(input.material.id)
	var name_lbl := _make_label(name_text, FONT_BODY, Color(0.85, 0.85, 0.9, 0.9))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	# Contador "disponible / necesario" — verde si ok, rojo si falta.
	var count_col := COLOR_MAT_OK if is_ok else COLOR_MAT_MISS
	var count_lbl := _make_label("%d / %d" % [available, needed], FONT_BODY, count_col)
	count_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	count_lbl.add_theme_constant_override("outline_size", 3)
	row.add_child(count_lbl)

	return row


func _material_rarity_color(material: MaterialData) -> Color:
	# MaterialData tiene rarity si está definido; si no, color neutro.
	# Acceso defensivo: chequeamos si el campo existe antes de usarlo.
	if material == null:
		return Color(0.5, 0.5, 0.5, 0.6)
	# MaterialData en el proyecto no tiene rarity propio — usamos un color fijo neutro
	# diferenciado del gris base.
	# TODO: si MaterialData recibe campo rarity en el futuro, mapear aquí.
	return Color(0.55, 0.65, 0.75, 0.85)


func _refresh_craft_button() -> void:
	if _selected_recipe == null:
		_craft_btn.disabled = true
		_craft_btn.text = "FORJAR"
		_craft_blocked_label.text = "Seleccioná una receta."
		_craft_blocked_label.visible = true
		return

	if not CraftingSystem.can_craft(_selected_recipe):
		_craft_btn.disabled = true
		var missing := CraftingSystem.get_missing_materials(_selected_recipe)
		# Armar texto descriptivo del faltante más relevante.
		var first_missing_key: StringName = missing.keys()[0] if not missing.is_empty() else &""
		if first_missing_key != &"":
			_craft_blocked_label.text = "Faltan materiales."
		else:
			_craft_blocked_label.text = "Materiales insuficientes."
		_craft_blocked_label.visible = true
		return

	# Todo OK — habilitar botón.
	_craft_btn.disabled = false
	_craft_blocked_label.visible = false
	var output_name: String = ""
	if _selected_recipe.output_item != null:
		output_name = "  " + _selected_recipe.output_item.display_name
	_craft_btn.text = "FORJAR%s" % output_name


# ─── Handlers de interacción ─────────────────────────────────────────────────

func _on_craft_pressed() -> void:
	if _selected_recipe == null or _is_animating:
		return
	_start_craft()


# ─── Flujo de crafteo y animación ────────────────────────────────────────────

func _start_craft() -> void:
	_is_animating = true
	_craft_btn.disabled = true
	_close_btn.disabled = true

	# Overlay de forja.
	_anim_overlay.color = Color(0.04, 0.04, 0.06, 0.85)
	_anim_label.text     = "Forjando."
	_anim_sub_label.text = ""
	_anim_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3, 1.0))
	_anim_overlay.visible = true

	# Puntos suspensivos durante la animación de forja.
	var dots_tween := create_tween()
	dots_tween.set_loops(2)
	dots_tween.tween_callback(func() -> void:
		if is_instance_valid(_anim_label):
			_anim_label.text = "Forjando."
	).set_delay(0.0)
	dots_tween.tween_callback(func() -> void:
		if is_instance_valid(_anim_label):
			_anim_label.text = "Forjando.."
	).set_delay(ANIM_FORGE_DURATION / 4.0)
	dots_tween.tween_callback(func() -> void:
		if is_instance_valid(_anim_label):
			_anim_label.text = "Forjando..."
	).set_delay(ANIM_FORGE_DURATION / 4.0)

	# Ejecutar el crafteo real después del suspenso.
	var timer := get_tree().create_timer(ANIM_FORGE_DURATION)
	timer.timeout.connect(_execute_craft)


func _execute_craft() -> void:
	var result: CraftResult = CraftingSystem.try_craft(_selected_recipe)

	if result == null:
		_show_result_aborted("error inesperado")
		return

	if result.success:
		_show_result_success(result)
	else:
		_show_result_aborted(result.reason)


func _show_result_success(result: CraftResult) -> void:
	var item_name: String = result.output_item.display_name if result.output_item != null else "Item"

	_anim_overlay.color = Color(0.08, 0.12, 0.04, 0.88)
	_anim_label.text    = "FORJADO"
	_anim_label.add_theme_color_override("font_color", COLOR_RESULT_SUCCESS)
	_anim_sub_label.text = "%s fue creado y agregado al inventario." % item_name
	_anim_sub_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7, 0.9))

	# Flash dorado.
	var tween := create_tween()
	tween.tween_property(_anim_overlay, "color", Color(0.22, 0.18, 0.0, 0.88), ANIM_FLASH_DURATION)
	tween.tween_property(_anim_overlay, "color", Color(0.08, 0.12, 0.04, 0.88), ANIM_FLASH_DURATION)
	tween.tween_callback(_finish_animation)


func _show_result_aborted(reason: String) -> void:
	var reason_text: String
	match reason:
		"insufficient_materials":
			reason_text = "Materiales insuficientes al momento del intento."
		"invalid_recipe":
			reason_text = "Receta inválida — contacta al desarrollador."
		"no_recipe":
			reason_text = "Receta no encontrada."
		_:
			reason_text = "No fue posible completar el crafteo."

	_anim_overlay.color = Color(0.1, 0.04, 0.04, 0.9)
	_anim_label.text    = "FALLO"
	_anim_label.add_theme_color_override("font_color", COLOR_RESULT_FAIL)
	_anim_sub_label.text = reason_text
	_anim_sub_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.6, 0.9))

	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(_finish_animation)


func _finish_animation() -> void:
	# Mantener resultado visible 1.2s adicionales.
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(func() -> void:
		_anim_overlay.visible = false
		_is_animating = false
		_close_btn.disabled = false
		# Refrescar toda la UI con el estado actualizado de materiales.
		_refresh_recipe_list()
		if _selected_recipe != null:
			# Re-seleccionar la misma receta (puede haber cambiado su status).
			_select_recipe(_selected_recipe)
		else:
			_select_recipe(null)
	)


# ─── Conexiones de signals ────────────────────────────────────────────────────

func _connect_signals() -> void:
	# Refrescar estado de materiales si el inventario cambia mientras está abierto.
	InventorySystem.materials_changed.connect(_on_materials_changed)

	# Soporte para recetas desbloqueadas en runtime (no aplica en MVP pero queda preparado).
	CraftingSystem.recipe_added.connect(_on_recipe_added)


func _on_materials_changed() -> void:
	if not _is_open:
		return
	# Refrescar indicadores de disponibilidad en lista y detalle.
	_refresh_recipe_list()
	if _selected_recipe != null:
		_refresh_detail_panel()
		_refresh_craft_button()
		_highlight_selected_recipe_row()


func _on_recipe_added(_recipe: CraftRecipe) -> void:
	if not _is_open:
		return
	# Receta nueva desbloqueada en runtime — reconstruir lista.
	_refresh_recipe_list()
