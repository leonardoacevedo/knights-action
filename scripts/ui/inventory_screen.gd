extends CanvasLayer
class_name InventoryScreen

## Pantalla de inventario in-game.
##
## Muestra los ítems equipados (3 slots), la mochila (ítems no equipados) y
## el detalle del ítem seleccionado. Se abre/cierra pausando el juego para que
## el combate no siga mientras el jugador gestiona su equipo.
##
## Conexión con InventorySystem (autoload) — no se importa, se accede directo.
## Conexión con PlayerStatsComponent — ninguna directa; al llamar a
## InventorySystem.equip/unequip las señales equipadas_changed se propagan solas.
##
## Conexión con RefinementScreen: si hay un nodo RefinementScreen en la escena
## (asignado vía refinement_screen_path o encontrado por tipo), el botón "Refinar"
## llama a refinement_screen.open(item_seleccionado). Si no hay RefinementScreen
## disponible, el botón no se muestra.

## Path opcional al RefinementScreen. Si no se asigna, InventoryScreen busca
## el nodo por clase en el árbol. Si tampoco lo encuentra, instancia la escena
## desde res://scenes/ui/refinement_screen.tscn.
@export var refinement_screen_path: NodePath

## Path opcional al CraftingScreen. Misma jerarquía de búsqueda que RefinementScreen.
@export var crafting_screen_path: NodePath

## Path opcional al SkillTreeScreen. Misma jerarquía de búsqueda que los otros.
@export var skill_tree_screen_path: NodePath

## Directorio donde viven los .tres de MaterialData. Opción A de cache.
const MATERIALS_DIR := "res://resources/materials"

# ─── Colores de rareza ────────────────────────────────────────────────────────

const COLOR_R1 := Color(1.0, 1.0, 1.0, 0.4)       # Común — gris translúcido
const COLOR_R2 := Color(0.3, 0.6, 1.0, 0.7)        # Raro — azul
const COLOR_R3 := Color(0.7, 0.3, 0.9, 0.8)        # Épico — violeta
const COLOR_R4 := Color(1.0, 0.75, 0.2, 0.9)       # Legendario — dorado

const COLOR_PANEL_BG    := Color(0.07, 0.07, 0.1, 0.96)
const COLOR_SLOT_BG     := Color(0.12, 0.12, 0.18, 0.9)
const COLOR_SLOT_HOVER  := Color(0.18, 0.18, 0.28, 0.95)
const COLOR_HEADER_BG   := Color(0.05, 0.05, 0.08, 1.0)
const COLOR_SECTION_BG  := Color(0.1, 0.1, 0.15, 0.8)
const COLOR_DETAIL_BG   := Color(0.08, 0.08, 0.12, 0.9)

const FONT_SIZE_TITLE   := 20
const FONT_SIZE_SECTION := 14
const FONT_SIZE_ITEM    := 13
const FONT_SIZE_DETAIL  := 12
const FONT_SIZE_AFFIX   := 11

# Etiquetas de slot para mostrar en la UI (misma posición que ItemData.Slot enum).
const SLOT_LABELS := ["ARMA", "ARMADURA", "ESCUDO"]

# ─── Nodos internos (construidos proceduralmente en _ready) ───────────────────

var _panel: PanelContainer
var _slot_rows: Array[Control] = []       # 3 controles, uno por slot equipado
var _slot_name_labels: Array[Label] = []  # Label con nombre del ítem equipado
var _bag_list: VBoxContainer              # Hijos son _ItemRow Controls
var _detail_panel: Control
var _detail_name: Label
var _detail_desc: Label
var _detail_stat: Label
var _detail_affixes: VBoxContainer
var _refine_btn: Button  # botón "Refinar" en sección de detalle; visible solo si item refinable.

# Sección de afinidad de set (columna izquierda)
var _affinity_label: Label = null         # Elemento activo + piezas
var _affinity_bonus_label: Label = null   # Nombre del bonus 2pc (y 3pc si aplica)

# Sección de materiales
var _materials_vbox: VBoxContainer        # Hijos son filas de material

# Cache de MaterialData: StringName id → MaterialData. Opción A — cargado en _ready.
var _materials_by_id: Dictionary = {}

# RefinementScreen resuelto al primer uso.
var _refinement_screen: RefinementScreen = null

# CraftingScreen resuelto al primer uso.
var _crafting_screen: CraftingScreen = null

# SkillTreeScreen resuelto al primer uso.
var _skill_tree_screen: SkillTreeScreen = null

# Estado interno
var _selected_item: ItemData = null
var _is_open: bool = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_load_materials_cache()
	_build_ui()
	_connect_signals()


# ─── API pública ──────────────────────────────────────────────────────────────

func open() -> void:
	_is_open = true
	visible = true
	get_tree().paused = true
	_selected_item = null
	_refresh_all()


func close() -> void:
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
	# _input (no _unhandled_input) para garantizar que la tecla I llega aunque
	# algún Control de la UI consuma el evento. Maneja tecla I y la action "inventory".
	if not event.is_pressed():
		return
	if event is InputEventKey and event.is_echo():
		return
	var fires_inventory: bool = false
	if InputMap.has_action(&"inventory") and event.is_action_pressed(&"inventory"):
		fires_inventory = true
	elif event is InputEventKey and event.physical_keycode == KEY_I:
		fires_inventory = true
	if fires_inventory:
		toggle()
		get_viewport().set_input_as_handled()


