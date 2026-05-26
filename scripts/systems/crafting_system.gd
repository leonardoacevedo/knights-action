extends Node
# Autoload "CraftingSystem"
#
# Dueño exclusivo de la lógica de crafteo de items. GDD §5.5.
# Las recetas son fijas en MVP — no hay descubrimiento ni desbloqueo dinámico.
#
# Dependencias:
#   - InventorySystem (autoload) — consulta y consume materiales, agrega el item resultante.
#   - CraftRecipe, CraftRecipeInput, CraftResult, ItemData (clases de datos).
#
# UI futura: conectarse a craft_started / craft_succeeded / craft_aborted.
# NO tocar UpgradeManager ni DropSystem — sistemas paralelos independientes.
#
# TODO (Fusión): la fusión 3xR(n) → 1xR(n+1) es feature separada post-Fase 2.
#   No va aquí — tendrá su propio FusionSystem.
# TODO (Recetas desbloqueables): en MVP todas las recetas están disponibles desde
#   el arranque. El flag CraftRecipe.required_player_level queda preparado para esto.


# ─── Signals para UI futura ───────────────────────────────────────────────────

## Emitido cuando se agrega una receta nueva al registro (útil para UI de crafteo).
signal recipe_added(recipe: CraftRecipe)

## Emitido justo antes de consumir materiales. La UI puede mostrar animación de inicio.
signal craft_started(recipe: CraftRecipe)

## Emitido cuando el crafteo completó con éxito.
signal craft_succeeded(result: CraftResult)

## Emitido cuando el crafteo fue abortado (materiales insuficientes, receta inválida, etc.).
signal craft_aborted(result: CraftResult)


# ─── Estado interno ───────────────────────────────────────────────────────────

# Lista de recetas conocidas. Cargada en _ready desde resources/recipes/*.tres.
var _recipes: Array[CraftRecipe] = []

# Inyección de dependencia para tests — reemplaza el autoload InventorySystem.
# En producción siempre null. En tests: objeto duck-type con la API de InventorySystem.
var _inventory_override: Object = null


# ─── Ciclo de vida ────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_recipes_from_disk()


func _load_recipes_from_disk() -> void:
	# Carga todos los .tres de resources/recipes/ al arrancar.
	# Si la carpeta no existe o está vacía, continúa sin recetas (log de advertencia).
	var dir := DirAccess.open("res://resources/recipes")
	if dir == null:
		push_warning("CraftingSystem: carpeta res://resources/recipes/ no existe. Sin recetas.")
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path: String = "res://resources/recipes/" + file_name
			var recipe: CraftRecipe = load(path) as CraftRecipe
			if recipe == null:
				push_warning("CraftingSystem: no se pudo cargar receta en %s" % path)
			elif not recipe.is_valid():
				push_warning("CraftingSystem: receta inválida ignorada: %s" % path)
			else:
				_recipes.append(recipe)
				recipe_added.emit(recipe)
		file_name = dir.get_next()
	dir.list_dir_end()


# ─── Helper de inventario ─────────────────────────────────────────────────────

func _inv() -> Object:
	# Resuelve qué inventario usar: el override de tests o el autoload global.
	if _inventory_override != null:
		return _inventory_override
	return InventorySystem


# ─── API pública de consulta ──────────────────────────────────────────────────

## Todas las recetas conocidas (cargadas desde disco).
func get_all_recipes() -> Array[CraftRecipe]:
	return _recipes.duplicate()


## Receta por ID. null si no existe.
func get_recipe_by_id(id: StringName) -> CraftRecipe:
	for recipe: CraftRecipe in _recipes:
		if recipe.id == id:
			return recipe
	return null


## true si el inventario tiene TODOS los materiales que la receta necesita Y hay oro suficiente.
func can_craft(recipe: CraftRecipe) -> bool:
	if recipe == null or not recipe.is_valid():
		return false
	# Validar oro primero (falla rápido si no alcanza).
	if recipe.gold_cost > 0 and not GoldSystem.can_afford(recipe.gold_cost):
		return false
	for input: CraftRecipeInput in recipe.inputs:
		var available: int = _inv().get_material_count(input.material.id)
		if available < input.count:
			return false
	return true


