extends Node
# Autoload "SaveSystem"
#
# Persiste el estado del personaje entre cierres de Godot. GDD §6 / Fase 3.
# Persiste: PlayerProgression (nivel/XP/skills), InventorySystem (items/materiales/equipo), GoldSystem (oro).
# NO persiste: HP runtime, Momentum, StageManager, HUD, timers.
#
# Flujo de guardado:
#   - request_save() → debounce 0.5s → save_now() → escribe a .tmp → rename atómico.
#   - Señales clave de los sistemas conectadas en _ready.
#
# Flujo de carga:
#   - _ready() → load() → aplica estado a los 3 sistemas si existe savegame.json.
#
# Formato: JSON version 1. Debuggable, versionado para migrations futuras.
# Path: user://savegame.json (location varía por OS, ver Godot docs).


# ─── Constantes ───────────────────────────────────────────────────────────────

const SAVE_PATH: String = "user://savegame.json"
const SAVE_PATH_TMP: String = "user://savegame.json.tmp"
const CURRENT_VERSION: int = 1
const DEBOUNCE_SECONDS: float = 0.5


# ─── Signals ──────────────────────────────────────────────────────────────────

signal save_completed(path: String)
signal load_completed(path: String, was_valid: bool)
signal save_failed(reason: String)


# ─── Estado interno ───────────────────────────────────────────────────────────

var _debounce_timer: float = 0.0
var _save_pending: bool = false

# Override de path para tests headless (evita escribir a user://).
var _save_path_override: String = ""
var _tmp_path_override: String = ""


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Cargar primero, luego conectar señales.
	# Si conectáramos antes, _restore_state podría disparar stats_changed → request_save
	# durante el load mismo, generando un save redundante al inicio.
	load_save()
	_connect_signals()


func _process(delta: float) -> void:
	if not _save_pending:
		return
	_debounce_timer -= delta
	if _debounce_timer <= 0.0:
		_save_pending = false
		_debounce_timer = 0.0
		save_now()


# ─── API pública ──────────────────────────────────────────────────────────────

## Solicita un save con debounce. Seguro llamar en cada signal de cambio.
func request_save() -> void:
	_save_pending = true
	_debounce_timer = DEBOUNCE_SECONDS


## Guarda inmediatamente. Retorna true si tuvo éxito.
## Escribe primero a .tmp y luego hace rename atómico.
func save_now() -> bool:
	var data: Dictionary = _build_save_data()
	var json_str: String = JSON.stringify(data, "\t")

	var tmp_path: String = _tmp_path_override if _tmp_path_override != "" else SAVE_PATH_TMP
	var final_path: String = _save_path_override if _save_path_override != "" else SAVE_PATH

	# Escribir a .tmp primero — si Godot crashea aquí, el save anterior queda intacto.
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var err_msg: String = "No se pudo abrir '%s' para escritura. Error: %d" % [tmp_path, FileAccess.get_open_error()]
		push_error("SaveSystem: " + err_msg)
		save_failed.emit(err_msg)
		return false
	file.store_string(json_str)
	file.close()

	# Rename atómico: .tmp → .json. Si falla, save_failed pero save previo sigue intacto.
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		var err_msg: String = "No se pudo abrir user:// para rename."
		push_error("SaveSystem: " + err_msg)
		save_failed.emit(err_msg)
		return false

	# DirAccess.rename toma paths relativos al dir abierto si son solo nombres,
	# o paths absolutos. Usamos los paths completos para evitar ambigüedad.
	var rename_err: int = dir.rename(tmp_path, final_path)
	if rename_err != OK:
		var err_msg: String = "rename '%s' → '%s' falló. Error: %d" % [tmp_path, final_path, rename_err]
		push_error("SaveSystem: " + err_msg)
		save_failed.emit(err_msg)
		return false

	save_completed.emit(final_path)
	return true