# ─── Construcción de la UI ────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo oscuro full-screen. Mouse filter IGNORE para no bloquear taps
	# en el panel (el panel maneja sus propios eventos).
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Contenedor raíz centrado (~80% ancho, ~85% alto).
	var root_ctrl := Control.new()
	root_ctrl.name = "RootControl"
	root_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# Panel central
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left   = 0.1
	_panel.anchor_right  = 0.9
	_panel.anchor_top    = 0.075
	_panel.anchor_bottom = 0.925
	_panel.offset_left   = 0.0
	_panel.offset_right  = 0.0
	_panel.offset_top    = 0.0
	_panel.offset_bottom = 0.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	# Fondo del panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.corner_radius_top_left     = 12
	panel_style.corner_radius_top_right    = 12
	panel_style.corner_radius_bottom_left  = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_color = Color(0.3, 0.3, 0.5, 0.6)
	panel_style.border_width_top    = 1
	panel_style.border_width_right  = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left   = 1
	_panel.add_theme_stylebox_override("panel", panel_style)
	root_ctrl.add_child(_panel)

	# Layout vertical principal dentro del panel
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(main_vbox)

	_build_header(main_vbox)
	_build_body(main_vbox)


func _build_header(parent: Control) -> void:
	# Header con título + botón cerrar.
	var header := ColorRect.new()
	header.name = "Header"
	header.color = COLOR_HEADER_BG
	header.custom_minimum_size = Vector2(0, 52)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header)

	var header_hbox := HBoxContainer.new()
	header_hbox.name = "HeaderHBox"
	header_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_hbox.add_theme_constant_override("separation", 0)
	header.add_child(header_hbox)

	# Spacer izquierdo
	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer_l)

	# Título
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "INVENTARIO"
	title_lbl.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	# Botón HABILIDADES — abre SkillTreeScreen. Hit area 104×52dp.
	# Violeta para diferenciarlo de FORJA (verde) y REFINAR (azul).
	var skills_btn := Button.new()
	skills_btn.name = "SkillsButton"
	skills_btn.text = "SKILLS"
	skills_btn.custom_minimum_size = Vector2(104, 52)
	skills_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_btn.add_theme_font_size_override("font_size", 13)
	skills_btn.add_theme_color_override("font_color", Color(0.78, 0.6, 1.0, 1.0))
	skills_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	skills_btn.add_theme_constant_override("outline_size", 3)
	skills_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var skills_normal := StyleBoxFlat.new()
	skills_normal.bg_color = Color(0.18, 0.1, 0.3, 0.85)
	skills_normal.corner_radius_top_left     = 0
	skills_normal.corner_radius_top_right    = 0
	skills_normal.corner_radius_bottom_left  = 0
	skills_normal.corner_radius_bottom_right = 0
	skills_btn.add_theme_stylebox_override("normal", skills_normal)
	var skills_hover := StyleBoxFlat.new()
	skills_hover.bg_color = Color(0.28, 0.16, 0.45, 0.95)
	skills_btn.add_theme_stylebox_override("hover",   skills_hover)
	skills_btn.add_theme_stylebox_override("pressed", skills_hover)
	skills_btn.pressed.connect(_on_skills_btn_pressed)
	header_hbox.add_child(skills_btn)

	# Botón FORJA — abre CraftingScreen. Hit area 84×52dp.
	# Verde para diferenciarlo del REFINAR (azul) en el panel de detalle.
	var forge_btn := Button.new()
	forge_btn.name = "ForgeButton"
	forge_btn.text = "FORJA"
	forge_btn.custom_minimum_size = Vector2(84, 52)
	forge_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forge_btn.add_theme_font_size_override("font_size", 13)
	forge_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6, 1.0))
	forge_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	forge_btn.add_theme_constant_override("outline_size", 3)
	forge_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var forge_normal := StyleBoxFlat.new()
	forge_normal.bg_color = Color(0.1, 0.28, 0.1, 0.85)
	forge_normal.corner_radius_top_left     = 0
	forge_normal.corner_radius_top_right    = 0
	forge_normal.corner_radius_bottom_left  = 0
	forge_normal.corner_radius_bottom_right = 0
	forge_btn.add_theme_stylebox_override("normal", forge_normal)
	var forge_hover := StyleBoxFlat.new()
	forge_hover.bg_color = Color(0.16, 0.42, 0.16, 0.95)
	forge_btn.add_theme_stylebox_override("hover",   forge_hover)
	forge_btn.add_theme_stylebox_override("pressed", forge_hover)
	forge_btn.pressed.connect(_on_forge_btn_pressed)
	header_hbox.add_child(forge_btn)

	# Spacer derecho
	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer_r)

	# Botón X — 60×52 hit area (supera 44dp mínimo)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(60, 52)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	close_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	close_btn.add_theme_constant_override("outline_size", 3)
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.2, 0.05, 0.05, 0.0)
	close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover := StyleBoxFlat.new()
	close_hover.bg_color = Color(0.4, 0.1, 0.1, 0.7)
	close_hover.corner_radius_top_right    = 12
	close_hover.corner_radius_bottom_right = 12
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.add_theme_stylebox_override("pressed", close_hover)
	header_hbox.add_child(close_btn)
	close_btn.pressed.connect(close)

	# Separador debajo del header
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_body(parent: Control) -> void:
	# Cuerpo: columna izquierda (Equipado) + columna derecha (Mochila + Detalle).
	var body_hbox := HBoxContainer.new()
	body_hbox.name = "BodyHBox"
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 0)
	parent.add_child(body_hbox)

	_build_equipped_column(body_hbox)

	# Separador vertical
	var vsep := ColorRect.new()
	vsep.color = Color(0.3, 0.3, 0.5, 0.3)
	vsep.custom_minimum_size = Vector2(1, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(vsep)

	_build_right_column(body_hbox)


func _build_equipped_column(parent: Control) -> void:
	# Columna izquierda — slots equipados.
	var col := VBoxContainer.new()
	col.name = "EquippedColumn"
	col.custom_minimum_size = Vector2(160, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	# Encabezado de sección
	var section_hdr := _make_section_header("EQUIPADO")
	col.add_child(section_hdr)

	# 3 filas de slot
	_slot_rows.clear()
	_slot_name_labels.clear()

	for i in range(3):
		var slot_ctrl := _make_equipped_slot_row(i)
		col.add_child(slot_ctrl)
		_slot_rows.append(slot_ctrl)

	# Relleno para empujar los slots hacia arriba
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)

	_build_affinity_section(col)


func _make_equipped_slot_row(slot_index: int) -> Control:
	# Contenedor del slot — altura mínima 72dp (supera 44dp mínimo touch).
	var outer := ColorRect.new()
	outer.name = "SlotRow_%d" % slot_index
	outer.color = COLOR_SLOT_BG
	outer.custom_minimum_size = Vector2(0, 72)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_STOP

	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 2)
	# Padding interno
	inner.offset_left   = 8.0
	inner.offset_top    = 6.0
	inner.offset_right  = -8.0
	inner.offset_bottom = -6.0
	outer.add_child(inner)

	# Label del nombre del slot (ARMA / ARMADURA / ESCUDO)
	var slot_type_lbl := Label.new()
	slot_type_lbl.text = SLOT_LABELS[slot_index]
	slot_type_lbl.add_theme_font_size_override("font_size", 10)
	slot_type_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	slot_type_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	slot_type_lbl.add_theme_constant_override("outline_size", 2)
	inner.add_child(slot_type_lbl)

	# Label del nombre del ítem equipado
	var item_name_lbl := Label.new()
	item_name_lbl.name = "ItemName"
	item_name_lbl.text = "—"
	item_name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SECTION)
	item_name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	item_name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	item_name_lbl.add_theme_constant_override("outline_size", 3)
	item_name_lbl.clip_text = true
	inner.add_child(item_name_lbl)
	_slot_name_labels.append(item_name_lbl)

	# Separador horizontal entre slots
	var hsep := ColorRect.new()
	hsep.color = Color(0.2, 0.2, 0.35, 0.4)
	hsep.custom_minimum_size = Vector2(0, 1)
	hsep.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Wrapeamos slot + separador en un VBox local para que el separador quede fuera
	var wrapper := VBoxContainer.new()
	wrapper.name = "SlotWrapper_%d" % slot_index
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 0)
	wrapper.add_child(outer)
	wrapper.add_child(hsep)

	# Click en el slot desequipa
	outer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_equipped_slot_tapped(slot_index)
		elif event is InputEventScreenTouch and event.pressed:
			_on_equipped_slot_tapped(slot_index)
	)

	return wrapper


