extends Node2D
# scripts/ui/test_arena_config_screen.gd
#
# Configurador del Modo Prueba.
# 4 filas (Melee / Tank / Archer / Mage) × rareza × cantidad (0-4).
# 5ta fila: BOSS ÚNICO — selector de clase + toggle 0/1.
# Total mobs máximo 8 (cap arena). Boss cap independiente = 1.
# Al Iniciar → construye EnemySpawnEntry array (mobs + opcional boss R4),
# llama TestArenaConfig.enter_test_mode, carga world.tscn.
#
# AISLAMIENTO: XP / Oro / Drops no se acumulan (guards en sistemas respectivos).
# El personaje usa su equip + stats actuales.

const MAX_TOTAL := 8
const MAX_BOSS  := 1

const COLOR_BG_TOP    := Color(0.04, 0.05, 0.10, 1.0)
const COLOR_PANEL_BG  := Color(0.07, 0.07, 0.12, 0.96)
const COLOR_ROW_BG    := Color(0.10, 0.10, 0.18, 0.90)
const COLOR_ROW_HOVER := Color(0.15, 0.14, 0.26, 0.95)
const COLOR_BTN_OK    := Color(0.12, 0.28, 0.12, 0.95)
const COLOR_BTN_OK_H  := Color(0.18, 0.42, 0.18, 0.98)
const COLOR_BTN_BACK  := Color(0.16, 0.12, 0.22, 0.95)
const COLOR_BTN_BACK_H := Color(0.26, 0.20, 0.36, 0.98)

const FONT_BTN  := 17
const FONT_ROW  := 15
const FONT_HINT := 12
const ROW_H     := 80

# Nombre de cada clase (orden = GameConfig.EnemyClass int).
const CLASS_NAMES := ["MELEE", "TANK", "ARCHER", "MAGO"]
# Íconos de placeholder (colores) por clase.
const CLASS_COLORS := [
	Color(0.9, 0.3, 0.25, 1.0),   # Melee — rojo
	Color(0.3, 0.5, 1.0, 1.0),    # Tank  — azul
	Color(0.3, 0.85, 0.35, 1.0),  # Archer — verde
	Color(0.75, 0.3, 0.95, 1.0),  # Mago  — violeta
]
const RARITY_NAMES := ["R1", "R2", "R3"]

# Estado editable mobs: [{ class_index, rarity_index (0=R1), count }]
var _rows: Array[Dictionary] = []
# Estado editable boss: { class_index, count } — count 0 ó 1.
var _boss_row: Dictionary = { "class_index": 0, "count": 0 }

# Labels de cantidad por fila (para actualizar en tiempo real).
var _count_labels: Array[Label] = []
# Botones de clase del boss (para actualizar estilo radio).
var _boss_class_btns: Array[Button] = []
# Botones toggle boss "Sin Boss" / "Con Boss".
var _boss_toggle_btns: Array[Button] = []
# Label de total.
var _total_label: Label = null
# Botón iniciar (se deshabilita si total+boss=0, mobs>MAX_TOTAL, boss>MAX_BOSS).
var _start_btn: Button = null

var _canvas: CanvasLayer = null


func _ready() -> void:
	get_tree().paused = false

	# Inicializar estado de cada fila.
	for i in range(4):
		_rows.append({ "class_index": i, "rarity_index": 0, "count": 0 })

	_build_background()
	_build_canvas()
	_build_ui()


# ─── Fondo ────────────────────────────────────────────────────────────────────

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = COLOR_BG_TOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


# ─── Canvas ───────────────────────────────────────────────────────────────────

func _build_canvas() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "UICanvas"
	_canvas.layer = 10
	add_child(_canvas)


# ─── UI principal ─────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	_build_header(root)
	_build_rows(root)
	_build_footer(root)


func _build_header(parent: Control) -> void:
	var hdr := ColorRect.new()
	hdr.color = Color(0.05, 0.05, 0.08, 1.0)
	hdr.anchor_left   = 0.0
	hdr.anchor_right  = 1.0
	hdr.anchor_top    = 0.0
	hdr.anchor_bottom = 0.0
	hdr.offset_bottom = 60
	hdr.grow_vertical = Control.GROW_DIRECTION_END
	hdr.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hdr)

	var title := Label.new()
	title.text = "MODO PRUEBA — CONFIGURAR ARENA"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(title)

	# Aviso de aislamiento.
	var hint := Label.new()
	hint.text = "XP / Oro / Drops NO se guardan en este modo."
	hint.add_theme_font_size_override("font_size", FONT_HINT)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 0.7))
	hint.anchor_left   = 0.0
	hint.anchor_right  = 1.0
	hint.anchor_top    = 0.0
	hint.anchor_bottom = 0.0
	hint.offset_top    = 60
	hint.offset_bottom = 82
	hint.grow_vertical = Control.GROW_DIRECTION_END
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hint)


