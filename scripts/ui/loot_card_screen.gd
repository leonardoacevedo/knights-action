extends CanvasLayer
class_name LootCardScreen

## Pantalla modal "Loot Card" — aparece al completar cada stage con el botín obtenido.
## GDD §5.5 (drops por stage cleared) / Milestone B / Pilar #2.
##
## Patrón de pausa:
##   Al abrirse setea get_tree().paused = true.
##   process_mode = ALWAYS → sigue respondiendo a input (botón CONTINUAR).
##   Al apretar CONTINUAR: get_tree().paused = false → el create_timer del StageManager
##   resume solo y la siguiente stage arranca normalmente.
##   NO hay queue_free: la pantalla queda viva esperando el siguiente items_dropped.
##
## Siempre se muestra aunque la lista sea vacía — el jugador necesita feedback
## de "etapa cerrada" incluso sin loot (Pilar #2: cada muerte / etapa enseña algo).
##
## Conexión:
##   Se autoconecta a DropSystem.items_dropped en _ready.
##   El World (o world.gd) la instancia y la agrega al árbol en su _ready.


# ─── Colores — idénticos a RefinementScreen / CraftingScreen ─────────────────

const COLOR_R1 := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_R2 := Color(0.3, 0.6, 1.0, 0.7)
const COLOR_R3 := Color(0.7, 0.3, 0.9, 0.8)
const COLOR_R4 := Color(1.0, 0.75, 0.2, 0.9)

const COLOR_PANEL_BG  := Color(0.07, 0.07, 0.1,  0.97)
const COLOR_HEADER_BG := Color(0.05, 0.05, 0.08, 1.0)
const COLOR_ITEM_BG   := Color(0.1,  0.1,  0.16, 0.9)

# Colores del título en función del número de items.
const COLOR_TITLE_LOOT  := Color(1.0, 0.88, 0.2, 1.0)   # dorado — hay botín
const COLOR_TITLE_EMPTY := Color(0.65, 0.65, 0.75, 0.9)  # gris — sin botín

# Fuentes.
const FONT_TITLE    := 22
const FONT_SECTION  := 15
const FONT_BODY     := 14
const FONT_SMALL    := 12

# Duración del fade-in al aparecer (ms).
const ANIM_FADE_IN_DURATION := 0.18

# Alto mínimo de cada item card (mobile-first, 88dp equivalente).
const ITEM_CARD_MIN_HEIGHT := 88

# Padding interno de las item cards.
const ITEM_CARD_PADDING := 12


# ─── Nodos construidos proceduralmente ───────────────────────────────────────

var _panel: PanelContainer
var _subtitle_label: Label
var _title_label: Label
var _items_vbox: VBoxContainer
var _empty_label: Label
var _continue_btn: Button


# ─── Estado ──────────────────────────────────────────────────────────────────

## Índice de la stage que acaba de completarse (actualizado en cada items_dropped).
var _last_stage_index: int = -1


# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 27  # Sobre CraftingScreen (26) y RefinementScreen (25).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_build_ui()

	# Conectar a DropSystem. Emitido siempre en stage_cleared (lista puede ser vacía).
	DropSystem.items_dropped.connect(_on_items_dropped)

	# Escuchar stage_cleared para mantener el índice actualizado.
	StageManager.stage_cleared.connect(_on_stage_cleared)


# ─── Callbacks de signals ─────────────────────────────────────────────────────

func _on_stage_cleared(index: int) -> void:
	_last_stage_index = index


func _on_items_dropped(items: Array[ItemData]) -> void:
	_populate(items)
	_show()


# ─── Mostrar / ocultar ────────────────────────────────────────────────────────

func _show() -> void:
	visible = true
	get_tree().paused = true

	# Fade-in del panel: arranca transparente, llega a opaco.
	_panel.modulate = Color(1, 1, 1, 0)
	var tween: Tween = create_tween()
	tween.tween_property(_panel, "modulate", Color(1, 1, 1, 1), ANIM_FADE_IN_DURATION)


func _hide_card() -> void:
	get_tree().paused = false
	visible = false


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo oscuro bloqueante — captura todos los toques fuera del panel.
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.0, 0.0, 0.0, 0.70)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Contenedor raíz para anchors correctos.
	var root_ctrl := Control.new()
	root_ctrl.name = "RootControl"
	root_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# Panel principal — 88% ancho, 90% alto, centrado.
	# Respeta notch / punch-hole en Android/iOS con un 5% de margen top.
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.anchor_left   = 0.06
	_panel.anchor_right  = 0.94
	_panel.anchor_top    = 0.05
	_panel.anchor_bottom = 0.95
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
	_build_items_scroll(main_vbox)
	_build_continue_button(main_vbox)