func _build_affinity_section(parent: Control) -> void:
	# Separador fino sobre la sección.
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.35)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)

	var section_hdr := _make_section_header("AFINIDAD")
	parent.add_child(section_hdr)

	var bg := ColorRect.new()
	bg.name = "AffinityBg"
	bg.color = Color(0.07, 0.07, 0.12, 0.85)
	bg.custom_minimum_size = Vector2(0, 60)
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	vbox.offset_left   = 8.0
	vbox.offset_top    = 6.0
	vbox.offset_right  = -8.0
	vbox.offset_bottom = -6.0
	vbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	bg.add_child(vbox)

	_affinity_label = _make_label("Sin afinidad", 12, Color(0.7, 0.7, 0.7, 0.8))
	_affinity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(_affinity_label)

	_affinity_bonus_label = _make_label("", 11, Color(0.85, 0.9, 0.65, 0.9))
	_affinity_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_affinity_bonus_label)


## Actualiza la sección de afinidad consultando SetBonusSystem (si existe).
func _refresh_affinity() -> void:
	if _affinity_label == null:
		return

	var sbs: Node = get_node_or_null("/root/SetBonusSystem")
	if sbs == null:
		_affinity_label.text = "Sin afinidad"
		_affinity_bonus_label.text = ""
		return

	var weapon: ItemData  = InventorySystem.get_equipped(ItemData.Slot.ARMA)
	var armor: ItemData   = InventorySystem.get_equipped(ItemData.Slot.ARMADURA)
	var shield_item: ItemData = InventorySystem.get_equipped(ItemData.Slot.ESCUDO)
	var result: Dictionary = sbs.compute_affinity(weapon, armor, shield_item)
	var elem: int   = result["element"]
	var pieces: int = result["pieces"]

	if pieces == 0:
		_affinity_label.text = "Sin afinidad"
		_affinity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		_affinity_bonus_label.text = ""
		return

	var elem_name: String = _element_display_name(elem)
	var elem_color: Color = _element_color(elem)
	_affinity_label.text = "%s  %dpc" % [elem_name, pieces]
	_affinity_label.add_theme_color_override("font_color", elem_color)

	var data: SetBonusData = sbs.get_bonus_data(elem)
	if data == null:
		_affinity_bonus_label.text = ""
		return

	var bonus_lines: PackedStringArray = []
	if pieces >= 2:
		bonus_lines.append("%s: %s" % [data.bonus_2pc_name, data.bonus_2pc_description])
	if pieces >= 3:
		bonus_lines.append("%s: %s" % [data.bonus_3pc_name, data.bonus_3pc_description])
	_affinity_bonus_label.text = "\n".join(bonus_lines)


