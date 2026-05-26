extends Node
# Autoload "UpgradeManager"
#
# Dueño exclusivo de la lógica de refinamiento +1 a +10. GDD §5.6.
# Ningún otro sistema debe mutar ItemData.refinement_level directamente.
#
# Dependencias:
#   - InventorySystem (autoload) — consume materiales.
#   - ItemData, RefineResult, MaterialData (clases de datos).
#
# UI futura: conectarse a las signals refine_started / refine_succeeded / refine_failed.
# Fórmula documentada en .claude/docs/formulas.md.

# ─── Tabla de refinamiento ────────────────────────────────────────────────────
# Fiel a GDD §5.6. Campos:
#   success_chance  — probabilidad entre 0.0 y 1.0.
#   penalty         — "none" / "materials_only" / "level_loss".
#   stones          — Piedras de Resonancia por intento (siempre 1 en MVP).
#   gold            — Oro por intento. Consumido por GoldSystem.consume() en attempt_refine.
const REFINE_TABLE: Dictionary = {
	1:  { "success_chance": 1.00, "penalty": "none",           "stones": 1, "gold": 10 },
	2:  { "success_chance": 1.00, "penalty": "none",           "stones": 1, "gold": 20 },
	3:  { "success_chance": 1.00, "penalty": "none",           "stones": 1, "gold": 40 },
	4:  { "success_chance": 0.70, "penalty": "materials_only", "stones": 1, "gold": 80 },
	5:  { "success_chance": 0.70, "penalty": "materials_only", "stones": 1, "gold": 160 },
	6:  { "success_chance": 0.50, "penalty": "materials_only", "stones": 1, "gold": 320 },
	7:  { "success_chance": 0.50, "penalty": "materials_only", "stones": 1, "gold": 640 },
	8:  { "success_chance": 0.30, "penalty": "level_loss",     "stones": 1, "gold": 1000 },
	9:  { "success_chance": 0.20, "penalty": "level_loss",     "stones": 1, "gold": 2000 },
	10: { "success_chance": 0.10, "penalty": "level_loss",     "stones": 1, "gold": 4000 },
}

# IDs de materiales consumidos por refinamiento. GDD §5.5-5.6.
const ID_PIEDRA: StringName = &"piedra_resonancia"
const ID_PERGAMINO: StringName = &"pergamino_proteccion"

# Niveles donde el pergamino es aplicable. GDD §5.6.
const SCROLL_LEVELS: Array[int] = [8, 9, 10]

# Hook de test: cuando no es -1, fuerza el resultado del próximo attempt_refine.
# Solo usar en tests. Valor: 1 = éxito forzado, 0 = fallo forzado, -1 = libre.
var _force_outcome: int = -1

# Inyección de dependencia para tests: reemplaza el autoload InventorySystem.
# En producción siempre null — se usa el autoload global directamente.
# En tests: asignar un objeto duck-type con get_material_count y remove_material.
var _inventory_override: Object = null

# ─── Signals para UI futura ───────────────────────────────────────────────────

## Emitido justo antes de resolver el RNG. La UI puede usar esto para animación
## de "cargando" o para mostrar la probabilidad en pantalla (Pilar #2).
signal refine_started(item: ItemData, target_level: int)

## Emitido cuando el intento subió el nivel.
signal refine_succeeded(result: RefineResult)

## Emitido cuando el intento falló (con o sin pérdida de nivel).
signal refine_failed(result: RefineResult)

## Emitido cuando el intento es abortado antes de consumir materiales.
## reason: "max_level" | "insufficient_materials" | "scroll_not_applicable" | "invalid_item"
signal refine_aborted(reason: String)


# ─── API pública de consulta ──────────────────────────────────────────────────

## Devuelve true si el item puede intentar refinamiento (no es null, no es +10).
func can_refine(item: ItemData) -> bool:
	if item == null:
		return false
	return item.refinement_level < 10


## Nivel objetivo del próximo intento (current + 1).
func get_target_level(item: ItemData) -> int:
	if item == null:
		return 0
	return item.refinement_level + 1


## Probabilidad de éxito para el nivel objetivo. 0.0 si el nivel es inválido.
func get_success_chance(target_level: int) -> float:
	if not REFINE_TABLE.has(target_level):
		return 0.0
	return REFINE_TABLE[target_level]["success_chance"]


## Tipo de penalización para el nivel objetivo: "none" / "materials_only" / "level_loss".
func get_penalty_type(target_level: int) -> String:
	if not REFINE_TABLE.has(target_level):
		return "none"
	return REFINE_TABLE[target_level]["penalty"]


## Costo en materiales y oro para el nivel objetivo.
## Retorna {"stones": N, "gold": N}.
func get_cost(target_level: int) -> Dictionary:
	if not REFINE_TABLE.has(target_level):
		return { "stones": 0, "gold": 0 }
	var row: Dictionary = REFINE_TABLE[target_level]
	return { "stones": row["stones"], "gold": row["gold"] }