func _build_header(parent: Control) -> void:
	var header := ColorRect.new()
	header.name = "Header"
	header.color = COLOR_HEADER_BG
	header.custom_minimum_size = Vector2(0, 72)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.offset_left   = 16.0
	vbox.offset_right  = -16.0
	vbox.offset_top    = 4.0
	vbox.offset_bottom = -4.0
	header.add_child(vbox)

	# Título principal — cambia color según hay o no botín.
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "BOTÍN"
	_title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_LOOT)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	# Subtítulo — "Etapa X completada — N items obtenidos".
	_subtitle_label = Label.new()
	_subtitle_label.name = "SubtitleLabel"
	_subtitle_label.text = "Etapa 1 completada — 0 items obtenidos"
	_subtitle_label.add_theme_font_size_override("font_size", FONT_SMALL)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_subtitle_label.add_theme_constant_override("outline_size", 2)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_subtitle_label)

	parent.add_child(header)

	# Separador.
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)


func _build_items_scroll(parent: Control) -> void:
	# ScrollContainer para listas largas (stage con muchos drops).
	var scroll := ScrollContainer.new()
	scroll.name = "ItemsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode  = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_items_vbox = VBoxContainer.new()
	_items_vbox.name = "ItemsVBox"
	_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_vbox.add_theme_constant_override("separation", 8)

	# Padding interno del scroll.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_child(_items_vbox)
	scroll.add_child(margin)

	# Label de estado vacío (visible solo cuando no hay items).
	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.text = "Sin botín en esta etapa."
	_empty_label.add_theme_font_size_override("font_size", FONT_BODY)
	_empty_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75, 0.75))
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_label.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_label.visible = false
	_items_vbox.add_child(_empty_label)


func _build_continue_button(parent: Control) -> void:
	# Separador visual antes del botón.
	var sep := ColorRect.new()
	sep.color = Color(0.3, 0.3, 0.5, 0.4)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)

	# Margin para que el botón no quede pegado a los bordes del panel.
	var btn_margin := MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_left",   24)
	btn_margin.add_theme_constant_override("margin_right",  24)
	btn_margin.add_theme_constant_override("margin_top",    16)
	btn_margin.add_theme_constant_override("margin_bottom", 24)
	parent.add_child(btn_margin)

	# Botón CONTINUAR — hit area mínima 120×60 dp (muy por encima de 44×44 dp HIG).
	_continue_btn = Button.new()
	_continue_btn.name = "ContinueButton"
	_continue_btn.text = "CONTINUAR"
	_continue_btn.custom_minimum_size = Vector2(0, 64)
	_continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_continue_btn.add_theme_font_size_override("font_size", FONT_SECTION)
	_continue_btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08, 1))
	_continue_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_continue_btn.add_theme_constant_override("outline_size", 2)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.85, 0.7, 0.15, 1.0)
	btn_normal.corner_radius_top_left     = 10
	btn_normal.corner_radius_top_right    = 10
	btn_normal.corner_radius_bottom_left  = 10
	btn_normal.corner_radius_bottom_right = 10
	_continue_btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(1.0, 0.85, 0.2, 1.0)
	btn_hover.corner_radius_top_left     = 10
	btn_hover.corner_radius_top_right    = 10
	btn_hover.corner_radius_bottom_left  = 10
	btn_hover.corner_radius_bottom_right = 10
	_continue_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.7, 0.55, 0.1, 1.0)
	btn_pressed.corner_radius_top_left     = 10
	btn_pressed.corner_radius_top_right    = 10
	btn_pressed.corner_radius_bottom_left  = 10
	btn_pressed.corner_radius_bottom_right = 10
	_continue_btn.add_theme_stylebox_override("pressed", btn_pressed)

	_continue_btn.pressed.connect(_on_continue_pressed)
	btn_margin.add_child(_continue_btn)


# ─── Población de la lista de items ──────────────────────────────────────────

func _populate(items: Array[ItemData]) -> void:
	# Limpiar cards anteriores (la pantalla se reutiliza en cada stage).
	for child in _items_vbox.get_children():
		if child != _empty_label:
			child.queue_free()

	# Actualizar subtítulo.
	var stage_num: int = _last_stage_index + 1
	var item_count: int = items.size()
	_subtitle_label.text = "Etapa %d completada — %d item%s obtenido%s" % [
		stage_num,
		item_count,
		"s" if item_count != 1 else "",
		"s" if item_count != 1 else "",
	]

	if items.is_empty():
		_title_label.text = "BOTÍN"
		_title_label.add_theme_color_override("font_color", COLOR_TITLE_EMPTY)
		_empty_label.visible = true
		return

	_title_label.text = "BOTÍN"
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_LOOT)
	_empty_label.visible = false

	for item in items:
		if item == null:
			continue
		var card: Control = _build_item_card(item)
		_items_vbox.add_child(card)