func _element_display_name(element: int) -> String:
	match element:
		ItemData.Element.FUEGO:  return "Fuego"
		ItemData.Element.AGUA:   return "Agua"
		ItemData.Element.TIERRA: return "Tierra"
		ItemData.Element.VIENTO: return "Viento"
		ItemData.Element.LUZ:    return "Luz"
		ItemData.Element.SOMBRA: return "Sombra"
	return "Neutro"


func _element_color(element: int) -> Color:
	match element:
		ItemData.Element.FUEGO:  return Color(1.0, 0.45, 0.1, 1.0)
		ItemData.Element.AGUA:   return Color(0.2, 0.7, 1.0, 1.0)
		ItemData.Element.TIERRA: return Color(0.5, 0.85, 0.3, 1.0)
		ItemData.Element.VIENTO: return Color(0.7, 0.9, 0.7, 1.0)
		ItemData.Element.LUZ:    return Color(1.0, 0.97, 0.75, 1.0)
		ItemData.Element.SOMBRA: return Color(0.45, 0.2, 0.6, 1.0)
	return Color(0.7, 0.7, 0.7, 0.8)


func _build_right_column(parent: Control) -> void:
	# Columna derecha — mochila arriba, materiales en medio, detalle abajo.
	var col := VBoxContainer.new()
	col.name = "RightColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	_build_bag_section(col)

	# Separador entre mochila y materiales
	var hsep_mat := ColorRect.new()
	hsep_mat.color = Color(0.3, 0.3, 0.5, 0.3)
	hsep_mat.custom_minimum_size = Vector2(0, 1)
	hsep_mat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(hsep_mat)

	_build_materials_section(col)

	# Separador horizontal entre materiales y detalle
	var hsep := ColorRect.new()
	hsep.color = Color(0.3, 0.3, 0.5, 0.3)
	hsep.custom_minimum_size = Vector2(0, 1)
	hsep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(hsep)

	_build_detail_section(col)


func _build_bag_section(parent: Control) -> void:
	var section_hdr := _make_section_header("MOCHILA")
	parent.add_child(section_hdr)

	# ScrollContainer para la lista de ítems.
	var scroll := ScrollContainer.new()
	scroll.name = "BagScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	# Altura mínima para mostrar ~3 ítems cómodamente.
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_bag_list = VBoxContainer.new()
	_bag_list.name = "BagList"
	_bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_bag_list)


func _build_materials_section(parent: Control) -> void:
	var section_hdr := _make_section_header("MATERIALES")
	parent.add_child(section_hdr)

	# ScrollContainer — altura fija para mostrar ~2-3 materiales sin saturar la pantalla.
	var scroll := ScrollContainer.new()
	scroll.name = "MaterialsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# No expand vertical — altura fija para no comprimir mochila ni detalle.
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_materials_vbox = VBoxContainer.new()
	_materials_vbox.name = "MaterialsList"
	_materials_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_materials_vbox)


func _build_detail_section(parent: Control) -> void:
	var section_hdr := _make_section_header("DETALLE")
	parent.add_child(section_hdr)

	_detail_panel = ColorRect.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.color = COLOR_DETAIL_BG
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.custom_minimum_size = Vector2(0, 140)
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "DetailVBox"
	detail_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_vbox.add_theme_constant_override("separation", 3)
	detail_vbox.offset_left   = 10.0
	detail_vbox.offset_top    = 8.0
	detail_vbox.offset_right  = -10.0
	detail_vbox.offset_bottom = -8.0
	_detail_panel.add_child(detail_vbox)

	_detail_name = _make_label("", FONT_SIZE_SECTION, Color(1, 1, 1, 1))
	detail_vbox.add_child(_detail_name)

	_detail_stat = _make_label("", FONT_SIZE_DETAIL, Color(0.8, 0.9, 1.0, 0.9))
	detail_vbox.add_child(_detail_stat)

	_detail_desc = _make_label("", FONT_SIZE_DETAIL, Color(0.75, 0.75, 0.8, 0.8))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_detail_desc)

	var affixes_header := _make_label("Afijos:", FONT_SIZE_AFFIX, Color(0.7, 0.7, 0.9, 0.8))
	detail_vbox.add_child(affixes_header)

	_detail_affixes = VBoxContainer.new()
	_detail_affixes.name = "AffixList"
	_detail_affixes.add_theme_constant_override("separation", 1)
	detail_vbox.add_child(_detail_affixes)

	# Separador antes del botón de refinamiento.
	var refine_sep := ColorRect.new()
	refine_sep.color = Color(0.25, 0.35, 0.55, 0.3)
	refine_sep.custom_minimum_size = Vector2(0, 1)
	refine_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(refine_sep)

	# Botón Refinar — hit area mínima 48×48 dp.
	# Visible solo si el item seleccionado puede refinarse. GDD §5.6.
	_refine_btn = Button.new()
	_refine_btn.name = "RefineButton"
	_refine_btn.text = "REFINAR"
	_refine_btn.custom_minimum_size = Vector2(0, 48)
	_refine_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refine_btn.add_theme_font_size_override("font_size", 14)
	_refine_btn.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0, 1.0))
	_refine_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_refine_btn.add_theme_constant_override("outline_size", 3)
	_refine_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_refine_btn.visible = false  # se muestra en _refresh_detail si aplica.

	var refine_normal := StyleBoxFlat.new()
	refine_normal.bg_color = Color(0.12, 0.22, 0.38, 0.9)
	refine_normal.corner_radius_top_left     = 6
	refine_normal.corner_radius_top_right    = 6
	refine_normal.corner_radius_bottom_left  = 6
	refine_normal.corner_radius_bottom_right = 6
	_refine_btn.add_theme_stylebox_override("normal", refine_normal)

	var refine_hover := StyleBoxFlat.new()
	refine_hover.bg_color = Color(0.18, 0.32, 0.52, 0.95)
	refine_hover.corner_radius_top_left     = 6
	refine_hover.corner_radius_top_right    = 6
	refine_hover.corner_radius_bottom_left  = 6
	refine_hover.corner_radius_bottom_right = 6
	_refine_btn.add_theme_stylebox_override("hover",   refine_hover)
	_refine_btn.add_theme_stylebox_override("pressed", refine_hover)

	_refine_btn.pressed.connect(_on_refine_btn_pressed)
	detail_vbox.add_child(_refine_btn)

	_clear_detail()


