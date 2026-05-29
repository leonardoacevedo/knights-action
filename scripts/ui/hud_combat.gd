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

	# Skill chips (3 slots, cooldown overlay). Conectado a PlayerSkillSystem.
	_build_skill_chips()
	PlayerSkillSystem.slot_equipped.connect(_on_slot_equipped)
	PlayerSkillSystem.cooldown_started.connect(_on_skill_cooldown_started)
	# Refrescar estado inicial post-restore de SaveSystem.
	for i in range(PlayerSkillSystem.MAX_SLOTS):
		var data: PlayerSkillData = PlayerSkillSystem.get_equipped(i)
		if data != null:
			_on_slot_equipped(i, data)

	# HUD redesign Fase 1 (28/05): PlayerAvatar + LevelBadge + StageLabel
	# matching imagen referencia aprobada por Leo.
	_build_player_avatar_with_level()
	_build_stage_label()
	# Conexiones para refresh
	PlayerProgression.level_up.connect(_on_player_level_up)
	StageManager.stage_started.connect(_on_stage_started_label)
	StageManager.stage_pending.connect(_on_stage_pending_label)
	# Refresh inicial
	_update_level_badge(PlayerProgression.get_level())
	_update_stage_label()

	# HUD Fase 2 (28/05): EnemyInfo top-right (avatar + nombre + HP + rareza).
	# Trackea el primer enemy R2+ del stage; cuando muere, oculta.
	_build_enemy_info()
	StageManager.stage_started.connect(_on_stage_started_enemy_info)
	StageManager.stage_cleared.connect(_on_stage_cleared_enemy_info)


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


# ─── Skill chips (slots 1/2/3 + CD overlay) ────────────────────────────────

var _skill_chips: Array[PanelContainer] = []
var _skill_cd_total: Array[float] = [0.0, 0.0, 0.0]
var _skill_cd_remaining: Array[float] = [0.0, 0.0, 0.0]


func _build_skill_chips() -> void:
	# HUD Fase 3 (28/05): chips visualization bottom-right encima de los botones
	# touch (BtnSkill1/2/3 + BtnAtk + BtnDash + BtnBlock viven en touch_controls.tscn).
	# Decisión Leo 28/05: 3 chips circulares + Atk Básico más grande (touch_controls
	# pendiente de update a 110dp Atk — esta sesión solo reorganiza chips visualization).
	var box: HBoxContainer = HBoxContainer.new()
	box.name = "SkillChipsContainer"
	box.add_theme_constant_override("separation", 8)
	# Anchor bottom-right encima de los botones touch (que están -114→-24 desde el bottom).
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -16.0 - (56.0 * 3 + 8.0 * 2)  # 3 chips 56dp + 2 gaps 8dp
	box.offset_top = -240.0  # encima de los buttons (que son @ -114→-24)
	box.offset_right = -16.0
	box.offset_bottom = -184.0
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	for i in range(PlayerSkillSystem.MAX_SLOTS):
		var chip: PanelContainer = _make_skill_chip(i + 1)
		_skill_chips.append(chip)
		box.add_child(chip)


func _make_skill_chip(slot_num: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(56, 56)  # Fase 3: 56dp matching spec
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.20, 0.85)
	# Corner radius más alto para look circular-ish.
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.border_color = Color(0.45, 0.45, 0.70, 0.55)
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	panel.add_theme_stylebox_override("panel", style)
	# Skill name short (3 chars uppercase, color del skill).
	var skill_lbl: Label = Label.new()
	skill_lbl.name = "SkillName"
	skill_lbl.text = "·"
	skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_lbl.add_theme_font_size_override("font_size", 14)
	skill_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
	skill_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	skill_lbl.add_theme_constant_override("outline_size", 2)
	skill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(skill_lbl)
	# Slot number en esquina (mini badge).
	var num_lbl: Label = Label.new()
	num_lbl.name = "SlotLabel"
	num_lbl.text = str(slot_num)
	num_lbl.add_theme_font_size_override("font_size", 10)
	num_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 0.85))
	num_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	num_lbl.add_theme_constant_override("outline_size", 2)
	num_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	num_lbl.offset_left = 3
	num_lbl.offset_top = 1
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(num_lbl)
	# CD overlay (oscuro semi-transparente que ocupa altura = remaining/total).
	var cd_overlay: ColorRect = ColorRect.new()
	cd_overlay.name = "CDOverlay"
	cd_overlay.color = Color(0, 0, 0, 0.55)
	cd_overlay.anchor_left = 0.0
	cd_overlay.anchor_right = 1.0
	cd_overlay.anchor_top = 0.0
	cd_overlay.anchor_bottom = 0.0  # invisible al inicio
	cd_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_overlay.visible = false
	panel.add_child(cd_overlay)
	return panel