func _build_item_card(item: ItemData) -> Control:
	# Contenedor raíz de la card — alto mínimo ITEM_CARD_MIN_HEIGHT dp.
	var card := PanelContainer.new()
	card.name = "Card_%s" % item.id
	card.custom_minimum_size = Vector2(0, ITEM_CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_ITEM_BG
	card_style.corner_radius_top_left     = 8
	card_style.corner_radius_top_right    = 8
	card_style.corner_radius_bottom_left  = 8
	card_style.corner_radius_bottom_right = 8
	card_style.border_color = _rarity_color(item.rarity)
	card_style.border_width_left = 3  # Franja lateral de rareza.
	card.add_theme_stylebox_override("panel", card_style)

	# Layout horizontal: franja | ícono | datos.
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", ITEM_CARD_PADDING)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left   = ITEM_CARD_PADDING
	hbox.offset_right  = -ITEM_CARD_PADDING
	hbox.offset_top    = ITEM_CARD_PADDING
	hbox.offset_bottom = -ITEM_CARD_PADDING
	card.add_child(hbox)

	# Placeholder del ícono — cuadrado 48×48 del color de rareza.
	# TODO: reemplazar por TextureRect cuando lleguen los sprites (Fase 3).
	var icon_rect := ColorRect.new()
	icon_rect.name = "IconPlaceholder"
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.color = _rarity_color(item.rarity)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Si el item tiene ícono real, usarlo.
	if item.icon != null:
		var tex_rect := TextureRect.new()
		tex_rect.name = "IconTexture"
		tex_rect.texture = item.icon
		tex_rect.custom_minimum_size = Vector2(48, 48)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tex_rect)
	else:
		hbox.add_child(icon_rect)

	# Datos del item (columna vertical).
	var data_vbox := VBoxContainer.new()
	data_vbox.name = "DataVBox"
	data_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	data_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(data_vbox)

	# Nombre del item.
	var name_lbl := Label.new()
	name_lbl.name = "ItemName"
	name_lbl.text = item.display_name
	name_lbl.add_theme_font_size_override("font_size", FONT_SECTION)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	data_vbox.add_child(name_lbl)

	# Slot y stat principal en la misma fila.
	var meta_hbox := HBoxContainer.new()
	meta_hbox.add_theme_constant_override("separation", 8)
	data_vbox.add_child(meta_hbox)

	var slot_lbl := Label.new()
	slot_lbl.name = "SlotLabel"
	slot_lbl.text = _slot_display(item.slot)
	slot_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	slot_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85, 0.85))
	slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_hbox.add_child(slot_lbl)

	var stat_lbl := Label.new()
	stat_lbl.name = "StatLabel"
	stat_lbl.text = _stat_display(item)
	stat_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	stat_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_hbox.add_child(stat_lbl)

	# Rareza — esquina inferior derecha de los datos.
	var rarity_lbl := Label.new()
	rarity_lbl.name = "RarityLabel"
	rarity_lbl.text = _rarity_display(item.rarity)
	rarity_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	rarity_lbl.add_theme_color_override("font_color", _rarity_color(item.rarity))
	rarity_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	rarity_lbl.add_theme_constant_override("outline_size", 2)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	data_vbox.add_child(rarity_lbl)

	return card


# ─── Botón CONTINUAR ─────────────────────────────────────────────────────────

func _on_continue_pressed() -> void:
	# Resume del árbol → el create_timer del StageManager continúa solo.
	# No hace falta emitir ninguna signal adicional.
	_hide_card()


# ─── Input — Escape como atajo de teclado (PC / testing) ─────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_ENTER:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()


# ─── Helpers de display ───────────────────────────────────────────────────────

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return COLOR_R1
		1: return COLOR_R2
		2: return COLOR_R3
		3: return COLOR_R4
	return COLOR_R1


func _rarity_display(rarity: int) -> String:
	match rarity:
		0: return "Común"
		1: return "Raro"
		2: return "Épico"
		3: return "Legendario"
	return "Común"


func _slot_display(slot) -> String:
	# slot es un enum Slot definido en ItemData.
	# Usamos String() como fallback seguro si el enum cambia.
	match int(slot):
		0: return "Arma"
		1: return "Armadura"
		2: return "Escudo"
	return str(slot)


func _stat_display(item: ItemData) -> String:
	# Muestra el stat principal refinado según el slot.
	var value: float = item.refined_stat()
	match int(item.slot):
		0: return "ATK: %d" % int(value)
		1: return "DEF: %d" % int(value)
		2: return "BLQ: %d" % int(value)
	return "STAT: %d" % int(value)