# ─── Helpers de construcción ─────────────────────────────────────────────────

func _make_section_header(title: String) -> ColorRect:
	var bg := ColorRect.new()
	bg.name = "SectionHeader_" + title
	bg.color = COLOR_SECTION_BG
	bg.custom_minimum_size = Vector2(0, 28)
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
		ItemData.Rarity.R1: return "C"
		ItemData.Rarity.R2: return "R"
		ItemData.Rarity.R3: return "E"
		ItemData.Rarity.R4: return "L"
	return "?"


# ─── Refresco de UI ───────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_equipped_slots()
	_refresh_affinity()
	_refresh_bag_list()
	_refresh_materials()
	_refresh_detail()


func _refresh_equipped_slots() -> void:
	for i in range(3):
		var slot := i as ItemData.Slot
		var item: ItemData = InventorySystem.get_equipped(slot)
		var lbl: Label = _slot_name_labels[i]
		if item != null:
			lbl.text = item.display_name
			lbl.add_theme_color_override("font_color", _rarity_color(item.rarity))
		else:
			lbl.text = "—"
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))


func _refresh_bag_list() -> void:
	# Limpiar filas anteriores.
	for child in _bag_list.get_children():
		child.queue_free()

	# Obtener todos los ítems y excluir los equipados.
	var all_items: Array[ItemData] = InventorySystem.get_all()
	var equipped_set: Array[ItemData] = []
	for s in range(3):
		var eq: ItemData = InventorySystem.get_equipped(s as ItemData.Slot)
		if eq != null:
			equipped_set.append(eq)

	for item in all_items:
		if item in equipped_set:
			continue
		var row := _make_bag_item_row(item)
		_bag_list.add_child(row)

	# Si mochila vacía, mostrar placeholder.
	if _bag_list.get_child_count() == 0:
		var empty_lbl := _make_label("(mochila vacía)", FONT_SIZE_ITEM, Color(0.6, 0.6, 0.6, 0.6))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bag_list.add_child(empty_lbl)


func _make_bag_item_row(item: ItemData) -> Control:
	# Fila de ítem en la mochila — hit area mínima 60dp de alto.
	var rarity_col := _rarity_color(item.rarity)

	var outer := ColorRect.new()
	outer.name = "BagItem_" + str(item.id)
	outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.12)
	outer.custom_minimum_size = Vector2(0, 60)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_STOP

	# Borde de rareza — franja izquierda
	var rarity_bar := ColorRect.new()
	rarity_bar.name = "RarityBar"
	rarity_bar.color = rarity_col
	rarity_bar.anchor_left   = 0.0
	rarity_bar.anchor_right  = 0.0
	rarity_bar.anchor_top    = 0.0
	rarity_bar.anchor_bottom = 1.0
	rarity_bar.offset_left   = 0.0
	rarity_bar.offset_right  = 4.0
	rarity_bar.offset_top    = 0.0
	rarity_bar.offset_bottom = 0.0
	rarity_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rarity_bar)

	# Contenido
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	hbox.offset_left   = 10.0
	hbox.offset_top    = 4.0
	hbox.offset_right  = -8.0
	hbox.offset_bottom = -4.0
	hbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(hbox)

	# Badge de rareza
	var rarity_badge := Label.new()
	rarity_badge.text = "[%s]" % _rarity_label(item.rarity)
	rarity_badge.add_theme_font_size_override("font_size", 10)
	rarity_badge.add_theme_color_override("font_color", rarity_col)
	rarity_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	rarity_badge.add_theme_constant_override("outline_size", 2)
	rarity_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rarity_badge)

	# Nombre del ítem
	var name_lbl := Label.new()
	name_lbl.text = item.display_name
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_ITEM)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# Stat principal
	var stat_lbl := Label.new()
	var stat_label_text: String
	match item.slot:
		ItemData.Slot.ARMA:     stat_label_text = "ATK %d" % item.stat_main
		ItemData.Slot.ARMADURA: stat_label_text = "DEF %d" % item.stat_main
		ItemData.Slot.ESCUDO:   stat_label_text = "BLQ %d" % item.stat_main
	if item.refinement_level > 0:
		stat_label_text += " +%d" % item.refinement_level
	stat_lbl.text = stat_label_text
	stat_lbl.add_theme_font_size_override("font_size", FONT_SIZE_ITEM)
	stat_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.9))
	stat_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	stat_lbl.add_theme_constant_override("outline_size", 2)
	stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(stat_lbl)

	# Separador
	var sep := ColorRect.new()
	sep.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.15)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var wrapper := VBoxContainer.new()
	wrapper.name = "BagWrapper_" + str(item.id)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 0)
	wrapper.add_child(outer)
	wrapper.add_child(sep)

	# Eventos touch/click en la fila
	outer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_bag_item_tapped(item)
		elif event is InputEventScreenTouch and event.pressed:
			_on_bag_item_tapped(item)
	)

	return wrapper