func _build_rows(parent: Control) -> void:
	# Contenedor de 4 filas mobs + 1 fila boss (separada visualmente).
	# Altura: 4 filas mobs + separador + 1 fila boss.
	var vbox := VBoxContainer.new()
	vbox.name = "RowsVBox"
	vbox.add_theme_constant_override("separation", 8)
	vbox.anchor_left   = 0.04
	vbox.anchor_right  = 0.96
	vbox.anchor_top    = 0.0
	vbox.anchor_bottom = 0.0
	vbox.offset_top    = 90
	vbox.offset_bottom = 90 + ROW_H * 4 + 8 * 3 + 16 + ROW_H + 10
	vbox.grow_vertical = Control.GROW_DIRECTION_END
	vbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vbox)

	_count_labels.clear()

	for i in range(4):
		var row_ctrl := _build_class_row(i)
		vbox.add_child(row_ctrl)

	# Separador visual entre mobs y boss.
	var separator := ColorRect.new()
	separator.color = Color(0.95, 0.85, 0.3, 0.35)
	separator.custom_minimum_size = Vector2(0, 2)
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(separator)

	var boss_row_ctrl := _build_boss_row()
	vbox.add_child(boss_row_ctrl)


func _build_class_row(row_index: int) -> Control:
	var class_name_str: String = CLASS_NAMES[row_index]
	var class_color: Color = CLASS_COLORS[row_index]

	var outer := ColorRect.new()
	outer.name = "ClassRow_%d" % row_index
	outer.color = COLOR_ROW_BG
	outer.custom_minimum_size = Vector2(0, ROW_H)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Borde izquierdo de color de clase.
	var left_bar := ColorRect.new()
	left_bar.color = class_color
	left_bar.anchor_left   = 0.0
	left_bar.anchor_right  = 0.0
	left_bar.anchor_top    = 0.0
	left_bar.anchor_bottom = 1.0
	left_bar.offset_right  = 5.0
	left_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(left_bar)

	# HBox principal dentro de la fila.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	hbox.offset_left   = 12.0
	hbox.offset_top    = 8.0
	hbox.offset_right  = -8.0
	hbox.offset_bottom = -8.0
	hbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(hbox)

	# Ícono placeholder (cuadrado del color de clase).
	var icon := ColorRect.new()
	icon.color = Color(class_color.r, class_color.g, class_color.b, 0.55)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	# Label del nombre de clase.
	var name_lbl := Label.new()
	name_lbl.text = class_name_str
	name_lbl.add_theme_font_size_override("font_size", FONT_ROW)
	name_lbl.add_theme_color_override("font_color", class_color)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# Selector de rareza — 3 botones tipo radio (R1 / R2 / R3).
	var rarity_hbox := HBoxContainer.new()
	rarity_hbox.add_theme_constant_override("separation", 4)
	rarity_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rarity_hbox)

	var rarity_btns: Array[Button] = []
	for ri in range(3):
		var r_btn := Button.new()
		r_btn.text = RARITY_NAMES[ri]
		r_btn.custom_minimum_size = Vector2(52, 52)
		r_btn.add_theme_font_size_override("font_size", 13)
		_style_rarity_btn(r_btn, ri, _rows[row_index].rarity_index == ri)
		var captured_ri := ri
		var captured_row := row_index
		r_btn.pressed.connect(func() -> void: _on_rarity_selected(captured_row, captured_ri, rarity_btns))
		rarity_hbox.add_child(r_btn)
		rarity_btns.append(r_btn)

	# Selector de cantidad: botón – / label / botón +.
	var qty_hbox := HBoxContainer.new()
	qty_hbox.add_theme_constant_override("separation", 4)
	qty_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(qty_hbox)

	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(52, 52)
	minus_btn.add_theme_font_size_override("font_size", 22)
	minus_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))
	var minus_style := StyleBoxFlat.new()
	minus_style.bg_color = Color(0.25, 0.10, 0.10, 0.85)
	minus_style.corner_radius_top_left     = 8
	minus_style.corner_radius_top_right    = 8
	minus_style.corner_radius_bottom_left  = 8
	minus_style.corner_radius_bottom_right = 8
	minus_btn.add_theme_stylebox_override("normal", minus_style)
	minus_btn.pressed.connect(func() -> void: _on_count_changed(row_index, -1))
	qty_hbox.add_child(minus_btn)

	var count_lbl := Label.new()
	count_lbl.text = "0"
	count_lbl.add_theme_font_size_override("font_size", 22)
	count_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	count_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	count_lbl.add_theme_constant_override("outline_size", 3)
	count_lbl.custom_minimum_size = Vector2(36, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_hbox.add_child(count_lbl)
	_count_labels.append(count_lbl)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(52, 52)
	plus_btn.add_theme_font_size_override("font_size", 22)
	plus_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
	var plus_style := StyleBoxFlat.new()
	plus_style.bg_color = Color(0.10, 0.25, 0.10, 0.85)
	plus_style.corner_radius_top_left     = 8
	plus_style.corner_radius_top_right    = 8
	plus_style.corner_radius_bottom_left  = 8
	plus_style.corner_radius_bottom_right = 8
	plus_btn.add_theme_stylebox_override("normal", plus_style)
	plus_btn.pressed.connect(func() -> void: _on_count_changed(row_index, 1))
	qty_hbox.add_child(plus_btn)

	return outer


func _build_boss_row() -> Control:
	const COLOR_BOSS_GOLD := Color(0.95, 0.85, 0.3, 1.0)

	var outer := ColorRect.new()
	outer.name = "BossRow"
	outer.color = Color(0.12, 0.10, 0.04, 0.92)
	outer.custom_minimum_size = Vector2(0, ROW_H)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Borde izquierdo dorado.
	var left_bar := ColorRect.new()
	left_bar.color = COLOR_BOSS_GOLD
	left_bar.anchor_left   = 0.0
	left_bar.anchor_right  = 0.0
	left_bar.anchor_top    = 0.0
	left_bar.anchor_bottom = 1.0
	left_bar.offset_right  = 5.0
	left_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(left_bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	hbox.offset_left   = 12.0
	hbox.offset_top    = 8.0
	hbox.offset_right  = -8.0
	hbox.offset_bottom = -8.0
	hbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	outer.add_child(hbox)

	# Ícono placeholder dorado.
	var icon := ColorRect.new()
	icon.color = Color(COLOR_BOSS_GOLD.r, COLOR_BOSS_GOLD.g, COLOR_BOSS_GOLD.b, 0.4)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	# Label BOSS ÚNICO.
	var name_lbl := Label.new()
	name_lbl.text = "BOSS\nÚNICO"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", COLOR_BOSS_GOLD)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.custom_minimum_size = Vector2(58, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# Selector clase boss — 4 botones radio (Melee/Tank/Archer/Mago).
	var class_hbox := HBoxContainer.new()
	class_hbox.add_theme_constant_override("separation", 4)
	class_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(class_hbox)

	_boss_class_btns.clear()
	for ci in range(4):
		var c_btn := Button.new()
		c_btn.text = CLASS_NAMES[ci]
		c_btn.custom_minimum_size = Vector2(52, 52)
		c_btn.add_theme_font_size_override("font_size", 11)
		var class_col: Color = CLASS_COLORS[ci]
		_style_boss_class_btn(c_btn, class_col, ci == _boss_row.class_index)
		var captured_ci := ci
		c_btn.pressed.connect(func() -> void: _on_boss_class_selected(captured_ci))
		class_hbox.add_child(c_btn)
		_boss_class_btns.append(c_btn)

	# Toggle Sin Boss / Con Boss.
	var toggle_hbox := HBoxContainer.new()
	toggle_hbox.add_theme_constant_override("separation", 4)
	toggle_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(toggle_hbox)

	_boss_toggle_btns.clear()
	var toggle_labels := ["Sin\nBoss", "Con\nBoss"]
	for ti in range(2):
		var t_btn := Button.new()
		t_btn.text = toggle_labels[ti]
		t_btn.custom_minimum_size = Vector2(64, 52)
		t_btn.add_theme_font_size_override("font_size", 12)
		_style_boss_toggle_btn(t_btn, ti, ti == _boss_row.count)
		var captured_ti := ti
		t_btn.pressed.connect(func() -> void: _on_boss_toggle(captured_ti))
		toggle_hbox.add_child(t_btn)
		_boss_toggle_btns.append(t_btn)

	return outer


func _style_boss_class_btn(btn: Button, class_col: Color, active: bool) -> void:
	btn.add_theme_color_override("font_color", class_col)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 2)
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = Color(class_col.r, class_col.g, class_col.b, 0.35)
		s.border_color = class_col
		s.border_width_top    = 2
		s.border_width_right  = 2
		s.border_width_bottom = 2
		s.border_width_left   = 2
	else:
		s.bg_color = Color(class_col.r, class_col.g, class_col.b, 0.08)
		s.border_color = Color(class_col.r, class_col.g, class_col.b, 0.25)
		s.border_width_top    = 1
		s.border_width_right  = 1
		s.border_width_bottom = 1
		s.border_width_left   = 1
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(class_col.r, class_col.g, class_col.b, 0.52)
	btn.add_theme_stylebox_override("hover", sh)


func _style_boss_toggle_btn(btn: Button, toggle_idx: int, active: bool) -> void:
	# toggle_idx 0 = Sin Boss (gris), 1 = Con Boss (dorado).
	var col: Color = Color(0.95, 0.85, 0.3, 1.0) if toggle_idx == 1 else Color(0.7, 0.7, 0.75, 0.9)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 2)
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = Color(col.r, col.g, col.b, 0.35)
		s.border_color = col
		s.border_width_top    = 2
		s.border_width_right  = 2
		s.border_width_bottom = 2
		s.border_width_left   = 2
	else:
		s.bg_color = Color(col.r, col.g, col.b, 0.07)
		s.border_color = Color(col.r, col.g, col.b, 0.22)
		s.border_width_top    = 1
		s.border_width_right  = 1
		s.border_width_bottom = 1
		s.border_width_left   = 1
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(col.r, col.g, col.b, 0.52)
	btn.add_theme_stylebox_override("hover", sh)


