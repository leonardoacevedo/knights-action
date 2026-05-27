extends Node2D
# scripts/ui/main_menu.gd
#
# Menú principal del juego. Construye la UI proceduralmente.
# Pantalla mobile-first portrait/landscape.
# Botones 80px alto mínimo, touch-friendly.

const COLOR_BG_TOP    := Color(0.05, 0.05, 0.10, 1.0)
const COLOR_BG_BOT    := Color(0.08, 0.06, 0.14, 1.0)
const COLOR_PANEL_BG  := Color(0.07, 0.07, 0.12, 0.96)
const COLOR_HEADER_BG := Color(0.05, 0.05, 0.08, 1.0)
const COLOR_BTN_NORMAL := Color(0.12, 0.12, 0.22, 0.95)
const COLOR_BTN_HOVER  := Color(0.22, 0.20, 0.38, 0.98)
const COLOR_BTN_DANGER := Color(0.28, 0.06, 0.06, 0.95)
const COLOR_BTN_DANGER_HOVER := Color(0.42, 0.10, 0.10, 0.98)

const FONT_SIZE_TITLE  := 28
const FONT_SIZE_BTN    := 18
const FONT_SIZE_SMALL  := 13
const BTN_HEIGHT       := 80

# StickFigure del personaje.
var _stick_figure: StickFigure = null

# Modal de confirmación de nueva partida.
var _confirm_modal: Control = null
var _modal_visible: bool = false

# Referencias a overlays de pantallas externas.
var _inventory_screen: InventoryScreen = null
var _skill_tree_screen: SkillTreeScreen = null

# CanvasLayer para toda la UI (encima del StickFigure).
var _canvas: CanvasLayer = null


func _ready() -> void:
	# Asegurarse de que el juego no está pausado al entrar al menú.
	get_tree().paused = false
	# Limpiar modo prueba si se volvió del mundo.
	TestArenaConfig.exit_test_mode()

	_build_background()
	_build_stick_figure()
	_build_canvas()
	_build_ui()
	_start_idle_bob()


# ─── Fondo ────────────────────────────────────────────────────────────────────

func _build_background() -> void:
	# Gradiente simple con dos ColorRect superpuestos (top + bot).
	var bg_top := ColorRect.new()
	bg_top.name = "BgTop"
	bg_top.color = COLOR_BG_TOP
	bg_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_top)

	var bg_bot := ColorRect.new()
	bg_bot.name = "BgBot"
	bg_bot.color = COLOR_BG_BOT
	# Cubre mitad inferior para dar sensación de gradiente.
	bg_bot.anchor_top    = 0.5
	bg_bot.anchor_bottom = 1.0
	bg_bot.anchor_left   = 0.0
	bg_bot.anchor_right  = 1.0
	add_child(bg_bot)


# ─── StickFigure del personaje ────────────────────────────────────────────────

func _build_stick_figure() -> void:
	_stick_figure = StickFigure.new()
	_stick_figure.name = "PlayerPreview"
	# Escala 3× del tamaño normal (se ve en el mundo como ~1×).
	_stick_figure.scale = Vector2(3.0, 3.0)
	# Posición centrada izquierda, zona inferior media de la pantalla.
	# Se ajusta relativo al viewport en _ready via get_viewport().
	add_child(_stick_figure)

	await get_tree().process_frame
	_position_stick_figure()
	_apply_equipped_visuals()


func _position_stick_figure() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Centro horizontal izquierdo (35% del ancho), 60% del alto.
	_stick_figure.position = Vector2(vp.x * 0.35, vp.y * 0.62)


func _apply_equipped_visuals() -> void:
	if _stick_figure == null:
		return
	# Leer equipo actual.
	var weapon: ItemData = InventorySystem.get_equipped(ItemData.Slot.ARMA)
	var armor: ItemData  = InventorySystem.get_equipped(ItemData.Slot.ARMADURA)

	# Mapear visual_type (int enum ItemData) a WeaponType de StickFigure.
	# ItemData.visual_type: 0=None, 1=Sword, 2=Bow, 3=Staff, 4=Hammer, 5=Shield.
	var weapon_type: StickFigure.WeaponType = StickFigure.WeaponType.SWORD
	if weapon != null:
		match weapon.visual_type:
			2: weapon_type = StickFigure.WeaponType.BOW
			3: weapon_type = StickFigure.WeaponType.STAFF
			4: weapon_type = StickFigure.WeaponType.HAMMER
			_: weapon_type = StickFigure.WeaponType.SWORD

	# Escudo en mano off.
	var shield: ItemData = InventorySystem.get_equipped(ItemData.Slot.ESCUDO)
	var off_type: StickFigure.WeaponType = StickFigure.WeaponType.SHIELD if shield != null else StickFigure.WeaponType.NONE

	_stick_figure.weapon_main = weapon_type
	_stick_figure.weapon_off  = off_type

	# Color del cuerpo: si hay armadura equipada usa tinte plateado, sino blanco neutro.
	if armor != null:
		_stick_figure.body_color = Color(0.75, 0.8, 0.95, 1.0)
	else:
		_stick_figure.body_color = Color(0.85, 0.85, 1.0, 1.0)

	_stick_figure.set_state(StickFigure.State.IDLE)