func _on_slot_equipped(slot: int, data: PlayerSkillData) -> void:
	if slot < 0 or slot >= _skill_chips.size():
		return
	var chip: PanelContainer = _skill_chips[slot]
	var skill_lbl: Label = chip.get_node_or_null("SkillName") as Label
	if skill_lbl == null:
		return
	if data == null:
		skill_lbl.text = "·"
		skill_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
		return
	# 3 chars del display_name como icono provisional.
	var short: String = (data.display_name as String).substr(0, 3).to_upper()
	skill_lbl.text = short
	# Color del skill (PlayerSkillData.color) si existe, sino blanco.
	var c: Color = data.color if data.color.a > 0.0 else Color(1, 1, 1, 1)
	skill_lbl.add_theme_color_override("font_color", c)


func _on_skill_cooldown_started(slot: int, cooldown: float) -> void:
	if slot < 0 or slot >= _skill_chips.size():
		return
	_skill_cd_total[slot] = cooldown
	_skill_cd_remaining[slot] = cooldown
	var chip: PanelContainer = _skill_chips[slot]
	var overlay: ColorRect = chip.get_node_or_null("CDOverlay") as ColorRect
	if overlay != null:
		overlay.visible = true
		overlay.anchor_bottom = 1.0  # cubre full al iniciar


func _process(delta: float) -> void:
	_process_skill_cooldowns(delta)


func _process_skill_cooldowns(delta: float) -> void:
	for i in range(_skill_cd_remaining.size()):
		if _skill_cd_remaining[i] <= 0.0:
			continue
		_skill_cd_remaining[i] -= delta
		var chip: PanelContainer = _skill_chips[i]
		var overlay: ColorRect = chip.get_node_or_null("CDOverlay") as ColorRect
		if overlay == null:
			continue
		if _skill_cd_remaining[i] <= 0.0:
			overlay.visible = false
			overlay.anchor_bottom = 0.0
			continue
		# Overlay shrinks from full → empty: anchor_bottom = t (remaining ratio).
		# Si no hay cooldown total, overlay vacío (evita el flash full de 1 frame, M6).
		var t: float
		if _skill_cd_total[i] <= 0.0:
			t = 0.0
		else:
			t = _skill_cd_remaining[i] / _skill_cd_total[i]
		overlay.anchor_bottom = clamp(t, 0.0, 1.0)


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


# ─── HUD Fase 1 (28/05): Avatar + LevelBadge + StageLabel ──────────────────
# Implementación matching imagen referencia. Decisiones Leo 28/05:
# - Furia canon (no Maná). 6 botones GDD §4.2 (Atk grande). C híbrido portraits
#   (PNG si existe, procedural fallback). Stage + Momentum ambos top-center.

const AVATAR_SIZE: float = 64.0
const AVATAR_BORDER_WIDTH: float = 3.0
const AVATAR_BORDER_COLOR: Color = Color(0.83, 0.62, 0.30, 0.95)  # dorado
const LEVEL_BADGE_SIZE: float = 32.0

var _level_label: Label = null
var _stage_label: Label = null


