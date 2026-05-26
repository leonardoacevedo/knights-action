extends Resource
class_name CraftRecipeInput

# Un input individual de una receta de crafteo. GDD §5.5.
#
# Separado en sub-Resource propio porque Godot 4 no maneja bien
# Array[Dictionary] tipado en exports — es imposible de editar en el inspector.
# Con esta clase: New Resource → CraftRecipeInput → asignar material + count.

## Material requerido. Apunta a un .tres de MaterialData en resources/materials/.
@export var material: MaterialData

## Cantidad requerida de ese material.
@export_range(1, 99) var count: int = 1