## true si el nivel objetivo requiere Pergamino para protegerse de downgrade.
## Solo +8, +9, +10. En niveles menores el pergamino no tiene efecto.
func requires_scroll_to_protect(target_level: int) -> bool:
	return target_level in SCROLL_LEVELS


## true si el item puede usar un pergamino en el próximo intento
## (target_level en SCROLL_LEVELS Y el inventario tiene al menos 1 Pergamino).
func can_use_scroll(item: ItemData) -> bool:
	if item == null:
		return false
	var target: int = get_target_level(item)
	if not (target in SCROLL_LEVELS):
		return false
	return _inv().get_material_count(ID_PERGAMINO) >= 1


# ─── Helper de inventario ─────────────────────────────────────────────────────

# Resuelve qué inventario usar: el override de tests o el autoload global.
func _inv() -> Object:
	if _inventory_override != null:
		return _inventory_override
	return InventorySystem


# ─── API principal ────────────────────────────────────────────────────────────

## Intenta refinar el item un nivel.
## use_protection_scroll: el jugador quiere usar un Pergamino para proteger contra downgrade.
##
## Flujo:
##   1. Validaciones (aborta sin consumir nada si falla — incluyendo oro insuficiente).
##   2. Consume Oro (GoldSystem.consume — siempre, sea éxito o fallo).
##   3. Consume materiales (Piedra + Pergamino si aplica — siempre).
##   4. RNG según tabla.
##   5. Aplica resultado al item.
##   6. Emite signal correspondiente.
##   7. Devuelve RefineResult.
##
func attempt_refine(item: ItemData, use_protection_scroll: bool = false) -> RefineResult:
	# Validación: item válido.
	if item == null:
		refine_aborted.emit("invalid_item")
		return null

	# Validación: nivel máximo.
	if item.refinement_level >= 10:
		refine_aborted.emit("max_level")
		return null

	var target_level: int = get_target_level(item)
	var row: Dictionary = REFINE_TABLE[target_level]

	# Validación: Pergamino usado fuera de +8/+9/+10.
	if use_protection_scroll and not (target_level in SCROLL_LEVELS):
		refine_aborted.emit("scroll_not_applicable")
		return null

	# Validación: oro suficiente (antes de consumir materiales — atómica).
	var gold_needed: int = row["gold"]
	if not GoldSystem.can_afford(gold_needed):
		refine_aborted.emit("insufficient_gold")
		return null

	# Validación: materiales suficientes (transacción atómica — chequeamos antes de consumir).
	var stones_needed: int = row["stones"]
	if _inv().get_material_count(ID_PIEDRA) < stones_needed:
		refine_aborted.emit("insufficient_materials")
		return null
	if use_protection_scroll and _inv().get_material_count(ID_PERGAMINO) < 1:
		refine_aborted.emit("insufficient_materials")
		return null

	# A partir de acá: intento confirmado. Emitir signal de inicio.
	refine_started.emit(item, target_level)

	# Consumir Oro (siempre, sea éxito o fallo — igual que las Piedras).
	GoldSystem.consume(gold_needed)

	# Consumir Piedra de Resonancia (siempre, sea éxito o fallo).
	_inv().remove_material(ID_PIEDRA, stones_needed)

	# Consumir Pergamino si se usa (siempre, sea éxito o fallo).
	if use_protection_scroll:
		_inv().remove_material(ID_PERGAMINO, 1)

	# Armar el resultado con contexto previo al RNG.
	var result := RefineResult.new()
	result.previous_level = item.refinement_level
	result.penalty_type = row["penalty"]
	result.protected_by_scroll = use_protection_scroll
	result.materials_consumed[ID_PIEDRA] = stones_needed
	if use_protection_scroll:
		result.materials_consumed[ID_PERGAMINO] = 1
	result.gold_consumed = gold_needed

	# RNG — o resultado forzado para tests.
	var succeeded: bool
	if _force_outcome == 1:
		succeeded = true
		_force_outcome = -1
	elif _force_outcome == 0:
		succeeded = false
		_force_outcome = -1
	else:
		succeeded = randf() <= row["success_chance"]

	if succeeded:
		item.refinement_level = target_level
		result.success = true
		result.new_level = target_level
		result.dropped_to_level = false
		refine_succeeded.emit(result)
	else:
		result.success = false
		if row["penalty"] == "level_loss" and not use_protection_scroll:
			# Baja 1 nivel. No puede bajar de 0.
			item.refinement_level = max(0, item.refinement_level - 1)
			result.dropped_to_level = true
		# "materials_only" o protegido: nivel sin cambio.
		result.new_level = item.refinement_level
		refine_failed.emit(result)

	return result


# ─── Helpers internos para tests ─────────────────────────────────────────────

## Fuerza el outcome del PRÓXIMO attempt_refine. Solo usar en tests.
## outcome: true = éxito forzado, false = fallo forzado.
func _test_force_outcome(outcome: bool) -> void:
	_force_outcome = 1 if outcome else 0
