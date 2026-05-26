extends Resource
class_name DropEntry

## Una entrada individual dentro de un DropTable.
## Define qué dropea, con qué probabilidad y en qué cantidad (para materiales).
## GDD §5.5 — materiales por zona; §111 — fórmula de drop_rate con momentum.

# ─── Tipo de drop ─────────────────────────────────────────────────────────────

enum DropType {
	ITEM,      ## Item equipable (ItemData). Count siempre = 1.
	MATERIAL,  ## Material de crafteo/refinamiento (MaterialData). Count = min..max.
}

@export var drop_type: DropType = DropType.MATERIAL

# ─── Payload ─────────────────────────────────────────────────────────────────
## Solo uno de los dos debe ser no-null según drop_type.

## Seteado cuando drop_type == ITEM. Null si es material.
@export var item_data: ItemData

## Seteado cuando drop_type == MATERIAL. Null si es item.
@export var material_data: MaterialData

# ─── Cantidad (solo aplica a MATERIAL) ───────────────────────────────────────

## Cantidad mínima de material que puede dropear. Inclusive.
@export_range(1, 99) var material_count_min: int = 1

## Cantidad máxima de material que puede dropear. Inclusive.
@export_range(1, 99) var material_count_max: int = 1

# ─── Probabilidad ────────────────────────────────────────────────────────────

## Peso relativo para futura selección ponderada exclusiva.
## No usado en Milestone A (cada entry se rolea independientemente).
## Reservado para extensión sin romper schema.
@export var weight: float = 1.0

## Probabilidad base de drop. 1.0 = 100%. El DropTable aplica el
## multiplicador de momentum antes de usar este valor. GDD §111.
@export_range(0.0, 1.0) var drop_chance: float = 1.0
