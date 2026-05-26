extends Node
# Autoload "PlayerProgression"
#
# Gestiona nivel, XP y árbol de habilidades del player. GDD §6.
# Persiste entre stages; será leído/escrito por SaveSystem cuando exista.
#
# NO modifica player.gd directamente. Expone bonuses vía
# get_skill_bonus_flat/pct(), que PlayerStatsComponent consume en recalculate().
#
# Para testing manual desde consola de Godot:
#   PlayerProgression.add_xp(500)
#   PlayerProgression.unlock_node(&"guerrero_vitalidad_1")
#   PlayerProgression.respec()

# ─── Constantes de progresión ─────────────────────────────────────────────────

const LEVEL_MAX: int = 30
const XP_BASE: float = 100.0      # nivel 1→2 requiere 100 XP
const XP_EXPONENT: float = 1.5    # xp_requerida = 100 × nivel^1.5

# Stats base que aumentan automáticamente al subir de nivel (GDD §6.1).
# Números deliberadamente conservadores — balance-engineer ajustará post-playtest.
const HEALTH_PER_LEVEL: int = 5   # +5 HP por nivel (nivel 1=base, nivel 2=+5, etc.)
const FURIA_PER_LEVEL: int = 2    # +2 Furia max por nivel

# ─── Costo de respec ──────────────────────────────────────────────────────────

const RESPEC_GOLD_COST: int = 0                  # TODO: sistema de Oro (Fase 3+)
const RESPEC_MATERIAL_ID: StringName = &"hierba_antigua"
const RESPEC_MATERIAL_COUNT: int = 10

# ─── Ruta del árbol de nodos ──────────────────────────────────────────────────

const SKILL_TREE_PATH: String = "res://resources/skills/main_tree.tres"

# ─── Signals ──────────────────────────────────────────────────────────────────

signal xp_gained(amount: int, total_xp: int)
signal level_up(new_level: int, points_awarded: int)
signal skill_unlocked(node: SkillNode)
signal respec_done(refunded_points: int)
## Emitido cada vez que el bonus de skills cambia (unlock o respec).
## PlayerStatsComponent lo escucha para disparar recalculate().
signal stats_changed()

# ─── Estado runtime ───────────────────────────────────────────────────────────

var _level: int = 1
var _xp: int = 0
var _skill_points_available: int = 0
var _unlocked_nodes: Array[StringName] = []
var _tree: SkillTree = null

## Override de inventario para tests headless (mismo patrón que UpgradeManager).
## En producción: null → usa InventorySystem autoload.
var _inventory_override: Object = null


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_tree = load(SKILL_TREE_PATH) as SkillTree
	if _tree == null:
		push_error("PlayerProgression: no se pudo cargar '%s'. Árbol vacío." % SKILL_TREE_PATH)


# ─── API pública — Nivel y XP ─────────────────────────────────────────────────

func get_level() -> int:
	return _level


func get_xp() -> int:
	return _xp


## XP necesaria para subir DEL nivel actual al siguiente.
## Fórmula GDD §6.1: xp_requerida = 100 × nivel^1.5
func get_xp_for_next_level() -> int:
	return xp_for_level(_level)


## Fracción de progreso hacia el próximo nivel. 0.0 a 1.0.
func get_xp_progress() -> float:
	var needed: int = get_xp_for_next_level()
	if needed <= 0:
		return 1.0
	return clampf(float(_xp) / float(needed), 0.0, 1.0)


## XP requerida para subir desde `level` al siguiente. Fórmula canónica.
static func xp_for_level(level: int) -> int:
	return int(round(XP_BASE * pow(float(level), XP_EXPONENT)))


## Otorga XP. Puede disparar múltiples level-ups si la cantidad es grande.
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	if _level >= LEVEL_MAX:
		return  # cap MVP — no acumular XP más allá del máximo
	_xp += amount
	xp_gained.emit(amount, _xp)
	_process_level_ups()


## Sube niveles mientras XP sea suficiente y no se alcance el cap.
func _process_level_ups() -> void:
	while _level < LEVEL_MAX:
		var needed: int = get_xp_for_next_level()
		if _xp < needed:
			break
		_xp -= needed
		_level += 1
		_skill_points_available += 1
		level_up.emit(_level, 1)
	# Al alcanzar el cap, descartar XP residual (no tiene sentido acumular).
	if _level >= LEVEL_MAX:
		_xp = 0
	# stats_changed se emite aquí para batching (un solo disparo aunque subió varios niveles).
	stats_changed.emit()


# ─── API pública — Árbol de Skills ───────────────────────────────────────────

func get_skill_points_available() -> int:
	return _skill_points_available


func get_unlocked_node_ids() -> Array[StringName]:
	return _unlocked_nodes.duplicate()


func get_skill_tree() -> SkillTree:
	return _tree