## Crea contenedor avatar (top-left) con LevelBadge debajo.
## Avatar: PNG si existe `assets/art/portraits/player_knight.png`, sino procedural
## (círculo con border dorado + color elemento del weapon + letra "K").
## LevelBadge: círculo dorado 32×32 con número de nivel.
func _build_player_avatar_with_level() -> void:
	# Container holder anclado top-left fuera del StatsContainer existente.
	var holder: Control = Control.new()
	holder.name = "PlayerAvatarHolder"
	holder.anchor_left = 0.0
	holder.anchor_top = 0.0
	holder.offset_left = 16.0
	holder.offset_top = 16.0
	holder.offset_right = 16.0 + AVATAR_SIZE
	holder.offset_bottom = 16.0 + AVATAR_SIZE + LEVEL_BADGE_SIZE + 6.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	# Mover StatsContainer existente a la derecha del avatar para no solapar.
	var stats: Node = get_node_or_null("StatsContainer")
	if stats is Control:
		(stats as Control).offset_left = 16.0 + AVATAR_SIZE + 12.0

	# Avatar canvas
	var avatar: Control = Control.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.anchor_left = 0.0
	avatar.anchor_top = 0.0
	avatar.offset_right = AVATAR_SIZE
	avatar.offset_bottom = AVATAR_SIZE
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(avatar)
	_populate_avatar(avatar, &"player_knight", _player_element_color(), "K")

	# LevelBadge debajo del avatar
	var badge_holder: Control = Control.new()
	badge_holder.name = "LevelBadge"
	badge_holder.custom_minimum_size = Vector2(LEVEL_BADGE_SIZE, LEVEL_BADGE_SIZE)
	badge_holder.anchor_left = 0.5
	badge_holder.anchor_right = 0.5
	badge_holder.offset_left = -LEVEL_BADGE_SIZE * 0.5
	badge_holder.offset_top = AVATAR_SIZE + 4.0
	badge_holder.offset_right = LEVEL_BADGE_SIZE * 0.5
	badge_holder.offset_bottom = AVATAR_SIZE + 4.0 + LEVEL_BADGE_SIZE
	badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge_holder)
	_build_circle_badge(badge_holder, LEVEL_BADGE_SIZE * 0.5,
		Color(0.10, 0.08, 0.05, 0.95), AVATAR_BORDER_COLOR)
	var lvl_lbl: Label = Label.new()
	lvl_lbl.name = "LevelNumber"
	lvl_lbl.text = "1"
	lvl_lbl.add_theme_font_size_override("font_size", 16)
	lvl_lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.55, 1))
	lvl_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lvl_lbl.add_theme_constant_override("outline_size", 3)
	lvl_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_holder.add_child(lvl_lbl)
	_level_label = lvl_lbl


## Pinta el avatar: TextureRect si PortraitFactory devuelve PNG, sino procedural.
func _populate_avatar(parent: Control, id: StringName, fill_color: Color, fallback_letter: String) -> void:
	var tex: Texture2D = null
	# PortraitFactory autoload puede no estar cargado en tests headless.
	var pf: Node = get_node_or_null("/root/PortraitFactory")
	if pf != null and pf.has_method("get_portrait"):
		tex = pf.call("get_portrait", id) as Texture2D
	if tex != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rect)
		# Border dorado sobre la textura (Line2D circular).
		_draw_border_ring(parent, AVATAR_SIZE * 0.5, AVATAR_BORDER_COLOR, AVATAR_BORDER_WIDTH)
		return
	# Fallback procedural: círculo color elemento + letra inicial + border.
	_build_circle_badge(parent, AVATAR_SIZE * 0.5,
		fill_color, AVATAR_BORDER_COLOR, AVATAR_BORDER_WIDTH)
	var letter: Label = Label.new()
	letter.text = fallback_letter
	letter.add_theme_font_size_override("font_size", 32)
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	letter.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	letter.add_theme_constant_override("outline_size", 4)
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(letter)


## Círculo procedural con relleno y ring. Útil para avatar fallback + level badge.
func _build_circle_badge(parent: Control, radius: float,
		fill_color: Color, ring_color: Color, ring_width: float = 2.0) -> void:
	var center: Vector2 = Vector2(radius, radius)
	# Fill
	var fill: Polygon2D = Polygon2D.new()
	fill.color = fill_color
	var pts: PackedVector2Array = PackedVector2Array()
	var segs: int = 28
	for i in range(segs):
		var ang: float = i * TAU / float(segs)
		pts.append(center + Vector2(cos(ang) * radius, sin(ang) * radius))
	fill.polygon = pts
	parent.add_child(fill)
	# Ring border
	_draw_border_ring(parent, radius, ring_color, ring_width)


