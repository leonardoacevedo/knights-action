extends Resource
class_name AffixData

# Stat secundaria de un item. Embedida en ItemData.affixes. GDD §5.2.
# stat_id usa StringName para comparaciones frecuentes (ej. &"hp", &"fire_res").

@export var stat_id: StringName = &""
@export var display_name: String = ""
@export var value: int = 0
