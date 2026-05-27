extends CanvasLayer
class_name HudCombat

## HUD de combate. Contador de Momentum + barras de HP/Furia.
## Se instancia en world.tscn como hijo del root (no del player).
##
## Layout:
##   Top-center: contador Momentum grande, con color según nivel.
##   Top-left:   barra HP (roja) + barra Furia (azul/violeta).

## Path al player. Asignar en Inspector desde world.tscn.
@export var player_path: NodePath

## Tamaño de fuente del contador de Momentum.
@export var momentum_font_size: int = 72

@onready var _momentum_label: Label = $MomentumContainer/MomentumLabel
@onready var _hp_bar_fg: ColorRect = $StatsContainer/HPRow/HPBarBG/HPBarFG
@onready var _hp_label: Label = $StatsContainer/HPRow/HPLabel
@onready var _furia_bar_fg: ColorRect = $StatsContainer/FuriaRow/FuriaBarBG/FuriaBarFG
@onready var _furia_label: Label = $StatsContainer/FuriaRow/FuriaLabel
@onready var _shield_display: ShieldChargesDisplay = $StatsContainer/ShieldRow/ShieldChargesDisplay
@onready var _set_bonus_row: HBoxContainer = $StatsContainer/SetBonusRow
@onready var _set_bonus_bg: ColorRect = $StatsContainer/SetBonusRow/SetBonusBG
@onready var _set_bonus_label: Label = $StatsContainer/SetBonusRow/SetBonusBG/SetBonusLabel

# Label de Oro — asignado en _ready para mantener null-safety si el nodo falta.
var _gold_label: Label = null

const COLOR_LOW := Color(1, 1, 1, 1)            # blanco, niveles 0-4
const COLOR_MID := Color(1, 0.72, 0.18, 1)      # naranja cálido, niveles 5-7
const COLOR_HIGH := Color(1, 0.32, 0.12, 1)     # rojo intenso, niveles 8-10

const COLOR_GOLD_OUTLINE := Color(1.0, 0.85, 0.0, 0.9)  # outline dorado para 10x

var _player: Player = null
# Trackear último nivel de Momentum para detectar bajada.
var _last_momentum_level: int = 0
# Tweens activos — kill antes de crear nuevo para no acumular.
var _momentum_pulse_tween: Tween = null
var _momentum_shake_tween: Tween = null
var _hp_max: int = 100
var _furia_max: int = 100
var _hp_bar_base_width: float = 0.0
var _furia_bar_base_width: float = 0.0


func _ready() -> void:
	# Conectar Momentum global.
	MomentumSystem.momentum_changed.connect(_on_momentum_changed)
	_apply_momentum_visual(0)

	# Conectar Oro global — path corregido para coincidir con GoldRow/GoldLabel.
	_gold_label = get_node_or_null("StatsContainer/GoldRow/GoldLabel") as Label
	GoldSystem.gold_changed.connect(_on_gold_changed)
	_update_gold_label(GoldSystem.get_gold())

	# Conectar set bonus — refrescar al cambiar equipo y al iniciar.
	InventorySystem.equipped_changed.connect(_on_equipped_changed)
	_update_set_bonus_display()

	# Guardamos el ancho base de las barras para escalar después.
	_hp_bar_base_width = _hp_bar_fg.size.x
	_furia_bar_base_width = _furia_bar_fg.size.x

	# Conectar al player si lo hay.
	if not player_path.is_empty():
		var node: Node = get_node_or_null(player_path)
		if node is Player:
			_player = node
			_connect_player()

	# Botón Volver al Menú — top-right discreto. Útil para test loops.
	_build_back_button()


func _build_back_button() -> void:
	# Contenedor full-rect para anclar el botón correctamente dentro del CanvasLayer.
	var container := Control.new()
	container.name = "BackMenuContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(container)

	var btn := Button.new()
	btn.name = "BackToMenuBtn"
	btn.text = "MENU"
	btn.custom_minimum_size = Vector2(80, 44)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 0.85))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 2)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.14, 0.75)
	s.corner_radius_top_left     = 6
	s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left  = 6
	s.corner_radius_bottom_right = 6
	s.border_color = Color(0.4, 0.4, 0.6, 0.4)
	s.border_width_top    = 1
	s.border_width_right  = 1
	s.border_width_bottom = 1
	s.border_width_left   = 1
	btn.add_theme_stylebox_override("normal", s)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.18, 0.16, 0.28, 0.92)
	sh.corner_radius_top_left     = 6
	sh.corner_radius_top_right    = 6
	sh.corner_radius_bottom_left  = 6
	sh.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)

	# Anclar top-right con margen de 16px, dentro del container full-rect.
	btn.anchor_left   = 1.0
	btn.anchor_right  = 1.0
	btn.anchor_top    = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left   = -96.0
	btn.offset_right  = -16.0
	btn.offset_top    = 16.0
	btn.offset_bottom = 60.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	btn.pressed.connect(_on_back_to_menu_pressed)
	container.add_child(btn)


func _on_back_to_menu_pressed() -> void:
	# Limpiar modo prueba al volver.
	TestArenaConfig.exit_test_mode()
	# Asegurarse de que el juego no quede pausado.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _connect_player() -> void:
	if _player == null:
		return
	if _player.health != null:
		_hp_max = _player.health.max_health
		_player.health.health_changed.connect(_on_hp_changed)
		_on_hp_changed(_player.health.current_health, _hp_max)
	if _player.furia != null:
		_furia_max = _player.furia.max_furia
		_player.furia.furia_changed.connect(_on_furia_changed)
		_on_furia_changed(_player.furia.get_current(), _furia_max)
	if _player.shield != null and _shield_display != null:
		_player.shield.charges_changed.connect(_on_shield_charges_changed)
		_on_shield_charges_changed(_player.shield.current_charges, _player.shield.max_charges)


