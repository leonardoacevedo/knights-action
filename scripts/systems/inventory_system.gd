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
## A4: emitido cuando un item sale de un slot por reemplazo en equip().
## Permite a los listeners saber qué pieza quedó desequipada (la nueva llega por equipped_changed).
signal unequipped(slot: ItemData.Slot, prev_item: ItemData)

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
	# A4: avisar del item anterior antes de pisarlo (la pieza nueva llega por equipped_changed).
	var prev_item: ItemData = _equipped.get(to_equip.slot, null)
	_equipped[to_equip.slot] = to_equip
	if prev_item != null and prev_item != to_equip:
		unequipped.emit(to_equip.slot, prev_item)
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


# ─── Serialización para SaveSystem ───────────────────────────────────────────

## Serializa el estado completo del inventario. Llamado por SaveSystem.
## Items: base_path + refinement_level + afijos explícitos (instancia propia del jugador).
## Equipped: slot int → índice en array de items, -1 si vacío.
func _serialize_state() -> Dictionary:
	# Serializar items
	var items_arr: Array = []
	for item: ItemData in _items:
		items_arr.append(_serialize_item(item))

	# Serializar equipo: slot → índice en _items (-1 si vacío)
	var equipped_dict: Dictionary = {}
	for slot: int in _equipped:
		var equipped_item: ItemData = _equipped[slot]
		if equipped_item == null:
			equipped_dict[str(slot)] = -1
		else:
			var idx: int = _items.find(equipped_item)
			equipped_dict[str(slot)] = idx

	# Serializar materiales: StringName → int (convertir key a String para JSON)
	var mats_dict: Dictionary = {}
	for mat_id: StringName in _materials:
		mats_dict[str(mat_id)] = _materials[mat_id]

	return {
		"items": items_arr,
		"equipped": equipped_dict,
		"materials": mats_dict,
	}


## Restaura el estado desde un Dictionary guardado. Llamado por SaveSystem en _ready.
## Limpia el inventario antes de restaurar (arranca de cero, no acumula).
func _restore_state(data: Dictionary) -> void:
	# Limpiar sin emitir signals — los listeners aún no están conectados al arrancar.
	_items.clear()
	_materials.clear()
	for slot: int in _equipped:
		_equipped[slot] = null

	# Restaurar items
	var items_arr: Array = data.get("items", [])
	for item_dict in items_arr:
		if not item_dict is Dictionary:
			push_warning("InventorySystem._restore_state: item_dict no es Dictionary, saltando.")
			continue
		var restored: ItemData = _deserialize_item(item_dict)
		if restored != null:
			_items.append(restored)

	# Restaurar materiales
	var mats_dict: Dictionary = data.get("materials", {})
	for mat_key in mats_dict:
		var mat_id: StringName = StringName(str(mat_key))
		var count: int = int(mats_dict[mat_key])
		if count > 0:
			_materials[mat_id] = count

	# Restaurar equipo: slot → índice en _items
	var equipped_dict: Dictionary = data.get("equipped", {})
	for slot_key in equipped_dict:
		var slot: int = int(str(slot_key))
		var idx: int = int(equipped_dict[slot_key])
		if not _equipped.has(slot):
			push_warning("InventorySystem._restore_state: slot %d inválido, saltando." % slot)
			continue
		if idx < 0 or idx >= _items.size():
			_equipped[slot] = null
		else:
			_equipped[slot] = _items[idx]


## Serializa un ItemData individual a Dictionary.
func _serialize_item(item: ItemData) -> Dictionary:
	var affixes_arr: Array = []
	for affix: AffixData in item.affixes:
		affixes_arr.append({
			"stat_id": str(affix.stat_id),
			"display_name": affix.display_name,
			"value": affix.value,
		})
	return {
		"base_id": str(item.id),
		"base_path": item.resource_path,
		"refinement_level": item.refinement_level,
		"affixes": affixes_arr,
	}


## Deserializa un Dictionary a ItemData. Carga el .tres base, duplica y aplica overrides.
## Si el .tres base no existe (el jugador cambió la versión del juego), retorna null con warning.
func _deserialize_item(item_dict: Dictionary) -> ItemData:
	var base_path: String = item_dict.get("base_path", "")
	var base_id: StringName = StringName(str(item_dict.get("base_id", "")))

	# Intentar cargar por base_path (camino feliz).
	var base: ItemData = null
	if base_path != "" and ResourceLoader.exists(base_path):
		base = load(base_path) as ItemData

	# A9: fallback por base_id si el path no resolvió (el .tres se movió/renombró).
	# Escaneamos resources/items/ por id en vez de perder el item.
	if base == null and base_id != &"":
		var found_path: String = _resolve_item_path_by_id(base_id)
		if found_path != "":
			base = load(found_path) as ItemData
			if base != null:
				push_warning("InventorySystem._deserialize_item: '%s' no resolvió por path, recuperado por base_id '%s'." \
					% [base_path, base_id])

	if base == null:
		push_warning("InventorySystem._deserialize_item: no se pudo resolver item (path='%s', base_id='%s'). Item perdido." \
			% [base_path, base_id])
		return null

	var instance: ItemData = base.duplicate(true) as ItemData

	# Aplicar overrides del save: refinement_level siempre.
	instance.refinement_level = int(item_dict.get("refinement_level", 0))

	# Aplicar afijos si están guardados (la instancia del jugador puede tener afijos modificados).
	var saved_affixes: Array = item_dict.get("affixes", [])
	if saved_affixes.size() > 0:
		var new_affixes: Array[AffixData] = []
		for aff_dict in saved_affixes:
			if not aff_dict is Dictionary:
				continue
			var aff: AffixData = AffixData.new()
			aff.stat_id = StringName(str(aff_dict.get("stat_id", "")))
			aff.display_name = str(aff_dict.get("display_name", ""))
			aff.value = int(aff_dict.get("value", 0))
			new_affixes.append(aff)
		instance.affixes = new_affixes

	return instance


# ─── Privado ──────────────────────────────────────────────────────────────────

func _find_equipped_slot(item: ItemData) -> int:
	# Retorna el Slot donde está equipado, o -1 si no está equipado.
	for slot: int in _equipped:
		if _equipped[slot] == item:
			return slot
	return -1


## A9: índice id → path de items, construido de forma perezosa la primera vez que
## un deserialize necesita el fallback. Cachea para no re-escanear en cada item.
var _item_path_index: Dictionary = {}
var _item_index_built: bool = false


## Resuelve el path de un .tres de item por su id, escaneando resources/items/.
## Devuelve "" si no se encuentra. Usado como fallback de _deserialize_item (A9).
func _resolve_item_path_by_id(target_id: StringName) -> String:
	if not _item_index_built:
		_build_item_path_index("res://resources/items")
		_item_index_built = true
	return _item_path_index.get(target_id, "")


## Escanea recursivamente `dir_path` y llena _item_path_index con id → path
## por cada .tres que cargue como ItemData con id no vacío.
func _build_item_path_index(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = dir_path.path_join(file_name)
		if dir.current_is_dir():
			# Recursión en subcarpetas (armor/, shields/, weapons/, etc.).
			if file_name != "." and file_name != "..":
				_build_item_path_index(full_path)
		elif file_name.ends_with(".tres"):
			var res: ItemData = load(full_path) as ItemData
			if res != null and res.id != &"":
				# Primer match gana — no pisar si el id ya está indexado.
				if not _item_path_index.has(res.id):
					_item_path_index[res.id] = full_path
		file_name = dir.get_next()
	dir.list_dir_end()