func _refresh_detail() -> void:
	if _selected_item == null:
		_clear_detail()
		return

	var item := _selected_item
	_detail_name.text = item.display_name
	_detail_name.add_theme_color_override("font_color", _rarity_color(item.rarity))

	var stat_txt: String
	match item.slot:
		ItemData.Slot.ARMA:     stat_txt = "ATK: %d" % item.stat_main
		ItemData.Slot.ARMADURA: stat_txt = "DEF: %d" % item.stat_main
		ItemData.Slot.ESCUDO:   stat_txt = "BLQ: %d" % item.stat_main
	if item.refinement_level > 0:
		stat_txt += "  (+%d refin.)" % item.refinement_level
	_detail_stat.text = stat_txt

	_detail_desc.text = item.description if item.description != "" else "(sin descripción)"

	# Limpiar afijos anteriores y reconstruir.
	for child in _detail_affixes.get_children():
		child.queue_free()

	if item.affixes.is_empty():
		var no_affix := _make_label("(ninguno)", FONT_SIZE_AFFIX, Color(0.6, 0.6, 0.6, 0.7))
		_detail_affixes.add_child(no_affix)
	else:
		for affix in item.affixes:
			var affix_lbl := _make_label(
				"• %s: +%d" % [affix.display_name, affix.value],
				FONT_SIZE_AFFIX,
				Color(0.85, 0.95, 0.7, 0.9)
			)
			_detail_affixes.add_child(affix_lbl)

	# Botón Refinar — visible si el item puede ser refinado (no es +10).
	if _refine_btn != null:
		var can_refine: bool = UpgradeManager.can_refine(item)
		_refine_btn.visible = can_refine
		if can_refine:
			var target_lv: int = UpgradeManager.get_target_level(item)
			_refine_btn.text = "REFINAR  (+%d  →  +%d)" % [item.refinement_level, target_lv]
		else:
			_refine_btn.text = "REFINAMIENTO MAXIMO (+10)"


func _clear_detail() -> void:
	_detail_name.text  = "(ningún ítem seleccionado)"
	_detail_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.7))
	_detail_stat.text  = ""
	_detail_desc.text  = ""
	for child in _detail_affixes.get_children():
		child.queue_free()
	if _refine_btn != null:
		_refine_btn.visible = false


# ─── Handlers de interacción ─────────────────────────────────────────────────

func _on_bag_item_tapped(item: ItemData) -> void:
	# Seleccionar para mostrar detalle y luego equipar.
	_selected_item = item
	_refresh_detail()
	InventorySystem.equip(item)
	# El signal equipped_changed disparará _refresh_all.


func _on_equipped_slot_tapped(slot_index: int) -> void:
	var slot := slot_index as ItemData.Slot
	var equipped: ItemData = InventorySystem.get_equipped(slot)
	if equipped == null:
		return
	# Seleccionar para detalle y desequipar.
	_selected_item = equipped
	InventorySystem.unequip(slot)
	# El signal equipped_changed disparará _refresh_all.


# ─── Señales de InventorySystem ───────────────────────────────────────────────

func _connect_signals() -> void:
	InventorySystem.item_added.connect(_on_inventory_changed)
	InventorySystem.item_removed.connect(_on_inventory_changed)
	InventorySystem.equipped_changed.connect(_on_equipped_changed)
	InventorySystem.materials_changed.connect(_on_materials_changed)
	InventorySystem.material_added.connect(_on_material_added)


func _on_inventory_changed(_item: ItemData) -> void:
	if _is_open:
		_refresh_bag_list()


func _on_equipped_changed(_slot: ItemData.Slot, _item: ItemData) -> void:
	if _is_open:
		_refresh_equipped_slots()
		_refresh_affinity()
		_refresh_bag_list()
		_refresh_detail()


# ─── Integración con RefinementScreen ────────────────────────────────────────

func _on_refine_btn_pressed() -> void:
	if _selected_item == null:
		return
	var rs := _get_refinement_screen()
	if rs == null:
		push_warning("InventoryScreen: no se encontró RefinementScreen — refinamiento no disponible.")
		return
	# Cerrar inventario antes de abrir refinamiento para no apilar pausas.
	close()
	rs.open(_selected_item)


