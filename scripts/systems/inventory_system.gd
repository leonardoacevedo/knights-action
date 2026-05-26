extends Node
# Autoload "InventorySystem"
#
# Gestiona inventario y equipo del jugador. Fuente de verdad de qué items
# tiene el jugador y qué tiene puesto en cada slot.
#
# NO aplica stats al player todavía — eso es la próxima iteración.
# NO persiste a disco — SaveSystem (futuro) será responsable.

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal equipped_changed(slot: ItemData.Slot, item: ItemData)

## Emitido cuando se agrega un material (puede emitirse varias veces por kill).
signal material_added(material: MaterialData, count: int)
## Emitido después de cualquier cambio en _materials (agregar o quitar).
## La UI puede escuchar este único signal para refrescar la vista de materiales.
signal materials_changed()
## Emitido cuando se quitan unidades de un material (consumo por crafteo/refinamiento).
signal material_removed(id: StringName, count: int)

# Inventario completo (items no equipados + equipados coexisten aquí).
var _items: Array[ItemData] = []

# Materiales: StringName id → int count. No mezclar con _items.
var _materials: Dictionary = {}

# Slot → ItemData equipado. Null si el slot está vacío.
var _equipped: Dictionary = {
	ItemData.Slot.ARMA: null,
	ItemData.Slot.ARMADURA: null,
	ItemData.Slot.ESCUDO: null,
}


# ─── API pública ──────────────────────────────────────────────────────────────

## Agrega una copia independiente del item al inventario y devuelve la instancia creada.
## duplicate(true) garantiza copia profunda — incluye sub-resources como AffixData.
## El .tres original queda inmutable; cada item del inventario es una instancia propia.
## Usar SIEMPRE el valor de retorno si se necesita la referencia para equip / refine / UI.
func add_item(item: ItemData) -> ItemData:
	if item == null:
		push_error("InventorySystem.add_item: item es null")
		return null
	var instance: ItemData = item.duplicate(true) as ItemData
	_items.append(instance)
	item_added.emit(instance)
	return instance


func remove_item(item: ItemData) -> bool:
	# Devuelve false si el item no estaba en el inventario.
	var idx: int = _items.find(item)
	if idx == -1:
		return false
	# Si estaba equipado, desequiparlo antes.
	var equipped_slot := _find_equipped_slot(item)
	if equipped_slot >= 0:
		_equipped[equipped_slot] = null
		equipped_changed.emit(equipped_slot, null)
	_items.remove_at(idx)
	item_removed.emit(item)
	return true


func get_all() -> Array[ItemData]:
	return _items.duplicate()


func equip(item: ItemData) -> void:
	# Si el item no está en el inventario, lo agrega primero.
	# Capturamos la instancia devuelta por add_item — es la copia real en _items,
	# no la referencia original que el caller nos pasó.
	var to_equip: ItemData = item
	if not _items.has(item):
		to_equip = add_item(item)
	# Si ya había algo en ese slot, queda en el inventario (no se elimina).
	_equipped[to_equip.slot] = to_equip
	equipped_changed.emit(to_equip.slot, to_equip)


func unequip(slot: ItemData.Slot) -> ItemData:
	# Devuelve el item que estaba equipado, o null si el slot estaba vacío.
	var previous: ItemData = _equipped.get(slot, null)
	if previous == null:
		return null
	_equipped[slot] = null
	equipped_changed.emit(slot, null)
	return previous


func get_equipped(slot: ItemData.Slot) -> ItemData:
	return _equipped.get(slot, null)


## Agrega `count` unidades de un material respetando max_stack.
## Devuelve la cantidad REALMENTE agregada (puede ser < count si llegó al cap).
func add_material(material: MaterialData, count: int = 1) -> int:
	if material == null:
		push_error("InventorySystem.add_material: material es null.")
		return 0
	if material.id == &"":
		push_error("InventorySystem.add_material: material sin id.")
		return 0
	# Guard: count <= 0 no tiene sentido, evita emitir signals con count=0 o sumar negativo.
	if count <= 0:
		return 0
	var current: int = _materials.get(material.id, 0)
	var space_left: int = material.max_stack - current
	if space_left <= 0:
		return 0
	var actually_added: int = mini(count, space_left)
	_materials[material.id] = current + actually_added
	material_added.emit(material, actually_added)
	materials_changed.emit()
	return actually_added


## Cantidad de un material en el inventario. 0 si no hay ninguno.
func get_material_count(id: StringName) -> int:
	return _materials.get(id, 0)


## Remueve `count` unidades. Devuelve false si no hay suficiente stock.
## No modifica el inventario si no hay stock completo (transacción atómica).
func remove_material(id: StringName, count: int) -> bool:
	# Guard: count <= 0 es no-op (transaccion vacia exitosa).
	if count <= 0:
		return true
	var current: int = _materials.get(id, 0)
	if current < count:
		return false
	var new_count: int = current - count
	if new_count == 0:
		_materials.erase(id)
	else:
		_materials[id] = new_count
	material_removed.emit(id, count)
	materials_changed.emit()
	return true


## Copia defensiva del diccionario de materiales. StringName id → int count.
func get_all_materials() -> Dictionary:
	return _materials.duplicate()


## Limpia inventario, equipo y materiales. Usar antes de reload de escena (Game Over → Reintentar).
## Default `quiet=true` — NO emite signals, asume que los listeners viejos están por queue_free
## y los nuevos del próximo árbol re-sincronizan en su _ready.
## Pasar `quiet=false` si un autoload sobrevive al reload y necesita re-sincronizar materiales
## (ej. UI persistente, no aplicable en Fase 2 pero queda preparado).
func reset(quiet: bool = true) -> void:
	_items.clear()
	_materials.clear()
	for slot: int in _equipped:
		_equipped[slot] = null
	if not quiet:
		materials_changed.emit()


# ─── Privado ──────────────────────────────────────────────────────────────────

func _find_equipped_slot(item: ItemData) -> int:
	# Retorna el Slot donde está equipado, o -1 si no está equipado.
	for slot: int in _equipped:
		if _equipped[slot] == item:
			return slot
	return -1