func _style_rarity_btn(btn: Button, rarity_idx: int, active: bool) -> void:
	const RARITY_COLORS := [
		Color(0.8, 0.8, 0.85, 0.9),   # R1 blanco
		Color(0.3, 0.6, 1.0,  1.0),   # R2 azul
		Color(0.7, 0.3, 0.9,  1.0),   # R3 violeta
	]
	var col: Color = RARITY_COLORS[rarity_idx]
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 2)

	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = Color(col.r, col.g, col.b, 0.35)
		s.border_color = col
		s.border_width_top    = 2
		s.border_width_right  = 2
		s.border_width_bottom = 2
		s.border_width_left   = 2
	else:
		s.bg_color = Color(col.r, col.g, col.b, 0.08)
		s.border_color = Color(col.r, col.g, col.b, 0.25)
		s.border_width_top    = 1
		s.border_width_right  = 1
		s.border_width_bottom = 1
		s.border_width_left   = 1
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	var s_hover := s.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(col.r, col.g, col.b, 0.52)
	btn.add_theme_stylebox_override("hover", s_hover)


func _build_footer(parent: Control) -> void:
	# Footer: label Total + botones Volver / Iniciar.
	var footer := Control.new()
	footer.name = "Footer"
	footer.anchor_left   = 0.04
	footer.anchor_right  = 0.96
	footer.anchor_top    = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top    = -120
	footer.offset_bottom = -8
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	parent.add_child(footer)

	# Label total — muestra "Mobs: N/8  ·  Boss: M/1".
	_total_label = Label.new()
	_total_label.name = "TotalLabel"
	_total_label.text = "Mobs: 0 / %d  ·  Boss: 0 / %d" % [MAX_TOTAL, MAX_BOSS]
	_total_label.add_theme_font_size_override("font_size", 16)
	_total_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.75, 1.0))
	_total_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_total_label.add_theme_constant_override("outline_size", 3)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.anchor_left   = 0.0
	_total_label.anchor_right  = 1.0
	_total_label.anchor_top    = 0.0
	_total_label.anchor_bottom = 0.35
	_total_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_total_label)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.anchor_left   = 0.0
	btn_hbox.anchor_right  = 1.0
	btn_hbox.anchor_top    = 0.40
	btn_hbox.anchor_bottom = 1.0
	btn_hbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	footer.add_child(btn_hbox)

	# Botón Volver.
	var back_btn := _make_button("VOLVER", Color(0.75, 0.75, 0.85, 1.0), COLOR_BTN_BACK)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_back_pressed)
	btn_hbox.add_child(back_btn)

	# Botón Iniciar.
	_start_btn = _make_button("INICIAR ARENA", Color(0.45, 1.0, 0.55, 1.0), COLOR_BTN_OK)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start_pressed)
	btn_hbox.add_child(_start_btn)