func _on_momentum_changed(new_level: int) -> void:
	_momentum_label.text = "%dx" % max(new_level, 1)
	_apply_momentum_visual(new_level)
	_apply_momentum_animation(new_level)
	_last_momentum_level = new_level


func _apply_momentum_visual(level: int) -> void:
	# Color del contador escala con nivel.
	if level >= 8:
		_momentum_label.add_theme_color_override("font_color", COLOR_HIGH)
	elif level >= 5:
		_momentum_label.add_theme_color_override("font_color", COLOR_MID)
	else:
		_momentum_label.add_theme_color_override("font_color", COLOR_LOW)
	# Glow extra al llegar al máximo.
	if level >= 10:
		_momentum_label.add_theme_constant_override("outline_size", 12)
		_momentum_label.add_theme_color_override("font_outline_color", COLOR_GOLD_OUTLINE)
	else:
		_momentum_label.add_theme_constant_override("outline_size", 6)
		_momentum_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))


func _apply_momentum_animation(new_level: int) -> void:
	# Pulse al cambiar nivel (overshoot scale).
	if _momentum_pulse_tween != null:
		_momentum_pulse_tween.kill()
	_momentum_pulse_tween = create_tween()
	_momentum_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_momentum_label.scale = Vector2.ONE
	_momentum_pulse_tween.tween_property(_momentum_label, "scale", Vector2(1.3, 1.3), 0.12)
	_momentum_pulse_tween.tween_property(_momentum_label, "scale", Vector2.ONE, 0.13)

	# Shake sutil si el nivel bajó.
	if new_level < _last_momentum_level and _last_momentum_level > 0:
		if _momentum_shake_tween != null:
			_momentum_shake_tween.kill()
		var origin: float = _momentum_label.position.x
		_momentum_shake_tween = create_tween()
		_momentum_shake_tween.tween_property(_momentum_label, "position:x", origin + 3.0, 0.04)
		_momentum_shake_tween.tween_property(_momentum_label, "position:x", origin - 3.0, 0.04)
		_momentum_shake_tween.tween_property(_momentum_label, "position:x", origin + 2.0, 0.04)
		_momentum_shake_tween.tween_property(_momentum_label, "position:x", origin, 0.03)


func _on_hp_changed(current: int, maximum: int) -> void:
	_hp_max = maximum
	var pct: float = float(current) / float(maximum) if maximum > 0 else 0.0
	_hp_bar_fg.size.x = _hp_bar_base_width * pct
	_hp_label.text = "%d / %d" % [current, maximum]


func _on_furia_changed(current: int, maximum: int) -> void:
	_furia_max = maximum
	var pct: float = float(current) / float(maximum) if maximum > 0 else 0.0
	_furia_bar_fg.size.x = _furia_bar_base_width * pct
	_furia_label.text = "%d" % current


func _on_shield_charges_changed(current: int, maximum: int) -> void:
	if _shield_display == null:
		return
	_shield_display.set_charges(current, maximum)


func _on_gold_changed(new_total: int, _delta: int) -> void:
	_update_gold_label(new_total)


func _update_gold_label(total: int) -> void:
	if _gold_label == null:
		return  # nodo no agregado al .tscn todavía — sin crash
	_gold_label.text = "Oro: %d" % total


func _on_equipped_changed(_slot: int, _item: ItemData) -> void:
	_update_set_bonus_display()


func _update_set_bonus_display() -> void:
	if _set_bonus_row == null:
		return
	if SetBonusSystem.active_pieces < 2:
		_set_bonus_row.visible = false
		return
	_set_bonus_row.visible = true
	var elem_name := _element_name(SetBonusSystem.active_element)
	var bonus_text := "%s %dpc" % [elem_name, SetBonusSystem.active_pieces]
	# Si 3pc, agregar nombre del bonus especial.
	if SetBonusSystem.active_pieces >= 3:
		var data: SetBonusData = SetBonusSystem.get_active_bonus_data()
		if data != null and data.bonus_3pc_name != "":
			bonus_text += " · " + data.bonus_3pc_name
	_set_bonus_label.text = bonus_text
	# Tinte de fondo según elemento.
	_set_bonus_bg.color = _element_color(SetBonusSystem.active_element)


func _element_name(elem: int) -> String:
	match elem:
		ItemData.Element.FUEGO:
			return "FUEGO"
		ItemData.Element.AGUA:
			return "AGUA"
		ItemData.Element.TIERRA:
			return "TIERRA"
		ItemData.Element.VIENTO:
			return "VIENTO"
		ItemData.Element.LUZ:
			return "LUZ"
		ItemData.Element.SOMBRA:
			return "SOMBRA"
		_:
			return "NEUTRAL"


func _element_color(elem: int) -> Color:
	match elem:
		ItemData.Element.FUEGO:
			return Color(0.7, 0.12, 0.08, 0.5)
		ItemData.Element.AGUA:
			return Color(0.08, 0.25, 0.7, 0.5)
		ItemData.Element.TIERRA:
			return Color(0.4, 0.22, 0.08, 0.5)
		ItemData.Element.VIENTO:
			return Color(0.30, 0.55, 0.30, 0.5)
		ItemData.Element.LUZ:
			return Color(0.85, 0.82, 0.55, 0.5)
		ItemData.Element.SOMBRA:
			return Color(0.30, 0.10, 0.45, 0.5)
		_:
			return Color(0.15, 0.15, 0.15, 0.4)