func is_unlocked(node_id: StringName) -> bool:
	return node_id in _unlocked_nodes


## ¿El nodo es desbloqueable AHORA?
## Requiere: puntos disponibles, nodo no desbloqueado ya, prereqs cumplidos.
func can_unlock(node_id: StringName) -> bool:
	if _tree == null:
		return false
	var node: SkillNode = _tree.get_node_by_id(node_id)
	if node == null:
		return false
	if is_unlocked(node_id):
		return false
	if _skill_points_available < node.point_cost:
		return false
	for prereq_id: StringName in node.prerequisites:
		if not is_unlocked(prereq_id):
			return false
	return true


## Intenta desbloquear un nodo. Atómica: punto y nodo se modifican juntos.
## Retorna true si tuvo éxito.
func unlock_node(node_id: StringName) -> bool:
	if not can_unlock(node_id):
		return false
	var node: SkillNode = _tree.get_node_by_id(node_id)
	# Operación atómica: descuenta punto y registra nodo en la misma operación.
	_skill_points_available -= node.point_cost
	_unlocked_nodes.append(node_id)
	skill_unlocked.emit(node)
	stats_changed.emit()
	return true


## Resetea todos los nodos desbloqueados y devuelve los puntos invertidos.
## Cobra el costo en materiales. Retorna true si tuvo éxito.
func respec() -> bool:
	var inv := _get_inv()
	if inv == null:
		push_error("PlayerProgression.respec(): inventario no disponible")
		return false
	# Verificar materiales antes de tocar estado.
	if not _can_afford_respec(inv):
		return false
	# Consumir materiales.
	if RESPEC_MATERIAL_COUNT > 0:
		var ok: bool = inv.remove_material(RESPEC_MATERIAL_ID, RESPEC_MATERIAL_COUNT)
		if not ok:
			return false
	# Calcular puntos a devolver (suma de point_cost de nodos desbloqueados).
	var refunded: int = _count_invested_points()
	# Resetear estado de nodos (puntos de nivel NO se tocan — son del personaje, no del árbol).
	_skill_points_available += refunded
	_unlocked_nodes.clear()
	respec_done.emit(refunded)
	stats_changed.emit()
	return true


func _can_afford_respec(inv: Object) -> bool:
	if RESPEC_MATERIAL_COUNT <= 0:
		return true
	return inv.get_material_count(RESPEC_MATERIAL_ID) >= RESPEC_MATERIAL_COUNT


func _count_invested_points() -> int:
	if _tree == null:
		return _unlocked_nodes.size()  # fallback: 1 punto por nodo
	var total: int = 0
	for node_id: StringName in _unlocked_nodes:
		var node: SkillNode = _tree.get_node_by_id(node_id)
		if node != null:
			total += node.point_cost
		else:
			total += 1  # nodo huérfano (tree cambió): devolver 1 punto conservador
	return total


# ─── API pública — Bonus de Skills ───────────────────────────────────────────
#
# Estos métodos los consume PlayerStatsComponent.recalculate().
# Son deterministas: misma entrada → misma salida. No tienen side effects.

## Suma total de efectos FLAT de todos los nodos desbloqueados para el stat dado.
func get_skill_bonus_flat(stat: SkillEffect.Stat) -> float:
	return _sum_effects(stat, SkillEffect.Mode.FLAT)


## Suma total de efectos PCT de todos los nodos desbloqueados para el stat dado.
## Retorna fracción (0.10 = +10%), no porcentaje.
func get_skill_bonus_pct(stat: SkillEffect.Stat) -> float:
	return _sum_effects(stat, SkillEffect.Mode.PCT)


func _sum_effects(stat: SkillEffect.Stat, mode: SkillEffect.Mode) -> float:
	if _tree == null:
		return 0.0
	var total: float = 0.0
	for node_id: StringName in _unlocked_nodes:
		var node: SkillNode = _tree.get_node_by_id(node_id)
		if node == null:
			continue
		for effect: SkillEffect in node.effects:
			if effect.stat == stat and effect.mode == mode:
				total += effect.amount
	return total


# ─── Reset completo ───────────────────────────────────────────────────────────

## Reinicia el sistema completo. Llamar en Game Over / nueva partida.
## quiet=true no emite signals (listeners del árbol previo ya no existen).
func reset(quiet: bool = true) -> void:
	_level = 1
	_xp = 0
	_skill_points_available = 0
	_unlocked_nodes.clear()
	if not quiet:
		stats_changed.emit()


# ─── Privado — Inventario ─────────────────────────────────────────────────────

func _get_inv() -> Object:
	if _inventory_override != null:
		return _inventory_override
	# Los autoloads de Godot son nodos en /root/. Se accede por path, no por Engine.get_singleton.
	return get_node_or_null("/root/InventorySystem")
