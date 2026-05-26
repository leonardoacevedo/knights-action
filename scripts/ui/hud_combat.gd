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

const COLOR_LOW := Color(1, 1, 1, 1)            # blanco, niveles 0-4
const COLOR_MID := Color(1, 0.72, 0.18, 1)      # naranja cálido, niveles 5-7
const COLOR_HIGH := Color(1, 0.32, 0.12, 1)     # rojo intenso, niveles 8-10

var _player: Player = null
var _hp_max: int = 100
var _furia_max: int = 100
var _hp_bar_base_width: float = 0.0
var _furia_bar_base_width: float = 0.0


func _ready() -> void:
	# Conectar Momentum global.
	MomentumSystem.momentum_changed.connect(_on_momentum_changed)
	_apply_momentum_visual(0)

	# Guardamos el ancho base de las barras para escalar después.
	_hp_bar_base_width = _hp_bar_fg.size.x
	_furia_bar_base_width = _furia_bar_fg.size.x

	# Conectar al player si lo hay.
	if not player_path.is_empty():
		var node: Node = get_node_or_null(player_path)
		if node is Player:
			_player = node
			_connect_player()


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


func _apply_momentum_visual(level: int) -> void:
	# Color del contador escala con nivel. Tamaño leve para enfatizar el cap.
	if level >= 8:
		_momentum_label.add_theme_color_override("font_color", COLOR_HIGH)
	elif level >= 5:
		_momentum_label.add_theme_color_override("font_color", COLOR_MID)
	else:
		_momentum_label.add_theme_color_override("font_color", COLOR_LOW)


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