func _make_button(label: String, font_color: Color, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 60)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", FONT_BTN)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 4)
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.corner_radius_top_left     = 10
	s.corner_radius_top_right    = 10
	s.corner_radius_bottom_left  = 10
	s.corner_radius_bottom_right = 10
	s.border_color = Color(1, 1, 1, 0.10)
	s.border_width_top    = 1
	s.border_width_right  = 1
	s.border_width_bottom = 1
	s.border_width_left   = 1
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(s.bg_color.r * 1.4, s.bg_color.g * 1.4, s.bg_color.b * 1.4, 0.98)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	var sd := s.duplicate() as StyleBoxFlat
	sd.bg_color = Color(s.bg_color.r * 0.5, s.bg_color.g * 0.5, s.bg_color.b * 0.5, 0.6)
	btn.add_theme_stylebox_override("disabled", sd)
	return btn


# ─── Handlers ─────────────────────────────────────────────────────────────────

func _on_rarity_selected(row_index: int, rarity_idx: int, rarity_btns: Array[Button]) -> void:
	_rows[row_index].rarity_index = rarity_idx
	# Actualizar estilo visual de los 3 botones de rareza de esta fila.
	for ri in range(3):
		_style_rarity_btn(rarity_btns[ri], ri, ri == rarity_idx)