# ─── Idle bob suave ───────────────────────────────────────────────────────────

func _start_idle_bob() -> void:
	if _stick_figure == null:
		return
	await get_tree().process_frame
	var base_y: float = _stick_figure.position.y
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_stick_figure, "position:y", base_y - 6.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_stick_figure, "position:y", base_y, 1.0).set_trans(Tween.TRANS_SINE)


# ─── Canvas y UI principal ────────────────────────────────────────────────────

func _build_canvas() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "UICanvas"
	_canvas.layer = 10
	add_child(_canvas)


func _build_ui() -> void:
	var root := Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	_build_title(root)
	_build_buttons(root)
	_build_confirm_modal(root)


func _build_title(parent: Control) -> void:
	# Título top-center.
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "KNIGHTS ACTION"
	title_lbl.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6, 1.0))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	title_lbl.add_theme_constant_override("outline_size", 6)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.anchor_left  = 0.0
	title_lbl.anchor_right = 1.0
	title_lbl.anchor_top   = 0.04
	title_lbl.anchor_bottom = 0.14
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title_lbl)

	# Subtítulo / versión.
	var sub_lbl := Label.new()
	sub_lbl.name = "SubLabel"
	sub_lbl.text = "Fase 3 — Alpha"
	sub_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.anchor_left   = 0.0
	sub_lbl.anchor_right  = 1.0
	sub_lbl.anchor_top    = 0.12
	sub_lbl.anchor_bottom = 0.18
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sub_lbl)


func _build_buttons(parent: Control) -> void:
	# Columna de botones — lado derecho, vertical, centrada verticalmente.
	# Anchor derecho para que en landscape quede bien.
	var col := VBoxContainer.new()
	col.name = "ButtonColumn"
	col.add_theme_constant_override("separation", 12)
	col.anchor_left   = 0.52
	col.anchor_right  = 0.97
	col.anchor_top    = 0.20
	col.anchor_bottom = 0.95
	col.offset_left   = 0.0
	col.offset_right  = 0.0
	col.offset_top    = 0.0
	col.offset_bottom = 0.0
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical   = Control.GROW_DIRECTION_BOTH
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(col)

	# 1. Modo Historia.
	var btn_historia := _make_button("MODO HISTORIA", Color(0.35, 0.6, 1.0, 1.0), COLOR_BTN_NORMAL)
	btn_historia.pressed.connect(_on_historia_pressed)
	col.add_child(btn_historia)

	# 2. Modo Pruebas.
	var btn_pruebas := _make_button("MODO PRUEBAS", Color(0.5, 1.0, 0.55, 1.0), COLOR_BTN_NORMAL)
	btn_pruebas.pressed.connect(_on_pruebas_pressed)
	col.add_child(btn_pruebas)

	# 3. Inventario.
	var btn_inv := _make_button("INVENTARIO", Color(0.8, 0.8, 1.0, 1.0), COLOR_BTN_NORMAL)
	btn_inv.pressed.connect(_on_inventario_pressed)
	col.add_child(btn_inv)

	# 4. Skills.
	var btn_skills := _make_button("HABILIDADES", Color(0.78, 0.6, 1.0, 1.0), COLOR_BTN_NORMAL)
	btn_skills.pressed.connect(_on_skills_pressed)
	col.add_child(btn_skills)

	# Spacer para empujar botón peligroso al fondo.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	# 5. Nueva Partida (rojo — acción destructiva).
	var btn_nueva := _make_button("NUEVA PARTIDA", Color(1.0, 0.4, 0.4, 1.0), COLOR_BTN_DANGER)
	btn_nueva.add_theme_stylebox_override("hover",   _make_flat_style(COLOR_BTN_DANGER_HOVER))
	btn_nueva.add_theme_stylebox_override("pressed", _make_flat_style(COLOR_BTN_DANGER_HOVER))
	btn_nueva.pressed.connect(_on_nueva_partida_pressed)
	col.add_child(btn_nueva)


func _make_button(label: String, font_color: Color, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", FONT_SIZE_BTN)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 4)

	var normal := _make_flat_style(bg_color)
	btn.add_theme_stylebox_override("normal", normal)
	var hover  := _make_flat_style(COLOR_BTN_HOVER)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)

	return btn