## Resuelve el RefinementScreen. Jerarquía de búsqueda:
##   1. refinement_screen_path asignado en inspector.
##   2. Nodo de tipo RefinementScreen en la escena.
##   3. Instanciar desde res://scenes/ui/refinement_screen.tscn y agregarlo al árbol.
## El resultado se cachea en _refinement_screen para llamadas futuras.
func _get_refinement_screen() -> RefinementScreen:
	if _refinement_screen != null and is_instance_valid(_refinement_screen):
		return _refinement_screen

	# Opción 1 — path explícito desde Inspector.
	if not refinement_screen_path.is_empty():
		var node := get_node_or_null(refinement_screen_path)
		if node is RefinementScreen:
			_refinement_screen = node
			return _refinement_screen

	# Opción 2 — buscar en el árbol por clase.
	var found := _find_refinement_screen_in_tree(get_tree().root)
	if found != null:
		_refinement_screen = found
		return _refinement_screen

	# Opción 3 — instanciar la escena en runtime.
	var scene: PackedScene = load("res://scenes/ui/refinement_screen.tscn")
	if scene == null:
		push_error("InventoryScreen: no se pudo cargar res://scenes/ui/refinement_screen.tscn")
		return null
	var instance: RefinementScreen = scene.instantiate() as RefinementScreen
	if instance == null:
		push_error("InventoryScreen: la escena no es un RefinementScreen válido.")
		return null
	# Agregar como hermano del InventoryScreen en el árbol.
	get_parent().add_child(instance)
	_refinement_screen = instance
	return _refinement_screen


# ─── Cache de MaterialData ───────────────────────────────────────────────────

## Carga todos los .tres de MATERIALS_DIR y los indexa por id. Opción A.
## Se llama una vez en _ready; no modifica InventorySystem.
func _load_materials_cache() -> void:
	var dir := DirAccess.open(MATERIALS_DIR)
	if dir == null:
		push_warning("InventoryScreen: no se pudo abrir %s" % MATERIALS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path := MATERIALS_DIR + "/" + fname
			var mat := load(path) as MaterialData
			if mat != null and mat.id != &"":
				_materials_by_id[mat.id] = mat
		fname = dir.get_next()
	dir.list_dir_end()


# ─── Materiales — refresco y construcción ────────────────────────────────────

func _refresh_materials() -> void:
	# Limpiar filas anteriores.
	for child in _materials_vbox.get_children():
		child.queue_free()

	var mats: Dictionary = InventorySystem.get_all_materials()
	if mats.is_empty():
		var empty_lbl := _make_label(
			"Aún no recogiste materiales — matá enemies para conseguirlos.",
			FONT_SIZE_ITEM,
			Color(0.55, 0.55, 0.6, 0.7)
		)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_materials_vbox.add_child(empty_lbl)
		return

	# Ordenar: rareza descendente, luego display_name ascendente.
	var ids: Array = mats.keys()
	ids.sort_custom(_sort_materials_by_rarity_then_name)

	for id: StringName in ids:
		var mat: MaterialData = _materials_by_id.get(id)
		if mat == null:
			# id en inventario sin .tres correspondiente — ignorar silenciosamente.
			continue
		var count: int = mats[id]
		var row := _make_material_row(mat, count)
		_materials_vbox.add_child(row)


func _make_material_row(mat: MaterialData, count: int) -> Control:
	# Fila de material — altura mínima 44dp para touch.
	var rarity_col := _rarity_color_from_int(mat.rarity)

	var outer := ColorRect.new()
	outer.name = "MatRow_" + str(mat.id)
	outer.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.10)
	outer.custom_minimum_size = Vector2(0, 44)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Franja de rareza izquierda
	var rarity_bar := ColorRect.new()
	rarity_bar.color = rarity_col
	rarity_bar.anchor_left   = 0.0
	rarity_bar.anchor_right  = 0.0
	rarity_bar.anchor_top    = 0.0
	rarity_bar.anchor_bottom = 1.0
	rarity_bar.offset_left   = 0.0
	rarity_bar.offset_right  = 3.0
	rarity_bar.offset_top    = 0.0
	rarity_bar.offset_bottom = 0.0
	rarity_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(rarity_bar)

	# Ícono placeholder (cuadrado del color de rareza, 28×28)
	var icon_rect := ColorRect.new()
	icon_rect.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.45)
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cuando haya Texture2D disponible, sustituir por TextureRect aquí.

	# Nombre
	var name_lbl := Label.new()
	name_lbl.text = mat.display_name
	name_lbl.add_theme_font_size_override("font_size", FONT_SIZE_ITEM)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.93))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tooltip con descripción — útil en desktop; en mobile queda preparado.
	if mat.description != "":
		name_lbl.tooltip_text = mat.description

	# Cantidad "×N" alineada a la derecha
	var count_lbl := Label.new()
	count_lbl.text = "×%d" % count
	count_lbl.add_theme_font_size_override("font_size", FONT_SIZE_ITEM)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.9))
	count_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	count_lbl.add_theme_constant_override("outline_size", 2)
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	hbox.offset_left   = 8.0
	hbox.offset_top    = 4.0
	hbox.offset_right  = -8.0
	hbox.offset_bottom = -4.0
	hbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)
	hbox.add_child(name_lbl)
	hbox.add_child(count_lbl)
	outer.add_child(hbox)

	# Separador fino entre filas
	var sep := ColorRect.new()
	sep.color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.12)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 0)
	wrapper.add_child(outer)
	wrapper.add_child(sep)

	return wrapper


## Versión de _rarity_color que acepta el int crudo del enum de MaterialData.
## MaterialData.rarity es ItemData.Rarity pero almacenado como int en el .tres.
func _rarity_color_from_int(rarity_int: int) -> Color:
	return _rarity_color(rarity_int as ItemData.Rarity)


func _sort_materials_by_rarity_then_name(a_id: StringName, b_id: StringName) -> bool:
	var a: MaterialData = _materials_by_id.get(a_id)
	var b: MaterialData = _materials_by_id.get(b_id)
	if a == null or b == null:
		return false
	if a.rarity != b.rarity:
		return a.rarity > b.rarity  # rareza descendente (R3/R4 primero)
	return a.display_name < b.display_name