func _on_count_changed(row_index: int, delta: int) -> void:
	var current: int = _rows[row_index].count
	var total_other: int = _get_total() - current
	var new_count: int = clampi(current + delta, 0, min(4, MAX_TOTAL - total_other))
	_rows[row_index].count = new_count
	_count_labels[row_index].text = str(new_count)
	_refresh_total()


func _get_total() -> int:
	var t := 0
	for row in _rows:
		t += row.count
	return t


func _get_boss_count() -> int:
	return _boss_row.count


func _on_boss_class_selected(class_idx: int) -> void:
	_boss_row.class_index = class_idx
	# Actualizar estilo radio de los 4 botones de clase.
	for ci in range(4):
		var class_col: Color = CLASS_COLORS[ci]
		_style_boss_class_btn(_boss_class_btns[ci], class_col, ci == class_idx)


func _on_boss_toggle(toggle_idx: int) -> void:
	# toggle_idx 0 = Sin Boss (count=0), 1 = Con Boss (count=1).
	_boss_row.count = toggle_idx
	_style_boss_toggle_btn(_boss_toggle_btns[0], 0, toggle_idx == 0)
	_style_boss_toggle_btn(_boss_toggle_btns[1], 1, toggle_idx == 1)
	_refresh_total()


func _refresh_total() -> void:
	var mobs  := _get_total()
	var boss  := _get_boss_count()
	_total_label.text = "Mobs: %d / %d  ·  Boss: %d / %d" % [mobs, MAX_TOTAL, boss, MAX_BOSS]
	var mob_ok  := mobs  <= MAX_TOTAL
	var boss_ok := boss  <= MAX_BOSS
	var any     := (mobs + boss) > 0
	if not mob_ok or not boss_ok or not any:
		_total_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))
		_start_btn.disabled = true
	else:
		_total_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
		_start_btn.disabled = false


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_start_pressed() -> void:
	var spawns: Array[EnemySpawnEntry] = []

	# Mapa de rarity_index → GameConfig.EnemyRarity.
	const RARITY_MAP := [
		GameConfig.EnemyRarity.R1,
		GameConfig.EnemyRarity.R2,
		GameConfig.EnemyRarity.R3,
	]
	# Mapa de class_index → GameConfig.EnemyClass.
	const CLASS_MAP := [
		GameConfig.EnemyClass.MELEE,
		GameConfig.EnemyClass.TANK,
		GameConfig.EnemyClass.ARCHER,
		GameConfig.EnemyClass.MAGE,
	]

	for row in _rows:
		if row.count <= 0:
			continue
		var entry := EnemySpawnEntry.new()
		entry.enemy_class = CLASS_MAP[row.class_index]
		entry.rarity      = RARITY_MAP[row.rarity_index]
		entry.count       = row.count
		entry.element     = 0   # Neutro por default.
		spawns.append(entry)

	# Boss: si count == 1, agregar entry R4 con la clase seleccionada.
	if _boss_row.count == 1:
		var boss_entry := EnemySpawnEntry.new()
		boss_entry.enemy_class = CLASS_MAP[_boss_row.class_index]
		boss_entry.rarity      = GameConfig.EnemyRarity.R4
		boss_entry.count       = 1
		boss_entry.element     = 0
		spawns.append(boss_entry)

	TestArenaConfig.enter_test_mode(spawns)
	get_tree().change_scene_to_file("res://scenes/world.tscn")