## Materiales que faltan para craftear la receta. StringName id → int cantidad faltante.
## Si el jugador tiene todo, devuelve diccionario vacío.
## Si recipe es null o inválida, devuelve diccionario vacío.
func get_missing_materials(recipe: CraftRecipe) -> Dictionary:
	var missing: Dictionary = {}
	if recipe == null or not recipe.is_valid():
		return missing
	for input: CraftRecipeInput in recipe.inputs:
		var available: int = _inv().get_material_count(input.material.id)
		var needed: int = input.count - available
		if needed > 0:
			missing[input.material.id] = needed
	return missing


# ─── API principal ────────────────────────────────────────────────────────────

## Intenta craftear usando la receta dada.
##
## Flujo:
##   1. Validación de receta (aborta si null o inválida, sin consumir nada).
##   2. Validación de materiales Y oro vía can_craft() (aborta si faltan, sin consumir nada).
##   3. Emite craft_started.
##   4. Consume Oro vía GoldSystem.consume().
##   5. Consume materiales atómicamente vía InventorySystem.remove_material().
##   6. Agrega output_item al inventario vía InventorySystem.add_item().
##   7. Emite craft_succeeded y devuelve CraftResult(success=true).
##
## En MVP: crafteo 100% determinístico. Si las precondiciones pasan → éxito.
## Pilar #2: el jugador siempre sabe exactamente por qué un craft falla.
func try_craft(recipe: CraftRecipe) -> CraftResult:
	# Validación: receta válida.
	if recipe == null or not recipe.is_valid():
		var aborted := CraftResult.new()
		aborted.success = false
		aborted.reason = "invalid_recipe"
		craft_aborted.emit(aborted)
		return aborted

	# Validación: oro suficiente (Pilar #2 — razón de fallo específica).
	if recipe.gold_cost > 0 and not GoldSystem.can_afford(recipe.gold_cost):
		var aborted := CraftResult.new()
		aborted.success = false
		aborted.reason = "insufficient_gold"
		craft_aborted.emit(aborted)
		return aborted

	# Validación: materiales suficientes.
	# Chequeamos todo ANTES de consumir — transacción atómica.
	# can_craft() también valida oro, pero el check explícito arriba ya lo cubrió.
	for input: CraftRecipeInput in recipe.inputs:
		var available: int = _inv().get_material_count(input.material.id)
		if available < input.count:
			var aborted := CraftResult.new()
			aborted.success = false
			aborted.reason = "insufficient_materials"
			craft_aborted.emit(aborted)
			return aborted

	# Precondiciones OK. Señal de inicio (UI puede mostrar animación).
	craft_started.emit(recipe)

	# Construir resultado antes de consumir (para tener el registro completo).
	var result := CraftResult.new()
	result.success = true
	result.output_item = recipe.output_item
	result.gold_consumed = 0

	# Consumir Oro (antes de materiales — si por algún bug falla, no perdemos materiales).
	if recipe.gold_cost > 0:
		GoldSystem.consume(recipe.gold_cost)
		result.gold_consumed = recipe.gold_cost

	# Consumir materiales. remove_material es atómico — no puede fallar a medias
	# porque ya validamos disponibilidad arriba y el inventario MVP es ilimitado.
	for input: CraftRecipeInput in recipe.inputs:
		_inv().remove_material(input.material.id, input.count)
		result.materials_consumed[input.material.id] = input.count

	# Agregar item al inventario. add_item devuelve la instancia duplicada —
	# actualizar result para que output_item apunte a la copia en el inventario,
	# no al .tres original de la receta.
	var crafted_instance: ItemData = _inv().add_item(recipe.output_item)
	if crafted_instance != null:
		result.output_item = crafted_instance

	craft_succeeded.emit(result)
	return result


# ─── Registro manual de recetas (para tests y futuro uso) ────────────────────

## Agrega una receta al registro en runtime. Usado en tests para inyectar recetas
## sin depender del disco. También útil para futuras recetas desbloqueables en runtime.
func _register_recipe(recipe: CraftRecipe) -> void:
	if recipe == null or not recipe.is_valid():
		push_warning("CraftingSystem._register_recipe: receta inválida ignorada.")
		return
	# No duplicar IDs.
	for existing: CraftRecipe in _recipes:
		if existing.id == recipe.id:
			push_warning("CraftingSystem._register_recipe: ID duplicado '%s' ignorado." % recipe.id)
			return
	_recipes.append(recipe)
	recipe_added.emit(recipe)