func _draw_border_ring(parent: Control, radius: float, color: Color, width: float) -> void:
	var center: Vector2 = Vector2(radius, radius)
	var ring: Line2D = Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.closed = true
	var segs: int = 28
	for i in range(segs):
		var ang: float = i * TAU / float(segs)
		ring.add_point(center + Vector2(cos(ang) * radius, sin(ang) * radius))
	parent.add_child(ring)


## Color sugerido para el avatar fallback según elemento del arma equipada.
func _player_element_color() -> Color:
	var weapon: ItemData = InventorySystem.get_equipped(ItemData.Slot.ARMA)
	var elem: int = weapon.element if weapon != null else 0
	var pf: Node = get_node_or_null("/root/PortraitFactory")
	if pf != null and pf.has_method("get_element_color"):
		return pf.call("get_element_color", elem) as Color
	return Color(0.32, 0.72, 0.53, 0.92)  # default TIERRA


## Label top-center sobre Momentum mostrando zona + stage.
## Format: "Mundo N: <zona_display> - Etapa K/Total"
func _build_stage_label() -> void:
	var holder: Control = Control.new()
	holder.name = "StageLabelHolder"
	holder.anchor_left = 0.0
	holder.anchor_right = 1.0
	holder.anchor_top = 0.0
	holder.offset_left = 0.0
	holder.offset_top = 4.0
	holder.offset_right = 0.0
	holder.offset_bottom = 24.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var lbl: Label = Label.new()
	lbl.name = "StageLabel"
	lbl.text = "—"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 0.85))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	_stage_label = lbl


# ── Handlers de refresh ────────────────────────────────────────────────────

func _on_player_level_up(new_level: int, _points: int) -> void:
	_update_level_badge(new_level)


func _update_level_badge(level: int) -> void:
	if _level_label != null:
		_level_label.text = str(level)


func _on_stage_started_label(_data: StageData, _index: int) -> void:
	_update_stage_label()


func _on_stage_pending_label(_data: StageData, _index: int) -> void:
	_update_stage_label()


func _update_stage_label() -> void:
	if _stage_label == null:
		return
	var zone: int = StageManager.current_zone if StageManager != null else 1
	var idx: int = StageManager.current_index() if StageManager != null else 0
	var total: int = StageManager.total_stages() if StageManager != null else 1
	# Sin run activa (idx < 0): no mintamos "Etapa 1/1", mostrar guion (M15).
	if idx < 0:
		_stage_label.text = "—"
		return
	var zone_name: String = _zone_display_name(zone)
	# Display 1-based.
	var stage_n: int = idx + 1
	_stage_label.text = "Mundo %d: %s — Etapa %d/%d" % [zone, zone_name, stage_n, total]


func _zone_display_name(zone: int) -> String:
	match zone:
		1: return "Valle de los Ecos"
		2: return "Fragua Cenicienta"
		3: return "Acueducto del Lamento"
		4: return "Cumbres de la Tempestad"
		_: return "Desconocida"


# ── HUD Fase 2: EnemyInfo top-right ────────────────────────────────────────

var _enemy_info_holder: Control = null
var _enemy_avatar: Control = null
var _enemy_name_label: Label = null
var _enemy_rarity_label: Label = null
var _enemy_hp_bar_fg: ColorRect = null
var _enemy_hp_bar_base_width: float = 0.0
var _tracked_enemy: Node = null


