extends Resource
class_name MaterialData

## Datos de un material de crafteo/refinamiento. GDD §5.5.
##
## NO extiende ItemData — los materiales no son equipables y tienen
## reglas de stack propias. Solo comparten el enum Rarity.
##
## Crear: New Resource → MaterialData. Guardar en
## `resources/items/materials/<nombre>.tres`.

# ─── Identidad ────────────────────────────────────────────────────────────────

## ID único en snake_case. Lo usa InventorySystem como clave de diccionario.
## Ej: &"piedra_resonancia", &"escama_ignis".
@export var id: StringName = &""

## Nombre legible para UI. Lo asigna narrative-lore.
@export var display_name: String = ""

## Descripción de flavor/uso. Multi-línea para el inspector de Godot.
@export_multiline var description: String = ""

# ─── Clasificación ────────────────────────────────────────────────────────────

## Ícono del material. Se asigna cuando el arte esté disponible.
@export var icon: Texture2D

## Rareza reusada de ItemData — sin duplicar el enum. GDD §5.
@export var rarity: ItemData.Rarity = ItemData.Rarity.R1

# ─── Stack ────────────────────────────────────────────────────────────────────

## Cantidad máxima por stack en inventario. Los consumibles como Piedras de
## Resonancia conviene tenerlo en 999 para no cortar el farming.
@export_range(1, 999) var max_stack: int = 99