func _make_flat_style(bg: Color, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.border_color = Color(1, 1, 1, 0.12)
	s.border_width_top    = 1
	s.border_width_right  = 1
	s.border_width_bottom = 1
	s.border_width_left   = 1
	return s


# ─── Modal de confirmación de nueva partida ───────────────────────────────────

func _build_confirm_modal(parent: Control) -> void:
	# Fondo bloqueante semitransparente.
	_confirm_modal = Control.new()
	_confirm_modal.name = "ConfirmModal"
	_confirm_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_modal.visible = false
	parent.add_child(_confirm_modal)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_modal.add_child(bg)

	# Panel centrado.
	var panel := PanelContainer.new()
	panel.name = "ModalPanel"
	panel.anchor_left   = 0.12
	panel.anchor_right  = 0.88
	panel.anchor_top    = 0.28
	panel.anchor_bottom = 0.72
	panel.offset_left   = 0
	panel.offset_right  = 0
	panel.offset_top    = 0
	panel.offset_bottom = 0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var p_style := _make_flat_style(Color(0.09, 0.06, 0.12, 0.98), 14)
	p_style.border_color = Color(0.8, 0.25, 0.25, 0.6)
	p_style.border_width_top    = 2
	p_style.border_width_right  = 2
	p_style.border_width_bottom = 2
	p_style.border_width_left   = 2
	panel.add_theme_stylebox_override("panel", p_style)
	_confirm_modal.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var warn := Label.new()
	warn.text = "BORRAR PARTIDA"
	warn.add_theme_font_size_override("font_size", 22)
	warn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	warn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	warn.add_theme_constant_override("outline_size", 4)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(warn)

	var info := Label.new()
	info.text = "Se borraran todos los datos guardados.\nEl personaje vuelve al nivel 1.\nEsta accion no se puede deshacer."
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.9))
	info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	info.add_theme_constant_override("outline_size", 2)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_hbox)

	var cancel := _make_button("CANCELAR", Color(0.85, 0.85, 0.9, 1.0), Color(0.18, 0.18, 0.25, 0.95))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_modal)
	btn_hbox.add_child(cancel)

	var confirm := _make_button("BORRAR Y REINICIAR", Color(1.0, 0.4, 0.4, 1.0), COLOR_BTN_DANGER)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_on_nueva_partida_confirmed)
	btn_hbox.add_child(confirm)


# ─── Handlers de botones ──────────────────────────────────────────────────────

func _on_historia_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_pruebas_pressed() -> void:
	# Cargar el configurador de arena como escena nueva (vuelve al menú desde allá).
	get_tree().change_scene_to_file("res://scenes/ui/test_arena_config.tscn")


func _on_inventario_pressed() -> void:
	var inv := _get_inventory_screen()
	if inv != null:
		inv.open()


func _on_skills_pressed() -> void:
	var sts := _get_skill_tree_screen()
	if sts != null:
		sts.open()


func _on_nueva_partida_pressed() -> void:
	_confirm_modal.visible = true
	_modal_visible = true


func _close_modal() -> void:
	_confirm_modal.visible = false
	_modal_visible = false


func _on_nueva_partida_confirmed() -> void:
	_close_modal()
	# Borrar save persistido.
	SaveSystem.delete_save()
	# Resetear autoloads en orden.
	PlayerProgression.reset(true)
	InventorySystem.reset(true)
	GoldSystem.reset()
	# Arrancar nueva run desde el mundo.
	get_tree().change_scene_to_file("res://scenes/world.tscn")


# ─── Resolución de overlays (misma jerarquía que InventoryScreen usa) ─────────

func _get_inventory_screen() -> InventoryScreen:
	if _inventory_screen != null and is_instance_valid(_inventory_screen):
		return _inventory_screen
	var scene: PackedScene = load("res://scenes/ui/inventory_screen.tscn")
	if scene == null:
		push_error("MainMenu: no se pudo cargar inventory_screen.tscn")
		return null
	var inst := scene.instantiate() as InventoryScreen
	if inst == null:
		push_error("MainMenu: la escena no es InventoryScreen válido.")
		return null
	_canvas.add_child(inst)
	_inventory_screen = inst
	return _inventory_screen


func _get_skill_tree_screen() -> SkillTreeScreen:
	if _skill_tree_screen != null and is_instance_valid(_skill_tree_screen):
		return _skill_tree_screen
	var scene: PackedScene = load("res://scenes/ui/skill_tree_screen.tscn")
	if scene == null:
		push_error("MainMenu: no se pudo cargar skill_tree_screen.tscn")
		return null
	var inst := scene.instantiate() as SkillTreeScreen
	if inst == null:
		push_error("MainMenu: la escena no es SkillTreeScreen válido.")
		return null
	_canvas.add_child(inst)
	_skill_tree_screen = inst
	return _skill_tree_screen


# ─── Input (cerrar modal con Escape) ─────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event is InputEventKey and event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		if _modal_visible:
			_close_modal()
			get_viewport().set_input_as_handled()