func _build_enemy_info() -> void:
	var holder: Control = Control.new()
	holder.name = "EnemyInfoHolder"
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.anchor_top = 0.0
	holder.offset_left = -(16.0 + 220.0 + 12.0 + AVATAR_SIZE)
	holder.offset_top = 16.0
	holder.offset_right = -16.0
	holder.offset_bottom = 16.0 + AVATAR_SIZE + 6.0
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false  # oculto hasta detectar enemy R2+
	add_child(holder)
	_enemy_info_holder = holder

	# Stats column (nombre + HP bar + rareza) anclada a la izq del avatar.
	var stats: VBoxContainer = VBoxContainer.new()
	stats.name = "EnemyStats"
	stats.add_theme_constant_override("separation", 4)
	stats.anchor_left = 0.0
	stats.anchor_right = 1.0
	stats.anchor_top = 0.0
	stats.offset_right = -(AVATAR_SIZE + 8.0)
	stats.offset_bottom = AVATAR_SIZE
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stats)

	var name_lbl: Label = Label.new()
	name_lbl.name = "EnemyName"
	name_lbl.text = "—"
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.85, 1))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(name_lbl)
	_enemy_name_label = name_lbl

	# HP bar (mirror del player HP pero roja).
	var bar_row: HBoxContainer = HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_END
	stats.add_child(bar_row)
	var hp_bg: ColorRect = ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(180, 18)
	hp_bg.color = Color(0.08, 0.08, 0.10, 0.85)
	bar_row.add_child(hp_bg)
	var hp_fg: ColorRect = ColorRect.new()
	hp_fg.offset_left = 2.0
	hp_fg.offset_top = 2.0
	hp_fg.offset_right = 178.0
	hp_fg.offset_bottom = 16.0
	hp_fg.color = Color(0.85, 0.20, 0.22, 1)
	hp_bg.add_child(hp_fg)
	_enemy_hp_bar_fg = hp_fg
	_enemy_hp_bar_base_width = 176.0

	var rarity_lbl: Label = Label.new()
	rarity_lbl.name = "EnemyRarity"
	rarity_lbl.text = "—"
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 0.9))
	rarity_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	rarity_lbl.add_theme_constant_override("outline_size", 2)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(rarity_lbl)
	_enemy_rarity_label = rarity_lbl

	# Avatar circular a la derecha del stats.
	var avatar: Control = Control.new()
	avatar.name = "EnemyAvatar"
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.anchor_left = 1.0
	avatar.anchor_right = 1.0
	avatar.anchor_top = 0.0
	avatar.offset_left = -AVATAR_SIZE
	avatar.offset_bottom = AVATAR_SIZE
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(avatar)
	_enemy_avatar = avatar


## Cuando arranca un stage nuevo, buscar el primer enemy R2+ y trackearlo.
func _on_stage_started_enemy_info(data: StageData, _index: int) -> void:
	# Esperar a que los enemies se spawneen (próximo frame).
	await get_tree().process_frame
	_pick_tracked_enemy(data)


func _on_stage_cleared_enemy_info(_index: int) -> void:
	_hide_enemy_info()


func _pick_tracked_enemy(data: StageData) -> void:
	if data == null:
		return
	var best: Node = _find_best_r2_enemy(null)
	if best == null:
		_hide_enemy_info()
		return
	_track_enemy(best)


## Busca el enemy R2+ vivo de mayor rareza en el grupo "enemy".
## `exclude`: nodo a ignorar (ej. el tracked que acaba de morir). Devuelve null si no queda ninguno.
func _find_best_r2_enemy(exclude: Node) -> Node:
	var best: Node = null
	var best_rarity: int = -1
	for child in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(child):
			continue
		if child == exclude:
			continue
		# Descartar el que ya está muerto (su HealthComponent reporta <= 0).
		var h: Node = child.get_node_or_null("HealthComponent")
		if h != null and h.get("current_health") != null and int(h.get("current_health")) <= 0:
			continue
		var r: int = int(child.get("rarity")) if child.get("rarity") != null else 0
		if r >= 1 and r > best_rarity:  # R2 = enum value 1
			best = child
			best_rarity = r
	return best