# ─── Handlers de señales de materiales ───────────────────────────────────────

func _on_materials_changed() -> void:
	if _is_open:
		_refresh_materials()


## Pulso breve en la sección de materiales cuando llega un material nuevo.
## 0.3 s es suficiente para feedback sin ser molesto.
func _on_material_added(_material: MaterialData, _count: int) -> void:
	if not _is_open or _materials_vbox == null:
		return
	# Tween de alfa sobre el contenedor para feedback "apareció algo nuevo".
	var tween := create_tween()
	tween.tween_property(_materials_vbox, "modulate:a", 0.4, 0.0)
	tween.tween_property(_materials_vbox, "modulate:a", 1.0, 0.3)


func _find_refinement_screen_in_tree(node: Node) -> RefinementScreen:
	if node is RefinementScreen:
		return node
	for child in node.get_children():
		var result := _find_refinement_screen_in_tree(child)
		if result != null:
			return result
	return null


# ─── Integración con CraftingScreen ─────────────────────────────────────────

func _on_forge_btn_pressed() -> void:
	var cs := _get_crafting_screen()
	if cs == null:
		push_warning("InventoryScreen: no se encontró CraftingScreen — crafteo no disponible.")
		return
	# Cerrar inventario antes de abrir forja para no apilar pausas.
	close()
	cs.open()


## Resuelve el CraftingScreen. Jerarquía de búsqueda:
##   1. crafting_screen_path asignado en inspector.
##   2. Nodo de tipo CraftingScreen en la escena.
##   3. Instanciar desde res://scenes/ui/crafting_screen.tscn y agregarlo al árbol.
## El resultado se cachea en _crafting_screen para llamadas futuras.
func _get_crafting_screen() -> CraftingScreen:
	if _crafting_screen != null and is_instance_valid(_crafting_screen):
		return _crafting_screen

	# Opción 1 — path explícito desde Inspector.
	if not crafting_screen_path.is_empty():
		var node := get_node_or_null(crafting_screen_path)
		if node is CraftingScreen:
			_crafting_screen = node
			return _crafting_screen

	# Opción 2 — buscar en el árbol por clase.
	var found := _find_crafting_screen_in_tree(get_tree().root)
	if found != null:
		_crafting_screen = found
		return _crafting_screen

	# Opción 3 — instanciar la escena en runtime.
	var scene: PackedScene = load("res://scenes/ui/crafting_screen.tscn")
	if scene == null:
		push_error("InventoryScreen: no se pudo cargar res://scenes/ui/crafting_screen.tscn")
		return null
	var instance: CraftingScreen = scene.instantiate() as CraftingScreen
	if instance == null:
		push_error("InventoryScreen: la escena no es un CraftingScreen válido.")
		return null
	# Agregar como hermano del InventoryScreen en el árbol.
	get_parent().add_child(instance)
	_crafting_screen = instance
	return _crafting_screen


func _find_crafting_screen_in_tree(node: Node) -> CraftingScreen:
	if node is CraftingScreen:
		return node
	for child in node.get_children():
		var result := _find_crafting_screen_in_tree(child)
		if result != null:
			return result
	return null


# ─── Integración con SkillTreeScreen ─────────────────────────────────────────

func _on_skills_btn_pressed() -> void:
	var sts := _get_skill_tree_screen()
	if sts == null:
		push_warning("InventoryScreen: no se encontró SkillTreeScreen — árbol de habilidades no disponible.")
		return
	# Cerrar inventario antes de abrir el árbol para no apilar pausas.
	close()
	sts.open()


## Resuelve el SkillTreeScreen. Jerarquía de búsqueda:
##   1. skill_tree_screen_path asignado en inspector.
##   2. Nodo de tipo SkillTreeScreen en la escena.
##   3. Instanciar desde res://scenes/ui/skill_tree_screen.tscn y agregarlo al árbol.
## El resultado se cachea en _skill_tree_screen para llamadas futuras.
func _get_skill_tree_screen() -> SkillTreeScreen:
	if _skill_tree_screen != null and is_instance_valid(_skill_tree_screen):
		return _skill_tree_screen

	# Opción 1 — path explícito desde Inspector.
	if not skill_tree_screen_path.is_empty():
		var node := get_node_or_null(skill_tree_screen_path)
		if node is SkillTreeScreen:
			_skill_tree_screen = node
			return _skill_tree_screen

	# Opción 2 — buscar en el árbol por clase.
	var found := _find_skill_tree_screen_in_tree(get_tree().root)
	if found != null:
		_skill_tree_screen = found
		return _skill_tree_screen

	# Opción 3 — instanciar la escena en runtime.
	var scene: PackedScene = load("res://scenes/ui/skill_tree_screen.tscn")
	if scene == null:
		push_error("InventoryScreen: no se pudo cargar res://scenes/ui/skill_tree_screen.tscn")
		return null
	var instance: SkillTreeScreen = scene.instantiate() as SkillTreeScreen
	if instance == null:
		push_error("InventoryScreen: la escena no es un SkillTreeScreen válido.")
		return null
	# Agregar como hermano del InventoryScreen en el árbol.
	get_parent().add_child(instance)
	_skill_tree_screen = instance
	return _skill_tree_screen


func _find_skill_tree_screen_in_tree(node: Node) -> SkillTreeScreen:
	if node is SkillTreeScreen:
		return node
	for child in node.get_children():
		var result := _find_skill_tree_screen_in_tree(child)
		if result != null:
			return result
	return null
