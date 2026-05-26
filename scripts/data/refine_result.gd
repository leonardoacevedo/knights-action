extends Resource
class_name RefineResult

# Resultado de un intento de refinamiento. GDD §5.6.
# Producido y emitido por UpgradeManager. La UI futura itera sus campos para
# mostrar animación de éxito/fallo, materiales consumidos y variación de nivel.
#
# Uso:
#   var result: RefineResult = UpgradeManager.attempt_refine(item, use_scroll)
#   UpgradeManager.refine_succeeded.connect(_on_refine_succeeded)
#   UpgradeManager.refine_failed.connect(_on_refine_failed)

# ─── Resultado principal ──────────────────────────────────────────────────────

## true si el intento subió el nivel, false si falló.
@export var success: bool = false

## Nivel de refinamiento ANTES del intento.
@export var previous_level: int = 0

## Nivel de refinamiento DESPUÉS del intento.
## Si success=true: previous_level + 1.
## Si penalty="level_loss" y sin protección: previous_level - 1.
## En cualquier otro caso de fallo: igual a previous_level.
@export var new_level: int = 0

# ─── Materiales consumidos ────────────────────────────────────────────────────

## Materiales consumidos durante este intento. StringName id → int count.
## Siempre incluye piedra_resonancia. Incluye pergamino_proteccion si se usó.
## NO incluye oro (pendiente implementación).
@export var materials_consumed: Dictionary = {}

## Oro consumido. Siempre 0 en Fase 2 — se implementa cuando llegue el sistema de Oro.
@export var gold_consumed: int = 0

# ─── Flags de contexto ────────────────────────────────────────────────────────

## true si el jugador usó un Pergamino de Protección en este intento.
@export var protected_by_scroll: bool = false

## true si el fallo aplicó la penalización de pérdida de nivel (downgrade).
## Solo puede ser true si penalty_type == "level_loss" Y protected_by_scroll == false.
@export var dropped_to_level: bool = false

## Tipo de penalización de este nivel: "none" / "materials_only" / "level_loss".
## Útil para que la UI muestre el riesgo retroactivamente en el log.
@export var penalty_type: String = "none"