func _track_enemy(enemy: Node) -> void:
	# Limpiar tracking previo.
	if _tracked_enemy != null and is_instance_valid(_tracked_enemy):
		var h_prev: Node = _tracked_enemy.get("health") if _tracked_enemy.get("health") != null else _tracked_enemy.get_node_or_null("HealthComponent")
		if h_prev != null and h_prev.has_signal("died"):
			if h_prev.died.is_connected(_on_tracked_enemy_died):
				h_prev.died.disconnect(_on_tracked_enemy_died)
			if h_prev.health_changed.is_connected(_on_tracked_enemy_hp_changed):
				h_prev.health_changed.disconnect(_on_tracked_enemy_hp_changed)
	_tracked_enemy = enemy
	if _enemy_info_holder == null:
		return
	_enemy_info_holder.visible = true
	# Nombre: usar boss data o "<Clase> <Rarity>" como fallback.
	var nm: String = _enemy_display_name(enemy)
	if _enemy_name_label != null:
		_enemy_name_label.text = nm
	# Rareza label.
	var rarity: int = int(enemy.get("rarity")) if enemy.get("rarity") != null else 0
	var rarity_text: String = _rarity_display(rarity)
	if _enemy_rarity_label != null:
		_enemy_rarity_label.text = rarity_text
	# Conectar HealthComponent.
	var health: Node = enemy.get_node_or_null("HealthComponent")
	if health != null:
		if health.has_signal("died"):
			health.died.connect(_on_tracked_enemy_died)
		if health.has_signal("health_changed"):
			health.health_changed.connect(_on_tracked_enemy_hp_changed)
			_on_tracked_enemy_hp_changed(health.get("current_health"), health.get("max_health"))
	# Avatar: rellenar fallback procedural según clase + element.
	for child in _enemy_avatar.get_children():
		child.queue_free()
	var elem: int = int(enemy.get("element")) if enemy.get("element") != null else 0
	var fill: Color = PortraitFactory.get_element_color(elem)
	var initial: String = nm.substr(0, 1).to_upper()
	# Si el enemy es boss → intentar PNG con id `boss_<nombre>`.
	var portrait_id: StringName = StringName(_enemy_portrait_id(enemy))
	_populate_avatar(_enemy_avatar, portrait_id, fill, initial)


func _on_tracked_enemy_hp_changed(current: Variant, maximum: Variant) -> void:
	if _enemy_hp_bar_fg == null:
		return
	var cur_i: int = int(current) if current != null else 0
	var max_i: int = max(int(maximum) if maximum != null else 1, 1)
	var pct: float = clamp(float(cur_i) / float(max_i), 0.0, 1.0)
	_enemy_hp_bar_fg.size.x = _enemy_hp_bar_base_width * pct


func _on_tracked_enemy_died() -> void:
	# Al morir el tracked, buscar el siguiente R2+ vivo (excluyendo el que murió).
	# Si no queda ninguno, recién ahí ocultar el panel (A12).
	var died: Node = _tracked_enemy
	var next: Node = _find_best_r2_enemy(died)
	if next != null:
		_track_enemy(next)
	else:
		_hide_enemy_info()


func _hide_enemy_info() -> void:
	_tracked_enemy = null
	if _enemy_info_holder != null:
		_enemy_info_holder.visible = false


func _enemy_display_name(enemy: Node) -> String:
	# Si es boss conocido, devolver nombre. Sino "<Clase> R<rarity>".
	var nm: String = String(enemy.name).replace("BossGuardian", "Guardián de la Maleza") \
		.replace("BossIgnis", "Ignis") \
		.replace("BossLyss", "Lyss") \
		.replace("BossVael", "Vael") \
		.replace("BossDuelista", "Duelista") \
		.replace("BossCazadora", "Cazadora") \
		.replace("BossHeraldo", "Heraldo")
	if nm.begins_with("Enemy"):
		var cls: int = int(enemy.get("enemy_class")) if enemy.get("enemy_class") != null else 0
		var rar: int = int(enemy.get("rarity")) if enemy.get("rarity") != null else 0
		var class_name_str: String = (["Guerrero", "Tanque", "Arquero", "Mago"][cls] if cls < 4 else "Enemigo")
		var rar_str: String = "R" + str(rar + 1)
		nm = class_name_str + " " + rar_str
	return nm


func _enemy_portrait_id(enemy: Node) -> String:
	var nm: String = String(enemy.name).to_lower()
	if nm.begins_with("boss"):
		return nm
	# Fallback enemy_class id.
	var cls: int = int(enemy.get("enemy_class")) if enemy.get("enemy_class") != null else 0
	# Parentizar para que el índice solo se evalúe cuando cls < 4 (evita IndexError, M4).
	return "enemy_" + (["melee", "tank", "archer", "mage"][cls] if cls < 4 else "unknown")


func _rarity_display(rarity: int) -> String:
	# Enum: R1=0, R2=1, R3=2, R4=3
	match rarity:
		0: return "Enemigo R1"
		1: return "Enemigo R2"
		2: return "Enemigo R3"
		3: return "BOSS R4"
	return "Enemigo"