## Carga el save. Retorna true si encontró y aplicó un save válido.
## Si no hay save, retorna false y los sistemas quedan en estado default.
## Nombre: load_save (no 'load') para no pisar la built-in load() de GDScript.
func load_save() -> bool:
	var final_path: String = _save_path_override if _save_path_override != "" else SAVE_PATH

	if not FileAccess.file_exists(final_path):
		load_completed.emit(final_path, false)
		return false

	var file: FileAccess = FileAccess.open(final_path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem.load: no se pudo abrir '%s'. Error: %d" % [final_path, FileAccess.get_open_error()])
		load_completed.emit(final_path, false)
		return false

	var content: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err: int = json.parse(content)
	if parse_err != OK:
		push_error("SaveSystem.load: JSON inválido en '%s'. Error: %s" % [final_path, json.get_error_message()])
		load_completed.emit(final_path, false)
		return false

	var data: Dictionary = json.get_data()
	if not data is Dictionary:
		push_error("SaveSystem.load: raíz del JSON no es Dictionary.")
		load_completed.emit(final_path, false)
		return false

	# Verificar versión. Si mismatch → intentar migration.
	var version: int = data.get("version", 0)
	if version != CURRENT_VERSION:
		data = _migrate(data, version)
		if data.is_empty():
			push_warning("SaveSystem.load: migration desde v%d falló o no hay datos. Nuevo personaje." % version)
			load_completed.emit(final_path, false)
			return false

	_apply_save_data(data)
	load_completed.emit(final_path, true)
	return true


## Borra el savegame. Usado en "Nueva Partida" / debug.
func delete_save() -> void:
	var final_path: String = _save_path_override if _save_path_override != "" else SAVE_PATH
	if FileAccess.file_exists(final_path):
		var dir: DirAccess = DirAccess.open("user://")
		if dir != null:
			dir.remove(final_path)


## Retorna true si existe un save en disco.
func has_save() -> bool:
	var final_path: String = _save_path_override if _save_path_override != "" else SAVE_PATH
	return FileAccess.file_exists(final_path)


# ─── Conexión de señales (auto-save) ──────────────────────────────────────────
#
# Cada señal con argumentos se conecta con una lambda que descarta los args.
# Godot 4 exige firmas compatibles; lambdas con parámetros explícitos resuelven eso.
# Las señales sin args se conectan directamente a _on_save_trigger.

func _connect_signals() -> void:
	# PlayerProgression
	var pp: Node = get_node_or_null("/root/PlayerProgression")
	if pp != null:
		# level_up(new_level: int, points_awarded: int)
		pp.level_up.connect(func(_lvl: int, _pts: int) -> void: request_save())
		# skill_unlocked(node: SkillNode)
		pp.skill_unlocked.connect(func(_node: SkillNode) -> void: request_save())
		# respec_done(refunded_points: int)
		pp.respec_done.connect(func(_pts: int) -> void: request_save())

	# InventorySystem
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv != null:
		# equipped_changed(slot: ItemData.Slot, item: ItemData)
		inv.equipped_changed.connect(func(_slot: ItemData.Slot, _item: ItemData) -> void: request_save())
		# materials_changed() — sin args
		inv.materials_changed.connect(_on_save_trigger)
		# item_added(item: ItemData)
		inv.item_added.connect(func(_item: ItemData) -> void: request_save())
		# item_removed(item: ItemData)
		inv.item_removed.connect(func(_item: ItemData) -> void: request_save())

	# GoldSystem
	var gs: Node = get_node_or_null("/root/GoldSystem")
	if gs != null:
		# gold_changed(new_total: int, delta: int)
		gs.gold_changed.connect(func(_total: int, _delta: int) -> void: request_save())

	# UpgradeManager
	var um: Node = get_node_or_null("/root/UpgradeManager")
	if um != null:
		if um.has_signal("refine_succeeded"):
			# refine_succeeded(result: RefineResult)
			um.refine_succeeded.connect(func(_res: RefineResult) -> void: request_save())
		if um.has_signal("refine_failed"):
			# refine_failed(result: RefineResult)
			um.refine_failed.connect(func(_res: RefineResult) -> void: request_save())

	# CraftingSystem
	var cs: Node = get_node_or_null("/root/CraftingSystem")
	if cs != null:
		if cs.has_signal("craft_succeeded"):
			# craft_succeeded(result: CraftResult)
			cs.craft_succeeded.connect(func(_res: CraftResult) -> void: request_save())

	# StageManager (checkpoint natural)
	var sm: Node = get_node_or_null("/root/StageManager")
	if sm != null:
		# stage_cleared(index: int)
		sm.stage_cleared.connect(func(_idx: int) -> void: request_save())


# Callback para señales sin argumentos.
func _on_save_trigger() -> void:
	request_save()


# ─── Construcción del save data ───────────────────────────────────────────────

func _build_save_data() -> Dictionary:
	var data: Dictionary = {}
	data["version"] = CURRENT_VERSION
	data["progression"] = _serialize_progression()
	data["inventory"] = _serialize_inventory()
	data["gold"] = _serialize_gold()
	return data


func _serialize_progression() -> Dictionary:
	var pp: Node = get_node_or_null("/root/PlayerProgression")
	if pp == null:
		push_warning("SaveSystem._serialize_progression: PlayerProgression no disponible.")
		return {}
	return pp._serialize_state()


func _serialize_inventory() -> Dictionary:
	var inv: Node = get_node_or_null("/root/InventorySystem")
	if inv == null:
		push_warning("SaveSystem._serialize_inventory: InventorySystem no disponible.")
		return {"items": [], "equipped": {}, "materials": {}}
	return inv._serialize_state()


func _serialize_gold() -> int:
	var gs: Node = get_node_or_null("/root/GoldSystem")
	if gs == null:
		push_warning("SaveSystem._serialize_gold: GoldSystem no disponible.")
		return 0
	return gs._serialize_state()


# ─── Aplicación del save data ─────────────────────────────────────────────────

func _apply_save_data(data: Dictionary) -> void:
	# Orden importante: Progression primero (no depende de Inventory),
	# luego Inventory (items antes de equipo), luego Gold.
	var pp_data: Dictionary = data.get("progression", {})
	if not pp_data.is_empty():
		var pp: Node = get_node_or_null("/root/PlayerProgression")
		if pp != null:
			pp._restore_state(pp_data)
		else:
			push_warning("SaveSystem._apply_save_data: PlayerProgression no disponible.")

	var inv_data: Dictionary = data.get("inventory", {})
	if not inv_data.is_empty():
		var inv: Node = get_node_or_null("/root/InventorySystem")
		if inv != null:
			inv._restore_state(inv_data)
		else:
			push_warning("SaveSystem._apply_save_data: InventorySystem no disponible.")

	var gold_val = data.get("gold", 0)
	if gold_val is int or gold_val is float:
		var gs: Node = get_node_or_null("/root/GoldSystem")
		if gs != null:
			gs._restore_state(int(gold_val))
		else:
			push_warning("SaveSystem._apply_save_data: GoldSystem no disponible.")


# ─── Migration ────────────────────────────────────────────────────────────────

## Hook para futuras migraciones de schema. Version 1 → N.
## Retorna un Dictionary migrado, o vacío si no se puede migrar.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	push_warning("SaveSystem._migrate: versión %d no soportada. No hay migration implementada. Nuevo personaje." % from_version)
	# En MVP: sin migration real. Retornar vacío → load() descarta el save corrupto/antiguo.
	return {}
